import 'package:flutter/material.dart';

import '../../services/game_connection_service.dart';
import '../../widgets/backpack_inventory.dart';

/// The Backpack tab. Thin shell around [BackpackInventory] (the window
/// border/background, the 3×12 slot grid, and the organize button) —
/// this widget's only job is the `connection.state == null` guard, since
/// `BackpackInventory` needs a non-null [GameState] to render.
class BackpackScreen extends StatelessWidget {
  const BackpackScreen({super.key, required this.connection});

  final GameConnectionService connection;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: connection,
      builder: (context, _) {
        final state = connection.state;
        if (state == null) {
          return const Center(child: Text('Waiting for game data…'));
        }

        return Padding(
          padding: const EdgeInsets.all(0),
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Stack(
                    children: [
                      BackpackInventory(connection: connection, state: state),
                    ],
                  ),
                );
              },
            )
          )
        );
      },
    );
  }
}
