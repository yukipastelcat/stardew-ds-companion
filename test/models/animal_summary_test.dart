import 'package:companion/models/animal_summary.dart';
import 'package:flutter_test/flutter_test.dart';

AnimalSummary _animal(int friendship) =>
    AnimalSummary(name: 'Test', type: 'White Chicken', friendship: friendship);

List<bool> _filled(AnimalSummary a) => [for (var i = 0; i < 5; i++) a.isHeartFilled(i)];
List<bool> _half(AnimalSummary a) => [for (var i = 0; i < 5; i++) a.isHeartHalf(i)];

void main() {
  test('fromJson parses fields and applies defaults', () {
    final full = AnimalSummary.fromJson({
      'name': 'Chip',
      'type': 'Cat-1',
      'friendship': 800,
      'wasPet': true,
    });
    expect(full.name, 'Chip');
    expect(full.type, 'Cat-1');
    expect(full.friendship, 800);
    expect(full.wasPet, isTrue);

    final empty = AnimalSummary.fromJson({});
    expect(empty.name, '');
    expect(empty.type, '');
    expect(empty.friendship, 0);
    expect(empty.wasPet, isFalse);
  });

  group('hearts (vanilla AnimalPage formula)', () {
    test('zero friendship shows no hearts', () {
      final a = _animal(0);
      expect(_filled(a), everyElement(isFalse));
      expect(_half(a), everyElement(isFalse));
    });

    test('hearts fill at 195-point thresholds, strictly greater', () {
      expect(_animal(195).isHeartFilled(0), isFalse);
      expect(_animal(196).isHeartFilled(0), isTrue);
      expect(_animal(975).isHeartFilled(4), isFalse);
      expect(_animal(976).isHeartFilled(4), isTrue);
    });

    test('friendship near the cap reads as five full hearts', () {
      final a = _animal(990);
      expect(_filled(a), everyElement(isTrue));
      // The half-heart overlay lands on an already-filled heart: invisible.
      expect(_half(a), everyElement(isFalse));
    });

    test('mid-range friendship shows two full, one half, two empty', () {
      final a = _animal(550);
      expect(_filled(a), [true, true, false, false, false]);
      expect(_half(a), [false, false, true, false, false]);
    });

    test('half heart needs at least 100 points into the 200-point slot', () {
      expect(_half(_animal(99)), everyElement(isFalse));
      expect(_half(_animal(100))[0], isTrue);
      expect(_half(_animal(150))[0], isTrue);
    });
  });
}
