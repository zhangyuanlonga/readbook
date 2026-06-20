// UI-GOV-EXEMPT-FILE: list-performance
// reason: Phase 10 reviewed this toolbar; shrinkWrap is limited to a bounded filter chip section.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/layout/app_adaptive.dart';
import '../../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../../app/widgets/foundation/app_progress.dart';
import '../../application/private_book_source_service.dart';
import '../private_book_source_filter_presenter.dart';
import 'image_resource_collection_widgets.dart';

class PrivateBookSourceToolbar extends StatelessWidget {
  const PrivateBookSourceToolbar({
    super.key,
    required this.keyword,
    required this.selectedGroupId,
    required this.groupsAsync,
    required this.onKeywordChanged,
    required this.onKeywordCleared,
    required this.onGroupSelected,
    required this.onRetry,
  });

  final String keyword;
  final String? selectedGroupId;
  final AsyncValue<List<PrivateBookSourceGroup>> groupsAsync;
  final ValueChanged<String> onKeywordChanged;
  final VoidCallback onKeywordCleared;
  final ValueChanged<String?> onGroupSelected;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final groupButton = _PrivateSourceGroupMenuButton(
      selectedGroupId: selectedGroupId,
      groupsAsync: groupsAsync,
      onSelected: onGroupSelected,
      onRetry: onRetry,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: _PrivateSourceSearchField(
            keyword: keyword,
            onChanged: onKeywordChanged,
            onClear: onKeywordCleared,
          ),
        ),
        SizedBox(width: metrics.isCompactWindow ? 8 : 12),
        SizedBox(
          width: metrics.isCompactWindow ? 112 : 180,
          child: groupButton,
        ),
      ],
    );
  }
}

class _PrivateSourceSearchField extends StatefulWidget {
  const _PrivateSourceSearchField({
    required this.keyword,
    required this.onChanged,
    required this.onClear,
  });

  final String keyword;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_PrivateSourceSearchField> createState() =>
      _PrivateSourceSearchFieldState();
}

class _PrivateSourceSearchFieldState extends State<_PrivateSourceSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.keyword);
  }

  @override
  void didUpdateWidget(covariant _PrivateSourceSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text == widget.keyword) {
      return;
    }
    _controller.value = TextEditingValue(
      text: widget.keyword,
      selection: TextSelection.collapsed(offset: widget.keyword.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompactCollectionSearchField(
      controller: _controller,
      hintText: '搜索书源名称、分组、描述',
      query: widget.keyword,
      onChanged: widget.onChanged,
      onClear: widget.onClear,
    );
  }
}

class _PrivateSourceGroupMenuButton extends StatelessWidget {
  const _PrivateSourceGroupMenuButton({
    required this.selectedGroupId,
    required this.groupsAsync,
    required this.onSelected,
    required this.onRetry,
  });

  final String? selectedGroupId;
  final AsyncValue<List<PrivateBookSourceGroup>> groupsAsync;
  final ValueChanged<String?> onSelected;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return groupsAsync.when(
      data: (groups) {
        if (PrivateBookSourceGroupFilterPresenter.isSelectionStale(
          groups,
          selectedGroupId,
        )) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onSelected(null);
          });
        }
        final selectedLabel =
            PrivateBookSourceGroupFilterPresenter.selectedLabel(
              groups,
              selectedGroupId,
            );
        return _GroupMenuPill(
          label: selectedLabel,
          selected: selectedGroupId != null,
          onTap:
              () => unawaited(
                showPrivateBookSourceGroupPicker(
                  context: context,
                  groups: groups,
                  selectedGroupId: selectedGroupId,
                  onSelected: onSelected,
                ),
              ),
        );
      },
      loading:
          () => const _GroupMenuPill(
            label: '读取分组',
            selected: false,
            loading: true,
          ),
      error:
          (error, _) => _GroupMenuPill(
            label: '分组失败',
            selected: false,
            error: true,
            onTap: onRetry,
          ),
    );
  }
}

class _GroupMenuPill extends StatelessWidget {
  const _GroupMenuPill({
    required this.label,
    required this.selected,
    this.loading = false,
    this.error = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final bool loading;
  final bool error;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground =
        error
            ? colorScheme.error
            : selected
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant;
    return Material(
      color:
          selected
              ? colorScheme.primaryContainer.withValues(alpha: 0.34)
              : colorScheme.surfaceContainerLowest.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: loading ? null : onTap,
        child: Container(
          height: 40,
          constraints: const BoxConstraints(maxWidth: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  error
                      ? colorScheme.error.withValues(alpha: 0.5)
                      : colorScheme.outlineVariant.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (loading) ...<Widget>[
                const AppProgressIndicator(
                  size: 16,
                  strokeWidth: 2,
                  semanticLabel: '加载私人书源筛选',
                ),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ),
              if (!loading) ...<Widget>[
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: foreground,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showPrivateBookSourceGroupPicker({
  required BuildContext context,
  required List<PrivateBookSourceGroup> groups,
  required String? selectedGroupId,
  required ValueChanged<String?> onSelected,
}) async {
  final selected = await showAdaptiveActionSurface<String?>(
    context: context,
    maxWidth: 440,
    maxHeightFactor: 0.78,
    builder:
        (context) => PrivateBookSourceGroupPickerSurface(
          groups: groups,
          selectedGroupId: selectedGroupId,
        ),
  );
  if (selected != PrivateBookSourceGroupPickerSurface.noSelection) {
    onSelected(selected);
  }
}

class PrivateBookSourceGroupPickerSurface extends StatelessWidget {
  const PrivateBookSourceGroupPickerSurface({
    super.key,
    required this.groups,
    required this.selectedGroupId,
  });

  static const String noSelection = '__private_group_no_selection__';

  final List<PrivateBookSourceGroup> groups;
  final String? selectedGroupId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '选择分组',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: '关闭',
              onPressed:
                  () => Navigator.of(
                    context,
                  ).pop(PrivateBookSourceGroupPickerSurface.noSelection),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.56,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: groups.length + 1,
            separatorBuilder:
                (_, _) => Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.32),
                ),
            itemBuilder: (context, index) {
              final isAll = index == 0;
              final group = isAll ? null : groups[index - 1];
              final id = group?.id;
              final selected = selectedGroupId == id;
              return ListTile(
                leading: Icon(
                  isAll ? Icons.folder_copy_outlined : Icons.folder_outlined,
                  color:
                      selected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  isAll ? '全部分组' : group!.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                trailing:
                    selected
                        ? Icon(Icons.check_rounded, color: colorScheme.primary)
                        : null,
                onTap: () => Navigator.of(context).pop(id),
              );
            },
          ),
        ),
      ],
    );
  }
}
