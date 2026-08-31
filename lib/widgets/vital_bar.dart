import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/stardew_colors.dart';

/// Which vanilla HUD bar this is — decides the accent behaviours: the
/// health bar gets the low-HP pink pulse and the red blood droplets, the
/// energy (stamina) bar gets the "tired" face and the sky-blue sweat
/// droplets.
enum VitalKind { health, energy }

/// One vanilla HUD bar (health or energy), redrawn from the real cropped
/// Cursors-sheet sprites plus a plain painted fill, matching how vanilla
/// `Game1.drawHUD` draws them (verified against the decompiled SV 1.6
/// source — see the rects in `stardew-ds-mod/UiIconCache.cs`). The mod
/// hides the real in-game bars (`stardew-ds-mod/HudBarPatches.cs`); two
/// of these sit next to the companion clock (see `VitalsBars` /
/// `BackpackToolbar`).
///
/// Reproduces:
/// * the 3-piece frame sprite (fixed top cap, vertically stretched
///   middle, fixed bottom cap) with a bottom-anchored fill coloured by
///   `Utility.getRedToGreenLerpColor` ([_redToGreenLerp]) and a darker
///   lip at the fill's top;
/// * ([VitalKind.energy]) the "tired" face sprite above the bar while
///   [exhausted];
/// * ([VitalKind.health]) a pink sine-pulse over the frame while
///   `value < 20` (vanilla's `Color.Pink * (sin(t / (value*50)) / 4 + 0.9)`);
/// * a ±3px shake (scaled to bar width) while [shake] — X-only for
///   health, both axes for energy, matching vanilla's `hitShakeTimer` /
///   `staminaShakeTimer`;
/// * a falling-droplet layer — red blood while `value <= 10`
///   ([VitalKind.health]), sky-blue sweat on each rising edge of [shake]
///   ([VitalKind.energy]) — matching the `Game1.uiOverlayTempSprites`
///   bursts vanilla spawns by the bars (the mod strips the real ones —
///   see `ModEntry.OnUpdateTicked`).
///
/// Sizes itself to the height it's given, at vanilla's skinny [frameAspect].
class VitalBar extends StatefulWidget {
  const VitalBar({
    super.key,
    required this.kind,
    required this.value,
    required this.max,
    required this.shake,
    this.exhausted = false,
    this.capTopUrl,
    this.bodyUrl,
    this.capBottomUrl,
    this.exhaustedUrl,
  });

  final VitalKind kind;
  final int value;
  final int max;

  /// `Game1.hitShakeTimer > 0` (health) / `Game1.staminaShakeTimer > 0`
  /// (energy) — see `GameState.healthShake` / `energyShake`.
  final bool shake;

  /// `Farmer.exhausted` — only drawn for [VitalKind.energy].
  final bool exhausted;

  final String? capTopUrl;
  final String? bodyUrl;
  final String? capBottomUrl;
  final String? exhaustedUrl;

  /// Vanilla stamina frame sprite: 12px wide source, drawn at 4x = 48px;
  /// the full bar (top cap + body + bottom cap) is ~224px tall at a
  /// default 270 max-stamina. `VitalsBars` uses this to pick bar width
  /// from bar height.
  static const double frameAspect = 48 / 224;

  /// Vanilla's stamina fill is `r.X = topOfBar.X + 12, r.Width = 24` on a
  /// 48px-wide bar — so 12/48 in from each edge, 24/48 (half) wide.
  static const double _fillInsetFraction = 12 / 48;

  /// Cap sprites are 12x16 source = 48x64 at 4x — square-ish, 4:3 tall.
  static const double _capAspect = 64 / 48;

  /// Where the fill sits vertically, as a fraction of cap height —
  /// measured off the actual served sprites: the cap sprites are 16 rows
  /// tall; the top cap's lighter inner channel starts at row 13 (rows
  /// 0–12 are the decorative finial), and the bottom cap's channel runs
  /// through row 13 (only rows 14–15 are the rounded foot).
  static const double _trackTopCapFraction = 13 / 16;
  static const double _trackBottomCapFraction = 2 / 16;

  @override
  State<VitalBar> createState() => _VitalBarState();
}

