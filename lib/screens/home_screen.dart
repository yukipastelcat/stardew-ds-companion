import 'package:flutter/material.dart';

import '../services/game_connection_service.dart';
import 'companion_screen.dart';
import 'idle_screen.dart';
import 'settings_screen.dart';

/// Top-level screen. Shows [IdleScreen] while the connection to the game
/// is not yet established (disconnected/connecting/error), and switches
/// to [CompanionScreen] once connected. A tap target in the top-right
/// corner is reserved for the settings icon, which opens [SettingsScreen]
/// (where the host/IP is entered).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _connection = GameConnectionService();

  @override
  void initState() {
    super.initState();
    _connection.autoConnect();
  }

  @override
  void dispose() {
    _connection.dispose();
    super.dispose();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(connection: _connection),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _connection,
          builder: (context, _) {
            final connected = _connection.isConnected;
            return Stack(
              children: [
                Positioned.fill(
                  child: connected ? CompanionScreen(connection: _connection) : const IdleScreen(),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: 'Settings',
                    onPressed: _openSettings,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
