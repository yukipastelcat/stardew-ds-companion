import 'package:companion/models/inventory_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InventoryItem.fromJson', () {
    test('parses a fully populated slot', () {
      final item = InventoryItem.fromJson({
        'name': 'Watering Can',
        'quantity': 1,
        'iconId': 7,
        'qualifiedItemId': '(T)WateringCan',
        'waterLeft': 20,
        'waterLeftMax': 40,
        'waterCanIsBottomless': true,
        'quality': 2,
        'cooldownFraction': 0.5,
      });

      expect(item.name, 'Watering Can');
      expect(item.quantity, 1);
      expect(item.iconId, 7);
      expect(item.qualifiedItemId, '(T)WateringCan');
      expect(item.waterLeft, 20);
      expect(item.waterLeftMax, 40);
      expect(item.waterCanIsBottomless, isTrue);
      expect(item.quality, 2);
      expect(item.cooldownFraction, 0.5);
    });

    test('applies defaults when optional fields are missing', () {
      final item = InventoryItem.fromJson({'name': 'Parsnip'});

      expect(item.quantity, 0);
      expect(item.iconId, isNull);
      expect(item.qualifiedItemId, isNull);
      expect(item.waterLeft, isNull);
      expect(item.waterCanIsBottomless, isFalse);
      expect(item.quality, 0);
      expect(item.cooldownFraction, isNull);
    });

    test('accepts an integer cooldownFraction', () {
      final item = InventoryItem.fromJson({'name': 'Sword', 'cooldownFraction': 1});
      expect(item.cooldownFraction, 1.0);
    });
  });

  group('InventoryItem.waterFraction', () {
    test('is the left/max ratio', () {
      const item = InventoryItem(name: 'Can', quantity: 1, waterLeft: 10, waterLeftMax: 40);
      expect(item.waterFraction, 0.25);
    });

    test('is null when either value is missing', () {
      expect(const InventoryItem(name: 'a', quantity: 1, waterLeft: 1).waterFraction, isNull);
      expect(const InventoryItem(name: 'a', quantity: 1, waterLeftMax: 1).waterFraction, isNull);
    });

    test('is null when max is zero', () {
      const item = InventoryItem(name: 'Can', quantity: 1, waterLeft: 0, waterLeftMax: 0);
      expect(item.waterFraction, isNull);
    });

    test('is clamped to 0-1', () {
      const over = InventoryItem(name: 'Can', quantity: 1, waterLeft: 50, waterLeftMax: 40);
      const under = InventoryItem(name: 'Can', quantity: 1, waterLeft: -5, waterLeftMax: 40);
      expect(over.waterFraction, 1.0);
      expect(under.waterFraction, 0.0);
    });
  });

  group('InventoryItem.toJson', () {
    test('omits default and null optional fields', () {
      const item = InventoryItem(name: 'Parsnip', quantity: 3);
      expect(item.toJson(), {'name': 'Parsnip', 'quantity': 3});
    });

    test('round-trips through fromJson', () {
      const item = InventoryItem(
        name: 'Pickles',
        quantity: 5,
        iconId: 1,
        qualifiedItemId: '(O)342_red',
        waterLeft: 1,
        waterLeftMax: 2,
        waterCanIsBottomless: true,
        quality: 4,
        cooldownFraction: 0.25,
      );
      final copy = InventoryItem.fromJson(item.toJson());

      expect(copy.toJson(), item.toJson());
    });
  });
}
