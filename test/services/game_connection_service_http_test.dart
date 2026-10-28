import 'dart:convert';

import 'package:companion/services/game_connection_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/fake_websocket.dart';

void main() {
  late List<http.Request> requests;
  late GameConnectionService service;

  GameConnectionService build(http.Client client) => GameConnectionService(
        port: 9123,
        client: client,
        channelFactory: (_) => FakeWebSocketChannel(),
      );

  setUp(() {
    requests = [];
    service = build(MockClient((request) async {
      requests.add(request);
      return http.Response('', 200);
    }));
  });

  tearDown(() => service.dispose());

  test('actions are no-ops until connect() has been called', () async {
    await service.selectSlot(1);
    await service.moveItem(1, 2);
    await service.organizeBackpack();
    await service.openJournal();

    expect(requests, isEmpty);
  });

  group('after connect()', () {
    setUp(() => service.connect());

    test('selectSlot POSTs the index to /select', () async {
      await service.selectSlot(4);

      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(requests.single.url.toString(), 'http://localhost:9123/select');
      expect(requests.single.headers['Content-Type'], contains('application/json'));
      expect(jsonDecode(requests.single.body), {'index': 4});
    });

    test('moveItem POSTs from/to to /move', () async {
      await service.moveItem(2, 7);

      expect(requests.single.url.path, '/move');
      expect(jsonDecode(requests.single.body), {'from': 2, 'to': 7});
    });

    test('moveItem to the same slot sends nothing', () async {
      await service.moveItem(3, 3);
      expect(requests, isEmpty);
    });

    test('organizeBackpack POSTs to /organize', () async {
      await service.organizeBackpack();
      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/organize');
    });

    test('openJournal POSTs to /open-journal', () async {
      await service.openJournal();
      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/open-journal');
    });

    test('network failures are swallowed', () async {
      final failing = build(MockClient((_) async => throw http.ClientException('offline')))
        ..connect();
      addTearDown(failing.dispose);

      await expectLater(failing.selectSlot(1), completes);
      await expectLater(failing.moveItem(1, 2), completes);
      await expectLater(failing.organizeBackpack(), completes);
      await expectLater(failing.openJournal(), completes);
    });

    test('error responses are swallowed too', () async {
      final erroring = build(MockClient((_) async => http.Response('nope', 500)))..connect();
      addTearDown(erroring.dispose);

      await expectLater(erroring.selectSlot(1), completes);
    });
  });
}
