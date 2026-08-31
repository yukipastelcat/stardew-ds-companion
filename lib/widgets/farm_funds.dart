import 'package:flutter/material.dart';

/// Current funds — the backpack toolbar's middle (flexible) cell (see
/// `BackpackToolbar`). Two centered lines:
///
/// ```
/// Current Funds:
/// <amount>g
/// ```
///
/// Vanilla shows current money only (no lifetime earnings on the HUD).
/// The amount is comma-grouped ([_grouped]); wrapping is allowed (the
/// toolbar row is tall enough that two short lines can't overflow it).
class FarmFunds extends StatelessWidget {
  const FarmFunds({super.key, required this.currentFunds});

  final int currentFunds;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.apply(fontSizeFactor: 1.5, fontWeightDelta: 2);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Current Funds:', style: style, textAlign: TextAlign.center),
        Text('${_grouped(currentFunds)}g', style: style, textAlign: TextAlign.center),
      ],
    );
  }

  /// Groups a non-negative integer's digits into thousands with commas
  /// ("1234567" -> "1,234,567"). Stardew money is never negative, so no
  /// sign handling. Dependency-free (no `intl`).
  static String _grouped(int value) => value
      .toString()
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
}
