import 'package:companion/services/game_connection_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('before connect()', () {
    late GameConnectionService service;

    setUp(() => service = GameConnectionService());
    tearDown(() => service.dispose());

    test('starts disconnected with no state', () {
      expect(service.status, ConnectionStatus.disconnected);
      expect(service.isConnected, isFalse);
      expect(service.state, isNull);
      expect(service.host, isNull);
      expect(service.lastError, isNull);
    });

    test('every URL builder returns null without a host', () {
      expect(service.spriteUrl('(O)24'), isNull);
      expect(service.animalSpriteUrl('Cat'), isNull);
      expect(service.portraitUrl, isNull);
      expect(service.portraitFrameUrl(1), isNull);
      expect(service.miniPortraitUrl, isNull);
      expect(service.portraitBackgroundUrl(true), isNull);
      expect(service.secretFriendUrl, isNull);
      expect(service.windowBorderUrl, isNull);
      expect(service.worldMapUrl, isNull);
      expect(service.iconUrl('backpack'), isNull);
      expect(service.seasonIconUrl(0), isNull);
      expect(service.weatherIconUrl(0), isNull);
      expect(service.qualityStarUrl(2), isNull);
    });
  });

  group('after connect()', () {
    late GameConnectionService service;

    setUp(() {
      service = GameConnectionService(port: 9123)..connect();
    });
    tearDown(() => service.dispose());

    test('targets localhost on the configured port', () {
      expect(service.host, 'localhost');
      expect(service.status, ConnectionStatus.connecting);
    });

    test('spriteUrl carries the item id as a query parameter', () {
      final uri = Uri.parse(service.spriteUrl('(O)24')!);

      expect(uri.scheme, 'http');
      expect(uri.host, 'localhost');
      expect(uri.port, 9123);
      expect(uri.path, '/sprite');
      expect(uri.queryParameters, {'id': '(O)24'});
    });

    test('spriteUrl is null for a missing or empty id', () {
      expect(service.spriteUrl(null), isNull);
      expect(service.spriteUrl(''), isNull);
    });

    test('animalSpriteUrl is null for an empty type', () {
      expect(service.animalSpriteUrl(''), isNull);
      final uri = Uri.parse(service.animalSpriteUrl('Cat-1')!);
      expect(uri.path, '/animal-sprite');
      expect(uri.queryParameters, {'type': 'Cat-1'});
    });

    test('portrait URLs carry the portrait version (0 without a state)', () {
      expect(Uri.parse(service.portraitUrl!).queryParameters, {'v': '0'});
      expect(Uri.parse(service.miniPortraitUrl!).path, '/mini-portrait');
      expect(
        Uri.parse(service.portraitFrameUrl(3, eyes: 1)!).queryParameters,
        {'frame': '3', 'eyes': '1', 'v': '0'},
      );
    });

    test('portraitBackgroundUrl encodes night', () {
      expect(Uri.parse(service.portraitBackgroundUrl(true)!).queryParameters, {'night': 'true'});
      expect(Uri.parse(service.portraitBackgroundUrl(false)!).queryParameters, {'night': 'false'});
    });

    test('numbered icons use the n parameter', () {
      final season = Uri.parse(service.seasonIconUrl(2)!);
      expect(season.path, '/season-icon');
      expect(season.queryParameters, {'n': '2'});

      final weather = Uri.parse(service.weatherIconUrl(5)!);
      expect(weather.path, '/weather-icon');
      expect(weather.queryParameters, {'n': '5'});
    });

    test('qualityStarUrl maps quality to the named icon', () {
      String? nameFor(int q) {
        final url = service.qualityStarUrl(q);
        return url == null ? null : Uri.parse(url).queryParameters['name'];
      }

      expect(nameFor(0), isNull);
      expect(nameFor(3), isNull);
      expect(nameFor(1), 'quality-silver');
      expect(nameFor(2), 'quality-gold');
      expect(nameFor(4), 'quality-iridium');
    });

    test('vitals helpers build on iconUrl', () {
      expect(Uri.parse(service.vitalsBarPieceUrl('health', 'top')!).queryParameters,
          {'name': 'vitals-health-top'});
      expect(Uri.parse(service.vitalsExhaustedUrl!).queryParameters, {'name': 'vitals-exhausted'});
      expect(Uri.parse(service.vitalsDropletUrl!).queryParameters, {'name': 'vitals-droplet'});
      expect(Uri.parse(service.wateringCanGaugeUrl!).queryParameters,
          {'name': 'watering-can-gauge'});
    });

    test('fixed-path endpoints', () {
      expect(Uri.parse(service.worldMapUrl!).path, '/world-map');
      expect(Uri.parse(service.secretFriendUrl!).path, '/secret-friend');
      expect(Uri.parse(service.windowBorderUrl!).path, '/window-border');
    });
  });
}
