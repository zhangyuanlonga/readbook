import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../app/widgets/adaptive_list_tile.dart';
import '../../../app/widgets/adaptive_overflow_toolbar.dart';
import '../../../app/widgets/app_empty_state_card.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../core/network/api_client.dart';
import '../application/advanced_theme_provider.dart';
import '../application/private_book_source_provider.dart';
import '../application/private_book_source_service.dart';
import 'widgets/image_resource_collection_widgets.dart';
import 'widgets/mine_route_top_bar.dart';

final _privateBookSourceSearchKeywordProvider =
    StateProvider.autoDispose<String>((ref) {
      return '';
    });

enum _PrivateSourceAction { test, submit, edit, delete }

class PrivateBookSourcesPage extends ConsumerWidget {
  const PrivateBookSourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGroupId = ref.watch(selectedPrivateBookSourceGroupProvider);
    final listAsync = ref.watch(privateBookSourcesProvider(selectedGroupId));
    final groupsAsync = ref.watch(privateBookSourceGroupsProvider);
    final quotaAsync = ref.watch(sourceQuotaProvider);
    final searchKeyword = ref.watch(_privateBookSourceSearchKeywordProvider);
    final activeAdvancedTheme =
        ref.watch(activeAdvancedThemeProvider).valueOrNull;
    final backdrop = resolveAdvancedThemeBackdrop(
      Theme.of(context).colorScheme,
      activeAdvancedTheme,
    );
    final metrics = AppAdaptiveMetrics.of(context);
    final horizontal = metrics.pagePadding;
    final routeTopBar = _buildRouteTopBar(context, ref);
    final topInset =
        MediaQuery.paddingOf(context).top + routeTopBar.preferredSize.height;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          context.go('/mine');
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: routeTopBar,
        body: DecoratedBox(
          decoration: buildAdvancedThemeBackdropDecoration(backdrop),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppLayout.pageContentMaxWidth(
                  context,
                  maxWidth: AppLayout.settingsContentMaxWidth,
                ),
              ),
              child: RefreshIndicator(
                onRefresh: () async => _refresh(ref),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    topInset + metrics.contentGap,
                    horizontal,
                    bottomInset + metrics.sectionGap,
                  ),
                  children: <Widget>[
                    _PrivateSourceToolbar(
                      selectedGroupId: selectedGroupId,
                      groupsAsync: groupsAsync,
                      onGroupSelected: (groupId) {
                        ref
                            .read(
                              selectedPrivateBookSourceGroupProvider.notifier,
                            )
                            .state = groupId;
                      },
                      onRetry:
                          () => ref.invalidate(privateBookSourceGroupsProvider),
                    ),
                    SizedBox(height: metrics.contentGap),
                    quotaAsync.when(
                      data: (quota) => _QuotaCard(quota: quota),
                      loading: () => const _LoadingCard(message: '正在读取额度'),
                      error:
                          (error, _) => _ErrorCard(
                            title: '额度读取失败',
                            message: _messageOf(error),
                            onRetry: () => ref.invalidate(sourceQuotaProvider),
                          ),
                    ),
                    SizedBox(height: metrics.contentGap),
                    listAsync.when(
                      data: (result) {
                        if (result.items.isEmpty) {
                          return _EmptySourcesCard(
                            onCreate: () => unawaited(_openForm(context, ref)),
                          );
                        }
                        final visibleItems = _filterPrivateSources(
                          result.items,
                          searchKeyword,
                        );
                        if (visibleItems.isEmpty) {
                          return _FilterEmptySourcesCard(
                            keyword: searchKeyword,
                            onClear:
                                () =>
                                    ref
                                        .read(
                                          _privateBookSourceSearchKeywordProvider
                                              .notifier,
                                        )
                                        .state = '',
                          );
                        }
                        return Column(
                          children: <Widget>[
                            for (final item in visibleItems) ...<Widget>[
                              _PrivateSourceTile(
                                item: item,
                                onEdit:
                                    () => unawaited(
                                      _openForm(context, ref, item: item),
                                    ),
                                onDelete:
                                    () => unawaited(
                                      _deleteSource(context, ref, item),
                                    ),
                                onTest:
                                    () => unawaited(
                                      _testSource(context, ref, item),
                                    ),
                                onSubmit:
                                    () => unawaited(
                                      _submitSource(context, ref, item),
                                    ),
                              ),
                              SizedBox(height: metrics.contentGap),
                            ],
                          ],
                        );
                      },
                      loading: () => const _LoadingCard(message: '正在加载书源'),
                      error:
                          (error, _) => _ErrorCard(
                            title: '书源加载失败',
                            message: _messageOf(error),
                            onRetry:
                                () =>
                                    ref.invalidate(privateBookSourcesProvider),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static PreferredSizeWidget _buildRouteTopBar(
    BuildContext context,
    WidgetRef ref,
  ) {
    return buildMineRouteTopBar(
      context: context,
      title: '我的书源',
      subtitle: '私人书源与共享审核',
      actions: <AdaptiveOverflowToolbarItem>[
        AdaptiveOverflowToolbarItem(
          icon: Icons.folder_copy_outlined,
          label: '分组',
          priority: 9,
          onPressed: () => unawaited(_openGroupManager(context, ref)),
        ),
        AdaptiveOverflowToolbarItem(
          icon: Icons.add_rounded,
          label: '新增书源',
          priority: 10,
          onPressed: () => unawaited(_openForm(context, ref)),
        ),
      ],
      mobileActions: <Widget>[
        IconButton(
          tooltip: '分组',
          onPressed: () => unawaited(_openGroupManager(context, ref)),
          icon: const Icon(Icons.folder_copy_outlined),
        ),
        IconButton(
          tooltip: '新增书源',
          onPressed: () => unawaited(_openForm(context, ref)),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }

  static Future<void> _openGroupManager(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final changed = await showAdaptiveActionSurface<bool>(
      context: context,
      maxWidth: 560,
      maxHeightFactor: 0.86,
      padding: EdgeInsets.zero,
      builder: (context) => const _PrivateSourceGroupManagerSheet(),
    );
    if (changed == true) {
      _refresh(ref);
    }
  }

  static void _refresh(WidgetRef ref) {
    ref.invalidate(privateBookSourcesProvider);
    ref.invalidate(privateBookSourceGroupsProvider);
    ref.invalidate(sourceQuotaProvider);
  }

  static Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    PrivateBookSourceItem? item,
  }) async {
    var formItem = item;
    if (item != null && (item.sourceJson.isEmpty && item.sourceCode.isEmpty)) {
      formItem = await _loadSourceDetailForEdit(context, ref, item);
      if (formItem == null || !context.mounted) {
        return;
      }
    }
    final saved = await showAdaptiveActionSurface<PrivateBookSourceItem?>(
      context: context,
      maxWidth: 680,
      maxHeightFactor: 0.9,
      padding: EdgeInsets.zero,
      builder: (context) => _PrivateSourceForm(item: formItem),
    );
    if (saved != null) {
      ref.read(_privateBookSourceSearchKeywordProvider.notifier).state = '';
      ref.read(selectedPrivateBookSourceGroupProvider.notifier).state = null;
      _refresh(ref);
    }
  }

  static Future<PrivateBookSourceItem?> _loadSourceDetailForEdit(
    BuildContext context,
    WidgetRef ref,
    PrivateBookSourceItem item,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final loading = messenger.showSnackBar(
      const SnackBar(content: Text('正在读取书源详情')),
    );
    try {
      final detail = await ref
          .read(privateBookSourceServiceProvider)
          .get(item.id);
      loading.close();
      return detail;
    } catch (error) {
      loading.close();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('书源详情读取失败：${_messageOf(error)}')),
        );
      }
      return null;
    }
  }

  static Future<void> _deleteSource(
    BuildContext context,
    WidgetRef ref,
    PrivateBookSourceItem item,
  ) async {
    final confirmed = await showAdaptiveActionSurface<bool>(
      context: context,
      maxWidth: 420,
      builder:
          (context) => _ConfirmActionSurface(
            icon: Icons.delete_outline,
            title: '删除书源',
            message: '确认删除“${item.name}”？删除后不可恢复。',
            confirmLabel: '删除',
            destructive: true,
          ),
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await _runVoidAction(
      context,
      ref,
      () => ref.read(privateBookSourceServiceProvider).delete(item.id),
      '书源已删除',
    );
  }

  static Future<void> _submitSource(
    BuildContext context,
    WidgetRef ref,
    PrivateBookSourceItem item,
  ) async {
    final noteController = TextEditingController(text: item.description);
    final note = await showAdaptiveActionSurface<String>(
      context: context,
      maxWidth: 520,
      builder:
          (context) => _SubmitSourceReviewSurface(controller: noteController),
    );
    noteController.dispose();
    if (note == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await _runVoidAction(
      context,
      ref,
      () => ref.read(privateBookSourceServiceProvider).submit(item.id, note),
      '已提交共享审核',
    );
  }

  static Future<void> _testSource(
    BuildContext context,
    WidgetRef ref,
    PrivateBookSourceItem item,
  ) async {
    final config = await showAdaptiveActionSurface<_SourceTestConfig>(
      context: context,
      maxWidth: 560,
      maxHeightFactor: 0.86,
      padding: EdgeInsets.zero,
      builder: (context) => _SourceTestConfigSheet(item: item),
    );
    if (config == null || !context.mounted) {
      return;
    }
    try {
      final result = await ref
          .read(privateBookSourceServiceProvider)
          .test(
            item.id,
            keyword: config.keyword,
            timeoutMs: config.timeoutMs,
            checkItems: config.checkItems,
          );
      if (!context.mounted) {
        return;
      }
      _refresh(ref);
      final report = result.report;
      if (report != null) {
        await showAdaptiveActionSurface<void>(
          context: context,
          maxWidth: 680,
          maxHeightFactor: 0.9,
          padding: EdgeInsets.zero,
          builder: (context) => _SourceCheckReportSheet(report: report),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('书源检测已记录：${_testLabel(result.item.lastTestStatus)}'),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_messageOf(error))));
    }
  }

  static Future<void> _runVoidAction(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String success,
  ) async {
    try {
      await action();
      if (!context.mounted) {
        return;
      }
      _refresh(ref);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_messageOf(error))));
    }
  }
}

