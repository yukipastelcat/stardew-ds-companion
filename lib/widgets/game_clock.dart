import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/stardew_colors.dart';

/// Redraws the vanilla `DayTimeMoneyBox` HUD element: its own box
/// backdrop sprite, the season/weather icons, digital date/time text, and
/// the single sundial-style needle, all at the same relative positions
/// the real game draws them at (source rects read from the real
/// decompiled `DayTimeMoneyBox.draw` before writing this — ported from
/// the pre-rebuild `companion-app` repo's `GameStatusBar`/`_ClockBox`,
/// where this was originally verified). Fixed 71:43 aspect ratio,
/// matching the box sprite's own native shape — sized here by [height]
/// (driven by the toolbar row's `slotSize`) rather than by width, so it
/// always matches the row height exactly regardless of how wide the
/// grid above it is.
class GameClock extends StatelessWidget {
  const GameClock({
    super.key,
    required this.weekday,
    required this.season,
    required this.dayOfMonth,
    required this.hour24,
    required this.minute,
    required this.weatherIcon,
    required this.weatherLabel,
    this.seasonIconUrl,
    this.weatherIconUrl,
    this.boxUrl,
    this.needleUrl,
    required this.height,
    this.fontScale = 1.0,
  });

  final String weekday;
  final String season;
  final int dayOfMonth;
  final int hour24;
  final int minute;
  final IconData weatherIcon;
  final String weatherLabel;
  final String? seasonIconUrl;
  final String? weatherIconUrl;
  final String? boxUrl;
  final String? needleUrl;
  final double height;

  /// Multiplier applied on top of the ambient default text size for the
  /// digital date/time text (the toolbar grows the box a flat number of
  /// pixels — see `BackpackToolbar._clockSizeBump` — and passes the
  /// matching ratio here so the text grows with it instead of looking
  /// undersized). Defaults to 1.0 (no change) for any other caller.
  final double fontScale;

  /// The box sprite's own native size, `Rectangle(333, 431, 71, 43)` on
  /// `Game1.mouseCursors` — every overlay below is positioned as a
  /// fraction of this, taken straight from the real draw call's pixel
  /// offsets (already in the same "4x" space the box itself renders at:
  /// 71x43 native -> 284x172 on screen, so e.g. offset 212 of 284 -> 0.75).
  static const _nativeWidth = 71.0;
  static const _nativeHeight = 43.0;

  String get _digital {
    final h12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final m = minute.toString().padLeft(2, '0');
    final suffix = hour24 < 12 ? 'AM' : 'PM';
    return '$h12:$m $suffix';
  }

  String get _dateLine => '$weekday. $dayOfMonth';

  /// The vanilla needle's own sweep: half a circle (rotation `PI` to
  /// `2*PI`) from 6am to ~2am, clamped at both ends — copied from the
  /// real `adjustedTime`/rotation math in `DayTimeMoneyBox.draw`. Vanilla
  /// runs this on the raw `Game1.timeOfDay` (an hhmm int that keeps
  /// counting past 2400 for post-midnight hours); this mod's snapshot
  /// reports a plain 0-23 `hour24` instead, so hours before 6am are
  /// treated as continuing the previous day (+24) to reproduce the same
  /// up-to-~26:00 range the real formula expects.
  double get _needleRotation {
    final h = hour24 < 6 ? hour24 + 24 : hour24;
    final timeOfDayLike = h * 100 + minute;
    final sweep = ((timeOfDayLike - 600) / 2000).clamp(0.0, 1.0);
    return math.pi + sweep * math.pi;
  }

