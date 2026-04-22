import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/resolved_book_cover.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/repositories/bookmark_repository_impl.dart';
import '../../../domain/entities/bookmark.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/repositories/bookmark_repository.dart';
import '../../bookshelf/application/bookshelf_service.dart';
import '../application/advanced_theme_provider.dart';
import '../application/cover_gallery_provider.dart';
import '../../reader/application/reader_entry_route_resolver.dart';

class BookmarksPage extends ConsumerStatefulWidget {
  const BookmarksPage({super.key});

  @override
  ConsumerState<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends ConsumerState<BookmarksPage> {
  final BookmarkRepository _bookmarkRepository = BookmarkRepositoryImpl(
    AppDatabase.instance,
  );
  final BookshelfService _bookshelfService = BookshelfService();
  final ReaderEntryRouteResolver _readerEntryRouteResolver =
      const ReaderEntryRouteResolver();

  bool _isLoading = true;
  String? _errorText;
  List<Bookmark> _bookmarks = const [];
  Map<String, BookshelfBook> _bookshelfIndex = const <String, BookshelfBook>{};

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final bookmarksFuture = _bookmarkRepository.listAllBookmarks();
      final booksFuture = _bookshelfService.getAll();
      final bookmarks = await bookmarksFuture;
      final books = await booksFuture;
      final index = <String, BookshelfBook>{
        for (final book in books) book.bookId: book,
      };
      if (!mounted) {
        return;
      }
      setState(() {
        _bookmarks = bookmarks;
        _bookshelfIndex = index;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '灵感加载失败，请稍后重试。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
          title: const Text('灵感'),
        ),
        body: LayoutBuilder(
          builder: (context, _) {
            final maxWidth = AppLayout.pageContentMaxWidth(
              context,
              maxWidth: AppLayout.mineContentMaxWidth,
            );

            return DecoratedBox(
              decoration: buildAdvancedThemeBackdropDecoration(backdrop),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: _buildBody(
                    context,
                    horizontal: horizontal,
                    topInset: topInset,
                    bottomSafe: bottomSafe,
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

  Widget _buildBody(
    BuildContext context, {
    required double horizontal,
    required double topInset,
    required double bottomSafe,
  }) {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomSafe),
          child: const CircularProgressIndicator(),
        ),
      );
    }

    final errorText = _errorText;
    if (errorText != null && errorText.isNotEmpty) {
      return _buildStatusBody(
        context,
        horizontal: horizontal,
        topInset: topInset,
        bottomSafe: bottomSafe,
        title: '加载失败',
        message: errorText,
        actionLabel: '重试',
        onAction: () => unawaited(_reload()),
      );
    }

    final groups = _buildBookGroups();
    if (groups.isEmpty) {
      return _buildStatusBody(
        context,
        horizontal: horizontal,
        topInset: topInset,
        bottomSafe: bottomSafe,
        title: '还没有灵感',
        message: '在阅读页选中文本后点击“保存灵感”即可添加。',
        actionLabel: '刷新',
        onAction: () => unawaited(_reload()),
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          horizontal,
          topInset + 12,
          horizontal,
          12 + bottomSafe,
        ),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildBookGroupCard(context, groups[index]);
        },
      ),
    );
  }

