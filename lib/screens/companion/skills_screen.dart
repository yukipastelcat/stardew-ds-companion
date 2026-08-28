import 'package:flutter/material.dart';

import '../../services/game_connection_service.dart';
import '../../theme/stardew_colors.dart';
import '../../theme/stardew_fonts.dart';

/// The Skills tab — replaces the old placeholder Journal tab (the
/// Journal itself now opens *in-game*, via the Backpack screen's new
/// Journal button — see `backpack_toolbar.dart`). Repeats the real
/// vanilla Skills page's own layout — player portrait over the real
/// day/night background, name + title, and the five skill rows (skill
/// name, icon, ten-segment level-progress bar — no numeric level, see
/// `_SkillRow`'s own doc comment) — at a scope narrowed to what
/// `GameStateSnapshot` reports and this app's compact screen actually
/// has room for. Verified against the decompiled
/// `StardewValley.Menus.SkillsPage.draw` before writing this (same
/// verify-before-guessing convention as every other real-sprite widget
/// in this app).
///
/// Deliberately NOT reproduced — out of scope for a companion screen at
/// this size, and none of it is in `GameStateSnapshot` yet either: the
/// Luck row (vanilla itself hides it until the Special Charm is found,
/// and still shows "???" even after that until Qi's Walnut Room is
/// cleared), profession badges/milestone stars, the Community Center
/// Junimo tracker, golden walnut/Qi gem counters, the mastery bar,
/// house upgrade level, mine depth, and stardrop count. A future round
/// wanting any of these needs new `GameStateSnapshot`/`UiIconCache`
/// fields first — see mod/README.md's route list.
///
/// Lives inside the game-styled window border `CompanionScreen` already
/// wraps every tab in, so — like `BackpackScreen`/`MapScreen` — this
/// widget doesn't add its own outer `GameWindowBox`.
class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key, required this.connection});

  final GameConnectionService connection;

  static const _skills = [
    _SkillSpec(name: 'Farming', iconKey: 'skill-farming'),
    _SkillSpec(name: 'Mining', iconKey: 'skill-mining'),
    _SkillSpec(name: 'Foraging', iconKey: 'skill-foraging'),
    _SkillSpec(name: 'Fishing', iconKey: 'skill-fishing'),
    _SkillSpec(name: 'Combat', iconKey: 'skill-combat'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: connection,
      builder: (context, _) {
        final state = connection.state;
        if (state == null) {
          return const Center(child: Text('Waiting for game data…'));
        }

        final levelsByName = <String, int>{
          'Farming': state.farmingLevel,
          'Mining': state.miningLevel,
          'Foraging': state.foragingLevel,
          'Fishing': state.fishingLevel,
          'Combat': state.combatLevel,
        };

        // Same day/night swap the clock badge and the Map screen's
        // portrait marker already key off — matches the game's own
        // Game1.timeOfDay >= 1900 check (see companion_screen's clock
        // doc comments / PortraitBackgroundCache.cs).
        final night = state.hour24 >= 19;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PortraitPanel(
              backgroundUrl: connection.portraitBackgroundUrl(night),
              portraitUrl: connection.portraitUrl,
              name: state.playerName,
              title: state.title,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final skill in _skills)
                    _SkillRow(
                      name: skill.name,
                      level: levelsByName[skill.name] ?? 0,
                      iconUrl: connection.iconUrl(skill.iconKey),
                      pipEmptyUrl: connection.iconUrl('pip-empty'),
                      pipFilledUrl: connection.iconUrl('pip-filled'),
                      pipEmptyWideUrl: connection.iconUrl('pip-empty-wide'),
                      pipFilledWideUrl: connection.iconUrl('pip-filled-wide'),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SkillSpec {
  const _SkillSpec({required this.name, required this.iconKey});

  final String name;
  final String iconKey;
}

/// The player's real composited portrait over the real day/night
/// background — same pair of endpoints `MapScreen`'s marker already
/// uses (`GameConnectionService.portraitUrl`/`portraitBackgroundUrl`),
/// shown here at full size instead of a small circular marker, with the
/// player's name and title (`GameState.title`, `Farmer.getTitle()`)
/// underneath — mirrors vanilla's own `SkillsPage.draw`, which draws
/// the background, the composited farmer sprite on top of it, then the
/// name/title text below both.
class _PortraitPanel extends StatelessWidget {
  const _PortraitPanel({
    required this.backgroundUrl,
    required this.portraitUrl,
    required this.name,
    required this.title,
  });

  final String? backgroundUrl;
  final String? portraitUrl;
  final String name;
  final String title;

  // Shrunk from 104x176 — the portrait doesn't need to dominate this
  // compact screen, and the smaller footprint leaves more width for the
  // skill rows' new name labels.
  static const _panelWidth = 76.0;
  static const _panelHeight = 124.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _panelWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: _panelHeight,
            decoration: BoxDecoration(
              color: StardewColors.parchmentDark,
              border: Border.all(color: StardewColors.wood, width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (backgroundUrl != null)
                  Image.network(
                    backgroundUrl!,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: portraitUrl == null
                      ? const Center(
                          child: Icon(Icons.person, size: 34, color: StardewColors.textBrown),
                        )
                      : Image.network(
                          portraitUrl!,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.person, size: 34, color: StardewColors.textBrown),
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name.isEmpty ? '…' : name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: stardewFont(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: StardewColors.textBrown,
            ),
          ),
          if (title.isNotEmpty)
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: stardewFont(fontSize: 10, color: StardewColors.textBrown),
            ),
        ],
      ),
    );
  }
}

/// One skill's row: the skill's name spelled out on the left (so a
/// player doesn't have to already know the five icons by sight), the
/// real skill icon next to it, then the ten-segment level-progress bar
/// filling the rest of the row. No numeric level is shown — the pip
/// bar alone (already the more prominent element, matching vanilla's
/// own layout) is the level indicator now; a future round wanting the
/// exact number back can read `level` from `GameState`, it's still
/// threaded through here for the pip-fill calculation below.
class _SkillRow extends StatelessWidget {
  const _SkillRow({
    required this.name,
    required this.level,
    required this.iconUrl,
    required this.pipEmptyUrl,
    required this.pipFilledUrl,
    required this.pipEmptyWideUrl,
    required this.pipFilledWideUrl,
  });

  final String name;
  final int level;
  final String? iconUrl;
  final String? pipEmptyUrl;
  final String? pipFilledUrl;
  final String? pipEmptyWideUrl;
  final String? pipFilledWideUrl;

  /// Ten pips per skill, matching vanilla's own 0-10 level range —
  /// verified against `SkillsPage.draw`'s `for (int i = 0; i < 10; i++)`
  /// pip loop.
  static const _pipCount = 10;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: stardewFont(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: StardewColors.textBrown,
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 22,
          height: 22,
          child: iconUrl == null
              ? const Icon(Icons.star, size: 18, color: StardewColors.wood)
              : Image.network(
                  iconUrl!,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.star, size: 18, color: StardewColors.wood),
                ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < _pipCount; i++) ...[
                if (i > 0) const SizedBox(width: 1),
                // Every 5th pip (positions 5 and 10 — the level-5/10
                // profession-milestone markers) is wider than the rest,
                // so it gets twice the flex share — verified against
                // SkillsPage.draw's own `(i + 1) % 5 == 0` branch, which
                // swaps in a 14px-wide sprite instead of the usual 8px
                // one at exactly those two positions.
                Expanded(
                  flex: (i + 1) % 5 == 0 ? 2 : 1,
                  child: _Pip(
                    filled: level > i,
                    emptyUrl: (i + 1) % 5 == 0 ? pipEmptyWideUrl : pipEmptyUrl,
                    filledUrl: (i + 1) % 5 == 0 ? pipFilledWideUrl : pipFilledUrl,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One level-progress-bar segment — filled (red) once the skill's level
/// exceeds this pip's position, empty (wood) otherwise. Prefers the
/// real vanilla sprite crop (`UiIconCache`'s `pip-*` entries); falls
/// back to a flat tinted box matching the same fill state if the sprite
/// hasn't loaded (same fallback pattern used throughout this app — see
/// `InventorySlot`'s `_fallbackSelectedFrameDecoration`).
class _Pip extends StatelessWidget {
  const _Pip({required this.filled, required this.emptyUrl, required this.filledUrl});

  final bool filled;
  final String? emptyUrl;
  final String? filledUrl;

  @override
  Widget build(BuildContext context) {
    final url = filled ? filledUrl : emptyUrl;

    Widget fallback() => DecoratedBox(
          decoration: BoxDecoration(
            color: filled ? StardewColors.accentRed : StardewColors.woodDark,
            borderRadius: BorderRadius.circular(1),
          ),
        );

    // Native sprites are 8x9 (or 14x9 for the wide ones) — same
    // width:height ratio either way, so one AspectRatio covers both.
    return AspectRatio(
      aspectRatio: 8 / 9,
      child: url == null
          ? fallback()
          : Image.network(
              url,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
              errorBuilder: (context, error, stackTrace) => fallback(),
            ),
    );
  }
}
