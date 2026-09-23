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
///   + title, Golden Walnut / Qi Gem counters, and the five skill rows
///   (skill name right-aligned against its icon, the ten-segment
///   level-progress bar, and the level in vanilla's NumberSprite digits).
/// - A horizontal rule, then the bottom half: the Community Center room
///   tracker on the left (only once the Meet the Wizard quest is done —
///   a locked placeholder before that, Joja variants on the Joja route),
///   a vertical rule, then the mastery bar above a row of farmhouse
///   level, deepest Mines/Skull Cavern floor and Stardrops found. The
///   bottom-right corner holds vanilla's seasonal doodle, with the Feast
///   of the Winter Star secret friend over it while vanilla shows them
///   (winter 18 until the feast).
///
/// Deliberately NOT reproduced: the Luck row (vanilla itself hides it
/// until the Special Charm is found) and profession badges.
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
                      goldenWalnuts: state.goldenWalnuts,
                      qiGems: state.qiGems,
                      walnutIconUrl: connection.iconUrl('golden-walnut'),
                      qiGemIconUrl: connection.iconUrl('qi-gem'),
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
                              buffed: state.buffedSkills.contains(skill.name.toLowerCase()),
                              connection: connection,
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
/// background, with their name, title and Golden Walnut / Qi Gem
/// counters underneath — mirrors vanilla's own `SkillsPage.draw`.
///
/// The background (`Game1.daybg`/`nightbg`, 128x192) already carries its
/// own frame, so it's drawn as-is at its native 2:3 proportions rather
/// than inside an extra border and cropped to fill. The farmer sits where
/// SkillsPage puts it relative to that background: the mod's 80x144
/// portrait canvas (see PortraitRenderer.cs — the farmer drawn at (8, 8)
/// inside it) lands at (24, 24) in background pixels, since SkillsPage
/// draws the farmer 32px right of and 32px below the background's
/// top-left.
class _PortraitPanel extends StatelessWidget {
  const _PortraitPanel({
    required this.backgroundUrl,
    required this.portraitUrl,
    required this.name,
    required this.title,
    required this.goldenWalnuts,
    required this.qiGems,
    required this.walnutIconUrl,
    required this.qiGemIconUrl,
  });

  final String? backgroundUrl;
  final String? portraitUrl;
  final String name;
  final String title;
  final int goldenWalnuts;
  final int qiGems;
  final String? walnutIconUrl;
  final String? qiGemIconUrl;

  static const _panelWidth = 96.0;

  static const _bgWidth = 128.0;
  static const _bgHeight = 192.0;

  @override
  Widget build(BuildContext context) {
    final textStyle = stardewFont(fontSize: 16, color: StardewColors.textBrown);

    Widget counter(String? iconUrl, int count) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(dimension: 20, child: _Sprite(iconUrl)),
            const SizedBox(width: 4),
            Text('$count', style: textStyle),
          ],
        );

    return SizedBox(
      width: _panelWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: AspectRatio(
            aspectRatio: _bgWidth / _bgHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final k = constraints.maxWidth / _bgWidth;
                return Stack(
                  children: [
                    Positioned.fill(child: _Sprite(backgroundUrl)),
                    Positioned(
                      left: 24 * k,
                      top: 24 * k,
                      width: 80 * k,
                      height: 144 * k,
                      child: portraitUrl == null
                          ? const Icon(Icons.person, size: 34, color: StardewColors.textBrown)
                          : _Sprite(portraitUrl),
                    ),
                  ],
                );
              },
            ),
          ),
          ),
          const SizedBox(height: 4),
          Text(
            name.isEmpty ? '…' : name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
          if (title.isNotEmpty)
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textStyle,
            ),
          if (goldenWalnuts > 0 || qiGems > 0) ...[
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                if (goldenWalnuts > 0) counter(walnutIconUrl, goldenWalnuts),
                if (qiGems > 0) counter(qiGemIconUrl, qiGems),
              ],
            ),
          ],
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
/// (pips at their native 8x9/14x9 proportions, up to [_maxPipScale])
/// rather than stretching to fill the row, followed by the level number
/// in vanilla's own NumberSprite digits (green while a buff is raising
/// the level, as in `SkillsPage.draw`).
class _SkillRow extends StatelessWidget {
  const _SkillRow({
    required this.name,
    required this.level,
    required this.iconUrl,
    required this.pipEmptyUrl,
    required this.pipFilledUrl,
    required this.pipEmptyWideUrl,
    required this.pipFilledWideUrl,
    required this.buffed,
    required this.connection,
  });

