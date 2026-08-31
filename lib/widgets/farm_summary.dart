import 'package:flutter/material.dart';

/// The farm's name (`"<name> Farm"`) on its own full-width row between the
/// inventory grid and the bottom control row (see `BackpackScreen`). One
/// line, centered, ellipsised. Uses the ambient `DefaultTextStyle` (the
/// app's pixel font — see `main.dart`) scaled up 1.5x.
class FarmName extends StatelessWidget {
  const FarmName({super.key, required this.farmName});

  final String farmName;

  /// Fixed height of the name row — `BackpackScreen` reserves this above
  /// the toolbar so adding it doesn't squeeze the inventory grid into an
  /// overflow (see `BackpackInventory.resolveLayout`).
  static const double rowHeight = 24;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.apply(fontSizeFactor: 1.5);
    return SizedBox(
      height: rowHeight,
      child: Center(
        child: Text(
          '$farmName Farm',
          style: style,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Current funds and lifetime earnings — the middle cell of the bottom
/// control row (see `BackpackToolbar`). Two lines, centered.
/// [totalEarnings] is nullable for backwards compat with older mod builds
/// that don't report it yet (see `GameState.totalEarnings`).
class FarmFunds extends StatelessWidget {
  const FarmFunds({
    super.key,
    required this.currentFunds,
    required this.totalEarnings,
  });

  final int currentFunds;
  final int? totalEarnings;

  @override
  Widget build(BuildContext context) {
    final lineStyle = DefaultTextStyle.of(context).style.apply(fontSizeFactor: 1.5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Current: ${currentFunds}g', style: lineStyle, textAlign: TextAlign.center),
        Text('Total: ${totalEarnings ?? 0}g', style: lineStyle, textAlign: TextAlign.center),
      ],
    );
  }
}
