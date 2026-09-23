import 'package:flutter/material.dart';

import '../../models/game_state.dart';
import '../../services/game_connection_service.dart';
import '../../theme/stardew_colors.dart';
import '../../theme/stardew_fonts.dart';
import '../../widgets/companion_screen_container.dart';

/// The Skills tab — replaces the old placeholder Journal tab (the
/// Journal itself now opens *in-game*, via the Backpack screen's new
/// Journal button — see `backpack_toolbar.dart`). Repeats the real
/// vanilla Skills page's own layout, verified against the decompiled
/// 1.6 `StardewValley.Menus.SkillsPage.draw` (same verify-before-
/// guessing convention as every other real-sprite widget in this app):
///
/// - Top half: player portrait over the real day/night background, name
///   + title, and the five skill rows (skill name right-aligned against
///   its icon and ten-segment level-progress bar — no numeric level, see
///   `_SkillRow`'s own doc comment).
/// - A horizontal rule, then the bottom half: the Community Center room
///   tracker on the left (only once the Meet the Wizard quest is done —
///   a locked placeholder before that, Joja variants on the Joja route),
///   a vertical rule, then the mastery bar above a row of farmhouse
///   level, deepest Mines/Skull Cavern floor and Stardrops found. The
///   Feast of the Winter Star secret friend takes the bottom-right
///   corner while vanilla shows it (winter 18 until the feast).
///
/// Deliberately NOT reproduced: the Luck row (vanilla itself hides it
/// until the Special Charm is found), profession badges, golden
/// walnut/Qi gem counters, and the purely decorative seasonal doodle.
///
/// Everything in the bottom half defaults to its "nothing to show" state
/// against an older mod build that doesn't report those fields yet (see
/// `GameState`'s "Skills screen extras").
///
/// Lives inside the game-styled window border `CompanionScreen` already
/// wraps every tab in, so — like `BackpackScreen`/`MapScreen` — this
/// widget doesn't add its own outer `GameWindowBox`; it wraps its own
/// content in `CompanionScreenContainer` instead for the standard tab
/// inset (`AnimalsScreen` wraps itself in it too, but with
/// `hasPadding: false` — see that screen's own doc comment).
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
    return CompanionScreenContainer(
      child: ListenableBuilder(
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

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                ),
              ),
              const SizedBox(height: 8),
              const _Rule.horizontal(),
              const SizedBox(height: 8),
              Expanded(
                flex: 3,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CommunityCenterTracker(state: state, connection: connection),
                    const SizedBox(width: 12),
                    const _Rule.vertical(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _MasteryRow(state: state, connection: connection),
                          _StatsRow(state: state, connection: connection),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
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

  // Widened from 76 (issue stardew-ds#10) — closer to vanilla's own
  // 2:3 portrait box. The height now follows the top half of the screen
  // (the image box is `Expanded`) instead of a fixed 124, since the
  // bottom half shares the screen with it.
  static const _panelWidth = 96.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _panelWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
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
          ),
          const SizedBox(height: 6),
          Text(
            name.isEmpty ? '…' : name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: stardewFont(
              fontSize: 16,
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
              style: stardewFont(fontSize: 13, color: StardewColors.textBrown),
            ),
        ],
      ),
    );
  }
}

