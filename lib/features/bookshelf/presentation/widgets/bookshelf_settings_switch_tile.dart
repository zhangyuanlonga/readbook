import 'package:flutter/material.dart';

/// 书架设置面板中的紧凑开关行。
///
/// 该组件只处理标题、副标题和 Switch 展示，不读取书架页面状态，也不负责持久化。
/// 页面层继续决定草稿状态和保存时机，后续拆分更多设置项时可以复用同一行样式。
class BookshelfSettingsSwitchTile extends StatelessWidget {
  const BookshelfSettingsSwitchTile({
    super.key,
    required this.value,
    required this.title,
    required this.onChanged,
    this.subtitle,
  });

  final bool value;
  final String title;
  final String? subtitle;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final enabled = onChanged != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color:
                          enabled
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12.5,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 64,
              child: Align(
                alignment: Alignment.centerRight,
                child: Switch.adaptive(value: value, onChanged: onChanged),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
