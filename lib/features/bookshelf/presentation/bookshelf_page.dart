import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/reading_progress.dart';
import '../application/bookshelf_service.dart';
import '../../reader/application/reader_preferences_service.dart';
import '../../book/application/book_detail_service.dart';

class BookshelfPage extends StatefulWidget {
  const BookshelfPage({super.key});

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  final BookshelfService _bookshelfService = BookshelfService();
  final ReaderPreferencesService _readerPreferencesService =
      ReaderPreferencesService();
  final BookDetailService _bookDetailService = BookDetailService();

  bool _isLoading = true;
  List<BookshelfBook> _books = const <BookshelfBook>[];
  Map<String, ReadingProgress> _progressByBookId =
      const <String, ReadingProgress>{};
  bool _useGridView = false;
  String? _openingBookId;

  @override
  void initState() {
    super.initState();
    _loadBookshelf();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('书架'),
        actions: [
          IconButton(
            onPressed:
                _isLoading
                    ? null
                    : () {
                      setState(() {
                        _useGridView = !_useGridView;
                      });
                    },
            tooltip: _useGridView ? '切换列表视图' : '切换网格视图',
            icon: Icon(
              _useGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
            ),
          ),
          IconButton(
            onPressed: _isLoading ? null : _loadBookshelf,
            tooltip: '刷新书架',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colorScheme.surface, colorScheme.surfaceContainerLow],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _loadBookshelf,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildOverviewCard(),
              const SizedBox(height: 10),
              _buildActionCard(),
              const SizedBox(height: 12),
              if (_isLoading)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Expanded(child: Text('正在加载书架...')),
                      ],
                    ),
                  ),
                )
              else if (_books.isEmpty)
                _buildEmptyCard()
              else if (_useGridView)
                _buildBookGrid()
              else
                ..._books.map(_buildBookCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final totalCount = _books.length;
    final hasProgressCount = _progressByBookId.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_stories_rounded, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '阅读概览',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildOverviewChip('书籍', '$totalCount'),
                _buildOverviewChip('有进度', '$hasProgressCount'),
                _buildOverviewChip('视图', _useGridView ? '网格' : '列表'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewChip(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
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
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard() {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.travel_explore_rounded, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '发现感兴趣的新书并加入书架。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => context.go('/search'),
              icon: const Icon(Icons.search),
              label: const Text('去搜索'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _books.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) => _buildGridCard(_books[index]),
    );
  }

  Widget _buildGridCard(BookshelfBook book) {
    final progress = _progressByBookId[book.bookId];
    final colorScheme = Theme.of(context).colorScheme;
    final isOpening = _openingBookId == book.bookId;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap:
            isOpening
                ? null
                : () async {
                  await _openFromBookshelf(book, progress: progress);
                },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCover(book.coverUrl, width: double.infinity, height: 104),
              const SizedBox(height: 8),
              Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (book.author != null && book.author!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    book.author!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (isOpening)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '打开中',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookCard(BookshelfBook book) {
    final progress = _progressByBookId[book.bookId];
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCover(book.coverUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildInfoPill('来源', book.sourceId),
                          if (book.author != null && book.author!.isNotEmpty)
                            _buildInfoPill('作者', book.author!),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '收藏时间: ${_formatDateTime(book.addedAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (progress != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '上次阅读: ${progress.chapterTitle}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () => _openDetail(book),
                  child: const Text('查看详情'),
                ),
                if (progress != null)
                  FilledButton(
                    onPressed: () => _continueReading(progress),
                    child: const Text('继续阅读'),
                  ),
                OutlinedButton(
                  onPressed: () => _removeBook(book),
                  child: const Text('移出书架'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPill(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
  }

  Widget _buildCover(
    String? coverUrl, {
    double width = 78,
    double height = 108,
  }) {
    final uri = Uri.tryParse(coverUrl ?? '');
    if (uri == null || !uri.hasScheme) {
      return _buildCoverFallback(width: width, height: height);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        coverUrl!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder:
            (context, error, stackTrace) =>
                _buildCoverFallback(width: width, height: height),
      ),
    );
  }

  Widget _buildCoverFallback({double width = 78, double height = 108}) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.menu_book_outlined),
    );
  }

  Future<void> _loadBookshelf() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final books = await _bookshelfService.getAll();
      final progressEntries = await Future.wait(
        books.map((book) async {
          final progress = await _readerPreferencesService.loadProgress(
            book.bookId,
          );
          return MapEntry(book.bookId, progress);
        }),
      );

      final progressMap = <String, ReadingProgress>{};
      for (final entry in progressEntries) {
        if (entry.value != null) {
          progressMap[entry.key] = entry.value!;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _books = books;
        _progressByBookId = progressMap;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openDetail(BookshelfBook book) {
    final route =
        Uri(
          path: '/book/${book.bookId}',
          queryParameters: {
            'sourceId': book.sourceId,
            'detailUrl': book.detailUrl,
            'title': book.title,
          },
        ).toString();

    context.push(route);
  }

  Future<void> _openFromBookshelf(
    BookshelfBook book, {
    ReadingProgress? progress,
  }) async {
    if (progress != null) {
      _continueReading(progress);
      return;
    }

    if (_openingBookId != null) {
      return;
    }

    setState(() {
      _openingBookId = book.bookId;
    });

    try {
      final detailResult = await _bookDetailService.load(
        sourceId: book.sourceId,
        bookId: book.bookId,
        detailUrl: book.detailUrl,
        fallbackTitle: book.title,
      );

      if (!mounted) {
        return;
      }

      final chapter = detailResult.chapters.first;
      final route =
          Uri(
            path: '/reader/${chapter.bookId}/${chapter.id}',
            queryParameters: {
              'chapterUrl': chapter.chapterUrl,
              'chapterTitle': chapter.title,
              'sourceId': book.sourceId,
              'detailUrl': book.detailUrl,
              'chapterIndex': chapter.index.toString(),
            },
          ).toString();

      context.push(route);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _openDetail(book);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂时无法直达阅读，已为你打开详情页。')));
    } finally {
      if (mounted) {
        setState(() {
          _openingBookId = null;
        });
      }
    }
  }

  void _continueReading(ReadingProgress progress) {
    final route =
        Uri(
          path: '/reader/${progress.bookId}/${progress.chapterId}',
          queryParameters: {
            'chapterUrl': progress.chapterUrl,
            'chapterTitle': progress.chapterTitle,
            'sourceId': progress.sourceId,
            'detailUrl': progress.detailUrl,
            'chapterIndex': progress.chapterIndex.toString(),
          },
        ).toString();

    context.push(route);
  }

  Future<void> _removeBook(BookshelfBook book) async {
    await _bookshelfService.remove(
      sourceId: book.sourceId,
      detailUrl: book.detailUrl,
    );
    await _loadBookshelf();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已从书架移除。')));
  }
}
