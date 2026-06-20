import 'package:flutter/material.dart';

import '../../../../app/widgets/foundation/foundation.dart';
import '../../application/advanced_theme_service.dart';
import '../advanced_theme_list_actions.dart';

class AdvancedThemeSummaryCard extends StatelessWidget {
  const AdvancedThemeSummaryCard({
    super.key,
    required this.theme,
    required this.isActive,
    required this.isSelected,
    required this.isSelectionMode,
    required this.isSaving,
    required this.previewStrip,
    required this.onTap,
    this.onLongPress,
    required this.onSelectionChanged,
    required this.onActionSelected,
    this.compact = false,
  });

  final AdvancedThemeSummary theme;
  final bool isActive;
  final bool isSelected;
  final bool isSelectionMode;
  final bool isSaving;
  final Widget previewStrip;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool?> onSelectionChanged;
  final ValueChanged<AdvancedThemeAction> onActionSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showSelectedState = isSelectionMode && isSelected;
    return AppSurface(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      backgroundColor:
          showSelectedState
              ? colorScheme.primary.withValues(alpha: 0.12)
              : isActive
              ? colorScheme.primary.withValues(alpha: 0.08)
              : colorScheme.surfaceContainerLow,
      borderColor:
          showSelectedState
              ? colorScheme.primary.withValues(alpha: 0.72)
              : isActive
              ? colorScheme.primary.withValues(alpha: 0.55)
              : colorScheme.outlineVariant.withValues(alpha: 0.45),
      onTap: isSaving ? null : onTap,
      onLongPress: isSaving ? null : onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isSelectionMode) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap:
                      isSaving ? null : () => onSelectionChanged(!isSelected),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: AppSelectionIndicator(
                      selected: isSelected,
                      enabled: !isSaving,
                      semanticLabel: isSelected ? '已选择主题' : '未选择主题',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _AdvancedThemeSummaryTitle(
                  theme: theme,
                  isActive: isActive,
                ),
              ),
              if (!isSelectionMode) ...[
                if (isActive) ...[
                  const SizedBox(width: 12),
                  const _ActiveThemeStatusIcon(),
                ],
                const SizedBox(width: 8),
                AppMenuButton<AdvancedThemeAction>(
                  enabled: !isSaving,
                  onSelected: onActionSelected,
                  actions: const [
                    AppMenuAction(
                      value: AdvancedThemeAction.edit,
                      label: '编辑',
                      icon: Icons.edit_outlined,
                    ),
                    AppMenuAction(
                      value: AdvancedThemeAction.duplicate,
                      label: '复制',
                      icon: Icons.copy_rounded,
                    ),
                    AppMenuAction(
                      value: AdvancedThemeAction.exportZip,
                      label: '导出 ZIP',
                      icon: Icons.archive_outlined,
                    ),
                    AppMenuAction(
                      value: AdvancedThemeAction.delete,
                      label: '删除',
                      icon: Icons.delete_outline,
                      destructive: true,
                    ),
                  ],
                ),
              ],
            ],
          ),
          if (!compact) ...[const SizedBox(height: 10), previewStrip],
        ],
      ),
    );
  }
}

class _AdvancedThemeSummaryTitle extends StatelessWidget {
  const _AdvancedThemeSummaryTitle({
    required this.theme,
    required this.isActive,
  });

  final AdvancedThemeSummary theme;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                theme.name,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (isActive) const _ActiveThemeBadge(),
          ],
        ),
        if ((theme.category?.trim().isNotEmpty ?? false))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              theme.category!.trim(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _ActiveThemeStatusIcon extends StatelessWidget {
  const _ActiveThemeStatusIcon();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: '当前生效',
      child: Icon(
        Icons.verified_outlined,
        size: 20,
        color: colorScheme.primary.withValues(alpha: 0.78),
      ),
    );
  }
}

class _ActiveThemeBadge extends StatelessWidget {
  const _ActiveThemeBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '当前生效',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
