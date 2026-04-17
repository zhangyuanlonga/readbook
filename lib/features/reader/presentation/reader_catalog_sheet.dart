import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/widgets/disk_cached_cover_image.dart';
import '../../../app/widgets/text_cover_placeholder.dart';
import '../../../domain/entities/bookmark.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/repositories/bookmark_repository.dart';
import '../application/reader_catalog_search_service.dart';
import '../application/reader_logical_position.dart';

class ReaderCatalogSheetSelection {
  const ReaderCatalogSheetSelection({
    required this.chapterIndex,
    this.scrollRatio,
    this.logicalPosition,
  });

  final int chapterIndex;
  final double? scrollRatio;
  final ReaderLogicalPosition? logicalPosition;
}

class ReaderCatalogSheetResult {
  const ReaderCatalogSheetResult._({this.selection, this.bookmark});

  const ReaderCatalogSheetResult.selection(
    ReaderCatalogSheetSelection selection,
  ) : this._(selection: selection);

  const ReaderCatalogSheetResult.bookmark(Bookmark bookmark)
    : this._(bookmark: bookmark);

  final ReaderCatalogSheetSelection? selection;
  final Bookmark? bookmark;
}

Future<ReaderCatalogSheetResult?> showReaderCatalogSheet({
  required BuildContext context,
  required ThemeData readerModalTheme,
  required List<Chapter> chapters,
  required int? currentChapterIndex,
  required String bookTitle,
  required String? bookAuthor,
  required String? bookCoverUrl,
  required bool supportsContentSearch,
  required BookmarkRepository bookmarkRepository,
  required String currentBookId,
  required List<ReaderCatalogSearchEntry>? Function(String normalizedKeyword)
  peekCatalogSearchEntries,
  required List<ReaderCatalogSearchEntry> Function(String keyword)
  lookupCatalogSearchEntries,
  required int? Function(ReaderCatalogSearchEntry entry)
  resolveCatalogSearchEntryTargetIndex,
  required Future<void> Function() refreshChapterBookmarks,
  required ValueChanged<String> showMessage,
}) async {
  const itemExtent = 58.0;
  final anchorIndex =
      currentChapterIndex == null
          ? 0
          : (currentChapterIndex - 2).clamp(0, chapters.length - 1);
  final scrollController = ScrollController(
    initialScrollOffset: anchorIndex * itemExtent,
  );
  final scrollThumbVisible = ValueNotifier<bool>(false);
  final searchController = TextEditingController();
  final catalogSearchNotifier = ValueNotifier<_ReaderCatalogSearchState>(
    const _ReaderCatalogSearchState(),
  );
  Timer? catalogSearchDebounceTimer;
  var catalogSearchToken = 0;
  var bookmarks = <Bookmark>[];
  var isBookmarkLoading = true;
  var hasBookmarkRequested = false;
  var bookmarkErrorText = '';
  var activeTabIndex = 0;
  var catalogDescending = false;

  Future<void> loadBookmarks(
    StateSetter setModalState,
    BuildContext modalContext,
  ) async {
    if (!modalContext.mounted) {
      return;
    }
    setModalState(() {
      isBookmarkLoading = true;
      bookmarkErrorText = '';
    });
    try {
      final items = await bookmarkRepository.listBookmarks(currentBookId);
      bookmarks = items;
    } catch (_) {
      bookmarkErrorText = '灵感加载失败，请稍后重试。';
    } finally {
      if (modalContext.mounted) {
        setModalState(() {
          isBookmarkLoading = false;
        });
      }
    }
  }

  Future<void> ensureBookmarksLoaded(
    StateSetter setModalState,
    BuildContext modalContext,
  ) async {
    if (hasBookmarkRequested) {
      return;
    }
    hasBookmarkRequested = true;
    await loadBookmarks(setModalState, modalContext);
  }

  List<int> orderedChapterIndexes() {
    if (!catalogDescending) {
      return List<int>.generate(chapters.length, (index) => index);
    }
    return List<int>.generate(
      chapters.length,
      (index) => chapters.length - 1 - index,
    );
  }

  void scheduleCatalogSearch(String rawKeyword) {
    final keyword = rawKeyword.trim();
    catalogSearchDebounceTimer?.cancel();
    if (keyword.isEmpty) {
      catalogSearchToken += 1;
      catalogSearchNotifier.value = const _ReaderCatalogSearchState();
      return;
    }

    final normalizedKeyword = keyword.toLowerCase();
    final cachedEntries = peekCatalogSearchEntries(normalizedKeyword);
    if (cachedEntries != null) {
      catalogSearchToken += 1;
      catalogSearchNotifier.value = _ReaderCatalogSearchState(
        keyword: keyword,
        entries: cachedEntries,
      );
      return;
    }

    final token = ++catalogSearchToken;
    catalogSearchNotifier.value = _ReaderCatalogSearchState(
      keyword: keyword,
      entries: catalogSearchNotifier.value.entries,
      isLoading: true,
    );
    catalogSearchDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      final entries = lookupCatalogSearchEntries(keyword);
      if (token != catalogSearchToken) {
        return;
      }
      catalogSearchNotifier.value = _ReaderCatalogSearchState(
        keyword: keyword,
        entries: entries,
      );
    });
  }

  searchController.addListener(() {
    scheduleCatalogSearch(searchController.text);
  });

  final result = await showModalBottomSheet<ReaderCatalogSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    backgroundColor: readerModalTheme.colorScheme.surface,
    builder: (context) {
      return Theme(
        data: readerModalTheme,
        child: StatefulBuilder(
          builder: (context, setModalState) {
            final colorScheme = Theme.of(context).colorScheme;
            final textTheme = Theme.of(context).textTheme;
            final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
            final safeBottom = _bottomSafeInset(context);
            final sheetHeightFactor = AppLayout.sheetHeightFactor(
              context,
              compact: 0.80,
              regular: 0.80,
              large: 0.80,
            );
            final sheetHorizontal = AppSpacing.pageHorizontal(context);

            Widget buildCatalogTab() {
              return ValueListenableBuilder<_ReaderCatalogSearchState>(
                valueListenable: catalogSearchNotifier,
                builder: (context, searchState, _) {
                  final isSearching = searchState.keyword.isNotEmpty;
                  final orderedIndexes = orderedChapterIndexes();
                  final tocSearchEntries =
                      catalogDescending
                          ? ([...searchState.tocEntries]..sort(
                            (a, b) => b.chapterIndex.compareTo(a.chapterIndex),
                          ))
                          : searchState.tocEntries;
                  final contentSearchEntries =
                      catalogDescending
                          ? ([...searchState.contentEntries]..sort(
                            (a, b) => b.chapterIndex.compareTo(a.chapterIndex),
                          ))
                          : searchState.contentEntries;

                  return Column(
                    children: [
                      if (isSearching && searchState.isLoading)
                        const Expanded(
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else if (isSearching && searchState.entries.isEmpty)
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '未找到匹配内容',
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    supportsContentSearch
                                        ? '当前仅支持搜索目录标题与本章正文。'
                                        : '当前模式仅支持搜索目录标题。',
                                    textAlign: TextAlign.center,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else if (isSearching)
                        Expanded(
                          child: _CatalogSearchResultList(
                            scrollController: scrollController,
                            tocEntries: tocSearchEntries,
                            contentEntries: contentSearchEntries,
                            onEntryTap: (entry) {
                              final targetChapterIndex =
                                  resolveCatalogSearchEntryTargetIndex(entry);
                              if (targetChapterIndex == null) {
                                showMessage('该分卷下暂无可读章节。');
                                return;
                              }
                              Navigator.of(context).pop(
                                ReaderCatalogSheetResult.selection(
                                  ReaderCatalogSheetSelection(
                                    chapterIndex: targetChapterIndex,
                                    scrollRatio: entry.scrollRatio,
                                    logicalPosition: entry.logicalPosition,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      else
                        Expanded(
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification is ScrollStartNotification ||
                                  notification is UserScrollNotification) {
                                scrollThumbVisible.value = true;
                              } else if (notification
                                  is ScrollEndNotification) {
                                scrollThumbVisible.value = false;
                              }
                              return false;
                            },
                            child: ValueListenableBuilder<bool>(
                              valueListenable: scrollThumbVisible,
                              builder: (context, visible, child) {
                                return Scrollbar(
                                  controller: scrollController,
                                  thumbVisibility: visible,
                                  child: child!,
                                );
                              },
                              child: ListView.builder(
                                controller: scrollController,
                                itemCount: orderedIndexes.length,
                                itemExtent: itemExtent,
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  10,
                                ),
                                itemBuilder: (context, index) {
                                  final chapterIndex = orderedIndexes[index];
                                  final chapter = chapters[chapterIndex];
                                  final selected =
                                      chapterIndex == currentChapterIndex;
                                  return _ReaderCatalogChapterTile(
                                    chapter: chapter,
                                    selected: selected,
                                    enabled: _isReadableChapter(chapter),
                                    onTap:
                                        _isReadableChapter(chapter)
                                            ? () => Navigator.of(context).pop(
                                              ReaderCatalogSheetResult.selection(
                                                ReaderCatalogSheetSelection(
                                                  chapterIndex: chapterIndex,
                                                ),
                                              ),
                                            )
                                            : null,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            }

            Widget buildBookmarkTab() {
              if (!hasBookmarkRequested) {
                unawaited(ensureBookmarksLoaded(setModalState, context));
              }
              final bookmarkGroups = _groupBookmarksForSheet(
                bookmarks,
                chapters,
              );
              final title =
                  isBookmarkLoading ? '灵感' : '灵感（${bookmarks.length}）';

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  sheetHorizontal,
                  10,
                  sheetHorizontal,
                  12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isBookmarkLoading)
                      Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '正在加载灵感...',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      )
                    else if (bookmarkErrorText.isNotEmpty)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              bookmarkErrorText,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.error,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed:
                                () => unawaited(
                                  loadBookmarks(setModalState, context),
                                ),
                            child: const Text('重试'),
                          ),
                        ],
                      )
                    else if (bookmarkGroups.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          '当前书籍还没有灵感。',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: bookmarkGroups.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final group = bookmarkGroups[index];
                            return _BookmarkGroupSection(
                              title: group.title,
                              items: group.bookmarks,
                              timeLabel: _formatBookmarkTime,
                              onTap:
                                  (bookmark) => Navigator.of(context).pop(
                                    ReaderCatalogSheetResult.bookmark(bookmark),
                                  ),
                              onDelete: (bookmark) async {
                                final modalContext = context;
                                await bookmarkRepository.removeBookmark(
                                  bookmark.id,
                                );
                                if (!modalContext.mounted) {
                                  return;
                                }
                                await loadBookmarks(
                                  setModalState,
                                  modalContext,
                                );
                                if (!modalContext.mounted) {
                                  return;
                                }
                                await refreshChapterBookmarks();
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              );
            }

            final bookmarkCountLabel = bookmarks.length.toString();

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(bottom: keyboardInset + safeBottom),
              child: FractionallySizedBox(
                heightFactor: sheetHeightFactor,
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          sheetHorizontal,
                          6,
                          sheetHorizontal,
                          4,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.28,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: TabBar(
                              labelColor: colorScheme.primary,
                              unselectedLabelColor:
                                  colorScheme.onSurfaceVariant,
                              dividerColor: Colors.transparent,
                              indicatorSize: TabBarIndicatorSize.tab,
                              indicator: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              splashBorderRadius: BorderRadius.circular(14),
                              onTap: (index) {
                                if (activeTabIndex == index) {
                                  return;
                                }
                                setModalState(() {
                                  activeTabIndex = index;
                                });
                                if (index == 1) {
                                  unawaited(
                                    ensureBookmarksLoaded(
                                      setModalState,
                                      context,
                                    ),
                                  );
                                }
                              },
                              tabs: [
                                _buildCountTab(
                                  context,
                                  label: '目录',
                                  countText: chapters.length.toString(),
                                ),
                                _buildCountTab(
                                  context,
                                  label: '灵感',
                                  countText: bookmarkCountLabel,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          sheetHorizontal,
                          6,
                          sheetHorizontal,
                          10,
                        ),
                        child: _ReaderCatalogHeaderCard(
                          bookTitle: bookTitle,
                          bookAuthor: bookAuthor,
                          bookCoverUrl: bookCoverUrl,
                          supportsContentSearch: supportsContentSearch,
                          searchController: searchController,
                          catalogDescending: catalogDescending,
                          onToggleSort: () {
                            setModalState(() {
                              catalogDescending = !catalogDescending;
                            });
                          },
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      Expanded(
                        child:
                            activeTabIndex == 0
                                ? buildCatalogTab()
                                : buildBookmarkTab(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );

  scrollController.dispose();
  searchController.dispose();
  scrollThumbVisible.dispose();
  catalogSearchDebounceTimer?.cancel();
  catalogSearchNotifier.dispose();
  return result;
}

Tab _buildCountTab(
  BuildContext context, {
  required String label,
  required String countText,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;
  return Tab(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            countText,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

double _bottomSafeInset(BuildContext context) {
  final viewPadding = MediaQuery.viewPaddingOf(context).bottom;
  final gestureInsets = MediaQuery.systemGestureInsetsOf(context).bottom;
  return max(viewPadding, gestureInsets);
}

bool _isReadableChapter(Chapter chapter) {
  return !chapter.isVolume && chapter.chapterUrl.trim().isNotEmpty;
}

List<_BookmarkGroup> _groupBookmarksForSheet(
  List<Bookmark> bookmarks,
  List<Chapter> chapters,
) {
  if (bookmarks.isEmpty) {
    return const <_BookmarkGroup>[];
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
    return b.createdAt.compareTo(a.createdAt);
  });

  final groups = <_BookmarkGroup>[];
  for (final bookmark in sorted) {
    final title = _resolveBookmarkChapterTitle(bookmark, chapters);
    final existing =
        groups.isNotEmpty && groups.last.chapterIndex == bookmark.chapterIndex
            ? groups.last
            : null;
    if (existing != null) {
      existing.bookmarks.add(bookmark);
    } else {
      groups.add(
        _BookmarkGroup(
          chapterIndex: bookmark.chapterIndex,
          title: title,
          bookmarks: [bookmark],
        ),
      );
    }
  }
  return groups;
}

String _resolveBookmarkChapterTitle(Bookmark bookmark, List<Chapter> chapters) {
  final chapterId = bookmark.chapterId.trim();
  if (chapterId.isNotEmpty) {
    Chapter? matched;
    for (final chapter in chapters) {
      if (chapter.id == chapterId) {
        matched = chapter;
        break;
      }
    }
    if (matched != null && matched.title.trim().isNotEmpty) {
      return matched.title.trim();
    }
  }

  final index = bookmark.chapterIndex;
  if (index >= 0 && index < chapters.length) {
    final title = chapters[index].title.trim();
    if (title.isNotEmpty) {
      return title;
    }
  }
  return '第 ${bookmark.chapterIndex + 1} 章';
}

String _formatBookmarkTime(DateTime time) {
  final year = time.year.toString().padLeft(4, '0');
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}

class _ReaderCatalogSearchState {
  const _ReaderCatalogSearchState({
    this.keyword = '',
    this.entries = const <ReaderCatalogSearchEntry>[],
    this.isLoading = false,
  });

  final String keyword;
  final List<ReaderCatalogSearchEntry> entries;
  final bool isLoading;

  List<ReaderCatalogSearchEntry> get tocEntries =>
      entries.where((entry) => !entry.isContent).toList(growable: false);

  List<ReaderCatalogSearchEntry> get contentEntries =>
      entries.where((entry) => entry.isContent).toList(growable: false);
}

class _CatalogSearchResultList extends StatelessWidget {
  const _CatalogSearchResultList({
    required this.scrollController,
    required this.tocEntries,
    required this.contentEntries,
    required this.onEntryTap,
  });

  final ScrollController scrollController;
  final List<ReaderCatalogSearchEntry> tocEntries;
  final List<ReaderCatalogSearchEntry> contentEntries;
  final ValueChanged<ReaderCatalogSearchEntry> onEntryTap;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    void appendSection(String title, List<ReaderCatalogSearchEntry> entries) {
      if (entries.isEmpty) {
        return;
      }
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 8));
      }
      children.add(
        _CatalogSearchSectionHeader(title: title, count: entries.length),
      );
      children.add(const SizedBox(height: 6));
      for (final entry in entries) {
        children.add(
          _CatalogSearchEntryTile(entry: entry, onTap: () => onEntryTap(entry)),
        );
        children.add(const SizedBox(height: 8));
      }
    }

    appendSection('目录匹配', tocEntries);
    appendSection('当前章节正文', contentEntries);

    return Scrollbar(
      controller: scrollController,
      thumbVisibility: true,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        children: children,
      ),
    );
  }
}

class _ReaderCatalogHeaderCard extends StatelessWidget {
  const _ReaderCatalogHeaderCard({
    required this.bookTitle,
    required this.bookAuthor,
    required this.bookCoverUrl,
    required this.supportsContentSearch,
    required this.searchController,
    required this.catalogDescending,
    required this.onToggleSort,
  });

  final String bookTitle;
  final String? bookAuthor;
  final String? bookCoverUrl;
  final bool supportsContentSearch;
  final TextEditingController searchController;
  final bool catalogDescending;
  final VoidCallback onToggleSort;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final normalizedTitle = bookTitle.trim().isEmpty ? '未命名书籍' : bookTitle;
    final normalizedAuthor = (bookAuthor ?? '').trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final searchWidth = (constraints.maxWidth * 0.34).clamp(120.0, 164.0);
        return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceContainerHigh,
            colorScheme.surfaceContainerLow,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 50,
              height: 68,
              child: DiskCachedCoverImage(
                imageUrl: bookCoverUrl,
                fit: BoxFit.cover,
                fallback: TextCoverPlaceholder(
                  title: normalizedTitle,
                  author: normalizedAuthor.isEmpty ? null : normalizedAuthor,
                  width: 50,
                  height: 68,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  normalizedTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (normalizedAuthor.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    normalizedAuthor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: searchWidth,
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: colorScheme.surface.withValues(alpha: 0.92),
                hintText: supportsContentSearch ? '搜索目录/正文' : '搜索目录',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 17,
                  color: colorScheme.onSurfaceVariant,
                ),
                suffixIcon: IconButton(
                  tooltip: catalogDescending ? '当前倒序' : '当前正序',
                  onPressed: onToggleSort,
                  icon: Icon(
                    catalogDescending
                        ? Icons.south_rounded
                        : Icons.north_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: colorScheme.primary.withValues(alpha: 0.9),
                    width: 1.1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}

class _ReaderCatalogChapterTile extends StatelessWidget {
  const _ReaderCatalogChapterTile({
    required this.chapter,
    required this.selected,
    required this.enabled,
    this.onTap,
  });

  final Chapter chapter;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isVolume = chapter.isVolume;
    final borderRadius = BorderRadius.circular(14);
    final selectedBackground = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: 0.15),
      colorScheme.surfaceContainerLow,
    );
    final unselectedBackground =
        isVolume
            ? colorScheme.secondaryContainer.withValues(alpha: 0.34)
            : colorScheme.surface.withValues(alpha: 0.78);

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? selectedBackground : unselectedBackground,
            borderRadius: borderRadius,
            border: Border.all(
              color:
                  selected
                      ? colorScheme.primary.withValues(alpha: 0.28)
                      : colorScheme.outlineVariant.withValues(alpha: 0.18),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        isVolume
                            ? colorScheme.secondaryContainer
                            : selected
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child:
                      isVolume
                          ? Icon(
                            Icons.folder_outlined,
                            size: 16,
                            color: colorScheme.onSecondaryContainer,
                          )
                          : Icon(
                            selected
                                ? Icons.menu_book_rounded
                                : Icons.article_outlined,
                            size: 16,
                            color:
                                selected
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurfaceVariant,
                          ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    chapter.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      height: 1.2,
                      fontWeight:
                          isVolume
                              ? FontWeight.w700
                              : (selected ? FontWeight.w700 : FontWeight.w500),
                      color:
                          isVolume
                              ? colorScheme.onSecondaryContainer
                              : selected
                              ? colorScheme.primary
                              : enabled
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (isVolume)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '分卷',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  Icon(
                    selected
                        ? Icons.play_circle_fill_rounded
                        : Icons.chevron_right_rounded,
                    size: 18,
                    color:
                        selected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogSearchSectionHeader extends StatelessWidget {
  const _CatalogSearchSectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Text(
          title,
          style: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _CatalogSearchEntryTile extends StatelessWidget {
  const _CatalogSearchEntryTile({required this.entry, required this.onTap});

  final ReaderCatalogSearchEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isVolumeEntry = !entry.isContent && entry.isVolume;
    final accentColor =
        entry.isContent
            ? colorScheme.tertiary
            : (isVolumeEntry ? colorScheme.secondary : colorScheme.primary);

    return Material(
      color:
          entry.isContent
              ? colorScheme.tertiaryContainer.withValues(alpha: 0.32)
              : isVolumeEntry
              ? colorScheme.secondaryContainer.withValues(alpha: 0.32)
              : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  entry.isContent
                      ? Icons.article_outlined
                      : isVolumeEntry
                      ? Icons.folder_outlined
                      : Icons.list_alt_outlined,
                  size: 16,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  entry.isContent ? '正文' : (isVolumeEntry ? '分卷' : '目录'),
                  style: textTheme.labelSmall?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookmarkGroup {
  _BookmarkGroup({
    required this.chapterIndex,
    required this.title,
    required List<Bookmark> bookmarks,
  }) : bookmarks = List<Bookmark>.from(bookmarks);

  final int chapterIndex;
  final String title;
  final List<Bookmark> bookmarks;
}

class _BookmarkGroupSection extends StatelessWidget {
  const _BookmarkGroupSection({
    required this.title,
    required this.items,
    required this.timeLabel,
    required this.onTap,
    required this.onDelete,
  });

  final String title;
  final List<Bookmark> items;
  final String Function(DateTime) timeLabel;
  final ValueChanged<Bookmark> onTap;
  final ValueChanged<Bookmark> onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        ...items.map((bookmark) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Material(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onTap(bookmark),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bookmark.snippet,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              timeLabel(bookmark.createdAt),
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '删除',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => onDelete(bookmark),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
