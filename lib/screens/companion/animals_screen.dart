import 'package:flutter/material.dart';

import '../../models/animal_summary.dart';
import '../../services/game_connection_service.dart';
import '../../theme/stardew_colors.dart';
import '../../widgets/companion_screen_container.dart';

/// The Animals tab — a real scrollable *table* of the farm's animals
/// (portrait+name, a 5-heart friendship meter, a hand-cursor icon plus
/// a real petting-status glyph column), styled after the in-game
/// reference screenshot from the tracking issue and, as of this round,
/// after vanilla's own real equivalent screen too: one continuous grid
/// rather than a list of separate cards, with vertical column rules
/// spanning every row and a real scrollbar rail (the game's own large
/// up/down scroll arrows) down the right edge.
///
/// CORRECTED after an in-app screenshot comparison against the
/// reference caught three bugs in the first build of this screen:
/// - This screen does *not* add its own `GameWindowBox` — it lives
///   inside the one `CompanionScreen` already wraps every tab in (like
///   `SkillsScreen`/`BackpackScreen`/`MapScreen`). An earlier draft
///   nested a second one here on the mistaken belief the reference
///   screenshot showed two tiers of window chrome; it doesn't — one
///   frame, tab icons overlaid on its top edge, is the whole picture.
///   Like those three tab screens, this one wraps itself in
///   `CompanionScreenContainer` too, but passes `hasPadding: false`:
///   each row draws its own grid-rule dividers flush against its full
///   width (see `_AnimalRow`'s own doc comment), so the standard tab
///   inset would pull the row content in from under them without
///   moving the dividers to match — see `CompanionScreenContainer`'s
///   own doc comment.
/// - The vertical grid-rule lines live inside each row, sized to match
///   its own real content from fixed constants (see `_AnimalRow`'s
///   doc comment) rather than positioned from outside against the
///   table's full width the way an earlier round did it — that
///   earlier, outside-in approach is also what an even earlier draft's
///   whole-row symmetric padding broke: it shrank the row's content
///   without moving the (then separately computed) divider lines to
///   match. The breathing room lives *inside* the flexible name column
///   only, not around the whole row, for the same reason.
/// - The status column is a hand-cursor icon *and* a second status
///   glyph stacked vertically in the reference, not just the
///   hand-cursor alone.
///
/// A later round found the real, decompiled
/// `StardewValley.Menus.AnimalPage` — vanilla 1.6's own "Animals" page,
/// added to its own `GameMenu` (see `UiIconCache`'s class doc comment
/// for how it was found) — and it turned out to be almost exactly what
/// this screen is reproducing, settling several rects/formulas earlier
/// rounds here had gotten wrong by inference:
/// - hearts are the real friendship-heart crop (`UiIconCache`'s
///   `heart-filled`/`heart-empty`) — confirmed against
///   `AnimalPage.drawNPCSlot`'s own heart-drawing loop, no change
///   needed;
/// - the portrait is the animal's own real breed sprite
///   (`AnimalIconCache`, via `GameConnectionService.animalSpriteUrl`),
///   now cropped with `AnimalPage`'s own real `AnimalEntry` formulas
///   for both a farm animal and a house pet (a fixed, deterministic
///   pixel-math crop, not any single named "idle frame") — see
///   `AnimalIconCache`'s class doc comment and
///   `EnsureCachedForPet`'s doc comment for the full multi-attempt
///   history that preceded finding `AnimalPage.cs` itself;
/// - the hand-cursor icon is vanilla's own real cursor sprite
///   (`UiIconCache`'s `hand-cursor`, corrected to `AnimalPage`'s own
///   10x10 crop from an earlier over-cropped 16x16 guess) — see
///   `_PettingBadge`'s doc comment for why it's now drawn at
///   unconditional full opacity rather than faded by pet status,
///   matching `AnimalPage.drawNPCSlot`'s own unconditional draw;
/// - the per-row status glyph below it is CORRECTED from an entirely
///   wrong sprite: an earlier round used
///   `StardewValley.Menus.OptionsCheckbox`'s generic checkbox sprite
///   (`UiIconCache`'s old `petting-checkbox-unchecked`/`-checked`) on
///   the assumption this was a generic checkbox reused here;
///   `AnimalPage` reveals it's a dedicated, purpose-built icon instead
///   (`UiIconCache`'s `petting-status-unpet`/`petting-status-pet`),
///   wired to `animal.wasPet` — see `_PettingStatusIcon`'s doc comment;
/// - the scrollbar's up/down arrows are `AnimalPage`'s own real
///   scrollbar buttons (`UiIconCache`'s `scroll-arrow-up`/
///   `scroll-arrow-down`, corrected from an earlier guess borrowed from
///   an unrelated community reference table);
/// - the table's internal grid rule lines are cropped from the same
///   tile vanilla's own `IClickableMenu.drawHorizontalPartition`/
///   `drawVerticalPartition` use for a menu's own internal dividers,
///   called with `small: true` exactly as `AnimalPage.draw()` itself
///   calls them (`UiIconCache`'s `table-divider-h`/`table-divider-v`,
///   corrected to the `small` branch's own tile indices 25/26 from an
///   earlier guess at the non-`small` branch's 6/5), falling back to a
///   flat wood-colored line only while disconnected or if that crop
///   fails to load — see `_HorizontalRule`/`_VerticalRule`'s doc
///   comment.
///
/// The list itself still matches the well-known `AnimalSocialMenu` mod
/// (spacechase0)'s data scope rather than vanilla `AnimalPage`'s own —
/// no produce-ready state, nothing else — since `AnimalPage` also lists
/// horses (out of scope here) and this app's `AnimalSummary`/
/// `GameStateSnapshot` don't capture the extra fields a full
/// vanilla-parity page would need (see those classes' doc comments).
/// The list also includes house pets (Cat/Dog) alongside farm animals,
/// unified into one list/table rather than a separate section — see
/// `AnimalSummary`'s and `GameStateSnapshot`'s doc comments for why.
///
/// A later round fixed the half-heart split itself: a real-device
/// screenshot showed it nowhere near a clean 50/50 seam (mostly just
/// the filled sprite showing through, with the empty overlay
/// squeezed into a small corner) despite looking correct in a layout
/// preview — see `_Heart`'s own doc comment for the fix.
class AnimalsScreen extends StatefulWidget {
  const AnimalsScreen({super.key, required this.connection});

