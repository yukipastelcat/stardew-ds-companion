import 'package:flutter/material.dart';

import '../theme/stardew_colors.dart';
import 'game_window_box.dart';

/// One tab in a [GameNavBar]: a label shown inline next to the icon, a
/// generic Material icon to fall back to, and the real in-game icon URL
/// to prefer when one is available.
class GameNavDestination {
  const GameNavDestination({
    required this.label,
    required this.fallbackIcon,
    this.iconUrl,
  });

  final String label;
  final IconData fallbackIcon;

  /// From `GameConnectionService.iconUrl(name)` — a crop of the game's
  /// own UI spritesheet (see stardew-ds-mod `UiIconCache.cs`). Null when
  /// not connected, in which case [fallbackIcon] is used instead.
  final String? iconUrl;
}

/// Bottom navigation bar styled after the game's own menu windows: the
/// whole bar sits inside one [GameWindowBox] (the same 9-slice in-game
/// border used by the Backpack panel) rather than each button carrying
/// its own border — this bar is always on screen once connected (the
/// idle screen is the only state it's absent from), so it earns the
/// same polished frame as any other panel. Inside the frame the three
/// destinations sit flush against each other with no gap, each getting
/// an even 1/3 of the width via [Expanded]; only the fill color (and
/// the icon/label inside) marks which tab is selected. [buttonHeight]
/// is the actual tap target size — defaults to 48, the standard
/// Material minimum touch target — with the window border's own
/// padding added on top of that for the frame.
class GameNavBar extends StatelessWidget {
  const GameNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
    this.borderUrl,
    this.buttonHeight = 48,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<GameNavDestination> destinations;

  /// From `GameConnectionService.windowBorderUrl`. Null falls back to
  /// [GameWindowBox]'s flat parchment-and-wood box.
  final String? borderUrl;

  final double buttonHeight;

  @override
  Widget build(BuildContext context) {
    return GameWindowBox(
      borderUrl: borderUrl,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: SizedBox(
        height: buttonHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < destinations.length; i++)
              Expanded(
                child: _GameNavItem(
                  destination: destinations[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
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

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: iconUrl == null
                      ? Icon(destination.fallbackIcon, size: 18, color: fg)
                      : Image.network(
                          iconUrl,
                          width: 20,
                          height: 20,
                          // Same fix as the organize button — without an
                          // explicit fit, the native ~16px icon crop
                          // rendered at its own pixel size instead of
                          // filling this 20x20 box.
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(destination.fallbackIcon, size: 18, color: fg),
                        ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    destination.label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
