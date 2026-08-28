import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/stardew_colors.dart';
import 'theme/stardew_fonts.dart';

void main() {
  runApp(const StardewDSApp());
}

class StardewDSApp extends StatelessWidget {
  const StardewDSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StardewDS Companion',
      // Sizes throughout this app (slotSize, kCompanionBoxPadding,
      // sprite crops, the clock's aspect box, etc.) are density-
      // independent pixels (dp) — Flutter's default logical-pixel
      // space, which the framework already scales against the real
      // device's devicePixelRatio automatically. No MediaQuery
      // override here: forcing devicePixelRatio to 1.0 would make
      // logical pixels equal raw physical pixels instead (~1240x1080
      // on the AYN Thor's screen), which doesn't match the ~1078x939dp
      // canvas this layout was actually tuned against (originally
      // tested at 355x315dp — see the compact-breakpoint math in
      // BackpackInventory.resolveLayout) and isn't what "density-
      // independent" sizing means.
      // Stardew Valley (FontStruct, RRDome, non-commercial license —
      // see lib/theme/stardew_fonts.dart) is the primary pixel font,
      // falling back to Pixelify Sans (the previous open-license
      // pixel-style stand-in for the game's own font, which isn't
      // redistributable — see project memory `mod_companion_api.md`)
      // for any glyph it doesn't cover. Applied to the whole TextTheme
      // rather than a handful of call sites, so every plain
      // Text/TextStyle in the app picks it up via DefaultTextStyle.merge
      // instead of only widgets that explicitly opt in.
      theme: ThemeData(
        textTheme: stardewTextTheme(),
        // Every Scaffold in the app (including HomeScreen's own, which
        // is what actually shows through in the safe-area strips above
        // CompanionScreen's nested Scaffold — status bar/notch area)
        // inherits this by default, instead of Flutter's usual white.
        // Setting it per-screen was easy to miss a spot; this is the
        // single source of truth.
        scaffoldBackgroundColor: StardewColors.wood,
      ),
      home: const HomeScreen(),
    );
  }
}
