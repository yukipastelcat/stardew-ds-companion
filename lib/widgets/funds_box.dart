import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/stardew_colors.dart';

/// The vanilla `DayTimeMoneyBox` money display, rendered standalone (no
/// visual join to the clock) as the backpack toolbar's funds cell. Uses
/// the real cropped sprites — the money-box backdrop (`money-box`, coin
/// icon + digit well) and the `MoneyDial` digit glyphs
/// (`money-digit-0`..`9`, drawn Maroon) — and reproduces the vanilla
/// effects, verified against the decompiled `DayTimeMoneyBox.drawMoneyBox`
/// / `MoneyDial.draw` (SV 1.6):
///
/// * the digit **roll** — the shown value chases the target at
///   `speed = (target - shown) / 100` per frame, so any change takes
///   ~100 frames regardless of size;
/// * the **shake** — ±3px (scaled to box size) while [moneyShake]
///   (`Game1.dayTimeMoneyBox.moneyShakeTimer > 0`);
/// * the **shine** — each digit briefly scales up ~7% in a right-to-left
///   wave for `numDigits * 60`ms after a gain settles
///   (`moneyShineTimer`);
/// * **particles** — gold coins puff up on a gain, grey dust specks on a
///   loss, matching the `MoneyDial.animations` bursts.
///
/// Vanilla shows current money only (no thousands separators, no lifetime
/// earnings) — same here.
class FundsBox extends StatefulWidget {
  const FundsBox({
    super.key,
    required this.funds,
    required this.moneyShake,
    required this.boxUrl,
    required this.digitUrl,
  });

  final int funds;
  final bool moneyShake;
  final String? boxUrl;
  final String? Function(int digit) digitUrl;

  /// The served `money-box` crop's size — `Rectangle(340, 472, 65, 17)`
  /// with the top 3 peg-handle rows removed => 65x14 (see `UiIconCache`).
  static const double _boxAspect = 65 / 14;

  /// Where the 8-slot digit well sits inside the (cropped) box and the
  /// per-digit advance, as fractions of its 65x14 size — measured off the
  /// actual served sprite: the well is 8 slots of `@#####` starting at
  /// col 8, rows 6-13 of the uncropped sprite (=> rows 3-10 of the crop).
  static const double _dialLeftFraction = 9 / 65;
  static const double _dialTopFraction = 3 / 14;
  static const double _digitWidthFraction = 5 / 65;
  static const double _digitAdvanceFraction = 6 / 65;
  static const double _digitHeightFraction = 8 / 14;

  /// `MoneyDial(8)` in `DayTimeMoneyBox`.
  static const int numDigits = 8;

  @override
  State<FundsBox> createState() => _FundsBoxState();
}

