import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/game_state.dart';
import '../../services/game_connection_service.dart';
import '../../theme/stardew_colors.dart';
import '../../theme/stardew_fonts.dart';

/// The Skills tab — a pixel-for-pixel copy of the real vanilla Skills page.
///
/// Every element is placed at the exact offset the decompiled 1.6
/// `StardewValley.Menus.SkillsPage.draw` uses (same verify-before-guessing
/// convention as every other real-sprite widget in this app), in the game's
/// own "native" menu coordinates: origin at the top-left of the `GameMenu`
/// (880x680 — `800 + 2 * borderWidth`, `600 + 2 * borderWidth` with
/// `borderWidth = 40`), 4x sprite scale, 68px between skill rows, 36px
/// between pips, and so on. The whole page is one fixed-layout canvas in
/// those units, scaled uniformly by a single factor so the window box this
/// tab lives in matches the game's own box (see [_Frame]) — no flexible
/// layout anywhere, so every element keeps the same position *relative to
/// every other element* as in the game, at any screen size.
///
/// - Top half: player portrait over the real day/night background, name +
///   title, Golden Walnut / Qi Gem counters under them, and the five skill
///   rows (skill name ending flush left of its icon, the ten-segment
///   level-progress bar, and the level in vanilla's `NumberSprite` digits).
/// - A horizontal rule, then the bottom half: the Community Center room
///   tracker on the left (a locked placeholder before the Meet the Wizard
///   quest, Joja variants on the Joja route), a vertical rule, then the
///   mastery bar above a row of farmhouse level (with the animated chimney
///   smoke once the house is fully upgraded), deepest Mines/Skull Cavern
///   floor and Stardrops found. The bottom-right corner holds vanilla's
///   seasonal doodle, with the Feast of the Winter Star secret friend over
///   it while vanilla shows them (winter 18 until the feast).
///
/// Deliberately NOT reproduced: the Luck row (vanilla itself hides it
/// until the Special Charm is found), profession badges and the Junimo
/// click easter egg.
///
/// Everything in the bottom half defaults to its "nothing to show" state
/// against an older mod build that doesn't report those fields yet (see
/// `GameState`'s "Skills screen extras").
class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key, required this.connection});

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

        return LayoutBuilder(builder: (context, constraints) {
          final frame = _Frame.fit(constraints.biggest);
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: _SkillsPage(state: state, connection: connection, frame: frame),
          );
        });
      },
    );
  }
}

/// Maps the game's native menu coordinates onto this tab's window box.
///
/// The page is anchored by the *parchment interior* of the two windows, not
/// their outer edges: the game's box (drawn from the dialogue-box tiles)
/// has a thinner frame, relative to the page, than the app's own 9-slice
/// `GameWindowBox`, so anchoring by outer edge would push the rules and
/// the level numbers under the app's thicker border. The game's interior
/// covers native x 32.9..847.9 and y 100.7..647.9 (measured off the real
/// game); the app's is the box minus its [_borderSide]/[_borderTop]/
/// [_borderBottom] frame (measured off the real app).
///
/// One scale fits the interior's width (or its height if the box is short).
/// Any spare height is shared around the top half (portrait, skill rows):
/// the bottom half (rule, Community Center tracker, mastery, stats, doodle)
/// is anchored to the bottom, so the last row sits where it does in the
/// game — against the bottom of the window — and the top half is centred
/// in the room left above the rule, as one block (the portrait's top stays
/// aligned with the first skill row's).
class _Frame {
  const _Frame({required this.scale, required this.originX, required this.originY, required this.slack});

  /// Screen px (logical) per native game px.
  final double scale;

  /// Screen position of native (0, 0).
  final double originX;
  final double originY;

  /// Spare interior height: all of it is added to everything from [_splitY]
  /// down, half of it to the top half.
  final double slack;

  // The game's parchment interior, in native px.
  static const _interiorLeft = 32.9;
  static const _interiorTop = 100.7;
  static const _interiorWidth = 815.0;
  static const _interiorHeight = 547.0;

  /// Native y between the last skill row (ends at 432) and the horizontal
  /// rule (457) — where spare height is inserted.
  static const _splitY = 445.0;

