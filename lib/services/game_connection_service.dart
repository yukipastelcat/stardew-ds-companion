import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/game_state.dart';

/// Connection status, surfaced to the UI so it can show something more
/// useful than a blank screen while (re)connecting.
enum ConnectionStatus { disconnected, connecting, connected, error }

/// Connects to the StardewDS SMAPI mod's companion server for live game
/// state, and sends item-selection/move requests to it.
///
/// Live state comes over a WebSocket (`GET /ws` — see
/// stardew-ds-mod/CompanionServer.cs), which the mod pushes a fresh
/// snapshot to whenever it actually changes, instead of this class
/// polling for it — noticeably lower latency than the original 1.5s
/// poll, and no wasted requests when nothing's changed. `/select` and
/// `/move` stay plain HTTP POSTs (via `package:http`) since they're
/// one-off commands, not something to keep a stream open for.
///
/// `package:web_socket_channel` is used instead of `dart:io`'s
/// `WebSocket` because `dart:io` doesn't work on the web target, and
/// building the app as a web app (via Docker) is the easiest way to test
/// this without installing Flutter locally or needing a phone/emulator —
/// `web_socket_channel` works the same way on native builds too, so this
/// isn't a web-only workaround (same reasoning that led to `package:http`
/// for the POST requests).
///
/// A dropped/failed socket retries forever after a fixed short delay
/// ([_reconnectDelay]) — no exponential backoff, since a game that's
/// briefly unreachable (still loading, save screen) should reconnect
/// quickly once it's back, and this is a fixed localhost connection,
/// not a public service worth being gentle with.
class GameConnectionService extends ChangeNotifier {
  GameConnectionService({this.port = 8082});

  /// Must match `Port` in stardew-ds-mod/ModEntry.cs.
  final int port;

  static const _requestTimeout = Duration(seconds: 3);

  /// Delay before retrying the WebSocket after it drops or fails to
  /// connect — see the class doc comment for why this is fixed instead
  /// of backing off.
  static const _reconnectDelay = Duration(seconds: 2);

  String? _host;
  final http.Client _client = http.Client();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSubscription;
  Timer? _reconnectTimer;

  /// Bumped every time [connect] runs, so a socket event (onDone/onError)
  /// arriving after the app has already moved on can tell it's stale and
  /// ignore itself instead of clobbering the newer state.
  int _connectionGeneration = 0;

  ConnectionStatus _status = ConnectionStatus.disconnected;
  GameState? _state;
  String? _lastError;

  String? get host => _host;
  ConnectionStatus get status => _status;
  GameState? get state => _state;
  String? get lastError => _lastError;
  bool get isConnected => _status == ConnectionStatus.connected;

  /// Opens the `ws://localhost:$port/ws` connection to the mod. The mod
  /// always runs on the same device as this app, so there's no host/IP
  /// to configure — call this once, right after construction.
  void connect() {
    _host = 'localhost';
    _status = ConnectionStatus.connecting;
    _lastError = null;
    _connectionGeneration++;
    notifyListeners();

    _openSocket();
  }