class _FundsBoxState extends State<FundsBox> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final _rng = math.Random();
  final List<_MoneyParticle> _particles = [];

  double _shown = 0;
  int _speed = 0;
  double _elapsedMs = 0;
  Duration _lastTick = Duration.zero;

  /// End time (in `_elapsedMs`) of the post-gain shine wave, or 0.
  double _shineUntilMs = 0;

  /// Countdown to the next particle/"sound" tick, in frames — vanilla's
  /// `soundTimer`.
  int _soundTimer = 0;

  @override
  void initState() {
    super.initState();
    _shown = widget.funds.toDouble();
  }

  @override
  void didUpdateWidget(FundsBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.funds != oldWidget.funds) {
      // Port of MoneyDial.draw's "target changed" branch.
      final target = widget.funds;
      _speed = ((target - _shown) / 100).truncate();
      _soundTimer = math.max(6, 100 ~/ (_speed.abs() + 1));
      if (!_ticker.isActive) {
        _lastTick = Duration.zero;
        _ticker.start();
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dtMs = (elapsed - _lastTick).inMicroseconds / 1000.0;
    _lastTick = elapsed;
    final dt = dtMs.clamp(0.0, 50.0);
    _elapsedMs += dt;
    // Everything below is authored per 60fps frame; scale by how many
    // frames actually elapsed.
    final frames = dt / (1000 / 60);

    final target = widget.funds.toDouble();
    if (_shown != target) {
      final dir = _shown < target ? 1 : -1;
      _shown += (_speed + dir) * frames;
      if ((target - _shown).abs() <= _speed.abs() + 1 ||
          (_speed != 0 && (target - _shown).sign != _speed.sign)) {
        _shown = target;
        _shineUntilMs = _elapsedMs + FundsBox.numDigits * 60;
      }
      _soundTimer -= frames.round();
      if (_soundTimer <= 0) {
        _soundTimer = math.max(6, 100 ~/ (_speed.abs() + 1));
        if (_rng.nextDouble() < 0.4) {
          _particles.add(target > _shown ? _MoneyParticle.coin(_rng) : _MoneyParticle.dust(_rng));
        }
      }
    }

    for (final p in _particles) {
      p.advance(dt);
    }
    _particles.removeWhere((p) => !p.alive);

    final done = _shown == target && _particles.isEmpty && _elapsedMs >= _shineUntilMs;
    if (mounted) setState(() {});
    if (done) _ticker.stop();
  }

  /// Vanilla's `moneyShineTimer / 60 == numDigits - i` gate: digit `i`
  /// (0 = leftmost) is enlarged for its own 60ms slot of the wave.
  double _digitScale(int indexFromLeft) {
    if (_elapsedMs >= _shineUntilMs) return 1;
    final remainingSlots = ((_shineUntilMs - _elapsedMs) / 60).ceil();
    return remainingSlots == FundsBox.numDigits - indexFromLeft ? 1.075 : 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        final maxH = constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;
        // Fit the wide/short box into the cell, keeping its aspect.
        final boxW = math.min(maxW, maxH * FundsBox._boxAspect);
        final boxH = boxW / FundsBox._boxAspect;

        final shakePx = 3.0 * (boxW / 260);
        double j() => (_rng.nextDouble() * 2 - 1) * shakePx;
        final shake = widget.moneyShake ? Offset(j(), j()) : Offset.zero;

        final digits = _significantDigits(_shown.round().abs());

        return Center(
          child: SizedBox(
            width: boxW,
            height: boxH,
            child: Transform.translate(
              offset: shake,
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: widget.boxUrl == null
                        ? const _BoxFallback()
                        : Image.network(
                            widget.boxUrl!,
                            fit: BoxFit.fill,
                            filterQuality: FilterQuality.none,
                            errorBuilder: (_, __, ___) => const _BoxFallback(),
                          ),
                  ),
                  for (var i = 0; i < digits.length; i++)
                    Positioned(
                      left: (FundsBox._dialLeftFraction + i * FundsBox._digitAdvanceFraction) * boxW,
                      top: FundsBox._dialTopFraction * boxH,
                      width: FundsBox._digitWidthFraction * boxW,
                      height: FundsBox._digitHeightFraction * boxH,
                      child: Transform.scale(
                        scale: _digitScale(i),
                        child: _DigitGlyph(url: widget.digitUrl(digits[i])),
                      ),
                    ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _MoneyParticlePainter(_particles, Size(boxW, boxH)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Digits of [value], leading zeros dropped (but always at least one
  /// digit), capped at [FundsBox.numDigits].
  static List<int> _significantDigits(int value) {
    final s = value.toString();
    final trimmed = s.length > FundsBox.numDigits ? s.substring(s.length - FundsBox.numDigits) : s;
    return trimmed.split('').map(int.parse).toList();
  }
}

class _DigitGlyph extends StatelessWidget {
  const _DigitGlyph({required this.url});

  final String? url;

  static const _maroon = Color(0xFF800000); // XNA Color.Maroon

  @override
  Widget build(BuildContext context) {
    if (url == null) return const SizedBox.shrink();
    return Image.network(
      url!,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
      color: _maroon,
      colorBlendMode: BlendMode.modulate,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

/// Flat parchment placeholder for the money-box backdrop.
class _BoxFallback extends StatelessWidget {
  const _BoxFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StardewColors.parchmentDark,
        border: Border.all(color: StardewColors.wood, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

/// A coin (gain) or dust speck (loss) puffed off the dial. Physics
/// loosely ported from the `TemporaryAnimatedSprite`s `MoneyDial.draw`
/// spawns — an upward pop with gravity and a ~1s life. Positions are in
/// vanilla's 4x pixel space; the painter scales them to the box.
class _MoneyParticle {
  _MoneyParticle({
    required this.color,
    required this.radius,
    required this.spawn,
    required this.vx,
    required this.vy,
  });

  factory _MoneyParticle.coin(math.Random rng) => _MoneyParticle(
        color: const Color(0xFFFFD700), // Color.Gold
        radius: 3,
        spawn: Offset(30 + rng.nextInt(160).toDouble(), -32 + rng.nextInt(80).toDouble()),
        vx: (rng.nextInt(20) - 10) / 10,
        vy: (-5 + rng.nextInt(3)).toDouble(), // -5..-3
      );

  factory _MoneyParticle.dust(math.Random rng) => _MoneyParticle(
        color: const Color(0xFFDDDDDD),
        radius: (1 + rng.nextInt(2)).toDouble(),
        spawn: Offset(rng.nextInt(160).toDouble(), -32 + rng.nextInt(64).toDouble()),
        vx: (rng.nextInt(70) - 30) / 10,
        vy: (-30 + rng.nextInt(25)) / 10,
      );

  final Color color;
  final double radius;
  final Offset spawn;
  double vx;
  double vy;

  double x = 0;
  double y = 0;
  double _ageMs = 0;
  static const _lifeMs = 900.0;

  bool get alive => _ageMs < _lifeMs;
  double get opacity => (1 - _ageMs / _lifeMs).clamp(0.0, 1.0);

  void advance(double dtMs) {
    _ageMs += dtMs;
    final frames = dtMs / (1000 / 60);
    vy += 0.25 * frames;
    x += vx * frames;
    y += vy * frames;
  }
}

class _MoneyParticlePainter extends CustomPainter {
  _MoneyParticlePainter(this.particles, this.box);

  final List<_MoneyParticle> particles;
  final Size box;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = box.width / 260;
    for (final p in particles) {
      if (p.opacity <= 0) continue;
      final c = Offset(
        (p.spawn.dx + p.x) * scale,
        box.height * 0.4 + (p.spawn.dy + p.y) * scale,
      );
      canvas.drawCircle(
        c,
        math.max(0.8, p.radius * scale),
        Paint()..color = p.color.withValues(alpha: p.opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_MoneyParticlePainter oldDelegate) => true;
}
