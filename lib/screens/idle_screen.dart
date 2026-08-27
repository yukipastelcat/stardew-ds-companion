import 'package:flutter/material.dart';

/// Shown on the home screen while the app is not yet connected to the
/// game (autoconnecting, connecting, or errored out) — see [HomeScreen].
/// Placeholder layout for now.
class IdleScreen extends StatelessWidget {
  const IdleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Idle Screen'));
  }
}