  final GameConnectionService connection;

  @override
  State<AnimalsScreen> createState() => _AnimalsScreenState();
}

class _AnimalsScreenState extends State<AnimalsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompanionScreenContainer(
      hasPadding: false,
      child: ListenableBuilder(
        listenable: widget.connection,
        builder: (context, _) {
          final state = widget.connection.state;
          if (state == null) {
            return const Center(child: Text('Waiting for game data…'));
          }

          final animals = state.animals;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: animals.isEmpty
                    // Genuinely no animals owned yet, not a connection
                    // problem — worded like the Backpack/Skills screens'
                    // own "waiting for data" copy, but distinct from it
                    // (there's no game state to wait on here — an empty
                    // list is itself a valid snapshot).
                    ? const Center(child: Text('No animals yet.'))
                    : _AnimalTable(
                        animals: animals,
                        connection: widget.connection,
                        scrollController: _scrollController,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Native decode size of one `table-divider-h`/`table-divider-v` tile,
/// and the `Image.network` `scale` that keeps it at that full native
/// resolution (no downscale/blur) rather than mapping it back down to
/// a smaller logical size. `UiIconCache.MenuTileIndices` (mod side)
/// crops these from `Game1.menuTexture` via
/// `Game1.getSourceRectForStandardTileSheet`, whose default "standard
/// tile size" is 64x64 — 4x (`Game1.pixelZoom`) the 16x16 native-pixel
/// size every *other* sprite in `UiIconCache` already uses.
///
/// This crop's own opaque line/bevel art doesn't fill the whole 64x64
/// tile — there's real (if not decompile-confirmed) padding around it
/// — so [_HorizontalRule]/[_VerticalRule] each crop down to a much
/// smaller *visible* size via `ClipRect`+`OverflowBox` (see their own
/// `_visibleHeight`/`_visibleWidth`) rather than reserving this whole
/// native size in the table's layout, which is what an earlier round
/// did and which made every row's trailing divider a mostly-blank
/// 64px-tall band — that cropping (not shrinking via `scale`) is what
/// keeps the line pixel-crisp while still letting the table stay
/// compact. `_dividerRuleGapWidth` below is the column-gap counterpart
/// to that same idea, sized to the vertical rule's visible width
/// rather than this native one.
///
/// Not decompile-confirmed — this round couldn't reach a full
/// `IClickableMenu.cs` decompile to verify the exact draw loop/tile
/// size vanilla uses here, nor fetch the actual served crop to measure
/// where its opaque pixels sit within the tile (`mod/README.md`'s
/// risk-area note on `table-divider-h`/`table-divider-v` has the
/// details) — so this is inferred from the 64x64-to-16x16,
/// `pixelZoom`-4 pattern every other icon in this app already follows,
/// not read directly off a decompile like the crop rects themselves
/// were, and the visible-size/gap-width constants below are best-effort
/// guesses at the padding, not measured values. If a decompile (or a
/// look at the real served PNG) later shows a different real tile size
/// or padding, correct these constants (and the matching gap sizing
/// below) rather than the crop rects on the mod side, which remain the
/// actual decompile-verified part (tile indices 25/26).
const double _dividerRuleSize = 64.0;
const double _dividerRuleTileScale = 1.0; // Game1.pixelZoom

/// The column-gap counterpart to [_HorizontalRule]'s/[_VerticalRule]'s
/// own visible-size constants, used by `_AnimalRow` — how wide a gap
/// it actually reserves around each `_VerticalRule`, instead of
/// reserving the full native `_dividerRuleSize` (which left a wide
/// mostly-blank margin on either side of the much narrower visible
/// line). A little wider than `_VerticalRule`'s own `_visibleWidth` on
/// purpose, so the line still gets a sliver of breathing room instead
/// of touching the hearts/status columns' content directly.
const double _dividerRuleGapWidth = 24.0;

/// The actual grid: a scrollable list of rows, each already including
/// its own trailing horizontal rule and the two vertical rules on
/// either side of its hearts column — see `_AnimalRow`'s own doc
/// comment for how one row draws its whole grid cell. `_AnimalTable`
/// itself no longer computes any of that: no `LayoutBuilder`, no
/// manual x-coordinate math, no `Stack`/`Positioned` overlay — an
/// earlier round tried computing the two vertical rules' x positions
/// here and overlaying them on top of each row from outside it, which
/// went through a table-wide-overlay-with-overflow bug, then a
/// per-row-Stack-with-a-corner-gap bug, then a
/// vertical-rule-painted-over-horizontal-rule color-clash bug — three
/// rounds of manual layout math fighting itself. Moving the grid lines
/// into `_AnimalRow` (CORRECTED per user suggestion) sidesteps all
/// three at once: every row's content is a handful of fixed-size
/// constants (see `_AnimalRow._rowHeight`'s doc comment), so the
/// vertical rules are given that exact height directly rather than
/// needing to be measured, with nothing left to get out of sync.
class _AnimalTable extends StatelessWidget {
  const _AnimalTable({
    required this.animals,
    required this.connection,
    required this.scrollController,
  });

  final List<AnimalSummary> animals;
  final GameConnectionService connection;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    // A rule after every row, not just between rows (i.e. not
    // ListView.separated), so the last row gets its own bottom border
    // too instead of ending bare against GameWindowBox's own outer
    // border — per user request.
    return ListView.builder(
      controller: scrollController,
      itemCount: animals.length,
      itemBuilder: (context, index) => _AnimalRow(
        animal: animals[index],
        portraitUrl: connection.animalSpriteUrl(animals[index].type),
        heartFilledUrl: connection.iconUrl('heart-filled'),
        heartEmptyUrl: connection.iconUrl('heart-empty'),
        handCursorUrl: connection.iconUrl('hand-cursor'),
        pettingStatusUnpetUrl: connection.iconUrl('petting-status-unpet'),
        pettingStatusPetUrl: connection.iconUrl('petting-status-pet'),
        horizontalRuleUrl: connection.iconUrl('table-divider-h'),
        verticalRuleUrl: connection.iconUrl('table-divider-v'),
      ),
    );
  }
}

/// A row divider — the real vanilla menu-partition crop
/// (`UiIconCache`'s `table-divider-h`, see `AnimalsScreen`'s doc
/// comment), tiled across its given width via `ImageRepeat.repeatX`
/// at its native pixel size (see `_dividerRuleSize`'s doc comment) —
/// the same "many small tiles in a row" technique vanilla's own
/// `drawHorizontalPartition` uses, not one image squashed thin. An
/// earlier version stretched the full crop with `BoxFit.fill` into a
/// flat 6px-tall box instead; squashing the crop's actual pixel detail
/// down that far (with nearest-neighbor sampling) is what made it read
/// as a flat line rather than the beveled wood-grain divider vanilla
/// actually draws. Falls back to the previous flat wood-colored 1px
/// line while disconnected or if the crop fails to load, same fallback
/// pattern as every other real-sprite widget in this file.
///
/// `_AnimalRow` now places one instance under each of its three
/// columns (rather than one instance spanning the whole row) so each
/// column ends up the same total height as its neighbors — see
/// `_AnimalRow`'s doc comment. The three segments tile
/// the same flat two-tone crop independently from each of their own
/// left edges, which reads as one continuous line since the crop has
/// no directional texture that would show a seam at the column
/// boundaries.
class _HorizontalRule extends StatelessWidget {
  const _HorizontalRule({this.url});

  final String? url;

  /// How much vertical space is actually reserved for this divider —
  /// independent of [_dividerRuleSize], which is still used below as
  /// the *native* height the sprite is decoded/tiled at (kept at full
  /// native resolution, `scale: _dividerRuleTileScale` == 1.0, so the
  /// line art stays crisp instead of getting downscaled/blurred). The
  /// [ClipRect]+[OverflowBox] pair lets the image render at that full
  /// native height while only this much of it actually gets laid out
  /// — the rest is clipped rather than shrunk, which is what
  /// decreasing [_dividerRuleSize] itself did (that shrinks the sprite
  /// along with the box, matching what a smaller `scale` also does).
  /// Reserving the *entire* `_dividerRuleSize` here (as an earlier
  /// round did) turned every row's trailing divider into a mostly-
  /// blank 64px-tall band, since the tile's actual opaque line/bevel
  /// art doesn't fill its whole native crop height — that's what was
  /// making rows look so sparse. Not decompile-confirmed exactly how
  /// tall the opaque art within the tile is or where it sits —
  /// centered here as a reasonable guess; nudge this value (or the
  /// `Alignment.center` below) if the line still looks clipped or
  /// off-center.
  static const double _visibleHeight = 8.0;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(height: 1, color: StardewColors.wood);

    if (url == null) {
      return SizedBox(height: _visibleHeight, child: fallback());
    }

    return SizedBox(
      height: _visibleHeight,
      child: ClipRect(
        child: OverflowBox(
          minHeight: 0,
          maxHeight: _dividerRuleSize,
          alignment: Alignment.center,
          child: Image.network(
            url!,
            scale: _dividerRuleTileScale,
            repeat: ImageRepeat.repeatX,
            alignment: Alignment.centerLeft,
            filterQuality: FilterQuality.none,
            errorBuilder: (context, error, stackTrace) => fallback(),
          ),
        ),
      ),
    );
  }
}

/// A column divider — same real-sprite-with-flat-line-fallback approach
/// as [_HorizontalRule], tiled vertically instead (`ImageRepeat.repeatY`
/// on `table-divider-v`). `_AnimalRow` gives this an explicit height
/// (`_AnimalRow._rowHeight`) rather than letting it size itself, so it
/// always matches the row's own real content — see `_AnimalRow`'s doc
/// comment for why that's a fixed constant rather than something
/// measured at runtime (`IntrinsicHeight` seems like the obvious tool
/// for that, but it's incompatible with this widget's own
/// `OverflowBox` below — don't reach for it here again).
class _VerticalRule extends StatelessWidget {
  const _VerticalRule({this.url});

  final String? url;

  /// Mirrors [_HorizontalRule._visibleHeight] — how wide this rule
  /// actually renders, cropped down from the full native
  /// `_dividerRuleSize` via [ClipRect]+[OverflowBox] below rather than
  /// shrunk via `scale`, so the line stays crisp at full native
  /// resolution. `_AnimalRow` reserves a slightly wider
  /// `_dividerRuleGapWidth` column gap than this and centers the rule
  /// within it — see `_dividerRuleSize`'s own doc comment for the same
  /// not-decompile-confirmed caveat on this guess.
  static const double _visibleWidth = 8.0;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(width: 1, color: StardewColors.wood);

    if (url == null) {
      return SizedBox(width: _visibleWidth, child: fallback());
    }

    return SizedBox(
      width: _visibleWidth,
      child: ClipRect(
        child: OverflowBox(
          minWidth: 0,
          maxWidth: _dividerRuleSize,
          alignment: Alignment.center,
          child: Image.network(
            url!,
            scale: _dividerRuleTileScale,
            repeat: ImageRepeat.repeatY,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.none,
            errorBuilder: (context, error, stackTrace) => fallback(),
          ),
        ),
      ),
    );
  }
}

/// One row of the table's grid — portrait+name (flexible), a 5-heart
/// friendship meter, and a hand-cursor + petting-status-glyph "needs
/// petting" status column, PLUS the row's own share of the grid lines:
/// a single [_HorizontalRule] spans the row's FULL width along the
/// bottom, and a [_VerticalRule] sits between each pair of columns —
/// no separate grid-drawing widget above this one anymore
/// (`CompanionScreen`'s own outer `GameWindowBox` still provides the
/// panel background behind everything).
///
/// This owns its own grid lines — CORRECTED (per user suggestion) from
/// three earlier rounds that instead computed the vertical rules'
/// positions in `_AnimalTable` and overlaid them from outside each row
/// (see that class's doc comment for the bugs that produced).
///
/// CHANGED again from a version that gave every column its own
/// trailing `_HorizontalRule` segment instead of one shared one — that
/// seemed reasonable (the doc comment on that version claimed the
/// three segments "read as one continuous line since the crop has no
/// directional texture that would show a seam at the column
/// boundaries"), but that claim was wrong in a way static review
/// didn't catch: the segments only cover their OWN column's width.
/// The gap between columns — where `verticalDivider()` puts its
/// `_VerticalRule` — was never covered by ANY `_HorizontalRule` at
/// all, because `verticalDivider()` only reserved `_rowHeight` (the
/// content band), not `_rowHeight` plus the trailing rule band beneath
/// it. That left a real notch of plain background at every single
/// column boundary, for the exact height of the horizontal rule — not
/// a rendering-order illusion, an actual gap. It wasn't visible in a
/// quick glance at a screenshot (the vertical rule's own dark band
/// happens to line up with the horizontal rule's dark half, so the
/// dark-to-dark join looked fine), but pixel-sampling a live render
/// confirmed the rule's lighter half was simply missing at every
/// column boundary — confirmed by the user reporting "borders have to
/// be connected" even after that version shipped.
///
/// Lesson: don't split a rule that needs to look continuous into
/// independently-positioned per-column segments with gaps between
/// them — draw it once, full width, and let the columns sit on top of
/// (or beside) it instead.
///
/// The whole row is a [Column]: a fixed-height [Row] of the three
/// columns plus their `_VerticalRule`s, then one [_HorizontalRule]
/// stretched (`crossAxisAlignment: stretch`) to the Column's full
/// width beneath it. Every column's content and every `_VerticalRule`
/// share the exact same explicit [_rowHeight] (see that constant's
/// doc comment) via the Row's own `crossAxisAlignment: stretch` rather
/// than being measured and matched dynamically — an `IntrinsicHeight`
/// wrapper is the obvious way to get that "stretch to match the
/// tallest sibling" effect without hardcoding a number, and an earlier
/// version of this fix used exactly that, but it crashed:
/// `IntrinsicHeight` queries every descendant's intrinsic height, and
/// `_VerticalRule`'s internal `OverflowBox` (see that class's doc
/// comment) doesn't support that query — Flutter throws rather than
/// doing something silently wrong there, which is what emptied the
/// animal list. Since every row here is sized from fixed constants,
/// not variable content, there was never anything to actually
/// *measure* at runtime — [_rowHeight] just states that fixed height
/// directly. Breathing-room padding lives *inside* each column (its
/// own `Padding`/the `_dividerRuleGapWidth` inset around each
/// `_VerticalRule`), not wrapped around the whole row, so nothing
/// shifts the grid lines out of alignment with the row's own column
/// boundaries the way whole-row padding did in an even earlier round.
class _AnimalRow extends StatelessWidget {
  const _AnimalRow({
    required this.animal,
    required this.portraitUrl,
    required this.heartFilledUrl,
    required this.heartEmptyUrl,
    required this.handCursorUrl,
    required this.pettingStatusUnpetUrl,
    required this.pettingStatusPetUrl,
    required this.horizontalRuleUrl,
    required this.verticalRuleUrl,
  });

  final AnimalSummary animal;
  final String? portraitUrl;
  final String? heartFilledUrl;
  final String? heartEmptyUrl;
  final String? handCursorUrl;
  final String? pettingStatusUnpetUrl;
  final String? pettingStatusPetUrl;
  final String? horizontalRuleUrl;
  final String? verticalRuleUrl;

  static const _heartCount = 5;

  // Fixed widths for the two right-hand columns — the name column
  // takes whatever's left (see the Expanded below). Hearts: 5 hearts
  // at _Heart's own 14px width + 1px gaps between them. Status: one
  // hand-cursor badge plus a little breathing room either side.
  static const double _heartsColumnWidth =
      _heartCount * _Heart._spriteWidth + (_heartCount - 1);
  static const double _statusColumnWidth = 64.0;

  // Shared width for both status-column icon slots (see the Column
  // below) — matches _PettingBadge's and _PettingStatusIcon's now-equal
  // _size (bumped from 13 to 20 per user request, to match the
  // hand-cursor badge above it), so both icons center on the same
  // width regardless of any off-center padding baked into either
  // sprite crop.
  static const _statusIconSlotWidth = 20.0;

  /// Every column's content is forced to this same height (via the
  /// Row's own `crossAxisAlignment: stretch` in `build` below) before
  /// its own 6px top/bottom padding is added, so all three columns'
  /// (and both `_VerticalRule`s') combined heights agree exactly —
  /// CHANGED from an `IntrinsicHeight`-measured version of this same
  /// idea, which crashed: `IntrinsicHeight` queries every descendant's
  /// own intrinsic height to find the max, and `_VerticalRule`'s
  /// internal `OverflowBox` (see that class's doc comment) explicitly
  /// doesn't support that query — Flutter throws rather than silently
  /// doing something wrong there, which is what emptied the list.
  /// Since every row here is sized from fixed constants, not variable
  /// content (the name `Text` is a single non-wrapping line), there's
  /// no actual need to *measure* anything at runtime: this is just
  /// [_Portrait._slotHeight], the tallest thing any column ever draws,
  /// named here so it stays obviously in sync with that constant
  /// rather than duplicating its value blindly.
  static const double _columnContentHeight = _Portrait._slotHeight;

  /// [_columnContentHeight] plus the 6px top/bottom padding every
  /// column's content gets (see `columnContent` below) — the height
  /// given to the row of columns (and, via `crossAxisAlignment:
  /// stretch`, to every `_VerticalRule` alongside them) BEFORE the
  /// row's single shared trailing [_HorizontalRule] beneath it. CHANGED
  /// from a version where this was also independently applied to each
  /// column's own `_HorizontalRule` segment — see `_AnimalRow`'s own
  /// doc comment for why per-column rule segments were replaced with
  /// one shared full-width rule (they left real gaps in the line at
  /// every column boundary).
  static const double _rowHeight = _columnContentHeight + 12;

  @override
  Widget build(BuildContext context) {
    final nameStyle = DefaultTextStyle.of(context).style
        .apply(fontSizeFactor: 1.75);
    // One column's own content, padded — no rule of its own anymore
    // (see this class's doc comment: a single [_HorizontalRule] now
    // spans the whole row instead of one segment per column). `width`
    // bounds the column to a fixed width when this call isn't wrapped
    // in `Expanded` by its caller (the hearts/status columns below).
    // Without it, a non-Expanded `Row` child gets Flutter's standard
    // UNBOUNDED main-axis width — this was the root cause of a
    // "BoxConstraints forces an infinite width" crash the first time
    // grid-line ownership moved into this widget (that version's
    // per-column `_HorizontalRule` had no width of its own and
    // inherited the unbounded width via `crossAxisAlignment: stretch`;
    // this version has no per-column rule to crash, but the same
    // unbounded-width hazard still applies to any wide content a
    // future column might add, so the guard stays).
    Widget columnContent(Widget content, {double? width}) {
      final padded = Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: content,
      );
      return width == null ? padded : SizedBox(width: width, child: padded);
    }

    // A vertical rule plus its own _dividerRuleGapWidth-wide breathing
    // room — see _dividerRuleGapWidth's and _VerticalRule's own doc
    // comments. Height comes from the surrounding Row's own
    // `crossAxisAlignment: stretch` (via the SizedBox(height:
    // _rowHeight) wrapping that Row in `build` below) rather than an
    // explicit SizedBox here, so it always matches the row of columns
    // exactly with no separate constant to keep in sync.
    Widget verticalDivider() => Padding(
      padding: EdgeInsets.symmetric(
        horizontal: (_dividerRuleGapWidth - _VerticalRule._visibleWidth) / 2,
      ),
      child: _VerticalRule(url: verticalRuleUrl),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _rowHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: columnContent(
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      children: [
                        _Portrait(url: portraitUrl),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                animal.name.isEmpty ? 'n/a' : animal.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: nameStyle,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              verticalDivider(),
              columnContent(
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < _heartCount; i++) ...[
                      if (i > 0) const SizedBox(width: 1),
                      _Heart(
                        filled: animal.isHeartFilled(i),
                        half: animal.isHeartHalf(i),
                        emptyUrl: heartEmptyUrl,
                        filledUrl: heartFilledUrl,
                      ),
                    ],
                  ],
                ),
                width: _heartsColumnWidth,
              ),
              verticalDivider(),
              columnContent(
                Transform.translate(
                  offset: const Offset(
                    -4,
                    0,
                  ), // visual tweak to match reference
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    // Both children share this exact width (badge and status
                    // icon both 20px now) so their horizontal centers land on
                    // the same pixel regardless of any off-center padding
                    // baked into either sprite crop — see this column's own
                    // doc comment on _AnimalRow.
                    children: [
                      SizedBox(
                        width: _statusIconSlotWidth,
                        child: Row(
                          children: [
                            Center(
                              child: _PettingBadge(
                                needsPetting: !animal.wasPet,
                                iconUrl: handCursorUrl,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: _statusIconSlotWidth,
                        child: Center(
                          child: _PettingStatusIcon(
                            pet: animal.wasPet,
                            unpetUrl: pettingStatusUnpetUrl,
                            petUrl: pettingStatusPetUrl,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                width: _statusColumnWidth,
              ),
            ],
          ),
        ),
        _HorizontalRule(url: horizontalRuleUrl),
      ],
    );
  }
}

/// The animal's real portrait sprite (`GameConnectionService.
/// animalSpriteUrl`), falling back to a generic pets icon while
/// disconnected or before the mod has cropped that breed yet — same
/// fallback pattern as every other real-sprite widget in this app (see
/// `InventorySlot`'s doc comment).
///
/// CORRECTED after an in-app screenshot showed a house pet's portrait
/// looking noticeably *smaller* than a farm animal's despite a cat
/// visually being the bigger creature — the earlier version forced
/// every crop through `BoxFit.contain` into one identical square box,
/// which independently stretches/shrinks each image to fill that box
/// by its own aspect ratio. That discards the size information the
/// real crop rects themselves encode (see `AnimalIconCache`'s doc
/// comment): a short farm animal's compact `16x16` crop got scaled up
/// 2x to fill the box, while a pet's real, *wider* `32x24` crop
/// (`AnimalPage`'s own pet-portrait formula keeps the sprite's full
/// frame width) was already box-width-sized and so wasn't scaled up
/// at all — a chicken and a cat ended up rendered at the same on-screen
/// width despite the cat's raw crop being twice as wide.
///
/// This now applies one fixed [_pixelScale] multiplier to every
/// animal's real (PNG-intrinsic) crop size instead — the same way
/// `AnimalPage.drawNPCSlot` itself draws every row's portrait at one
/// shared draw scale rather than independently normalizing each one,
/// so a farm animal's taller/wider real crop reads as a taller/wider
/// icon, matching relative size differences vanilla's own crop rects
/// were designed to convey. `FittedBox`'s `BoxFit.scaleDown` is only a
/// safety net for an unexpectedly large crop overflowing the row (it
/// never *enlarges* a small one), so it doesn't reintroduce the same
/// per-animal normalization this correction removes.
class _Portrait extends StatelessWidget {
  const _Portrait({required this.url});

  final String? url;

  /// Device pixels rendered per source-sprite pixel, the same for
  /// every animal. `filterQuality: FilterQuality.none` below keeps the
  /// upscale crisp/nearest-neighbor rather than blurring these small
  /// pixel-art crops.
  static const _pixelScale = 2.0;

  /// Reserves a consistent column width/height across rows regardless
  /// of each animal's real (and varying) crop size, so names still
  /// start at the same x position and rows stay a consistent height —
  /// sized to comfortably fit the largest real crop this app currently
  /// serves at [_pixelScale] without the `FittedBox` safety net ever
  /// needing to shrink it (pet: `32x24` → `64x48`; a tall farm animal:
  /// up to `~16x28` → `~32x56`).
  static const _slotWidth = 64.0;
  static const _slotHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    Widget fallback() =>
        const Icon(Icons.pets, size: 22, color: StardewColors.wood);

    return SizedBox(
      width: _slotWidth,
      height: _slotHeight,
      child: Center(
        child: url == null
            ? fallback()
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Image.network(
                  url!,
                  scale: 1 / _pixelScale,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (context, error, stackTrace) => fallback(),
                ),
              ),
      ),
    );
  }
}

/// One heart in the 5-heart friendship meter — filled, half-filled, or
/// empty. Real vanilla sprite crop preferred (`UiIconCache`'s
/// `heart-filled`/`heart-empty` entries), same fallback-to-flat-tint
/// pattern as `_Pip` in the Skills screen when the sprite hasn't
/// loaded.
///
/// A half-filled heart is built from each sprite's own half — the
/// filled sprite's left half plus the empty sprite's right half, laid
/// side by side — rather than one full sprite with the other stacked
/// on top of it. That distinction matters because the empty sprite
/// isn't a solid grey heart; it's a *hollow outline* (opaque border,
/// fully transparent interior — the same shape every fully-empty
/// heart elsewhere in the row already renders as). CORRECTED (round
/// three) after a real-device screenshot showed exactly what that
/// implies: with the filled sprite drawn full-width as an unclipped
/// base layer and only the empty sprite clipped to the right half on
/// top of it, the empty overlay's opaque *border* pixels correctly
/// painted grey over that half — but its transparent *interior*
/// pixels covered nothing, so the filled layer's solid red interior
/// kept showing straight through underneath. The result looked like a
/// fully-filled heart with a grey border grafted onto its right edge,
/// which is exactly what got reported. Clipping the filled sprite to
/// its own left half too (instead of leaving it as the unclipped
/// base) removes the "always-visible full-width base layer" that was
/// bleeding through in the first place: the right half now shows
/// nothing but the empty sprite's own hollow outline, background
/// showing through its interior exactly like a genuinely empty heart
/// does.
///
/// Both halves use the same `Align(widthFactor: 0.5)` + `ClipRect`
/// trick (see round two's note below on why, and why a `CustomClipper`
/// was dropped for it) — `Alignment.centerLeft` for the filled half,
/// `Alignment.centerRight` for the empty half — but now laid out with
/// a `Row` instead of a `Stack`. A `Stack` was fine (with an explicit
/// `alignment`) back when only one child needed positioning off-center
/// — the filled layer filled the whole box either way, so the Stack's
/// own `alignment` only had to steer the one half-width `ClipRect`.
/// With *two* half-width, differently-positioned clip boxes now, a
/// `Row` sequences them left-to-right with no positioning ambiguity to
/// get wrong a third time, instead of needing a second `Positioned` or
/// a repeat of the round-two alignment bug for the new left-hand box.
///
/// Round two's finding still holds and is why this isn't back to a
/// single `CustomClipper<Rect>` spanning the full box: `Align`'s
/// `widthFactor` needs *loose* incoming constraints to let its child
/// lay out at full natural size and overflow (only then does the
/// overflow-plus-`ClipRect` trick have something to clip); a `Row`
/// gives its non-flexible children exactly that (unbounded main-axis
/// constraints), the same as the `Stack` it replaced did for its own
/// non-positioned children.
class _Heart extends StatelessWidget {
  const _Heart({
    required this.filled,
    required this.half,
    required this.emptyUrl,
    required this.filledUrl,
  });

  final bool filled;
  final bool half;
  final String? emptyUrl;
  final String? filledUrl;
  static const _spriteWidth = 20.0;
  static const _spriteHeight = 18.0;

  // Native crop is 7x6 — see UiIconCache's "heart-filled"/"heart-empty"
  // entries.
  static const _size = Size(_spriteWidth, _spriteHeight);

  @override
  Widget build(BuildContext context) {
    Widget fallbackFor(bool isFilled) => DecoratedBox(
      decoration: BoxDecoration(
        color: isFilled ? StardewColors.accentRed : StardewColors.woodDark,
        borderRadius: BorderRadius.circular(1),
      ),
    );

    // Always an explicit `_size`-sized box — see this class's own doc
    // comment for why an implicitly-sized `Image.network` (relying on
    // ambient Stack/BoxFit constraints to land on the right size) was
    // the root of the original half-heart split bug this replaced.
    Widget spriteOrFallback(String? url, bool isFilled) => SizedBox(
      width: _size.width,
      height: _size.height,
      child: url == null
          ? fallbackFor(isFilled)
          : Image.network(
              url,
              width: _size.width,
              height: _size.height,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
              errorBuilder: (context, error, stackTrace) =>
                  fallbackFor(isFilled),
            ),
    );

    // Clips `sprite` to just the half of its own box nearest `side`,
    // by way of the same "let the child overflow past a halved
    // Align, then hard-clip it" trick this class's own doc comment
    // walks through — see there for why a `Row` (not a `Stack`) is
    // what positions the two halves this returns for relative to each
    // other.
    Widget halfOf(Widget sprite, Alignment side) => ClipRect(
      child: Align(alignment: side, widthFactor: 0.5, child: sprite),
    );

    return SizedBox(
      width: _size.width,
      height: _size.height,
      child: half
          ? Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                halfOf(spriteOrFallback(filledUrl, true), Alignment.centerLeft),
                halfOf(spriteOrFallback(emptyUrl, false), Alignment.centerRight),
              ],
            )
          : spriteOrFallback(filled ? filledUrl : emptyUrl, filled),
    );
  }
}

