/// A single item slot as reported by the StardewDS SMAPI mod.
class InventoryItem {
  const InventoryItem({
    required this.name,
    required this.quantity,
    this.iconId,
    this.qualifiedItemId,
    this.waterLeft,
    this.waterLeftMax,
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
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        if (iconId != null) 'iconId': iconId,
        if (qualifiedItemId != null) 'qualifiedItemId': qualifiedItemId,
        if (waterLeft != null) 'waterLeft': waterLeft,
        if (waterLeftMax != null) 'waterLeftMax': waterLeftMax,
      };
}