  final String name;
  final int level;
  final String? iconUrl;
  final String? pipEmptyUrl;
  final String? pipFilledUrl;
  final String? pipEmptyWideUrl;
  final String? pipFilledWideUrl;
  final bool buffed;
  final GameConnectionService connection;

  /// Ten pips per skill, matching vanilla's own 0-10 level range —
  /// verified against `SkillsPage.draw`'s `for (int i = 0; i < 10; i++)`
  /// pip loop.
  static const _pipCount = 10;

  /// Screen px per native pip px (so pips are at most 14px tall). Pip
  /// widths follow the native sprite proportions (8x9, or 14x9 for the
  /// 5th/10th), with a 1px native gap between pips — vanilla's 9px
  /// pitch at the same scale. Shrinks on narrow screens so the name
  /// keeps at least [_minNameShare] of the row.
  static const _maxPipScale = 14.0 / 9;
  static const _minNameShare = 0.25;

  /// Native width of the ten pips plus their gaps (8 * 8 + 2 * 14 + 9),
  /// and of the two-digit level number box.
  static const _pipsNativeWidth = 101.0;
  static final _numberNativeWidth = _NumberSprite.widthFor(2, 1);

  /// Icon (22) plus the three 6px gaps around it and the number.
  static const _fixedWidth = 22.0 + 6 * 3;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final available = constraints.maxWidth * (1 - _minNameShare) - _fixedWidth;
      final pipScale =
          (available / (_pipsNativeWidth + _numberNativeWidth)).clamp(0.5, _maxPipScale).toDouble();
      return _build(pipScale);
    });
  }

  Widget _build(double pipScale) {
    final pipHeight = 9 * pipScale;
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: stardewFont(fontSize: 16, color: StardewColors.textBrown),
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
                if (i > 0) SizedBox(width: pipScale),
                // Every 5th pip (positions 5 and 10 — the level-5/10
                // profession-milestone markers) is wider than the rest
                // — verified against SkillsPage.draw's own
                // `(i + 1) % 5 == 0` branch, which swaps in a 14px-wide
                // sprite instead of the usual 8px one at exactly those
                // two positions.
                SizedBox(
                  width: ((i + 1) % 5 == 0 ? 14 : 8) * pipScale,
                  height: pipHeight,
                  child: _Pip(
                    filled: level > i,
                    emptyUrl: (i + 1) % 5 == 0 ? pipEmptyWideUrl : pipEmptyUrl,
                    filledUrl: (i + 1) % 5 == 0 ? pipFilledWideUrl : pipFilledUrl,
                  ),
                ),
              ],
            ],
        ),
        const SizedBox(width: 6),
        // Fixed two-digit-wide box, right-aligned like NumberSprite (which
        // draws right to left from its position), so the bars line up.
        SizedBox(
          width: _NumberSprite.widthFor(2, pipScale),
          child: Align(
            alignment: Alignment.centerRight,
            child: _NumberSprite(
              number: level,
              scale: pipScale,
              color: buffed ? _buffedLevelColor : _levelColor,
              opacity: level == 0 ? 0.75 : 1,
              connection: connection,
            ),
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
    final progressText = '${state.masteryExpIntoLevel}/${state.masteryExpForNextLevel}';

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
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _trough,
                border: Border.all(color: _troughEdge, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Align(
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
                    // drawBar's "N/M" text, centered on the bar in 75%
                    // white; vanilla drops it at level 5.
                    if (state.masteryLevel < 5)
                      Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            progressText,
                            style: stardewFont(fontSize: 14, color: Colors.white.withValues(alpha: 0.75)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _NumberSprite(
            number: state.masteryLevel,
            scale: _height / 9,
            color: _levelColor,
            opacity: state.masteryLevel == 0 ? 0.75 : 1,
            connection: connection,
          ),
        ],
      ),
    );
  }
}

TextStyle get _statStyle => stardewFont(fontSize: 16, color: StardewColors.textBrown);

