import 'package:flutter/material.dart';

/// The farm's name (`"<name> Farm"`) on its own full-width row between the
/// inventory grid and the bottom control row (see `BackpackScreen`). One
/// line, centered, bold, ellipsised. Uses the ambient `DefaultTextStyle`
/// (the app's pixel font — see `main.dart`) scaled up 1.5x.
class FarmName extends StatelessWidget {
  const FarmName({super.key, required this.farmName});

  final String farmName;

  /// Fixed height of the name row — `BackpackScreen` reserves this above
  /// the toolbar so adding it doesn't squeeze the inventory grid into an
  /// overflow (see `BackpackInventory.resolveLayout`).
  static const double rowHeight = 24;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.apply(fontSizeFactor: 1.5, fontWeightDelta: 2);
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
