import 'package:flutter/material.dart';

import '../../../../app/platform/app_input_focus_behavior.dart';
import '../../../../app/widgets/foundation/foundation.dart';

class AdvancedThemeEditorTitle extends StatelessWidget {
  const AdvancedThemeEditorTitle({
    super.key,
    required this.isEditing,
    required this.nameController,
    required this.title,
    required this.onStartEditing,
    required this.onChanged,
    required this.onSubmitted,
  });

  final bool isEditing;
  final TextEditingController nameController;
  final String title;
  final VoidCallback onStartEditing;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: AppTextField(
          key: const ValueKey<String>('advanced_theme_name_field'),
          controller: nameController,
          autofocus: appEnableAutoFocusForTextInput,
          textInputAction: TextInputAction.done,
          onChanged: onChanged,
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