/// The per-row "needs petting" hand-cursor icon — vanilla's own real
/// `AnimalPage.drawNPCSlot` cursor sprite (see `UiIconCache`'s
/// `hand-cursor` entry for the exact rect and its own correction
/// history). Drawn at full opacity unconditionally, matching real
/// vanilla — CORRECTED from an earlier round that faded it to a third
/// opacity once the animal had been pet, on the mistaken assumption
/// vanilla dims this icon as an "actionable vs. done" affordance; it
/// doesn't — `AnimalPage.drawNPCSlot` draws this icon the same way
/// every row regardless of pet status, and lets the separate status
/// glyph below it (see [_PettingStatusIcon]) carry the pet/not-pet
/// signal instead. [needsPetting] now only tints this widget's
/// disconnected/error fallback icon, not the real sprite.
class _PettingBadge extends StatelessWidget {
  const _PettingBadge({required this.needsPetting, required this.iconUrl});

  final bool needsPetting;
  final String? iconUrl;

  // Shares the status column with _PettingStatusIcon below it now, so
  // smaller than this widget's original standalone size (24) to leave
  // the two room to stack without crowding a ~40px-wide column.
  static const _size = 20.0;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Icon(
      Icons.back_hand,
      size: 16,
      color: needsPetting
          ? StardewColors.accentRed
          : StardewColors.wood.withValues(alpha: 0.35),
    );