/// One skill's row: the skill's name spelled out (so a player doesn't
/// have to already know the five icons by sight), right-aligned so it
/// sits flush against the real skill icon and the ten-segment
/// level-progress bar after it — the same arrangement as vanilla's
/// `SkillsPage.draw`, which draws each name at `x - MeasureString(skill).X`
/// so it ends right where the icon starts. The bar is a fixed size
/// (pips are [_pipHeight] tall at their native 8x9/14x9 proportions)
/// rather than stretching to fill the row. No numeric level is shown — the pip
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

  /// Pip height; widths follow the native sprite proportions (8x9, or
  /// 14x9 for the 5th/10th), with a 1px native gap between pips —
  /// vanilla's 9px pitch at the same scale.
  static const _pipHeight = 14.0;
  static const _pipScale = _pipHeight / 9;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: stardewFont(
              fontSize: 15,
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
        Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _pipCount; i++) ...[
                if (i > 0) const SizedBox(width: _pipScale),
                // Every 5th pip (positions 5 and 10 — the level-5/10
                // profession-milestone markers) is wider than the rest
                // — verified against SkillsPage.draw's own
                // `(i + 1) % 5 == 0` branch, which swaps in a 14px-wide
                // sprite instead of the usual 8px one at exactly those
                // two positions.
                SizedBox(
                  width: ((i + 1) % 5 == 0 ? 14 : 8) * _pipScale,
                  height: _pipHeight,
                  child: _Pip(
                    filled: level > i,
                    emptyUrl: (i + 1) % 5 == 0 ? pipEmptyWideUrl : pipEmptyUrl,
                    filledUrl: (i + 1) % 5 == 0 ? pipFilledWideUrl : pipFilledUrl,
                  ),
                ),
              ],
            ],
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

    // Sized by `_SkillRow` to the sprite's native proportions.
    return SizedBox.expand(
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

/// Vanilla's own divider color for the Skills page's horizontal and
/// vertical rules — `new Color(214, 143, 84)` in `SkillsPage.draw`.
const _ruleColor = Color(0xFFD68F54);

/// Vanilla's own purple for the Stardrop count once all 7 are found —
/// `new Color(160, 30, 235)` in `SkillsPage.draw`.
const _allStardropsColor = Color(0xFFA01EEB);

/// The 4px (at vanilla's 4x scale, so a thin line here) rules that
/// split the Skills page into its skill-rows half and its stats half,
/// and the stats half into the Community Center tracker and the rest.
class _Rule extends StatelessWidget {
  const _Rule.horizontal() : _vertical = false;
  const _Rule.vertical() : _vertical = true;

  final bool _vertical;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _vertical ? 2 : null,
      height: _vertical ? null : 2,
      child: const ColoredBox(color: _ruleColor),
    );
  }
}

/// One of the mod's `/icon` sprite crops, drawn pixel-crisp at whatever
/// size its parent gives it — nothing at all if the icon isn't
/// available (not connected, or an older mod build that doesn't crop it
/// yet), so the layout around it doesn't shift.
class _Sprite extends StatelessWidget {
  const _Sprite(this.url);

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null) return const SizedBox.shrink();
    return Image.network(
      url!,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

/// The Community Center room tracker from the bottom-left of vanilla's
/// Skills page, laid out in the same native-pixel coordinates
/// `SkillsPage.draw` uses (its 4x-scaled offsets divided by 4, relative
/// to the 52x48 box the Joja/locked panels fill) and scaled up to fit:
/// six room stars around a ring — Bulletin Board on top, Boiler Room and
/// Vault on the right, Crafts Room and Fish Tank on the left, Pantry at
/// the bottom — filled once that room is restored.
///
/// Before the Meet the Wizard quest (`GameState.communityCenterUnlocked`
/// false) vanilla draws a locked placeholder panel instead. On the Joja
/// route the stars switch to their Joja variants and a Joja panel covers
/// the Bulletin Board slot; once every room is restored the Junimo way,
/// a Junimo stands in the middle.
class _CommunityCenterTracker extends StatelessWidget {
  const _CommunityCenterTracker({required this.state, required this.connection});

  final GameState state;
  final GameConnectionService connection;

  static const _boxWidth = 52.0;
  static const _boxHeight = 48.0;

  /// Native-pixel top-left of each room's 11x11 star, indexed by vanilla
  /// area number (0 Pantry, 1 Crafts Room, 2 Fish Tank, 3 Boiler Room,
  /// 4 Vault, 5 Bulletin Board) — `SkillsPage.draw`'s `(x ± 60, y + 28)`
  /// etc. offsets, divided by 4, shifted by the panel's `(x - 80, y - 16)`
  /// origin.
  static const _starPositions = [
    Offset(20, 34),
    Offset(5, 11),
    Offset(5, 26),
    Offset(35, 11),
    Offset(35, 26),
    Offset(20, 4),
  ];

  static const _areaNames = [
    'Pantry',
    'Crafts Room',
    'Fish Tank',
    'Boiler Room',
    'Vault',
    'Bulletin Board',
  ];

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (!state.communityCenterUnlocked) {
      children.add(Positioned(
        left: 0,
        top: 0,
        width: 52,
        height: 47,
        child: _Sprite(connection.iconUrl('cc-locked')),
      ));
    } else {
      final joja = state.isJojaMember;
      if (joja) {
        children.add(Positioned(
          left: 0,
          top: 0,
          width: 51,
          height: 48,
          child: _Sprite(connection.iconUrl('cc-joja')),
        ));
      }
      for (var area = 0; area < _starPositions.length; area++) {
        // The Joja panel takes the Bulletin Board's slot outright.
        if (joja && area == 5) continue;
        final done = area < state.communityCenterAreas.length && state.communityCenterAreas[area];
        final key = 'cc-area-${done ? 'complete' : 'incomplete'}${joja ? '-joja' : ''}';
        children.add(Positioned(
          left: _starPositions[area].dx,
          top: _starPositions[area].dy,
          width: 11,
          height: 11,
          child: Tooltip(
            message: _areaNames[area],
            child: _Sprite(connection.iconUrl(key)),
          ),
        ));
      }
      if (state.communityCenterComplete) {
        // Drawn centered on (x + 26, y + 82) at 4x with a 7.5px origin.
        children.add(Positioned(
          left: 19,
          top: 17,
          width: 13,
          height: 15,
          child: _Sprite(connection.iconUrl('cc-junimo')),
        ));
      }
    }

    return AspectRatio(
      aspectRatio: _boxWidth / _boxHeight,
      child: FittedBox(
        child: SizedBox(
          width: _boxWidth,
          height: _boxHeight,
          child: Stack(children: children),
        ),
      ),
    );
  }
}

