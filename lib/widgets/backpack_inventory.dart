import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../services/game_connection_service.dart';
import 'draggable_inventory_slot.dart';

const _totalSlots = 36;
const _slotSpacing = 4.0;

/// Wide layout: 12 columns × 3 rows — the default, matching the
/// vanilla inventory menu's own row shape. Used whenever it fits
/// without shrinking slots below [_compactBreakpoint].
const _wideColumns = 12;
const _wideRows = 3;

/// Compact layout: 9 columns × 4 rows — same 36 total slots, just
/// reflowed into a squarer grid than the wide 12×3 layout. Switched to
/// automatically (see [BackpackInventory.resolveLayout]) whenever the
/// wide layout's own slot size would drop below [_compactBreakpoint].
///
/// 9 columns was picked over 6 to stay closer to full width on narrow
/// screens (at ~355px wide, 9x4 comes out ~355px wide vs 6x6's ~262px)
/// — but it trades away comfortable clearance over [_compactBreakpoint]
/// itself: 9x4 lands right around the 36px line rather than safely
/// above it like 6x6 did, and leaves the freed-up height unused instead
/// (nothing currently fills it). If slots end up feeling cramped again,
/// 6 is the safer fallback.
const _compactColumns = 9;
const _compactRows = 4;

/// Below this slot size (px), the wide 12-column layout is considered
/// too cramped and the grid reflows to the compact 9-column layout
/// instead.
///
/// Round 23: doubled from 36 to 72 (user request — "make the minimum
/// slot size twice as big") to push the reflow trigger higher, so slots
/// stay larger/more touch-friendly before the grid switches layouts.
/// On the real AYN Thor screen (1240x1080 @ 1.15 ratio, no
/// devicePixelRatio override — see companion_app_ui.md's "Target
/// hardware" note) the wide layout still resolves to ~82dp slots,
/// comfortably above even this doubled threshold, so this doesn't
/// change anything on the actual device today — it only shifts where
/// the reflow kicks in for smaller windows (e.g. the 355x315dp window
/// the app was originally tested on, which relies on the compact
/// layout).
const _compactBreakpoint = 72.0;

/// The Backpack screen's slot grid: the game's own window border sits
/// one level up now (`CompanionScreen`'s outer `GameWindowBox`), so this
/// widget itself only renders the 36-slot grid — the organize
/// button/clock toolbar is a separate sibling widget (`BackpackToolbar`)
/// that `BackpackScreen` stacks below this one, not a child of this
/// widget any more (see [resolveLayout] for why the two still need to
/// agree on `slotSize`).
///
/// A slot at or beyond `state.backpackSize` (a row not yet purchased) is
/// shown locked, matching the vanilla inventory menu. Tapping an
/// unlocked slot asks the mod to make that item active in-game —
/// mirrored the other way too, so the highlighted slot always reflects
/// what's actually equipped. Long-press-dragging an item onto another
/// unlocked slot swaps the two (see `GameConnectionService.moveItem`).
class BackpackInventory extends StatelessWidget {
  const BackpackInventory({
    super.key,
    required this.connection,
    required this.state,
    required this.columns,
    required this.rows,
    required this.slotSize,
  });

  final GameConnectionService connection;
  final GameState state;

  /// Column/row count and per-slot size, precomputed once by
  /// `BackpackScreen` via [resolveLayout] and handed to both this
  /// widget and the sibling `BackpackToolbar` — see that method's doc
  /// comment for why this can't just be computed independently inside
  /// each widget's own `LayoutBuilder`.
  final int columns;
  final int rows;
  final double slotSize;

  /// The gap `BackpackScreen` leaves between this grid and the
  /// `BackpackToolbar` row below it. Exposed here (rather than left as
  /// a private literal at the `BackpackScreen` call site) because
  /// [resolveLayout] has to reserve the same amount when solving for
  /// `slotSize`, so both places read one number instead of risking two
  /// literals drifting apart.
  static const double spacingBeforeToolbar = 8.0;

  /// The same per-slot gap used between grid cells (see
  /// `SliverGridDelegateWithFixedCrossAxisCount`'s `mainAxisSpacing`/
  /// `crossAxisSpacing` in `build`), exposed publicly so
  /// `BackpackScreen` can compute the grid's own rendered width (to
  /// size `BackpackToolbar` at that same width) without duplicating
  /// this literal.
  static const double slotSpacing = _slotSpacing;

