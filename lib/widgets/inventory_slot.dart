import 'package:flutter/material.dart';

import '../models/inventory_item.dart';
import '../theme/stardew_colors.dart';

/// A single square backpack slot, drawn with the game's own slot frame
/// (see `GameConnectionService.slotFrameUrl`) and, for a slot beyond the
/// player's current backpack capacity, the same darkened overlay the
/// vanilla inventory menu composites on top at half opacity — plus the
/// item's real sprite, a stack-count badge for stackable items, and a
/// thin water gauge for a Watering Can.
///
/// The currently selected/equipped slot swaps in the real vanilla
/// hotbar's own highlighted-slot frame (`GameConnectionService.
/// slotSelectedFrameUrl` — tile 56 on `Game1.menuTexture`, in place of
/// the normal tile-10 frame, exactly how `Toolbar.draw` does it) instead
/// of drawing a border on top — no fabricated highlight color.
class InventorySlot extends StatelessWidget {
  const InventorySlot({
    super.key,
    required this.item,
    required this.locked,
    this.selected = false,
    this.spriteUrl,
    this.frameUrl,
    this.selectedFrameUrl,
    this.lockedOverlayUrl,
    this.onTap,
  });

  final InventoryItem? item;

  /// True when this slot's index is at/beyond `GameState.backpackSize`
  /// — an unpurchased backpack row that can't hold an item.
  final bool locked;

  /// Whether this is the item currently equipped/active in-game.
  final bool selected;

  /// Real in-game sprite for [item] (`GameConnectionService.spriteUrl`).
  final String? spriteUrl;

  /// Real in-game slot background frame (`GameConnectionService.slotFrameUrl`).
  final String? frameUrl;

  /// Real in-game highlighted-slot frame (`GameConnectionService.slotSelectedFrameUrl`)
  /// — used in place of [frameUrl], not on top of it, when [selected].
  final String? selectedFrameUrl;

  /// Real in-game locked-row overlay (`GameConnectionService.slotLockedOverlayUrl`).
  final String? lockedOverlayUrl;

  final VoidCallback? onTap;

  static const _fallbackFrameDecoration = BoxDecoration(
    color: StardewColors.slotFill,
    border: Border.fromBorderSide(BorderSide(color: StardewColors.slotBorder, width: 2)),
    borderRadius: BorderRadius.all(Radius.circular(4)),
  );

  /// Fallback for the selected slot when [selectedFrameUrl] is null or
  /// fails to load (disconnected, or the mod hasn't rendered it yet) —
  /// only used until then, not a permanent stand-in for the real frame.
  static const _fallbackSelectedFrameDecoration = BoxDecoration(
    color: StardewColors.slotFill,
    border: Border.fromBorderSide(BorderSide(color: StardewColors.accentGreen, width: 2)),
    borderRadius: BorderRadius.all(Radius.circular(4)),
  );

  @override
  Widget build(BuildContext context) {
    final slot = AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _frame(),
              if (locked)
                Opacity(opacity: 0.5, child: _lockedOverlay()),
              if (!locked && item != null)
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: _sprite(),
                ),
              if (!locked && (item?.quantity ?? 0) > 1)
                Positioned(
                  bottom: 1,
                  right: 3,
                  child: _StackCountText('${item!.quantity}'),
                ),
              if (!locked && item?.waterFraction != null)
                Positioned(
                  left: 3,
                  right: 3,
                  bottom: 2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: SizedBox(
                      height: 3,
                      child: LinearProgressIndicator(
                        value: item!.waterFraction,
                        backgroundColor: StardewColors.woodDark.withOpacity(0.4),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF4FA3D1)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (locked || item?.name == null) return slot;
    return Tooltip(message: item!.name, child: slot);
  }

  Widget _frame() {
    // Real vanilla behavior (see the class doc comment): the selected
    // slot's highlighted frame *replaces* the normal frame, it isn't
    // drawn on top of it — so this picks one URL, not both.
    final url = (selected ? selectedFrameUrl : null) ?? frameUrl;
    if (url == null) {
      return DecoratedBox(decoration: selected ? _fallbackSelectedFrameDecoration : _fallbackFrameDecoration);
    }
    return Image.network(
      url,
      fit: BoxFit.fill,
      // Pixel art, not a photo — nearest-neighbor sampling keeps the
      // crop's hard edges instead of blurring them.
      filterQuality: FilterQuality.none,
      errorBuilder: (context, error, stackTrace) =>
          DecoratedBox(decoration: selected ? _fallbackSelectedFrameDecoration : _fallbackFrameDecoration),
    );
  }

  Widget _lockedOverlay() {
    if (lockedOverlayUrl == null) {
      return const DecoratedBox(decoration: BoxDecoration(color: Colors.black));
    }
    return Image.network(
      lockedOverlayUrl!,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
      errorBuilder: (context, error, stackTrace) => const DecoratedBox(decoration: BoxDecoration(color: Colors.black)),
    );
  }

  Widget _sprite() {
    if (spriteUrl == null) return const SizedBox.shrink();
    return Image.network(
      spriteUrl!,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

/// White text with a dark drop shadow — the same look the vanilla game
/// uses for its own stack-count numbers, so it stays readable over any
/// item sprite or background.
class _StackCountText extends StatelessWidget {
  const _StackCountText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        shadows: [Shadow(color: Colors.black87, offset: Offset(1, 1))],
      ),
    );
  }
}
