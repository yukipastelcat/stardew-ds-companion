import 'package:flutter/material.dart';

/// Farm name, current funds, and lifetime earnings — plain text sitting
/// in the gap between the toolbar's organize/journal column and the
/// clock (see `BackpackToolbar`). Uses the ambient `DefaultTextStyle`
/// (the app's pixel font — see `main.dart`) scaled up 1.5x, and relies
/// on the parent to place/translate it.
///
/// [totalEarnings] is nullable for backwards compat with older mod
/// builds that don't report it yet (see `GameState.totalEarnings`).
class FarmSummary extends StatelessWidget {
  const FarmSummary({
    super.key,
    required this.farmName,
    required this.currentFunds,
    required this.totalEarnings,
  });

  final String farmName;
  final int currentFunds;
  final int? totalEarnings;

  @override
  Widget build(BuildContext context) {
    final lineStyle = DefaultTextStyle.of(context).style.apply(fontSizeFactor: 1.5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('$farmName Farm', style: lineStyle, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
        Text('Current Funds: $currentFunds', style: lineStyle, textAlign: TextAlign.center),
        Text('Total Earnings: ${totalEarnings ?? 0}', style: lineStyle, textAlign: TextAlign.center),
      ],
    );
  }
}