  Widget _buildStatusBody(
    BuildContext context, {
    required double horizontal,
    required double topInset,
    required double bottomSafe,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          horizontal,
          topInset + 48,
          horizontal,
          24 + bottomSafe,
        ),
        children: [
          Icon(Icons.bookmarks_outlined, size: 48, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.tonal(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookGroupCard(BuildContext context, _BookmarkBookGroup group) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final book = group.book;
    final rawTitle = (book?.title ?? '').trim();
    final title = rawTitle.isNotEmpty ? rawTitle : '未知书籍';
    final rawAuthor = (book?.author ?? '').trim();
    final author =
        rawAuthor.isNotEmpty ? rawAuthor : (book == null ? '书籍已从书架移除' : '作者未知');

    final subtitle =
        '共 ${group.bookmarks.length} 条 · 最近 ${_formatTime(group.latestTime)}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCover(
                  realCoverUrl: book?.coverUrl,
                  title: title,
                  author: rawAuthor,
                  bookId: book?.bookId,
                  sourceId: book?.sourceId,
                  detailUrl: book?.detailUrl,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        author,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._buildChapterSections(context, group),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildChapterSections(
    BuildContext context,
    _BookmarkBookGroup group,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final chapters = _groupBookmarksByChapter(group.bookmarks);
    final widgets = <Widget>[];

    for (var index = 0; index < chapters.length; index += 1) {
      final chapter = chapters[index];
      widgets.add(
        Text(
          chapter.title,
          style: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.primary,
          ),
        ),
      );
      widgets.add(const SizedBox(height: 6));
      for (final bookmark in chapter.bookmarks) {
        widgets.add(_buildBookmarkItem(context, bookmark, group.book));
      }
      if (index != chapters.length - 1) {
        widgets.add(const Divider(height: 18));
      }
    }
    return widgets;
  }

  Widget _buildBookmarkItem(
    BuildContext context,
    Bookmark bookmark,
    BookshelfBook? book,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final snippet = _compactSnippet(bookmark.snippet);
    final canOpen = _canOpenBookmark(book);
    final timeLabel = _formatTime(bookmark.updatedAt);
    final subtitle = canOpen ? timeLabel : '$timeLabel · 书籍已移除，无法定位';

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        snippet.isEmpty ? '（空灵感）' : snippet,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodyMedium,
      ),
      subtitle: Text(
        subtitle,
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: IconButton(
        tooltip: '删除灵感',
        icon: const Icon(Icons.delete_outline_rounded),
        onPressed: () => unawaited(_deleteBookmark(bookmark)),
      ),
      onTap: () => _openBookmark(bookmark, book),
    );
  }

  Widget _buildCover({
    String? realCoverUrl,
    String? title,
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
      title: title ?? '',
      author: author,
      width: 54,
      height: 74,
      borderRadius: BorderRadius.circular(10),
    );
  }

  List<_BookmarkBookGroup> _buildBookGroups() {
    if (_bookmarks.isEmpty) {
      return const <_BookmarkBookGroup>[];
    }

    final map = <String, List<Bookmark>>{};
    for (final bookmark in _bookmarks) {
      map.putIfAbsent(bookmark.bookId, () => <Bookmark>[]).add(bookmark);
    }

    final groups = <_BookmarkBookGroup>[];
    for (final entry in map.entries) {
      final items = entry.value.toList(growable: false);
      final latest = _latestTime(items);
      groups.add(
        _BookmarkBookGroup(
          bookId: entry.key,
          book: _bookshelfIndex[entry.key],
          bookmarks: items,
          latestTime: latest,
        ),
      );
    }

    groups.sort((a, b) => b.latestTime.compareTo(a.latestTime));
    return groups;
  }

  List<_BookmarkChapterGroup> _groupBookmarksByChapter(
    List<Bookmark> bookmarks,
  ) {
    if (bookmarks.isEmpty) {
      return const <_BookmarkChapterGroup>[];
    }

    final sorted = [...bookmarks]..sort((a, b) {
      final indexCompare = a.chapterIndex.compareTo(b.chapterIndex);
      if (indexCompare != 0) {
        return indexCompare;
      }
      final offsetCompare = a.startOffset.compareTo(b.startOffset);
      if (offsetCompare != 0) {
        return offsetCompare;
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });

    final groups = <_BookmarkChapterGroup>[];
    for (final bookmark in sorted) {
      final key = _chapterKey(bookmark);
      final title = _chapterTitle(bookmark);
      final existing =
          groups.isNotEmpty && groups.last.key == key ? groups.last : null;
      if (existing != null) {
        existing.bookmarks.add(bookmark);
      } else {
        groups.add(
          _BookmarkChapterGroup(key: key, title: title, bookmarks: [bookmark]),
        );
      }
    }
    return groups;
  }

  String _chapterKey(Bookmark bookmark) {
    final index = bookmark.chapterIndex;
    if (index >= 0) {
      return 'index:$index';
    }
    final id = bookmark.chapterId.trim();
    if (id.isNotEmpty) {
      return 'id:$id';
    }
    return 'unknown';
  }

  String _chapterTitle(Bookmark bookmark) {
    final index = bookmark.chapterIndex;
    if (index >= 0) {
      return '第 ${index + 1} 章';
    }
    final chapterId = bookmark.chapterId.trim();
    if (chapterId.isNotEmpty) {
      return '章节 $chapterId';
    }
    return '未知章节';
  }

  DateTime _latestTime(List<Bookmark> bookmarks) {
    var latest = bookmarks.first.updatedAt;
    for (final bookmark in bookmarks.skip(1)) {
      if (bookmark.updatedAt.isAfter(latest)) {
        latest = bookmark.updatedAt;
      }
    }
    return latest;
  }

  String _compactSnippet(String snippet) {
    return snippet.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _formatTime(DateTime time) {
    final year = time.year.toString().padLeft(4, '0');
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  bool _canOpenBookmark(BookshelfBook? book) {
    if (book == null) {
      return false;
    }
    return book.sourceId.trim().isNotEmpty && book.detailUrl.trim().isNotEmpty;
  }

  void _openBookmark(Bookmark bookmark, BookshelfBook? book) {
    if (!_canOpenBookmark(book)) {
      _showMessage('书籍已移出书架，暂无法定位灵感。');
      return;
    }

    context.push(
      _readerEntryRouteResolver.buildRouteFromBookmark(
        bookmark: bookmark,
        sourceId: book!.sourceId,
        detailUrl: book.detailUrl,
      ),
    );
  }

  Future<void> _deleteBookmark(Bookmark bookmark) async {
    try {
      await _bookmarkRepository.removeBookmark(bookmark.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _bookmarks = _bookmarks
            .where((item) => item.id != bookmark.id)
            .toList(growable: false);
      });
      _showMessage('已删除灵感。');
    } catch (_) {
      _showMessage('删除失败，请稍后重试。');
    }
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _BookmarkBookGroup {
  const _BookmarkBookGroup({
    required this.bookId,
    required this.book,
    required this.bookmarks,
    required this.latestTime,
  });

  final String bookId;
  final BookshelfBook? book;
  final List<Bookmark> bookmarks;
  final DateTime latestTime;
}

class _BookmarkChapterGroup {
  _BookmarkChapterGroup({
    required this.key,
    required this.title,
    required List<Bookmark> bookmarks,
  }) : bookmarks = List<Bookmark>.from(bookmarks);

  final String key;
  final String title;
  final List<Bookmark> bookmarks;
}
