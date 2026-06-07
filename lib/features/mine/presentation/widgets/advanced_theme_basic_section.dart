import 'package:flutter/material.dart';

import '../../../../app/platform/app_input_focus_behavior.dart';

class AdvancedThemeEditorTitle extends StatelessWidget {
  const AdvancedThemeEditorTitle({
    super.key,
    required this.isEditing,
    required this.nameController,
    required this.title,
    required this.onStartEditing,
    required this.onSubmitted,
  });

  final bool isEditing;
  final TextEditingController nameController;
  final String title;
  final VoidCallback onStartEditing;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: TextField(
          controller: nameController,
          autofocus: appEnableAutoFocusForTextInput,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          onSubmitted: onSubmitted,
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onStartEditing,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.edit_outlined,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
