import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/home_screen.dart';
import 'theme/stardew_colors.dart';

void main() {
  runApp(const StardewDSApp());
}

class StardewDSApp extends StatelessWidget {
  const StardewDSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StardewDS Companion',
      // Pixelify Sans: an open-license pixel-style stand-in for the
      // game's own font (which isn't redistributable — see
      // project memory `mod_companion_api.md`). Applied to the whole
      // TextTheme rather than a handful of call sites, so every plain
      // Text/TextStyle in the app picks it up via DefaultTextStyle.merge
      // instead of only widgets that explicitly opt in.
      theme: ThemeData(
        textTheme: GoogleFonts.pixelifySansTextTheme(),
        // Every Scaffold in the app (including HomeScreen's own, which
        // is what actually shows through in the safe-area strips above
        // CompanionScreen's nested Scaffold — status bar/notch area,
        // any gap around the settings icon) inherits this by default,
        // instead of Flutter's usual white. Setting it per-screen was
        // easy to miss a spot; this is the single source of truth.
        scaffoldBackgroundColor: StardewColors.wood,
      ),
      home: const HomeScreen(),
    );
  }
}