  /// Resolves the grid's own column/row count and per-slot size for the
  /// given [constraints] — same wide-vs-compact breakpoint logic this
  /// widget has always used, just exposed as a public static method
  /// (rather than computed inline in `build`) so `BackpackScreen` can
  /// call it once and hand the *same* `slotSize` to both this widget
  /// and `BackpackToolbar`.
  ///
  /// [toolbarHeightMultiplier] is `BackpackToolbar.heightMultiplier`
  /// (how many slot-heights tall the toolbar row renders, currently
  /// 2x) — passed in rather than imported directly, so this file has no
  /// dependency on `backpack_toolbar.dart` at all: this widget no
  /// longer builds or knows about the toolbar, only that *some* sibling
  /// below it needs `toolbarHeightMultiplier * slotSize` of height plus
  /// [spacingBeforeToolbar] of gap reserved, to avoid the same circular
  /// dependency the original single-widget version had to solve
  /// algebraically (slotSize determines the toolbar's height, but that
  /// height also eats into the space slotSize is computed from).
  static ({int columns, int rows, double slotSize}) resolveLayout(
    BoxConstraints constraints, {
    required double toolbarHeightMultiplier,
  }) {
    final wideSlotSize = _slotSizeFor(constraints, _wideColumns, _wideRows, toolbarHeightMultiplier);
    final useCompact = wideSlotSize < _compactBreakpoint;
    final columns = useCompact ? _compactColumns : _wideColumns;
    final rows = useCompact ? _compactRows : _wideRows;
    final slotSize =
        useCompact ? _slotSizeFor(constraints, columns, rows, toolbarHeightMultiplier) : wideSlotSize;
    return (columns: columns, rows: rows, slotSize: slotSize);
  }

  static double _slotSizeFor(
    BoxConstraints constraints,
    int columns,
    int rows,
    double toolbarHeightMultiplier,
  ) {
    final maxSlotSize = (constraints.maxWidth - (columns - 1) * _slotSpacing) / columns;
    final maxByHeight = (constraints.maxHeight - (rows - 1) * _slotSpacing - spacingBeforeToolbar) /
        (rows + toolbarHeightMultiplier);
    return (maxSlotSize < maxByHeight ? maxSlotSize : maxByHeight).clamp(16.0, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    final frameUrl = connection.slotFrameUrl;
    final selectedFrameUrl = connection.slotSelectedFrameUrl;
    final lockedOverlayUrl = connection.slotLockedOverlayUrl;
    final wateringCanGaugeUrl = connection.wateringCanGaugeUrl;

    final gridWidth = slotSize * columns + (columns - 1) * _slotSpacing;
    final gridHeight = slotSize * rows + (rows - 1) * _slotSpacing;

    // Whichever layout wins, the resolved slotSize can end up bound by
    // either axis depending on screen size, leaving the grid smaller
    // than the space this widget is actually given (e.g. at ~355x310
    // the compact layout is width-bound, close to but not quite 355px
    // wide, with leftover height on this widget's own axis). Center
    // balances that leftover space on both sides, whichever axis it
    // falls on, instead of the grid sitting pinned to a corner.
    return Center(
      child: SizedBox(
        width: gridWidth,
        height: gridHeight,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _totalSlots,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: _slotSpacing,
            crossAxisSpacing: _slotSpacing,
          ),
          itemBuilder: (context, index) {
            final item = index < state.inventory.length ? state.inventory[index] : null;
            final locked = index >= state.backpackSize;

            return DraggableInventorySlot(
              index: index,
              item: item,
              locked: locked,
              selected: !locked && index == state.selectedIndex,
              spriteUrl: item != null ? connection.spriteUrl(item.qualifiedItemId) : null,
              frameUrl: frameUrl,
              selectedFrameUrl: selectedFrameUrl,
              lockedOverlayUrl: lockedOverlayUrl,
              qualityStarUrl: item != null ? connection.qualityStarUrl(item.quality) : null,
              wateringCanGaugeUrl: wateringCanGaugeUrl,
              onTap: locked ? null : () => connection.selectSlot(index),
              onMove: locked ? null : connection.moveItem,
            );
          },
        ),
      ),
    );
  }
}
