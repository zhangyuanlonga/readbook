import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_spacing.dart';
import '../../../app/widgets/disk_cached_cover_image.dart';
import '../../../core/errors/app_exception.dart';

import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/reading_progress.dart';
import '../application/bookshelf_service.dart';
import '../application/local_book_import_service.dart';
import '../../reader/application/reader_preferences_service.dart';
import '../../book/application/book_detail_service.dart';
import 'widgets/bookshelf_grid_sliver.dart';

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
  final LocalBookImportService _localBookImportService =
      LocalBookImportService();

  bool _isLoading = true;
  List<BookshelfBook> _books = const <BookshelfBook>[];
  Map<String, ReadingProgress> _progressByBookId =
      const <String, ReadingProgress>{};
  Map<String, String> _latestCachedChapterByBookId = const <String, String>{};
  bool _useGridView = false;
  String? _openingBookId;
  String? _loadErrorText;
  bool _isSelectionMode = false;
  bool _isBatchDeleting = false;
  final Set<String> _selectedBookKeys = <String>{};
  int _loadTicket = 0;

  static const String _kLocalBookSourceId =
      LocalBookImportService.localBookSourceId;
  static const Duration _kBookshelfLoadTimeout = Duration(seconds: 8);
  static const Duration _kProgressLoadTimeout = Duration(seconds: 2);
  static const Duration _kBooksModeSwitchItemDuration = Duration(
    milliseconds: 320,
  );
  static const int _kProgressBatchSize = 24;
  static const int _kBooksModeSwitchStaggerGroup = 8;
  static const double _kBooksModeSwitchStaggerStep = 0.07;
  static const double _kBooksModeSwitchCurveSpan = 0.42;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_loadBookshelf());
    });
  }

  @override
  void dispose() {
    _loadTicket += 1;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        leading:
            _isSelectionMode
                ? IconButton(
                  onPressed: _exitSelectionMode,
                  tooltip: '取消选择',
                  icon: const Icon(Icons.close),
                )
                : null,
        title: Text(
          _isSelectionMode ? '已选择 ${_selectedBookKeys.length} 项' : '书架',
        ),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              onPressed: _books.isEmpty ? null : _selectAllBooks,
              tooltip: '全选',
              icon: const Icon(Icons.select_all),
            ),
            IconButton(
              onPressed:
                  _selectedBookKeys.isEmpty || _isBatchDeleting
                      ? null
                      : _deleteSelectedBooks,
              tooltip: '删除已选',
              icon: const Icon(Icons.delete_outline),
            ),
          ] else ...[
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
                _useGridView
                    ? Icons.view_list_rounded
                    : Icons.grid_view_rounded,
              ),
            ),
            IconButton(
              tooltip: '导入本地书籍',
              onPressed: _importLocalBook,
              icon: const Icon(Icons.upload_file_outlined),
            ),
          ],
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
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 0),
                sliver: SliverToBoxAdapter(child: _buildOverviewCard()),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 0),
                sliver: SliverToBoxAdapter(child: _buildActionCard()),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  12,
                  horizontal,
                  16 + bottomSafe,
                ),
                sliver: _buildBooksContentSliver(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBooksContentSliver() {
    if (_isLoading && _books.isEmpty) {
      return const SliverToBoxAdapter(
        child: Card(
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
        ),
      );
    }

    if (_books.isEmpty && _loadErrorText != null) {
      return SliverToBoxAdapter(
        child: _buildLoadErrorCard(message: _loadErrorText!),
      );
    }

    if (_books.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyCard());
    }

    if (_useGridView) {
      return _buildBookGridSliver();
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final book = _books[index];
        return _buildModeSwitchAnimatedBookItem(
          book: book,
          index: index,
          child: _buildBookCard(book),
        );
      }, childCount: _books.length),
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

  Widget _buildLoadErrorCard({required String message}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '书架加载失败',
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
            const SizedBox(height: 10),
            FilledButton.tonal(
              onPressed: () => unawaited(_loadBookshelf()),
              child: const Text('重试'),
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
                '发现新书并加入书架',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
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

  Widget _buildBookGridSliver() {
    return BookshelfGridSliver(
      itemCount: _books.length,
      itemBuilder: (context, index) {
        final book = _books[index];
        return _buildModeSwitchAnimatedBookItem(
          book: book,
          index: index,
          child: _buildGridCard(book),
        );
      },
    );
  }

  Widget _buildModeSwitchAnimatedBookItem({
    required BookshelfBook book,
    required int index,
    required Widget child,
  }) {
    final delay =
        (index % _kBooksModeSwitchStaggerGroup) * _kBooksModeSwitchStaggerStep;
    final begin = delay.clamp(0.0, 1 - _kBooksModeSwitchCurveSpan);
    final end = begin + _kBooksModeSwitchCurveSpan;

    return TweenAnimationBuilder<double>(
      key: ValueKey<String>(
        'bookshelf_mode_${_useGridView ? 'grid' : 'list'}_${book.bookId}',
      ),
      tween: Tween<double>(begin: 0, end: 1),
      duration: _kBooksModeSwitchItemDuration,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, value, builtChild) {
        final translateY = (1 - value) * 16;
        final scale = 0.986 + (0.014 * value);
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, translateY),
            child: Transform.scale(
              alignment: Alignment.topCenter,
              scale: scale,
              child: builtChild,
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridCard(BookshelfBook book) {
    final progress = _progressByBookId[book.bookId];
    final colorScheme = Theme.of(context).colorScheme;
    final isOpening = _openingBookId == book.bookId;
    final isSelected = _isBookSelected(book);
    final titleText = _toSingleLineText(book.title);
    final authorText = _toSingleLineText(book.author ?? '');
    final chapterText = _toSingleLineText(progress?.chapterTitle ?? '');
    final subtitleText =
        chapterText.isNotEmpty
            ? '上次: $chapterText'
            : (authorText.isNotEmpty ? '作者: $authorText' : '未开始阅读');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onLongPress: () {
          if (_isSelectionMode) {
            _enterSelectionMode(book);
            return;
          }
          _openBookDetail(book);
        },
        onTap:
            _isSelectionMode
                ? () => _toggleBookSelection(book)
                : isOpening || _isBatchDeleting
                ? null
                : () async {
                  await _openFromBookshelf(book, progress: progress);
                },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _buildCover(
                        book.coverUrl,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    if (isOpening)
                      Positioned(
                        left: 6,
                        right: 6,
                        bottom: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colorScheme.scrim.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '打开中',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_isSelectionMode)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () => _toggleBookSelection(book),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color:
                                  isSelected
                                      ? colorScheme.primary
                                      : colorScheme.surface.withValues(
                                        alpha: 0.9,
                                      ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    isSelected
                                        ? colorScheme.primary
                                        : colorScheme.outline.withValues(
                                          alpha: 0.7,
                                        ),
                              ),
                            ),
                            child: Icon(
                              Icons.check,
                              size: 14,
                              color:
                                  isSelected
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                titleText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 1),
              Text(
                subtitleText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
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
    final isOpening = _openingBookId == book.bookId;
    final isSelected = _isBookSelected(book);
    final titleText = _toSingleLineText(book.title);
    final authorText = _toSingleLineText(book.author ?? '');
    final chapterText = _toSingleLineText(progress?.chapterTitle ?? '');
    final latestChapterText = _toSingleLineText(
      _latestCachedChapterByBookId[book.bookId] ?? '',
    );
    final lastReadLine =
        chapterText.isNotEmpty ? '上次: $chapterText' : '上次: 未开始阅读';
    final latestLine =
        latestChapterText.isNotEmpty ? '最新: $latestChapterText' : '最新: 暂无缓存章节';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap:
            _isSelectionMode
                ? () => _toggleBookSelection(book)
                : isOpening || _isBatchDeleting
                ? null
                : () async {
                  await _openFromBookshelf(book, progress: progress);
                },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 6, top: 2),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleBookSelection(book),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              InkResponse(
                onLongPress:
                    _isBatchDeleting ? null : () => _openBookDetail(book),
                containedInkWell: true,
                borderRadius: BorderRadius.circular(12),
                child: _buildCover(book.coverUrl, width: 58, height: 84),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress:
                      _isBatchDeleting ? null : () => _enterSelectionMode(book),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              titleText,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!_isSelectionMode) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  isOpening
                                      ? const CircularProgressIndicator(
                                        strokeWidth: 2,
                                      )
                                      : Icon(
                                        Icons.chevron_right_rounded,
                                        size: 20,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        authorText.isNotEmpty ? '作者: $authorText' : '作者: 未知',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lastReadLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        latestLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _bookKey(BookshelfBook book) {
    return '${book.sourceId}::${book.detailUrl}';
  }

  bool _isBookSelected(BookshelfBook book) {
    return _selectedBookKeys.contains(_bookKey(book));
  }

  void _enterSelectionMode(BookshelfBook book) {
    if (_isBatchDeleting) {
      return;
    }

    if (_isSelectionMode) {
      _toggleBookSelection(book);
      return;
    }

    final key = _bookKey(book);
    setState(() {
      _isSelectionMode = true;
      _selectedBookKeys
        ..clear()
        ..add(key);
    });
  }

  void _toggleBookSelection(BookshelfBook book) {
    if (!_isSelectionMode || _isBatchDeleting) {
      return;
    }

    final key = _bookKey(book);
    setState(() {
      if (_selectedBookKeys.contains(key)) {
        _selectedBookKeys.remove(key);
      } else {
        _selectedBookKeys.add(key);
      }

      if (_selectedBookKeys.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _selectAllBooks() {
    if (_books.isEmpty || _isBatchDeleting) {
      return;
    }

    setState(() {
      _isSelectionMode = true;
      _selectedBookKeys
        ..clear()
        ..addAll(_books.map(_bookKey));
    });
  }

  void _exitSelectionMode() {
    if (_isBatchDeleting) {
      return;
    }

    setState(() {
      _isSelectionMode = false;
      _selectedBookKeys.clear();
    });
  }

  void _syncSelectionWithBooks() {
    if (!_isSelectionMode) {
      return;
    }

    final validKeys = _books.map(_bookKey).toSet();
    final nextSelected =
        _selectedBookKeys.where((key) => validKeys.contains(key)).toSet();

    final changed =
        nextSelected.length != _selectedBookKeys.length ||
        (_books.isEmpty && _isSelectionMode);

    if (!changed || !mounted) {
      return;
    }

    setState(() {
      _selectedBookKeys
        ..clear()
        ..addAll(nextSelected);
      if (_selectedBookKeys.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  Future<void> _deleteSelectedBooks() async {
    if (_selectedBookKeys.isEmpty || _isBatchDeleting) {
      return;
    }

    final selected = _books
        .where((book) => _selectedBookKeys.contains(_bookKey(book)))
        .toList(growable: false);
    if (selected.isEmpty) {
      _exitSelectionMode();
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: '删除书籍',
      content: '确定删除已选 ${selected.length} 本书吗？该操作不可撤销。',
      confirmText: '删除',
    );
    if (!mounted || confirmed != true) {
      return;
    }

    setState(() {
      _isBatchDeleting = true;
    });

    var removedCount = 0;
    for (final book in selected) {
      try {
        await _removeBook(book, reload: false, showFeedback: false);
        removedCount += 1;
      } catch (_) {
        // Continue deleting remaining selected books.
      }
    }

    await _loadBookshelf();

    if (!mounted) {
      return;
    }

    setState(() {
      _isBatchDeleting = false;
      _isSelectionMode = false;
      _selectedBookKeys.clear();
    });

    _showMessage('已删除 $removedCount 本书。');
  }

  String _toSingleLineText(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
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
      child: DiskCachedCoverImage(
        imageUrl: coverUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        fallback: _buildCoverFallback(width: width, height: height),
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
    final ticket = ++_loadTicket;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadErrorText = null;
      });
    }

    try {
      final books = await _bookshelfService.getAll().timeout(
        _kBookshelfLoadTimeout,
      );

      if (!mounted || ticket != _loadTicket) {
        return;
      }

      setState(() {
        _books = books;
        _progressByBookId = const <String, ReadingProgress>{};
        _latestCachedChapterByBookId = const <String, String>{};
        _isLoading = false;
      });
      _syncSelectionWithBooks();

      if (books.isEmpty) {
        return;
      }

      await _loadLatestCachedChapterMap(books, ticket: ticket);
      await _loadProgressMapInBatches(books, ticket: ticket);
    } on TimeoutException {
      if (!mounted || ticket != _loadTicket) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadErrorText = '加载书架超时，请稍后重试。';
      });
    } catch (error) {
      if (!mounted || ticket != _loadTicket) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadErrorText = '加载书架失败：$error';
      });
    }
  }

  Future<void> _loadLatestCachedChapterMap(
    List<BookshelfBook> books, {
    required int ticket,
  }) async {
    final ids = books
        .map((book) => book.bookId.trim())
        .where((bookId) => bookId.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ids.isEmpty) {
      return;
    }

    final latestMap = await AppDatabase.instance.getLatestCachedChapterTitles(
      ids,
    );

    if (!mounted || ticket != _loadTicket) {
      return;
    }

    setState(() {
      _latestCachedChapterByBookId = latestMap;
    });
  }

  Future<void> _loadProgressMapInBatches(
    List<BookshelfBook> books, {
    required int ticket,
  }) async {
    final progressMap = <String, ReadingProgress>{};

    for (var start = 0; start < books.length; start += _kProgressBatchSize) {
      if (!mounted || ticket != _loadTicket) {
        return;
      }

      final end =
          (start + _kProgressBatchSize > books.length)
              ? books.length
              : start + _kProgressBatchSize;
      final batch = books.sublist(start, end);

      final entries = await Future.wait(
        batch.map((book) async {
          try {
            final progress = await _readerPreferencesService
                .loadProgress(book.bookId)
                .timeout(_kProgressLoadTimeout);
            return MapEntry(book.bookId, progress);
          } catch (_) {
            return MapEntry<String, ReadingProgress?>(book.bookId, null);
          }
        }),
      );

      if (!mounted || ticket != _loadTicket) {
        return;
      }

      for (final entry in entries) {
        final value = entry.value;
        if (value != null) {
          progressMap[entry.key] = value;
        }
      }

      setState(() {
        _progressByBookId = Map<String, ReadingProgress>.from(progressMap);
      });

      if (end < books.length) {
        await Future<void>.delayed(Duration.zero);
      }
    }
  }

  Future<void> _importLocalBook() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Book Files',
            extensions: ['txt', 'epub'],
            uniformTypeIdentifiers: [
              'public.plain-text',
              'org.idpf.epub-container',
            ],
          ),
        ],
        confirmButtonText: '导入书架',
      );
      if (file == null) {
        return;
      }

      final filePath = file.path.trim();
      if (filePath.isEmpty) {
        _showMessage('选择的文件无效，请重试。');
        return;
      }

      final result = await _localBookImportService.importFromFile(
        filePath: filePath,
        displayName: file.name,
      );

      await _loadBookshelf();
      _showMessage('已导入《${result.localBook.title}》到书架。');
    } on AppException catch (error) {
      _showMessage(error.briefMessage);
    } catch (_) {
      _showMessage('导入本地书籍失败，请重试。');
    }
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openFromBookshelf(
    BookshelfBook book, {
    ReadingProgress? progress,
  }) async {
    if (progress != null) {
      _continueReading(progress);
      return;
    }

    if (book.sourceId == _kLocalBookSourceId) {
      context.push('/local/book/${book.bookId}');
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
      _showMessage('打开阅读失败，请稍后重试。');
    } finally {
      if (mounted) {
        setState(() {
          _openingBookId = null;
        });
      }
    }
  }

  void _continueReading(ReadingProgress progress) {
    if (progress.sourceId == _kLocalBookSourceId) {
      context.push('/local/reader/${progress.bookId}/${progress.chapterId}');
      return;
    }

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

  void _openBookDetail(BookshelfBook book) {
    if (_isBatchDeleting) {
      return;
    }

    if (book.sourceId == _kLocalBookSourceId) {
      context.push('/local/book/${book.bookId}');
      return;
    }

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

  Future<void> _removeBook(
    BookshelfBook book, {
    bool reload = true,
    bool showFeedback = true,
  }) async {
    if (book.sourceId == _kLocalBookSourceId) {
      await _localBookImportService.removeLocalBook(
        bookId: book.bookId,
        detailUrl: book.detailUrl,
      );
    } else {
      await _bookshelfService.remove(
        sourceId: book.sourceId,
        detailUrl: book.detailUrl,
      );
    }

    if (reload) {
      await _loadBookshelf();
    }

    if (!mounted || !showFeedback) {
      return;
    }

    _showMessage('已从书架移除。');
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    String confirmText = '确认',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }
}
