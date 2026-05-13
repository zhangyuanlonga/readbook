import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/platform/app_platform_capabilities.dart';
import '../../../app/tasks/app_task_manager.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/app_task_status.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../application/advanced_theme_provider.dart';
import '../application/cache_management_service.dart';
import '../providers.dart';

enum _StorageClearOption {
  chapterCaches,
  paginationCaches,
  coverCaches,
  searchSourceHits,
  legacyResidual,
  otherAppData,
  localImportedBooks,
}

class CacheManagementPage extends ConsumerStatefulWidget {
  const CacheManagementPage({super.key});

  @override
  ConsumerState<CacheManagementPage> createState() =>
      _CacheManagementPageState();
}

class _CacheManagementPageState extends ConsumerState<CacheManagementPage> {
  late final CacheManagementService _cacheManagementService;
  Map<String, CachedBookPresentation> _bookPresentationIndex =
      const <String, CachedBookPresentation>{};
  StorageManagementSnapshot? _storageSnapshot;
  bool _isBookPresentationIndexLoading = false;
  bool _hasLoadedBookPresentationIndex = false;
  bool _isStorageSnapshotLoading = false;
  Set<StorageSnapshotBucket> _loadedStorageBuckets =
      const <StorageSnapshotBucket>{};
  bool _isClearingSelection = false;
  Set<_StorageClearOption> _selectedOptions = <_StorageClearOption>{
    _StorageClearOption.chapterCaches,
    _StorageClearOption.paginationCaches,
    _StorageClearOption.coverCaches,
  };

  @override
  void initState() {
    super.initState();
    _cacheManagementService = ref.read(cacheManagementServiceProvider);
    unawaited(_loadBookPresentationIndex());
  }

