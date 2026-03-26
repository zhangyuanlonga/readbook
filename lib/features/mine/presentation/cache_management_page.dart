import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/widgets/disk_cached_cover_image.dart';
import '../../../core/cache/cover_image_disk_cache.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../bookshelf/application/bookshelf_service.dart';

class CacheManagementPage extends StatefulWidget {
  const CacheManagementPage({super.key});

  @override
  State<CacheManagementPage> createState() => _CacheManagementPageState();
}

class _CacheManagementPageState extends State<CacheManagementPage> {
  final BookshelfService _bookshelfService = BookshelfService();
  late final Future<Map<String, BookshelfBook>> _bookshelfIndexFuture;

  @override
  void initState() {
    super.initState();
    _bookshelfIndexFuture = _buildBookshelfIndex();
  }

  Future<Map<String, BookshelfBook>> _buildBookshelfIndex() async {
    final items = await _bookshelfService.getAll();
    return <String, BookshelfBook>{for (final item in items) item.bookId: item};
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
          title: const Text('缓存'),
          actions: [
            IconButton(
              onPressed: () {
                setState(() {
                  // force rebuild; stream will re-emit if DB changed.
                });
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
                  child: FutureBuilder<Map<String, BookshelfBook>>(
                    future: _bookshelfIndexFuture,
                    builder: (context, snapshot) {
                      final bookshelfIndex =
                          snapshot.data ?? const <String, BookshelfBook>{};

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
                                  bookshelfIndex: bookshelfIndex,
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
    required Map<String, BookshelfBook> bookshelfIndex,
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
        final bookshelfBook = bookshelfIndex[summary.bookId];

        final title = bookshelfBook?.title ?? summary.bookId;
        final subtitle =
            bookshelfBook == null
                ? '已缓存 ${summary.cachedCount} 章 · 书籍未加入书架'
                : '已缓存 ${summary.cachedCount} 章';

        return Card(
          child: ListTile(
            leading: _buildCover(bookshelfBook?.coverUrl, title),
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: '清理本书缓存',
              onPressed: () => _confirmClearBook(summary, bookshelfBook),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
            onTap: () => _confirmClearBook(summary, bookshelfBook),
          ),
        );
      },
    );
  }

  Widget _buildCover(String? coverUrl, String title) {
    final uri = Uri.tryParse(coverUrl ?? '');
    if (uri != null && uri.hasScheme) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DiskCachedCoverImage(
          imageUrl: coverUrl,
          width: 42,
          height: 56,
          fit: BoxFit.cover,
          fallback: _buildCoverFallback(title),
        ),
      );
    }

    return _buildCoverFallback(title);
  }

  Widget _buildCoverFallback(String title) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 42,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surfaceContainerHighest,
      ),
      alignment: Alignment.center,
      child: Text(
        title.isNotEmpty ? title.characters.first : '书',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
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
    BookshelfBook? bookshelfBook,
  ) async {
    final title = bookshelfBook?.title ?? summary.bookId;

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
      bookshelfBook?.coverUrl ?? '',
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
