// UI-GOV-EXEMPT-FILE: list-children
// reason: Phase 10 reviewed this Reader catalog structure; full shell migration is deferred to Phase 12.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../app/layout/app_spacing.dart';
import '../../../app/theme/app_component_theme_tokens.dart';
import '../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../app/widgets/foundation/foundation.dart';
import '../../../app/widgets/resolved_book_cover.dart';
import '../../../domain/entities/bookmark.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/repositories/bookmark_repository.dart';
import '../application/reader_mode_model.dart';
import '../application/reader_catalog_search_presentation.dart';
import '../application/reader_catalog_search_service.dart';
import '../application/reader_logical_position.dart';
import 'reader_layout_context.dart';

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

const double _kReaderCatalogInitialSheetSize = 0.8;
const double _kReaderCatalogExpandedSheetSize = 1.0;

Future<ReaderCatalogSheetResult?> showReaderCatalogSheet({
  required BuildContext context,
  required ThemeData readerModalTheme,
  required List<Chapter> chapters,
  required int? currentChapterIndex,
  required String bookTitle,
  required String? bookAuthor,
  required String? bookCoverUrl,
  String? customCoverPath,
  ResolvedBookCover? resolvedCover,
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
  final routeContext = Navigator.of(context).context;
  final readerLayoutContext = ReaderLayoutContext.resolve(
    context,
    viewportKind: ReaderModeViewportKind.textScroll,
  );
  final barrierLabel =
      MaterialLocalizations.of(context).modalBarrierDismissLabel;
  final isDesktopSurface =
      readerLayoutContext.catalogPanelPresentation ==
      ReaderPanelPresentation.sidePanel;
  const catalogSearchPresenter = ReaderCatalogSearchPresenter();
  const itemExtent = 52.0;
  final anchorIndex =
      currentChapterIndex == null
          ? 0
          : (currentChapterIndex - 2).clamp(0, chapters.length - 1);
  final scrollController = ScrollController(
    initialScrollOffset: anchorIndex * itemExtent,
  );
  final scrollThumbVisible = ValueNotifier<bool>(false);
  final searchController = TextEditingController();
  final bookmarkSearchController = TextEditingController();
  final catalogSearchNotifier = ValueNotifier<_ReaderCatalogSearchState>(
    const _ReaderCatalogSearchState(),
  );
  final bookmarkSearchNotifier = ValueNotifier<String>('');
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

  bookmarkSearchController.addListener(() {
    bookmarkSearchNotifier.value = bookmarkSearchController.text.trim();
  });

  Widget buildSearchBar(
    BuildContext context, {
    required TextEditingController controller,
    required String hintText,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 12, 16, 10),
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: SizedBox(
        height: 48,
        child: AppTextField(
          controller: controller,
          hintText: hintText,
          textInputAction: TextInputAction.search,
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget buildCatalogSurface(
    BuildContext context,
    StateSetter setModalState, {
    required bool isDesktopSurface,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final componentTokens = appComponentThemeTokensOf(context);
    final tabContainerRadius = BorderRadius.all(
      Radius.circular(componentTokens.selection.segmentRadius),
    );
    final tabIndicatorRadius = BorderRadius.all(
      Radius.circular(componentTokens.selection.tabIndicatorRadius),
    );
    final sheetHorizontal = AppSpacing.pageHorizontal(context);

    if (!hasBookmarkRequested) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        unawaited(ensureBookmarksLoaded(setModalState, context));
      });
    }

    Future<void> openCatalogMoreActions({
      ScrollController? listController,
    }) async {
      final effectiveController = listController ?? scrollController;
      final action = await showAdaptiveActionSurface<String>(
        context: context,
        maxWidth: 420,
        padding: EdgeInsets.zero,
        builder: (actionContext) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    catalogDescending
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                  ),
                  title: Text(catalogDescending ? '切换为正序' : '切换为倒序'),
                  onTap: () => Navigator.of(actionContext).pop('sort'),
                ),
              ],
            ),
          );
        },
      );

      if (action == 'locate') {
        if (currentChapterIndex == null) {
          return;
        }
        final currentDisplayIndex = orderedChapterIndexes().indexOf(
          currentChapterIndex,
        );
        final target =
            ((currentDisplayIndex - 2).clamp(0, chapters.length - 1) *
                    itemExtent)
                .toDouble();
        effectiveController.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
        return;
      }

      if (action == 'sort') {
        setModalState(() {
          catalogDescending = !catalogDescending;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (effectiveController.hasClients) {
            effectiveController.jumpTo(0);
          }
        });
      }
    }

    Widget buildCatalogTab() {
      return ValueListenableBuilder<_ReaderCatalogSearchState>(
        valueListenable: catalogSearchNotifier,
        builder: (context, searchState, _) {
          final isSearching = searchState.keyword.isNotEmpty;
          final orderedIndexes = orderedChapterIndexes();
          final searchPresentation = catalogSearchPresenter.resolve(
            entries: searchState.entries,
            descending: catalogDescending,
          );

          return Column(
            children: [
              if (isSearching && searchState.isLoading)
                const Expanded(
                  child: Center(
                    child: AppProgressIndicator(
                      size: 22,
                      strokeWidth: 2,
                      semanticLabel: '搜索目录',
                    ),
                  ),
                )
              else if (isSearching && searchState.entries.isEmpty)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: AppStateView(
                        kind: AppViewStateKind.filteredEmpty,
                        icon: Icons.manage_search_rounded,
                        title: '未找到匹配内容',
                        description:
                            supportsContentSearch
                                ? '当前仅支持搜索目录标题与本章正文。'
                                : '当前模式仅支持搜索目录标题。',
                        compact: true,
                      ),
                    ),
                  ),
                )
              else if (isSearching)
                Expanded(
                  child: _CatalogSearchResultList(
                    scrollController: scrollController,
                    tocEntries: searchPresentation.tocEntries,
                    contentEntries: searchPresentation.contentEntries,
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
                      } else if (notification is ScrollEndNotification) {
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
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        itemBuilder: (context, index) {
                          final chapterIndex = orderedIndexes[index];
                          final chapter = chapters[chapterIndex];
                          final selected = chapterIndex == currentChapterIndex;
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

      return Padding(
        padding: EdgeInsets.fromLTRB(sheetHorizontal, 0, sheetHorizontal, 12),
        child: ValueListenableBuilder<String>(
          valueListenable: bookmarkSearchNotifier,
          builder: (context, keyword, _) {
            final filteredBookmarks = _filterBookmarksForKeyword(
              bookmarks: bookmarks,
              chapters: chapters,
              keyword: keyword,
            );
            final bookmarkGroups = _groupBookmarksForSheet(
              filteredBookmarks,
              chapters,
            );
            if (isBookmarkLoading) {
              return const AppInlineProgress(label: '正在加载灵感', compact: true);
            }
            if (bookmarkErrorText.isNotEmpty) {
              return Row(
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
                        () => unawaited(loadBookmarks(setModalState, context)),
                    child: const Text('重试'),
                  ),
                ],
              );
            }
            if (bookmarks.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  '当前书籍还没有灵感。',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            if (bookmarkGroups.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  '未找到匹配灵感。',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return ListView.separated(
              itemCount: bookmarkGroups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final group = bookmarkGroups[index];
                return _BookmarkGroupSection(
                  title: group.title,
                  items: group.bookmarks,
                  timeLabel: _formatBookmarkTime,
                  onTap:
                      (bookmark) => Navigator.of(
                        context,
                      ).pop(ReaderCatalogSheetResult.bookmark(bookmark)),
                  onDelete: (bookmark) async {
                    final modalContext = context;
                    await bookmarkRepository.removeBookmark(bookmark.id);
                    if (!modalContext.mounted) {
                      return;
                    }
                    await loadBookmarks(setModalState, modalContext);
                    if (!modalContext.mounted) {
                      return;
                    }
                    await refreshChapterBookmarks();
                  },
                );
              },
            );
          },
        ),
      );
    }

    void handleTabChange(int index, {ScrollController? listController}) {
      if (activeTabIndex == index) {
        return;
      }
      setModalState(() {
        activeTabIndex = index;
      });
      if (index == 1) {
        unawaited(ensureBookmarksLoaded(setModalState, context));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (listController != null && listController.hasClients) {
          listController.jumpTo(0);
        }
      });
    }

    Widget buildSharedSearchBar(
      BuildContext context, {
      ScrollController? listController,
    }) {
      final isCatalogTabActive = activeTabIndex == 0;
      final componentTokens = appComponentThemeTokensOf(context);
      final controlRadius = BorderRadius.all(
        Radius.circular(componentTokens.input.radius),
      );
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: buildSearchBar(
                context,
                controller:
                    isCatalogTabActive
                        ? searchController
                        : bookmarkSearchController,
                hintText: isCatalogTabActive ? '搜索目录' : '搜索灵感',
                padding: EdgeInsets.zero,
              ),
            ),
            if (isCatalogTabActive) ...[
              const SizedBox(width: 8),
              SizedBox.square(
                dimension: 48,
                child: AppSurface(
                  padding: EdgeInsets.zero,
                  borderRadius: controlRadius,
                  backgroundColor: colorScheme.surfaceContainerLow.withValues(
                    alpha: 0.92,
                  ),
                  borderColor: colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                  onTap:
                      () => openCatalogMoreActions(
                        listController: listController,
                      ),
                  child: Center(
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    List<Widget> buildCatalogSearchResultChildren({
      required List<ReaderCatalogSearchEntry> tocEntries,
      required List<ReaderCatalogSearchEntry> contentEntries,
      required ValueChanged<ReaderCatalogSearchEntry> onEntryTap,
    }) {
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
            _CatalogSearchEntryTile(
              entry: entry,
              onTap: () => onEntryTap(entry),
            ),
          );
          children.add(const SizedBox(height: 8));
        }
      }

      appendSection('目录匹配', tocEntries);
      appendSection('当前章节正文', contentEntries);
      return children;
    }

    Widget buildCenteredMobileState({
      required Widget child,
      EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 24),
    }) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Padding(padding: padding, child: child)),
      );
    }

    Widget buildMobileTabSwitcher(
      BuildContext context, {
      required ScrollController listController,
    }) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.28),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              Expanded(
                child: _ReaderCatalogMobileTabButton(
                  tab: _buildCountTab(
                    context,
                    label: '目录',
                    countText: chapters.length.toString(),
                  ),
                  selected: activeTabIndex == 0,
                  selectedColor: colorScheme.primaryContainer,
                  onTap:
                      () => handleTabChange(0, listController: listController),
                ),
              ),
              Expanded(
                child: _ReaderCatalogMobileTabButton(
                  tab: _buildCountTab(
                    context,
                    label: '灵感',
                    countText: bookmarks.length.toString(),
                  ),
                  selected: activeTabIndex == 1,
                  selectedColor: colorScheme.primaryContainer,
                  onTap:
                      () => handleTabChange(1, listController: listController),
                ),
              ),
            ],
          ),
        ),
      );
    }

    List<Widget> buildMobileCatalogSlivers(
      BuildContext context, {
      required ScrollController listController,
    }) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              sheetHorizontal,
              MediaQuery.paddingOf(context).top + 8,
              sheetHorizontal,
              8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AdaptiveSheetDragHandle(),
                const SizedBox(height: 10),
                buildMobileTabSwitcher(context, listController: listController),
                buildSharedSearchBar(context, listController: listController),
              ],
            ),
          ),
        ),
        if (activeTabIndex == 0)
          ValueListenableBuilder<_ReaderCatalogSearchState>(
            valueListenable: catalogSearchNotifier,
            builder: (context, searchState, _) {
              final isSearching = searchState.keyword.isNotEmpty;
              final orderedIndexes = orderedChapterIndexes();
              final searchPresentation = catalogSearchPresenter.resolve(
                entries: searchState.entries,
                descending: catalogDescending,
              );

              if (isSearching && searchState.isLoading) {
                return buildCenteredMobileState(
                  child: const AppProgressIndicator(
                    size: 22,
                    strokeWidth: 2,
                    semanticLabel: '搜索目录',
                  ),
                );
              }
              if (isSearching && searchState.entries.isEmpty) {
                return buildCenteredMobileState(
                  child: AppStateView(
                    kind: AppViewStateKind.filteredEmpty,
                    icon: Icons.manage_search_rounded,
                    title: '未找到匹配内容',
                    description:
                        supportsContentSearch
                            ? '当前仅支持搜索目录标题与本章正文。'
                            : '当前模式仅支持搜索目录标题。',
                    compact: true,
                  ),
                );
              }
              if (isSearching) {
                final children = buildCatalogSearchResultChildren(
                  tocEntries: searchPresentation.tocEntries,
                  contentEntries: searchPresentation.contentEntries,
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
                );
                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    10,
                    12,
                    MediaQuery.paddingOf(context).bottom + 12,
                  ),
                  sliver: SliverList.list(children: children),
                );
              }
              return SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  10,
                  12,
                  MediaQuery.paddingOf(context).bottom + 12,
                ),
                sliver: SliverFixedExtentList(
                  itemExtent: itemExtent,
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final chapterIndex = orderedIndexes[index];
                    final chapter = chapters[chapterIndex];
                    final selected = chapterIndex == currentChapterIndex;
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
                  }, childCount: orderedIndexes.length),
                ),
              );
            },
          )
        else ...[
          ValueListenableBuilder<String>(
            valueListenable: bookmarkSearchNotifier,
            builder: (context, keyword, _) {
              final filteredBookmarks = _filterBookmarksForKeyword(
                bookmarks: bookmarks,
                chapters: chapters,
                keyword: keyword,
              );
              final bookmarkGroups = _groupBookmarksForSheet(
                filteredBookmarks,
                chapters,
              );
              if (isBookmarkLoading) {
                return buildCenteredMobileState(
                  child: const AppInlineProgress(
                    label: '正在加载灵感',
                    compact: true,
                  ),
                );
              }
              if (bookmarkErrorText.isNotEmpty) {
                return buildCenteredMobileState(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          bookmarkErrorText,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.error,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed:
                            () => unawaited(
                              loadBookmarks(setModalState, context),
                            ),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                );
              }
              if (bookmarks.isEmpty) {
                return buildCenteredMobileState(
                  child: Text(
                    '当前书籍还没有灵感。',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              if (bookmarkGroups.isEmpty) {
                return buildCenteredMobileState(
                  child: Text(
                    '未找到匹配灵感。',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  sheetHorizontal,
                  0,
                  sheetHorizontal,
                  MediaQuery.paddingOf(context).bottom + 12,
                ),
                sliver: SliverList.separated(
                  itemCount: bookmarkGroups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final group = bookmarkGroups[index];
                    return _BookmarkGroupSection(
                      title: group.title,
                      items: group.bookmarks,
                      timeLabel: _formatBookmarkTime,
                      onTap:
                          (bookmark) => Navigator.of(
                            context,
                          ).pop(ReaderCatalogSheetResult.bookmark(bookmark)),
                      onDelete: (bookmark) async {
                        final modalContext = context;
                        await bookmarkRepository.removeBookmark(bookmark.id);
                        if (!modalContext.mounted) {
                          return;
                        }
                        await loadBookmarks(setModalState, modalContext);
                        if (!modalContext.mounted) {
                          return;
                        }
                        await refreshChapterBookmarks();
                      },
                    );
                  },
                ),
              );
            },
          ),
        ],
      ];
    }

    final bookmarkCountLabel = bookmarks.length.toString();
    final content = DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              sheetHorizontal,
              8,
              sheetHorizontal,
              2,
            ),
            child: AppSurface(
              padding: const EdgeInsets.all(3),
              borderRadius: tabContainerRadius,
              backgroundColor: colorScheme.surfaceContainerLow,
              borderColor: colorScheme.outlineVariant.withValues(alpha: 0.28),
              child: TabBar(
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                dividerColor: colorScheme.outlineVariant.withValues(alpha: 0),
                indicatorSize: TabBarIndicatorSize.tab,
                // UI-GOV-EXEMPT: hardcoded-style fixed-visual
                // reason: TabBar still requires Decoration for the selected segment indicator.
                indicator: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: tabIndicatorRadius,
                ),
                splashBorderRadius: tabIndicatorRadius,
                labelStyle: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                onTap: (index) => handleTabChange(index),
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
          Padding(
            padding: EdgeInsets.fromLTRB(
              sheetHorizontal,
              0,
              sheetHorizontal,
              4,
            ),
            child: buildSharedSearchBar(
              context,
              listController: scrollController,
            ),
          ),
          Expanded(
            child: activeTabIndex == 0 ? buildCatalogTab() : buildBookmarkTab(),
          ),
        ],
      ),
    );

    if (isDesktopSurface) {
      final panelSpec = readerLayoutContext.panelLayoutFor(
        ReaderPanelRole.catalog,
      );
      return Theme(
        data: readerModalTheme,
        child: Padding(
          padding: panelSpec.outerPadding,
          child: Align(
            alignment: panelSpec.alignment,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: panelSpec.maxWidth,
                maxHeight:
                    MediaQuery.sizeOf(context).height -
                    panelSpec.outerPadding.vertical,
              ),
              child: AppSurface(
                tone: AppSurfaceTone.elevated,
                padding: EdgeInsets.zero,
                borderRadius: BorderRadius.all(
                  Radius.circular(componentTokens.overlay.radius + 6),
                ),
                borderColor: readerModalTheme.colorScheme.outlineVariant
                    .withValues(alpha: 0.35),
                backgroundColor: readerModalTheme.colorScheme.surface,
                clipBehavior: Clip.antiAlias,
                child: content,
              ),
            ),
          ),
        ),
      );
    }

    return Theme(
      data: readerModalTheme,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: _kReaderCatalogInitialSheetSize,
          minChildSize: 0,
          maxChildSize: _kReaderCatalogExpandedSheetSize,
          snap: true,
          snapSizes: const [
            _kReaderCatalogInitialSheetSize,
            _kReaderCatalogExpandedSheetSize,
          ],
          expand: false,
          shouldCloseOnMinExtent: true,
          builder: (context, draggableController) {
            final mobileRadius = BorderRadius.vertical(
              top: Radius.circular(componentTokens.overlay.topRadius),
            );
            return ClipRRect(
              borderRadius: mobileRadius,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: AppSurface(
                  tone: AppSurfaceTone.elevated,
                  padding: EdgeInsets.zero,
                  borderRadius: mobileRadius,
                  borderColor: readerModalTheme.colorScheme.outlineVariant
                      .withValues(alpha: 0.32),
                  backgroundColor: readerModalTheme.colorScheme.surface
                      .withValues(alpha: 0.9),
                  clipBehavior: Clip.antiAlias,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollStartNotification ||
                          notification is UserScrollNotification) {
                        scrollThumbVisible.value = true;
                      } else if (notification is ScrollEndNotification) {
                        scrollThumbVisible.value = false;
                      }
                      return false;
                    },
                    child: ValueListenableBuilder<bool>(
                      valueListenable: scrollThumbVisible,
                      builder: (context, visible, _) {
                        return Scrollbar(
                          controller: draggableController,
                          thumbVisibility: visible,
                          child: CustomScrollView(
                            controller: draggableController,
                            slivers: buildMobileCatalogSlivers(
                              context,
                              listController: draggableController,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  final Future<ReaderCatalogSheetResult?> routeResult;
  if (isDesktopSurface) {
    routeResult = showGeneralDialog<ReaderCatalogSheetResult>(
      context: routeContext,
      barrierDismissible: true,
      barrierLabel: barrierLabel,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder:
              (context, setModalState) => buildCatalogSurface(
                context,
                setModalState,
                isDesktopSurface: true,
              ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  } else {
    // UI-GOV-EXEMPT: modal-surface fixed-visual
    // reason: Reader catalog mobile route is deferred to Phase 12 reader shell migration.
    routeResult = showModalBottomSheet<ReaderCatalogSheetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      isDismissible: true,
      enableDrag: false,
      builder: (context) {
        return StatefulBuilder(
          builder:
              (context, setModalState) => buildCatalogSurface(
                context,
                setModalState,
                isDesktopSurface: false,
              ),
        );
      },
    );
  }
  final result = await routeResult;

  catalogSearchDebounceTimer?.cancel();
  // These objects are still referenced by the bottom sheet route during the
  // dismiss animation and pending callbacks. Let the route release them
  // naturally instead of disposing immediately after await returns.
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
    child: SizedBox(
      height: 46,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
    ),
  );
}

class _ReaderCatalogMobileTabButton extends StatelessWidget {
  const _ReaderCatalogMobileTabButton({
    required this.tab,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final Tab tab;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedColor : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Opacity(
            opacity: selected ? 1 : 0.86,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: tab.child ?? const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    );
  }
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

List<Bookmark> _filterBookmarksForKeyword({
  required List<Bookmark> bookmarks,
  required List<Chapter> chapters,
  required String keyword,
}) {
  final normalizedKeyword = keyword.trim().toLowerCase();
  if (normalizedKeyword.isEmpty) {
    return bookmarks;
  }
  return bookmarks
      .where((bookmark) {
        final chapterTitle = _resolveBookmarkChapterTitle(bookmark, chapters);
        final haystack =
            [
              chapterTitle,
              bookmark.displaySnippet,
              bookmark.note ?? '',
            ].join('\n').toLowerCase();
        return haystack.contains(normalizedKeyword);
      })
      .toList(growable: false);
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
    final componentTokens = appComponentThemeTokensOf(context);
    final isVolume = chapter.isVolume;
    final borderRadius = BorderRadius.all(
      Radius.circular(componentTokens.selection.segmentRadius),
    );
    final iconRadius = BorderRadius.all(
      Radius.circular(componentTokens.selection.chipRadius),
    );
    final pillRadius = BorderRadius.all(
      Radius.circular(componentTokens.button.radius),
    );
    final selectedBackground = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: 0.15),
      colorScheme.surfaceContainerLow,
    );
    final unselectedBackground =
        isVolume
            ? colorScheme.secondaryContainer.withValues(alpha: 0.34)
            : colorScheme.surface.withValues(alpha: 0.78);

    return AppSurface(
      padding: EdgeInsets.zero,
      borderRadius: borderRadius,
      backgroundColor: selected ? selectedBackground : unselectedBackground,
      borderColor:
          selected
              ? colorScheme.primary.withValues(alpha: 0.28)
              : colorScheme.outlineVariant.withValues(alpha: 0.18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    isVolume
                        ? colorScheme.secondaryContainer
                        : selected
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHigh,
                borderRadius: iconRadius,
              ),
              child:
                  isVolume
                      ? Icon(
                        Icons.folder_outlined,
                        size: 14,
                        color: colorScheme.onSecondaryContainer,
                      )
                      : Icon(
                        selected
                            ? Icons.menu_book_rounded
                            : Icons.article_outlined,
                        size: 14,
                        color:
                            selected
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant,
                      ),
            ),
            const SizedBox(width: 7),
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
            const SizedBox(width: 4),
            if (isVolume)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: pillRadius,
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
                size: 16,
                color:
                    selected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
              ),
          ],
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
    final componentTokens = appComponentThemeTokensOf(context);
    final isVolumeEntry = !entry.isContent && entry.isVolume;
    final accentColor =
        entry.isContent
            ? colorScheme.tertiary
            : (isVolumeEntry ? colorScheme.secondary : colorScheme.primary);
    final tileRadius = BorderRadius.all(
      Radius.circular(componentTokens.selection.segmentRadius),
    );
    final iconRadius = BorderRadius.all(
      Radius.circular(componentTokens.selection.chipRadius),
    );
    final pillRadius = BorderRadius.all(
      Radius.circular(componentTokens.button.radius),
    );

    return AppSurface(
      padding: EdgeInsets.zero,
      borderRadius: tileRadius,
      backgroundColor:
          entry.isContent
              ? colorScheme.tertiaryContainer.withValues(alpha: 0.32)
              : isVolumeEntry
              ? colorScheme.secondaryContainer.withValues(alpha: 0.32)
              : colorScheme.surfaceContainerLow,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: iconRadius,
              ),
              child: Icon(
                entry.isContent
                    ? Icons.article_outlined
                    : isVolumeEntry
                    ? Icons.folder_outlined
                    : Icons.list_alt_outlined,
                size: 14,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 7),
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
                  const SizedBox(height: 1),
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
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: pillRadius,
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
    final componentTokens = appComponentThemeTokensOf(context);
    final tileRadius = BorderRadius.all(
      Radius.circular(componentTokens.selection.segmentRadius),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 3),
        ...items.map((bookmark) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: AppSurface(
              padding: EdgeInsets.zero,
              borderRadius: tileRadius,
              backgroundColor: colorScheme.surfaceContainerHighest,
              onTap: () => onTap(bookmark),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(9, 7, 5, 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bookmark.displaySnippet,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                          if (bookmark.hasNote) ...[
                            const SizedBox(height: 3),
                            Text(
                              bookmark.note!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.3,
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
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
                      icon: const Icon(Icons.delete_outline, size: 16),
                      onPressed: () => onDelete(bookmark),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
