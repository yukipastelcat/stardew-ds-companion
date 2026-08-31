import 'package:flutter/material.dart';

import '../../services/game_connection_service.dart';
import '../../widgets/backpack_inventory.dart';
import '../../widgets/backpack_toolbar.dart';
import '../../widgets/farm_funds.dart';
import '../../widgets/farm_name.dart';
import '../../widgets/vitals_bars.dart';

/// The Backpack tab: `BackpackInventory` (the 36-slot grid), then the
/// full-width `FarmName` row, then `BackpackToolbar` (health/energy bars,
/// funds, clock, organize/journal), inside the game-styled window border
/// `CompanionScreen` already wraps every tab in. This widget owns the
/// `connection.state == null` guard (all three need a non-null
/// `GameState` to render) and the one `LayoutBuilder` that resolves the
/// shared grid layout — see `BackpackInventory.resolveLayout`'s doc
/// comment for why the grid and the toolbar can't each resolve their own
/// `slotSize` independently, and why the `FarmName` row's height is
/// reserved there.
///
/// The toolbar row is sized to match the grid's own rendered width
/// (rather than stretching to the full space `BackpackScreen` is given)
/// — see the `toolbarWidth` computation in `build`.
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

        return LayoutBuilder(
          builder: (context, constraints) {
            final layout = BackpackInventory.resolveLayout(
              constraints,
              toolbarHeightMultiplier: BackpackToolbar.heightMultiplier,
              reservedAboveToolbar: FarmName.rowHeight,
            );
            final toolbarWidth = layout.slotSize * layout.columns +
                (layout.columns - 1) * BackpackInventory.slotSpacing;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: BackpackInventory(
                    connection: connection,
                    state: state,
                    columns: layout.columns,
                    rows: layout.rows,
                    slotSize: layout.slotSize,
                  ),
                ),
                const SizedBox(height: BackpackInventory.spacingBeforeToolbar),
                // Farm name on its own full-width row, then the control
                // row — both centered at toolbarWidth (the grid's own
                // rendered width) rather than the Column's full stretch
                // width, so they line up with the grid's own edges
                // instead of the (sometimes wider) panel.
                Center(
                  child: SizedBox(
                    width: toolbarWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FarmName(farmName: state.farmName),
                        Transform.translate(
                          offset: Offset(0, 12),
                          child: BackpackToolbar(
                            slotSize: layout.slotSize,
                            organizeIconUrl: connection.iconUrl('organize'),
                            onOrganize: connection.organizeBackpack,
                            journalIconUrl: connection.iconUrl('journal'),
                            journalPulseIconUrl: connection.iconUrl('journal-pulse'),
                            onOpenJournal: connection.openJournal,
                            hasNewQuestActivity: state.hasNewQuestActivity,
                            funds: FarmFunds(currentFunds: state.currentFunds),
                            weekday: state.weekday,
                            season: state.season,
                            dayOfMonth: state.dayOfMonth,
                            hour24: state.hour24,
                            minute: state.minute,
                            weather: state.weather,
                            seasonIconUrl: connection.seasonIconUrl(state.seasonNumber),
                            weatherIconUrl: connection.weatherIconUrl(state.weatherIconCode),
                            clockBoxUrl: connection.clockBoxUrl,
                            clockNeedleUrl: connection.clockNeedleUrl,
                            vitals: VitalsBars(connection: connection, state: state),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
