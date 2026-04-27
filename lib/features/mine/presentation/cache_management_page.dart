import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/resolved_book_cover.dart';
import '../application/advanced_theme_provider.dart';
import '../application/cache_management_service.dart';
import '../application/cover_gallery_provider.dart';
import '../providers.dart';

class CacheManagementPage extends ConsumerStatefulWidget {
  const CacheManagementPage({super.key});

  @override
  ConsumerState<CacheManagementPage> createState() =>
      _CacheManagementPageState();
}

class _CacheManagementPageState extends ConsumerState<CacheManagementPage> {
  late final CacheManagementService _cacheManagementService;
  late Future<Map<String, CachedBookPresentation>> _bookPresentationIndexFuture;

  @override
  void initState() {
    super.initState();
    _cacheManagementService = ref.read(cacheManagementServiceProvider);
    _bookPresentationIndexFuture =
        _cacheManagementService.buildBookPresentationIndex();
  }

  void _reloadBookPresentationIndex() {
    setState(() {
      _bookPresentationIndexFuture =
          _cacheManagementService.buildBookPresentationIndex();
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeAdvancedTheme =
        ref.watch(activeAdvancedThemeProvider).valueOrNull;
    ref.watch(coverGalleriesProvider);
    final backdrop = resolveAdvancedThemeBackdrop(
      Theme.of(context).colorScheme,
      activeAdvancedTheme,
    );
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final canPopRoute = context.canPop();

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
          title: const Text('书籍缓存'),
          actions: [
            IconButton(
              onPressed: _confirmClearAll,
              tooltip: '清理全部缓存',
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
            IconButton(
              onPressed: () {
                _reloadBookPresentationIndex();
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
                      topInset + 12,
                      horizontal,
                      12 + bottomSafe,
                    ),
                    child: FutureBuilder<Map<String, CachedBookPresentation>>(
                      future: _bookPresentationIndexFuture,
                      builder: (context, snapshot) {
                        final presentationIndex =
                            snapshot.data ??
                            const <String, CachedBookPresentation>{};

                        return StreamBuilder<List<CachedBookSummary>>(
                          stream: _cacheManagementService.watchCachedBooks(),
                          builder: (context, summarySnapshot) {
                            final summaries =
                                summarySnapshot.data ??
                                const <CachedBookSummary>[];
                            final totalCachedChapters = summaries.fold<int>(
                              0,
                              (sum, item) => sum + item.cachedCount,
                            );

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHeaderCard(
                                  context,
                                  cachedBookCount: summaries.length,
                                  cachedChapterCount: totalCachedChapters,
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: _buildCacheList(
                                    context,
                                    summaries: summaries,
                                    presentationIndex: presentationIndex,
                                  ),
                                ),
                              ],
                            );
                          },
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

  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/mine');
  }

  Widget _buildHeaderCard(
    BuildContext context, {
    required int cachedBookCount,
    required int cachedChapterCount,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surfaceContainerHighest,
              colorScheme.surfaceContainerLow,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_outlined, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '本地缓存',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '已缓存 $cachedBookCount 本书 · 共 $cachedChapterCount 章',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '提示：这里会统一清理章节缓存与封面缓存，用于离线/弱网加速。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCacheList(
    BuildContext context, {
    required List<CachedBookSummary> summaries,
    required Map<String, CachedBookPresentation> presentationIndex,
  }) {
    if (summaries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.inbox_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '暂无缓存章节。\n你可以在书籍详情页或阅读页选择范围缓存。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: summaries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final summary = summaries[index];
        final presentation = presentationIndex[summary.bookId];

        final rawTitle = presentation?.title?.trim() ?? '';
        final title = rawTitle.isNotEmpty ? rawTitle : '未知书籍';
        final author = presentation?.author?.trim() ?? '';
        final statusLabel =
            presentation == null
                ? '缺少书籍信息'
                : presentation.inBookshelf
                ? '书架中'
                : '已移出书架';

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _confirmClearBook(summary, presentation),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCover(
                  realCoverUrl: presentation?.coverUrl,
                  title: title,
                  author: presentation?.author,
                  bookId: presentation?.bookId ?? summary.bookId,
                  sourceId: presentation?.sourceId,
                  detailUrl: presentation?.detailUrl,
                ),
                const SizedBox(width: 12),
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
                      if (author.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildInfoChip(context, '${summary.cachedCount} 章缓存'),
                          _buildInfoChip(context, statusLabel),
                          _buildInfoChip(
                            context,
                            '更新于 ${_formatTime(summary.updatedAt)}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '清理本书缓存',
                  onPressed: () => _confirmClearBook(summary, presentation),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(BuildContext context, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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

  Widget _buildCover({
    String? realCoverUrl,
    required String title,
    String? author,
    String? bookId,
    String? sourceId,
    String? detailUrl,
  }) {
    final resolvedCover = resolveBookCover(
      realCoverUrl: realCoverUrl,
      activeTheme: ref.read(activeAdvancedThemeProvider).valueOrNull,
      galleries: ref.read(coverGalleriesProvider).valueOrNull ?? const [],
      bookId: bookId,
      sourceId: sourceId,
      detailUrl: detailUrl,
    );
    return ResolvedBookCoverView(
      cover: resolvedCover,
      title: title,
      author: author,
      width: 42,
      height: 56,
      borderRadius: BorderRadius.circular(12),
    );
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('清理全部缓存？'),
          content: const Text('将删除所有已缓存的章节正文和封面缓存。此操作不可恢复。'),
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

    final clearedCoverCount = await _cacheManagementService.clearAllCaches();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已清理全部缓存（封面 $clearedCoverCount 张）。')),
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
          content: Text(
            '将删除《$title》的已缓存章节（${summary.cachedCount} 章），并尝试清理该书封面缓存。',
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

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }
}
