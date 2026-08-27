import 'inventory_item.dart';

/// Equipped items reported by the mod, by slot. Display names are always
/// present when a slot is filled; the `*Id` fields are the item's
/// qualified id (e.g. "(O)60"), passed to
/// `GameConnectionService.spriteUrl` to fetch the real in-game icon —
/// null means either the slot is empty or (for older mod builds) ids
/// just aren't reported yet.
class EquippedItems {
  const EquippedItems({
    this.hat,
    this.hatId,
    this.leftRing,
    this.leftRingId,
    this.rightRing,
    this.rightRingId,
    this.boots,
    this.bootsId,
  });

  final String? hat;
  final String? hatId;
  final String? leftRing;
  final String? leftRingId;
  final String? rightRing;
  final String? rightRingId;
  final String? boots;
  final String? bootsId;

  factory EquippedItems.fromJson(Map<String, dynamic> json) {
    return EquippedItems(
      hat: json['hat'] as String?,
      hatId: json['hatId'] as String?,
      leftRing: json['leftRing'] as String?,
      leftRingId: json['leftRingId'] as String?,
      rightRing: json['rightRing'] as String?,
      rightRingId: json['rightRingId'] as String?,
      boots: json['boots'] as String?,
      bootsId: json['bootsId'] as String?,
    );
  }
}

/// A live snapshot of the player/farm state, as reported by the
/// stardew-ds-mod companion server's `GET /state` endpoint. Mirrors
/// `GameStateSnapshot` on the mod side (see stardew-ds-mod/GameStateSnapshot.cs)
/// — keep the two in sync.
class GameState {
  const GameState({
    required this.playerName,
    required this.farmName,
    required this.level,
    required this.currentFunds,
    required this.health,
    required this.maxHealth,
    required this.energy,
    required this.maxEnergy,
    required this.weekday,
    required this.season,
    required this.dayOfMonth,
    required this.year,
    required this.hour24,
    required this.minute,
    required this.weather,
    required this.seasonNumber,
    required this.weatherIconCode,
    required this.backpackSize,
    required this.selectedIndex,
    required this.inventory,
    required this.equipment,
    this.totalEarnings,
  });

  final String playerName;
  final String farmName;
  final int level;
  final int currentFunds;

  /// Team-wide lifetime earnings (money is shared in Stardew). Nullable
  /// for backwards compat with older mod builds that don't report it yet.
  final int? totalEarnings;

  final int health;
  final int maxHealth;
  final int energy;
  final int maxEnergy;

  final String weekday;
  final String season;
  final int dayOfMonth;
  final int year;
  final int hour24;
  final int minute;
  final String weather;

  /// 0=spring, 1=summer, 2=fall, 3=winter — pass to
  /// `GameConnectionService.seasonIconUrl` for the real HUD season icon.
  final int seasonNumber;

  /// The game's own weather-icon code — pass to
  /// `GameConnectionService.weatherIconUrl` for the real HUD weather icon.
  final int weatherIconCode;

  final int backpackSize;

  /// Index of the item currently equipped/selected in-game — kept in sync
  /// both ways: reflects what the player picks with number keys in-game,
  /// and is what the app asks the mod to change via `POST /select`.
  final int selectedIndex;

  final List<InventoryItem?> inventory;
  final EquippedItems equipment;

  factory GameState.fromJson(Map<String, dynamic> json) {
    final rawInventory = json['inventory'] as List<dynamic>? ?? const [];

    return GameState(
      playerName: json['playerName'] as String? ?? '',
      farmName: json['farmName'] as String? ?? '',
      level: json['level'] as int? ?? 0,
      currentFunds: json['currentFunds'] as int? ?? 0,
      health: json['health'] as int? ?? 0,
      maxHealth: json['maxHealth'] as int? ?? 0,
      energy: json['energy'] as int? ?? 0,
      maxEnergy: json['maxEnergy'] as int? ?? 0,
      weekday: json['weekday'] as String? ?? '',
      season: json['season'] as String? ?? '',
      dayOfMonth: json['dayOfMonth'] as int? ?? 0,
      year: json['year'] as int? ?? 1,
      hour24: json['hour24'] as int? ?? 0,
      minute: json['minute'] as int? ?? 0,
      weather: json['weather'] as String? ?? '',
      seasonNumber: json['seasonNumber'] as int? ?? 0,
      weatherIconCode: json['weatherIconCode'] as int? ?? 0,
      backpackSize: json['backpackSize'] as int? ?? 0,
      selectedIndex: json['selectedIndex'] as int? ?? 0,
      totalEarnings: json['totalEarnings'] as int?,
      inventory: rawInventory
          .map((e) => e == null ? null : InventoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      equipment: json['equipment'] == null
          ? const EquippedItems()
          : EquippedItems.fromJson(json['equipment'] as Map<String, dynamic>),
    );
  }
}