    return iconUrl == null
        ? fallback()
        : Image.network(
            iconUrl!,
            width: _size,
            height: _size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
            errorBuilder: (context, error, stackTrace) => fallback(),
          );
  }
}

/// The per-row petting-status glyph the reference screenshot draws
/// under the status column's hand-cursor icon — CORRECTED twice now:
/// first from purely decorative to real (a follow-up reference
/// screenshot showed a green checkmark for an already-pet animal), and
/// then, this round, from an entirely wrong real sprite to the correct
/// one. That first fix rendered `StardewValley.Menus.OptionsCheckbox`'s
/// generic real checkbox sprite, on the assumption this was a generic
/// checkbox reused here — a reasonable-looking guess (green box, dark
/// tick) that's nonetheless not what vanilla itself draws in this
/// specific menu. The real, decompiled `AnimalPage.drawNPCSlot` reveals
/// a dedicated, purpose-built icon instead, on a different sheet
/// (`Game1.mouseCursors_1_6`, not `Game1.mouseCursors`) at
/// `Rectangle(273 + WasPetYet * 9, 253, 9, 9)` — a real 3-state glyph
/// (not-pet / auto-pet / hand-pet) this app's own `AnimalSummary.wasPet`
/// bool only distinguishes two of (see `UiIconCache`'s
/// `petting-status-unpet`/`petting-status-pet` entries for the rects
/// this widget actually uses).
///
/// This *is* reading the same underlying `wasPet` field the
/// hand-cursor icon above it already reads (see `_PettingBadge`'s doc
/// comment) — not a second, different signal — but the two aren't a
/// redundant pair: `AnimalPage.drawNPCSlot` itself draws both, every
/// row, unconditionally — the hand-cursor as a constant "you can pet
/// this" affordance, this glyph as the actual pet/not-pet state.
class _PettingStatusIcon extends StatelessWidget {
  const _PettingStatusIcon({
    required this.pet,
    required this.unpetUrl,
    required this.petUrl,
  });

