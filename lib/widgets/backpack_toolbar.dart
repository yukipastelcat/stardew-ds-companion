import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/stardew_colors.dart';

/// The Backpack screen's bottom control row: the organize button (moved
/// here from `BackpackInventory`, still sized to exactly match a grid
/// slot — see `BackpackInventory.build`'s `slotSize`) on the left, and
/// the real in-game day/time clock on the right (box backdrop, season
/// icon, weather icon, digital date/time, and the single sundial-style
/// needle — see `_GameClock`), sized to [heightMultiplier] times the
/// organize button's own height.
///
/// This whole row now renders *outside* `BackpackInventory`'s own
/// height budget — it's a `Positioned` overlay that deliberately
/// reaches into the ancestor GameWindowBox's padding to sit flush
/// against the box's true bottom edge (see `BackpackInventory.build`'s
/// doc comment) — so growing the clock taller than a single grid slot
/// no longer costs the grid any of its own space.
class BackpackToolbar extends StatelessWidget {
  const BackpackToolbar({
    super.key,
    required this.slotSize,
    required this.organizeIconUrl,
    required this.onOrganize,
    required this.farmName,
    required this.currentFunds,
    this.totalEarnings,
    required this.weekday,
    required this.season,
    required this.dayOfMonth,
    required this.hour24,
    required this.minute,
    required this.weather,
    this.seasonIconUrl,
    this.weatherIconUrl,
    this.clockBoxUrl,
    this.clockNeedleUrl,
  });

  /// Matches the inventory grid's own per-slot size — see
  /// `BackpackInventory.build`.
  final double slotSize;

  final String? organizeIconUrl;
  final VoidCallback onOrganize;

  /// Shown centered between the organize button and the clock — see
  /// `GameState.farmName`/`currentFunds`/`totalEarnings`. [totalEarnings]
  /// is nullable for backwards compat with older mod builds that don't
  /// report it yet (see `GameState.totalEarnings`'s own doc comment).
  final String farmName;
  final int currentFunds;
  final int? totalEarnings;

  final String weekday;
  final String season;
  final int dayOfMonth;
  final int hour24;
  final int minute;
  final String weather;

  /// Real in-game HUD icon URLs (see `GameConnectionService.seasonIconUrl`/
  /// `weatherIconUrl`/`clockBoxUrl`/`clockNeedleUrl`). Null falls back to
  /// flat placeholders/Material icons — see `_GameClock`.
  final String? seasonIconUrl;
  final String? weatherIconUrl;
  final String? clockBoxUrl;
  final String? clockNeedleUrl;

  /// How much taller the clock is than the organize button — "2x of
  /// the sort icon height", per request. Public so `BackpackInventory`
  /// could reference the same ratio if it ever needs to reserve space
  /// for this row again; currently the row is fully self-sized (see the
  /// class doc comment), so nothing outside this file reads it today.
  static const double heightMultiplier = 2.0;

  @override
  Widget build(BuildContext context) {
    final clockHeight = slotSize * heightMultiplier;

    return SizedBox(
      height: clockHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        // Bottom-aligned rather than the Row default (center): the
        // organize button stays at its own [slotSize] height (shorter
        // than the clock, see heightMultiplier above), so this pins it
        // — and the clock's own box art — to the row's bottom edge
        // instead of floating them in the middle of the taller row.
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _OrganizeButton(iconUrl: organizeIconUrl, onPressed: onOrganize, size: slotSize),
          Expanded(
            child: Center(
              child: _FarmSummary(
                farmName: farmName,
                currentFunds: currentFunds,
                totalEarnings: totalEarnings,
              ),
            ),
          ),
          _GameClock(
            weekday: weekday,
            season: season,
            dayOfMonth: dayOfMonth,
            hour24: hour24,
            minute: minute,
            weatherIcon: _weatherIcon(weather),
            weatherLabel: weather,
            seasonIconUrl: seasonIconUrl,
            weatherIconUrl: weatherIconUrl,
            boxUrl: clockBoxUrl,
            needleUrl: clockNeedleUrl,
            height: clockHeight,
          ),
        ],
      ),
    );
  }

  /// Mirrors the vanilla `DayTimeMoneyBox`'s own weather badges —
  /// Material equivalents only, used as the fallback icon before/if the
  /// real [weatherIconUrl] sprite loads.
  static IconData _weatherIcon(String weather) {
    switch (weather) {
      case 'Rainy':
        return Icons.water_drop_outlined;
      case 'Stormy':
        return Icons.thunderstorm_outlined;
      case 'Snowy':
        return Icons.ac_unit;
      case 'Windy':
        return Icons.air;
      default:
        return Icons.wb_sunny_outlined;
    }
  }
}

