import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/stardew_colors.dart';

/// The backpack toolbar's Journal button, placed below the organize
/// button (see `BackpackToolbar`) and sized to match it — same "the icon
/// itself is the tap target" construction as `OrganizeButton`, reusing
/// its warm pressed-tint treatment. Tapping calls [onPressed]
/// (`GameConnectionService.openJournal`), which asks the mod to open the
/// real in-game `QuestLog` menu — the same menu the vanilla journal
/// key/quest-log button opens.
///
/// While [hasNewQuestActivity] is true, a small "!" badge ([pulseIconUrl]
/// — `UiIconCache`'s "journal-pulse", the exact crop `DayTimeMoneyBox`
/// itself draws) pulses over the button's top-right corner, replicating
/// the real in-game quest-log button's own "new activity" animation:
/// verified against the decompiled `DayTimeMoneyBox.draw`'s
/// `questPulseTimer` scale formula
/// (`1f / (Math.Max(300f, Math.Abs(questPulseTimer % 1000 - 500)) / 500f)`)
/// — a smooth pulse from 1x scale at each 1-second cycle's edges up to
/// ~1.67x at its midpoint. [_pulseController] repeats every 1000ms
/// (matching that same 1000ms modulus) while [hasNewQuestActivity] stays
/// true, and [_scaleMultiplier] below reproduces that exact formula
/// against the controller's own `value` (0-1, standing in for vanilla's
/// countdown timer — the formula is symmetric across the cycle, so
/// counting up instead of down traces the same curve). Vanilla also
/// jitters the badge by a random +/-1px while scale > 1; that's skipped
/// here as a deliberate simplification (a per-frame `Random` in a widget
/// build isn't worth the added complexity for a 1px wobble).
class JournalButton extends StatefulWidget {
  const JournalButton({
    super.key,
    required this.iconUrl,
    required this.pulseIconUrl,
    required this.onPressed,
    required this.hasNewQuestActivity,
    required this.size,
  });

  final String? iconUrl;
  final String? pulseIconUrl;
  final VoidCallback onPressed;
  final bool hasNewQuestActivity;

  /// Matches the inventory grid's own per-slot size, same as
  /// `OrganizeButton.size`.
  final double size;

  @override
  State<JournalButton> createState() => _JournalButtonState();
}

class _JournalButtonState extends State<JournalButton> with SingleTickerProviderStateMixin {
  static const _pressedTint = Color(0x8DFCE7B8); // StardewColors.parchment at ~55% opacity

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    if (widget.hasNewQuestActivity) _pulseController.repeat();
  }

  @override
  void didUpdateWidget(JournalButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasNewQuestActivity && !oldWidget.hasNewQuestActivity) {
      _pulseController.repeat();
    } else if (!widget.hasNewQuestActivity && oldWidget.hasNewQuestActivity) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  /// See the class doc comment — reproduces `DayTimeMoneyBox.draw`'s
  /// `questPulseTimer` scale formula against [_pulseController]'s own
  /// 0-1 `value`.
  static double _scaleMultiplier(double t) {
    final ms = t * 1000;
    final v = (ms - 500).abs();
    final denom = math.max(300.0, v) / 500.0;
    return 1 / denom;
  }

  @override
  Widget build(BuildContext context) {
    Widget icon = widget.iconUrl == null
        ? Icon(Icons.menu_book, size: widget.size, color: StardewColors.wood)
        : Image.network(
            widget.iconUrl!,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
            errorBuilder: (context, error, stackTrace) =>
                Icon(Icons.menu_book, size: widget.size, color: StardewColors.wood),
          );

    if (_pressed) {
      icon = ColorFiltered(
        colorFilter: const ColorFilter.mode(_pressedTint, BlendMode.srcATop),
        child: icon,
      );
    }

    final badgeSize = widget.size * 0.4;

    return Tooltip(
      message: 'Journal',
      child: InkWell(
        customBorder: const CircleBorder(),
        // Calls GameConnectionService.openJournal, which asks the mod to
        // open the real in-game QuestLog menu — same result as pressing
        // the journal key (or the in-game quest-log button) in-game.
        onTap: widget.onPressed,
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              icon,
              if (widget.hasNewQuestActivity)
                Positioned(
                  top: -badgeSize * 0.4,
                  right: -badgeSize * 0.4,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = _scaleMultiplier(_pulseController.value);
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: SizedBox(
                      width: badgeSize,
                      height: badgeSize,
                      child: widget.pulseIconUrl == null
                          ? const DecoratedBox(
                              decoration: BoxDecoration(
                                color: StardewColors.accentRed,
                                shape: BoxShape.circle,
                              ),
                            )
                          : Image.network(
                              widget.pulseIconUrl!,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.none,
                              errorBuilder: (context, error, stackTrace) => const DecoratedBox(
                                decoration: BoxDecoration(
                                  color: StardewColors.accentRed,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
