import 'package:flutter/material.dart';

import '../theme/stardew_colors.dart';

/// The backpack toolbar's organize button, built from scratch instead of
/// [IconButton] — [IconButton] (and Material buttons generally) pad the
/// tap target *outward* from the icon rather than letting the icon fill
/// it, which left visible empty space around the icon no matter what
/// `iconSize` was set to. Here the icon is drawn at exactly [size]
/// (matched to the grid's own slot size by the caller — see
/// `BackpackInventory.build`'s `slotSize` — so the button reads as one
/// more slot rather than an arbitrarily-sized control) with nothing
/// wrapping it — the icon *is* the tap target, no inset.
///
/// On press, the icon itself changes rather than just scaling: a warm
/// highlight tint is blended over the same real in-game sprite
/// (`ColorFiltered`/`BlendMode.srcATop`). Vanilla's own organize button
/// has no separate hover/pressed texture to swap to (confirmed against
/// the decompiled `InventoryPage.cs` — `performHoverAction` only scales
/// the same `Rectangle(162, 440, 16, 16)` icon via
/// `ClickableTextureComponent.tryHover`), so this tint is this app's own
/// pressed-state treatment on the real icon, not a second game asset.
class OrganizeButton extends StatefulWidget {
  const OrganizeButton({
    super.key,
    required this.iconUrl,
    required this.onPressed,
    required this.size,
  });

  final String? iconUrl;
  final VoidCallback onPressed;

  /// Matches the inventory grid's own per-slot size — see
  /// `BackpackInventory.build`.
  final double size;

  @override
  State<OrganizeButton> createState() => _OrganizeButtonState();
}

class _OrganizeButtonState extends State<OrganizeButton> {
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