/// The organize button, built from scratch instead of [IconButton] —
/// [IconButton] (and Material buttons generally) pad the tap target
/// *outward* from the icon rather than letting the icon fill it, which
/// left visible empty space around the icon no matter what `iconSize`
/// was set to. Here the icon is drawn at exactly [size] (matched to the
/// grid's own slot size by the caller — see `BackpackInventory.build`'s
/// `slotSize` — so the button reads as one more slot rather than an
/// arbitrarily-sized control) with nothing wrapping it — the icon *is*
/// the tap target, no inset.
///
/// On press, the icon itself changes rather than just scaling: a warm
/// highlight tint is blended over the same real in-game sprite
/// (`ColorFiltered`/`BlendMode.srcATop`). Vanilla's own organize button
/// has no separate hover/pressed texture to swap to (confirmed against
/// the decompiled `InventoryPage.cs` — `performHoverAction` only scales
/// the same `Rectangle(162, 440, 16, 16)` icon via
/// `ClickableTextureComponent.tryHover`), so this tint is this app's own
/// pressed-state treatment on the real icon, not a second game asset.
/// Farm name, current funds, and lifetime earnings — plain text sitting
/// in the gap between the organize button and the clock. Uses the same
/// pixel font pinned directly (see `_GameClock`'s date/time `Text`s)
/// rather than relying on inherited `DefaultTextStyle`, and `parchment`
/// (not `woodDarker`) since this sits directly on the panel's wood
/// background rather than on the clock's own lighter box art (see
/// `game_nav_bar.dart`'s identical choice for text over wood).
class _FarmSummary extends StatelessWidget {
  const _FarmSummary({
    required this.farmName,
    required this.currentFunds,
    required this.totalEarnings,
  });

  final String farmName;
  final int currentFunds;
  final int? totalEarnings;

  @override
  Widget build(BuildContext context) {
    final nameStyle = GoogleFonts.pixelifySans(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: StardewColors.parchment,
    );
    final lineStyle = DefaultTextStyle.of(context).style.apply(fontSizeFactor: 0.75);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('$farmName Farm', style: lineStyle, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
        Text('Current Funds: $currentFunds', style: lineStyle, textAlign: TextAlign.center),
        Text('Total Earnings: ${totalEarnings ?? 0}', style: lineStyle, textAlign: TextAlign.center),
      ],
    );
  }
}

class _OrganizeButton extends StatefulWidget {
  const _OrganizeButton({required this.iconUrl, required this.onPressed, required this.size});

  final String? iconUrl;
  final VoidCallback onPressed;

  /// Matches the inventory grid's own per-slot size — see
  /// `BackpackInventory.build`.
  final double size;

  @override
  State<_OrganizeButton> createState() => _OrganizeButtonState();
}

class _OrganizeButtonState extends State<_OrganizeButton> {
  static const _pressedTint = Color(0x8DFCE7B8); // StardewColors.parchment at ~55% opacity

  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    Widget icon = widget.iconUrl == null
        ? Icon(Icons.sort, size: widget.size, color: StardewColors.wood)
        : Image.network(
            widget.iconUrl!,
            width: widget.size,
            height: widget.size,
            // Without an explicit fit, Image doesn't stretch to the given
            // width/height when they differ from the source's own pixel
            // size — the real bug behind "the icon is still small": the
            // /icon?name=organize crop is a native 16x16 PNG
            // (UiIconCache.cs's Rectangle(162, 440, 16, 16)), so it was
            // rendering at 16px, centered inside the box, instead of
            // filling it. `contain` scales it up to fill the box (it's
            // square, so this is equivalent to `fill` here) while still
            // respecting the asset's own aspect ratio if that ever
            // changes.
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
            errorBuilder: (context, error, stackTrace) =>
                Icon(Icons.sort, size: widget.size, color: StardewColors.wood),
          );

    if (_pressed) {
      icon = ColorFiltered(
        colorFilter: const ColorFilter.mode(_pressedTint, BlendMode.srcATop),
        child: icon,
      );
    }

    return Tooltip(
      message: 'Organize',
      child: InkWell(
        customBorder: const CircleBorder(),
        // Calls GameConnectionService.organizeBackpack, which asks the
        // mod to run the real in-game organize logic
        // (ItemGrabMenu.organizeItemsInList) — same result as pressing
        // the button in-game. The next state push reflects the new order.
        onTap: widget.onPressed,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        child: SizedBox(width: widget.size, height: widget.size, child: icon),
      ),
    );
  }
}

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
class _GameClock extends StatelessWidget {
  const _GameClock({
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
                style: GoogleFonts.pixelifySans(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: StardewColors.woodDarker,
                ),
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
                style: GoogleFonts.pixelifySans(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: StardewColors.woodDarker,
                ),
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

/// Per-season icon and accent color, for the [_ClockIcon] fallback when
/// there's no real [_GameClock.seasonIconUrl] sprite (or it fails to
/// load).
class _SeasonStyle {
  const _SeasonStyle({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  static const _bySeason = <String, _SeasonStyle>{
    'Spring': _SeasonStyle(icon: Icons.local_florist, color: Color(0xFF7CB342)),
    'Summer': _SeasonStyle(icon: Icons.wb_sunny, color: Color(0xFFF2A93B)),
    'Fall': _SeasonStyle(icon: Icons.eco, color: Color(0xFFC1601E)),
    'Winter': _SeasonStyle(icon: Icons.ac_unit, color: Color(0xFF5B9BD5)),
  };

  static _SeasonStyle of(String season) =>
      _bySeason[season] ?? const _SeasonStyle(icon: Icons.eco, color: StardewColors.wood);
}

/// A rectangle expressed as fractions of some other box's size, with a
/// helper to turn itself into a [Positioned] once that box's concrete
/// [Size] is known. Keeps the `_GameClock` overlay math (all derived from
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
/// rotated itself (the `Transform.rotate` wrapping it in `_GameClock`
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
