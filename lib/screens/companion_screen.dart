import 'package:flutter/material.dart';

import '../services/game_connection_service.dart';
import '../widgets/game_nav_bar.dart';
import '../widgets/game_window_box.dart';
import 'companion/backpack_screen.dart';
import 'companion/journal_screen.dart';
import 'companion/map_screen.dart';

/// Shown on the home screen once the app is connected to the game.
/// Hosts the Backpack/Map/Journal tabs behind a game-styled bottom
/// navigation bar — one in-game window border (`GameWindowBox`, same
/// as the Backpack panel) framing three flush, even-width tabs, each
/// with the real in-game icon (cropped by the mod's `UiIconCache` —
/// see `GameConnectionService.iconUrl`) and label shown in line.
class CompanionScreen extends StatefulWidget {
  const CompanionScreen({super.key, required this.connection});

  final GameConnectionService connection;

  @override
  State<CompanionScreen> createState() => _CompanionScreenState();
}

class _CompanionScreenState extends State<CompanionScreen> {
  int _selectedIndex = 0;

  List<Widget> get _screens => [
        BackpackScreen(connection: widget.connection),
        const MapScreen(),
        const JournalScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWindowBox(
        borderUrl: widget.connection.windowBorderUrl,
        padding: const EdgeInsets.all(kCompanionBoxPadding),
        child: SafeArea(bottom: false, child: _screens[_selectedIndex]),
      ),
      bottomNavigationBar: GameNavBar(
        selectedIndex: _selectedIndex,
        onSelected: (index) => setState(() => _selectedIndex = index),
        borderUrl: widget.connection.windowBorderUrl,
        destinations: [
          GameNavDestination(
            label: 'Backpack',
            fallbackIcon: Icons.backpack,
            iconUrl: widget.connection.iconUrl('backpack'),
          ),
          GameNavDestination(
            label: 'Map',
            fallbackIcon: Icons.map,
            iconUrl: widget.connection.iconUrl('map'),
          ),
          GameNavDestination(
            label: 'Journal',
            fallbackIcon: Icons.menu_book,
            iconUrl: widget.connection.iconUrl('skills'),
          ),
        ],
      ),
    );
  }
}