  // The app's window frame thickness, in logical px, measured off the
  // running app (the top is thicker: it carries an inner ledge, like the
  // game's).
  static const _borderSide = 12.14;
  static const _borderTop = 16.04;
  static const _borderBottom = 12.14;

  factory _Frame.fit(Size size) {
    final innerWidth = size.width - 2 * _borderSide;
    final innerHeight = size.height - _borderTop - _borderBottom;
    final scale = math.min(innerWidth / _interiorWidth, innerHeight / _interiorHeight);
    return _Frame(
      scale: scale,
      originX: _borderSide + (innerWidth - _interiorWidth * scale) / 2 - _interiorLeft * scale,
      originY: _borderTop - _interiorTop * scale,
      slack: math.max(0, innerHeight - _interiorHeight * scale),
    );
  }

  double x(double nativeX) => originX + nativeX * scale;
  double y(double nativeY) => originY + nativeY * scale + (nativeY >= _splitY ? slack : slack / 2);
  double len(double native) => native * scale;

  /// Positions [child] at native `(x, y)` with native size `w x h`.
  Widget at(double nx, double ny, double w, double h, Widget child) => Positioned(
        left: x(nx),
        top: y(ny),
        width: len(w),
        height: len(h),
        child: child,
      );

  /// A solid rect at native coordinates — vanilla's `Game1.staminaRect`.
  Widget rect(double nx, double ny, double w, double h, Color color) =>
      at(nx, ny, w, h, ColoredBox(color: color));
}

/// Native px height of vanilla's `Game1.smallFont` text at its 1x size, as
/// mapped onto the app's pixel font — tuned so a label like "Farming" is
/// the same width as in the game.
const double _fontNative = 39;

/// Vanilla's `Game1.textColor`.
const _textColor = StardewColors.textBrown;

/// Vanilla's own divider color for the Skills page's horizontal and
/// vertical rules — `new Color(214, 143, 84)` in `SkillsPage.draw`.
const _ruleColor = Color(0xFFD68F54);

/// Vanilla's own purple for the Stardrop count once all 7 are found —
/// `new Color(160, 30, 235)` in `SkillsPage.draw`.
const _allStardropsColor = Color(0xFFA01EEB);

/// Vanilla's level-number tints — `Color.SandyBrown`, or
/// `Color.LightGreen` while a buff raises the skill.
const _levelColor = Color(0xFFF4A460);
const _buffedLevelColor = Color(0xFF90EE90);

class _SkillSpec {
  const _SkillSpec({required this.name, required this.iconKey});

  final String name;
  final String iconKey;
}

const _skills = [
  _SkillSpec(name: 'Farming', iconKey: 'skill-farming'),
  _SkillSpec(name: 'Mining', iconKey: 'skill-mining'),
  _SkillSpec(name: 'Foraging', iconKey: 'skill-foraging'),
  _SkillSpec(name: 'Fishing', iconKey: 'skill-fishing'),
  _SkillSpec(name: 'Combat', iconKey: 'skill-combat'),
];

class _SkillsPage extends StatelessWidget {
  const _SkillsPage({required this.state, required this.connection, required this.frame});

  final GameState state;
  final GameConnectionService connection;
  final _Frame frame;

  // SkillsPage.draw's own layout constants: IClickableMenu.borderWidth (40),
  // spaceToClearTopBorder (96), spaceToClearSideBorder (16), and the menu's
  // 880x680 size.
  static const _menuWidth = 880.0;
  static const _menuHeight = 680.0;

