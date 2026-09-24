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
    this.communityCenterUnlocked = false,
    this.communityCenterAreas = const [],
    this.isJojaMember = false,
    this.communityCenterComplete = false,
    this.houseUpgradeLevel = 0,
    this.houseLevelLabel = '',
    this.deepestMineLevel = 0,
    this.deepestSkullCavernLevel = 0,
    this.stardropsFound = 0,
    this.masteryUnlocked = false,
    this.masteryLevel = 0,
    this.masteryProgress = 0,
    this.masteryExpIntoLevel = 0,
    this.masteryExpForNextLevel = 0,
    this.masteryLabel = '',
    this.masteryLabelWidth = 0,
    this.secretFriendName,
    this.buffedSkills = const {},
    this.goldenWalnuts = 0,
    this.qiGems = 0,
    this.doodleIcon = '',
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

  // ---- Skills screen extras ------------------------------------------
  // The stats vanilla 1.6's own Skills page shows under the skill rows
  // (mirrors stardew-ds-mod's GameStateSnapshot, which cites the
  // decompiled SkillsPage.draw). All default to "nothing to show" so an
  // older mod build that doesn't report them still renders cleanly.

  /// Whether the Community Center tracker is shown at all — the host is
  /// a Joja member, or the "Meet the Wizard" quest has been completed
  /// (`canReadJunimoText`). Before that, vanilla draws a locked
  /// placeholder (`cc-locked` icon) instead.
  final bool communityCenterUnlocked;

  /// Per-room completion in vanilla area order: Pantry, Crafts Room,
  /// Fish Tank, Boiler Room, Vault, Bulletin Board. Empty while
  /// [communityCenterUnlocked] is false.
  final List<bool> communityCenterAreas;

  /// The host bought a Joja membership — the room stars switch to their
  /// Joja variants and a Joja panel covers the Bulletin Board slot.
  final bool isJojaMember;

  /// Every room restored the Junimo way — vanilla draws a Junimo in the
  /// middle of the room stars.
  final bool communityCenterComplete;

  /// Farmhouse upgrade tier, 0-3.
  final int houseUpgradeLevel;

  /// The game's own localized "Level N" label for [houseUpgradeLevel]
  /// (`houseUpgradeLevel + 1`). Empty from an older mod build.
  final String houseLevelLabel;

  /// Deepest regular Mines floor reached, 0-120.
  final int deepestMineLevel;

  /// Deepest Skull Cavern floor reached, 0 until the player has been
  /// below the Mines. Vanilla shows this instead of [deepestMineLevel]
  /// once it's non-zero, with a skull over the ladder icon.
  final int deepestSkullCavernLevel;

  /// Stardrops found, 0-7.
  final int stardropsFound;

  /// Whether the mastery bar is shown (the player has earned any mastery
  /// exp). Before that, vanilla draws a locked banner (`mastery-locked`).
  final bool masteryUnlocked;

  /// Mastery level, 0-5.
  final int masteryLevel;

  /// Mastery bar fill fraction toward the next level, 0-1 (1 at level 5).
  final double masteryProgress;

  /// Mastery exp earned into the current level, and exp the next level
  /// needs — vanilla's "N/M" text. Both 0 at level 5.
  final int masteryExpIntoLevel;
  final int masteryExpForNextLevel;

  /// The game's own localized "Mastery" label. Empty from an older mod
  /// build.
  final String masteryLabel;

  /// The game's own `smallFont.MeasureString(masteryLabel).X` in native px —
  /// the Skills page shifts and narrows its mastery bar by it. 0 from an
  /// older mod build (the app then measures the label itself).
  final double masteryLabelWidth;

  /// Display name of this year's Feast of the Winter Star secret friend,
  /// only between winter 18 and the feast (once the invitation letter's
  /// been read) — null otherwise. Their mugshot is
  /// `GameConnectionService.secretFriendUrl`.
  final String? secretFriendName;

  /// Skills whose level a buff is currently raising ("farming", "mining",
  /// "foraging", "fishing", "combat") — vanilla draws their level number
  /// green instead of sandy brown.
  final Set<String> buffedSkills;

  /// The team's unspent Golden Walnuts and this player's Qi Gems —
  /// vanilla shows each under the player's title while it's above 0.
  final int goldenWalnuts;
  final int qiGems;

  /// `/icon` name of the seasonal doodle vanilla draws in the bottom-right
  /// corner of the Skills page. Empty from an older mod build.
  final String doodleIcon;

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
      communityCenterUnlocked: json['communityCenterUnlocked'] as bool? ?? false,
      communityCenterAreas: (json['communityCenterAreas'] as List<dynamic>? ?? const [])
          .map((e) => e as bool? ?? false)
          .toList(),
      isJojaMember: json['isJojaMember'] as bool? ?? false,
      communityCenterComplete: json['communityCenterComplete'] as bool? ?? false,
      houseUpgradeLevel: json['houseUpgradeLevel'] as int? ?? 0,
      houseLevelLabel: json['houseLevelLabel'] as String? ?? '',
      deepestMineLevel: json['deepestMineLevel'] as int? ?? 0,
      deepestSkullCavernLevel: json['deepestSkullCavernLevel'] as int? ?? 0,
      stardropsFound: json['stardropsFound'] as int? ?? 0,
      masteryUnlocked: json['masteryUnlocked'] as bool? ?? false,
      masteryLevel: json['masteryLevel'] as int? ?? 0,
      masteryProgress: (json['masteryProgress'] as num?)?.toDouble() ?? 0,
      masteryExpIntoLevel: json['masteryExpIntoLevel'] as int? ?? 0,
      masteryExpForNextLevel: json['masteryExpForNextLevel'] as int? ?? 0,
      masteryLabel: json['masteryLabel'] as String? ?? '',
      masteryLabelWidth: (json['masteryLabelWidth'] as num?)?.toDouble() ?? 0,
      secretFriendName: json['secretFriendName'] as String?,
      buffedSkills: (json['buffedSkills'] as List<dynamic>? ?? const []).whereType<String>().toSet(),
      goldenWalnuts: json['goldenWalnuts'] as int? ?? 0,
      qiGems: json['qiGems'] as int? ?? 0,
      doodleIcon: json['doodleIcon'] as String? ?? '',
    );
  }
}
