import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/layout/app_layout.dart';
import '../../application/bookshelf_service.dart';

class BookshelfTaxonomyPickerSurface extends StatelessWidget {
  const BookshelfTaxonomyPickerSurface({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.createLabel,
    required this.onCancel,
    required this.onSave,
    required this.onCreate,
    this.createPanel,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String createLabel;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final VoidCallback onCreate;
  final Widget? createPanel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final desktopLike = AppLayout.isDesktopLike(
      context,
      platform: theme.platform,
    );
    final contentMaxHeight = math.max(
      desktopLike ? 120.0 : 180.0,
      MediaQuery.sizeOf(context).height * (desktopLike ? 0.38 : 0.52),
    );
    final padding =
        desktopLike
            ? const EdgeInsets.fromLTRB(18, 16, 18, 14)
            : const EdgeInsets.fromLTRB(16, 14, 16, 16);
    final compactButtonStyle = TextButton.styleFrom(
      minimumSize: const Size(0, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
    final saveButtonStyle = FilledButton.styleFrom(
      minimumSize: const Size(0, 34),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: colorScheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                style: compactButtonStyle,
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded, size: 17),
                label: Text(createLabel),
              ),
            ],
          ),
          if (createPanel != null) ...[
            const SizedBox(height: 12),
            createPanel!,
          ],
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.58),
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: contentMaxHeight),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: child,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                style: compactButtonStyle,
                onPressed: onCancel,
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: saveButtonStyle,
                onPressed: onSave,
                icon: const Icon(Icons.check_rounded, size: 17),
                label: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BookshelfInlineTaxonomyCreatePanel extends StatelessWidget {
  const BookshelfInlineTaxonomyCreatePanel({
    super.key,
    required this.kind,
    required this.nameController,
    required this.color,
    required this.errorText,
    required this.onColorChanged,
    required this.onNameChanged,
    required this.onSubmit,
    required this.onCancel,
    required this.formatColorLabel,
  });

  final BookshelfTaxonomyKind kind;
  final TextEditingController nameController;
  final Color color;
  final String? errorText;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final String Function(int colorValue) formatColorLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isTag = kind == BookshelfTaxonomyKind.tag;
    final swatches = taxonomyCreateColorSwatches(
      fallbackColor: color,
      fallbackName: isTag ? '新标签' : '新分类',
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: isTag ? '标签名称' : '分类名称',
                errorText: errorText,
                isDense: true,
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              textInputAction: TextInputAction.done,
              onChanged: onNameChanged,
              onSubmitted: (_) => onSubmit(),
            ),
            const SizedBox(height: 10),
            Text(
              '选择颜色',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final swatch in swatches)
                  BookshelfTaxonomyCreateColorButton(
                    color: swatch,
                    selected: swatch.toARGB32() == color.toARGB32(),
                    onTap: () => onColorChanged(swatch),
                    formatColorLabel: formatColorLabel,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onCancel, child: const Text('取消')),
                const SizedBox(width: 8),
                FilledButton(onPressed: onSubmit, child: const Text('添加')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BookshelfTagPicker extends StatelessWidget {
  const BookshelfTagPicker({
    super.key,
    required this.items,
    required this.selectedTags,
    required this.normalizeTags,
    required this.onChanged,
  });

  final List<BookshelfTaxonomyItem> items;
  final List<String> selectedTags;
  final List<String> Function(Iterable<String> values) normalizeTags;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return BookshelfTaxonomyOptionsWrap(
      children: [
        BookshelfTaxonomyOptionChip(
          avatar: const Icon(Icons.block_rounded),
          label: '未打标签',
          selected: selectedTags.isEmpty,
          onTap: () => onChanged(const <String>[]),
        ),
        for (final item in items)
          BookshelfTaxonomyOptionChip(
            avatar: BookshelfTaxonomyColorDot(item.colorValue),
            label: item.name,
            selected: selectedTags.contains(item.name),
            onTap: () {
              if (!selectedTags.contains(item.name)) {
                onChanged(normalizeTags([...selectedTags, item.name]));
                return;
              }
              onChanged(
                selectedTags
                    .where((tag) => tag != item.name)
                    .toList(growable: false),
              );
            },
          ),
      ],
    );
  }
}

class BookshelfCategoryPicker extends StatelessWidget {
  const BookshelfCategoryPicker({
    super.key,
    required this.items,
    required this.selectedCategory,
    required this.onChanged,
  });

  final List<BookshelfTaxonomyItem> items;
  final String? selectedCategory;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return BookshelfTaxonomyOptionsWrap(
      children: [
        BookshelfTaxonomyOptionChip(
          avatar: const Icon(Icons.block_rounded),
          label: '未分类',
          selected: selectedCategory == null || selectedCategory!.isEmpty,
          onTap: () => onChanged(null),
        ),
        for (final item in items)
          BookshelfTaxonomyOptionChip(
            avatar: BookshelfTaxonomyColorDot(item.colorValue),
            label: item.name,
            selected: selectedCategory == item.name,
            onTap:
                () =>
                    onChanged(selectedCategory == item.name ? null : item.name),
          ),
      ],
    );
  }
}

class BookshelfTaxonomyOptionsWrap extends StatelessWidget {
  const BookshelfTaxonomyOptionsWrap({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(spacing: 8, runSpacing: 8, children: children),
    );
  }
}

class BookshelfTaxonomyOptionChip extends StatelessWidget {
  const BookshelfTaxonomyOptionChip({
    super.key,
    required this.avatar,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Widget avatar;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color:
          selected
              ? colorScheme.primaryContainer.withValues(alpha: 0.72)
              : colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color:
              selected
                  ? colorScheme.primary.withValues(alpha: 0.38)
                  : colorScheme.outlineVariant.withValues(alpha: 0.72),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTheme.merge(
                data: IconThemeData(
                  size: 15,
                  color:
                      selected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                ),
                child: avatar,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color:
                        selected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookshelfTaxonomyCreateColorButton extends StatelessWidget {
  const BookshelfTaxonomyCreateColorButton({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.formatColorLabel,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String Function(int colorValue) formatColorLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black;
    return Tooltip(
      message: formatColorLabel(color.toARGB32()),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? colorScheme.onSurface : colorScheme.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child:
              selected
                  ? Icon(Icons.check_rounded, size: 16, color: foregroundColor)
                  : null,
        ),
      ),
    );
  }
}

class BookshelfTaxonomyColorDot extends StatelessWidget {
  const BookshelfTaxonomyColorDot(this.colorValue, {super.key});

  final int colorValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Color(colorValue),
        shape: BoxShape.circle,
      ),
    );
  }
}

List<Color> taxonomyCreateColorSwatches({
  required Color fallbackColor,
  required String fallbackName,
}) {
  final colors = <Color>[
    fallbackColor,
    Color(BookshelfTaxonomyItem.defaultColorForName(fallbackName)),
    const Color(0xFF2563EB),
    const Color(0xFF059669),
    const Color(0xFFDC2626),
    const Color(0xFF7C3AED),
    const Color(0xFFEA580C),
    const Color(0xFF0891B2),
  ];
  final seen = <int>{};
  return <Color>[
    for (final color in colors)
      if (seen.add(color.toARGB32())) color,
  ];
}