  @override
  Widget build(BuildContext context) {
    final f = frame;

    final levelsByName = <String, int>{
      'Farming': state.farmingLevel,
      'Mining': state.miningLevel,
      'Foraging': state.foragingLevel,
      'Fishing': state.fishingLevel,
      'Combat': state.combatLevel,
    };

    // Same day/night swap the clock badge and the Map screen's portrait
    // marker already key off — matches the game's own
    // Game1.timeOfDay >= 1900 check (see companion_screen's clock doc
    // comments / PortraitBackgroundCache.cs).
    final night = state.hour24 >= 19;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ..._portrait(f, night),
        ..._counters(f),
        for (var j = 0; j < _skills.length; j++)
          ..._skillRow(f, j, _skills[j], levelsByName[_skills[j].name] ?? 0),

        // The horizontal rule: (32, 457), 808 wide, 4 tall.
        f.rect(33, 457, _menuWidth - 64 - 8 - 1, 4, _ruleColor),
        _CommunityCenterTracker(state: state, connection: connection, frame: f),
        // The vertical rule: 124 right of the tracker's origin, a third of
        // the menu tall (minus 32 + 4).
        f.rect(236, 457, 4, (_menuHeight / 3).floorToDouble() - 32 - 4, _ruleColor),

        ..._mastery(f),
        ..._stats(f),
      ],
    );
  }

  TextStyle _style(double scale, {Color color = _textColor, double size = _fontNative}) =>
      stardewFont(fontSize: size * scale, color: color, height: 1);

  /// A single line of text whose top-left is native `(x, y)`, like
  /// `SpriteBatch.DrawString`. [align] picks which side of the box [x]
  /// anchors: left (text starts at x), right (text ends at x) or center.
  Widget _text(_Frame f, double x, double y, String text,
      {TextAlign align = TextAlign.left, Color color = _textColor, double size = _fontNative}) {
    const boxWidth = 420.0;
    final left = switch (align) {
      TextAlign.right => x - boxWidth,
      TextAlign.center => x - boxWidth / 2,
      _ => x,
    };
    return Positioned(
      left: f.x(left),
      top: f.y(y),
      width: f.len(boxWidth),
      child: Text(
        text,
        textAlign: align,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: _style(f.scale, color: color, size: size),
      ),
    );
  }

  // ---- Portrait, name, title ---------------------------------------------

  /// The player's real composited portrait over the real day/night
  /// background. The background (`Game1.daybg`/`nightbg`, 128x192) already
  /// carries its own frame, so it's drawn as-is at its native size at
  /// (56, 116). The farmer sits where SkillsPage puts it relative to that
  /// background: the mod's 80x144 portrait canvas (see PortraitRenderer.cs —
  /// the farmer drawn at (8, 8) inside it) lands at (24, 24) in background
  /// pixels, since SkillsPage draws the farmer 32px right of and 32px below
  /// the background's top-left. Name and title are centred on x = 120.
  List<Widget> _portrait(_Frame f, bool night) {
    return [
      f.at(56, 116, 128, 192, _Sprite(connection.portraitBackgroundUrl(night))),
      f.at(
        56 + 24,
        116 + 24,
        80,
        144,
        connection.portraitUrl == null
            ? const Icon(Icons.person, size: 34, color: StardewColors.textBrown)
            : _AnimatedPortrait(urlFor: (frame, eyes) => connection.portraitFrameUrl(frame, eyes: eyes)),
      ),
      _text(f, 120, 311, state.playerName.isEmpty ? '…' : state.playerName, align: TextAlign.center),
      if (state.title.isNotEmpty) _text(f, 120, 341, state.title, align: TextAlign.center),
    ];
  }

  // ---- Golden Walnut / Qi Gem counters -----------------------------------

  /// Each counter is a 16x16 object-sheet icon drawn at 2x (32x32) followed
  /// by its count; a lone counter is nudged 24px right, and the second
  /// counter follows the first (`SkillsPage.draw`'s `x` bookkeeping).
  List<Widget> _counters(_Frame f) {
    const y = 380.0;
    var x = 40.0;
    final walnuts = state.goldenWalnuts;
    final gems = state.qiGems;
    final widgets = <Widget>[];

    if (walnuts > 0) {
      widgets.add(f.at(x + (gems <= 0 ? 24 : 0), y, 32, 32, _Sprite(connection.iconUrl('golden-walnut'))));
      x += gems <= 0 ? 60 : 36;
      widgets.add(_text(f, x, y, '$walnuts'));
      x += 56;
    }
    if (gems > 0) {
      widgets.add(f.at(x + (walnuts <= 0 ? 24 : 0), y, 32, 32, _Sprite(connection.iconUrl('qi-gem'))));
      x += walnuts <= 0 ? 60 : 36;
      widgets.add(_text(f, x, y, '$gems'));
    }
    return widgets;
  }

  // ---- Skill rows ---------------------------------------------------------

  /// One skill's row `j`: name ending at x = 324 (flush against the icon),
  /// the icon (a black 30% shadow 4px down-left of the white copy) at
  /// x = 332, ten pips from x = 384 at a 36px pitch (24px extra after the
  /// fifth), then the level in `NumberSprite` digits centred at x = 832
  /// (820 for a single digit) — all straight from `SkillsPage.draw`.
  List<Widget> _skillRow(_Frame f, int j, _SkillSpec skill, int level) {
    final rowY = 68.0 * j;
    final buffed = state.buffedSkills.contains(skill.name.toLowerCase());
    final iconUrl = connection.iconUrl(skill.iconKey);

    return [
      _text(f, 324, 132 + rowY, skill.name, align: TextAlign.right),
      f.at(328, 128 + rowY, 40, 40, _Sprite(iconUrl, tint: Colors.black.withValues(alpha: 0.3))),
      f.at(332, 124 + rowY, 40, 40, _Sprite(iconUrl)),
      for (var i = 0; i < 10; i++) ..._pip(f, i, rowY, filled: level > i),
      ..._number(
        f,
        level,
        cx: 820 + (level >= 10 ? 12 : 0),
        cy: 140 + rowY,
        color: buffed ? _buffedLevelColor : _levelColor,
        opacity: level == 0 ? 0.75 : 1,
      ),
    ];
  }

  /// One level-progress segment: a 35% black shadow (the empty sprite, 4px
  /// down-left) and the sprite itself — the filled variant once the level
  /// exceeds its position, the empty one at 65% opacity otherwise. Every
  /// fifth pip (the level 5/10 milestones) is the wider 14px sprite.
  List<Widget> _pip(_Frame f, int i, double rowY, {required bool filled}) {
    final wide = (i + 1) % 5 == 0;
    final x = 384.0 + 36 * i + (i >= 5 ? 24 : 0);
    final w = wide ? 56.0 : 32.0;
    final emptyUrl = connection.iconUrl(wide ? 'pip-empty-wide' : 'pip-empty');
    final filledUrl = connection.iconUrl(wide ? 'pip-filled-wide' : 'pip-filled');

    return [
      // Vanilla draws the wide shadow only for an unfilled pip (a filled one
      // is a separate profession-badge component with its own shadow).
      f.at(x - 4, 128 + rowY, w, 36, _Sprite(emptyUrl, tint: Colors.black.withValues(alpha: 0.35), fit: BoxFit.fill)),
      f.at(
        x,
        124 + rowY,
        w,
        36,
        _Pip(filled: filled, emptyUrl: emptyUrl, filledUrl: filledUrl),
      ),
    ];
  }

  /// A number in vanilla's chunky `NumberSprite` digits: 8x8 glyphs drawn at
  /// 4x (32x32) *centred* on their position, the last digit at `(cx, cy)`
  /// and each earlier one 28px to its left (they overlap by 4px), tinted
  /// [color] over a 35%-black shadow 4px down-left.
  List<Widget> _number(
    _Frame f,
    int number, {
    required double cx,
    required double cy,
    required Color color,
    double opacity = 1,
  }) {
    final digits = '$number'.split('');
    Widget glyph(String d, double centerX, double centerY, Color tint, BlendMode mode) => f.at(
          centerX - 16,
          centerY - 16,
          32,
          32,
          _DigitSprite(url: connection.iconUrl('digit-$d'), tint: tint, mode: mode),
        );

    return [
      for (var k = 0; k < digits.length; k++)
        glyph(digits[digits.length - 1 - k], cx - 4 - 28.0 * k, cy + 4, Colors.black.withValues(alpha: 0.35), BlendMode.srcIn),
      for (var k = 0; k < digits.length; k++)
        glyph(digits[digits.length - 1 - k], cx - 28.0 * k, cy, color.withValues(alpha: opacity), BlendMode.modulate),
    ];
  }

  // ---- Mastery ------------------------------------------------------------

  /// The mastery bar: localized "Mastery" label, the mastery icon, then a
  /// progress bar toward the next mastery level and the current level
  /// number — `SkillsPage.draw` + `MasteryTrackerMenu.drawBar`, at the same
  /// native offsets (the label's own width shifts everything after it, so
  /// the label is measured in the same font). Until the player earns any
  /// mastery exp, vanilla draws a locked banner in its place instead.
  List<Widget> _mastery(_Frame f) {
    if (!state.masteryUnlocked) {
      return [
        f.at(260, 485, 568, 48, Tooltip(message: 'Mastery (locked)', child: _Sprite(connection.iconUrl('mastery-locked')))),
      ];
    }

    final label = state.masteryLabel.isEmpty ? 'Mastery' : state.masteryLabel;
    // The game's own measurement when the mod reports it; otherwise the
    // app's pixel font, whose advance widths run ~10% wide.
    final labelWidth = state.masteryLabelWidth > 0 ? state.masteryLabelWidth : _measure(label) * 0.91;
    final xo = labelWidth.truncateToDouble() - 64;
    const yo = 84.0;
    final level = state.masteryLevel;
    final width = 0.64 - (labelWidth - 100) / 800;

    int px(double v) => v.truncate();

    // drawBar's colors.
    const light = Color(0xFF3CB450);
    const med = Color(0xFF00713E);
    const medDark = Color(0xFF005032);
    const troughEdge = Color(0xFF3C3C19);
    const trough = Color(0xFFAD814F);

    final barWidth = level >= 5 ? px(576 * width).toDouble() : px(576 * state.masteryProgress * width).toDouble();
    final progressText = '${state.masteryExpIntoLevel}/${state.masteryExpForNextLevel}';
    final numberX = xo + px(584 * width);

    return [
      _text(f, 256, yo + 408, label),
      f.at(xo + 332 - 4, yo + 400 + 4, 44, 44, _Sprite(connection.iconUrl('mastery'), tint: Colors.black.withValues(alpha: 0.35))),
      f.at(xo + 332, yo + 400, 44, 44, _Sprite(connection.iconUrl('mastery'))),
      f.rect(xo + 380 - 1, yo + 408, px(584 * width) + 4.0, 40, Colors.black.withValues(alpha: 0.35)),
      f.rect(xo + 384, yo + 404, px((level >= 5 ? 144 : 146) * 4 * width) + 4.0, 40, troughEdge),
      f.rect(xo + 388, yo + 408, px(576 * width).toDouble(), 32, trough),
      if (level >= 5 || barWidth > 0) ...[
        f.rect(xo + 388, 348 + 144, barWidth, 32, med),
        f.rect(xo + 388, 348 + 148, 4, 28, medDark),
        if (barWidth > 8) ...[
          f.rect(xo + 388, 348 + 172, barWidth - 8, 4, medDark),
          f.rect(xo + 392, 348 + 144, barWidth - 4, 4, light),
          f.rect(xo + 380 + barWidth, 348 + 144, 4, 28, light),
          f.rect(xo + 384 + barWidth, 348 + 144, 4, 32, medDark),
        ],
      ],
      if (level < 5)
        _text(f, xo + 388 + 288 * width, 348 + 146, progressText,
            align: TextAlign.center, color: Colors.white.withValues(alpha: 0.75)),
      ..._number(f, level, cx: numberX + 412, cy: yo + 424, color: _levelColor, opacity: level == 0 ? 0.75 : 1),
    ];
  }

  /// Width, in native px, the game's `smallFont.MeasureString` would give
  /// [text] — approximated with the app's own pixel font at the same size.
  double _measure(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: stardewFont(fontSize: _fontNative)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  // ---- Farmhouse / floor / Stardrops / doodle ----------------------------

  /// The bottom row of vanilla's Skills page: farmhouse level, deepest
  /// floor reached, Stardrops found — and, in the bottom-right corner,
  /// the seasonal doodle with the Feast of the Winter Star secret friend
  /// over it while vanilla shows them.
  List<Widget> _stats(_Frame f) {
    final houseLabel = state.houseLevelLabel.isEmpty
        ? 'Level ${state.houseUpgradeLevel + 1}'
        : state.houseLevelLabel;
    // A long localized label pushes the icon and text 20px left.
    final houseOffset = _measure(houseLabel) > 120 ? -20.0 : 0.0;

    // Vanilla shows the Skull Cavern floor instead of the Mines floor
    // once the player's been below the Mines, marked with a skull; no
    // number at all before the first floor.
    final inSkullCavern = state.deepestSkullCavernLevel > 0;
    final floor = inSkullCavern ? state.deepestSkullCavernLevel : state.deepestMineLevel;

    final secretFriend = state.secretFriendName;

    const houseX = 264.0;
    const y = 581.0;
    const mineX = 444.0;
    const stardropX = 564.0;
    const cornerX = stardropX;

    return [
      // Farmhouse.
      f.at(
        houseX + houseOffset + 20,
        y - 4,
        40,
        40,
        Tooltip(message: 'Farmhouse', child: _Sprite(connection.iconUrl('house'))),
      ),
      _text(f, houseX + houseOffset + 72, y, houseLabel),
      if (state.houseUpgradeLevel >= 3)
        _HouseSmoke(frame: f, anchorX: houseX + houseOffset + 50, anchorY: y - 4, url: connection.iconUrl('smoke')),

      // Deepest floor.
      f.at(
        mineX + 8,
        y - 8,
        52,
        52,
        Tooltip(
          message: inSkullCavern ? 'Deepest Skull Cavern floor' : 'Deepest mine floor',
          child: _Sprite(connection.iconUrl(floor == 0 ? 'mine-level-none' : 'mine-level')),
        ),
      ),
      if (floor != 0) _text(f, mineX + 72 + (inSkullCavern ? 8 : 0), y, '$floor'),
      if (inSkullCavern) f.at(mineX + 40, y - 8 + 24, 32, 36, _Sprite(connection.iconUrl('skull-cavern'))),

      // Stardrops.
      f.at(
        stardropX + 32,
        y - 8 - 4,
        48,
        56,
        Tooltip(
          message: 'Stardrops found',
          child: _Sprite(connection.iconUrl(state.stardropsFound > 0 ? 'stardrop' : 'stardrop-none')),
        ),
      ),
      if (state.stardropsFound > 0)
        _text(
          f,
          stardropX + 88,
          y,
          'x ${state.stardropsFound}',
          color: state.stardropsFound >= 7 ? _allStardropsColor : _textColor,
        ),

      // Bottom-right corner: the seasonal doodle (33x23 at 4x) at
      // (x + 144, y - 20), with the secret friend's mugshot at (x + 180, y)
      // and its gift box at (x + 244, y + 40) drawn over it.
      if (state.doodleIcon.isNotEmpty)
        f.at(cornerX + 144, y - 8 - 20, 132, 92, _Sprite(connection.iconUrl(state.doodleIcon))),
      if (secretFriend != null) ...[
        f.at(
          cornerX + 180,
          y - 8,
          64,
          76,
          Tooltip(message: 'Secret friend: $secretFriend', child: _Sprite(connection.secretFriendUrl)),
        ),
        f.at(cornerX + 244, y - 8 + 40, 40, 44, _Sprite(connection.iconUrl('secret-friend-gift'))),
      ],
    ];
  }
}

