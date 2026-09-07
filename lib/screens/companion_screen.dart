import 'package:flutter/material.dart';

import '../services/game_connection_service.dart';
import '../widgets/game_nav_bar.dart';
import '../widgets/game_window_box.dart';
import 'companion/animals_screen.dart';
import 'companion/backpack_screen.dart';
import 'companion/map_screen.dart';
import 'companion/skills_screen.dart';

/// Shown on the home screen once the app is connected to the game.
/// Hosts the Backpack/Map/Skills/Animals tabs behind a plain top
/// navigation bar (icon-only, no window-border background or labels
/// — see `GameNavBar`'s doc comment). Per user request the nav bar now
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
/// (see `journal_button.dart`'s `JournalButton` and
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
        AnimalsScreen(connection: widget.connection),
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
                    // see GameNavDestination.overlayIconUrl's doc comment.
                    overlayIconUrl: widget.connection.miniPortraitUrl,
                  ),
                  GameNavDestination(
                    label: 'Animals',
                    fallbackIcon: Icons.pets,
                    // CORRECTED twice now. First it pointed at a raw
                    // "White Chicken" creature-sprite crop as the tab's
                    // whole icon — no baked-in frame, unlike Backpack/
                    // Map/Skills' own icons, so it read as the one
                    // frameless tab (on the mistaken assumption vanilla
                    // has no real GameMenu tab for Animals at all). A
                    // second attempt tried to compensate by borrowing
                    // Skills' own bare-frame crop as a backing and
                    // compositing the chicken on top of it as an overlay
                    // — closer, but still not the actual thing, and
                    // called out as such. Vanilla 1.6 genuinely added its
                    // own real "animals" GameMenu tab (confirmed by
                    // reading the decompiled GameMenu.cs directly — see
                    // UiIconCache's own doc comment for the citation), so
                    // this now reads that real icon exactly the same
                    // simple way Backpack/Map do — one direct `iconUrl`
                    // crop, no overlay, no borrowed frame.
                    iconUrl: widget.connection.iconUrl('animals-tab'),
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