/// The bottom row of vanilla's Skills page: farmhouse level, deepest
/// floor reached, Stardrops found — and, in the bottom-right corner,
/// the Feast of the Winter Star secret friend while vanilla shows them.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.state, required this.connection});

  final GameState state;
  final GameConnectionService connection;

  static const _iconSize = 24.0;

  /// Scale for the bottom-right doodle / secret friend, in screen px per
  /// native sprite px.
  static const _cornerScale = 1.5;

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
        // Bottom-right corner: vanilla's seasonal doodle (33x23 native),
        // with the Winter Star secret friend drawn over its right side
        // while they're shown — SkillsPage puts the doodle at x + 144 and
        // the mugshot at x + 180 (9 native px further right).
        const SizedBox(width: 8),
        SizedBox(
          width: 42 * _cornerScale,
          height: 23 * _cornerScale,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (state.doodleIcon.isNotEmpty)
                Positioned(
                  left: 0,
                  top: 0,
                  width: 33 * _cornerScale,
                  height: 23 * _cornerScale,
                  child: _Sprite(connection.iconUrl(state.doodleIcon)),
                ),
              if (secretFriend != null)
                Positioned(
                  left: 9 * _cornerScale,
                  top: 5 * _cornerScale,
                  child: _SecretFriend(
                    name: secretFriend,
                    mugshotUrl: connection.secretFriendUrl,
                    giftUrl: connection.iconUrl('secret-friend-gift'),
                    scale: _cornerScale,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The Feast of the Winter Star secret friend: their mugshot (in their
/// winter outfit where they have one) with vanilla's little gift box
/// over its bottom-right corner — `SkillsPage.draw` draws the 10x11 box
/// at (+64, +40) over the 16x19 mugshot at 4x.
class _SecretFriend extends StatelessWidget {
  const _SecretFriend({required this.name, required this.mugshotUrl, required this.giftUrl, required this.scale});

  final String name;
  final String? mugshotUrl;
  final String? giftUrl;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Secret friend: $name',
      child: SizedBox(
        width: 26 * scale,
        height: 21 * scale,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: 16 * scale,
              height: 19 * scale,
              child: _Sprite(mugshotUrl),
            ),
            Positioned(
              left: 16 * scale,
              top: 10 * scale,
              width: 10 * scale,
              height: 11 * scale,
              child: _Sprite(giftUrl),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vanilla's level-number tints — `Color.SandyBrown`, or
/// `Color.LightGreen` while a buff raises the skill.
const _levelColor = Color(0xFFF4A460);
const _buffedLevelColor = Color(0xFF90EE90);

/// A number in vanilla's chunky `NumberSprite` digits (the mod's
/// `digit-0`…`digit-9` icons): 8x8 cells, 7px apart (vanilla steps
/// `8 * 4 - 4` screen px per digit at 4x, so neighbours overlap by 1px),
/// each tinted [color] over a 35%-black shadow 1px down-left.
class _NumberSprite extends StatelessWidget {
  const _NumberSprite({
    required this.number,
    required this.scale,
    required this.color,
    required this.connection,
    this.opacity = 1,
  });

  final int number;
  final double scale;
  final Color color;
  final double opacity;
  final GameConnectionService connection;

  static double widthFor(int digits, double scale) => (8 + (digits - 1) * 7 + 1) * scale;

  @override
  Widget build(BuildContext context) {
    final digits = '$number'.split('');

    Widget digit(String d, Color tint, BlendMode mode) {
      final url = connection.iconUrl('digit-$d');
      if (url == null) return const SizedBox.shrink();
      return Image.network(
        url,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.none,
        color: tint,
        colorBlendMode: mode,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    }

    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: widthFor(digits.length, scale),
        height: 9 * scale,
        child: Stack(
          children: [
            for (var i = 0; i < digits.length; i++)
              Positioned(
                left: i * 7 * scale,
                top: scale,
                width: 8 * scale,
                height: 8 * scale,
                child: digit(digits[i], Colors.black.withValues(alpha: 0.35), BlendMode.srcIn),
              ),
            for (var i = 0; i < digits.length; i++)
              Positioned(
                left: (i * 7 + 1) * scale,
                top: 0,
                width: 8 * scale,
                height: 8 * scale,
                child: digit(digits[i], color, BlendMode.modulate),
              ),
          ],
        ),
      ),
    );
  }
}
