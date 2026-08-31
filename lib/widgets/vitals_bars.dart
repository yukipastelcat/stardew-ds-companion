import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/game_state.dart';
import '../services/game_connection_service.dart';
import '../theme/stardew_colors.dart';

/// The vanilla health and energy (stamina) bars, redrawn next to the
/// companion's clock (see `BackpackToolbar`). The mod hides the real
/// in-game bars (`stardew-ds-mod/HudBarPatches.cs`); this reproduces them
/// from the real cropped Cursors-sheet sprites plus a plain painted fill,
/// matching how vanilla `Game1.drawHUD` draws them (verified against the
/// decompiled 1.6 source — see the rects in `UiIconCache.cs`):
///
/// * two skinny vertical bars, **health left, energy right** (vanilla
///   draws the health bar 56px left of the stamina bar) — both always
///   shown, regardless of location or current health (a deliberate
///   difference from vanilla, which hides the health bar outside danger
///   zones when at full HP);
/// * each bar = a 3-piece frame sprite (fixed top cap, vertically
///   stretched middle, fixed bottom cap) with a bottom-anchored fill
///   rect coloured by `Utility.getRedToGreenLerpColor` (ported in
///   [_redToGreenLerp]) and a slightly darker 4px lip at the fill's top,
///   exactly as `drawHUD` does it;
/// * the "tired" face sprite above the energy bar while
///   [GameState.exhausted];
/// * a pink sine-pulse over the health frame while `health < 20`
///   (vanilla's `Color.Pink * (sin(t / (health*50)) / 4 + 0.9)`);
/// * a ±3px shake of the whole energy bar while [GameState.energyShake]
///   and an X-only shake of the health bar while [GameState.healthShake];
/// * a falling-droplet particle layer — red "blood" drops while
///   `health <= 10`, sky-blue "sweat" drops on each [GameState.energyShake]
///   — matching the `Game1.uiOverlayTempSprites` bursts vanilla spawns by
///   the bars (the mod strips the real ones — see `ModEntry.OnUpdateTicked`).
///
/// Sized by [_VitalsBarsState]'s `LayoutBuilder` to the height it's given
/// (the clock's body height minus its leg pegs — see `BackpackToolbar`),
/// picking its own width from that so the bars stay at vanilla's skinny
/// ~48:224 frame aspect no matter how wide the Backpack grid is.
class VitalsBars extends StatefulWidget {
  const VitalsBars({super.key, required this.connection, required this.state});

  final GameConnectionService connection;
  final GameState state;

  /// Vanilla stamina frame sprite: 12px wide source, drawn at 4x = 48px;
  /// the full bar (top cap + body + bottom cap) is ~224px tall at a
  /// default 270 max-stamina. Everything below is sized off this ratio.
  static const double _frameAspect = 48 / 224;

  /// Vanilla's stamina fill is `r.X = topOfBar.X + 12, r.Width = 24` on a
  /// 48px-wide bar — so 12/48 in from each edge, 24/48 (half) wide.
  static const double _fillInsetFraction = 12 / 48;

  /// Cap sprites are 12x16 source = 48x64 at 4x — square-ish, 4:3 tall.
  static const double _capAspect = 64 / 48;

  /// Where the fill sits vertically, as a fraction of the (4:3) cap
  /// height. Derived from the vanilla stamina bar's own geometry
  /// (`Game1.drawHUD`, default MaxStamina): 232px bar = 64 top cap + 104
  /// body + 64 bottom cap; the fill runs [48, 216] of that — i.e. it
  /// starts 48/64 = 0.75 down the top cap and ends 16/64 = 0.25 up the
  /// bottom cap.
  static const double _trackTopCapFraction = 0.75;
  static const double _trackBottomCapFraction = 0.25;

  @override
  State<VitalsBars> createState() => _VitalsBarsState();
}

