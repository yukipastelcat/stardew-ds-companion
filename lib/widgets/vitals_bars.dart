import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../services/game_connection_service.dart';
import 'vital_bar.dart';

/// The vanilla health and energy (stamina) bars, side by side, drawn next
/// to the companion's clock (see `BackpackToolbar`). Just a thin layout
/// container — each bar is a self-contained [VitalBar] (frame sprite,
/// fill, shake, pulse / tired face, droplet particles). **Health left,
/// energy right** (vanilla draws the health bar 56px left of the stamina
/// bar; the energy bar ends up nearest the clock). Both are always shown,
/// regardless of location or current health — a deliberate difference
/// from vanilla, which hides the health bar outside danger zones at full
/// HP.
///
/// Sized by its `LayoutBuilder` to the height it's given (the clock's
/// body height minus its leg pegs — see `BackpackToolbar`); the bars
/// take their width from that at [VitalBar.frameAspect], so they stay
/// skinny no matter how wide the Backpack grid is.
class VitalsBars extends StatelessWidget {
  const VitalsBars({super.key, required this.connection, required this.state});

  final GameConnectionService connection;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final c = connection;
    final s = state;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The parent (BackpackToolbar) pins the height; width comes in
        // unbounded (a non-flex Row child), so derive everything from the
        // height.
        final height = constraints.maxHeight.isFinite ? constraints.maxHeight : constraints.maxWidth;
        final barWidth = height * VitalBar.frameAspect;
        final gap = barWidth * 0.35;
        final totalWidth = barWidth * 2 + gap;

        return SizedBox(
          width: totalWidth,
          height: height,
          child: Stack(
            // Droplets / the tired face reach outside the bar box.
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: barWidth,
                height: height,
                child: VitalBar(
                  kind: VitalKind.health,
                  value: s.health,
                  max: s.maxHealth,
                  shake: s.healthShake,
                  capTopUrl: c.vitalsBarPieceUrl('health', 'cap-top'),
                  bodyUrl: c.vitalsBarPieceUrl('health', 'body'),
                  capBottomUrl: c.vitalsBarPieceUrl('health', 'cap-bottom'),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                width: barWidth,
                height: height,
                child: VitalBar(
                  kind: VitalKind.energy,
                  value: s.energy,
                  max: s.maxEnergy,
                  shake: s.energyShake,
                  exhausted: s.exhausted,
                  capTopUrl: c.vitalsBarPieceUrl('energy', 'cap-top'),
                  bodyUrl: c.vitalsBarPieceUrl('energy', 'body'),
                  capBottomUrl: c.vitalsBarPieceUrl('energy', 'cap-bottom'),
                  exhaustedUrl: c.vitalsExhaustedUrl,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