/// The mastery bar: localized "Mastery" label, the mastery icon, then a
/// progress bar toward the next mastery level and the current level
/// number — mirrors `SkillsPage.draw` + `MasteryTrackerMenu.drawBar`
/// (a brown trough, green fill; vanilla only greys the fill out at
/// level 5 on the full-size Mastery menu, not on the Skills page). Until
/// the player earns any mastery exp, vanilla draws a locked banner in
/// its place instead.
class _MasteryRow extends StatelessWidget {
  const _MasteryRow({required this.state, required this.connection});

  final GameState state;
  final GameConnectionService connection;

  static const _height = 22.0;

  // MasteryTrackerMenu.drawBar's colors.
  static const _trough = Color(0xFFAD814F);
  static const _troughEdge = Color(0xFF3C3C19);
  static const _fill = Color(0xFF00713E);
  static const _fillLight = Color(0xFF3CB450);

  @override
  Widget build(BuildContext context) {
    if (!state.masteryUnlocked) {
      return Tooltip(
        message: 'Mastery (locked)',
        child: SizedBox(
          height: _height,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AspectRatio(
              aspectRatio: 142 / 12,
              child: _Sprite(connection.iconUrl('mastery-locked')),
            ),
          ),
        ),
      );
    }

    final label = state.masteryLabel.isEmpty ? 'Mastery' : state.masteryLabel;
    final progressText = state.masteryLevel >= 5
        ? 'Max'
        : '${state.masteryExpIntoLevel}/${state.masteryExpForNextLevel}';

    return SizedBox(
      height: _height,
      child: Row(
        children: [
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _statStyle),
          ),
          const SizedBox(width: 6),
          SizedBox.square(dimension: _height, child: _Sprite(connection.iconUrl('mastery'))),
          const SizedBox(width: 6),
          Expanded(
            child: Tooltip(
              message: progressText,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _trough,
                  border: Border.all(color: _troughEdge, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: state.masteryProgress.clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: _fill,
                          border: Border(top: BorderSide(color: _fillLight, width: 2)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${state.masteryLevel}', style: _statStyle),
        ],
      ),
    );
  }
}

TextStyle get _statStyle => stardewFont(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: StardewColors.textBrown,
    );

/// The bottom row of vanilla's Skills page: farmhouse level, deepest
/// floor reached, Stardrops found — and, in the bottom-right corner,
/// the Feast of the Winter Star secret friend while vanilla shows them.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.state, required this.connection});

