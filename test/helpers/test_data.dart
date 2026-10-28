import 'dart:convert';

import 'package:companion/models/game_state.dart';
import 'package:companion/services/game_connection_service.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'fake_websocket.dart';

/// A realistic state payload as the mod would push it.
Map<String, dynamic> stateJson({
  int backpackSize = 12,
  int selectedIndex = 0,
  List<Map<String, dynamic>?>? inventory,
  List<Map<String, dynamic>> animals = const [],
  String playerName = 'Abigail',
  String locationName = 'Farm',
}) {
  return {
    'playerName': playerName,
    'farmName': 'Pastel',
    'currentFunds': 1234,
    'health': 100,
    'maxHealth': 100,
    'energy': 270,
    'maxEnergy': 270,
    'weekday': 'Mon',
    'season': 'spring',
    'dayOfMonth': 3,
    'year': 1,
    'hour24': 9,
    'minute': 20,
    'weather': 'Sunny',
    'backpackSize': backpackSize,
    'selectedIndex': selectedIndex,
    'locationName': locationName,
    'inventory': inventory ??
        [
          {'name': 'Hoe', 'quantity': 1, 'qualifiedItemId': '(T)Hoe'},
          {'name': 'Parsnip', 'quantity': 12, 'qualifiedItemId': '(O)24'},
          null,
        ],
    'animals': animals,
  };
}

/// A connected [GameConnectionService] backed by a [FakeWebSocketChannel]
/// and the given HTTP [client].
class ConnectedService {
  ConnectedService._(this.service, this.channels);

  final GameConnectionService service;

  /// Every channel the service has opened, oldest first.
  final List<FakeWebSocketChannel> channels;

  FakeWebSocketChannel get channel => channels.last;

  static ConnectedService create({http.Client? client, int port = 8082}) {
    final channels = <FakeWebSocketChannel>[];
    final service = GameConnectionService(
      port: port,
      client: client,
      channelFactory: (uri) {
        final channel = FakeWebSocketChannel();
        channels.add(channel);
        return channel;
      },
    );
    return ConnectedService._(service, channels);
  }

  /// Connects and delivers [json] as the first state frame.
  Future<void> connectWithState(WidgetTester tester, Map<String, dynamic> json) async {
    service.connect();
    channel.markReady();
    channel.emit(jsonEncode(json));
    await pumpFrames(tester);
  }

  GameState? get state => service.state;
}

/// Delivers pending socket frames and runs the frame callback the service
/// schedules for them (the first pump moves the stream event, the second
/// runs the frame it schedules).
Future<void> pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

/// Gives the test a large landscape window like the target handheld, and
/// restores the default when the test ends.
void useHandheldWindow(WidgetTester tester, {Size size = const Size(1240, 1080)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