/// The farmer portrait, walking in place and blinking.
///
/// Vanilla's `SkillsPage` steps its portrait through the sprite sheet's
/// frames `{0, 1, 0, 2}` every 150ms (`playerPanelFrames`/`playerPanelTimer`)
/// — but only while the cursor hovers over it; the app has no cursor, so it
/// runs continuously. The face blinks the way `Farmer.update` blinks it:
/// once `blinkTimer` passes 2200ms there's a 1% chance per 60fps tick of a
/// blink, which holds the eyes closed (`currentEyes = 4`) for 50ms, half
/// closed (1) for 50ms, closed again for 50ms, then open (0) again. The mod
/// renders each frame in each eye state; this just picks between them.
///
/// Every frame/eye combination is kept in the tree (only the current one
/// visible) so each is loaded and cached up front and stepping never
/// flickers.
class _AnimatedPortrait extends StatefulWidget {
  const _AnimatedPortrait({required this.urlFor});

  /// URL of walk frame (0-2) with eye state (0, 1 or 4).
  final String? Function(int frame, int eyes) urlFor;

  @override
  State<_AnimatedPortrait> createState() => _AnimatedPortraitState();
}

class _AnimatedPortraitState extends State<_AnimatedPortrait> {
  static const _sequence = [0, 1, 0, 2];
  static const _eyeStates = [0, 1, 4];