  final bool pet;
  final String? unpetUrl;
  final String? petUrl;

  // Matches _PettingBadge's own _size — see _statusIconSlotWidth's doc
  // comment on _AnimalRow for why the two are kept equal.
  static const _size = 20.0;

  @override
  Widget build(BuildContext context) {
    // Same outlined-square look this widget always had, as the
    // fallback while disconnected or if the sprite crop fails to load
    // — a plain green-tinted fill/border swap stands in for the real
    // pet/unpet sprite pair.
    Widget fallback() => Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: pet ? StardewColors.accentGreen : StardewColors.parchment,
        border: Border.all(color: StardewColors.wood, width: 1.5),
      ),
    );

    final url = pet ? petUrl : unpetUrl;

    return SizedBox(
      width: _size,
      height: _size,
      child: url == null
          ? fallback()
          : Image.network(
              url,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
              errorBuilder: (context, error, stackTrace) => fallback(),
            ),
    );
  }
}

/// A narrow rail to the right of the table with the game's own large
/// scroll-up/scroll-down arrows and a thin track between them — mirrors
/// the reference screenshot's own scrollbar, and doubles as a tap
/// target that nudges the list (see `_AnimalsScreenState._scrollBy`).
class _ScrollRail extends StatelessWidget {
  const _ScrollRail({
    required this.upIconUrl,
    required this.downIconUrl,
    required this.onScrollUp,
    required this.onScrollDown,
  });

