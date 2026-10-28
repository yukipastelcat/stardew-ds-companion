import 'dart:convert';

import 'package:companion/screens/companion/animals_screen.dart';
import 'package:companion/screens/companion/backpack_screen.dart';
import 'package:companion/screens/companion/map_screen.dart';
import 'package:companion/screens/companion/skills_screen.dart';
import 'package:companion/screens/companion_screen.dart';
import 'package:companion/widgets/draggable_inventory_slot.dart';
import 'package:companion/widgets/inventory_slot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/test_data.dart';

const _waiting = 'Waiting for game data…';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  late List<http.Request> requests;
  late ConnectedService harness;

  setUp(() {
    requests = [];
    harness = ConnectedService.create(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('', 200);
      }),
    );
  });

  /// Pumps [build] and always disposes the service before the test returns,
  /// so a pending reconnect timer can't trip the end-of-test check.
  void screenTest(
    String name,
    Future<void> Function(WidgetTester tester) body,
  ) {
    testWidgets(name, (tester) async {
      useHandheldWindow(tester);
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        harness.service.dispose();
      }
    });
  }

  group('before any game data arrives', () {
    for (final entry in <String, Widget Function(ConnectedService)>{
      'BackpackScreen': (h) => BackpackScreen(connection: h.service),
      'SkillsScreen': (h) => SkillsScreen(connection: h.service),
      'MapScreen': (h) => MapScreen(connection: h.service),
      'AnimalsScreen': (h) => AnimalsScreen(connection: h.service),
    }.entries) {
      screenTest('${entry.key} asks the player to wait', (tester) async {
        await tester.pumpWidget(_app(entry.value(harness)));

        expect(find.text(_waiting), findsOneWidget);
      });
    }
  });

  group('BackpackScreen', () {
    screenTest('renders all 36 slots, locking the ones not yet unlocked', (tester) async {
      await tester.pumpWidget(_app(BackpackScreen(connection: harness.service)));
      await harness.connectWithState(tester, stateJson(backpackSize: 12));
      await tester.pump();

      expect(find.byType(DraggableInventorySlot), findsNWidgets(36));
      final slots = tester.widgetList<InventorySlot>(find.byType(InventorySlot)).toList();
      expect(slots.where((s) => s.locked), hasLength(24));
      expect(slots.where((s) => !s.locked), hasLength(12));
    });

    screenTest('marks only the selected slot and shows stack sizes', (tester) async {
      await tester.pumpWidget(_app(BackpackScreen(connection: harness.service)));
      await harness.connectWithState(tester, stateJson(selectedIndex: 1));
      await tester.pump();

      final slots = tester.widgetList<InventorySlot>(find.byType(InventorySlot)).toList();
      expect(slots.where((s) => s.selected), hasLength(1));
      expect(slots[1].selected, isTrue);
      expect(find.text('12'), findsOneWidget); // the Parsnip stack
    });

    screenTest('shows current funds', (tester) async {
      await tester.pumpWidget(_app(BackpackScreen(connection: harness.service)));
      await harness.connectWithState(tester, stateJson());
      await tester.pump();

      expect(find.text('1,234g'), findsOneWidget);
    });

    screenTest('tapping an unlocked slot asks the mod to select it', (tester) async {
      await tester.pumpWidget(_app(BackpackScreen(connection: harness.service)));
      await harness.connectWithState(tester, stateJson());
      await tester.pump();

      await tester.tap(find.byType(InventorySlot).at(1));
      await tester.pump();

      final select = requests.where((r) => r.url.path == '/select').single;
      expect(jsonDecode(select.body), {'index': 1});
    });

    screenTest('tapping a locked slot does nothing', (tester) async {
      await tester.pumpWidget(_app(BackpackScreen(connection: harness.service)));
      await harness.connectWithState(tester, stateJson(backpackSize: 12));
      await tester.pump();

      await tester.tap(find.byType(InventorySlot).at(20), warnIfMissed: false);
      await tester.pump();

      expect(requests, isEmpty);
    });

    screenTest('goes back to waiting when the save is unloaded', (tester) async {
      await tester.pumpWidget(_app(BackpackScreen(connection: harness.service)));
      await harness.connectWithState(tester, stateJson());
      await tester.pump();
      expect(find.byType(DraggableInventorySlot), findsNWidgets(36));

      harness.channel.emit(jsonEncode({'connected': false}));
      await pumpFrames(tester);

      expect(find.text(_waiting), findsOneWidget);
      expect(find.byType(DraggableInventorySlot), findsNothing);
    });
  });

  group('AnimalsScreen', () {
    screenTest('says so when there are no animals', (tester) async {
      await tester.pumpWidget(_app(AnimalsScreen(connection: harness.service)));
      await harness.connectWithState(tester, stateJson());
      await tester.pump();

      expect(find.text('No animals yet.'), findsOneWidget);
    });

    screenTest('lists each animal by name', (tester) async {
      await tester.pumpWidget(_app(AnimalsScreen(connection: harness.service)));
      await harness.connectWithState(
        tester,
        stateJson(animals: [
          {'name': 'Clucky', 'type': 'White Chicken', 'friendship': 500, 'wasPet': true},
          {'name': 'Bessie', 'type': 'Dairy Cow', 'friendship': 1000, 'wasPet': false},
        ]),
      );
      await tester.pump();

      expect(find.text('Clucky'), findsOneWidget);
      expect(find.text('Bessie'), findsOneWidget);
      expect(find.text('No animals yet.'), findsNothing);
    });
  });

  group('SkillsScreen', () {
    screenTest('shows the player name', (tester) async {
      await tester.pumpWidget(_app(SkillsScreen(connection: harness.service)));
      await harness.connectWithState(tester, stateJson(playerName: 'Leah'));
      await tester.pump();

      expect(find.text('Leah'), findsOneWidget);
      expect(find.text(_waiting), findsNothing);
    });
  });

  group('MapScreen', () {
    screenTest('shows the current location', (tester) async {
      await tester.pumpWidget(_app(MapScreen(connection: harness.service)));
      await harness.connectWithState(tester, stateJson(locationName: 'Town'));
      await tester.pump();

      expect(find.text('Town'), findsOneWidget);
    });

    screenTest('shows a placeholder while the location is unknown', (tester) async {
      await tester.pumpWidget(_app(MapScreen(connection: harness.service)));
      await harness.connectWithState(tester, stateJson(locationName: ''));
      await tester.pump();

      expect(find.text('…'), findsOneWidget);
    });
  });

  group('CompanionScreen', () {
    screenTest('starts on the Backpack tab and switches tabs from the nav bar', (tester) async {
      await tester.pumpWidget(_app(CompanionScreen(connection: harness.service)));
      await harness.connectWithState(tester, stateJson(locationName: 'Beach'));
      await tester.pump();

      expect(find.byType(BackpackScreen), findsOneWidget);
      expect(find.byType(MapScreen), findsNothing);

      await tester.tap(find.bySemanticsLabel('Map'));
      await tester.pump();
      expect(find.byType(MapScreen), findsOneWidget);
      expect(find.byType(BackpackScreen), findsNothing);
      expect(find.text('Beach'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Pets'));
      await tester.pump();
      expect(find.byType(AnimalsScreen), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Skills'));
      await tester.pump();
      expect(find.byType(SkillsScreen), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Backpack'));
      await tester.pump();
      expect(find.byType(BackpackScreen), findsOneWidget);
    });
  });
}
