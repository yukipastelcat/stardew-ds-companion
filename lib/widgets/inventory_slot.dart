import 'package:flutter/material.dart';

import '../models/inventory_item.dart';
import '../theme/stardew_colors.dart';

/// A single square backpack slot, drawn with the game's own slot frame
/// (see `GameConnectionService.slotFrameUrl`) and, for a slot beyond the
/// player's current backpack capacity, the same darkened overlay the
/// vanilla inventory menu composites on top at half opacity — plus the
/// item's real sprite, a stack-count badge for stackable items, and —
/// for a Watering Can — the real in-game water-level gauge
/// (`WateringCan.drawInMenu`'s own frame + fill, not a fabricated bar).
///
/// The currently selected/equipped slot swaps in the real vanilla
/// hotbar's own highlighted-slot frame (`GameConnectionService.
/// slotSelectedFrameUrl` — tile 56 on `Game1.menuTexture`, in place of
/// the normal tile-10 frame, exactly how `Toolbar.draw` does it) instead
/// of drawing a border on top — no fabricated highlight color. The
/// item sprite itself also grows to nearly fill the slot (thinner
/// padding) once selected, animated over a short duration.
///
/// Two more real-game touches: a quality star badge (silver/gold/
/// iridium — `Object.drawInMenu`'s own icon, cropped by the mod's
/// `UiIconCache`) in the slot's bottom-left corner for anything with
/// [InventoryItem.quality] set, and — for a melee weapon still
/// recovering from its special move (sword block, dagger stab, club
/// pound) — the same red "reloading" wipe vanilla's own
/// `MeleeWeapon.drawInMenu` draws over the icon (`Color.Red` at 66%
/// opacity, anchored to the bottom edge and shrinking upward as
/// [InventoryItem.cooldownFraction] counts down to 0), reproduced here
/// as a plain color overlay rather than a sprite since that's what the
/// real effect actually is.
class InventorySlot extends StatelessWidget {
  const InventorySlot({
    super.key,
    required this.item,
    required this.locked,
    this.selected = false,
    this.spriteUrl,
    this.frameUrl,
    this.selectedFrameUrl,
    this.lockedOverlayUrl,
    this.qualityStarUrl,
    this.wateringCanGaugeUrl,
    this.onTap,
  });

  final InventoryItem? item;

  /// True when this slot's index is at/beyond `GameState.backpackSize`
  /// — an unpurchased backpack row that can't hold an item.
  final bool locked;

  /// Whether this is the item currently equipped/active in-game.
  final bool selected;

  /// Real in-game sprite for [item] (`GameConnectionService.spriteUrl`).
  final String? spriteUrl;

  /// Real in-game slot background frame (`GameConnectionService.slotFrameUrl`).
  final String? frameUrl;

  /// Real in-game highlighted-slot frame (`GameConnectionService.slotSelectedFrameUrl`)
  /// — used in place of [frameUrl], not on top of it, when [selected].
  final String? selectedFrameUrl;

  /// Real in-game locked-row overlay (`GameConnectionService.slotLockedOverlayUrl`).
  final String? lockedOverlayUrl;

  /// Real in-game quality star badge for [item] (`GameConnectionService.qualityStarUrl`) — null when [item] has no quality (or is locked/empty).
  final String? qualityStarUrl;

  /// Real in-game watering-can water-gauge frame (`GameConnectionService.wateringCanGaugeUrl`)
  /// — the exact crop `WateringCan.drawInMenu` draws behind its own
  /// water-level fill. Only ever shown when [item] reports a
  /// [InventoryItem.waterFraction]; the fill bar itself is drawn as a
  /// plain solid color, not a second sprite (see `_WaterGauge`).
  final String? wateringCanGaugeUrl;

  final VoidCallback? onTap;

  /// Padding around the item sprite in a normal (unselected) slot —
  /// leaves room for the frame's own border art.
  static const double _spritePadding = 5;

  /// Padding around the item sprite when this slot is [selected] — 1px
  /// per side, so the sprite renders at exactly the slot size minus 2px,
  /// echoing the vanilla game's own enlarged look for the equipped
  /// hotbar item.
  static const double _selectedSpritePadding = 1;

  /// Inset of the quality star badge from the slot's bottom-left corner
  /// — mirrors [_StackCountText]'s bottom-right inset (`bottom: 1, right: 3`)
  /// so the two badges read as a matched pair.
  static const double _qualityBadgeInset = 2;