  final String? upIconUrl;
  final String? downIconUrl;
  final VoidCallback onScrollUp;
  final VoidCallback onScrollDown;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: Column(
        children: [
          _ScrollArrowButton(
            iconUrl: upIconUrl,
            fallbackIcon: Icons.keyboard_arrow_up,
            onTap: onScrollUp,
          ),
          Expanded(
            child: Center(
              child: Container(width: 3, color: StardewColors.woodDark),
            ),
          ),
          _ScrollArrowButton(
            iconUrl: downIconUrl,
            fallbackIcon: Icons.keyboard_arrow_down,
            onTap: onScrollDown,
          ),
        ],
      ),
    );
  }
}

class _ScrollArrowButton extends StatelessWidget {
  const _ScrollArrowButton({
    required this.iconUrl,
    required this.fallbackIcon,
    required this.onTap,
  });

  final String? iconUrl;
  final IconData fallbackIcon;
  final VoidCallback onTap;

  static const _size = 26.0;

  @override
  Widget build(BuildContext context) {
    Widget fallback() =>
        Icon(fallbackIcon, size: 22, color: StardewColors.textBrown);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: iconUrl == null
            ? fallback()
            : Image.network(
                iconUrl!,
                width: _size,
                height: _size,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
                errorBuilder: (context, error, stackTrace) => fallback(),
              ),
      ),
    );
  }
}
