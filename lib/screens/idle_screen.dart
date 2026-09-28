import 'package:flutter/material.dart';

/// A blank black screen, shown instead of the companion UI whenever there's
/// nothing for it to show: not connected to the game / no save loaded, or
/// the game is in a cutscene, sleeping, or on a loading screen
/// (`GameState.idle`) — see [HomeScreen].
class IdleScreen extends StatelessWidget {
  const IdleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.black, child: SizedBox.expand());
  }
}