  /// Timer tick; the walk cycle advances every [_ticksPerStep] ticks
  /// (150ms).
  static const _tick = Duration(milliseconds: 50);
  static const _ticksPerStep = 3;

  final _random = math.Random();
  Timer? _timer;
  int _ticks = 0;
  int _index = 0;
  int _eyes = 0;

  /// Vanilla's `Farmer.blinkTimer`, in ms.
  int _blinkTimer = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_tick, (_) => _advance());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _advance() {
    _ticks++;
    _blinkTimer += _tick.inMilliseconds;

    var eyes = _eyes;
    // Vanilla rolls 1% per 60fps tick; one 50ms tick is three of them.
    if (_blinkTimer > 2200 && _random.nextDouble() < 1 - math.pow(0.99, 3)) {
      _blinkTimer = -150;
      eyes = 4;
    } else if (_blinkTimer > -100) {
      eyes = _blinkTimer < -50 ? 1 : (_blinkTimer < 0 ? 4 : 0);
    }

    final step = _ticks % _ticksPerStep == 0;
    if (!step && eyes == _eyes) return;
    setState(() {
      _eyes = eyes;
      if (step) _index = (_index + 1) % _sequence.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final frame = _sequence[_index];
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var f = 0; f < 3; f++)
          for (final e in _eyeStates)
            Opacity(
              opacity: f == frame && e == _eyes ? 1 : 0,
              child: _Sprite(widget.urlFor(f, e)),
            ),
      ],
    );
  }
}

