import 'package:flutter/material.dart';

import '../services/game_connection_service.dart';
import '../widgets/game_nav_bar.dart';
import '../widgets/game_window_box.dart';
import 'companion/backpack_screen.dart';
import 'companion/map_screen.dart';
import 'companion/skills_screen.dart';

/// Shown on the home screen once the app is connected to the game.
/// Hosts the Backpack/Map/Skills tabs behind a plain top navigation
/// bar (icon-only, no window-border background or labels — see
/// `GameNavBar`'s doc comment). Per user request the nav bar now
/// *overlays* the game-styled `GameWindowBox` panel instead of sitting
/// above it and pushing it down: the panel fills the full available
/// area and the nav bar floats on top of its top edge in a `Stack`
/// (`GameWindowBox` listed first so it paints underneath, `GameNavBar`
/// second so it paints — and hit-tests — on top). Because the bar has
/// no background of its own (see `GameNavBar`'s doc comment), the
/// window's own wood/parchment border/art shows through around and
/// behind the icons rather than a solid strip. A single outer
/// `SafeArea` wraps the `Stack` so the nav bar itself still clears the
/// notch/status bar.
///
/// The third tab used to be a "Journal" placeholder; it's now "Skills"
/// (`SkillsScreen`, repeating the real vanilla Skills page's own
/// layout) — the actual in-game Journal (quest log) is opened directly
/// in-game instead, via a new button on the Backpack screen's toolbar
/// (see `backpack_toolbar.dart`'s `_JournalButton` and
/// `GameConnectionService.openJournal`).
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
        MapScreen(connection: widget.connection),
        SkillsScreen(connection: widget.connection),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Bottom layer: the window panel fills the whole area (it
            // no longer gets pushed down by an Expanded sibling — the
            // nav bar floats over its top edge instead of sitting in
            // its own row above it).
            Positioned.fill(
              top: 52,
              child: GameWindowBox(
                borderUrl: widget.connection.windowBorderUrl,
                padding: const EdgeInsets.all(kCompanionBoxPadding),
                child: _screens[_selectedIndex],
              ),
            ),
            // Top layer: the nav bar, pinned to the top edge, painted
            // (and hit-tested) over whatever the panel drew underneath.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GameNavBar(
                selectedIndex: _selectedIndex,
                onSelected: (index) => setState(() => _selectedIndex = index),
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
                    label: 'Skills',
                    fallbackIcon: Icons.bar_chart,
                    iconUrl: widget.connection.iconUrl('skills'),
                    // Vanilla's own "skills" tab icon is a bare frame with
                    // the player's mini portrait drawn on top separately —
                    // see GameNavDestination.portraitOverlayUrl's doc
                    // comment.
                    portraitOverlayUrl: widget.connection.miniPortraitUrl,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
