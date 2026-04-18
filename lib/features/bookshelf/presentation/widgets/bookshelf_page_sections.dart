import 'package:flutter/material.dart';

import '../../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../../app/theme/app_border_tokens.dart';

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

class BookshelfInlineSearchBar extends StatelessWidget {
  const BookshelfInlineSearchBar({
    super.key,
    required this.palette,
    required this.controller,
    this.focusNode,
    required this.onChanged,
    required this.onClear,
    this.summaryText,
    this.hintText = '搜索书名、作者、标签、分类',
  });

  final ResolvedAdvancedThemePalette palette;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String? summaryText;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 42,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        textAlignVertical: TextAlignVertical.center,
        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.2),
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            height: 1.2,
            color: palette.textSecondaryColor,
          ),
          filled: true,
          fillColor: palette.searchFieldBackgroundColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: resolveAppBorderSide(
              Theme.of(context).colorScheme,
              baseColor: palette.outlineColor,
              containerColor: palette.searchFieldBackgroundColor,
              tone: AppBorderTone.strong,
              width: 1.2,
            ),
          ),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
          suffixIconConstraints: const BoxConstraints(minHeight: 40),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) {
              final hasSummary = (summaryText?.trim().isNotEmpty ?? false);
              if (!hasSummary && value.text.isEmpty) {
                return const SizedBox.shrink();
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasSummary)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: palette.surfaceColor.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          summaryText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: palette.textSecondaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (value.text.isNotEmpty)
                    IconButton(
                      tooltip: '清空搜索',
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  if (hasSummary && value.text.isEmpty)
                    const SizedBox(width: 12),
                ],
              );
            },
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 10,
          ),
        ),
      ),
    );
  }
}

class BookshelfInlineSearchTrigger extends StatelessWidget {
  const BookshelfInlineSearchTrigger({
    super.key,
    required this.palette,
    required this.summaryText,
    required this.onTap,
    this.label = '搜索书架',
  });

  final ResolvedAdvancedThemePalette palette;
  final String summaryText;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 40,
      child: Material(
        color: palette.searchFieldBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: palette.textSecondaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: palette.textSecondaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surfaceColor.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    summaryText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.textSecondaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BookshelfFilterBar extends StatelessWidget {
  const BookshelfFilterBar({
    super.key,
    required this.palette,
    required this.baseChips,
    required this.customChips,
    required this.highlightFilterAction,
    required this.filterActionMessage,
    required this.onOpenFilterSheet,
    this.showActionButton = true,
  });

  final ResolvedAdvancedThemePalette palette;
  final List<BookshelfFilterChipData> baseChips;
  final List<BookshelfFilterChipData> customChips;
  final bool highlightFilterAction;
  final String filterActionMessage;
  final VoidCallback? onOpenFilterSheet;
  final bool showActionButton;

  @override
  Widget build(BuildContext context) {
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
            backgroundColor: palette.surfaceColor.withValues(alpha: 0.35),
            selectedColor:
                secondary
                    ? palette.noticeSurfaceColor.withValues(alpha: 0.88)
                    : palette.noticeSurfaceColor.withValues(alpha: 0.82),
            labelStyle: chipTextStyle?.copyWith(
              color:
                  selected
                      ? (secondary
                          ? palette.noticeAccentColor
                          : palette.textPrimaryColor)
                      : palette.textSecondaryColor,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            side: BorderSide(
              color:
                  selected
                      ? (secondary
                          ? palette.noticeAccentColor.withValues(alpha: 0.26)
                          : resolveAppBorderColor(
                            Theme.of(context).colorScheme,
                            baseColor: palette.cardBorderColor,
                            containerColor: palette.noticeSurfaceColor,
                            tone: AppBorderTone.strong,
                          ))
                      : resolveAppBorderColor(
                        Theme.of(context).colorScheme,
                        baseColor: palette.cardBorderColor,
                        containerColor: palette.surfaceColor,
                      ),
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
          if (showActionButton) ...[
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
                          ? palette.primaryColor
                          : palette.textSecondaryColor,
                ),
                icon: const Icon(Icons.filter_list_rounded, size: 18),
                label: const Text('筛选'),
              ),
            ),
          ],
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
        visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
        iconSize: 17,
        style: IconButton.styleFrom(
          backgroundColor: colorScheme.surfaceContainerLow,
          foregroundColor: colorScheme.onSurface,
          disabledBackgroundColor: colorScheme.surfaceContainerLow.withValues(
            alpha: 0.58,
          ),
          disabledForegroundColor: colorScheme.onSurfaceVariant.withValues(
            alpha: 0.45,
          ),
          minimumSize: const Size(36, 36),
          padding: const EdgeInsets.all(2),
        ),
        icon: Icon(icon),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
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
                    fontSize: 15,
                    color:
                        effectiveEnabled
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                  ),
                ),
                if (subtitle case final text?) ...[
                  const SizedBox(height: 3),
                  Text(
                    text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12.5,
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
            constraints: const BoxConstraints(minWidth: 60),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: resolveAppBorderColor(
                  colorScheme,
                  containerColor: colorScheme.surfaceContainerLow,
                ),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              valueLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
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
  const BookshelfEmptyCard({
    super.key,
    required this.onImportLocal,
    required this.palette,
  });

  final VoidCallback onImportLocal;
  final ResolvedAdvancedThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: palette.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: resolveAppBorderSide(
          Theme.of(context).colorScheme,
          baseColor: palette.cardBorderColor,
          containerColor: palette.cardColor,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(
              Icons.import_contacts_outlined,
              color: palette.primaryColor,
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
                color: palette.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onImportLocal,
              style: FilledButton.styleFrom(
                backgroundColor: palette.primaryColor,
                foregroundColor: palette.buttonTextColor,
              ),
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
  const BookshelfFilterEmptyCard({
    super.key,
    required this.label,
    required this.palette,
    this.searchKeyword,
  });

  final String label;
  final ResolvedAdvancedThemePalette palette;
  final String? searchKeyword;

  @override
  Widget build(BuildContext context) {
    final normalizedKeyword = searchKeyword?.trim() ?? '';
    final hasSearchKeyword = normalizedKeyword.isNotEmpty;
    return Card(
      color: palette.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: resolveAppBorderSide(
          Theme.of(context).colorScheme,
          baseColor: palette.cardBorderColor,
          containerColor: palette.cardColor,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              hasSearchKeyword
                  ? Icons.search_off_rounded
                  : Icons.filter_alt_off_rounded,
              color: palette.primaryColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasSearchKeyword
                    ? '当前“$label”中没有匹配“$normalizedKeyword”的书籍'
                    : '当前“$label”分类暂无书籍',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondaryColor,
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
    required this.palette,
  });

  final String message;
  final VoidCallback onRetry;
  final ResolvedAdvancedThemePalette palette;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: palette.noticeSurfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: palette.noticeAccentColor.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '书架加载失败',
              style: TextStyle(
                color: palette.noticeAccentColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(message, style: TextStyle(color: palette.textPrimaryColor)),
            const SizedBox(height: 10),
            FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