  void _openSocket() {
    _closeSocket(keepGeneration: true);

    final generation = _connectionGeneration;
    final uri = Uri(scheme: 'ws', host: _host!, port: port, path: '/ws');

    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;

      // `WebSocketChannel.connect` returns synchronously without
      // actually connecting — per its own doc comment, a failed
      // connection attempt (mod/game not running yet, wrong port, the
      // common case here since this app polls a fixed localhost
      // address) completes `channel.ready` with an error (a
      // WebSocketChannelException, or a TimeoutException) rather than
      // throwing here or necessarily reaching `stream`'s `onError`.
      // Left unobserved, that rejected Future is reported by Dart as
      // an unhandled exception — this is that report the user saw.
      // `_onSocketDown` is idempotent (it checks `generation` and
      // cancels/resets before scheduling a retry), so it's safe to
      // route both this and `stream`'s own `onError`/`onDone` (kept
      // below as a second, redundant safety net for a connection that
      // drops after having connected successfully) through it.
      channel.ready.catchError((Object _) {
        _onSocketDown(generation);
      });

      _channelSubscription = channel.stream.listen(
        (raw) => _onMessage(generation, raw),
        onError: (Object _) => _onSocketDown(generation),
        onDone: () => _onSocketDown(generation),
        cancelOnError: true,
      );
    } catch (_) {
      _onSocketDown(generation);
    }
  }

  void _onMessage(int generation, dynamic raw) {
    if (generation != _connectionGeneration) return; // stale socket, ignore

    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      if (json['connected'] == false) {
        // Mod is reachable but no save is loaded yet.
        _state = null;
        _status = ConnectionStatus.connecting;
        _lastError = 'Connected to the mod — load a save to see live data.';
      } else {
        _state = GameState.fromJson(json);
        _status = ConnectionStatus.connected;
        _lastError = null;
      }
    } catch (_) {
      // Malformed push — ignore it, the next one will reconcile.
      return;
    }
    notifyListeners();
  }

  void _onSocketDown(int generation) {
    if (generation != _connectionGeneration) return; // already superseded

    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel = null;

    _status = ConnectionStatus.error;
    _lastError = 'Could not reach the mod at localhost:$port — is the game running?';
    notifyListeners();

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (generation == _connectionGeneration) _openSocket();
    });
  }

  void _closeSocket({bool keepGeneration = false}) {
    if (!keepGeneration) _connectionGeneration++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  Uri _uri(String path) => Uri.parse('http://${_host!}:$port$path');

  /// Builds the URL for the mod's `GET /animal-sprite?type=` endpoint —
  /// a PNG of that breed's real in-game portrait, cropped straight out
  /// of the animal's own loaded sprite texture (see
  /// stardew-ds-mod/AnimalIconCache.cs) — not anything this app bundles
  /// or downloads itself. Keyed by [type] (`AnimalSummary.type`, e.g.
  /// "White Chicken") rather than by individual animal, since every
  /// animal of the same breed shares one texture — same sharing as
  /// [spriteUrl] caching per qualified item id rather than per
  /// inventory slot. Returns null when not connected or [type] is
  /// empty.
  String? animalSpriteUrl(String type) {
    if (_host == null || type.isEmpty) return null;
    return Uri(
      scheme: 'http',
      host: _host!,
      port: port,
      path: '/animal-sprite',
      queryParameters: {'type': type},
    ).toString();
  }

  /// Builds the URL for the mod's `GET /sprite` endpoint, which returns a
  /// PNG cropped from the player's own loaded game textures (see
  /// stardew-ds-mod/SpriteCache.cs) — real in-game art, not anything this
  /// app bundles or downloads itself. Returns null when not connected or
  /// [qualifiedItemId] is missing, so callers can fall back to a generic
  /// icon without a null check at every call site.
  String? spriteUrl(String? qualifiedItemId) {
    if (_host == null || qualifiedItemId == null || qualifiedItemId.isEmpty) {
      return null;
    }
    return Uri(
      scheme: 'http',
      host: _host!,
      port: port,
      path: '/sprite',
      queryParameters: {'id': qualifiedItemId},
    ).toString();
  }

  /// URL for the mod's `GET /portrait` endpoint — a PNG of the player's
  /// actual composited farmer sprite (see stardew-ds-mod/PortraitRenderer.cs).
  /// Null when not connected.
  String? get portraitUrl {
    if (_host == null) return null;
    return Uri(scheme: 'http', host: _host!, port: port, path: '/portrait').toString();
  }

  /// URL for the mod's `GET /mini-portrait` endpoint — a PNG of the real
  /// vanilla head+hair-only mini portrait (see
  /// stardew-ds-mod/MiniPortraitRenderer.cs), the exact
  /// `FarmerRenderer.drawMiniPortrat` render the GameMenu's Skills tab
  /// and MapPage's own player marker both use. Prefer this over
  /// [portraitUrl] anywhere a small face-only icon is wanted —
  /// [portraitUrl] is the full standing body and needs cropping to look
  /// right at a small size. Null when not connected.
  String? get miniPortraitUrl {
    if (_host == null) return null;
    return Uri(scheme: 'http', host: _host!, port: port, path: '/mini-portrait').toString();
  }

  /// URL for the real background image the vanilla inventory menu draws
  /// behind the player's portrait (day/night variant, swapped by the game
  /// itself at 7pm). Null when not connected.
  String? portraitBackgroundUrl(bool night) {
    if (_host == null) return null;
    return Uri(
      scheme: 'http',
      host: _host!,
      port: port,
      path: '/portrait-background',
      queryParameters: {'night': night.toString()},
    ).toString();
  }

  /// URL for the game's own 9-slice menu window-border texture (see
  /// stardew-ds-mod/WindowBorderCache.cs) — a single 60x60 PNG meant to
  /// be stretched with `Image.centerSlice`. Null when not connected.
  String? get windowBorderUrl {
    if (_host == null) return null;
    return Uri(scheme: 'http', host: _host!, port: port, path: '/window-border').toString();
  }

  /// URL for the backpack grid's own slot background frame (see
  /// stardew-ds-mod/InventorySlotIconCache.cs) — the same tile the
  /// vanilla inventory menu draws behind every item slot. Null when not
  /// connected.
  String? get slotFrameUrl {
    if (_host == null) return null;
    return Uri(scheme: 'http', host: _host!, port: port, path: '/slot-frame').toString();
  }

  /// URL for the darkened overlay the vanilla inventory menu draws (at
  /// ~50% opacity) over a backpack slot beyond the player's current
  /// capacity — composite it on top of [slotFrameUrl] at the same
  /// opacity for a locked slot. Null when not connected.
  String? get slotLockedOverlayUrl {
    if (_host == null) return null;
    return Uri(scheme: 'http', host: _host!, port: port, path: '/slot-locked-overlay').toString();
  }

  /// URL for the real vanilla hotbar's own highlighted-slot frame (see
  /// stardew-ds-mod/InventorySlotIconCache.cs — tile 56 on
  /// `Game1.menuTexture`, the same tile `Toolbar.draw` swaps in for
  /// whichever slot is `Game1.player.CurrentToolIndex`). Use this *in
  /// place of* [slotFrameUrl] for the currently selected/equipped slot,
  /// not layered on top of it — that's how the real game draws it too.
  /// Null when not connected.
  String? get slotSelectedFrameUrl {
    if (_host == null) return null;
    return Uri(scheme: 'http', host: _host!, port: port, path: '/slot-selected-frame').toString();
  }

  /// URL for the vanilla clock/day box's own backdrop sprite (see
  /// stardew-ds-mod/ClockCache.cs) — the wood-and-parchment box the real
  /// `DayTimeMoneyBox` draws itself. Null when not connected.
  String? get clockBoxUrl {
    if (_host == null) return null;
    return Uri(scheme: 'http', host: _host!, port: port, path: '/clock-box').toString();
  }

  /// URL for the vanilla clock's single sundial-style needle sprite (see
  /// stardew-ds-mod/ClockCache.cs) — there's no 12-hour analog face in
  /// the real game, just this one needle sweeping a half circle across
  /// the day. Null when not connected.
  String? get clockNeedleUrl {
    if (_host == null) return null;
    return Uri(scheme: 'http', host: _host!, port: port, path: '/clock-needle').toString();
  }

  /// URL for the real vanilla world map background (see
  /// stardew-ds-mod/WorldMapCache.cs) — the same texture the in-game map
  /// page itself draws. Combine with `GameState.mapMarkerX`/`mapMarkerY`
  /// (0-1 fractions of this image's own width/height) to place the
  /// player's position marker. Null when not connected.
  String? get worldMapUrl {
    if (_host == null) return null;
    return Uri(scheme: 'http', host: _host!, port: port, path: '/world-map').toString();
  }

  /// URL for one of the mod's fixed UI icons ("backpack", "map",
  /// "crafting"), cropped from the game's own UI spritesheet (see
  /// stardew-ds-mod/UiIconCache.cs). Null when not connected.
  String? iconUrl(String name) {
    if (_host == null) return null;
    return Uri(
      scheme: 'http',
      host: _host!,
      port: port,
      path: '/icon',
      queryParameters: {'name': name},
    ).toString();
  }

  /// URL for the real HUD season icon (0=spring..3=winter), cropped from
  /// the game's own Cursors sheet. Null when not connected.
  String? seasonIconUrl(int seasonNumber) => _numberedIconUrl('season-icon', seasonNumber);

  /// URL for the real HUD weather icon, keyed by the game's own weather
  /// icon code. Null when not connected.
  String? weatherIconUrl(int weatherIconCode) => _numberedIconUrl('weather-icon', weatherIconCode);

  /// URL for the real vanilla item-quality star badge matching
  /// [quality] (1=silver, 2=gold, 4=iridium — see
  /// `InventoryItem.quality`'s doc comment), cropped from the game's own
  /// Cursors sheet (`UiIconCache.cs`). Null for quality 0 (no badge —
  /// vanilla draws nothing for normal-quality items either) or when not
  /// connected.
  String? qualityStarUrl(int quality) {
    final name = switch (quality) {
      1 => 'quality-silver',
      2 => 'quality-gold',
      4 => 'quality-iridium',
      _ => null,
    };
    return name == null ? null : iconUrl(name);
  }

  /// URL for the real vanilla watering-can water-gauge frame/background
  /// (`GameConnectionService.iconUrl('watering-can-gauge')` — see
  /// `UiIconCache.cs`), the exact crop `WateringCan.drawInMenu` draws
  /// behind its own water-level fill. Null when not connected. The fill
  /// itself isn't a sprite (see `InventoryItem.waterFraction`/
  /// `waterCanIsBottomless`) — [InventorySlot] draws it as a plain
  /// solid-color rect, same as the sword cooldown-wipe overlay.
  String? get wateringCanGaugeUrl => iconUrl('watering-can-gauge');

  /// URLs for the health / energy (stamina) bar pieces the mod crops from
  /// the game's own Cursors sheet (`UiIconCache.cs`'s `vitals-*` entries),
  /// used by `VitalsBars` to redraw the bars the mod now hides in-game
  /// (`HudBarPatches.cs`). Each bar is a 3-piece vertical sprite: a fixed
  /// top cap, a vertically-stretched middle, and a fixed bottom cap. The
  /// colored fill isn't a sprite — `VitalsBars` paints it as a plain rect
  /// (see `InventoryItem.waterFraction` for the same pattern). Null when
  /// not connected.
  String? vitalsBarPieceUrl(String bar, String piece) => iconUrl('vitals-$bar-$piece');

  /// URL for the vanilla "tired" face sprite drawn above the energy bar
  /// while `GameState.exhausted` (`UiIconCache.cs` `vitals-exhausted`).
  String? get vitalsExhaustedUrl => iconUrl('vitals-exhausted');

  /// URL for the 5x6 droplet sprite vanilla spawns next to the bars —
  /// tinted red (blood, low health) or sky-blue (sweat, low stamina) by
  /// `VitalsBars`'s own particle layer (`UiIconCache.cs` `vitals-droplet`).
  String? get vitalsDropletUrl => iconUrl('vitals-droplet');

  String? _numberedIconUrl(String path, int n) {
    if (_host == null) return null;
    return Uri(
      scheme: 'http',
      host: _host!,
      port: port,
      path: '/$path',
      queryParameters: {'n': '$n'},
    ).toString();
  }

  /// Asks the mod to make the item at [index] the active/equipped one —
  /// the same as if the player had pressed that number key in-game.
  Future<void> selectSlot(int index) async {
    if (_host == null) return;

    try {
      await _client
          .post(
            _uri('/select'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'index': index}),
          )
          .timeout(_requestTimeout);
    } catch (_) {
      // Best-effort — the next state push will reconcile the real state
      // either way, so a dropped select request just means a brief stale
      // highlight until then rather than a crash.
    }
  }

  /// Asks the mod to swap whatever is in backpack slots [from] and [to]
  /// — the app's drag-and-drop between slots. Best-effort, same as
  /// [selectSlot]: the next state push reconciles the real arrangement
  /// either way, so a dropped request just means a brief visual lag rather than
  /// a crash. Callers should only allow this between two unlocked slots
  /// (index `< state.backpackSize`) — the mod also re-checks this and
  /// silently drops an out-of-range request.
  Future<void> moveItem(int from, int to) async {
    if (_host == null || from == to) return;

    try {
      await _client
          .post(
            _uri('/move'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'from': from, 'to': to}),
          )
          .timeout(_requestTimeout);
    } catch (_) {
      // Best-effort — see selectSlot's doc comment.
    }
  }

  /// Asks the mod to organize the backpack — the app's organize button.
  /// Calls the exact same game logic pressing the real in-game button
  /// does (`ItemGrabMenu.organizeItemsInList`), so the result matches.
  /// Best-effort, same as [selectSlot]/[moveItem].
  Future<void> organizeBackpack() async {
    if (_host == null) return;

    try {
      await _client
          .post(_uri('/organize'), headers: {'Content-Type': 'application/json'})
          .timeout(_requestTimeout);
    } catch (_) {
      // Best-effort — see selectSlot's doc comment.
    }
  }

  /// Asks the mod to open the real in-game Journal (quest log) menu —
  /// the Backpack screen's new Journal button. Opens the exact same
  /// `QuestLog` menu the journal key/in-game quest-log button does; see
  /// `ModEntry.ApplyPendingOpenJournal` for the guards against opening
  /// it mid-cutscene or over another menu. Best-effort, same as
  /// [selectSlot]/[moveItem]/[organizeBackpack].
  Future<void> openJournal() async {
    if (_host == null) return;

    try {
      await _client
          .post(_uri('/open-journal'), headers: {'Content-Type': 'application/json'})
          .timeout(_requestTimeout);
    } catch (_) {
      // Best-effort — see selectSlot's doc comment.
    }
  }

  @override
  void dispose() {
    _closeSocket();
    _client.close();
    super.dispose();
  }
}
