import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../app/widgets/app_empty_state_card.dart';
import '../../../app/widgets/app_status_state_card.dart';
import '../../../app/widgets/resolved_book_cover.dart';
import '../../../domain/entities/bookmark.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/repositories/bookmark_repository.dart';
import '../../reader/application/reader_entry_route_resolver.dart';
import '../../reader/application/local/local_reader_entry_guard_service.dart';
import '../../reader/application/local/local_reader_identity.dart';
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
  late final LocalReaderEntryGuardService _localReaderEntryGuardService;
  final ReaderEntryRouteResolver _readerEntryRouteResolver =
      const ReaderEntryRouteResolver();

  String? _errorText;
  int _selectedGroupIndex = 0;
  List<Bookmark> _bookmarks = const [];
  Map<String, BookshelfBook> _bookshelfIndex = const <String, BookshelfBook>{};
  List<BookmarkBookGroupData> _groups = const <BookmarkBookGroupData>[];
  bool _isSelectionMode = false;
  final Set<String> _selectedBookmarkIds = <String>{};

  @override
  void initState() {
    super.initState();
    _bookmarksQueryService = ref.read(bookmarksQueryServiceProvider);
    _bookmarkRepository = ref.read(mineBookmarkRepositoryProvider);
    _localReaderEntryGuardService = ref.read(
      bookmarksLocalReaderEntryGuardServiceProvider,
    );
    unawaited(_reload());
  }

  Future<void> _reload() async {
    if (!mounted) {
      return;
    }
    setState(() {
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
        _groups = data.groups;
        _isSelectionMode = false;
        _selectedBookmarkIds.clear();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '灵感加载失败，请稍后重试。';
      });
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
    final metrics = AppAdaptiveMetrics.of(context);
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
          title: Text(_isSelectionMode ? '选择灵感' : '灵感笔记'),
          actions: [
            if (!_isSelectionMode && _groups.isNotEmpty)
              IconButton(
                tooltip: '编辑',
                onPressed: () => setState(() => _isSelectionMode = true),
                icon: const Icon(Icons.edit_outlined),
              ),
            if (_isSelectionMode) ...[
              TextButton(
                onPressed:
                    _selectedBookmarkIds.isEmpty
                        ? null
                        : _deleteSelectedBookmarks,
                child: Text(
                  '删除${_selectedBookmarkIds.isEmpty ? '' : ' (${_selectedBookmarkIds.length})'}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              TextButton(
                onPressed:
                    () => setState(() {
                      _isSelectionMode = false;
                      _selectedBookmarkIds.clear();
                    }),
                child: const Text('取消'),
              ),
            ],
          ],
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
                  child:
                      metrics.isMediumUpWindow
                          ? _buildDesktopBody(
                            context,
                            horizontal: horizontal,
                            topInset: topInset,
                            bottomSafe: bottomSafe,
                          )
                          : _buildBody(
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

  Future<void> _deleteSelectedBookmarks() async {
    final confirmed = await showBookmarkDeleteConfirmSurface(
      context: context,
      title: '确认删除',
      message: '确定要删除选中的 ${_selectedBookmarkIds.length} 条灵感吗？',
    );

    if (confirmed != true) return;

    setState(() {
      _isSelectionMode = false;
    });

    try {
      for (final id in _selectedBookmarkIds) {
        await _bookmarkRepository.removeBookmark(id);
      }
      await _reload();
      if (mounted) {
        _showMessage('已删除 ${_selectedBookmarkIds.length} 条灵感。');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('删除失败，请稍后重试。');
      }
    }
  }

  Widget _buildBody(
    BuildContext context, {
    required double horizontal,
    required double topInset,
    required double bottomSafe,
  }) {
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

    final groups = _groups;
    if (groups.isEmpty) {
      return _buildEmptyState(
        context,
        horizontal: horizontal,
        topInset: topInset,
        bottomSafe: bottomSafe,
      );
    }

    final totalBooks = groups.length;
    final totalBookmarks = groups.fold<int>(
      0,
      (sum, group) => sum + group.bookmarks.length,
    );
    final booksWithNotes =
        groups
            .where((group) => group.bookmarks.any((item) => item.hasNote))
            .length;

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          horizontal,
          topInset + 12,
          horizontal,
          12 + bottomSafe,
        ),
        children: [
          // 精简版统计卡片
          _buildStatsCard(
            context,
            totalBooks: totalBooks,
            totalBookmarks: totalBookmarks,
            booksWithNotes: booksWithNotes,
          ),
          const SizedBox(height: 12),
          ...groups.map((group) => _buildBookGroupCard(context, group)),
        ],
      ),
    );
  }

  Widget _buildStatsCard(
    BuildContext context, {
    required int totalBooks,
    required int totalBookmarks,
    required int booksWithNotes,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatItem(
              icon: Icons.menu_book_outlined,
              value: '$totalBooks',
              label: '本书',
              color: colorScheme.primary,
            ),
            Container(
              width: 1,
              height: 30,
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            _StatItem(
              icon: Icons.auto_awesome_outlined,
              value: '$totalBookmarks',
              label: '灵感',
              color: colorScheme.primary,
            ),
            Container(
              width: 1,
              height: 30,
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            _StatItem(
              icon: Icons.edit_note_outlined,
              value: '$booksWithNotes',
              label: '含笔记',
              color: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required double horizontal,
    required double topInset,
    required double bottomSafe,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        horizontal,
        topInset + 48,
        horizontal,
        24 + bottomSafe,
      ),
      children: [
        BookmarksEmptyStateCard(onAction: () => context.go('/bookshelf')),
      ],
    );
  }

  Widget _buildDesktopBody(
    BuildContext context, {
    required double horizontal,
    required double topInset,
    required double bottomSafe,
  }) {
    // 桌面版保持原有逻辑，但使用优化后的卡片样式
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

    final groups = _groups;
    if (groups.isEmpty) {
      return _buildEmptyState(
        context,
        horizontal: horizontal,
        topInset: topInset,
        bottomSafe: bottomSafe,
      );
    }

    if (_selectedGroupIndex >= groups.length) {
      _selectedGroupIndex = groups.length - 1;
    }
    final selectedGroup = groups[_selectedGroupIndex];
    final metrics = AppAdaptiveMetrics.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        topInset + 12,
        horizontal,
        12 + bottomSafe,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 360,
            child: Column(children: [_buildDesktopGroupList(context, groups)]),
          ),
          SizedBox(width: metrics.contentGap),
          Expanded(child: _buildDesktopGroupDetail(context, selectedGroup)),
        ],
      ),
    );
  }

  Widget _buildDesktopGroupList(
    BuildContext context,
    List<BookmarkBookGroupData> groups,
  ) {
    final totalBooks = groups.length;
    final totalBookmarks = groups.fold<int>(
      0,
      (sum, group) => sum + group.bookmarks.length,
    );
    final booksWithNotes =
        groups
            .where((group) => group.bookmarks.any((item) => item.hasNote))
            .length;

    return Column(
      children: [
        _buildStatsCard(
          context,
          totalBooks: totalBooks,
          totalBookmarks: totalBookmarks,
          booksWithNotes: booksWithNotes,
        ),
        SizedBox(height: 12),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: ListView.separated(
              itemCount: groups.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final group = groups[index];
                return _buildBookGroupCard(
                  context,
                  group,
                  selected: index == _selectedGroupIndex,
                  onTap:
                      () => setState(() {
                        _selectedGroupIndex = index;
                      }),
                );
              },
            ),
          ),
        ),
      ],
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
          BookmarksStatusStateCard(
            title: title,
            message: message,
            actionLabel: actionLabel,
            onAction: onAction,
          ),
        ],
      ),
    );
  }

  Widget _buildBookGroupCard(
    BuildContext context,
    BookmarkBookGroupData group, {
    bool selected = false,
    VoidCallback? onTap,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final book = group.book;
    final displayState = group.displayState;
    final title = group.displayTitle;
    final author = group.displayAuthor;
    final bookmarkCount = group.bookmarks.length;
    final noteCount = group.bookmarks.where((item) => item.hasNote).length;
    final isInShelf = book != null && book.sourceId.trim().isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ?? () => _openBookGroup(group),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              _buildCover(
                realCoverUrl: displayState?.displayCover ?? book?.coverUrl,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          '$bookmarkCount 条',
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (noteCount > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_note_outlined,
                                size: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '$noteCount 条笔记',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _formatTimeShort(group.latestTime),
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        if (!isInShelf)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '已下架',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color:
                    selected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopGroupDetail(
    BuildContext context,
    BookmarkBookGroupData group,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final book = group.book;
    final chapters = _groupBookmarksByChapter(group.bookmarks);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCover(
                realCoverUrl:
                    group.displayState?.displayCover ?? book?.coverUrl,
                title: group.displayTitle,
                author: group.displayAuthor,
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
                      group.displayTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.displayAuthor,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _DetailTag(
                          icon: Icons.auto_awesome_outlined,
                          text: '${group.bookmarks.length} 条灵感',
                        ),
                        if (group.bookmarks.any((item) => item.hasNote))
                          _DetailTag(
                            icon: Icons.edit_note_outlined,
                            text:
                                '${group.bookmarks.where((item) => item.hasNote).length} 条笔记',
                          ),
                        _DetailTag(
                          icon: Icons.access_time_rounded,
                          text: _formatTimeShort(group.latestTime),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final chapter in chapters) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      chapter.title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  Text(
                    '${chapter.bookmarks.length} 条',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            for (final bookmark in chapter.bookmarks)
              _BookmarkDetailItem(
                bookmark: bookmark,
                subtitle:
                    _canOpenBookmark(book)
                        ? _formatTimeShort(bookmark.updatedAt)
                        : '${_formatTimeShort(bookmark.updatedAt)} · 书籍已移除，无法定位',
                onTap: () => unawaited(_openBookmark(bookmark, book)),
                onDelete: () => unawaited(_deleteBookmark(bookmark)),
              ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Future<void> _openBookGroup(BookmarkBookGroupData group) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => _BookmarkBookDetailPage(
              group: group,
              buildCover: _buildCover,
              canOpenBookmark: _canOpenBookmark,
              openBookmark: _openBookmark,
              deleteBookmark: _deleteBookmark,
              formatTime: _formatTimeShort,
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
      brightness: Theme.of(context).brightness,
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

  String _formatTimeShort(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(time.year, time.month, time.day);

    if (date == today) {
      return '今天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }

    final yesterday = today.subtract(const Duration(days: 1));
    if (date == yesterday) {
      return '昨天';
    }

    final daysDiff = today.difference(date).inDays;
    if (daysDiff < 7) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[time.weekday - 1];
    }

    return '${time.month}月${time.day}日';
  }

  bool _canOpenBookmark(BookshelfBook? book) {
    if (book == null) {
      return false;
    }
    return book.sourceId.trim().isNotEmpty && book.detailUrl.trim().isNotEmpty;
  }

  Future<void> _openBookmark(Bookmark bookmark, BookshelfBook? book) async {
    if (!_canOpenBookmark(book)) {
      _showMessage('书籍已移出书架，暂无法定位灵感。');
      return;
    }

    if (LocalReaderIdentity.isLocalSourceId(book!.sourceId)) {
      final guard = await _localReaderEntryGuardService.guardBookmark(bookmark);
      if (!mounted) {
        return;
      }
      final route = guard.route;
      if (route == null ||
          guard.action == LocalReaderEntryGuardAction.unavailable) {
        _showMessage(guard.message ?? '本地图书暂不可用。');
        return;
      }
      context.push(route);
      if (guard.message != null) {
        _showMessage(guard.message!);
      }
      return;
    }

    context.push(
      _readerEntryRouteResolver.buildRouteFromBookmark(
        bookmark: bookmark,
        sourceId: book.sourceId,
        detailUrl: book.detailUrl,
      ),
    );
  }

  Future<void> _deleteBookmark(Bookmark bookmark) async {
    final confirmed = await showBookmarkDeleteConfirmSurface(
      context: context,
      title: '删除灵感',
      message: '确定要删除这条灵感吗？',
    );

    if (confirmed != true) return;

    try {
      await _bookmarkRepository.removeBookmark(bookmark.id);
      if (!mounted) return;
      setState(() {
        _bookmarks = _bookmarks
            .where((item) => item.id != bookmark.id)
            .toList(growable: false);
        _groups = _bookmarksQueryService.buildGroups(
          bookmarks: _bookmarks,
          bookshelfIndex: _bookshelfIndex,
        );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
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

// ==================== 辅助组件 ====================

Future<bool?> showBookmarkDeleteConfirmSurface({
  required BuildContext context,
  required String title,
  required String message,
}) {
  return showAdaptiveActionSurface<bool>(
    context: context,
    maxWidth: 420,
    builder: (surfaceContext) {
      final colorScheme = Theme.of(surfaceContext).colorScheme;
      final textTheme = Theme.of(surfaceContext).textTheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: colorScheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(message, style: textTheme.bodyMedium),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(surfaceContext).pop(false),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => Navigator.of(surfaceContext).pop(true),
                  style: FilledButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                  child: const Text('删除'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class BookmarksEmptyStateCard extends StatelessWidget {
  const BookmarksEmptyStateCard({super.key, required this.onAction});

  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return AppEmptyStateCard(
      icon: Icons.auto_awesome_outlined,
      title: '灵感空空如也',
      description: '阅读时选中喜欢的段落，点击「保存灵感」',
      actionLabel: '去阅读一本书',
      onAction: onAction,
    );
  }
}

class BookmarksStatusStateCard extends StatelessWidget {
  const BookmarksStatusStateCard({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return AppStatusStateCard(
      icon: Icons.bookmarks_outlined,
      title: title,
      message: message,
      tone:
          title == '加载失败'
              ? AppStatusStateTone.error
              : AppStatusStateTone.neutral,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
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
  });

  final BookmarkBookGroupData group;
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
  final Future<void> Function(Bookmark bookmark) deleteBookmark;
  final String Function(DateTime time) formatTime;

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
    final title = widget.group.displayTitle;
    final author = widget.group.displayAuthor;
    final chapters = _groupBookmarksByChapter(_bookmarks);
    final metrics = AppAdaptiveMetrics.of(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('灵感详情'),
        actions: [
          IconButton(
            tooltip: '删除本书所有灵感',
            onPressed: _deleteAllBookmarks,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppLayout.pageContentMaxWidth(
              context,
              maxWidth: AppLayout.settingsContentMaxWidth,
            ),
          ),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              metrics.pagePadding,
              metrics.contentGap,
              metrics.pagePadding,
              metrics.sectionGap + bottomSafe,
            ),
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      widget.buildCover(
                        realCoverUrl:
                            widget.group.displayState?.displayCover ??
                            book?.coverUrl,
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
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                _DetailTag(
                                  icon: Icons.auto_awesome_outlined,
                                  text: '${_bookmarks.length} 条灵感',
                                ),
                                if (_bookmarks.any((item) => item.hasNote))
                                  _DetailTag(
                                    icon: Icons.edit_note_outlined,
                                    text:
                                        '${_bookmarks.where((item) => item.hasNote).length} 条笔记',
                                  ),
                                _DetailTag(
                                  icon: Icons.access_time_rounded,
                                  text: widget.formatTime(
                                    widget.group.latestTime,
                                  ),
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
              SizedBox(height: metrics.contentGap),
              if (_bookmarks.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.auto_awesome_outlined,
                            size: 48,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '这本书的灵感已经删空了。',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...chapters.map(
                  (chapter) => Padding(
                    padding: EdgeInsets.only(bottom: metrics.contentGap),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    chapter.title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${chapter.bookmarks.length} 条',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...chapter.bookmarks.map(
                              (bookmark) => _BookmarkDetailItem(
                                bookmark: bookmark,
                                subtitle:
                                    widget.canOpenBookmark(book)
                                        ? widget.formatTime(bookmark.updatedAt)
                                        : '${widget.formatTime(bookmark.updatedAt)} · 书籍已移除，无法定位',
                                onTap:
                                    () => widget.openBookmark(bookmark, book),
                                onDelete: () async {
                                  final navigator = Navigator.of(context);
                                  await widget.deleteBookmark(bookmark);
                                  if (!mounted) return;
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
        ),
      ),
    );
  }

  Future<void> _deleteAllBookmarks() async {
    final confirmed = await showBookmarkDeleteConfirmSurface(
      context: context,
      title: '删除所有灵感',
      message: '确定要删除本书的所有 ${_bookmarks.length} 条灵感吗？',
    );

    if (confirmed != true) return;

    for (final bookmark in _bookmarks) {
      await widget.deleteBookmark(bookmark);
    }
    if (mounted) {
      Navigator.pop(context);
    }
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bookmark.displaySnippet.isEmpty
                    ? '（空灵感）'
                    : bookmark.displaySnippet,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
              if (bookmark.hasNote) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.edit_note_outlined,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          bookmark.note!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      subtitle,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '删除灵感',
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailTag extends StatelessWidget {
  const _DetailTag({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
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
