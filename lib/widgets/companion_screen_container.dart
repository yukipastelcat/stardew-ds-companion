import 'package:flutter/material.dart';

/// Padding [CompanionScreenContainer] applies around its child. Exposed
/// here, rather than left as a private literal inside the widget,
/// because `BackpackInventory`'s toolbar row deliberately breaks out of
/// this exact inset to sit flush against the box's true bottom edge
/// instead of respecting it like the rest of the tab content does —
/// see `BackpackInventory.build`'s doc comment.
const double kCompanionBoxPadding = 24.0;

/// The standard padded content area inside `CompanionScreen`'s outer
/// `GameWindowBox` panel. This used to be a `padding` parameter on
/// `GameWindowBox` itself; it was pulled out into its own widget so the
/// window border stays a plain, padding-agnostic frame and each tab
/// screen asks for this inset explicitly instead.
///
/// Every tab screen wraps its own top-level content in this widget —
/// `BackpackScreen`, `MapScreen`, and `SkillsScreen` all take the
/// default [hasPadding] of `true` for the standard [kCompanionBoxPadding]
/// inset. `AnimalsScreen` passes `hasPadding: false`: its table's
/// column-divider lines are positioned against the panel's own width,
/// so the full inset would pull the row content in from under them —
/// see `AnimalsScreen`'s own doc comment.
///
/// A [Stack] rather than a bare [Padding] so future overlay content
/// (e.g. a toast/badge anchored to this area) has somewhere to sit
/// alongside the padded [child] without another wrapper needing to be
/// added at the call site.
class CompanionScreenContainer extends StatelessWidget {
  const CompanionScreenContainer({super.key, required this.child, this.hasPadding = true});

  final Widget child;

  /// When false, applies a much smaller flush inset instead of the
  /// standard [kCompanionBoxPadding] — see `AnimalsScreen`, the only
  /// caller that sets this to false.
  final bool hasPadding;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: hasPadding ? const EdgeInsets.all(kCompanionBoxPadding) : const EdgeInsets.all(12),
          child: child,
        ),
      ],
    );
  }
}
