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
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _connection = GameConnectionService();
  bool _connected = false;
  bool _idle = false;

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
    super.dispose();
  }

  /// Only the connected and idle switches matter here — rebuilding on
  /// every state push would rebuild the whole companion UI (nav bar,
  /// window frame, every tab) each time; the screens listen to the
  /// connection themselves for the parts that actually change.
  void _onConnectionChanged() {
    final connected = _connection.isConnected;
    final idle = _connection.state?.idle ?? false;
    if (connected != _connected || idle != _idle) {
      setState(() {
        _connected = connected;
        _idle = idle;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showCompanion = _connected && !_idle;
    return Scaffold(
      backgroundColor: showCompanion ? null : Colors.black,
      body: !_connected
          ? const IdleScreen()
          // While idle the companion stays mounted but offstage (not
          // painted, animations paused) rather than being torn down, so
          // the selected tab survives every cutscene and door transition.
          : Stack(
              fit: StackFit.expand,
              children: [
                Offstage(
                  offstage: _idle,
                  child: TickerMode(
                    enabled: !_idle,
                    child: SafeArea(child: CompanionScreen(connection: _connection)),
                  ),
                ),
                if (_idle) const IdleScreen(),
              ],
            ),
    );
  }
}