  Future<void> _loadBookPresentationIndex() async {
    if (_isBookPresentationIndexLoading) {
      return;
    }
    const taskId = 'cache-book-presentation-index-scan';
    final taskManager = ref.read(appTaskManagerProvider);
    taskManager.startTask(
      id: taskId,
      status: const AppTaskStatusData(
        title: '正在扫描缓存书籍信息',
        message: '正在建立缓存展示索引…',
        kind: AppTaskStatusKind.cacheScan,
      ),
      channel: AppTaskChannel.resourceScan,
      priority: AppTaskPriority.background,
    );
    setState(() {
      _isBookPresentationIndexLoading = true;
    });
    try {
      final presentationIndex =
          await _cacheManagementService.buildBookPresentationIndex();
      if (!mounted) {
        return;
      }
      setState(() {
        _bookPresentationIndex = presentationIndex;
        _hasLoadedBookPresentationIndex = true;
      });
      taskManager.updateTask(
        taskId,
        AppTaskStatusData(
          title: '缓存书籍信息扫描完成',
          message: '已索引 ${presentationIndex.length} 本书。',
          kind: AppTaskStatusKind.cacheScan,
          progress: 1,
          result: AppTaskStatusResult.success,
        ),
      );
    } catch (error) {
      taskManager.updateTask(
        taskId,
        AppTaskStatusData(
          title: '缓存书籍信息扫描失败',
          message: '$error',
          kind: AppTaskStatusKind.cacheScan,
          result: AppTaskStatusResult.failure,
        ),
      );
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _isBookPresentationIndexLoading = false;
        });
      }
    }
  }

  Future<void> _loadStorageSnapshot({
    Set<StorageSnapshotBucket>? buckets,
  }) async {
    if (_isStorageSnapshotLoading) {
      return;
    }
    final targetBuckets = buckets ?? allStorageSnapshotBuckets;
    const taskId = 'cache-storage-snapshot-scan';
    final taskManager = ref.read(appTaskManagerProvider);
    taskManager.startTask(
      id: taskId,
      status: const AppTaskStatusData(
        title: '正在扫描存储占用',
        message: '正在统计缓存、主题资源和本地图书占用…',
        kind: AppTaskStatusKind.cacheScan,
      ),
      channel: AppTaskChannel.resourceScan,
      priority: AppTaskPriority.background,
    );
    setState(() {
      _isStorageSnapshotLoading = true;
    });
    try {
      final snapshot = await _cacheManagementService.loadStorageSnapshot(
        buckets: targetBuckets,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _storageSnapshot = _mergeStorageSnapshot(
          current: _storageSnapshot,
          next: snapshot,
          buckets: targetBuckets,
        );
        _loadedStorageBuckets = <StorageSnapshotBucket>{
          ..._loadedStorageBuckets,
          ...targetBuckets,
        };
      });
      taskManager.updateTask(
        taskId,
        AppTaskStatusData(
          title: '存储占用扫描完成',
          message: '已完成缓存和资源占用统计。',
          kind: AppTaskStatusKind.cacheScan,
          progress: 1,
          result: AppTaskStatusResult.success,
        ),
      );
    } catch (error) {
      taskManager.updateTask(
        taskId,
        AppTaskStatusData(
          title: '存储占用扫描失败',
          message: '$error',
          kind: AppTaskStatusKind.cacheScan,
          result: AppTaskStatusResult.failure,
        ),
      );
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _isStorageSnapshotLoading = false;
        });
      }
    }
  }

  StorageManagementSnapshot _mergeStorageSnapshot({
    required StorageManagementSnapshot? current,
    required StorageManagementSnapshot next,
    required Set<StorageSnapshotBucket> buckets,
  }) {
    final base =
        current ??
        const StorageManagementSnapshot(
          cachedBookCount: 0,
          cachedChapterCount: 0,
          chapterCachesBytes: 0,
          paginationLayoutCount: 0,
          paginationLayoutsBytes: 0,
          coverCacheCount: 0,
          coverCachesBytes: 0,
          searchSourceHitCount: 0,
          searchSourceHitsBytes: 0,
          legacyResidualCount: 0,
          legacyResidualBytes: 0,
          themeAssetBytes: 0,
          localImportedBookCount: 0,
          localImportedBookBytes: 0,
          otherDataBytes: 0,
        );
    final hasChapter = buckets.contains(StorageSnapshotBucket.chapterCaches);
    final hasPagination = buckets.contains(
      StorageSnapshotBucket.paginationCaches,
    );
    final hasCover = buckets.contains(StorageSnapshotBucket.coverCaches);
    final hasSearch = buckets.contains(StorageSnapshotBucket.searchSourceHits);
    final hasLegacy = buckets.contains(StorageSnapshotBucket.legacyResidual);
    final hasTheme = buckets.contains(StorageSnapshotBucket.themeAssets);
    final hasLocalBooks = buckets.contains(
      StorageSnapshotBucket.localImportedBooks,
    );
    final hasOther = buckets.contains(StorageSnapshotBucket.otherAppData);
    return StorageManagementSnapshot(
      cachedBookCount: hasChapter ? next.cachedBookCount : base.cachedBookCount,
      cachedChapterCount:
          hasChapter ? next.cachedChapterCount : base.cachedChapterCount,
      chapterCachesBytes:
          hasChapter ? next.chapterCachesBytes : base.chapterCachesBytes,
      paginationLayoutCount:
          hasPagination
              ? next.paginationLayoutCount
              : base.paginationLayoutCount,
      paginationLayoutsBytes:
          hasPagination
              ? next.paginationLayoutsBytes
              : base.paginationLayoutsBytes,
      coverCacheCount: hasCover ? next.coverCacheCount : base.coverCacheCount,
      coverCachesBytes:
          hasCover ? next.coverCachesBytes : base.coverCachesBytes,
      searchSourceHitCount:
          hasSearch ? next.searchSourceHitCount : base.searchSourceHitCount,
      searchSourceHitsBytes:
          hasSearch ? next.searchSourceHitsBytes : base.searchSourceHitsBytes,
      legacyResidualCount:
          hasLegacy ? next.legacyResidualCount : base.legacyResidualCount,
      legacyResidualBytes:
          hasLegacy ? next.legacyResidualBytes : base.legacyResidualBytes,
      themeAssetBytes: hasTheme ? next.themeAssetBytes : base.themeAssetBytes,
      localImportedBookCount:
          hasLocalBooks
              ? next.localImportedBookCount
              : base.localImportedBookCount,
      localImportedBookBytes:
          hasLocalBooks
              ? next.localImportedBookBytes
              : base.localImportedBookBytes,
      otherDataBytes: hasOther ? next.otherDataBytes : base.otherDataBytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeAdvancedTheme =
        ref.watch(activeAdvancedThemeProvider).valueOrNull;
    final backdrop = resolveAdvancedThemeBackdrop(
      Theme.of(context).colorScheme,
      activeAdvancedTheme,
    );
    final metrics = AppAdaptiveMetrics.of(context);
    final horizontal = metrics.pagePadding;
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final canPopRoute = context.canPop();
    final capabilities = ref.watch(appPlatformCapabilitiesProvider);

    return PopScope<void>(
      canPop: canPopRoute,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !mounted) {
          return;
        }
        context.go('/mine');
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          leading: IconButton(
            onPressed: _handleBackNavigation,
            tooltip: '返回',
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('存储管理'),
          actions: [
            IconButton(
              onPressed: () {
                unawaited(_loadBookPresentationIndex());
                unawaited(_loadStorageSnapshot());
              },
              tooltip: '刷新',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, _) {
            final maxWidth = AppLayout.pageContentMaxWidth(
              context,
              maxWidth: AppLayout.settingsContentMaxWidth,
            );

            return DecoratedBox(
              decoration: buildAdvancedThemeBackdropDecoration(backdrop),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      topInset + metrics.contentGap,
                      horizontal,
                      metrics.sectionGap + bottomSafe,
                    ),
                    child: StreamBuilder<List<CachedBookSummary>>(
                      stream: _cacheManagementService.watchCachedBooks(),
                      builder: (context, summarySnapshot) {
                        final summaries =
                            summarySnapshot.data ?? const <CachedBookSummary>[];
                        final totalCachedChapters = summaries.fold<int>(
                          0,
                          (sum, item) => sum + item.cachedCount,
                        );
                        final needsPresentationIndexRefresh = summaries.any(
                          (summary) =>
                              !_bookPresentationIndex.containsKey(
                                summary.bookId,
                              ),
                        );
                        if (needsPresentationIndexRefresh &&
                            !_isBookPresentationIndexLoading) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) {
                              return;
                            }
                            unawaited(_loadBookPresentationIndex());
                          });
                        }

                        final snapshot =
                            _storageSnapshot ??
                            StorageManagementSnapshot(
                              cachedBookCount: summaries.length,
                              cachedChapterCount: totalCachedChapters,
                              chapterCachesBytes: 0,
                              paginationLayoutCount: 0,
                              paginationLayoutsBytes: 0,
                              coverCacheCount: 0,
                              coverCachesBytes: 0,
                              searchSourceHitCount: 0,
                              searchSourceHitsBytes: 0,
                              legacyResidualCount: 0,
                              legacyResidualBytes: 0,
                              themeAssetBytes: 0,
                              localImportedBookCount: 0,
                              localImportedBookBytes: 0,
                              otherDataBytes: 0,
                            );

                        final isBootstrapLoading =
                            (_isBookPresentationIndexLoading &&
                                !_hasLoadedBookPresentationIndex);

                        return AppFadeSlideTransition(
                          child: ListView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            children: [
                              AppAnimatedSwitcher(
                                child:
                                    isBootstrapLoading
                                        ? const LinearProgressIndicator(
                                          key: ValueKey(
                                            'cache_management_loading',
                                          ),
                                          minHeight: 2,
                                        )
                                        : const SizedBox.shrink(
                                          key: ValueKey(
                                            'cache_management_idle',
                                          ),
                                        ),
                              ),
                              if (isBootstrapLoading)
                                const SizedBox(height: 12),
                              if (_loadedStorageBuckets.isEmpty) ...[
                                _buildStorageLazyNotice(context),
                                SizedBox(height: metrics.contentGap),
                              ],
                              if (!capabilities.supportsManagedFileStorage) ...[
                                _buildStorageCapabilityNotice(context),
                                SizedBox(height: metrics.contentGap),
                              ],
                              ..._buildStorageSections(
                                context,
                                snapshot: snapshot,
                                summaries: summaries,
                                presentationIndex: _bookPresentationIndex,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStorageLazyNotice(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(metrics.cardPadding),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(metrics.cardRadius),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.speed_outlined, color: colorScheme.primary),
          SizedBox(width: metrics.contentGap),
          Expanded(
            child: Text(
              '存储占用已改为按需统计，进入页面不会立即扫描缓存和资源目录。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                height: 1.4,
              ),
            ),
          ),
          TextButton.icon(
            onPressed:
                _isStorageSnapshotLoading
                    ? null
                    : () => unawaited(_loadStorageSnapshot()),
            icon:
                _isStorageSnapshotLoading
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.refresh_rounded),
            label: const Text('统计'),
          ),
        ],
      ),
    );
  }

  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/mine');
  }

  Widget _buildStorageCapabilityNotice(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(metrics.cardPadding),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(metrics.cardRadius),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: colorScheme.secondary),
          SizedBox(width: metrics.contentGap),
          Expanded(
            child: Text(
              '当前平台使用受限存储能力，文件路径和批量清理会按平台能力降级显示；本地阅读、书签和阅读记录不受影响。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildStorageSections(
    BuildContext context, {
    required StorageManagementSnapshot snapshot,
    required List<CachedBookSummary> summaries,
    required Map<String, CachedBookPresentation> presentationIndex,
  }) {
    final metrics = AppAdaptiveMetrics.of(context);
    return <Widget>[
      _buildSectionTitle(context, '缓存数据'),
      SizedBox(height: metrics.contentGap * 0.6),
      _buildStorageOptionRow(
        context,
        option: _StorageClearOption.chapterCaches,
        icon: Icons.menu_book_outlined,
        title: '章节缓存',
        statsBucket: StorageSnapshotBucket.chapterCaches,
        statsLabel: _snapshotStatsLabel(
          '${snapshot.cachedChapterCount} 条 · ${_formatBytes(snapshot.chapterCachesBytes)}',
          StorageSnapshotBucket.chapterCaches,
        ),
      ),
      _buildListDivider(context),
      _buildStorageOptionRow(
        context,
        option: _StorageClearOption.paginationCaches,
        icon: Icons.auto_stories_outlined,
        title: '分页缓存',
        statsBucket: StorageSnapshotBucket.paginationCaches,
        statsLabel: _snapshotStatsLabel(
          '${snapshot.paginationLayoutCount} 条 · ${_formatBytes(snapshot.paginationLayoutsBytes)}',
          StorageSnapshotBucket.paginationCaches,
        ),
      ),
      _buildListDivider(context),
      _buildStorageOptionRow(
        context,
        option: _StorageClearOption.coverCaches,
        icon: Icons.image_outlined,
        title: '封面缓存',
        statsBucket: StorageSnapshotBucket.coverCaches,
        statsLabel: _snapshotStatsLabel(
          '${snapshot.coverCacheCount} 条 · ${_formatBytes(snapshot.coverCachesBytes)}',
          StorageSnapshotBucket.coverCaches,
        ),
      ),
      _buildListDivider(context),
      _buildStorageOptionRow(
        context,
        option: _StorageClearOption.searchSourceHits,
        icon: Icons.travel_explore_outlined,
        title: '搜索命中记录',
        statsBucket: StorageSnapshotBucket.searchSourceHits,
        statsLabel: _snapshotStatsLabel(
          '${snapshot.searchSourceHitCount} 条 · ${_formatBytes(snapshot.searchSourceHitsBytes)}',
          StorageSnapshotBucket.searchSourceHits,
        ),
      ),
      _buildListDivider(context),
      _buildStorageOptionRow(
        context,
        option: _StorageClearOption.legacyResidual,
        icon: Icons.restore_from_trash_outlined,
        title: '旧版残留',
        statsBucket: StorageSnapshotBucket.legacyResidual,
        statsLabel: _snapshotStatsLabel(
          '${snapshot.legacyResidualCount} 项 · ${_formatBytes(snapshot.legacyResidualBytes)}',
          StorageSnapshotBucket.legacyResidual,
        ),
        highRisk: true,
        onDetailsTap:
            () => _showStorageDetails(
              title: '旧版残留',
              loader: _cacheManagementService.loadLegacyResidualDetails,
            ),
      ),
      _buildListDivider(context),
      _buildStorageOptionRow(
        context,
        option: _StorageClearOption.otherAppData,
        icon: Icons.layers_clear_outlined,
        title: '其他数据',
        statsBucket: StorageSnapshotBucket.otherAppData,
        statsLabel: _snapshotStatsLabel(
          _formatBytes(snapshot.otherDataBytes),
          StorageSnapshotBucket.otherAppData,
        ),
        highRisk: true,
        onDetailsTap:
            () => _showStorageDetails(
              title: '其他数据',
              loader: _cacheManagementService.loadOtherDataDetails,
            ),
      ),
      SizedBox(height: metrics.sectionGap),
      _buildSectionTitle(context, '本地数据'),
      SizedBox(height: metrics.contentGap * 0.6),
      _buildReadOnlyStorageRow(
        context,
        icon: Icons.palette_outlined,
        title: '主题数据',
        statsBucket: StorageSnapshotBucket.themeAssets,
        statsLabel: _snapshotStatsLabel(
          _formatBytes(snapshot.themeAssetBytes),
          StorageSnapshotBucket.themeAssets,
        ),
        onDetailsTap:
            () => _showStorageDetails(
              title: '主题数据',
              loader: _cacheManagementService.loadThemeAssetDetails,
              emptyText: '暂无主题资源。',
            ),
      ),
      _buildListDivider(context),
      _buildStorageOptionRow(
        context,
        option: _StorageClearOption.localImportedBooks,
        icon: Icons.folder_delete_outlined,
        title: '本地图书数据',
        statsBucket: StorageSnapshotBucket.localImportedBooks,
        statsLabel: _snapshotStatsLabel(
          '${snapshot.localImportedBookCount} 本 · ${_formatBytes(snapshot.localImportedBookBytes)}',
          StorageSnapshotBucket.localImportedBooks,
        ),
        highRisk: true,
      ),
      SizedBox(height: metrics.contentGap),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed:
                _selectedOptions.isEmpty || _isClearingSelection
                    ? null
                    : _clearSelectedStorageItems,
            icon: AppAnimatedSwitcher(
              child:
                  _isClearingSelection
                      ? const SizedBox(
                        key: ValueKey('cache_clear_progress'),
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(
                        Icons.delete_sweep_outlined,
                        key: ValueKey('cache_clear_icon'),
                      ),
            ),
            label: Text(_isClearingSelection ? '清理中...' : '清理所选'),
          ),
          TextButton(
            onPressed:
                _isClearingSelection
                    ? null
                    : () {
                      setState(() {
                        _selectedOptions = <_StorageClearOption>{
                          _StorageClearOption.chapterCaches,
                          _StorageClearOption.paginationCaches,
                          _StorageClearOption.coverCaches,
                        };
                      });
                    },
            child: const Text('恢复默认勾选'),
          ),
        ],
      ),
      SizedBox(height: metrics.sectionGap),
      _buildSectionTitle(context, '书籍缓存'),
      SizedBox(height: metrics.contentGap * 0.6),
      ..._buildBookCacheRows(
        context,
        summaries: summaries,
        presentationIndex: presentationIndex,
      ),
    ];
  }

  String _snapshotStatsLabel(String value, StorageSnapshotBucket bucket) {
    return _loadedStorageBuckets.contains(bucket) ? value : '未统计';
  }

  Widget _buildStorageOptionRow(
    BuildContext context, {
    required _StorageClearOption option,
    required IconData icon,
    required String title,
    required StorageSnapshotBucket statsBucket,
    required String statsLabel,
    bool highRisk = false,
    VoidCallback? onDetailsTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    final selected = _selectedOptions.contains(option);

    void toggle() {
      setState(() {
        if (selected) {
          _selectedOptions.remove(option);
        } else {
          _selectedOptions.add(option);
        }
      });
    }

    return InkWell(
      onTap: _isClearingSelection ? null : toggle,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: metrics.listTileMinHeight),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: metrics.contentGap * 0.8),
          child: Row(
            children: [
              Checkbox(
                value: selected,
                visualDensity: VisualDensity.compact,
                onChanged: _isClearingSelection ? null : (_) => toggle(),
              ),
              Icon(icon, size: 18, color: colorScheme.primary),
              SizedBox(width: metrics.contentGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildInfoChip(context, statsLabel),
                        if (highRisk) _buildInfoChip(context, '高风险'),
                      ],
                    ),
                  ],
                ),
              ),
              if (onDetailsTap != null) ...[
                SizedBox(width: metrics.contentGap * 0.4),
                IconButton(
                  tooltip: '查看明细',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDetailsTap,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
              IconButton(
                tooltip: '刷新统计',
                visualDensity: VisualDensity.compact,
                onPressed:
                    _isStorageSnapshotLoading
                        ? null
                        : () => unawaited(
                          _loadStorageSnapshot(buckets: {statsBucket}),
                        ),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyStorageRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required StorageSnapshotBucket statsBucket,
    required String statsLabel,
    VoidCallback? onDetailsTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    return InkWell(
      onTap: onDetailsTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: metrics.listTileMinHeight),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: metrics.contentGap * 0.8),
          child: Row(
            children: [
              const SizedBox(width: 40),
              Icon(icon, size: 18, color: colorScheme.primary),
              SizedBox(width: metrics.contentGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(children: [_buildInfoChip(context, statsLabel)]),
                  ],
                ),
              ),
              if (onDetailsTap != null) ...[
                SizedBox(width: metrics.contentGap * 0.4),
                IconButton(
                  tooltip: '查看明细',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDetailsTap,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
              IconButton(
                tooltip: '刷新统计',
                visualDensity: VisualDensity.compact,
                onPressed:
                    _isStorageSnapshotLoading
                        ? null
                        : () => unawaited(
                          _loadStorageSnapshot(buckets: {statsBucket}),
                        ),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBookCacheRows(
    BuildContext context, {
    required List<CachedBookSummary> summaries,
    required Map<String, CachedBookPresentation> presentationIndex,
  }) {
    if (summaries.isEmpty) {
      return <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(
            vertical: AppAdaptiveMetrics.of(context).contentGap,
          ),
          child: Row(
            children: [
              const Icon(Icons.inbox_outlined, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '暂无缓存章节。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    final children = <Widget>[];
    for (var index = 0; index < summaries.length; index++) {
      if (index > 0) {
        children.add(_buildListDivider(context));
      }
      final summary = summaries[index];
      final presentation = presentationIndex[summary.bookId];
      final rawTitle = presentation?.title?.trim() ?? '';
      final title = rawTitle.isNotEmpty ? rawTitle : '未知书籍';
      final statusLabel =
          presentation == null
              ? '缺少书籍信息'
              : presentation.inBookshelf
              ? '书架中'
              : '已移出书架';

      children.add(
        InkWell(
          onTap: () => _confirmClearBook(summary, presentation),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: AppAdaptiveMetrics.of(context).contentGap,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.book_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: AppAdaptiveMetrics.of(context).contentGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildInfoChip(context, '${summary.cachedCount} 章'),
                          _buildInfoChip(
                            context,
                            _formatBytes(summary.estimatedBytes),
                          ),
                          _buildInfoChip(context, statusLabel),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: AppAdaptiveMetrics.of(context).contentGap * 0.4,
                ),
                IconButton(
                  tooltip: '清理本书缓存',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _confirmClearBook(summary, presentation),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return children;
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _buildListDivider(BuildContext context) {
    return Divider(
      height: 1,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.42),
    );
  }

  Widget _buildInfoChip(BuildContext context, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    final metrics = AppAdaptiveMetrics.of(context);
    return Container(
      constraints: BoxConstraints(minHeight: metrics.chipHeight * 0.75),
      padding: EdgeInsets.symmetric(
        horizontal: metrics.contentGap * 0.8,
        vertical: metrics.isCompactDensity ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    const units = <String>['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }
    final fractionDigits = value >= 100 || unitIndex == 0 ? 0 : 1;
    return '${value.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
  }

  Future<void> _clearSelectedStorageItems() async {
    if (_selectedOptions.isEmpty || _isClearingSelection) {
      return;
    }
    final labels = <String>[
      if (_selectedOptions.contains(_StorageClearOption.chapterCaches)) '章节缓存',
      if (_selectedOptions.contains(_StorageClearOption.paginationCaches))
        '分页缓存',
      if (_selectedOptions.contains(_StorageClearOption.coverCaches)) '封面缓存',
      if (_selectedOptions.contains(_StorageClearOption.searchSourceHits))
        '搜索命中记录',
      if (_selectedOptions.contains(_StorageClearOption.legacyResidual)) '旧版残留',
      if (_selectedOptions.contains(_StorageClearOption.otherAppData)) '其他数据',
      if (_selectedOptions.contains(_StorageClearOption.localImportedBooks))
        '本地图书数据',
    ];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final highRiskLabels = <String>[
          if (_selectedOptions.contains(_StorageClearOption.legacyResidual))
            '旧版残留',
          if (_selectedOptions.contains(_StorageClearOption.otherAppData))
            '其他数据',
          if (_selectedOptions.contains(_StorageClearOption.localImportedBooks))
            '本地图书数据',
        ];
        return AlertDialog(
          title: const Text('清理所选内容？'),
          content: Text(
            highRiskLabels.isEmpty
                ? '将清理：${labels.join('、')}。'
                : '将清理：${labels.join('、')}。\n\n高风险项：${highRiskLabels.join('、')}。\n其中本地图书数据清理后需要重新导入，其他数据与旧版残留清理后可能无法恢复。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('清理'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isClearingSelection = true;
    });
    final taskId = 'cache-cleanup:${DateTime.now().microsecondsSinceEpoch}';
    final taskManager = ref.read(appTaskManagerProvider);
    taskManager.startTask(
      id: taskId,
      status: AppTaskStatusData(
        title: '正在清理缓存',
        message: '将清理：${labels.join('、')}。',
        kind: AppTaskStatusKind.cacheCleanup,
      ),
      channel: AppTaskChannel.maintenance,
      priority: AppTaskPriority.userInitiated,
    );

    var clearedChapterCount = 0;
    var clearedPaginationCount = 0;
    var clearedCoverCount = 0;
    var clearedSearchHitCount = 0;
    var clearedLegacyResidualCount = 0;
    var clearedOtherDataCount = 0;
    var clearedLocalBooksCount = 0;
    try {
      if (_selectedOptions.contains(_StorageClearOption.chapterCaches)) {
        taskManager.updateTask(
          taskId,
          const AppTaskStatusData(
            title: '正在清理缓存',
            message: '正在清理章节缓存…',
            kind: AppTaskStatusKind.cacheCleanup,
          ),
        );
        clearedChapterCount =
            await _cacheManagementService.clearChapterCachesOnly();
      }
      if (_selectedOptions.contains(_StorageClearOption.paginationCaches)) {
        taskManager.updateTask(
          taskId,
          const AppTaskStatusData(
            title: '正在清理缓存',
            message: '正在清理分页缓存…',
            kind: AppTaskStatusKind.cacheCleanup,
          ),
        );
        clearedPaginationCount =
            await _cacheManagementService.clearPaginationCachesOnly();
      }
      if (_selectedOptions.contains(_StorageClearOption.coverCaches)) {
        taskManager.updateTask(
          taskId,
          const AppTaskStatusData(
            title: '正在清理缓存',
            message: '正在清理封面缓存…',
            kind: AppTaskStatusKind.cacheCleanup,
          ),
        );
        clearedCoverCount =
            await _cacheManagementService.clearCoverCachesOnly();
      }
      if (_selectedOptions.contains(_StorageClearOption.searchSourceHits)) {
        taskManager.updateTask(
          taskId,
          const AppTaskStatusData(
            title: '正在清理缓存',
            message: '正在清理搜索命中记录…',
            kind: AppTaskStatusKind.cacheCleanup,
          ),
        );
        clearedSearchHitCount =
            await _cacheManagementService.clearSearchSourceHitsOnly();
      }
      if (_selectedOptions.contains(_StorageClearOption.legacyResidual)) {
        taskManager.updateTask(
          taskId,
          const AppTaskStatusData(
            title: '正在清理缓存',
            message: '正在清理旧版残留…',
            kind: AppTaskStatusKind.cacheCleanup,
          ),
        );
        clearedLegacyResidualCount =
            await _cacheManagementService.clearLegacyResidualOnly();
      }
      if (_selectedOptions.contains(_StorageClearOption.otherAppData)) {
        taskManager.updateTask(
          taskId,
          const AppTaskStatusData(
            title: '正在清理缓存',
            message: '正在清理其他数据…',
            kind: AppTaskStatusKind.cacheCleanup,
          ),
        );
        clearedOtherDataCount =
            await _cacheManagementService.clearOtherAppDataOnly();
      }
      if (_selectedOptions.contains(_StorageClearOption.localImportedBooks)) {
        taskManager.updateTask(
          taskId,
          const AppTaskStatusData(
            title: '正在清理缓存',
            message: '正在清理本地图书数据…',
            kind: AppTaskStatusKind.cacheCleanup,
          ),
        );
        clearedLocalBooksCount =
            await _cacheManagementService.clearLocalImportedBooksOnly();
      }
      await _loadBookPresentationIndex();
      await _loadStorageSnapshot();
    } catch (error) {
      taskManager.updateTask(
        taskId,
        AppTaskStatusData(
          title: '缓存清理失败',
          message: '$error',
          kind: AppTaskStatusKind.cacheCleanup,
          result: AppTaskStatusResult.failure,
        ),
      );
      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _isClearingSelection = false;
        });
      }
    }

    if (!mounted) {
      return;
    }

    final fragments = <String>[
      if (_selectedOptions.contains(_StorageClearOption.chapterCaches))
        '章节缓存 $clearedChapterCount 条',
      if (_selectedOptions.contains(_StorageClearOption.paginationCaches))
        '分页缓存 $clearedPaginationCount 条',
      if (_selectedOptions.contains(_StorageClearOption.coverCaches))
        '封面缓存 $clearedCoverCount 条',
      if (_selectedOptions.contains(_StorageClearOption.searchSourceHits))
        '搜索命中记录 $clearedSearchHitCount 条',
      if (_selectedOptions.contains(_StorageClearOption.legacyResidual))
        '旧版残留 $clearedLegacyResidualCount 项',
      if (_selectedOptions.contains(_StorageClearOption.otherAppData))
        '其他数据 $clearedOtherDataCount 项',
      if (_selectedOptions.contains(_StorageClearOption.localImportedBooks))
        '本地图书数据 $clearedLocalBooksCount 本',
    ];
    final message = '已清理：${fragments.join('，')}。';
    taskManager.updateTask(
      taskId,
      AppTaskStatusData(
        title: '缓存清理完成',
        message: message,
        kind: AppTaskStatusKind.cacheCleanup,
        progress: 1,
        result: AppTaskStatusResult.success,
      ),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showStorageDetails({
    required String title,
    required Future<List<StorageDetailEntry>> Function() loader,
    String emptyText = '暂无明细。',
  }) async {
    final entries = await loader();
    if (!mounted) {
      return;
    }
    final metrics = AppAdaptiveMetrics.of(context);
    final content = _StorageDetailsContent(
      title: title,
      entries: entries,
      emptyText: emptyText,
      formatBytes: _formatBytes,
    );
    if (metrics.isMediumUpWindow) {
      await showDialog<void>(
        context: context,
        builder:
            (context) => Dialog(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 680,
                  maxHeight: 620,
                ),
                child: content,
              ),
            ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: SizedBox(
              height:
                  MediaQuery.sizeOf(context).height *
                  (AppAdaptiveMetrics.of(context).isCompactDensity
                      ? 0.82
                      : 0.72),
              child: content,
            ),
          ),
    );
  }

  Future<void> _confirmClearBook(
    CachedBookSummary summary,
    CachedBookPresentation? presentation,
  ) async {
    final title =
        presentation?.title?.trim().isNotEmpty == true
            ? presentation!.title!.trim()
            : '未知书籍';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('清理本书缓存？'),
          content: Text('将删除《$title》的已缓存章节（${summary.cachedCount} 章）。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('清理'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final clearedCover = await _cacheManagementService.clearBookCache(
      bookId: summary.bookId,
      coverUrl: presentation?.coverUrl,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(clearedCover ? '已清理《$title》的缓存与封面。' : '已清理《$title》的缓存。'),
      ),
    );
  }
}

class _StorageDetailsContent extends StatelessWidget {
  const _StorageDetailsContent({
    required this.title,
    required this.entries,
    required this.emptyText,
    required this.formatBytes,
  });

  final String title;
  final List<StorageDetailEntry> entries;
  final String emptyText;
  final String Function(int bytes) formatBytes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child:
              entries.isEmpty
                  ? Center(child: Text(emptyText))
                  : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return ListTile(
                        title: Text(
                          entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle:
                            entry.subtitle == null
                                ? null
                                : Text(
                                  entry.subtitle!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        trailing: Text(
                          [
                            if (entry.trailingLabel != null)
                              entry.trailingLabel!,
                            formatBytes(entry.bytes),
                          ].join(' · '),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
