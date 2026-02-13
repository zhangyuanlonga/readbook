import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/reading_progress.dart';
import '../application/bookshelf_service.dart';
import '../../reader/application/reader_preferences_service.dart';

class BookshelfPage extends StatefulWidget {
  const BookshelfPage({super.key});

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  final BookshelfService _bookshelfService = BookshelfService();
  final ReaderPreferencesService _readerPreferencesService =
      ReaderPreferencesService();

  bool _isLoading = true;
  List<BookshelfBook> _books = const <BookshelfBook>[];
  Map<String, ReadingProgress> _progressByBookId =
      const <String, ReadingProgress>{};
  bool _useGridView = false;

  @override
  void initState() {
    super.initState();
    _loadBookshelf();
  }

  @override
  Widget build(BuildContext context) {
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
              _useGridView ? Icons.view_list : Icons.grid_view_rounded,
            ),
          ),
          IconButton(
            onPressed: _isLoading ? null : _loadBookshelf,
            tooltip: '刷新书架',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadBookshelf,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('书架暂无内容，请先在搜索结果或详情页加入书架。'),
                ),
              )
            else if (_useGridView)
              _buildBookGrid()
            else
              ..._books.map(_buildBookCard),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => context.go('/search'),
              icon: const Icon(Icons.search),
              label: const Text('去搜索新书'),
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
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) => _buildGridCard(_books[index]),
    );
  }

  Widget _buildGridCard(BookshelfBook book) {
    final progress = _progressByBookId[book.bookId];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(book),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCover(book.coverUrl, width: double.infinity, height: 104),
              const SizedBox(height: 6),
              Text(
                book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (book.author != null && book.author!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    book.author!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (progress != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '读至: ${progress.chapterTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const Spacer(),
              Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    onPressed:
                        progress == null
                            ? null
                            : () => _continueReading(progress),
                    tooltip: '继续阅读',
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                  ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    onPressed: () => _removeBook(book),
                    tooltip: '移出书架',
                    icon: const Icon(Icons.delete_outline, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookCard(BookshelfBook book) {
    final progress = _progressByBookId[book.bookId];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text('来源: ${book.sourceId}'),
                      if (book.author != null && book.author!.isNotEmpty)
                        Text('作者: ${book.author}'),
                      const SizedBox(height: 4),
                      Text(
                        '收藏时间: ${book.addedAt.toLocal()}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (progress != null)
                        Text(
                          '上次阅读: ${progress.chapterTitle}',
                          style: Theme.of(context).textTheme.bodySmall,
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
      borderRadius: BorderRadius.circular(8),
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
        borderRadius: BorderRadius.circular(8),
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
