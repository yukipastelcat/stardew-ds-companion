import 'package:flutter/material.dart';

import '../theme/stardew_colors.dart';

/// One tab in a [GameNavBar]: a generic Material icon to fall back to,
/// plus the real in-game icon URL to prefer when one is available.
/// [label] is kept for accessibility (exposed via [Semantics]) even
/// though the bar no longer renders it visually — see [GameNavBar]'s
/// doc comment.
class GameNavDestination {
  const GameNavDestination({
    required this.label,
    required this.fallbackIcon,
    this.iconUrl,
    this.portraitOverlayUrl,
  });

  final String label;
  final IconData fallbackIcon;

  /// From `GameConnectionService.iconUrl(name)` — a crop of the game's
  /// own UI spritesheet (see stardew-ds-mod `UiIconCache.cs`). Null when
  /// not connected, in which case [fallbackIcon] is used instead.
  final String? iconUrl;

  /// The player's real mini portrait
  /// (`GameConnectionService.miniPortraitUrl`), composited over
  /// [iconUrl] when set. Only the Skills tab passes this: verified
  /// against decompiled `GameMenu.draw`, vanilla's own "skills" tab icon
  /// (sheetIndex 1, `Rectangle(16, 368, 16, 16)` on Cursors — the exact
  /// crop `UiIconCache`'s `"skills"` entry uses) is just an empty frame
  /// by itself; the game draws the player's own mini portrait
  /// (`FarmerRenderer.drawMiniPortrat`) on top of it separately, which
  /// is why a plain crop of that one tile renders as a hollow border
  /// with nothing inside. `MiniPortraitRenderer.cs` (mod-side) now
  /// renders that exact same call off-screen and serves it as
  /// `GET /mini-portrait` — a real head+hair-only icon, not a cropped
  /// guess off the full-body `/portrait` image (an earlier version of
  /// this reused that instead, and needed an increasingly elaborate
  /// derived crop to approximate a face from it).
  final String? portraitOverlayUrl;
}

/// Top navigation bar: icon-only tabs packed against the left edge
/// (not spread evenly across the full width — see `build` below) with
/// no window-border background and no labels. Per user request this
/// used to be a bottom bar wrapped in a [GameWindowBox] (the in-game
/// window border/background) with an inline label next to each icon
/// and each tab given an even 1/3 of the width; the background and
/// labels were removed, the bar moved from the bottom of the screen to
/// the top, and (this round) the tabs were pulled left and their icons
/// enlarged. Only the icon's own tint (accent red vs brown, see
/// [_GameNavItem]) marks which tab is selected. [buttonHeight] is the
/// tap target's height — bumped `48 → 64` this round so the larger
/// icons fit without overflowing.
class GameNavBar extends StatelessWidget {
  const GameNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
    this.buttonHeight = 56,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<GameNavDestination> destinations;

  final double buttonHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: buttonHeight,
      child: Row(
        // Per user request: tabs no longer each take an even 1/3 of
        // the bar's width (that was the `Expanded` below) — they're
        // now left-aligned, sized to their own content, with a small
        // gap between them so the enlarged icons don't touch.
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 12),
          for (var i = 0; i < destinations.length; i++) ...[
            _GameNavItem(
              destination: destinations[i],
              selected: i == selectedIndex,
              onTap: () => onSelected(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _GameNavItem extends StatelessWidget {
  const _GameNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final GameNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconUrl = destination.iconUrl;
    final fg = selected ? StardewColors.accentRed : StardewColors.textBrown;

    final icon = Stack(
      alignment: Alignment.center,
      children: [
        iconUrl == null
            ? Icon(destination.fallbackIcon, size: 50, color: fg)
            : Image.network(
                iconUrl,
                width: 56,
                height: 56,
                // Same fix as the organize button — without an
                // explicit fit, the native ~16px icon crop
                // rendered at its own pixel size instead of
                // filling this box.
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(destination.fallbackIcon, size: 50, color: fg),
              ),
        if (destination.portraitOverlayUrl != null)
          // Centered on the icon — a plain Stack child, which lines up
          // with the surrounding Stack's own `alignment: Alignment.center`.
          //
          // `destination.portraitOverlayUrl` is
          // `GameConnectionService.miniPortraitUrl` — the real vanilla
          // head+hair-only render (mod/MiniPortraitRenderer.cs, serving
          // the exact `FarmerRenderer.drawMiniPortrat` call vanilla's
          // own Skills tab uses), so this is a plain contain — no
          // derived crop needed, unlike the full-body `/portrait` image
          // this used earlier.
          SizedBox(
            width: 40,
            height: 40,
            child: Image.network(
              destination.portraitOverlayUrl!,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ),
      ],
    );

    return Semantics(
      button: true,
      selected: selected,
      // The visible label was removed (see GameNavBar's doc comment),
      // so it's passed here instead — a screen reader still announces
      // "Backpack"/"Map"/"Skills" for this now icon-only button.
      label: destination.label,
      // Plain GestureDetector, not Material+InkWell — per user
      // request, tapping a tab no longer shows the Material ripple
      // (InkWell's splash/highlight was the only reason this used to
      // need a Material ancestor at all).
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: SizedBox(
            width: 56,
            height: 56,
            // Shifted down 6px while selected — per user request,
            // brought back after round 27 dropped it alongside the
            // label/bottom-alignment removal (it was 4px there,
            // tied to keeping clear of the old window border's
            // bottom edge; now it's just a standalone "pressed in"
            // cue on the selected tab).
            child: selected
                ? Transform.translate(offset: const Offset(0, 4), child: icon)
                : icon,
          ),
        ),
      ),
    );
  }
}