  /// Rendered size of the quality star badge — the real sprite is a
  /// native 8x8 crop; scaled up slightly (nearest-neighbor, no blur) so
  /// it stays legible at the app's much larger slot size than vanilla's
  /// own ~64px inventory menu.
  static const double _qualityBadgeSize = 12;

  static const _fallbackFrameDecoration = BoxDecoration(
    color: StardewColors.slotFill,
    border: Border.fromBorderSide(BorderSide(color: StardewColors.slotBorder, width: 2)),
    borderRadius: BorderRadius.all(Radius.circular(4)),
  );

  /// Fallback for the selected slot when [selectedFrameUrl] is null or
  /// fails to load (disconnected, or the mod hasn't rendered it yet) —
  /// only used until then, not a permanent stand-in for the real frame.
  static const _fallbackSelectedFrameDecoration = BoxDecoration(
    color: StardewColors.slotFill,
    border: Border.fromBorderSide(BorderSide(color: StardewColors.accentGreen, width: 2)),
    borderRadius: BorderRadius.all(Radius.circular(4)),
  );

  @override
  Widget build(BuildContext context) {
    final slot = AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _frame(),
              if (locked)
                Opacity(opacity: 0.5, child: _lockedOverlay()),
              if (!locked && item != null)
                AnimatedPadding(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.all(selected ? _selectedSpritePadding : _spritePadding),
                  child: _sprite(),
                ),
              if (!locked && (item?.cooldownFraction ?? 0) > 0)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: _CooldownWipe(fraction: item!.cooldownFraction!),
                ),
              if (!locked && (item?.quantity ?? 0) > 1)
                Positioned(
                  bottom: 1,
                  right: 3,
                  child: _StackCountText('${item!.quantity}'),
                ),
              if (!locked && item?.waterFraction != null)
                Positioned.fill(
                  child: _WaterGauge(
                    fraction: item!.waterFraction!,
                    isBottomless: item!.waterCanIsBottomless,
                    frameUrl: wateringCanGaugeUrl,
                  ),
                ),
              if (!locked && item != null && qualityStarUrl != null)
                Positioned(
                  bottom: _qualityBadgeInset,
                  left: _qualityBadgeInset,
                  width: _qualityBadgeSize,
                  height: _qualityBadgeSize,
                  child: Image.network(
                    qualityStarUrl!,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (locked || item?.name == null) return slot;
    return Tooltip(message: item!.name, child: slot);
  }

  Widget _frame() {
    // Real vanilla behavior (see the class doc comment): the selected
    // slot's highlighted frame *replaces* the normal frame, it isn't
    // drawn on top of it — so this picks one URL, not both.
    final url = (selected ? selectedFrameUrl : null) ?? frameUrl;
    if (url == null) {
      return DecoratedBox(decoration: selected ? _fallbackSelectedFrameDecoration : _fallbackFrameDecoration);
    }
    return Image.network(
      url,
      fit: BoxFit.fill,
      // Pixel art, not a photo — nearest-neighbor sampling keeps the
      // crop's hard edges instead of blurring them.
      filterQuality: FilterQuality.none,
      errorBuilder: (context, error, stackTrace) =>
          DecoratedBox(decoration: selected ? _fallbackSelectedFrameDecoration : _fallbackFrameDecoration),
    );
  }

  Widget _lockedOverlay() {
    if (lockedOverlayUrl == null) {
      return const DecoratedBox(decoration: BoxDecoration(color: Colors.black));
    }
    return Image.network(
      lockedOverlayUrl!,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
      errorBuilder: (context, error, stackTrace) => const DecoratedBox(decoration: BoxDecoration(color: Colors.black)),
    );
  }

  Widget _sprite() {
    if (spriteUrl == null) return const SizedBox.shrink();
    return Image.network(
      spriteUrl!,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

/// The real vanilla "reloading" cooldown overlay a melee weapon's own
/// `drawInMenu` draws while its special move is recovering: a
/// translucent red rectangle anchored to the slot's bottom edge, sized
/// to [fraction] of the slot's full height (1 = special just used,
/// covering the whole icon; shrinking toward 0 as the real vanilla
/// per-type cooldown timer — `defenseCooldown`, `daggerCooldown` or
/// `clubCooldown` — counts down), so the icon gets visibly "uncovered"
/// from the top down as the weapon becomes usable again — the exact
/// same math as `Game1.staminaRect` drawn at `Color.Red * 0.66f`, just
/// as a solid color box instead of a 1x1 tinted texture (there's no
/// sprite to crop here — the real effect already is a flat color fill).
class _CooldownWipe extends StatelessWidget {
  const _CooldownWipe({required this.fraction});

  /// 0-1; already clamped by the mod before it reaches the app, but
  /// clamped again here defensively since this drives a layout size.
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: fraction.clamp(0.0, 1.0),
        widthFactor: 1.0,
        child: const ColoredBox(color: Color(0xA8FF0000)), // Color.Red @ ~66% alpha
      ),
    );
  }
}

/// White text with a dark drop shadow — the same look the vanilla game
/// uses for its own stack-count numbers, so it stays readable over any
/// item sprite or background.
class _StackCountText extends StatelessWidget {
  const _StackCountText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        shadows: [Shadow(color: Colors.black87, offset: Offset(1, 1))],
      ),
    );
  }
}

