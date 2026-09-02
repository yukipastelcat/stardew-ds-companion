import 'animal_summary.dart';
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
    required this.locationName,
    this.mapMarkerX,
    this.mapMarkerY,
    this.title = '',
    this.farmingLevel = 0,
    this.miningLevel = 0,
    this.foragingLevel = 0,
    this.fishingLevel = 0,
    this.combatLevel = 0,
    this.hasVisibleQuests = false,
    this.hasNewQuestActivity = false,
    this.exhausted = false,
    this.energyShake = false,
    this.healthShake = false,
    this.animals = const [],
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

  /// Display name of the location the player is currently in (e.g.
  /// "Farm", "Town", "The Mines") — see `GameStateSnapshot.LocationName`.
  final String locationName;

  /// The player's position on the real vanilla world map, as a 0-1
  /// fraction of `GameConnectionService.worldMapUrl`'s own image
  /// width/height — see `GameStateSnapshot.MapMarkerX`/`MapMarkerY`.
  /// Null when the current location isn't mapped in `Data/WorldMap`
  /// (most mine/cave levels, a handful of interiors), same as the real
  /// in-game map page showing no marker there either.
  final double? mapMarkerX;

  /// See [mapMarkerX].
  final double? mapMarkerY;

  /// Farmer.getTitle() — the title shown under the player's name on the
  /// real Skills page (e.g. "Newcomer"), derived from total skill level.
  /// Defaults to '' for backwards compat with older mod builds.
  final String title;

  /// The five skill levels the Skills screen draws a pip row for — see
  /// `GameStateSnapshot.FarmingLevel`/etc's doc comment. Luck isn't
  /// reported/shown (see `SkillsScreen`'s doc comment). Default to 0 for
  /// backwards compat with older mod builds that don't report these yet.
  final int farmingLevel;
  final int miningLevel;
  final int foragingLevel;
  final int fishingLevel;
  final int combatLevel;

  /// Mirrors `Farmer.hasVisibleQuests`/`hasNewQuestActivity()` — see
  /// `GameStateSnapshot`'s doc comments. [hasNewQuestActivity] drives the
  /// Backpack screen's Journal button pulse (`BackpackToolbar`).
  final bool hasVisibleQuests;
  final bool hasNewQuestActivity;

  /// Mirrors `Farmer.exhausted` — the player is over-tired (stamina hit 0,
  /// or up past 2am). While true, `VitalsBars` draws the vanilla "tired"
  /// face above the energy bar, the same decoration vanilla `Game1.drawHUD`
  /// draws. Defaults to false for older mod builds that don't report it.
  final bool exhausted;

  /// Mirrors `Game1.staminaShakeTimer > 0` / `Game1.hitShakeTimer > 0` —
  /// vanilla jitters the energy bar (on stamina spend while low, ~1s) and
  /// the health bar (on taking damage, 250–500ms) and spawns sky-blue /
  /// red droplet particles by them. `VitalsBars` reproduces the shake +
  /// droplets while these are true (blood droplets also keyed off
  /// [health] `<= 10`, matching vanilla's own check). Default false for
  /// older mod builds.
  final bool energyShake;
  final bool healthShake;

  /// Farm animals reported by the mod (see AnimalSummary's doc
  /// comment for scope) — defaults to empty for backwards compat with
  /// older mod builds that don't report this yet.
  final List<AnimalSummary> animals;

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
      locationName: json['locationName'] as String? ?? '',
      mapMarkerX: (json['mapMarkerX'] as num?)?.toDouble(),
      mapMarkerY: (json['mapMarkerY'] as num?)?.toDouble(),
      inventory: rawInventory
          .map((e) => e == null ? null : InventoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      equipment: json['equipment'] == null
          ? const EquippedItems()
          : EquippedItems.fromJson(json['equipment'] as Map<String, dynamic>),
      animals: (json['animals'] as List<dynamic>? ?? const [])
          .map((e) => AnimalSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      title: json['title'] as String? ?? '',
      farmingLevel: json['farmingLevel'] as int? ?? 0,
      miningLevel: json['miningLevel'] as int? ?? 0,
      foragingLevel: json['foragingLevel'] as int? ?? 0,
      fishingLevel: json['fishingLevel'] as int? ?? 0,
      combatLevel: json['combatLevel'] as int? ?? 0,
      hasVisibleQuests: json['hasVisibleQuests'] as bool? ?? false,
      hasNewQuestActivity: json['hasNewQuestActivity'] as bool? ?? false,
      exhausted: json['exhausted'] as bool? ?? false,
      energyShake: json['energyShake'] as bool? ?? false,
      healthShake: json['healthShake'] as bool? ?? false,
    );
  }
}
