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

enum _BookshelfSheetAction { read, detail, select, tag, delete }

enum _BookshelfFilter { all, local, novel, manga, custom }

enum _TagManageSheetAction { rename, delete }

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
  Map<String, int> _sourceTypeBySourceId = const <String, int>{};
  Map<String, List<String>> _bookTagsByKey = const <String, List<String>>{};
  bool _useGridView = false;
  _BookshelfFilter _activeFilter = _BookshelfFilter.all;
  String? _activeCustomTag;
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
  static const Duration _kSourceMapLoadTimeout = Duration(seconds: 2);
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
      unawaited(_restoreViewModePreference());
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
    final filteredBooks = _filteredBooks;

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
          if (_isSelectionMode)
            if (_isBatchDeleting)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              const SizedBox.shrink()
          else ...[
            IconButton(
              onPressed:
                  _isLoading || filteredBooks.isEmpty || _isBatchDeleting
                      ? null
                      : _startSelectionMode,
              tooltip: '管理书架',
              icon: const Icon(Icons.checklist_rounded),
            ),
            IconButton(
              tooltip: '导入本地书籍',
              onPressed: _importLocalBook,
              icon: const Icon(Icons.upload_file_outlined),
            ),
          ],
        ],
      ),
      bottomNavigationBar:
          _isSelectionMode
              ? _buildSelectionActionBar(filteredBooks: filteredBooks)
              : null,
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
              if (_books.isNotEmpty)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 0),
                  sliver: SliverToBoxAdapter(child: _buildFilterBar()),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  10,
                  horizontal,
                  16 + bottomSafe,
                ),
                sliver: _buildBooksContentSliver(filteredBooks),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBooksContentSliver(List<BookshelfBook> books) {
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

    if (books.isEmpty) {
      return SliverToBoxAdapter(child: _buildFilterEmptyCard());
    }

    if (_useGridView) {
      return _buildBookGridSliver(books);
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final book = books[index];
        return _buildModeSwitchAnimatedBookItem(
          book: book,
          index: index,
          child: _buildBookCard(book),
        );
      }, childCount: books.length),
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

  Widget _buildFilterEmptyCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.filter_alt_off_rounded, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '当前“${_activeFilterLabel()}”分类暂无书籍',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
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

  Widget _buildFilterBar() {
    final colorScheme = Theme.of(context).colorScheme;
    final baseFilters = const <_BookshelfFilter>[
      _BookshelfFilter.all,
      _BookshelfFilter.local,
      _BookshelfFilter.novel,
      _BookshelfFilter.manga,
    ];
    final customTags = _userTags;

    return SizedBox(
      height: 38,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...baseFilters.map((filter) {
                  final selected = _activeFilter == filter;
                  final label = _filterLabel(filter);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: selected,
                      showCheckmark: false,
                      onSelected: (_) => _activateFilter(filter),
                      selectedColor: colorScheme.primaryContainer,
                      labelStyle: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(
                        color:
                            selected
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurfaceVariant,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  );
                }),
                ...customTags.map((tag) {
                  final selected =
                      _activeFilter == _BookshelfFilter.custom &&
                      _activeCustomTag == tag;
                  final label = '#$tag';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onLongPress:
                          _isBatchDeleting
                              ? null
                              : () => unawaited(_showTagManageSheet(tag)),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: selected,
                        showCheckmark: false,
                        onSelected:
                            (_) => _activateFilter(
                              _BookshelfFilter.custom,
                              customTag: tag,
                            ),
                        selectedColor: colorScheme.secondaryContainer,
                        labelStyle: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(
                          color:
                              selected
                                  ? colorScheme.onSecondaryContainer
                                  : colorScheme.onSurfaceVariant,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                        ),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: _useGridView ? '切换列表视图' : '切换网格视图',
            child: IconButton(
              onPressed: _isLoading ? null : _toggleBookshelfViewMode,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 38, height: 38),
              icon: Icon(
                _useGridView
                    ? Icons.view_list_rounded
                    : Icons.grid_view_rounded,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionActionBar({
    required List<BookshelfBook> filteredBooks,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _isBatchDeleting || filteredBooks.isEmpty
                          ? null
                          : _selectAllBooks,
                  icon: const Icon(Icons.select_all_rounded),
                  label: const Text('全选'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      _isBatchDeleting || _selectedBookKeys.isEmpty
                          ? null
                          : _deleteSelectedBooks,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('删除'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookGridSliver(List<BookshelfBook> books) {
    return BookshelfGridSliver(
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
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
    final latestChapterText = _toSingleLineText(
      _latestCachedChapterByBookId[book.bookId] ?? '',
    );
    final authorLine = authorText.isNotEmpty ? '作者: $authorText' : '作者: 未知';
    final latestLine =
        latestChapterText.isNotEmpty ? '最新: $latestChapterText' : '最新: 暂无缓存章节';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onLongPress:
            _isBatchDeleting
                ? null
                : () {
                  if (_isSelectionMode) {
                    _toggleBookSelection(book);
                    return;
                  }
                  unawaited(_showBookActionSheet(book));
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
                    if (!_isSelectionMode)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: _buildSourceBadge(book, compact: true),
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
              const SizedBox(height: 2),
              Text(
                authorLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                latestLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
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
    final latestChapterText = _toSingleLineText(
      _latestCachedChapterByBookId[book.bookId] ?? '',
    );
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
                    _isBatchDeleting
                        ? null
                        : () {
                          if (_isSelectionMode) {
                            _toggleBookSelection(book);
                            return;
                          }
                          unawaited(_showBookActionSheet(book));
                        },
                containedInkWell: true,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 58,
                  height: 84,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _buildCover(
                          book.coverUrl,
                          width: 58,
                          height: 84,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: _buildSourceBadge(book, compact: true),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress:
                      _isBatchDeleting
                          ? null
                          : () {
                            if (_isSelectionMode) {
                              _toggleBookSelection(book);
                              return;
                            }
                            unawaited(_showBookActionSheet(book));
                          },
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

  List<BookshelfBook> get _filteredBooks {
    return _books
        .where((book) => _bookMatchesFilter(book, _activeFilter))
        .toList(growable: false);
  }

  bool _bookMatchesFilter(BookshelfBook book, _BookshelfFilter filter) {
    switch (filter) {
      case _BookshelfFilter.all:
        return true;
      case _BookshelfFilter.local:
        return book.sourceId == _kLocalBookSourceId;
      case _BookshelfFilter.manga:
        return book.sourceId != _kLocalBookSourceId &&
            (_sourceTypeBySourceId[book.sourceId] ?? 0) == 2;
      case _BookshelfFilter.novel:
        return book.sourceId != _kLocalBookSourceId &&
            (_sourceTypeBySourceId[book.sourceId] ?? 0) != 2;
      case _BookshelfFilter.custom:
        final tag = _activeCustomTag;
        if (tag == null || tag.isEmpty) {
          return true;
        }
        return _tagsOfBook(book).contains(tag);
    }
  }

  List<String> get _userTags {
    final counts = <String, int>{};
    for (final book in _books) {
      for (final tag in _tagsOfBook(book)) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final tags = counts.keys.toList(growable: false);
    tags.sort((a, b) {
      final countCompare = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
      if (countCompare != 0) {
        return countCompare;
      }
      return a.compareTo(b);
    });
    return tags;
  }

  List<String> _tagsOfBook(BookshelfBook book) {
    return _bookTagsByKey[_bookKey(book)] ?? const <String>[];
  }

  String _filterLabel(_BookshelfFilter filter) {
    switch (filter) {
      case _BookshelfFilter.all:
        return '全部';
      case _BookshelfFilter.local:
        return '本地';
      case _BookshelfFilter.novel:
        return '小说';
      case _BookshelfFilter.manga:
        return '漫画';
      case _BookshelfFilter.custom:
        return _activeCustomTag ?? '标签';
    }
  }

  String _activeFilterLabel() {
    if (_activeFilter == _BookshelfFilter.custom) {
      final tag = _activeCustomTag;
      if (tag == null || tag.isEmpty) {
        return '标签';
      }
      return '#$tag';
    }
    return _filterLabel(_activeFilter);
  }

  void _activateFilter(_BookshelfFilter filter, {String? customTag}) {
    setState(() {
      _activeFilter = filter;
      _activeCustomTag = filter == _BookshelfFilter.custom ? customTag : null;
      if (_isSelectionMode) {
        _isSelectionMode = false;
        _selectedBookKeys.clear();
      }
    });
  }

  List<String> _normalizeTags(Iterable<String> values) {
    final result = <String>[];
    for (final raw in values) {
      var value = _toSingleLineText(raw);
      if (value.startsWith('#')) {
        value = value.substring(1).trim();
      }
      if (value.isEmpty) {
        continue;
      }
      if (value.length > 12) {
        value = value.substring(0, 12).trim();
      }
      if (value.isEmpty) {
        continue;
      }
      if (!result.contains(value)) {
        result.add(value);
      }
    }
    return result;
  }

  void _ensureFilterStillValid() {
    if (_activeFilter != _BookshelfFilter.custom) {
      return;
    }
    final tag = _activeCustomTag;
    if (tag == null || !_userTags.contains(tag)) {
      _activeFilter = _BookshelfFilter.all;
      _activeCustomTag = null;
      if (_isSelectionMode) {
        _isSelectionMode = false;
        _selectedBookKeys.clear();
      }
    }
  }

  void _startSelectionMode() {
    if (_isBatchDeleting || _filteredBooks.isEmpty) {
      return;
    }
    setState(() {
      _isSelectionMode = true;
      _selectedBookKeys.clear();
    });
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

  Future<void> _showBookActionSheet(BookshelfBook book) async {
    if (_isBatchDeleting || !mounted) {
      return;
    }
    final progress = _progressByBookId[book.bookId];
    final latestChapter = _toSingleLineText(
      _latestCachedChapterByBookId[book.bookId] ?? '',
    );
    final author = _toSingleLineText(book.author ?? '');
    final authorLine = author.isNotEmpty ? '作者: $author' : '作者: 未知';
    final latestLine =
        latestChapter.isNotEmpty ? '最新: $latestChapter' : '最新: 暂无缓存章节';
    final selected = await showModalBottomSheet<_BookshelfSheetAction>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        final horizontal = AppSpacing.pageHorizontal(sheetContext);
        final bottomInset = MediaQuery.viewPaddingOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            4,
            horizontal,
            10 + bottomInset,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 88),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCover(book.coverUrl, width: 56, height: 82),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _toSingleLineText(book.title),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                authorLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(
                                  sheetContext,
                                ).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                latestLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(
                                  sheetContext,
                                ).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap:
                            () => Navigator.of(
                              sheetContext,
                            ).pop(_BookshelfSheetAction.detail),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '书籍详情',
                                style: Theme.of(
                                  sheetContext,
                                ).textTheme.labelLarge?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _BookSheetActionButton(
                      icon: Icons.menu_book_rounded,
                      label: '继续阅读',
                      onTap:
                          () => Navigator.of(
                            sheetContext,
                          ).pop(_BookshelfSheetAction.read),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BookSheetActionButton(
                      icon: Icons.bookmark_add_outlined,
                      label: '添加标签',
                      onTap:
                          () => Navigator.of(
                            sheetContext,
                          ).pop(_BookshelfSheetAction.tag),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BookSheetActionButton(
                      icon: Icons.checklist_rounded,
                      label: '批量管理',
                      onTap:
                          () => Navigator.of(
                            sheetContext,
                          ).pop(_BookshelfSheetAction.select),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BookSheetActionButton(
                      icon: Icons.delete_outline_rounded,
                      label: '删除',
                      onTap:
                          () => Navigator.of(
                            sheetContext,
                          ).pop(_BookshelfSheetAction.delete),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('取消'),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || selected == null) {
      return;
    }
    switch (selected) {
      case _BookshelfSheetAction.read:
        await _openFromBookshelf(book, progress: progress);
        break;
      case _BookshelfSheetAction.detail:
        _openBookDetail(book);
        break;
      case _BookshelfSheetAction.select:
        _enterSelectionMode(book);
        break;
      case _BookshelfSheetAction.tag:
        await _showBookTagSheet(book);
        break;
      case _BookshelfSheetAction.delete:
        await _confirmAndRemoveBook(book);
        break;
    }
  }

  Future<void> _showBookTagSheet(BookshelfBook book) async {
    final bookKey = _bookKey(book);
    final initialSelected = List<String>.from(
      _bookTagsByKey[bookKey] ?? const <String>[],
    );
    final allTags = List<String>.from(_userTags);
    final selectedTags = List<String>.from(initialSelected);

    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final horizontal = AppSpacing.pageHorizontal(sheetContext);
        final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                4,
                horizontal,
                12 + bottomInset,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '设置标签',
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _toSingleLineText(book.title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                      color:
                          Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...allTags.map((tag) {
                        return FilterChip(
                          label: Text(tag),
                          selected: selectedTags.contains(tag),
                          onSelected: (enabled) {
                            setModalState(() {
                              if (enabled) {
                                if (!selectedTags.contains(tag)) {
                                  selectedTags.add(tag);
                                }
                              } else {
                                selectedTags.remove(tag);
                              }
                            });
                          },
                        );
                      }),
                      ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('新增标签'),
                        onPressed: () async {
                          final created = await _showCreateTagDialog(
                            sheetContext,
                            existingTags: <String>{...allTags, ...selectedTags},
                          );
                          if (created == null || !mounted) {
                            return;
                          }
                          setModalState(() {
                            if (!allTags.contains(created)) {
                              allTags.add(created);
                            }
                            if (!selectedTags.contains(created)) {
                              selectedTags.add(created);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed:
                              () => Navigator.of(
                                sheetContext,
                              ).pop(_normalizeTags(selectedTags)),
                          child: const Text('保存'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    final normalized = _normalizeTags(selected);
    final previous = _bookTagsByKey[bookKey] ?? const <String>[];
    final unchanged =
        previous.length == normalized.length &&
        previous.every((tag) => normalized.contains(tag));
    if (unchanged) {
      return;
    }

    try {
      await _bookshelfService.setBookTags(
        sourceId: book.sourceId,
        detailUrl: book.detailUrl,
        tags: normalized,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        final next = Map<String, List<String>>.from(_bookTagsByKey);
        if (normalized.isEmpty) {
          next.remove(bookKey);
        } else {
          next[bookKey] = normalized;
        }
        _bookTagsByKey = next;
        _ensureFilterStillValid();
      });
      _showMessage(normalized.isEmpty ? '已清除标签。' : '标签已保存。');
    } catch (_) {
      _showMessage('标签保存失败，请重试。');
    }
  }

  Future<void> _showTagManageSheet(String tag) async {
    if (_isSelectionMode || _isBatchDeleting || !mounted) {
      return;
    }

    final selected = await showModalBottomSheet<_TagManageSheetAction>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('重命名标签'),
              subtitle: Text('#$tag'),
              onTap:
                  () => Navigator.of(
                    sheetContext,
                  ).pop(_TagManageSheetAction.rename),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(sheetContext).colorScheme.error,
              ),
              title: Text(
                '删除标签',
                style: TextStyle(
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
              ),
              subtitle: Text('#$tag'),
              onTap:
                  () => Navigator.of(
                    sheetContext,
                  ).pop(_TagManageSheetAction.delete),
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    );
    if (!mounted || selected == null) {
      return;
    }

    switch (selected) {
      case _TagManageSheetAction.rename:
        await _renameTag(tag);
        break;
      case _TagManageSheetAction.delete:
        await _deleteTag(tag);
        break;
    }
  }

  Future<void> _renameTag(String tag) async {
    final nextTag = await _showRenameTagDialog(
      context,
      initialTag: tag,
      existingTags: _userTags.toSet(),
    );
    if (!mounted || nextTag == null || nextTag == tag) {
      return;
    }

    try {
      final affectedCount = await _bookshelfService.renameTag(
        fromTag: tag,
        toTag: nextTag,
      );
      if (!mounted) {
        return;
      }
      if (affectedCount <= 0) {
        _showMessage('未找到可重命名的标签。');
        return;
      }

      setState(() {
        final nextMap = <String, List<String>>{};
        for (final entry in _bookTagsByKey.entries) {
          final tags = _normalizeTags(
            entry.value.map((value) => value == tag ? nextTag : value),
          );
          if (tags.isNotEmpty) {
            nextMap[entry.key] = tags;
          }
        }
        _bookTagsByKey = nextMap;
        if (_activeFilter == _BookshelfFilter.custom &&
            _activeCustomTag == tag) {
          _activeCustomTag = nextTag;
        }
        _ensureFilterStillValid();
      });
      _showMessage('标签已重命名为 #$nextTag。');
    } catch (_) {
      _showMessage('重命名失败，请重试。');
    }
  }

  Future<void> _deleteTag(String tag) async {
    final bindCount =
        _bookTagsByKey.values.where((tags) => tags.contains(tag)).length;
    final confirmed = await _showConfirmDialog(
      title: '删除标签',
      content:
          bindCount > 0
              ? '确定删除标签 #$tag 吗？会从 $bindCount 本书中移除。'
              : '确定删除标签 #$tag 吗？',
      confirmText: '删除',
    );
    if (!mounted || confirmed != true) {
      return;
    }

    try {
      final affectedCount = await _bookshelfService.deleteTag(tag);
      if (!mounted) {
        return;
      }
      if (affectedCount <= 0) {
        _showMessage('标签已不存在。');
        return;
      }

      setState(() {
        final nextMap = <String, List<String>>{};
        for (final entry in _bookTagsByKey.entries) {
          final tags = entry.value
              .where((value) => value != tag)
              .toList(growable: false);
          if (tags.isNotEmpty) {
            nextMap[entry.key] = tags;
          }
        }
        _bookTagsByKey = nextMap;
        _ensureFilterStillValid();
      });
      _showMessage('已删除标签 #$tag。');
    } catch (_) {
      _showMessage('删除标签失败，请重试。');
    }
  }

  Future<String?> _showCreateTagDialog(
    BuildContext dialogContext, {
    required Set<String> existingTags,
  }) {
    return _showTagNameDialog(
      dialogContext,
      title: '新增标签',
      confirmText: '创建',
      hintText: '例如：在读 / 已完结',
      existingTags: existingTags,
    );
  }

  Future<String?> _showRenameTagDialog(
    BuildContext dialogContext, {
    required String initialTag,
    required Set<String> existingTags,
  }) {
    return _showTagNameDialog(
      dialogContext,
      title: '重命名标签',
      confirmText: '保存',
      hintText: '输入新的标签名称',
      initialValue: initialTag,
      existingTags: existingTags,
      originalTag: initialTag,
    );
  }

  Future<String?> _showTagNameDialog(
    BuildContext dialogContext, {
    required String title,
    required String confirmText,
    required String hintText,
    required Set<String> existingTags,
    String initialValue = '',
    String? originalTag,
  }) async {
    final controller = TextEditingController(text: initialValue);
    String? errorText;

    final result = await showDialog<String>(
      context: dialogContext,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String? validate() {
              final value = _normalizeTags([controller.text]);
              if (value.isEmpty) {
                return '请输入标签名称';
              }
              final tag = value.first;
              if (originalTag != null && tag == originalTag) {
                return null;
              }
              if (originalTag == null && existingTags.contains(tag)) {
                return '该标签已存在';
              }
              return null;
            }

            void submit() {
              final validation = validate();
              if (validation != null) {
                setDialogState(() {
                  errorText = validation;
                });
                return;
              }
              final tag = _normalizeTags([controller.text]).first;
              Navigator.of(context).pop(tag);
            }

            return AlertDialog(
              title: Text(title),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLength: 12,
                decoration: InputDecoration(
                  hintText: hintText,
                  errorText: errorText,
                ),
                onSubmitted: (_) => submit(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(onPressed: submit, child: Text(confirmText)),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _confirmAndRemoveBook(BookshelfBook book) async {
    final confirmed = await _showConfirmDialog(
      title: '删除书籍',
      content: '确定从书架删除《${_toSingleLineText(book.title)}》吗？该操作不可撤销。',
      confirmText: '删除',
    );
    if (!mounted || confirmed != true) {
      return;
    }
    try {
      await _removeBook(book);
    } on AppException catch (error) {
      _showMessage(error.briefMessage);
    } catch (_) {
      _showMessage('删除失败，请稍后重试。');
    }
  }

  void _selectAllBooks() {
    final visibleBooks = _filteredBooks;
    if (visibleBooks.isEmpty || _isBatchDeleting) {
      return;
    }

    setState(() {
      _isSelectionMode = true;
      _selectedBookKeys
        ..clear()
        ..addAll(visibleBooks.map(_bookKey));
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

    final visibleBooks = _filteredBooks;
    final validKeys = visibleBooks.map(_bookKey).toSet();
    final nextSelected =
        _selectedBookKeys.where((key) => validKeys.contains(key)).toSet();

    final changed =
        nextSelected.length != _selectedBookKeys.length ||
        (visibleBooks.isEmpty && _isSelectionMode);

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

  Widget _buildSourceBadge(BookshelfBook book, {bool compact = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLocal = book.sourceId == _kLocalBookSourceId;
    final label = isLocal ? '本地' : '在线';
    final background =
        isLocal
            ? colorScheme.secondaryContainer.withValues(alpha: 0.94)
            : colorScheme.primaryContainer.withValues(alpha: 0.94);
    final foreground =
        isLocal
            ? colorScheme.onSecondaryContainer
            : colorScheme.onPrimaryContainer;
    final borderRadius = compact ? 6.0 : 7.0;
    final horizontalPadding = compact ? 8.0 : 10.0;
    final minWidth = compact ? 30.0 : 36.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: compact ? 1.5 : 2,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 9.5 : 10.5,
              height: 1.1,
            ),
          ),
        ),
      ),
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
      final sourceTypeMap = await _loadSourceTypeMap();
      final rawTagMap = await _bookshelfService.getTagMap();
      final validBookKeys = books.map(_bookKey).toSet();
      final tagMap = <String, List<String>>{};
      for (final entry in rawTagMap.entries) {
        if (!validBookKeys.contains(entry.key)) {
          continue;
        }
        final tags = _normalizeTags(entry.value);
        if (tags.isEmpty) {
          continue;
        }
        tagMap[entry.key] = tags;
      }

      if (!mounted || ticket != _loadTicket) {
        return;
      }

      setState(() {
        _books = books;
        _sourceTypeBySourceId = sourceTypeMap;
        _bookTagsByKey = tagMap;
        _progressByBookId = const <String, ReadingProgress>{};
        _latestCachedChapterByBookId = const <String, String>{};
        _isLoading = false;
        _ensureFilterStillValid();
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

  Future<void> _restoreViewModePreference() async {
    final useGrid = await _bookshelfService.loadUseGridView();
    if (!mounted || _useGridView == useGrid) {
      return;
    }
    setState(() {
      _useGridView = useGrid;
    });
  }

  void _toggleBookshelfViewMode() {
    final next = !_useGridView;
    setState(() {
      _useGridView = next;
    });
    unawaited(_bookshelfService.saveUseGridView(next));
  }

  Future<Map<String, int>> _loadSourceTypeMap() async {
    try {
      final sources = await AppDatabase.instance.getAllSources().timeout(
        _kSourceMapLoadTimeout,
      );
      final map = <String, int>{};
      for (final source in sources) {
        final sourceId = source.id.trim();
        if (sourceId.isEmpty) {
          continue;
        }
        map[sourceId] = source.sourceType;
      }
      return map;
    } catch (_) {
      return const <String, int>{};
    }
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

class _BookSheetActionButton extends StatelessWidget {
  const _BookSheetActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fg = colorScheme.onSurface;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: fg),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