class _ConfirmActionSurface extends StatelessWidget {
  const _ConfirmActionSurface({
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = destructive ? colorScheme.error : colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style:
                  destructive
                      ? FilledButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                      )
                      : null,
              child: Text(confirmLabel),
            ),
          ],
        ),
      ],
    );
  }
}

class _RenameGroupSurface extends StatelessWidget {
  const _RenameGroupSurface({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '重命名分组',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '分组名称'),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed:
                  () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SubmitSourceReviewSurface extends StatelessWidget {
  const _SubmitSourceReviewSurface({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          '提交共享审核',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: '提交说明',
            hintText: '说明这个书源适合共享的原因',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed:
                  () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('提交'),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuotaCard extends StatelessWidget {
  const _QuotaCard({required this.quota});

  final SourceQuotaSnapshot quota;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: _QuotaPill(
              label:
                  '总书源 ${quota.privateSourceCount}/${_limitText(quota.maxPrivateSources)}',
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: _QuotaPill(
              label:
                  '检测 ${quota.dailyTestUsed}/${_limitText(quota.dailyTestLimit)}',
              foregroundColor: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuotaPill extends StatelessWidget {
  const _QuotaPill({required this.label, this.foregroundColor});

  final String label;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = foregroundColor ?? colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.52),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivateSourceToolbar extends StatelessWidget {
  const _PrivateSourceToolbar({
    required this.selectedGroupId,
    required this.groupsAsync,
    required this.onGroupSelected,
    required this.onRetry,
  });

  final String? selectedGroupId;
  final AsyncValue<List<PrivateBookSourceGroup>> groupsAsync;
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
        const Expanded(child: _PrivateSourceSearchField()),
        SizedBox(width: metrics.isCompactWindow ? 8 : 12),
        SizedBox(
          width: metrics.isCompactWindow ? 112 : 180,
          child: groupButton,
        ),
      ],
    );
  }
}

class _PrivateSourceSearchField extends ConsumerStatefulWidget {
  const _PrivateSourceSearchField();

  @override
  ConsumerState<_PrivateSourceSearchField> createState() =>
      _PrivateSourceSearchFieldState();
}

class _PrivateSourceSearchFieldState
    extends ConsumerState<_PrivateSourceSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(_privateBookSourceSearchKeywordProvider),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyword = ref.watch(_privateBookSourceSearchKeywordProvider);
    if (_controller.text != keyword) {
      _controller.value = TextEditingValue(
        text: keyword,
        selection: TextSelection.collapsed(offset: keyword.length),
      );
    }
    return CompactCollectionSearchField(
      controller: _controller,
      hintText: '搜索书源名称、分组、描述',
      query: keyword,
      onChanged:
          (value) =>
              ref.read(_privateBookSourceSearchKeywordProvider.notifier).state =
                  value,
      onClear:
          () =>
              ref.read(_privateBookSourceSearchKeywordProvider.notifier).state =
                  '',
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
        if (selectedGroupId != null &&
            !groups.any((group) => group.id == selectedGroupId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onSelected(null);
          });
        }
        final selectedLabel =
            selectedGroupId == null
                ? '全部分组'
                : groups
                        .where((group) => group.id == selectedGroupId)
                        .map((group) => group.displayName)
                        .firstOrNull ??
                    '全部分组';
        return _GroupMenuPill(
          label: selectedLabel,
          selected: selectedGroupId != null,
          onTap:
              () => unawaited(
                _showPrivateSourceGroupPicker(
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
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
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

Future<void> _showPrivateSourceGroupPicker({
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
        (context) => _PrivateSourceGroupPickerSurface(
          groups: groups,
          selectedGroupId: selectedGroupId,
        ),
  );
  if (selected != _PrivateSourceGroupPickerSurface.noSelection) {
    onSelected(selected);
  }
}

class _PrivateSourceGroupPickerSurface extends StatelessWidget {
  const _PrivateSourceGroupPickerSurface({
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
              onPressed: () => Navigator.of(context).pop(noSelection),
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

class _PrivateSourceGroupManagerSheet extends ConsumerStatefulWidget {
  const _PrivateSourceGroupManagerSheet();

  @override
  ConsumerState<_PrivateSourceGroupManagerSheet> createState() =>
      _PrivateSourceGroupManagerSheetState();
}

class _PrivateSourceGroupManagerSheetState
    extends ConsumerState<_PrivateSourceGroupManagerSheet> {
  late final TextEditingController _nameController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final groupsAsync = ref.watch(privateBookSourceGroupsProvider);
    final metrics = AppAdaptiveMetrics.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.pagePadding,
        metrics.contentGap,
        metrics.pagePadding,
        bottomInset + metrics.sectionGap,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLowest.withValues(
                  alpha: 0.94,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.28),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        enabled: !_saving,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(height: 1.15),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: '新增分组，例如：常用、漫画、备用',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 9,
                          ),
                        ),
                        onSubmitted: (_) => unawaited(_createGroup()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed:
                          _saving ? null : () => unawaited(_createGroup()),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(_saving ? '保存中' : '新增'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: groupsAsync.when(
                data: (groups) {
                  if (groups.isEmpty) {
                    return const AppEmptyStateCard(
                      icon: Icons.folder_off_outlined,
                      title: '暂无私人分组',
                      description: '新增分组后，可以在书源编辑里选择或填写对应分组名。',
                      compact: true,
                    );
                  }
                  return ListView.separated(
                    itemCount: groups.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      final isDefault = _isDefaultGroup(group);
                      return AdaptiveListTile(
                        key: ValueKey(group.id),
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(
                          group.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(isDefault ? '默认兜底分组' : '私人书源分组'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton(
                              tooltip: '重命名',
                              onPressed: () => unawaited(_renameGroup(group)),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: '删除',
                              onPressed:
                                  isDefault
                                      ? null
                                      : () => unawaited(_deleteGroup(group)),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                loading:
                    () => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                error:
                    (error, _) => AppEmptyStateCard(
                      icon: Icons.error_outline_rounded,
                      title: '分组读取失败',
                      description: _messageOf(error),
                      actionLabel: '重试',
                      onAction:
                          () => ref.invalidate(privateBookSourceGroupsProvider),
                      compact: true,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('请填写分组名称');
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      await ref.read(privateBookSourceServiceProvider).createGroup(name);
      _nameController.clear();
      _markChanged();
      _showMessage('分组已新增');
    } catch (error) {
      _showMessage(_messageOf(error));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _renameGroup(PrivateBookSourceGroup group) async {
    final controller = TextEditingController(text: group.displayName);
    final name = await showAdaptiveActionSurface<String>(
      context: context,
      maxWidth: 440,
      builder: (context) => _RenameGroupSurface(controller: controller),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == group.displayName) {
      return;
    }
    try {
      final updated = await ref
          .read(privateBookSourceServiceProvider)
          .updateGroup(group.id, name);
      ref.read(selectedPrivateBookSourceGroupProvider.notifier).state =
          updated.id;
      _markChanged();
      _showMessage('分组已重命名');
    } catch (error) {
      _showMessage(_messageOf(error));
    }
  }

  Future<void> _deleteGroup(PrivateBookSourceGroup group) async {
    final confirmed = await showAdaptiveActionSurface<bool>(
      context: context,
      maxWidth: 440,
      builder:
          (context) => _ConfirmActionSurface(
            icon: Icons.folder_delete_outlined,
            title: '删除分组',
            message: '确认删除“${group.displayName}”？分组内书源会移到未分组。',
            confirmLabel: '删除',
            destructive: true,
          ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(privateBookSourceServiceProvider).deleteGroup(group.id);
      if (ref.read(selectedPrivateBookSourceGroupProvider) == group.id) {
        ref.read(selectedPrivateBookSourceGroupProvider.notifier).state = null;
      }
      _markChanged();
      _showMessage('分组已删除');
    } catch (error) {
      _showMessage(_messageOf(error));
    }
  }

  void _markChanged() {
    ref.invalidate(privateBookSourceGroupsProvider);
    ref.invalidate(privateBookSourcesProvider);
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PrivateSourceTile extends StatelessWidget {
  const _PrivateSourceTile({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onTest,
    required this.onSubmit,
  });

  final PrivateBookSourceItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTest;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final testText =
        item.lastTestStatus.isEmpty && item.lastTestMessage.isEmpty
            ? '未检测'
            : '${_testLabel(item.lastTestStatus)}${item.lastTestMessage.isEmpty ? '' : ' · ${item.lastTestMessage}'}';
    final infoLine = [
      _typeLabel(item.supportedTypes),
      _groupLabel(item.groupName),
      _reviewLabel(item.reviewStatus),
      '检测 $testText',
      if (item.description.isNotEmpty) item.description,
    ].join(' · ');
    return Material(
      color: colorScheme.surfaceContainerLow.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: item.visibility == 'shared' ? null : onEdit,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.32),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      infoLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              _PrivateSourceMoreButton(
                item: item,
                onTest: onTest,
                onSubmit: onSubmit,
                onEdit: onEdit,
                onDelete: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivateSourceMoreButton extends StatelessWidget {
  const _PrivateSourceMoreButton({
    required this.item,
    required this.onTest,
    required this.onSubmit,
    required this.onEdit,
    required this.onDelete,
  });

  final PrivateBookSourceItem item;
  final VoidCallback onTest;
  final VoidCallback onSubmit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 36,
      height: 36,
      child: PopupMenuButton<_PrivateSourceAction>(
        tooltip: '更多',
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_horiz_rounded),
        onSelected: (action) {
          switch (action) {
            case _PrivateSourceAction.test:
              onTest();
            case _PrivateSourceAction.submit:
              onSubmit();
            case _PrivateSourceAction.edit:
              onEdit();
            case _PrivateSourceAction.delete:
              onDelete();
          }
        },
        itemBuilder:
            (context) => <PopupMenuEntry<_PrivateSourceAction>>[
              const PopupMenuItem(
                value: _PrivateSourceAction.test,
                child: _PrivateSourceMenuItem(
                  icon: Icons.science_outlined,
                  label: '检测',
                ),
              ),
              PopupMenuItem(
                value: _PrivateSourceAction.submit,
                enabled: item.visibility == 'private',
                child: const _PrivateSourceMenuItem(
                  icon: Icons.ios_share_outlined,
                  label: '提交共享',
                ),
              ),
              PopupMenuItem(
                value: _PrivateSourceAction.edit,
                enabled: item.visibility != 'shared',
                child: const _PrivateSourceMenuItem(
                  icon: Icons.edit_outlined,
                  label: '编辑',
                ),
              ),
              PopupMenuItem(
                value: _PrivateSourceAction.delete,
                child: _PrivateSourceMenuItem(
                  icon: Icons.delete_outline,
                  label: '删除',
                  color: colorScheme.error,
                ),
              ),
            ],
      ),
    );
  }
}

class _PrivateSourceMenuItem extends StatelessWidget {
  const _PrivateSourceMenuItem({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? Theme.of(context).colorScheme.onSurface;
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: foreground),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: foreground)),
      ],
    );
  }
}

enum _SourceTestMode {
  main('主链路', <String>['domain', 'search', 'info', 'toc', 'content']),
  discovery('发现', <String>['domain', 'discovery', 'info', 'toc', 'content']),
  custom('自定义', <String>['domain', 'search']);

  const _SourceTestMode(this.label, this.items);

  final String label;
  final List<String> items;
}

class _SourceTestConfig {
  const _SourceTestConfig({
    required this.keyword,
    required this.timeoutMs,
    required this.checkItems,
  });

  final String keyword;
  final int timeoutMs;
  final List<String> checkItems;
}

class _SourceTestConfigSheet extends StatefulWidget {
  const _SourceTestConfigSheet({required this.item});

  final PrivateBookSourceItem item;

  @override
  State<_SourceTestConfigSheet> createState() => _SourceTestConfigSheetState();
}

class _SourceTestConfigSheetState extends State<_SourceTestConfigSheet> {
  final TextEditingController _keywordController = TextEditingController();
  _SourceTestMode _mode = _SourceTestMode.main;
  int _timeoutMs = 30000;
  late Set<String> _checkItems = _SourceTestMode.main.items.toSet();

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = AppAdaptiveMetrics.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.pagePadding,
        metrics.contentGap,
        metrics.pagePadding,
        bottomInset + metrics.sectionGap,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('检测书源', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                widget.item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              SegmentedButton<_SourceTestMode>(
                segments: const <ButtonSegment<_SourceTestMode>>[
                  ButtonSegment(
                    value: _SourceTestMode.main,
                    label: Text('主链路'),
                    icon: Icon(Icons.route_outlined),
                  ),
                  ButtonSegment(
                    value: _SourceTestMode.discovery,
                    label: Text('发现'),
                    icon: Icon(Icons.explore_outlined),
                  ),
                  ButtonSegment(
                    value: _SourceTestMode.custom,
                    label: Text('自定义'),
                    icon: Icon(Icons.tune_rounded),
                  ),
                ],
                selected: <_SourceTestMode>{_mode},
                onSelectionChanged: (values) {
                  final value = values.first;
                  setState(() {
                    _mode = value;
                    if (value != _SourceTestMode.custom) {
                      _checkItems = value.items.toSet();
                    }
                  });
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _keywordController,
                decoration: const InputDecoration(
                  labelText: '检测关键字',
                  hintText: '为空时使用书源内置关键字',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _timeoutMs,
                decoration: const InputDecoration(
                  labelText: '超时',
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
                items: const <DropdownMenuItem<int>>[
                  DropdownMenuItem(value: 12000, child: Text('12 秒')),
                  DropdownMenuItem(value: 30000, child: Text('30 秒')),
                  DropdownMenuItem(value: 60000, child: Text('60 秒')),
                  DropdownMenuItem(value: 90000, child: Text('90 秒')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _timeoutMs = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              Text('检测过程', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final item in const <String>[
                    'domain',
                    'search',
                    'discovery',
                    'info',
                    'toc',
                    'content',
                  ])
                    FilterChip(
                      label: Text(_checkItemLabel(item)),
                      selected: _checkItems.contains(item),
                      onSelected:
                          _mode == _SourceTestMode.custom
                              ? (selected) {
                                setState(() {
                                  if (selected) {
                                    _checkItems.add(item);
                                  } else {
                                    _checkItems.remove(item);
                                  }
                                });
                              }
                              : null,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed:
                        _checkItems.isEmpty
                            ? null
                            : () => Navigator.of(context).pop(
                              _SourceTestConfig(
                                keyword: _keywordController.text.trim(),
                                timeoutMs: _timeoutMs,
                                checkItems: _orderedCheckItems(_checkItems),
                              ),
                            ),
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('开始检测'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceCheckReportSheet extends StatelessWidget {
  const _SourceCheckReportSheet({required this.report});

  final SourceCheckReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    final summary = report.summary;
    final title = summary.valid ? '检测通过' : '检测失败';
    final summaryMessage = summary.message.trim();
    final showSummaryMessage =
        summaryMessage.isNotEmpty && summaryMessage != title;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.pagePadding,
        metrics.contentGap,
        metrics.pagePadding,
        metrics.sectionGap,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  summary.valid
                      ? Icons.check_circle_rounded
                      : Icons.error_rounded,
                  color:
                      summary.valid ? colorScheme.primary : colorScheme.error,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              [
                if (summary.sourceName.isNotEmpty) summary.sourceName,
                if (summary.mode.isNotEmpty) summary.mode,
                if (summary.keyword.isNotEmpty) '关键字 ${summary.keyword}',
                if (summary.elapsedMs > 0) _formatDurationMs(summary.elapsedMs),
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (showSummaryMessage) ...<Widget>[
              const SizedBox(height: 10),
              Text(summaryMessage, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 14),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: report.logs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _SourceCheckLogRow(entry: report.logs[index]);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed:
                      report.copyText.trim().isEmpty
                          ? null
                          : () {
                            Clipboard.setData(
                              ClipboardData(text: report.copyText),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('检测日志已复制')),
                            );
                          },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('复制日志'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceCheckLogRow extends StatelessWidget {
  const _SourceCheckLogRow({required this.entry});

  final SourceCheckLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = switch (entry.level) {
      'success' => colorScheme.primary,
      'error' => colorScheme.error,
      'muted' => colorScheme.onSurfaceVariant,
      _ => colorScheme.onSurface,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          entry.direction == 'in' ? '<-' : '->',
          style: theme.textTheme.bodySmall?.copyWith(color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                entry.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (entry.details.isNotEmpty)
                _SourceCheckLogDetails(details: entry.details),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '[${_formatLogTime(entry.timeMs)}]',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SourceCheckLogDetails extends StatelessWidget {
  const _SourceCheckLogDetails({required this.details});

  final List<String> details;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    final pendingCompact = <_SourceCheckDetail>[];
    void flushCompact() {
      if (pendingCompact.isEmpty) {
        return;
      }
      children.add(_SourceCheckCompactDetails(items: List.of(pendingCompact)));
      pendingCompact.clear();
    }

    for (final raw in details) {
      final detail = _SourceCheckDetail.parse(raw);
      if (detail.isCompact) {
        pendingCompact.add(detail);
      } else {
        flushCompact();
        children.add(_SourceCheckLongDetail(detail: detail));
      }
    }
    flushCompact();

    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children
            .expand((child) => <Widget>[child, const SizedBox(height: 5)])
            .take(children.length * 2 - 1)
            .toList(growable: false),
      ),
    );
  }
}

class _SourceCheckCompactDetails extends StatelessWidget {
  const _SourceCheckCompactDetails({required this.items});

  final List<_SourceCheckDetail> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = constraints.maxWidth >= 280 ? 14.0 : 8.0;
        final itemWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: 4,
          children: <Widget>[
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _SourceCheckInfoText(item: item, maxLines: 1),
              ),
          ],
        );
      },
    );
  }
}

class _SourceCheckLongDetail extends StatelessWidget {
  const _SourceCheckLongDetail({required this.detail});

  final _SourceCheckDetail detail;

  @override
  Widget build(BuildContext context) {
    return _SourceCheckInfoText(item: detail, maxLines: 4);
  }
}

class _SourceCheckInfoText extends StatelessWidget {
  const _SourceCheckInfoText({required this.item, required this.maxLines});

  final _SourceCheckDetail item;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    if (item.label.isEmpty) {
      return Text(
        item.value,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: labelStyle,
      );
    }
    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: labelStyle,
        children: <InlineSpan>[
          TextSpan(text: '${item.label}：'),
          TextSpan(text: item.value, style: valueStyle),
        ],
      ),
    );
  }
}

class _SourceCheckDetail {
  const _SourceCheckDetail({
    required this.label,
    required this.value,
    required this.isCompact,
  });

  final String label;
  final String value;
  final bool isCompact;

  factory _SourceCheckDetail.parse(String raw) {
    final text = raw.trim();
    final separator = _firstDetailSeparator(text);
    if (separator <= 0) {
      return _SourceCheckDetail(
        label: '',
        value: text,
        isCompact: _isCompactDetail('', text),
      );
    }
    final label = text.substring(0, separator).trim();
    final value = text.substring(separator + 1).trim();
    return _SourceCheckDetail(
      label: label,
      value: value,
      isCompact: _isCompactDetail(label, value),
    );
  }
}

int _firstDetailSeparator(String value) {
  final chinese = value.indexOf('：');
  final ascii = value.indexOf(':');
  if (chinese < 0) {
    return ascii;
  }
  if (ascii < 0) {
    return chinese;
  }
  return chinese < ascii ? chinese : ascii;
}

bool _isCompactDetail(String label, String value) {
  final lowerValue = value.toLowerCase();
  final lowerLabel = label.toLowerCase();
  if (value.contains('\n') ||
      lowerValue.contains('http://') ||
      lowerValue.contains('https://') ||
      lowerValue.startsWith('{') ||
      lowerValue.startsWith('[') ||
      lowerLabel.contains('url') ||
      label.contains('地址') ||
      label.contains('请求体') ||
      lowerLabel == 'body') {
    return false;
  }
  return value.runes.length <= 18;
}

class _PrivateSourceForm extends ConsumerStatefulWidget {
  const _PrivateSourceForm({this.item});

  final PrivateBookSourceItem? item;

  @override
  ConsumerState<_PrivateSourceForm> createState() => _PrivateSourceFormState();
}

class _PrivateSourceFormState extends ConsumerState<_PrivateSourceForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _groupController;
  late final TextEditingController _sourceController;
  String _type = 'novel';
  bool _saving = false;
  bool _groupEdited = false;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    _groupController = TextEditingController(text: item?.groupName ?? '');
    _sourceController = TextEditingController(
      text:
          item?.sourceJson.isNotEmpty == true
              ? item!.sourceJson
              : item?.sourceCode ?? '',
    );
    _sourceController.addListener(_fillGroupFromSourceJson);
    _type =
        item?.supportedTypes.isNotEmpty == true
            ? item!.supportedTypes.first
            : 'novel';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _groupController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final groupsAsync = ref.watch(privateBookSourceGroupsProvider);
    final metrics = AppAdaptiveMetrics.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.pagePadding,
        metrics.contentGap,
        metrics.pagePadding,
        bottomInset + metrics.sectionGap,
      ),
      child: Form(
        key: _formKey,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _isEditing ? '编辑书源' : '新增书源',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: '名称'),
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
                              ? '请填写名称'
                              : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: '类型'),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'novel', child: Text('小说')),
                    DropdownMenuItem(value: 'comic', child: Text('漫画')),
                    DropdownMenuItem(value: 'audio', child: Text('音频')),
                    DropdownMenuItem(value: 'video', child: Text('视频')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _type = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                _PrivateGroupAutocompleteField(
                  controller: _groupController,
                  groupsAsync: groupsAsync,
                  onChanged: () {
                    _groupEdited = true;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: '描述'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sourceController,
                  minLines: 8,
                  maxLines: 14,
                  decoration: const InputDecoration(
                    labelText: 'Legado JSON',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    final raw = value?.trim() ?? '';
                    if (raw.isEmpty) {
                      return '请粘贴书源 JSON';
                    }
                    if (!PrivateBookSourceInput.isValidJson(raw)) {
                      return 'JSON 格式不正确';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      onPressed:
                          _saving
                              ? null
                              : () => Navigator.of(context).pop(null),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? '保存中' : '保存'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
    });
    final input = PrivateBookSourceInput(
      name: _nameController.text.trim(),
      supportedTypes: <String>[_type],
      sourceCode: _sourceController.text.trim(),
      description: _descriptionController.text.trim(),
      groupName: _groupController.text.trim(),
    );
    try {
      late final PrivateBookSourceItem saved;
      if (_isEditing) {
        saved = await ref
            .read(privateBookSourceServiceProvider)
            .update(widget.item!.id, input);
      } else {
        saved = await ref.read(privateBookSourceServiceProvider).create(input);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_messageOf(error))));
    }
  }

  void _fillGroupFromSourceJson() {
    if (_isEditing || _groupEdited || _groupController.text.trim().isNotEmpty) {
      return;
    }
    final groupName = PrivateBookSourceInput.defaultGroupNameFromJson(
      _sourceController.text.trim(),
    );
    if (groupName.isEmpty) {
      return;
    }
    _groupController.text = groupName;
  }
}

class _PrivateGroupAutocompleteField extends StatefulWidget {
  const _PrivateGroupAutocompleteField({
    required this.controller,
    required this.groupsAsync,
    required this.onChanged,
  });

  final TextEditingController controller;
  final AsyncValue<List<PrivateBookSourceGroup>> groupsAsync;
  final VoidCallback onChanged;

  @override
  State<_PrivateGroupAutocompleteField> createState() =>
      _PrivateGroupAutocompleteFieldState();
}

class _PrivateGroupAutocompleteFieldState
    extends State<_PrivateGroupAutocompleteField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups =
        widget.groupsAsync.valueOrNull ?? const <PrivateBookSourceGroup>[];
    final groupNames = _uniqueGroupNames(groups);
    final loading = widget.groupsAsync.isLoading && groups.isEmpty;
    final hasError = widget.groupsAsync.hasError && groups.isEmpty;
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) {
        final rawKeyword = value.text.trim();
        final keyword = rawKeyword.toLowerCase();
        if (keyword.isEmpty) {
          return groupNames.take(12);
        }
        final matches =
            groupNames
                .where((name) => name.toLowerCase().contains(keyword))
                .take(12)
                .toList();
        final exists = groupNames.any((name) => name.toLowerCase() == keyword);
        if (!exists) {
          matches.add(rawKeyword);
        }
        return matches;
      },
      onSelected: (_) => widget.onChanged(),
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: '私人分组',
            hintText: '选择已有分组，或输入新分组名',
            helperText:
                loading
                    ? '正在读取分组'
                    : hasError
                    ? '分组读取失败，可直接输入新分组名'
                    : '不存在的分组名会在保存时自动创建',
            suffixIcon: IconButton(
              tooltip: '查看已有分组',
              onPressed:
                  groupNames.isEmpty
                      ? null
                      : () {
                        focusNode.requestFocus();
                        textController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: textController.text.length,
                        );
                      },
              icon: const Icon(Icons.arrow_drop_down_rounded),
            ),
          ),
          onChanged: (_) => widget.onChanged(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final items = options.toList(growable: false);
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final maxWidth = MediaQuery.sizeOf(context).width - 32;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            elevation: 2,
            shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Container(
              width: maxWidth.clamp(260.0, 420.0),
              constraints: const BoxConstraints(maxHeight: 248),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow.withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder:
                    (_, _) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Divider(
                        height: 1,
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.28,
                        ),
                      ),
                    ),
                itemBuilder: (context, index) {
                  final name = items[index];
                  final exists = groupNames.any(
                    (groupName) =>
                        groupName.toLowerCase() == name.toLowerCase(),
                  );
                  return _PrivateGroupOptionRow(
                    name: name,
                    exists: exists,
                    onTap: () => onSelected(name),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PrivateGroupOptionRow extends StatelessWidget {
  const _PrivateGroupOptionRow({
    required this.name,
    required this.exists,
    required this.onTap,
  });

  final String name;
  final bool exists;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color:
                    exists
                        ? colorScheme.primaryContainer.withValues(alpha: 0.48)
                        : colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.82,
                        ),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                exists
                    ? Icons.folder_outlined
                    : Icons.create_new_folder_outlined,
                size: 19,
                color:
                    exists ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    exists ? '已有私人分组' : '保存时创建',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

List<String> _uniqueGroupNames(List<PrivateBookSourceGroup> groups) {
  final seen = <String>{};
  final names = <String>[];
  for (final group in groups) {
    final name = group.displayName.trim();
    if (name.isEmpty || !seen.add(name)) {
      continue;
    }
    names.add(name);
  }
  names.sort();
  return names;
}

class _EmptySourcesCard extends StatelessWidget {
  const _EmptySourcesCard({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return AppEmptyStateCard(
      icon: Icons.library_books_outlined,
      title: '还没有私人书源',
      description: '可以导入自己的 Legado JSON 书源，并按私人分组维护。',
      actionLabel: '新增书源',
      onAction: onCreate,
    );
  }
}

class _FilterEmptySourcesCard extends StatelessWidget {
  const _FilterEmptySourcesCard({required this.keyword, required this.onClear});

  final String keyword;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AppEmptyStateCard(
      icon: Icons.manage_search_outlined,
      title: '没有匹配的书源',
      description: keyword.trim().isEmpty ? '当前分组暂无书源。' : keyword.trim(),
      actionLabel: '清空搜索',
      onAction: onClear,
      compact: true,
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppEmptyStateCard(
      icon: Icons.error_outline_rounded,
      title: title,
      description: message,
      actionLabel: '重试',
      onAction: onRetry,
      compact: true,
      centered: false,
    );
  }
}

String _limitText(int value) => value < 0 ? '不限' : '$value';

String _typeLabel(List<String> types) {
  if (types.isEmpty) {
    return '小说';
  }
  return types
      .map((type) {
        return switch (type) {
          'novel' => '小说',
          'comic' => '漫画',
          'audio' => '音频',
          'video' => '视频',
          _ => type,
        };
      })
      .join('、');
}

String _groupLabel(String value) {
  final normalized = value.trim();
  return normalized.isEmpty ? '未分组' : normalized;
}

bool _isDefaultGroup(PrivateBookSourceGroup group) {
  return group.displayName == '未分组';
}

String _reviewLabel(String value) {
  return switch (value) {
    'pending' => '待审核',
    'approved' => '已通过',
    'rejected' => '已拒绝',
    _ => value.isEmpty ? '待审核' : value,
  };
}

String _testLabel(String value) {
  return switch (value) {
    'passed' => '通过',
    'failed' => '失败',
    'pending' => '待检测',
    _ => value.isEmpty ? '未检测' : value,
  };
}

String _checkItemLabel(String value) {
  return switch (value) {
    'domain' => '域名',
    'search' => '搜索',
    'discovery' => '发现',
    'info' => '详情',
    'toc' => '目录',
    'content' => '正文',
    _ => value,
  };
}

List<String> _orderedCheckItems(Set<String> values) {
  return const <String>[
    'domain',
    'search',
    'discovery',
    'info',
    'toc',
    'content',
  ].where(values.contains).toList(growable: false);
}

String _formatDurationMs(int value) {
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)} 秒';
  }
  return '$value ms';
}

String _formatLogTime(int value) {
  final minutes = value ~/ 60000;
  final seconds = (value % 60000) ~/ 1000;
  final millis = value % 1000;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(3, '0')}';
}

List<PrivateBookSourceItem> _filterPrivateSources(
  List<PrivateBookSourceItem> items,
  String keyword,
) {
  final normalized = keyword.trim().toLowerCase();
  if (normalized.isEmpty) {
    return items;
  }
  return items
      .where((item) {
        final text =
            [
              item.name,
              item.description,
              item.groupName,
              item.reviewStatus,
              item.lastTestStatus,
              item.lastTestMessage,
              _typeLabel(item.supportedTypes),
              _groupLabel(item.groupName),
              _reviewLabel(item.reviewStatus),
              _testLabel(item.lastTestStatus),
            ].join(' ').toLowerCase();
        return text.contains(normalized);
      })
      .toList(growable: false);
}

String _messageOf(Object error) {
  if (error is ApiException) {
    return error.briefMessage;
  }
  return error.toString();
}
