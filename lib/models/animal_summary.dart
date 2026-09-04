/// One farm animal OR house pet (Cat/Dog), as reported by the StardewDS
/// SMAPI mod's `GET /state` (and `GET /ws`) snapshot — mirrors
/// `AnimalDto` on the mod side (see stardew-ds-mod/GameStateSnapshot.cs)
/// — keep the two in sync. The mod unifies both into one list because
/// this screen shows them as a single table, matching the reference
/// in-game screenshot the screen was built from — see
/// GameStateSnapshot.CollectPets's doc comment for why a pet needed its
/// own capture path (it isn't a FarmAnimal).
///
/// Scoped to what the Animals screen actually shows: a name, a portrait
/// (via [GameConnectionService.animalSpriteUrl]), and how affectionate
/// the animal is. Deliberately doesn't report produce-ready state or
/// anything else — vanilla itself has no "Animals" page at all (farm
/// animals aren't listed anywhere in the real game's own `GameMenu`);
/// the closest real precedent is the well-known `AnimalSocialMenu` mod
/// (spacechase0), which adds exactly this — a friendship/petting list,
/// nothing about produce — so this screen matches that same scope
/// rather than guessing at a wider one. A future round wanting more
/// (produce-ready, mood, age) needs new `GameStateSnapshot`/`AnimalDto`
/// fields first — see mod/README.md's route list.
class AnimalSummary {
  const AnimalSummary({
    required this.name,
    required this.type,
    required this.friendship,
    this.wasPet = false,
  });

  final String name;

  /// For a farm animal: species/breed string (e.g. "White Chicken",
  /// "Dairy Cow"), mirroring `FarmAnimal.type`. For a house pet: "Cat"
  /// or "Dog" (or a modded pet type), with a "-<breed>" suffix for
  /// non-default breeds (e.g. "Cat-1") — the mod's own `AnimalDto.Type`,
  /// mirroring `Pet.petType`/`Pet.whichBreed` (a `NetString` breed id,
  /// not a number, as of Stardew 1.6). Passed to
  /// [GameConnectionService.animalSpriteUrl] as the cache key for this
  /// animal's real portrait sprite: every animal (or pet) of the same
  /// breed shares one crop, the same way [GameConnectionService.spriteUrl]
  /// shares one crop per qualified item id rather than per inventory
  /// slot.
  final String type;

  /// `FarmAnimal.friendshipTowardFarmer`, or the same-named field on a
  /// house pet — both 0-1000 (200 points per heart, 5 hearts max) — the
  /// same scale the real `AnimalSocialMenu` mod reads from this exact
  /// FarmAnimal field. See [isHeartFilled]/[isHeartHalf].
  final int friendship;

  /// `FarmAnimal.wasPet`, or `Pet.grantedFriendshipForPet` for a house
  /// pet — whether this animal has already been pet today. Drives the
  /// "Needs petting" label, the same wording (and, for a farm animal,
  /// the same underlying field) `AnimalSocialMenu` itself shows.
  final bool wasPet;

  /// Correction round (data, not rendering): this used to be a naive
  /// `friendship ~/ 200` / `friendship % 200 >= 100` model — clean, but
  /// wrong. It made Chip and Dip (and any animal near the 5-heart cap)
  /// show 4.5 hearts in the app while the real game showed a full 5.
  ///
  /// The actual vanilla formula, from the decompiled
  /// `AnimalPage.drawNPCSlot` (StardewValley.Menus.AnimalPage): each
  /// heart slot `i` (0-4) is filled when
  /// `friendship > (i + 1) * 195` — 195 points per heart, NOT 200. On
  /// top of that, vanilla draws one extra "half heart" overlay — a
  /// partially-cropped filled-heart sprite — at slot
  /// `friendship ~/ 200`, but only when `friendship % 200 >= 100`. That
  /// overlay lands at a *200-point* index while the base hearts fill at
  /// *195-point* thresholds, so by the time friendship is high enough
  /// to trigger the half-heart overlay on a given slot, that slot is
  /// often already fully filled by the 195 threshold — the overlay ends
  /// up drawn on top of a heart that's already solid, so it never reads
  /// as "half" on screen. [isHeartHalf] reproduces that: it only reports
  /// a visible half heart when the overlay's slot isn't already filled.
  ///
  /// Worked examples (verified against user reports/screenshots):
  /// - friendship in 976-999 (Chip/Dip): slot 4's threshold is
  ///   4*195=780, i.e. filled once friendship > 975 — so all 5 hearts
  ///   read filled, matching the real game.
  /// - friendship ~550 (Yoghurt): hearts 0-1 filled (thresholds 195,
  ///   390), heart 2 not yet filled (threshold 585) but
  ///   550 ~/ 200 == 2 and 550 % 200 == 150 >= 100, so heart 2 shows
  ///   half — 2 full + 1 half + 2 empty, matching every prior
  ///   screenshot of Yoghurt.
  bool isHeartFilled(int i) => friendship > (i + 1) * 195;

  /// See [isHeartFilled]'s doc comment for the full derivation. True
  /// only when heart slot [i] is the vanilla half-heart overlay's slot
  /// (`friendship ~/ 200 == i`), that overlay would actually be drawn
  /// (`friendship % 200 >= 100`), and slot [i] isn't already filled by
  /// the 195-point threshold (an overlay drawn on an already-filled
  /// heart is invisible in the real game, so it shouldn't render here
  /// either).
  bool isHeartHalf(int i) =>
      !isHeartFilled(i) && friendship % 200 >= 100 && friendship ~/ 200 == i;

  factory AnimalSummary.fromJson(Map<String, dynamic> json) {
    return AnimalSummary(
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      friendship: json['friendship'] as int? ?? 0,
      wasPet: json['wasPet'] as bool? ?? false,
    );
  }
}