class _VitalBarState extends State<VitalBar> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _rng = math.Random();

  final List<_Droplet> _droplets = [];

  /// Wall-clock ms, advanced by the ticker — drives the pink health pulse
  /// and the droplet physics without leaning on `DateTime.now()` per frame.
  double _elapsedMs = 0;
  Duration _lastTick = Duration.zero;

  /// Next `_elapsedMs` at which the once-a-second blood burst may spawn
  /// again (vanilla re-checks on its own 1s `noteBlockTimer`).
  double _nextBloodSpawnMs = 0;

  bool get _isHealth => widget.kind == VitalKind.health;
  bool get _lowPulse => _isHealth && widget.max > 0 && widget.value > 0 && widget.value < 20;
  bool get _critical => _isHealth && widget.max > 0 && widget.value <= 10;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(VitalBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sky-blue sweat burst: 4 drops on each rising edge of the energy
    // shake, matching vanilla's `staminaShakeTimer = 1000; for (i<4) ...`.
    // Keyed off the state transition here rather than off a tick, so it
    // fires even when the ticker was stopped (steady bar) the moment before.
    if (widget.kind == VitalKind.energy && widget.shake && !oldWidget.shake) {
      for (var i = 0; i < 4; i++) {
        _droplets.add(_Droplet.sweat(_rng, delayMs: i * 30.0));
      }
    }
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// Whether anything is currently animating. The ticker runs only while
  /// this holds, so a steady bar costs nothing per frame.
  bool get _animating =>
      _droplets.isNotEmpty ||
      widget.shake ||
      (widget.kind == VitalKind.energy && widget.exhausted) ||
      _lowPulse ||
      _critical;

  void _syncTicker() {
    if (_animating) {
      if (!_ticker.isActive) {
        _lastTick = Duration.zero;
        _ticker.start();
      }
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final dtMs = (elapsed - _lastTick).inMicroseconds / 1000.0;
    _lastTick = elapsed;
    // Guard against the first frame's huge dt and any post-pause jump.
    final dt = dtMs.clamp(0.0, 50.0);
    _elapsedMs += dt;

    // Red blood: 3 drops per second while health <= 10, matching vanilla's
    // once-a-second `noteBlockTimer` check in the update loop.
    if (_critical) {
      if (_elapsedMs >= _nextBloodSpawnMs) {
        for (var i = 0; i < 3; i++) {
          _droplets.add(_Droplet.blood(_rng, delayMs: i * 150.0));
        }
        _nextBloodSpawnMs = _elapsedMs + 1000;
      }
    } else {
      _nextBloodSpawnMs = _elapsedMs;
    }

    for (final d in _droplets) {
      d.advance(dt);
    }
    _droplets.removeWhere((d) => !d.alive);

    if (mounted) setState(() {});
    _syncTicker();
  }

  static int _clampByte(num v) => v.clamp(0, 255).round();

  double get _fraction => widget.max > 0 ? (widget.value / widget.max).clamp(0.0, 1.0) : 0.0;

  /// Port of `Utility.getRedToGreenLerpColor(power)`:
  /// `R = power<=0.5 ? 255 : (1-power)*2*255`, `G = min(255, power*2*255)`,
  /// `B = 0`.
  static Color _redToGreenLerp(double power) {
    power = power.clamp(0.0, 1.0);
    final r = power <= 0.5 ? 255.0 : (1 - power) * 2 * 255;
    final g = math.min(255.0, power * 2 * 255);
    return Color.fromARGB(255, _clampByte(r), _clampByte(g), 0);
  }

  /// Vanilla's low-health frame tint:
  /// `Color.Pink * (sin(ms / (health*50)) / 4 + 0.9)`, where `Color.Pink`
  /// is (255, 192, 203). A multiplier > 1 clamps per channel (XNA
  /// `Color * float` behaviour).
  Color? get _frameTint {
    if (!_lowPulse) return null;
    final factor = math.sin(_elapsedMs / (widget.value * 50)) / 4 + 0.9;
    return Color.fromARGB(
      255,
      _clampByte(255 * factor),
      _clampByte(192 * factor),
      _clampByte(203 * factor),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fills whatever box the caller gives it (`VitalsBars` sizes it to
    // `height * frameAspect` wide). The inner LayoutBuilder is only for
    // the pixel maths (shake amplitude, droplet scale) — it never picks
    // its own size, so it's safe under any constraints.
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (constraints.maxHeight.isFinite ? constraints.maxHeight * VitalBar.frameAspect : 0.0);
        final h = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : (w == 0 ? 0.0 : w / VitalBar.frameAspect);

        // Vanilla shakes by `random.Next(-3, 4)` px on a 48px-wide bar;
        // scale that to our (much narrower) bar so the wobble stays
        // proportional instead of flinging a ~16px bar ±3px.
        final shakePx = 3.0 * (w / 48);
        double jitter() => (_rng.nextDouble() * 2 - 1) * shakePx;
        final shakeOffset = !widget.shake
            ? Offset.zero
            : _isHealth
                ? Offset(jitter(), 0) // vanilla: health shakes X only
                : Offset(jitter(), jitter());

        return Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Transform.translate(
                offset: shakeOffset,
                child: _Frame(
                  fraction: _fraction,
                  fillColor: _redToGreenLerp(_fraction),
                  frameTint: _frameTint,
                  topCapUrl: widget.capTopUrl,
                  bodyUrl: widget.bodyUrl,
                  bottomCapUrl: widget.capBottomUrl,
                ),
              ),
            ),
            if (widget.kind == VitalKind.energy && widget.exhausted)
              Positioned(
                // Vanilla draws the 12x11 "tired" sprite at 4x directly
                // on top of the bar's top cap — its bottom edge on the
                // bar's top edge. The sprite is `width:height = 12:11`,
                // so at `width == w` its height is `w * 11/12`; offset
                // up by exactly that so it sits flush above the bar.
                top: -(w * 11 / 12),
                left: 0,
                width: w,
                child: _ExhaustedFace(url: widget.exhaustedUrl, width: w),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DropletPainter(droplets: _droplets, box: Size(w, h)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The 3-piece frame sprite with a bottom-anchored coloured fill inset
/// [VitalBar._fillInsetFraction] from each edge.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.fraction,
    required this.fillColor,
    required this.frameTint,
    required this.topCapUrl,
    required this.bodyUrl,
    required this.bottomCapUrl,
  });

  final double fraction;
  final Color fillColor;

  /// Non-null only for the health bar while `value < 20` — the pink
  /// sine-pulse vanilla applies to the frame draw colour.
  final Color? frameTint;

  final String? topCapUrl;
  final String? bodyUrl;
  final String? bottomCapUrl;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // `_Frame` always fills a tightly-sized box (see [VitalBar.build]);
        // guard anyway so an unexpected unbounded constraint can't push an
        // infinite/NaN size into the Positioned fill below.
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;
        final capHeight = w * VitalBar._capAspect;
        final inset = w * VitalBar._fillInsetFraction;

        final trackBottom = capHeight * VitalBar._trackBottomCapFraction;
        final trackTop = capHeight * VitalBar._trackTopCapFraction;
        final trackHeight = math.max(0.0, h - trackTop - trackBottom);
        final fillHeight = trackHeight * fraction.clamp(0.0, 1.0);

        // Darker lip at the fill's top — vanilla does `c.R -= 50; c.G -= 50;`
        // and redraws a 4-of-64 slice.
        final lip = Color.fromARGB(
          255,
          (fillColor.r * 255.0 - 50).clamp(0, 255).round(),
          (fillColor.g * 255.0 - 50).clamp(0, 255).round(),
          (fillColor.b * 255.0).clamp(0, 255).round(),
        );
        final lipHeight = math.min(fillHeight, math.max(1.0, capHeight * (4 / 64)));

        return Stack(
          // Clip so a full fill can't visually spill past the frame if
          // the track constants are a little off for a given sprite.
          clipBehavior: Clip.hardEdge,
          fit: StackFit.expand,
          children: [
            // Frame first (behind) — caps pinned, body stretched between.
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _frameImage(topCapUrl, height: capHeight),
                  Expanded(child: _frameImage(bodyUrl, fit: BoxFit.fill)),
                  _frameImage(bottomCapUrl, height: capHeight),
                ],
              ),
            ),
            // Coloured fill on top of the frame's hollow interior, inset so
            // the tube walls still show — this is the order vanilla draws
            // in (frame, then `staminaRect` fill at +12px inset).
            Positioned(
              left: inset,
              right: inset,
              bottom: trackBottom,
              height: fillHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: lipHeight, child: ColoredBox(color: lip)),
                  Expanded(child: ColoredBox(color: fillColor)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _frameImage(String? url, {double? height, BoxFit fit = BoxFit.fill}) {
    final color = frameTint;
    if (url == null) {
      // Flat wood rail fallback before a connection / if the crop 404s.
      return SizedBox(
        height: height,
        width: double.infinity,
        child: const ColoredBox(color: StardewColors.woodDark),
      );
    }
    return Image.network(
      url,
      height: height,
      width: double.infinity,
      fit: fit,
      filterQuality: FilterQuality.none,
      color: color,
      colorBlendMode: color == null ? null : BlendMode.modulate,
      errorBuilder: (context, error, stackTrace) => SizedBox(
        height: height,
        width: double.infinity,
        child: const ColoredBox(color: StardewColors.woodDark),
      ),
    );
  }
}

/// The little "tired" face sprite (`vitals-exhausted`, source
/// `Rectangle(191, 406, 12, 11)`), shown above the energy bar while
/// exhausted. Falls back to nothing rather than a placeholder — it's a
/// decoration, not load-bearing.
class _ExhaustedFace extends StatelessWidget {
  const _ExhaustedFace({required this.url, required this.width});

  final String? url;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (url == null) return const SizedBox.shrink();
    return Image.network(
      url!,
      width: width,
      fit: BoxFit.fitWidth,
      filterQuality: FilterQuality.none,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

/// One falling droplet — a small teardrop painted in the vanilla tint
/// (`Color.Red` blood / `Color.SkyBlue` sweat). Physics ported from the
/// `TemporaryAnimatedSprite` fields vanilla sets on the real particles:
/// an initial `motion` plus a constant `acceleration` of (0, 0.5) per
/// 60fps tick, a short `delayBeforeAnimationStart`, and a lifetime of
/// roughly a second. Distances are in vanilla's own 4x HUD pixel space;
/// [_DropletPainter] scales them to the (much smaller) companion bar.
class _Droplet {
  _Droplet({
    required this.color,
    required this.vx,
    required this.vy,
    required this.spawnJitterX,
    required this.delayMs,
  });

  factory _Droplet.blood(math.Random rng, {required double delayMs}) => _Droplet(
        color: const Color(0xFFFF0000),
        vx: -1.5,
        vy: (-9 + rng.nextInt(3)).toDouble(), // vanilla: -8 + random(-1, 2) => -9..-7
        spawnJitterX: rng.nextInt(32).toDouble(),
        delayMs: delayMs,
      );

  factory _Droplet.sweat(math.Random rng, {required double delayMs}) => _Droplet(
        color: const Color(0xFF87CEEB), // Color.SkyBlue
        vx: -2,
        vy: -10,
        spawnJitterX: rng.nextInt(32).toDouble(),
        delayMs: delayMs,
      );

  final Color color;
  double vx;
  double vy;
  final double spawnJitterX;
  double delayMs;

  /// Offset from the bar's top-centre, in vanilla HUD pixels.
  double x = 0;
  double y = 0;
  double _ageMs = 0;

  static const _lifetimeMs = 950.0;

  bool get alive => _ageMs < _lifetimeMs;

  double get opacity {
    if (delayMs > 0) return 0;
    final t = _ageMs / _lifetimeMs;
    return (1 - t * t).clamp(0.0, 1.0);
  }

  void advance(double dtMs) {
    if (delayMs > 0) {
      delayMs -= dtMs;
      return;
    }
    _ageMs += dtMs;
    // Integrate at vanilla's 60fps tick scale so vx/vy stay in the units
    // vanilla authored them in.
    final ticks = dtMs / (1000 / 60);
    vy += 0.5 * ticks;
    x += vx * ticks;
    y += vy * ticks;
  }
}

class _DropletPainter extends CustomPainter {
  _DropletPainter({required this.droplets, required this.box});

  final List<_Droplet> droplets;
  final Size box;

  @override
  void paint(Canvas canvas, Size size) {
    // Vanilla bars are ~224px tall; scale its particle offsets to ours.
    final scale = box.height / 224;
    final originX = box.width / 2;
    for (final d in droplets) {
      if (d.opacity <= 0) continue;
      final px = originX + (d.spawnJitterX - 16) * scale + d.x * scale;
      final py = box.height * 0.12 + d.y * scale;
      if (py > box.height * 1.4) continue;

      final paint = Paint()..color = d.color.withValues(alpha: d.opacity);
      final r = math.max(1.0, 2.2 * scale);
      // Teardrop: a circle with a short tail pointing along travel.
      final path = Path()
        ..addOval(Rect.fromCircle(center: Offset(px, py), radius: r))
        ..moveTo(px - r, py)
        ..lineTo(px, py - r * 2.2)
        ..lineTo(px + r, py)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_DropletPainter oldDelegate) => true;
}