  @override
  Widget build(BuildContext context) {
    final width = height * _nativeWidth / _nativeHeight;
    final seasonStyle = _SeasonStyle.of(season);

    // Fractions below are all `<real draw offset> / <box's own 284x172
    // render size>` — see the class doc comment.
    const seasonIconRect = _FracRect(left: 212 / 284, top: 68 / 172, width: 48 / 284, height: 32 / 172);
    const weatherIconRect = _FracRect(left: 116 / 284, top: 68 / 172, width: 48 / 284, height: 32 / 172);
    // Needle bounding box before rotation (top-left = anchor - origin*scale),
    // plus where its own pivot sits inside that box (origin (3,17) of a
    // 7x19 sprite).
    const needleRect = _FracRect(left: 76 / 284, top: 20 / 172, width: 28 / 284, height: 76 / 172);
    const needlePivot = Alignment(2 * (3 / 7) - 1, 2 * (17 / 19) - 1);
    // Fraction-of-box position of each text field's own CENTER point
    // (not a Flutter Alignment — see the Positioned/FractionalTranslation
    // pair below for why plain Align can't correctly place these).
    const dateCenterFraction = Offset(183.15 / 284, 43.1 / 172);
    const timeCenterFraction = Offset(183.15 / 284, 133.61 / 172);

    final clockTextStyle = DefaultTextStyle.of(context).style.apply(fontSizeFactor: fontScale, fontWeightDelta: 2);

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: boxUrl != null
                ? Image.network(
                    boxUrl!,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (context, error, stackTrace) => const _ClockBoxFallback(),
                  )
                : const _ClockBoxFallback(),
          ),
          // Positioned + FractionalTranslation(-0.5, -0.5), not Align:
          // Align's single `alignment` value doubles as both "where in
          // the parent" and "which point of the child" using the *same*
          // fraction, so it only truly centers a child when that
          // fraction is (0.5, 0.5) — everywhere else (like these two
          // off-center text fields) it anchors some other point of the
          // child there instead, and that error scales with the
          // child's own size. Since _dateLine/_digital render at
          // different lengths depending on the actual date/time, an
          // Align-based version drifted off the sprite's real text
          // field by a different amount for almost every value. Placing
          // the text's top-left at the target point via Positioned and
          // then translating back by exactly half its own (now-known)
          // rendered size centers it at that point exactly, regardless
          // of string length.
          Positioned(
            left: dateCenterFraction.dx * width,
            top: dateCenterFraction.dy * height,
            child: FractionalTranslation(
              translation: const Offset(-0.5, -0.5),
              child: Text(
                _dateLine,
                // Pixelify Sans (see main.dart) explicitly here rather
                // than relying on inherited DefaultTextStyle — this Text
                // sits at a tiny 8px size where a fallback system font is
                // hard to tell apart from the pixel font by eye, so the
                // font is pinned directly instead of trusting inheritance.
                style: clockTextStyle,
              ),
            ),
          ),
          Positioned(
            left: timeCenterFraction.dx * width,
            top: timeCenterFraction.dy * height,
            child: FractionalTranslation(
              translation: const Offset(-0.5, -0.5),
              child: Text(
                _digital,
                style: clockTextStyle,
              ),
            ),
          ),
          seasonIconRect.positioned(
            box: Size(width, height),
            child: _ClockIcon(icon: seasonStyle.icon, spriteUrl: seasonIconUrl, tooltip: '$season $dayOfMonth'),
          ),
          weatherIconRect.positioned(
            box: Size(width, height),
            child: _ClockIcon(icon: weatherIcon, spriteUrl: weatherIconUrl, tooltip: weatherLabel),
          ),
          needleRect.positioned(
            box: Size(width, height),
            child: Transform.rotate(
              angle: _needleRotation,
              alignment: needlePivot,
              child: needleUrl != null
                  ? Image.network(
                      needleUrl!,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.none,
                      errorBuilder: (context, error, stackTrace) => const _ClockNeedleFallback(),
                    )
                  : const _ClockNeedleFallback(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Per-season Material fallback icon for the [_ClockIcon], used when
/// there's no real `GameClock.seasonIconUrl` sprite (or it fails to
/// load).
class _SeasonStyle {
  const _SeasonStyle({required this.icon});

  final IconData icon;

  static const _bySeason = <String, _SeasonStyle>{
    'Spring': _SeasonStyle(icon: Icons.local_florist),
    'Summer': _SeasonStyle(icon: Icons.wb_sunny),
    'Fall': _SeasonStyle(icon: Icons.eco),
    'Winter': _SeasonStyle(icon: Icons.ac_unit),
  };

  static _SeasonStyle of(String season) =>
      _bySeason[season] ?? const _SeasonStyle(icon: Icons.eco);
}

/// A rectangle expressed as fractions of some other box's size, with a
/// helper to turn itself into a [Positioned] once that box's concrete
/// [Size] is known. Keeps the [GameClock] overlay math (all derived from
/// the real game's pixel offsets) in one small, readable place instead of
/// repeating `left: frac * width` at every call site.
class _FracRect {
  const _FracRect({required this.left, required this.top, required this.width, required this.height});

  final double left;
  final double top;
  final double width;
  final double height;

  Positioned positioned({required Size box, required Widget child}) {
    return Positioned(
      left: left * box.width,
      top: top * box.height,
      width: width * box.width,
      height: height * box.height,
      child: child,
    );
  }
}

/// One of the clock box's own icons (season or weather), drawn directly
/// on the box the way the real game does — no separate circular badge
/// backing, since the box art already reads as the "chrome" around it.
/// Falls back to the equivalent Material icon when there's no sprite URL
/// or it fails to load.
class _ClockIcon extends StatelessWidget {
  const _ClockIcon({required this.icon, this.spriteUrl, required this.tooltip});

  final IconData icon;
  final String? spriteUrl;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: spriteUrl != null
          ? Image.network(
              spriteUrl!,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
              errorBuilder: (context, error, stackTrace) => Icon(icon, size: 16, color: StardewColors.woodDarker),
            )
          : Icon(icon, size: 16, color: StardewColors.woodDarker),
    );
  }
}

/// Flat parchment-and-wood placeholder for the clock box backdrop, shown
/// before a connection is live or if the real sprite fails to load.
class _ClockBoxFallback extends StatelessWidget {
  const _ClockBoxFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: StardewColors.parchmentDark,
        border: Border.all(color: StardewColors.wood, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// Simple static wedge standing in for the real needle sprite — not
/// rotated itself (the `Transform.rotate` wrapping it in [GameClock]
/// still applies), just a plain shape so something reads as "a pointer"
/// before the real sprite is available.
class _ClockNeedleFallback extends StatelessWidget {
  const _ClockNeedleFallback();

  @override
  Widget build(BuildContext context) {
    // Fills the exact (tight) box `Positioned` already sized for the real
    // needle sprite — no Center/Align needed, and nothing to size
    // explicitly, since a childless Container under tight constraints
    // just becomes that box.
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: StardewColors.woodDarker,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