  final GameState state;
  final GameConnectionService connection;

  static const _iconSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final houseLabel = state.houseLevelLabel.isEmpty
        ? 'Level ${state.houseUpgradeLevel + 1}'
        : state.houseLevelLabel;

    // Vanilla shows the Skull Cavern floor instead of the Mines floor
    // once the player's been below the Mines, marked with a skull; no
    // number at all before the first floor.
    final inSkullCavern = state.deepestSkullCavernLevel > 0;
    final floor = inSkullCavern ? state.deepestSkullCavernLevel : state.deepestMineLevel;

    final secretFriend = state.secretFriendName;

    // The three stats shrink to fit rather than overflow on a narrow
    // screen; the secret friend keeps its size in the corner.
    return Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
        Tooltip(
          message: 'Farmhouse',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(dimension: _iconSize, child: _Sprite(connection.iconUrl('house'))),
              const SizedBox(width: 4),
              Text(houseLabel, style: _statStyle),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Tooltip(
          message: inSkullCavern ? 'Deepest Skull Cavern floor' : 'Deepest mine floor',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: _iconSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: _Sprite(connection.iconUrl(floor == 0 ? 'mine-level-none' : 'mine-level')),
                    ),
                    if (inSkullCavern)
                      // 8x9 skull at (+8, +6) native px over the 13x13 ladder.
                      Positioned(
                        left: _iconSize * 8 / 13,
                        top: _iconSize * 6 / 13,
                        width: _iconSize * 8 / 13,
                        height: _iconSize * 9 / 13,
                        child: _Sprite(connection.iconUrl('skull-cavern')),
                      ),
                  ],
                ),
              ),
              if (floor != 0) ...[
                const SizedBox(width: 4),
                Text('$floor', style: _statStyle),
              ],
            ],
          ),
        ),
        const SizedBox(width: 14),
        Tooltip(
          message: 'Stardrops found',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: _iconSize * 12 / 14,
                height: _iconSize,
                child: _Sprite(connection.iconUrl(state.stardropsFound > 0 ? 'stardrop' : 'stardrop-none')),
              ),
              if (state.stardropsFound > 0) ...[
                const SizedBox(width: 4),
                Text(
                  'x ${state.stardropsFound}',
                  style: _statStyle.copyWith(
                    color: state.stardropsFound >= 7 ? _allStardropsColor : null,
                  ),
                ),
              ],
            ],
          ),
        ),
              ],
            ),
          ),
        ),
        if (secretFriend != null) ...[
          const SizedBox(width: 8),
          _SecretFriend(
            name: secretFriend,
            mugshotUrl: connection.secretFriendUrl,
            giftUrl: connection.iconUrl('secret-friend-gift'),
          ),
        ],
      ],
    );
  }
}

/// The Feast of the Winter Star secret friend: their mugshot (in their
/// winter outfit where they have one) with vanilla's little gift box
/// over its bottom-right corner — `SkillsPage.draw` draws the 10x11 box
/// at (+64, +40) over the 16x19 mugshot at 4x.
class _SecretFriend extends StatelessWidget {
  const _SecretFriend({required this.name, required this.mugshotUrl, required this.giftUrl});

  final String name;
  final String? mugshotUrl;
  final String? giftUrl;

  static const _scale = 2.0;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Secret friend: $name',
      child: SizedBox(
        width: 26 * _scale,
        height: 21 * _scale,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: 16 * _scale,
              height: 19 * _scale,
              child: _Sprite(mugshotUrl),
            ),
            Positioned(
              left: 16 * _scale,
              top: 10 * _scale,
              width: 10 * _scale,
              height: 11 * _scale,
              child: _Sprite(giftUrl),
            ),
          ],
        ),
      ),
    );
  }
}
