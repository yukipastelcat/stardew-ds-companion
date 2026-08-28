/// A single item slot as reported by the StardewDS SMAPI mod.
class InventoryItem {
  const InventoryItem({
    required this.name,
    required this.quantity,
    this.iconId,
    this.qualifiedItemId,
    this.waterLeft,
    this.waterLeftMax,
    this.waterCanIsBottomless = false,
    this.quality = 0,
    this.cooldownFraction,
  });

  final String name;
  final int quantity;
  final int? iconId;

  /// The item's SDV 1.6 qualified id (e.g. "(O)24") — pass this to
  /// [GameConnectionService.spriteUrl] to fetch its real in-game icon
  /// from the mod. Null for mock/preview data, which has no mod to ask.
  final String? qualifiedItemId;

  /// Remaining/max water for a watering can; both null for anything else
  /// (or for mock/preview data).
  final int? waterLeft;
  final int? waterLeftMax;

  /// True for an enchanted bottomless watering can (never empties).
  /// Mirrors the mod's `InventorySlotDto.WaterCanIsBottomless` — picks
  /// the real vanilla water-gauge fill color (`InventorySlot`'s
  /// `_WaterGauge`): BlueViolet at full opacity here, DodgerBlue at 70%
  /// opacity otherwise, exactly matching `WateringCan.drawInMenu`.
  final bool waterCanIsBottomless;

  /// Item quality: 0=normal (no star), 1=silver, 2=gold, 4=iridium —
  /// mirrors the mod's `GameStateSnapshot.InventorySlotDto.Quality`.
  /// Only ever non-zero for the same items vanilla itself draws a
  /// quality star on (crops, fish, artisan goods, and other
  /// `StardewValley.Object` items) — tools/weapons/equipment report 0.
  /// Pass to [GameConnectionService.qualityStarUrl] for the real
  /// in-game star badge.
  final int quality;

  /// 0-1 fraction of a stabbing/defense sword's real vanilla "reloading"
  /// cooldown-wipe still remaining (1 = just blocked, counting down to 0
  /// as it recovers), or null for anything not currently on that
  /// cooldown. Mirrors the mod's `InventorySlotDto.CooldownFraction` —
  /// see that field's doc comment for why this rides the state snapshot
  /// as a plain fraction instead of a sprite URL (the real vanilla
  /// effect is a flat red color overlay, not cropped game art).
  final double? cooldownFraction;

  /// [waterLeft] / [waterLeftMax] as a 0-1 fraction, or null when this
  /// item doesn't report water state.
  double? get waterFraction {
    if (waterLeft == null || waterLeftMax == null || waterLeftMax == 0) return null;
    return (waterLeft! / waterLeftMax!).clamp(0.0, 1.0);
  }

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      name: json['name'] as String,
      quantity: json['quantity'] as int? ?? 0,
      iconId: json['iconId'] as int?,
      qualifiedItemId: json['qualifiedItemId'] as String?,
      waterLeft: json['waterLeft'] as int?,
      waterLeftMax: json['waterLeftMax'] as int?,
      waterCanIsBottomless: json['waterCanIsBottomless'] as bool? ?? false,
      quality: json['quality'] as int? ?? 0,
      cooldownFraction: (json['cooldownFraction'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        if (iconId != null) 'iconId': iconId,
        if (qualifiedItemId != null) 'qualifiedItemId': qualifiedItemId,
        if (waterLeft != null) 'waterLeft': waterLeft,
        if (waterLeftMax != null) 'waterLeftMax': waterLeftMax,
        if (waterCanIsBottomless) 'waterCanIsBottomless': waterCanIsBottomless,
        if (quality != 0) 'quality': quality,
        if (cooldownFraction != null) 'cooldownFraction': cooldownFraction,
      };
}
