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
      theme: ThemeData(
        textTheme: stardewTextTheme(),
        scaffoldBackgroundColor: StardewColors.wood,
      ),
      home: const HomeScreen(),
    );
  }
}
