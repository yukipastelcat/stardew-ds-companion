import 'package:flutter/material.dart';

import '../theme/stardew_colors.dart';

/// A panel wrapper styled after the vanilla game's own 9-slice menu
/// window border (see `GameConnectionService.windowBorderUrl` /
/// `WindowBorderCache.cs` on the mod side) — the same ornate wood-carved
/// box every in-game dialogue/menu uses. Its stretched center tile also
/// serves as the panel's in-game background fill, so this one image
/// gives both the border and the background at once. Falls back to a
/// flat colored border + fill when disconnected or if the crop fails to
/// load.
///
/// The border image is a single 60x60 crop of the game's own texture;
/// [Image.centerSlice] does the same 9-slice stretch the game's own
/// `drawTextureBox` does, so a bordered box of any size reuses the same
/// four corners, four edges, and stretchy center tile.
///
/// This widget is a plain, padding-agnostic frame — it no longer takes
/// a `padding` parameter itself. A caller that wants its content inset
/// from the border wraps `child` in its own padding widget before
/// handing it here (see `CompanionScreenContainer`, which every tab
/// screen under `CompanionScreen` wraps itself in for this).
class GameWindowBox extends StatelessWidget {
  const GameWindowBox({
    super.key,
    required this.child,
    this.borderUrl,
  });

  final Widget child;

  /// From `GameConnectionService.windowBorderUrl`. Null falls back to a
  /// flat parchment box with a solid wood border.
  final String? borderUrl;

  static const _fallbackDecoration = BoxDecoration(
    color: StardewColors.parchment,
    border: Border.fromBorderSide(BorderSide(color: StardewColors.wood, width: 3)),
    borderRadius: BorderRadius.all(Radius.circular(10)),
  );

  @override
  Widget build(BuildContext context) {
    if (borderUrl == null) {
      return Container(decoration: _fallbackDecoration, child: child);
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Image.network(
            borderUrl!,
            centerSlice: const Rect.fromLTWH(20, 20, 20, 20),
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none,
            errorBuilder: (context, error, stackTrace) => const DecoratedBox(decoration: _fallbackDecoration),
          ),
        ),
        child,
      ],
    );
  }
}
