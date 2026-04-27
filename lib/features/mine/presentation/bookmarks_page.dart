import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/resolved_book_cover.dart';
import '../../../domain/entities/bookmark.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/repositories/bookmark_repository.dart';
import '../../reader/application/reader_entry_route_resolver.dart';
import '../application/advanced_theme_provider.dart';
import '../application/bookmarks_query_service.dart';
import '../application/cover_gallery_provider.dart';
import '../providers.dart';

class BookmarksPage extends ConsumerStatefulWidget {
  const BookmarksPage({super.key});

  @override
  ConsumerState<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends ConsumerState<BookmarksPage> {
  static const Duration _loadTimeout = Duration(seconds: 8);
  late final BookmarksQueryService _bookmarksQueryService;
  late final BookmarkRepository _bookmarkRepository;
  final ReaderEntryRouteResolver _readerEntryRouteResolver =
      const ReaderEntryRouteResolver();

  bool _isLoading = true;
  String? _errorText;
  List<Bookmark> _bookmarks = const [];
  Map<String, BookshelfBook> _bookshelfIndex = const <String, BookshelfBook>{};

  @override
  void initState() {
    super.initState();
    _bookmarksQueryService = ref.read(bookmarksQueryServiceProvider);
    _bookmarkRepository = ref.read(mineBookmarkRepositoryProvider);
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
      final data = await _bookmarksQueryService.loadPageData(
        timeout: _loadTimeout,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _bookmarks = data.bookmarks;
        _bookshelfIndex = data.bookshelfIndex;
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
        itemCount: groups.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildOverviewCard(context, groups);
          }
          return _buildBookGroupCard(context, groups[index - 1]);
        },
      ),
    );
  }

  Widget _buildOverviewCard(
    BuildContext context,
    List<_BookmarkBookGroup> groups,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalBookmarks = groups.fold<int>(
      0,
      (sum, group) => sum + group.bookmarks.length,
    );
    final booksWithNotes =
        groups
            .where((group) => group.bookmarks.any((item) => item.hasNote))
            .length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.auto_awesome_outlined,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '灵感书单',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '共 ${groups.length} 本书，累计 $totalBookmarks 条灵感，$booksWithNotes 本书包含笔记。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    final title = _resolvedTitle(book, fallbackBookmarks: group.bookmarks);
    final author = _resolvedAuthor(book, fallbackBookmarks: group.bookmarks);
    final noteCount = group.bookmarks.where((item) => item.hasNote).length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openBookGroup(group),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              _buildCover(
                realCoverUrl: book?.coverUrl,
                title: title,
                author: author,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTag(context, '${group.bookmarks.length} 条灵感'),
                        if (noteCount > 0) _buildTag(context, '$noteCount 条笔记'),
                        _buildTag(
                          context,
                          '最近 ${_formatTime(group.latestTime)}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(BuildContext context, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _openBookGroup(_BookmarkBookGroup group) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => _BookmarkBookDetailPage(
              group: group,
              buildCover: _buildCover,
              canOpenBookmark: _canOpenBookmark,
              openBookmark: _openBookmark,
              deleteBookmark: _deleteBookmark,
              formatTime: _formatTime,
              resolvedTitle: _resolvedTitle,
              resolvedAuthor: _resolvedAuthor,
            ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
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

  DateTime _latestTime(List<Bookmark> bookmarks) {
    var latest = bookmarks.first.updatedAt;
    for (final bookmark in bookmarks.skip(1)) {
      if (bookmark.updatedAt.isAfter(latest)) {
        latest = bookmark.updatedAt;
      }
    }
    return latest;
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

  Future<bool> _deleteBookmark(Bookmark bookmark) async {
    try {
      await _bookmarkRepository.removeBookmark(bookmark.id);
      if (!mounted) {
        return false;
      }
      setState(() {
        _bookmarks = _bookmarks
            .where((item) => item.id != bookmark.id)
            .toList(growable: false);
      });
      _showMessage('已删除灵感。');
      return true;
    } catch (_) {
      _showMessage('删除失败，请稍后重试。');
      return false;
    }
  }

  String _resolvedTitle(
    BookshelfBook? book, {
    required List<Bookmark> fallbackBookmarks,
  }) {
    final rawTitle = (book?.title ?? '').trim();
    if (rawTitle.isNotEmpty) {
      return rawTitle;
    }
    final fallback = fallbackBookmarks.firstOrNull?.displaySnippet ?? '';
    return fallback.isEmpty ? '未知书籍' : '已移除书籍';
  }

  String _resolvedAuthor(
    BookshelfBook? book, {
    required List<Bookmark> fallbackBookmarks,
  }) {
    final rawAuthor = (book?.author ?? '').trim();
    if (rawAuthor.isNotEmpty) {
      return rawAuthor;
    }
    return book == null ? '书籍已从书架移除' : '作者未知';
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _BookmarkBookDetailPage extends StatefulWidget {
  const _BookmarkBookDetailPage({
    required this.group,
    required this.buildCover,
    required this.canOpenBookmark,
    required this.openBookmark,
    required this.deleteBookmark,
    required this.formatTime,
    required this.resolvedTitle,
    required this.resolvedAuthor,
  });

  final _BookmarkBookGroup group;
  final Widget Function({
    String? realCoverUrl,
    String? title,
    String? author,
    String? bookId,
    String? sourceId,
    String? detailUrl,
  })
  buildCover;
  final bool Function(BookshelfBook? book) canOpenBookmark;
  final void Function(Bookmark bookmark, BookshelfBook? book) openBookmark;
  final Future<bool> Function(Bookmark bookmark) deleteBookmark;
  final String Function(DateTime time) formatTime;
  final String Function(
    BookshelfBook? book, {
    required List<Bookmark> fallbackBookmarks,
  })
  resolvedTitle;
  final String Function(
    BookshelfBook? book, {
    required List<Bookmark> fallbackBookmarks,
  })
  resolvedAuthor;

  @override
  State<_BookmarkBookDetailPage> createState() =>
      _BookmarkBookDetailPageState();
}

class _BookmarkBookDetailPageState extends State<_BookmarkBookDetailPage> {
  late List<Bookmark> _bookmarks;

  @override
  void initState() {
    super.initState();
    _bookmarks = List<Bookmark>.from(widget.group.bookmarks);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final book = widget.group.book;
    final title = widget.resolvedTitle(book, fallbackBookmarks: _bookmarks);
    final author = widget.resolvedAuthor(book, fallbackBookmarks: _bookmarks);
    final chapters = _groupBookmarksByChapter(_bookmarks);

    return Scaffold(
      appBar: AppBar(title: const Text('灵感详情')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  widget.buildCover(
                    realCoverUrl: book?.coverUrl,
                    title: title,
                    author: author,
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          author,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _DetailTag(text: '${_bookmarks.length} 条灵感'),
                            _DetailTag(
                              text:
                                  '${_bookmarks.where((item) => item.hasNote).length} 条笔记',
                            ),
                            _DetailTag(
                              text: widget.formatTime(widget.group.latestTime),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_bookmarks.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: Text(
                  '这本书的灵感已经删空了。',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ...chapters.map(
              (chapter) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chapter.title,
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...chapter.bookmarks.map(
                          (bookmark) => _BookmarkDetailItem(
                            bookmark: bookmark,
                            subtitle:
                                widget.canOpenBookmark(book)
                                    ? widget.formatTime(bookmark.updatedAt)
                                    : '${widget.formatTime(bookmark.updatedAt)} · 书籍已移除，无法定位',
                            onTap: () => widget.openBookmark(bookmark, book),
                            onDelete: () async {
                              final navigator = Navigator.of(context);
                              final deleted = await widget.deleteBookmark(
                                bookmark,
                              );
                              if (!deleted || !mounted) {
                                return;
                              }
                              setState(() {
                                _bookmarks.removeWhere(
                                  (item) => item.id == bookmark.id,
                                );
                              });
                              if (_bookmarks.isEmpty) {
                                navigator.pop();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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
      return a.startOffset.compareTo(b.startOffset);
    });

    final groups = <_BookmarkChapterGroup>[];
    for (final bookmark in sorted) {
      final key =
          bookmark.chapterIndex >= 0
              ? 'index:${bookmark.chapterIndex}'
              : 'id:${bookmark.chapterId}';
      final title =
          bookmark.chapterIndex >= 0
              ? '第 ${bookmark.chapterIndex + 1} 章'
              : '章节 ${bookmark.chapterId}';
      final current =
          groups.isNotEmpty && groups.last.key == key ? groups.last : null;
      if (current != null) {
        current.bookmarks.add(bookmark);
      } else {
        groups.add(
          _BookmarkChapterGroup(key: key, title: title, bookmarks: [bookmark]),
        );
      }
    }
    return groups;
  }
}

class _BookmarkDetailItem extends StatelessWidget {
  const _BookmarkDetailItem({
    required this.bookmark,
    required this.subtitle,
    required this.onTap,
    required this.onDelete,
  });

  final Bookmark bookmark;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        bookmark.displaySnippet.isEmpty ? '（空灵感）' : bookmark.displaySnippet,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bookmark.hasNote)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                bookmark.note!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      trailing: IconButton(
        tooltip: '删除灵感',
        icon: const Icon(Icons.delete_outline_rounded),
        onPressed: onDelete,
      ),
      onTap: onTap,
    );
  }
}

class _DetailTag extends StatelessWidget {
  const _DetailTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
