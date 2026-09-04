import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'theme/stardew_colors.dart';
import 'theme/stardew_fonts.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Hide the Android nav bar (and status bar) for a fullscreen, game-like feel.
  // It reappears temporarily on an edge swipe, then auto-hides again.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const StardewDSApp());
}

class StardewDSApp extends StatelessWidget {
  const StardewDSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StardewDS Companion',
      theme: ThemeData(
        textTheme: stardewTextTheme(),
        scaffoldBackgroundColor: StardewColors.wood,
      ),
      home: const HomeScreen(),
    );
  }
}
