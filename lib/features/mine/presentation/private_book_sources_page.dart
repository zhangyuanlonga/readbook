import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/adaptive_filter_bar.dart';
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
                    const _PrivateSourceSearchField(),
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
                    _GroupFilterSection(
                      selectedGroupId: selectedGroupId,
                      groupsAsync: groupsAsync,
                      onSelected: (groupId) {
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
                                onToggle:
                                    (enabled) => unawaited(
                                      _runAction(
                                        context,
                                        ref,
                                        () => ref
                                            .read(
                                              privateBookSourceServiceProvider,
                                            )
                                            .setEnabled(item.id, enabled),
                                        enabled ? '已启用书源' : '已停用书源',
                                      ),
                                    ),
                                onTest:
                                    () => unawaited(
                                      _runAction(
                                        context,
                                        ref,
                                        () => ref
                                            .read(
                                              privateBookSourceServiceProvider,
                                            )
                                            .test(item.id),
                                        '书源测试已记录',
                                      ),
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
          icon: Icons.refresh_rounded,
          label: '刷新',
          priority: 8,
          onPressed: () => _refresh(ref),
        ),
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
        IconButton(
          tooltip: '刷新',
          onPressed: () => _refresh(ref),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  static Future<void> _openGroupManager(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
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
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _PrivateSourceForm(item: item),
    );
    if (changed == true) {
      _refresh(ref);
    }
  }

  static Future<void> _deleteSource(
    BuildContext context,
    WidgetRef ref,
    PrivateBookSourceItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('删除书源'),
            content: Text('确认删除“${item.name}”？删除后不可恢复。'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('删除'),
              ),
            ],
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
    final note = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('提交共享审核'),
            content: TextField(
              controller: noteController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '提交说明',
                hintText: '说明这个书源适合共享的原因',
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.of(context).pop(noteController.text.trim()),
                child: const Text('提交'),
              ),
            ],
          ),
    );
    noteController.dispose();
    if (note == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await _runAction(
      context,
      ref,
      () => ref.read(privateBookSourceServiceProvider).submit(item.id, note),
      '已提交共享审核',
    );
  }

  static Future<void> _runAction(
    BuildContext context,
    WidgetRef ref,
    Future<PrivateBookSourceItem> Function() action,
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
              label: '测试 ${_remainingText(quota.dailyTestRemaining)}',
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

class _GroupFilterSection extends StatelessWidget {
  const _GroupFilterSection({
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
        return AdaptiveFilterBar(
          showActionButton: false,
          chips: <AdaptiveFilterChipData>[
            AdaptiveFilterChipData(
              label: '全部',
              selected: selectedGroupId == null,
              onTap: () => onSelected(null),
            ),
            for (final group in groups)
              AdaptiveFilterChipData(
                label: group.displayName,
                selected: selectedGroupId == group.id,
                onTap: () => onSelected(group.id),
              ),
          ],
        );
      },
      loading:
          () => const SizedBox(
            height: 32,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      error:
          (error, _) => Align(
            alignment: Alignment.centerLeft,
            child: _InlineRetryPill(onPressed: onRetry, label: '分组读取失败'),
          ),
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
  bool _changed = false;

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
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottomInset + 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '私人分组',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed:
                      () => Navigator.of(context).pop(_changed ? true : null),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: '新增分组',
                      hintText: '例如：常用、漫画、备用',
                    ),
                    onSubmitted: (_) => unawaited(_createGroup()),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _saving ? null : () => unawaited(_createGroup()),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(_saving ? '保存中' : '新增'),
                ),
              ],
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
    final name = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('重命名分组'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: '分组名称'),
              onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.of(context).pop(controller.text.trim()),
                child: const Text('保存'),
              ),
            ],
          ),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('删除分组'),
            content: Text('确认删除“${group.displayName}”？分组内书源会移到未分组。'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('删除'),
              ),
            ],
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
    _changed = true;
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

class _InlineRetryPill extends StatelessWidget {
  const _InlineRetryPill({required this.onPressed, required this.label});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        foregroundColor: colorScheme.onSurfaceVariant,
      ),
      icon: const Icon(Icons.refresh_rounded, size: 16),
      label: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PrivateSourceTile extends StatelessWidget {
  const _PrivateSourceTile({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    required this.onTest,
    required this.onSubmit,
  });

  final PrivateBookSourceItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTest;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final testText =
        item.lastTestStatus.isEmpty && item.lastTestMessage.isEmpty
            ? '未测试'
            : '${_testLabel(item.lastTestStatus)}${item.lastTestMessage.isEmpty ? '' : ' · ${item.lastTestMessage}'}';
    final infoLine = [
      _typeLabel(item.supportedTypes),
      _groupLabel(item.groupName),
      _visibilityLabel(item.visibility),
      _reviewLabel(item.reviewStatus),
      '测试 $testText',
      if (item.description.isNotEmpty) item.description,
    ].join(' · ');
    return Material(
      color: colorScheme.surfaceContainerLow.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: item.visibility == 'shared' ? null : onEdit,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.32),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _EnabledStatusPill(
                          enabled: item.enabled,
                          onTap: () => onToggle(!item.enabled),
                        ),
                      ],
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

class _EnabledStatusPill extends StatelessWidget {
  const _EnabledStatusPill({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = enabled ? colorScheme.primary : colorScheme.onSurfaceVariant;
    return Material(
      color:
          enabled
              ? colorScheme.primaryContainer.withValues(alpha: 0.5)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.74),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            enabled ? '启用' : '停用',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
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
                  label: '测试',
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
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottomInset + 16),
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
                TextFormField(
                  controller: _groupController,
                  decoration: const InputDecoration(
                    labelText: '私人分组',
                    hintText: '不填会使用书源 JSON 分组或未分组',
                  ),
                  onChanged: (_) {
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
                              : () => Navigator.of(context).pop(false),
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
      if (_isEditing) {
        await ref
            .read(privateBookSourceServiceProvider)
            .update(widget.item!.id, input);
      } else {
        await ref.read(privateBookSourceServiceProvider).create(input);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
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

String _remainingText(int value) => value < 0 ? '不限' : '剩 $value';

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

String _visibilityLabel(String value) {
  return switch (value) {
    'private' => '私人',
    'submitted' => '审核中',
    'shared' => '共享',
    _ => value.isEmpty ? '私人' : value,
  };
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
    'pending' => '待测试',
    _ => value.isEmpty ? '未测试' : value,
  };
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
              item.visibility,
              item.reviewStatus,
              item.lastTestStatus,
              item.lastTestMessage,
              _typeLabel(item.supportedTypes),
              _groupLabel(item.groupName),
              _visibilityLabel(item.visibility),
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
