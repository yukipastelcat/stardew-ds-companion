import 'package:flutter/material.dart';

import '../../services/game_connection_service.dart';
import '../../theme/stardew_colors.dart';
import '../../theme/stardew_fonts.dart';

/// The Map tab: the real vanilla world map background
/// (`GameConnectionService.worldMapUrl` — see stardew-ds-mod/WorldMapCache.cs),
/// with the player's current location name shown above it and a small
/// marker (the player's own real mini portrait —
/// `GameConnectionService.miniPortraitUrl`, the exact head+hair-only
/// render vanilla's own `MapPage.drawMiniPortraits` uses) placed over
/// the map at `GameState.mapMarkerX`/`mapMarkerY`.
///
/// Lives inside the game-styled window border `CompanionScreen` already
/// wraps every tab in, so — like `BackpackScreen`/`JournalScreen` —
/// this widget doesn't add its own outer `GameWindowBox`.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key, required this.connection});

  final GameConnectionService connection;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: connection,
      builder: (context, _) {
        final state = connection.state;
        if (state == null) {
          return const Center(child: Text('Waiting for game data…'));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LocationLabel(text: state.locationName),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: AspectRatio(
                  // The real world-map texture (`LooseSprites\map`) has
                  // been 300x180 for years — not re-verified against a
                  // real build here (see stardew-ds/mod/README.md's
                  // "Known risk areas" #8). A slightly-off ratio just
                  // letterboxes the image a little; it doesn't break the
                  // marker placement below, since that's positioned as a
                  // fraction of this same box either way.
                  aspectRatio: 300 / 180,
                  child: _WorldMap(
                    mapUrl: connection.worldMapUrl,
                    portraitUrl: connection.miniPortraitUrl,
                    markerX: state.mapMarkerX,
                    markerY: state.mapMarkerY,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Small parchment pill showing the player's current location name, in
/// the same pixel font the clock/toolbar text uses.
class _LocationLabel extends StatelessWidget {
  const _LocationLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: StardewColors.parchmentDark,
          border: Border.all(color: StardewColors.wood, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text.isEmpty ? '…' : text,
          style: stardewFont(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: StardewColors.textBrown,
          ),
        ),
      ),
    );
  }
}

/// The map image itself plus the player-position marker, if the current
/// location has one (see `GameState.mapMarkerX`'s doc comment for when
/// it's null).
class _WorldMap extends StatelessWidget {
  const _WorldMap({
    required this.mapUrl,
    required this.portraitUrl,
    required this.markerX,
    required this.markerY,
  });

  final String? mapUrl;
  final String? portraitUrl;
  final double? markerX;
  final double? markerY;

  static const _fallbackDecoration = BoxDecoration(
    color: StardewColors.parchment,
    border: Border.fromBorderSide(BorderSide(color: StardewColors.wood, width: 3)),
    borderRadius: BorderRadius.all(Radius.circular(6)),
  );

  @override
  Widget build(BuildContext context) {
    final hasMarker = markerX != null && markerY != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (mapUrl == null)
            const DecoratedBox(decoration: _fallbackDecoration)
          else
            Image.network(
              mapUrl!,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
              errorBuilder: (context, error, stackTrace) =>
                  const DecoratedBox(decoration: _fallbackDecoration),
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : const DecoratedBox(decoration: _fallbackDecoration),
            ),
          if (hasMarker)
            // Alignment's -1..1 axes line up with markerX/markerY's 0..1
            // fractions of this same box — same "position at an exact
            // fraction of the box" approach the clock's date/time text
            // uses (see companion_app_ui.md's round 18 note), just via
            // Align instead of a manual Positioned offset since the
            // marker doesn't need to react to its own rendered size.
            // Clamped to 0..1 first: a marker position at or past the
            // box's edge would otherwise push Align's target outside
            // -1..1, which shoves the marker partway outside this
            // Stack's bounds and lets the surrounding ClipRRect cut it
            // off — clamping keeps it fully visible, pinned to the
            // nearest edge, instead of silently disappearing there.
            Align(
              alignment: Alignment(
                markerX!.clamp(0.0, 1.0) * 2 - 1,
                markerY!.clamp(0.0, 1.0) * 2 - 1,
              ),
              child: _PlayerMarker(portraitUrl: portraitUrl),
            ),
        ],
      ),
    );
  }
}

/// The player's own real mini portrait (head+hair only, no
/// shirt/pants/hat), matching real vanilla's own `MapPage.drawMiniPortraits`
/// exactly — see `GameConnectionService.miniPortraitUrl`.
class _PlayerMarker extends StatelessWidget {
  const _PlayerMarker({required this.portraitUrl});

  final String? portraitUrl;

  // Circular parchment-and-red-ring frame dropped per user request —
  // just the real mini portrait now, sized up (26 -> 44) so it reads
  // clearly against the map's own busy art without needing a ring
  // around it.
  static const _size = 44.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      // `miniPortraitUrl` (mod/MiniPortraitRenderer.cs) is the real
      // vanilla head+hair-only render, not a crop of the full-body
      // `/portrait` image — a plain contain fits it cleanly (earlier
      // versions of this widget used `portraitUrl` and needed an
      // increasingly elaborate derived crop to approximate a face).
      child: portraitUrl == null
          ? const Icon(Icons.person, size: 30, color: StardewColors.textBrown)
          : Image.network(
              portraitUrl!,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.person, size: 30, color: StardewColors.textBrown),
            ),
    );
  }
}