class _VitalsBarsState extends State<VitalsBars> with SingleTickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(VitalsBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sky-blue sweat burst: 4 drops on each rising edge of energyShake,
    // matching vanilla's `staminaShakeTimer = 1000; for (i<4) ...`. Keyed
    // off the state transition here rather than off a tick, so it fires
    // even when the ticker was stopped (steady bar) the moment before.
    if (widget.state.energyShake && !oldWidget.state.energyShake) {
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

  /// Whether anything is currently animating — the shake flags, the
  /// low-health pulse, the tired face's (static, but cheap to keep) or a
  /// live droplet. The ticker runs only while this holds, so a steady bar
  /// costs nothing per frame.
  bool get _animating {
    final s = widget.state;
    return _droplets.isNotEmpty ||
        s.energyShake ||
        s.healthShake ||
        s.exhausted ||
        (s.maxHealth > 0 && s.health > 0 && s.health < 20) ||
        (s.maxHealth > 0 && s.health <= 10);
  }

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

    final s = widget.state;

    // Red blood: 3 drops per second while health <= 10, matching vanilla's
    // once-a-second `noteBlockTimer` check in the update loop.
    if (s.maxHealth > 0 && s.health <= 10) {
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

  static double _fraction(int value, int max) =>
      max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;

  static int _clampByte(num v) => v.clamp(0, 255).round();

  /// Port of `Utility.getRedToGreenLerpColor(power)`:
  /// `R = power<=0.5 ? 255 : (1-power)*2*255`, `G = min(255, power*2*255)`,
  /// `B = 0`.
  static Color _redToGreenLerp(double power) {
    power = power.clamp(0.0, 1.0);
    final r = power <= 0.5 ? 255.0 : (1 - power) * 2 * 255;
    final g = math.min(255.0, power * 2 * 255);
    return Color.fromARGB(255, _clampByte(r), _clampByte(g), 0);
  }

  /// Vanilla's low-health frame tint: `Color.Pink * (sin(ms / (health*50)) / 4 + 0.9)`,
  /// where `Color.Pink` is (255, 192, 203). A multiplier > 1 clamps per
  /// channel (XNA `Color * float` behaviour).
  Color? _healthFrameTint(int health) {
    if (health >= 20 || health <= 0) return null;
    final factor = math.sin(_elapsedMs / (health * 50)) / 4 + 0.9;
    return Color.fromARGB(
      255,
      _clampByte(255 * factor),
      _clampByte(192 * factor),
      _clampByte(203 * factor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : constraints.maxWidth; // fallback if handed an unbounded box
        final barWidth = height * VitalsBars._frameAspect;
        final gap = barWidth * 0.35;
        final totalWidth = barWidth * 2 + gap;

        final s = widget.state;
        final c = widget.connection;

        // Vanilla shakes by `random.Next(-3, 4)` px on a 48px-wide bar;
        // scale that to our (much narrower) bar so the wobble stays
        // proportional instead of flinging a 16px bar ±3px.
        final shakePx = 3.0 * (barWidth / 48);
        double jitter() => (_rng.nextDouble() * 2 - 1) * shakePx;
        final healthShakeOffset =
            s.healthShake ? Offset(jitter(), 0) : Offset.zero; // vanilla: X only
        final energyShakeOffset =
            s.energyShake ? Offset(jitter(), jitter()) : Offset.zero;

        return SizedBox(
          width: totalWidth,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Health bar (left).
              Positioned(
                left: 0,
                bottom: 0,
                width: barWidth,
                height: height,
                child: Transform.translate(
                  offset: healthShakeOffset,
                  child: _Bar(
                    fraction: _fraction(s.health, s.maxHealth),
                    fillColor: _redToGreenLerp(_fraction(s.health, s.maxHealth)),
                    frameTint: _healthFrameTint(s.health),
                    topCapUrl: c.vitalsBarPieceUrl('health', 'cap-top'),
                    bodyUrl: c.vitalsBarPieceUrl('health', 'body'),
                    bottomCapUrl: c.vitalsBarPieceUrl('health', 'cap-bottom'),
                  ),
                ),
              ),
              // Energy bar (right, nearest the clock).
              Positioned(
                right: 0,
                bottom: 0,
                width: barWidth,
                height: height,
                child: Transform.translate(
                  offset: energyShakeOffset,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _Bar(
                        fraction: _fraction(s.energy, s.maxEnergy),
                        fillColor: _redToGreenLerp(_fraction(s.energy, s.maxEnergy)),
                        frameTint: null,
                        topCapUrl: c.vitalsBarPieceUrl('energy', 'cap-top'),
                        bodyUrl: c.vitalsBarPieceUrl('energy', 'body'),
                        bottomCapUrl: c.vitalsBarPieceUrl('energy', 'cap-bottom'),
                      ),
                      if (s.exhausted)
                        Positioned(
                          // Vanilla draws the 12x11 "tired" sprite at 4x
                          // (48x11*4) directly on top of the bar's top cap
                          // — its bottom edge on the bar's top edge. The
                          // sprite is `width:height = 12:11`, so at
                          // `width == barWidth` its height is `barWidth *
                          // 11/12`; offset up by exactly that so it sits
                          // flush above the bar.
                          top: -(barWidth * 11 / 12),
                          left: 0,
                          width: barWidth,
                          child: _ExhaustedFace(url: c.vitalsExhaustedUrl, width: barWidth),
                        ),
                    ],
                  ),
                ),
              ),
              // Droplet particle layer — spans the whole box, drops fall
              // from near each bar's top and arc down-left like vanilla's.
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _DropletPainter(
                      droplets: _droplets,
                      box: Size(totalWidth, height),
                      healthBarCenterX: barWidth / 2,
                      energyBarCenterX: totalWidth - barWidth / 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One bar: the 3-piece frame sprite with a bottom-anchored coloured fill
/// inset [VitalsBars._fillInsetFraction] from each edge.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.fillColor,
    required this.frameTint,
    required this.topCapUrl,
    required this.bodyUrl,
    required this.bottomCapUrl,
  });

  final double fraction;
  final Color fillColor;

  /// Non-null only for the health bar while `health < 20` — the pink
  /// sine-pulse vanilla applies to the frame draw colour.
  final Color? frameTint;

  final String? topCapUrl;
  final String? bodyUrl;
  final String? bottomCapUrl;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final capHeight = w * VitalsBars._capAspect;
        final inset = w * VitalsBars._fillInsetFraction;

        // The fill "track" — the hollow interior of the frame tube.
        final trackBottom = capHeight * VitalsBars._trackBottomCapFraction;
        final trackTop = capHeight * VitalsBars._trackTopCapFraction;
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
          // Both children are Positioned — without this the Stack would
          // collapse to zero under the loose constraints it gets as a
          // non-positioned child of the energy-bar Stack.
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
    required this.originBar,
    required this.spawnJitterX,
    required this.delayMs,
  });

  factory _Droplet.blood(math.Random rng, {required double delayMs}) => _Droplet(
        color: const Color(0xFFFF0000),
        vx: -1.5,
        vy: (-9 + rng.nextInt(3)).toDouble(), // vanilla: -8 + random(-1, 2) => -9..-7
        originBar: _DropletBar.health,
        spawnJitterX: rng.nextInt(32).toDouble(),
        delayMs: delayMs,
      );

  factory _Droplet.sweat(math.Random rng, {required double delayMs}) => _Droplet(
        color: const Color(0xFF87CEEB), // Color.SkyBlue
        vx: -2,
        vy: -10,
        originBar: _DropletBar.energy,
        spawnJitterX: rng.nextInt(32).toDouble(),
        delayMs: delayMs,
      );

  final Color color;
  double vx;
  double vy;
  final _DropletBar originBar;
  final double spawnJitterX;
  double delayMs;

  /// Offset from the origin bar's top, in vanilla HUD pixels.
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

enum _DropletBar { health, energy }

class _DropletPainter extends CustomPainter {
  _DropletPainter({
    required this.droplets,
    required this.box,
    required this.healthBarCenterX,
    required this.energyBarCenterX,
  });

  final List<_Droplet> droplets;
  final Size box;
  final double healthBarCenterX;
  final double energyBarCenterX;

  @override
  void paint(Canvas canvas, Size size) {
    // Vanilla bars are ~224px tall; scale its particle offsets to ours.
    final scale = box.height / 224;
    for (final d in droplets) {
      if (d.opacity <= 0) continue;
      final originX = d.originBar == _DropletBar.health ? healthBarCenterX : energyBarCenterX;
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
  bool shouldRepaint(_DropletPainter old) => true;
}
