import 'package:companion/screens/idle_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('IdleScreen is a full-size black box', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: IdleScreen(),
    ));

    final box = tester.widget<ColoredBox>(find.byType(ColoredBox));
    expect(box.color, Colors.black);
    expect(tester.getSize(find.byType(IdleScreen)), tester.view.physicalSize / tester.view.devicePixelRatio);
  });
}
