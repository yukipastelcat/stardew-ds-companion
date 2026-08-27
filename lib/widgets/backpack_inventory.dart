import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../services/game_connection_service.dart';
import '../theme/stardew_colors.dart';
import 'draggable_inventory_slot.dart';
import 'game_window_box.dart';

const _totalSlots = 36;
const _slotSpacing = 4.0;

/// Wide layout: 12 columns × 3 rows — the default, matching the
/// vanilla inventory menu's own row shape. Used whenever it fits
/// without shrinking slots below [_compactBreakpoint].
const _wideColumns = 12;
const _wideRows = 3;

/// Compact layout: 9 columns × 4 rows — same 36 total slots, just
/// reflowed into a squarer grid than the wide 12×3 layout. Switched to
/// automatically (see `BackpackInventory.build`) whenever the wide
/// layout's own slot size would drop below [_compactBreakpoint].
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
/// too cramped and the grid reflows to the compact 6-column layout
/// instead.
const _compactBreakpoint = 36.0;

/// Everything the Backpack screen shows once connected: the game's own
/// window border/background (see [GameWindowBox]), the slot grid, and
/// the organize button — bundled as one widget so the screen itself
/// only has to handle the "waiting for game data" case.
///
/// A slot at or beyond `state.backpackSize` (a row not yet purchased) is
/// shown locked, matching the vanilla inventory menu. Tapping an
/// unlocked slot asks the mod to make that item active in-game —
/// mirrored the other way too, so the highlighted slot always reflects
/// what's actually equipped. Long-press-dragging an item onto another
/// unlocked slot swaps the two (see `GameConnectionService.moveItem`).
/// The organize button (bottom-right, using the game's own icon) asks
/// the mod to run the real in-game organize logic
/// (`ItemGrabMenu.organizeItemsInList`) — see
/// `GameConnectionService.organizeBackpack`.
class BackpackInventory extends StatelessWidget {
  const BackpackInventory({super.key, required this.connection, required this.state});

  final GameConnectionService connection;
  final GameState state;

  /// The slot size the given (columns, rows) layout would render at
  /// under [constraints] — same algebraic solve `BackpackInventory`
  /// has always used, just parameterized so both the wide and compact
  /// layouts can be tried. The organize button is sized to match a
  /// slot exactly, so it occupies vertical space like one more grid
  /// row — that's the `(rows + 1)` divisor below, chosen specifically
  /// to avoid a circular dependency (slotSize determines the button's
  /// height, but the button's height also eats into the space slotSize
  /// is computed from): (rows+1)*slotSize + (rows-1)*slotSpacing (the
  /// gaps between grid rows) + spacingBeforeButton (the one extra gap
  /// before the button row) == constraints.maxHeight.
  static double _slotSizeFor(BoxConstraints constraints, int columns, int rows, double spacingBeforeButton) {
    final maxSlotSize = (constraints.maxWidth - (columns - 1) * _slotSpacing) / columns;
    final maxByHeight =
        (constraints.maxHeight - (rows - 1) * _slotSpacing - spacingBeforeButton) / (rows + 1);
    return (maxSlotSize < maxByHeight ? maxSlotSize : maxByHeight).clamp(16.0, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    final frameUrl = connection.slotFrameUrl;
    final selectedFrameUrl = connection.slotSelectedFrameUrl;
    final lockedOverlayUrl = connection.slotLockedOverlayUrl;
    final organizeUrl = connection.iconUrl('organize');

    return LayoutBuilder(
        builder: (context, constraints) {
          const spacingBeforeButton = 8.0;

          final wideSlotSize = _slotSizeFor(constraints, _wideColumns, _wideRows, spacingBeforeButton);
          final useCompact = wideSlotSize < _compactBreakpoint;
          final columns = useCompact ? _compactColumns : _wideColumns;
          final rows = useCompact ? _compactRows : _wideRows;
          final slotSize =
              useCompact ? _slotSizeFor(constraints, columns, rows, spacingBeforeButton) : wideSlotSize;
          final gridWidth = slotSize * columns + (columns - 1) * _slotSpacing;
          final gridHeight = slotSize * rows + (rows - 1) * _slotSpacing;

          // Whichever layout wins, the computed slotSize can end up
          // bound by either axis depending on screen size, leaving the
          // grid smaller than the available space on the other axis
          // (e.g. at ~355x310 the compact layout is width-bound, close
          // to but not quite 355px wide, with the leftover height
          // unused). GameWindowBox doesn't center its child (its Stack
          // has no `alignment`, so its Padding-wrapped child sits
          // top-left by default), so without this Center the grid would
          // be pinned to a corner with a visible gap on one side —
          // Center here balances that leftover space on both sides
          // instead, whichever axis it falls on.
          return Center(
            child: SizedBox(
              width: gridWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
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
                          onTap: locked ? null : () => connection.selectSlot(index),
                          onMove: locked ? null : connection.moveItem,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: spacingBeforeButton),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _OrganizeButton(
                      iconUrl: organizeUrl,
                      onPressed: connection.organizeBackpack,
                      size: slotSize,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
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
