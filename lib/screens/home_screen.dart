import 'package:flutter/material.dart';

import '../services/game_connection_service.dart';
import 'companion_screen.dart';
import 'idle_screen.dart';

/// Top-level screen. Shows [IdleScreen] while the connection to the game
/// is not yet established (disconnected/connecting/error), and switches
/// to [CompanionScreen] once connected. The mod always runs on the same
/// device as this app now, so there's no host/IP to configure — the
/// connection is opened automatically against localhost.
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
    _connection.connect();
  }

  @override
  void dispose() {
    _connection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _connection,
          builder: (context, _) {
            final connected = _connection.isConnected;
            return connected ? CompanionScreen(connection: _connection) : const IdleScreen();
          },
        ),
      ),
    );
  }
}
