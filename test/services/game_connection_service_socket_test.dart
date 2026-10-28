import 'dart:convert';

import 'package:companion/services/game_connection_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_websocket.dart';
import '../helpers/test_data.dart';

void main() {
  late ConnectedService harness;
  late GameConnectionService service;
  late int notifications;

  // Disposes the service before the test body returns: a pending reconnect
  // timer would otherwise trip the framework's end-of-test timer check
  // (addTearDown callbacks run after it).
  void socketTest(String name, Future<void> Function(WidgetTester tester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        service.dispose();
      }
    });
  }

  setUp(() {
    harness = ConnectedService.create(port: 9123);
    service = harness.service;
    notifications = 0;
    service.addListener(() => notifications++);
  });

  socketTest('connect opens ws://localhost:<port>/ws', (tester) async {
    Uri? opened;
    final svc = GameConnectionService(
      port: 9123,
      channelFactory: (uri) {
        opened = uri;
        return FakeWebSocketChannel();
      },
    )..connect();
    addTearDown(svc.dispose);

    expect(opened.toString(), 'ws://localhost:9123/ws');
    expect(svc.status, ConnectionStatus.connecting);
  });

  socketTest('a state frame makes the service connected', (tester) async {
    await harness.connectWithState(tester, stateJson(playerName: 'Leah'));

    expect(service.status, ConnectionStatus.connected);
    expect(service.isConnected, isTrue);
    expect(service.state?.playerName, 'Leah');
    expect(service.lastError, isNull);
    expect(notifications, greaterThan(1)); // connect() + the applied frame
  });

  socketTest('connected:false means the mod is up but no save is loaded', (tester) async {
    await harness.connectWithState(tester, stateJson());
    harness.channel.emit(jsonEncode({'connected': false}));
    await pumpFrames(tester);

    expect(service.state, isNull);
    expect(service.status, ConnectionStatus.connecting);
    expect(service.lastError, contains('load a save'));
  });

  socketTest('malformed and non-text frames are ignored', (tester) async {
    await harness.connectWithState(tester, stateJson(playerName: 'Leah'));

    harness.channel.emit('not json');
    await pumpFrames(tester);
    harness.channel.emit([1, 2, 3]);
    await pumpFrames(tester);

    expect(service.state?.playerName, 'Leah');
    expect(service.status, ConnectionStatus.connected);
  });

  socketTest('an identical frame does not notify listeners again', (tester) async {
    final raw = jsonEncode(stateJson());
    service.connect();
    harness.channel.emit(raw);
    await pumpFrames(tester);
    final after = notifications;

    harness.channel.emit(raw);
    await pumpFrames(tester);

    expect(notifications, after);
  });

  socketTest('frames arriving in the same frame are coalesced to the latest', (tester) async {
    service.connect();
    harness.channel.emit(jsonEncode(stateJson(playerName: 'First')));
    harness.channel.emit(jsonEncode(stateJson(playerName: 'Second')));
    await pumpFrames(tester);

    expect(service.state?.playerName, 'Second');
  });

  socketTest('a dropped socket reports an error, then reconnects after 2s', (tester) async {
    await harness.connectWithState(tester, stateJson());
    expect(harness.channels, hasLength(1));

    harness.channel.serverClose();
    await pumpFrames(tester);

    expect(service.status, ConnectionStatus.error);
    expect(service.lastError, contains('localhost:9123'));
    expect(harness.channels, hasLength(1));

    await tester.pump(const Duration(seconds: 1));
    expect(harness.channels, hasLength(1));

    await tester.pump(const Duration(seconds: 1));
    expect(harness.channels, hasLength(2));
    expect(service.status, ConnectionStatus.error); // until a frame arrives

    harness.channel.emit(jsonEncode(stateJson(playerName: 'Back')));
    await pumpFrames(tester);
    expect(service.status, ConnectionStatus.connected);
    expect(service.state?.playerName, 'Back');
  });

  socketTest('a socket error is handled like a drop', (tester) async {
    service.connect();
    harness.channel.serverError(StateError('boom'));
    await pumpFrames(tester);

    expect(service.status, ConnectionStatus.error);
  });

  socketTest('a failed handshake is handled like a drop', (tester) async {
    service.connect();
    harness.channel.failReady(StateError('refused'));
    await pumpFrames(tester);

    expect(service.status, ConnectionStatus.error);
    await tester.pump(const Duration(seconds: 2));
    expect(harness.channels, hasLength(2));
  });

  socketTest('a throwing channel factory is handled like a drop', (tester) async {
    var calls = 0;
    final svc = GameConnectionService(channelFactory: (uri) {
      calls++;
      throw StateError('no network');
    })..connect();

    expect(svc.status, ConnectionStatus.error);
    await tester.pump(const Duration(seconds: 2));
    expect(calls, 2);
    svc.dispose();
  });

  socketTest('calling connect again replaces the old socket and ignores its frames', (tester) async {
    service.connect();
    final first = harness.channel;
    service.connect();
    final second = harness.channel;

    expect(second, isNot(same(first)));
    expect(first.closedByClient, isTrue);

    first.emit(jsonEncode(stateJson(playerName: 'Stale')));
    second.emit(jsonEncode(stateJson(playerName: 'Fresh')));
    await pumpFrames(tester);

    expect(service.state?.playerName, 'Fresh');
  });

  testWidgets('dispose closes the socket and cancels the reconnect timer', (tester) async {
    service.connect();
    harness.channel.serverClose();
    await pumpFrames(tester);
    expect(service.status, ConnectionStatus.error);

    service.dispose();
    await tester.pump(const Duration(seconds: 5));

    expect(harness.channels, hasLength(1));
  });
}
