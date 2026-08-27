import 'package:flutter/material.dart';

import '../models/inventory_item.dart';
import '../theme/stardew_colors.dart';
import 'inventory_slot.dart';

/// Wraps [InventorySlot] with drag-and-drop between backpack slots.
///
/// A long-press-and-drag on a slot holding an item picks it up; a plain
/// tap still reaches [InventorySlot]'s own [onTap] underneath, since
/// [LongPressDraggable] only takes over once the long-press fires — this
/// is why it's used here instead of a plain [Draggable], which would
/// otherwise compete with tap-to-select. Dropping on another unlocked
/// slot calls [onMove] with (fromIndex, toIndex); the destination slot
/// gets a green outline while a compatible drag hovers over it. Locked
/// slots are neither draggable nor droppable, and an empty slot can be a
/// drop target but can't itself be picked up.
class DraggableInventorySlot extends StatelessWidget {
  const DraggableInventorySlot({
    super.key,
    required this.index,
    required this.item,
    required this.locked,
    this.selected = false,
    this.spriteUrl,
    this.frameUrl,
    this.selectedFrameUrl,
    this.lockedOverlayUrl,
    this.onTap,
    this.onMove,
  });

  final int index;
  final InventoryItem? item;
  final bool locked;
  final bool selected;
  final String? spriteUrl;
  final String? frameUrl;
  final String? selectedFrameUrl;
  final String? lockedOverlayUrl;
  final VoidCallback? onTap;

  /// Called with (fromIndex, toIndex) when an item is dropped on this
  /// slot from a different one. Null disables drag-and-drop entirely
  /// (the slot behaves like a plain [InventorySlot]).
  final void Function(int from, int to)? onMove;

  @override
  Widget build(BuildContext context) {
    final slot = InventorySlot(
      item: item,
      locked: locked,
      selected: selected,
      spriteUrl: spriteUrl,
      frameUrl: frameUrl,
      selectedFrameUrl: selectedFrameUrl,
      lockedOverlayUrl: lockedOverlayUrl,
      onTap: onTap,
    );

    if (locked || onMove == null) return slot;

    final target = DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) => onMove!(details.data, index),
      builder: (context, candidateData, rejectedData) {
        if (candidateData.isEmpty) return slot;
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: StardewColors.accentGreen, width: 3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: slot,
        );
      },
    );

    if (item == null) return target;

    return LongPressDraggable<int>(
      data: index,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _DragFeedback(spriteUrl: spriteUrl),
      childWhenDragging: Opacity(opacity: 0.35, child: target),
      child: target,
    );
  }
}

/// Small floating copy of the item's sprite shown under the finger while
/// dragging.
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({this.spriteUrl});

  final String? spriteUrl;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 48,
        height: 48,
        child: spriteUrl == null
            ? const Icon(Icons.drag_indicator, color: StardewColors.wood)
            : Image.network(
                spriteUrl!,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
              ),
      ),
    );
  }
}
