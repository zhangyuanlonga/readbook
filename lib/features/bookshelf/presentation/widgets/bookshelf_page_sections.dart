import 'package:flutter/material.dart';

class BookshelfFilterChipData {
  const BookshelfFilterChipData({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
}

class BookshelfViewModeEditBar extends StatelessWidget {
  const BookshelfViewModeEditBar({
    super.key,
    required this.summaryText,
    required this.useGridView,
    required this.viewButtonEnabled,
    required this.onToggleViewMode,
  });

  final String summaryText;
  final bool useGridView;
  final bool viewButtonEnabled;
  final VoidCallback? onToggleViewMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Text(
          summaryText,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: useGridView ? '网格模式' : '列表模式',
          onPressed: viewButtonEnabled ? onToggleViewMode : null,
          visualDensity: VisualDensity.compact,
          iconSize: 20,
          color:
              viewButtonEnabled
                  ? (useGridView
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant)
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
          icon: Icon(
            useGridView ? Icons.grid_view_rounded : Icons.view_list_rounded,
          ),
        ),
      ],
    );
  }
}

class BookshelfFilterBar extends StatelessWidget {
  const BookshelfFilterBar({
    super.key,
    required this.baseChips,
    required this.customChips,
    required this.highlightFilterAction,
    required this.filterActionMessage,
    required this.onOpenFilterSheet,
  });

  final List<BookshelfFilterChipData> baseChips;
  final List<BookshelfFilterChipData> customChips;
  final bool highlightFilterAction;
  final String filterActionMessage;
  final VoidCallback? onOpenFilterSheet;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chipTextStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600);

    Widget buildChip(BookshelfFilterChipData chip, {bool secondary = false}) {
      final selected = chip.selected;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onLongPress: chip.onLongPress,
          child: ChoiceChip(
            label: Text(chip.label),
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            selected: selected,
            showCheckmark: false,
            onSelected: chip.onTap == null ? null : (_) => chip.onTap!.call(),
            backgroundColor: colorScheme.surfaceContainerLow.withValues(
              alpha: 0.35,
            ),
            selectedColor:
                secondary
                    ? colorScheme.secondaryContainer.withValues(alpha: 0.88)
                    : colorScheme.primaryContainer.withValues(alpha: 0.82),
            labelStyle: chipTextStyle?.copyWith(
              color:
                  selected
                      ? (secondary
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onPrimaryContainer)
                      : colorScheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            side: BorderSide(
              color:
                  selected
                      ? (secondary
                          ? colorScheme.secondary.withValues(alpha: 0.26)
                          : colorScheme.primary.withValues(alpha: 0.26))
                      : colorScheme.outlineVariant.withValues(alpha: 0.72),
              width: 0.8,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 38,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...baseChips.map((chip) => buildChip(chip)),
                ...customChips.map((chip) => buildChip(chip, secondary: true)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: filterActionMessage,
            child: TextButton.icon(
              onPressed: onOpenFilterSheet,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor:
                    highlightFilterAction
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
              ),
              icon: const Icon(Icons.filter_list_rounded, size: 18),
              label: const Text('筛选'),
            ),
          ),
        ],
      ),
    );
  }
}

class BookshelfStepperSettingRow extends StatelessWidget {
  const BookshelfStepperSettingRow({
    super.key,
    required this.title,
    required this.valueLabel,
    required this.onDecrease,
    required this.onIncrease,
    this.subtitle,
    this.enabled = true,
  });

  final String title;
  final String valueLabel;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final String? subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveEnabled = enabled;

    Widget buildButton({
      required IconData icon,
      required VoidCallback? onPressed,
    }) {
      return IconButton(
        onPressed: effectiveEnabled ? onPressed : null,
        visualDensity: VisualDensity.compact,
        iconSize: 18,
        style: IconButton.styleFrom(
          backgroundColor: colorScheme.surfaceContainerLow,
          foregroundColor: colorScheme.onSurface,
          disabledBackgroundColor: colorScheme.surfaceContainerLow.withValues(
            alpha: 0.58,
          ),
          disabledForegroundColor: colorScheme.onSurfaceVariant.withValues(
            alpha: 0.45,
          ),
        ),
        icon: Icon(icon),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color:
                        effectiveEnabled
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                  ),
                ),
                if (subtitle case final text?) ...[
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          buildButton(icon: Icons.remove_rounded, onPressed: onDecrease),
          const SizedBox(width: 6),
          Container(
            constraints: const BoxConstraints(minWidth: 64),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              valueLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color:
                    effectiveEnabled
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 6),
          buildButton(icon: Icons.add_rounded, onPressed: onIncrease),
        ],
      ),
    );
  }
}

class BookshelfEmptyCard extends StatelessWidget {
  const BookshelfEmptyCard({super.key, required this.onImportLocal});

  final VoidCallback onImportLocal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(
              Icons.import_contacts_outlined,
              color: colorScheme.primary,
              size: 28,
            ),
            const SizedBox(height: 10),
            Text(
              '书架暂无内容',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '请先在搜索结果或详情页加入书架。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onImportLocal,
              icon: const Icon(Icons.library_add_rounded),
              label: const Text('导入本地图书'),
            ),
          ],
        ),
      ),
    );
  }
}

class BookshelfFilterEmptyCard extends StatelessWidget {
  const BookshelfFilterEmptyCard({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.filter_alt_off_rounded, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '当前“$label”分类暂无书籍',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookshelfLoadErrorCard extends StatelessWidget {
  const BookshelfLoadErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '书架加载失败',
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
            const SizedBox(height: 10),
            FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