/// The real vanilla watering-can water-level gauge: a small frame
/// (`GameConnectionService.wateringCanGaugeUrl` — the exact 14x5 crop
/// `WateringCan.drawInMenu` draws from `Game1.mouseCursors` at
/// `Rectangle(297, 420, 14, 5)`, verified against decompiled
/// `WateringCan.cs` before writing) with a solid-color fill bar drawn
/// inside it, sized to [fraction] of the frame's own inner width — same
/// approach vanilla itself uses (`Game1.staminaRect`, a 1x1 texture
/// stretched to a Rectangle, not a second sprite). Colored DodgerBlue
/// at 70% opacity normally, or BlueViolet at full opacity for an
/// enchanted bottomless can ([isBottomless]) — [WateringCan.drawInMenu]'s
/// own two-color choice.
///
/// Positioned at the same fractions of the slot vanilla's own 64px
/// reference `drawInMenu` call uses (frame at `location + (4,44)` sized
/// 56x20; fill at `location + (8,48)` sized up to 48x8), scaled here to
/// whatever pixel size this slot actually renders at via [LayoutBuilder]
/// — the same "position at a fraction of the box" approach already used
/// for the clock's date/time text and the map screen's player marker.
class _WaterGauge extends StatelessWidget {
  const _WaterGauge({
    required this.fraction,
    required this.isBottomless,
    this.frameUrl,
  });

  /// 0-1 fraction of the can's water capacity remaining.
  final double fraction;

  /// True for an enchanted bottomless can — picks the fill color.
  final bool isBottomless;

  /// Real in-game gauge frame/background; null shows just the fill.
  final String? frameUrl;

  // Vanilla reference: a 64x64 inventory slot, per `WateringCan.
  // drawInMenu`'s own hardcoded offsets/sizes.
  static const double _refSlot = 64;
  static const double _frameLeft = 4 / _refSlot;
  static const double _frameTop = 44 / _refSlot;
  static const double _frameWidth = 56 / _refSlot;
  static const double _frameHeight = 20 / _refSlot;
  static const double _fillLeft = 8 / _refSlot;
  static const double _fillTop = 48 / _refSlot;
  static const double _fillMaxWidth = 48 / _refSlot;
  static const double _fillHeight = 8 / _refSlot;

  // WateringCan.drawInMenu's own two fill colors.
  static const Color _dodgerBlue70 = Color(0xB31E90FF); // Color.DodgerBlue @ 70% alpha
  static const Color _blueViolet = Color(0xFF8A2BE2); // Color.BlueViolet, full alpha

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final clampedFraction = fraction.clamp(0.0, 1.0);
        return Stack(
          children: [
            Positioned(
              left: size.width * _frameLeft,
              top: size.height * _frameTop,
              width: size.width * _frameWidth,
              height: size.height * _frameHeight,
              child: frameUrl == null
                  ? const SizedBox.shrink()
                  : Image.network(
                      frameUrl!,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.none,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
            ),
            Positioned(
              left: size.width * _fillLeft,
              top: size.height * _fillTop,
              width: size.width * _fillMaxWidth * clampedFraction,
              height: size.height * _fillHeight,
              child: ColoredBox(color: isBottomless ? _blueViolet : _dodgerBlue70),
            ),
          ],
        );
      },
    );
  }
}