/// One level-progress-bar segment — filled (red) once the skill's level
/// exceeds this pip's position, empty (wood) at 65% opacity otherwise.
/// Prefers the real vanilla sprite crop (`UiIconCache`'s `pip-*` entries);
/// falls back to a flat tinted box matching the same fill state if the
/// sprite hasn't loaded.
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

    return Opacity(
      opacity: filled ? 1 : 0.65,
      child: SizedBox.expand(
        child: url == null
            ? fallback()
            : Image.network(
                url,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
                errorBuilder: (context, error, stackTrace) => fallback(),
              ),
      ),
    );
  }
}

/// One of the mod's `/icon` sprite crops, drawn pixel-crisp at whatever
/// size its parent gives it — nothing at all if the icon isn't
/// available (not connected, or an older mod build that doesn't crop it
/// yet), so the layout around it doesn't shift. [tint] recolors it to a
/// flat silhouette (used for the shadows vanilla draws under most sprites).
class _Sprite extends StatelessWidget {
  const _Sprite(this.url, {this.tint, this.fit = BoxFit.fill});

  final String? url;
  final Color? tint;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (url == null) return const SizedBox.shrink();
    return Image.network(
      url!,
      fit: fit,
      filterQuality: FilterQuality.none,
      color: tint,
      colorBlendMode: tint == null ? null : BlendMode.srcIn,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

/// One `NumberSprite` digit glyph, tinted [tint] via [mode] (`modulate` for
/// the level's own color, `srcIn` for the black shadow).
class _DigitSprite extends StatelessWidget {
  const _DigitSprite({required this.url, required this.tint, required this.mode});

  final String? url;
  final Color tint;
  final BlendMode mode;

  @override
  Widget build(BuildContext context) {
    if (url == null) return const SizedBox.shrink();
    return Image.network(
      url!,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
      color: tint,
      colorBlendMode: mode,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

/// The Community Center room tracker from the bottom-left of vanilla's
/// Skills page, at the native offsets `SkillsPage.draw` uses: six 44x44 room
/// stars around a ring anchored at (112, 473) — Bulletin Board on top,
/// Boiler Room and Vault on the right, Crafts Room and Fish Tank on the
/// left, Pantry at the bottom — filled once that room is restored.
///
/// Before the Meet the Wizard quest (`GameState.communityCenterUnlocked`
/// false) vanilla draws a locked placeholder panel instead. On the Joja
/// route the stars switch to their Joja variants and a Joja panel covers
/// the Bulletin Board slot; once every room is restored the Junimo way,
/// a Junimo stands in the middle.
class _CommunityCenterTracker extends StatelessWidget {
  const _CommunityCenterTracker({required this.state, required this.connection, required this.frame});

  final GameState state;
  final GameConnectionService connection;
  final _Frame frame;

  /// Native top-left of each room's 44x44 star, indexed by vanilla area
  /// number (0 Pantry, 1 Crafts Room, 2 Fish Tank, 3 Boiler Room, 4 Vault,
  /// 5 Bulletin Board) — `SkillsPage.draw`'s `(x ± 60, y + 28)` etc.
  /// offsets from `(112, 473)`.
  static const _starPositions = [
    Offset(112, 593),
    Offset(52, 501),
    Offset(52, 561),
    Offset(172, 501),
    Offset(172, 561),
    Offset(112, 473),
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
    final f = frame;
    final children = <Widget>[];

    if (!state.communityCenterUnlocked) {
      children.add(f.at(32, 457, 208, 188, _Sprite(connection.iconUrl('cc-locked'))));
    } else {
      final joja = state.isJojaMember;
      if (joja) {
        children.add(f.at(32, 457, 204, 192, _Sprite(connection.iconUrl('cc-joja'))));
      }
      for (var area = 0; area < _starPositions.length; area++) {
        // The Joja panel takes the Bulletin Board's slot outright.
        if (joja && area == 5) continue;
        final done = area < state.communityCenterAreas.length && state.communityCenterAreas[area];
        final key = 'cc-area-${done ? 'complete' : 'incomplete'}${joja ? '-joja' : ''}';
        children.add(f.at(
          _starPositions[area].dx,
          _starPositions[area].dy,
          44,
          44,
          Tooltip(
            message: _areaNames[area],
            child: _Sprite(connection.iconUrl(key)),
          ),
        ));
      }
      if (state.communityCenterComplete) {
        // Drawn centred on (x + 26, y + 82) with a 7.5px origin at 4x.
        children.add(f.at(108, 525, 52, 60, _Sprite(connection.iconUrl('cc-junimo'))));
      }
    }

    // The tracker's children are positioned against the page's own Stack.
    return Positioned.fill(child: Stack(clipBehavior: Clip.none, children: children));
  }
}

/// The three chimney-smoke puffs `SkillsPage.draw` animates over the house
/// icon once the farmhouse is fully upgraded: each puff drifts up 0.01px
/// per ms while turning, growing from 0.5x to 2.5x and fading out over
/// 2 seconds, staggered 709ms apart. Same math as the game's own loop, with
/// the sprite's rotation/scale origin at 3/5/4 native pixels.
class _HouseSmoke extends StatefulWidget {
  const _HouseSmoke({required this.frame, required this.anchorX, required this.anchorY, required this.url});

  final _Frame frame;
  final double anchorX;
  final double anchorY;
  final String? url;

  @override
  State<_HouseSmoke> createState() => _HouseSmokeState();
}

class _HouseSmokeState extends State<_HouseSmoke> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();

  static const _interval = 709;
  static const _origins = [3.0, 5.0, 4.0];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    if (url == null) return const SizedBox.shrink();
    final f = widget.frame;

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final base = _controller.value * 2000;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (var k = 0; k < 3; k++) _puff(f, url, (base + _interval * k) % 2000, _origins[k]),
            ],
          );
        },
      ),
    );
  }

  Widget _puff(_Frame f, String url, double t, double origin) {
    final scale = 0.5 + t / 1000;
    final size = 10 * scale;
    final alpha = 0.53 * (1 - t / 2000);
    final left = widget.anchorX - origin * scale;
    final top = widget.anchorY - t * 0.01 - origin * scale;

    return Positioned(
      left: f.x(left),
      top: f.y(top),
      width: f.len(size),
      height: f.len(size),
      child: Transform.rotate(
        angle: -t * 0.001,
        alignment: Alignment((origin * scale) / (size / 2) - 1, (origin * scale) / (size / 2) - 1),
        child: Image.network(
          url,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.none,
          color: const Color.fromRGBO(80, 80, 80, 1).withValues(alpha: alpha),
          colorBlendMode: BlendMode.modulate,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
