import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/widgets/resolved_book_cover.dart';
import '../../../core/cache/cover_image_disk_cache.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/app_advanced_theme.dart';
import '../../../domain/entities/cover_gallery.dart';
import '../../bookshelf/application/bookshelf_service.dart';
import '../application/advanced_theme_service.dart';
import '../application/cover_gallery_service.dart';

class CacheManagementPage extends StatefulWidget {
  const CacheManagementPage({super.key});

  @override
  State<CacheManagementPage> createState() => _CacheManagementPageState();
}

class _CacheManagementPageState extends State<CacheManagementPage> {
  final BookshelfService _bookshelfService = BookshelfService();
  final AdvancedThemeService _advancedThemeService = AdvancedThemeService();
  final CoverGalleryService _coverGalleryService = CoverGalleryService();
  late Future<Map<String, _CachedBookPresentation>>
  _bookPresentationIndexFuture;
  AppAdvancedTheme? _activeTheme;
  List<CoverGallery> _coverGalleries = const <CoverGallery>[];

  @override
  void initState() {
    super.initState();
    _bookPresentationIndexFuture = _buildBookPresentationIndex();
    unawaited(_loadCoverThemeContext());
  }

  Future<Map<String, _CachedBookPresentation>>
  _buildBookPresentationIndex() async {
    final items = await _bookshelfService.getAll();
    final records = await AppDatabase.instance.listLatestReadingRecords();
    final result = <String, _CachedBookPresentation>{};

    for (final record in records) {
      final bookId = record.bookId.trim();
      if (bookId.isEmpty) {
        continue;
      }
      final title = record.bookTitle.trim();
      result[bookId] = _CachedBookPresentation(
        bookId: record.bookId,
        sourceId: record.sourceId,
        detailUrl: record.detailUrl,
        title: title.isEmpty ? null : title,
        author: record.bookAuthor?.trim(),
        coverUrl: record.coverUrl?.trim(),
        inBookshelf: false,
      );
    }

    for (final item in items) {
      final bookId = item.bookId.trim();
      if (bookId.isEmpty) {
        continue;
      }
      result[bookId] = _CachedBookPresentation(
        bookId: item.bookId,
        sourceId: item.sourceId,
        detailUrl: item.detailUrl,
        title:
            item.title.trim().isEmpty
                ? result[bookId]?.title
                : item.title.trim(),
        author:
            item.author?.trim().isNotEmpty == true
                ? item.author!.trim()
                : result[bookId]?.author,
        coverUrl:
            item.coverUrl?.trim().isNotEmpty == true
                ? item.coverUrl!.trim()
                : result[bookId]?.coverUrl,
        inBookshelf: true,
      );
    }

    return result;
  }

  Future<void> _loadCoverThemeContext() async {
    final activeTheme = await _advancedThemeService.loadActiveTheme();
    final coverGalleries = await _coverGalleryService.loadGalleries();
    if (!mounted) {
      return;
    }
    setState(() {
      _activeTheme = activeTheme;
      _coverGalleries = coverGalleries;
    });
  }

  void _reloadBookPresentationIndex() {
    setState(() {
      _bookPresentationIndexFuture = _buildBookPresentationIndex();
    });
    unawaited(_loadCoverThemeContext());
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
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
        appBar: AppBar(
          leading: IconButton(
            onPressed: _handleBackNavigation,
            tooltip: '返回',
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('本地缓存'),
          actions: [
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

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    12,
                    horizontal,
                    12 + bottomSafe,
                  ),
                  child: FutureBuilder<Map<String, _CachedBookPresentation>>(
                    future: _bookPresentationIndexFuture,
                    builder: (context, snapshot) {
                      final presentationIndex =
                          snapshot.data ??
                          const <String, _CachedBookPresentation>{};

                      return StreamBuilder<List<ChapterCacheBookSummary>>(
                        stream: AppDatabase.instance.watchCachedBooks(),
                        builder: (context, summarySnapshot) {
                          final summaries =
                              summarySnapshot.data ??
                              const <ChapterCacheBookSummary>[];
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
                                onClearAll: _confirmClearAll,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '小说缓存',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
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
    required VoidCallback? onClearAll,
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: onClearAll,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('清理全部缓存'),
                    ),
                  ),
                ],
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
    required List<ChapterCacheBookSummary> summaries,
    required Map<String, _CachedBookPresentation> presentationIndex,
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
        final subtitle =
            presentation == null
                ? '已缓存 ${summary.cachedCount} 章 · 缺少书籍信息'
                : presentation.inBookshelf
                ? '已缓存 ${summary.cachedCount} 章'
                : '已缓存 ${summary.cachedCount} 章 · 书籍已从书架移除';

        return Card(
          child: ListTile(
            leading: _buildCover(
              realCoverUrl: presentation?.coverUrl,
              title: title,
              author: presentation?.author,
              bookId: presentation?.bookId ?? summary.bookId,
              sourceId: presentation?.sourceId,
              detailUrl: presentation?.detailUrl,
            ),
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: '清理本书缓存',
              onPressed: () => _confirmClearBook(summary, presentation),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
            onTap: () => _confirmClearBook(summary, presentation),
          ),
        );
      },
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
      activeTheme: _activeTheme,
      galleries: _coverGalleries,
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

    await AppDatabase.instance.clearChapterCaches();
    final clearedCoverCount = await CoverImageDiskCache.instance.clearAll();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已清理全部缓存（封面 $clearedCoverCount 张）。')),
    );
  }

  Future<void> _confirmClearBook(
    ChapterCacheBookSummary summary,
    _CachedBookPresentation? presentation,
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

    await AppDatabase.instance.deleteChapterCachesByBookId(summary.bookId);
    final clearedCover = await CoverImageDiskCache.instance.clearByUrl(
      presentation?.coverUrl ?? '',
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

class _CachedBookPresentation {
  const _CachedBookPresentation({
    this.bookId,
    this.sourceId,
    this.detailUrl,
    this.title,
    this.author,
    this.coverUrl,
    required this.inBookshelf,
  });

  final String? bookId;
  final String? sourceId;
  final String? detailUrl;
  final String? title;
  final String? author;
  final String? coverUrl;
  final bool inBookshelf;
}
