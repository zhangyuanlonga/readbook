import 'package:flutter/material.dart';

class BookshelfBookMoreMenu extends StatelessWidget {
  const BookshelfBookMoreMenu({
    super.key,
    required this.menuChildren,
    required this.compact,
  });

  final List<Widget> menuChildren;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: menuChildren,
      builder: (context, controller, _) {
        return IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: '更多',
          iconSize: compact ? 17 : 20,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(
            width: compact ? 28 : 34,
            height: compact ? 28 : 34,
          ),
          onPressed: controller.isOpen ? controller.close : controller.open,
          icon: Icon(
            compact ? Icons.more_vert_rounded : Icons.more_horiz_rounded,
          ),
        );
      },
    );
  }
}

class BookshelfBookMenuItem extends StatelessWidget {
  const BookshelfBookMenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      leadingIcon: Icon(icon, size: 18),
      style:
          foregroundColor == null
              ? null
              : ButtonStyle(
                foregroundColor: WidgetStateProperty.all(foregroundColor),
              ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
