import 'package:flutter/material.dart';

class BookshelfGridBookCardShell extends StatelessWidget {
  const BookshelfGridBookCardShell({
    super.key,
    required this.isPressed,
    required this.pressDuration,
    required this.selectionMode,
    required this.batchDeleting,
    required this.openingOrBusy,
    required this.onTapDown,
    required this.onTapCancel,
    required this.onTapUp,
    required this.onLongPress,
    required this.onTap,
    required this.child,
  });

  final bool isPressed;
  final Duration pressDuration;
  final bool selectionMode;
  final bool batchDeleting;
  final bool openingOrBusy;
  final VoidCallback onTapDown;
  final VoidCallback onTapCancel;
  final VoidCallback onTapUp;
  final Future<void> Function() onLongPress;
  final Future<void> Function() onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isPressed ? 0.985 : 1,
      duration: pressDuration,
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTapDown: selectionMode ? null : (_) => onTapDown(),
          onTapCancel: onTapCancel,
          onTapUp: (_) => onTapUp(),
          onLongPress:
              batchDeleting
                  ? null
                  : () {
                    onLongPress();
                  },
          onTap:
              openingOrBusy
                  ? null
                  : () {
                    onTap();
                  },
          child: SizedBox.expand(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
