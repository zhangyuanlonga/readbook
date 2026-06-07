import 'package:flutter/material.dart';

class BookshelfListBookCardShell extends StatelessWidget {
  const BookshelfListBookCardShell({
    super.key,
    required this.isPressed,
    required this.pressDuration,
    required this.margin,
    required this.cardColor,
    required this.borderColor,
    required this.selectionMode,
    required this.openingOrBusy,
    required this.onTapDown,
    required this.onTapCancel,
    required this.onTapUp,
    required this.onTap,
    required this.child,
  });

  final bool isPressed;
  final Duration pressDuration;
  final EdgeInsets margin;
  final Color cardColor;
  final Color borderColor;
  final bool selectionMode;
  final bool openingOrBusy;
  final VoidCallback onTapDown;
  final VoidCallback onTapCancel;
  final VoidCallback onTapUp;
  final Future<void> Function() onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isPressed ? 0.988 : 1,
      duration: pressDuration,
      curve: Curves.easeOutCubic,
      child: Card(
        margin: margin,
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTapDown: selectionMode ? null : (_) => onTapDown(),
          onTapCancel: onTapCancel,
          onTapUp: (_) => onTapUp(),
          onTap:
              openingOrBusy
                  ? null
                  : () {
                    onTap();
                  },
          borderRadius: BorderRadius.circular(14),
          child: child,
        ),
      ),
    );
  }
}
