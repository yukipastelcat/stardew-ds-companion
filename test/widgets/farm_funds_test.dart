import 'package:companion/widgets/farm_funds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, int funds) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: FarmFunds(currentFunds: funds))),
  );
}

void main() {
  testWidgets('shows the label and the amount', (tester) async {
    await _pump(tester, 500);

    expect(find.text('Current Funds:'), findsOneWidget);
    expect(find.text('500g'), findsOneWidget);
  });

  testWidgets('groups thousands with commas', (tester) async {
    await _pump(tester, 1234567);
    expect(find.text('1,234,567g'), findsOneWidget);
  });

  testWidgets('does not add a leading comma at group boundaries', (tester) async {
    await _pump(tester, 100000);
    expect(find.text('100,000g'), findsOneWidget);
  });

  testWidgets('shows zero', (tester) async {
    await _pump(tester, 0);
    expect(find.text('0g'), findsOneWidget);
  });
}
