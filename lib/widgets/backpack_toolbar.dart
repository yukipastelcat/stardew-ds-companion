import 'package:flutter/material.dart';

import 'farm_summary.dart';
import 'game_clock.dart';
import 'journal_button.dart';
import 'organize_button.dart';

/// The Backpack screen's bottom control row, left to right:
///
/// 1. the health/energy bars ([vitals] — `VitalsBars`, built by the
///    caller), bottom-aligned to the clock box's body;
/// 2. the farm name / funds / earnings summary (`FarmSummary`), in a
///    flexible middle cell;
/// 3. the real in-game day/time clock (`GameClock` — box backdrop,
///    season icon, weather icon, digital date/time, sundial needle),
///    sized to [heightMultiplier] times a single button's own height;
/// 4. the organize button and the new Journal button stacked vertically
///    (each sized to exactly match a grid slot — see
///    `BackpackInventory.build`'s `slotSize` — together exactly filling
///    the row's own [heightMultiplier]x-slotSize height, organize on top
///    / journal below).
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
    required this.journalIconUrl,
    required this.journalPulseIconUrl,
    required this.onOpenJournal,
    required this.hasNewQuestActivity,
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
    required this.vitals,
  });

  /// Matches the inventory grid's own per-slot size — see
  /// `BackpackInventory.build`.
  final double slotSize;

  final String? organizeIconUrl;
  final VoidCallback onOrganize;

  /// The real vanilla quest-log button icon (`DayTimeMoneyBox.questButton`
  /// — see `UiIconCache`'s "journal" entry) and its "new activity" pulse
  /// badge ("journal-pulse"). Tapping opens the real in-game Journal
  /// (`QuestLog`) — see `GameConnectionService.openJournal`.
  final String? journalIconUrl;
  final String? journalPulseIconUrl;
  final VoidCallback onOpenJournal;

  /// Mirrors `Farmer.hasNewQuestActivity()` (`GameState.hasNewQuestActivity`)
  /// — while true, the Journal button pulses the same "!" badge the real
  /// in-game quest-log button pulses (`DayTimeMoneyBox.questPulseTimer`).
  final bool hasNewQuestActivity;

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
  /// flat placeholders/Material icons — see `GameClock`.
  final String? seasonIconUrl;
  final String? weatherIconUrl;
  final String? clockBoxUrl;
  final String? clockNeedleUrl;

  /// The health/energy bars (`VitalsBars`), built by the caller since it
  /// owns the `GameConnectionService` / `GameState`. The leftmost cell of
  /// the bottom row, bottom-aligned to the clock box's body — see
  /// [_clockLegFraction] and `build`.
  final Widget vitals;

  /// How much taller the clock is than the organize button — "2x of
  /// the sort icon height", per request. Public so `BackpackInventory`
  /// could reference the same ratio if it ever needs to reserve space
  /// for this row again; currently the row is fully self-sized (see the
  /// class doc comment), so nothing outside this file reads it today.
  static const double heightMultiplier = 2.0;

  /// Both the organize/journal column and the farm-name summary are
  /// nudged up by this many dp (`Transform.translate(Offset(0, -12))`,
  /// below) after being centered in the row — a pre-existing tuning
  /// value, unrelated to the clock, kept here as a named constant so
  /// [_clockSizeBump] (right below) can be derived from it instead of
  /// guessed.
  static const double _rowTopTrim = 12.0;

  /// How much bigger than [heightMultiplier]'s own height the clock
  /// itself renders. [GameClock] is always given this exact same
  /// height as the row, so its top edge sits at the row's own top
  /// (offset 0) regardless of the bump's value. The organize button's
  /// top, by contrast, starts at `_clockSizeBump / 2` (its column is
  /// vertically centered in the taller row) and is then nudged up by
  /// [_rowTopTrim]. Setting `_clockSizeBump / 2 - _rowTopTrim = 0`
  /// solves to `_clockSizeBump = 2 * _rowTopTrim` — the value below —
  /// which is what makes the organize button's top edge land exactly
  /// on the clock's top edge (the request that grew this from an
  /// original flat 12dp, then 24dp, bump into a derived one). The
  /// clock's font size is scaled by the same ratio (see
  /// [GameClock.fontScale]) so the digital date/time text grows along
  /// with the box instead of looking undersized inside it; the
  /// fraction-based centering in [GameClock] already re-centers that
  /// text at whatever size it ends up rendering at, so no separate
  /// alignment fix is needed there.
  ///
  /// NOTE: this aligns the two elements' *bounding boxes*. If the real
  /// clock-box sprite has any transparent margin baked into its own top
  /// edge (a cropped HUD sprite easily can), the visible painted box
  /// will still sit slightly lower than this — that's an asset-level
  /// offset no bounding-box math here can correct; it'd need measuring
  /// the actual sprite.
  static const double _clockSizeBump = 2 * _rowTopTrim;

  /// The vanilla `DayTimeMoneyBox` backdrop sprite
  /// (`Rectangle(333, 431, 71, 43)` — see `ClockCache.cs` and `GameClock`)
  /// has two short peg "legs" baked into the bottom few rows of its 43px
  /// height. The health/energy bars are meant to sit flush with the box's
  /// *body*, above those legs, so they're bottom-aligned to
  /// `clockBottom - _clockLegFraction * clockHeight`. ~3 of 43 source px
  /// by eye off the sprite sheet — confirm visually against the real crop
  /// (`/clock-box`), same "measure the actual sprite" caveat `GameClock`'s
  /// own doc comment raises about transparent margins.
  static const double _clockLegFraction = 3 / 43;

  /// Small horizontal gap between adjacent cells of the bottom row
  /// (bars | farm info | clock | sort/journal).
  static const double _cellGap = 6;

  @override
  Widget build(BuildContext context) {
    final clockHeight = slotSize * heightMultiplier;
    final biggerClockHeight = clockHeight + _clockSizeBump;
    final clockFontScale = biggerClockHeight / clockHeight;
    final vitalsHeight = biggerClockHeight * (1 - _clockLegFraction);

    return SizedBox(
      height: biggerClockHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        // Bottom-aligned rather than the Row default (center): the
        // organize button stays at its own [slotSize] height (shorter
        // than the clock, see heightMultiplier above), so this pins it
        // — and the clock's own box art — to the row's bottom edge
        // instead of floating them in the middle of the taller row.
        crossAxisAlignment: CrossAxisAlignment.center,
        // Left -> right: health bar, energy bar, farm info, clock,
        // sort/journal.
        children: [
          // Health/energy bars. The wrapper is the full row height; a
          // bottom pad of the clock's leg-peg height then leaves exactly
          // `vitalsHeight` for the bars, ending them level with the clock
          // box's body (its art bottom, above the two peg legs) rather
          // than its true bottom edge. `mainAxisSize: min` keeps the
          // Column from trying to fill the (unbounded, in a Row) main
          // axis — the two SizedBoxes already sum to `biggerClockHeight`.
          Padding(
            padding: EdgeInsets.only(right: _cellGap),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: vitalsHeight, child: vitals),
                SizedBox(height: biggerClockHeight * _clockLegFraction),
              ],
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: Offset(0, -_rowTopTrim),
              child: FarmSummary(
                farmName: farmName,
                currentFunds: currentFunds,
                totalEarnings: totalEarnings,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _cellGap),
            child: GameClock(
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
              height: biggerClockHeight,
              fontScale: clockFontScale,
            ),
          ),
          // Organize on top, Journal below — together exactly fill the
          // row's own clockHeight (2x a single slotSize-square button,
          // see heightMultiplier), so spaceBetween pins one to the top
          // edge and the other to the bottom with zero gap between them
          // at the current 2.0 multiplier, and still degrades gracefully
          // (even spacing instead of a hard overlap) if that multiplier
          // is ever changed.
          SizedBox(
            width: slotSize,
            height: clockHeight,
            child: Transform.translate(
              offset: Offset(0, -_rowTopTrim),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OrganizeButton(iconUrl: organizeIconUrl, onPressed: onOrganize, size: slotSize),
                  JournalButton(
                    iconUrl: journalIconUrl,
                    pulseIconUrl: journalPulseIconUrl,
                    onPressed: onOpenJournal,
                    hasNewQuestActivity: hasNewQuestActivity,
                    size: slotSize,
                  ),
                ],
              ),
            ),
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
      case 'Green Rain':
        return Icons.eco_outlined;
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
