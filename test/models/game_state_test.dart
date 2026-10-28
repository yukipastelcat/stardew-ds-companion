import 'package:companion/models/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameState.fromJson', () {
    test('an empty payload yields safe defaults', () {
      final state = GameState.fromJson({});

      expect(state.playerName, '');
      expect(state.farmName, '');
      expect(state.currentFunds, 0);
      expect(state.year, 1);
      expect(state.inventory, isEmpty);
      expect(state.animals, isEmpty);
      expect(state.buffedSkills, isEmpty);
      expect(state.communityCenterAreas, isEmpty);
      expect(state.totalEarnings, isNull);
      expect(state.mapMarkerX, isNull);
      expect(state.mapMarkerY, isNull);
      expect(state.secretFriendName, isNull);
      expect(state.equipment.hat, isNull);
      expect(state.idle, isFalse);
      expect(state.exhausted, isFalse);
    });

    test('parses core player, time and vitals fields', () {
      final state = GameState.fromJson({
        'playerName': 'Abigail',
        'farmName': 'Pastel',
        'level': 3,
        'currentFunds': 1234567,
        'totalEarnings': 9999999,
        'health': 80,
        'maxHealth': 100,
        'energy': 150,
        'maxEnergy': 270,
        'weekday': 'Mon',
        'season': 'spring',
        'dayOfMonth': 12,
        'year': 2,
        'hour24': 14,
        'minute': 30,
        'weather': 'Sunny',
        'seasonNumber': 2,
        'weatherIconCode': 4,
        'backpackSize': 24,
        'selectedIndex': 5,
        'locationName': 'Farm',
        'idle': true,
      });

      expect(state.playerName, 'Abigail');
      expect(state.farmName, 'Pastel');
      expect(state.currentFunds, 1234567);
      expect(state.totalEarnings, 9999999);
      expect(state.health, 80);
      expect(state.maxEnergy, 270);
      expect(state.dayOfMonth, 12);
      expect(state.year, 2);
      expect(state.hour24, 14);
      expect(state.minute, 30);
      expect(state.seasonNumber, 2);
      expect(state.weatherIconCode, 4);
      expect(state.backpackSize, 24);
      expect(state.selectedIndex, 5);
      expect(state.locationName, 'Farm');
      expect(state.idle, isTrue);
    });

    test('keeps empty inventory slots as null', () {
      final state = GameState.fromJson({
        'inventory': [
          {'name': 'Hoe', 'quantity': 1},
          null,
          {'name': 'Parsnip', 'quantity': 12},
        ],
      });

      expect(state.inventory, hasLength(3));
      expect(state.inventory[0]?.name, 'Hoe');
      expect(state.inventory[1], isNull);
      expect(state.inventory[2]?.quantity, 12);
    });

    test('parses equipment', () {
      final state = GameState.fromJson({
        'equipment': {
          'hat': 'Cowboy Hat',
          'hatId': '(H)0',
          'leftRing': 'Ruby Ring',
          'leftRingId': '(O)533',
          'boots': 'Sneakers',
          'bootsId': '(B)504',
        },
      });

      expect(state.equipment.hat, 'Cowboy Hat');
      expect(state.equipment.hatId, '(H)0');
      expect(state.equipment.leftRing, 'Ruby Ring');
      expect(state.equipment.rightRing, isNull);
      expect(state.equipment.bootsId, '(B)504');
    });

    test('parses animals', () {
      final state = GameState.fromJson({
        'animals': [
          {'name': 'Chip', 'type': 'Cat', 'friendship': 1000, 'wasPet': true},
          {'name': 'Clucky', 'type': 'White Chicken', 'friendship': 200},
        ],
      });

      expect(state.animals.map((a) => a.name), ['Chip', 'Clucky']);
      expect(state.animals.first.wasPet, isTrue);
      expect(state.animals.last.wasPet, isFalse);
    });

    test('accepts integer values for double fields', () {
      final state = GameState.fromJson({
        'mapMarkerX': 1,
        'mapMarkerY': 0.25,
        'masteryProgress': 1,
        'masteryLabelWidth': 42,
      });

      expect(state.mapMarkerX, 1.0);
      expect(state.mapMarkerY, 0.25);
      expect(state.masteryProgress, 1.0);
      expect(state.masteryLabelWidth, 42.0);
    });

    test('parses skills screen extras', () {
      final state = GameState.fromJson({
        'title': 'Farmer',
        'farmingLevel': 10,
        'miningLevel': 7,
        'foragingLevel': 5,
        'fishingLevel': 3,
        'combatLevel': 1,
        'communityCenterUnlocked': true,
        'communityCenterAreas': [true, false, true, false, false, true],
        'isJojaMember': false,
        'houseUpgradeLevel': 2,
        'deepestMineLevel': 95,
        'deepestSkullCavernLevel': 12,
        'stardropsFound': 3,
        'masteryUnlocked': true,
        'masteryLevel': 2,
        'masteryExpIntoLevel': 500,
        'masteryExpForNextLevel': 1000,
        'secretFriendName': 'Leah',
        'buffedSkills': ['farming', 'mining'],
        'goldenWalnuts': 4,
        'qiGems': 9,
      });

      expect(state.title, 'Farmer');
      expect(state.farmingLevel, 10);
      expect(state.combatLevel, 1);
      expect(state.communityCenterUnlocked, isTrue);
      expect(state.communityCenterAreas, [true, false, true, false, false, true]);
      expect(state.houseUpgradeLevel, 2);
      expect(state.deepestSkullCavernLevel, 12);
      expect(state.masteryExpForNextLevel, 1000);
      expect(state.secretFriendName, 'Leah');
      expect(state.buffedSkills, {'farming', 'mining'});
      expect(state.goldenWalnuts, 4);
      expect(state.qiGems, 9);
    });

    test('ignores non-string entries in buffedSkills', () {
      final state = GameState.fromJson({
        'buffedSkills': ['farming', 3, null],
      });
      expect(state.buffedSkills, {'farming'});
    });

    test('ignores unknown fields', () {
      expect(() => GameState.fromJson({'someFutureField': 123}), returnsNormally);
    });
  });
}
