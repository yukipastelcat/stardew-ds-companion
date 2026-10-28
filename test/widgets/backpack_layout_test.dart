import 'package:companion/widgets/backpack_inventory.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

BoxConstraints _box(double w, double h) => BoxConstraints.tight(Size(w, h));

void main() {
  const toolbar = 2.0;

  test('a large window uses the wide 12x3 layout', () {
    final layout = BackpackInventory.resolveLayout(_box(1240, 1080), toolbarHeightMultiplier: toolbar);

    expect(layout.columns, 12);
    expect(layout.rows, 3);
    expect(layout.slotSize, greaterThanOrEqualTo(72));
  });

  test('a small window reflows to the compact 9x4 layout', () {
    final layout = BackpackInventory.resolveLayout(_box(355, 315), toolbarHeightMultiplier: toolbar);

    expect(layout.columns, 9);
    expect(layout.rows, 4);
  });

  test('the grid and toolbar always fit inside the given constraints', () {
    for (final size in const [Size(355, 315), Size(800, 480), Size(1240, 1080), Size(600, 900)]) {
      final c = _box(size.width, size.height);
      final layout = BackpackInventory.resolveLayout(c, toolbarHeightMultiplier: toolbar);

      final width = layout.slotSize * layout.columns + (layout.columns - 1) * BackpackInventory.slotSpacing;
      final height = layout.slotSize * (layout.rows + toolbar) +
          (layout.rows - 1) * BackpackInventory.slotSpacing +
          BackpackInventory.spacingBeforeToolbar;

      expect(width, lessThanOrEqualTo(size.width + 0.001), reason: '$size width');
      expect(height, lessThanOrEqualTo(size.height + 0.001), reason: '$size height');
    }
  });

  test('slot size never drops below 16', () {
    final layout = BackpackInventory.resolveLayout(_box(50, 50), toolbarHeightMultiplier: toolbar);
    expect(layout.slotSize, 16.0);
  });

  test('a taller toolbar leaves smaller slots on a height-bound window', () {
    final short = BackpackInventory.resolveLayout(_box(2000, 400), toolbarHeightMultiplier: 1);
    final tall = BackpackInventory.resolveLayout(_box(2000, 400), toolbarHeightMultiplier: 3);
    expect(tall.slotSize, lessThan(short.slotSize));
  });
}
