import 'dart:async';

import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A [WebSocketChannel] driven by the test instead of a real socket.
///
/// [emit] plays the mod pushing a text frame; [serverClose] / [serverError]
/// play the connection dropping.
class FakeWebSocketChannel extends StreamChannelMixin<dynamic> implements WebSocketChannel {
  final StreamController<dynamic> _incoming = StreamController<dynamic>();
  final Completer<void> _ready = Completer<void>();
  final FakeWebSocketSink _sink = FakeWebSocketSink();

  /// True once the app side closed the sink (e.g. on reconnect or dispose).
  bool get closedByClient => _sink.closed;

  void emit(Object? frame) => _incoming.add(frame);

  void serverClose() => _incoming.close();

  void serverError(Object error) => _incoming.addError(error);

  void markReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  void failReady(Object error) {
    if (!_ready.isCompleted) _ready.completeError(error);
  }

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  Future<void> get ready => _ready.future;

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;
}

class FakeWebSocketSink implements WebSocketSink {
  bool closed = false;

  @override
  void add(dynamic data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) => stream.drain<void>();

  @override
  Future<void> close([int? closeCode, String? closeReason]) {
    closed = true;
    return Future<void>.value();
  }

  @override
  Future<void> get done => Future<void>.value();
}
