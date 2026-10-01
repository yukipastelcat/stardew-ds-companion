import 'package:flutter/material.dart';

import '../services/game_connection_service.dart';
import 'companion_screen.dart';
import 'idle_screen.dart';

/// Top-level screen. Shows the black [IdleScreen] while the connection to
/// the game isn't established (disconnected/connecting/error, or no save
/// loaded) and while the game reports itself idle (`GameState.idle`: a
/// cutscene, sleeping, or a loading screen); [CompanionScreen] otherwise.
/// The mod always runs on the same device as this app now, so there's no
/// host/IP to configure — the connection is opened automatically against
/// localhost.
///
/// Switching between the two cross-fades through black, the way the game
/// itself fades out for a cutscene or a warp: the idle screen fades in over
/// the companion, and only once it's fully opaque is the companion taken
/// offstage (and back on before the black fades out again).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  static const _fadeOutDuration = Duration(milliseconds: 350);
  static const _fadeInDuration = Duration(milliseconds: 450);

  final _connection = GameConnectionService();
  bool _connected = false;
  bool _idle = false;

  /// Keeps the companion mounted while fading to black after a disconnect,
  /// so it doesn't vanish before the black has covered it.
  bool _companionMounted = false;

  /// Opacity of the black idle layer: 1 = fully idle, 0 = companion shown.
  late final AnimationController _black = AnimationController(
    vsync: this,
    value: 1,
    duration: _fadeOutDuration,
    reverseDuration: _fadeInDuration,
  )..addStatusListener(_onFadeStatus);

  bool get _showCompanion => _connected && !_idle;

  @override
  void initState() {
    super.initState();
    _connection.addListener(_onConnectionChanged);
    _connection.connect();
  }

  @override
  void dispose() {
    _connection.removeListener(_onConnectionChanged);
    _connection.dispose();
    _black.dispose();
    super.dispose();
  }

  /// Only the connected and idle switches matter here — rebuilding on
  /// every state push would rebuild the whole companion UI (nav bar,
  /// window frame, every tab) each time; the screens listen to the
  /// connection themselves for the parts that actually change.
  void _onConnectionChanged() {
    final connected = _connection.isConnected;
    final idle = _connection.state?.idle ?? false;
    if (connected == _connected && idle == _idle) return;

    setState(() {
      _connected = connected;
      _idle = idle;
      if (connected) _companionMounted = true;
    });
    if (_showCompanion) {
      _black.reverse();
    } else {
      _black.forward();
    }
  }

  /// Once fully black: drop the companion if the game went away, or just
  /// rebuild so it goes offstage (not painted, animations paused).
  void _onFadeStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    setState(() {
      if (!_connected) _companionMounted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hidden = _black.isCompleted && !_showCompanion;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_companionMounted)
            Offstage(
              offstage: hidden,
              child: TickerMode(
                enabled: !hidden,
                child: ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: SafeArea(child: CompanionScreen(connection: _connection)),
                ),
              ),
            ),
          // Blocks taps on the companion while it's fading out or still
          // covered, and lets them through once the black is gone.
          IgnorePointer(
            ignoring: _showCompanion,
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _black, curve: Curves.easeInOut),
              child: const IdleScreen(),
            ),
          ),
        ],
      ),
    );
  }
}
