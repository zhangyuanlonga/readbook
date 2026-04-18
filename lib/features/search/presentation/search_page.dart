import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/navigation/search_entry_transition.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/theme/app_border_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';

import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/book.dart';
import '../../../runtime/sources/source_registry.dart';
import '../../book/presentation/book_detail_route.dart';
import '../../mine/application/advanced_theme_provider.dart';
import '../../source/application/source_runtime_facade.dart';
import '../application/search_history_service.dart';
import '../application/search_service.dart';
import '../application/search_system_settings_service.dart';
import 'search_render_state_controller.dart';
import 'widgets/search_book_card.dart';
import 'widgets/search_empty_state.dart';
import 'widgets/search_failure_banner.dart';
import 'widgets/search_grouped_empty_fallback_card.dart';
import 'widgets/search_input_card.dart';
import 'widgets/search_progress_card.dart';
import 'widgets/search_report_summary.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, this.hideTopSearchBar = false});

  final bool hideTopSearchBar;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _keywordController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final SourceRuntimeFacade _sourceRuntimeFacade = SourceRuntimeFacade.instance;
  late final SearchService _searchService;
  final SearchHistoryService _historyService = SearchHistoryService();
  final SearchSystemSettingsService _searchSystemSettingsService =
      SearchSystemSettingsService();

  static const Duration _progressUiThrottleWindow = Duration(
    milliseconds: 1500,
  );
  static const Duration _sourceCountLoadTimeout = Duration(seconds: 8);
  static const Set<PointerDeviceKind> _dragDevices = <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };
  static const int _searchResultPageSize = 40;
  static const double _paginationTriggerDistance = 280;
  static const Duration _scrollUiResumeDelay = Duration(milliseconds: 180);
  static const Duration _scrollUiMaxDeferredWindow = Duration(seconds: 2);

  bool _isSearching = false;
  bool _isLoadingSourceCount = false;
  final ValueNotifier<SearchExecutionReport?> _progressReportNotifier =
      ValueNotifier<SearchExecutionReport?>(null);
  final SearchRenderStateController _renderStateController =
      SearchRenderStateController(pageSize: _searchResultPageSize);
  SearchCancellationToken? _activeSearchToken;
  int _searchSessionId = 0;
  SearchContentMode _searchContentMode = SearchContentMode.novel;
  bool _isPreciseBookMatch = false;
  bool _aggregateByTitleAuthorEnabled = true;
  int _availableSourceCount = 0;
  Set<String> _selectedSourceIds = <String>{};
  final ScrollController _pageScrollController = ScrollController();
  bool _isAppendingResults = false;
  SearchExecutionReport? _pendingProgressReport;
  Timer? _progressUiTimer;
  DateTime? _lastProgressUiUpdateAt;
  bool _isListScrollActive = false;
  Timer? _scrollUiResumeTimer;
  Timer? _scrollUiForceFlushTimer;
  _DeferredProgressUiUpdate? _deferredProgressUiUpdate;
  int? _pendingSearchCompletionSessionId;
  SearchCancellationToken? _pendingSearchCompletionToken;

  // Search history
  List<String> _searchHistory = const <String>[];

  @override
  void initState() {
    super.initState();
    _searchService = SearchService(sourceRuntimeFacade: _sourceRuntimeFacade);
    _pageScrollController.addListener(_onPageScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refreshSourceCount());
      unawaited(_loadSearchHistory());
      unawaited(_loadSearchSystemSettings());
    });
  }

  @override
  void dispose() {
    _activeSearchToken?.cancel();
    _clearProgressUiThrottle();
    _clearDeferredProgressUiUpdate();
    _clearPendingSearchCompletion();
    _pageScrollController.removeListener(_onPageScroll);
    _pageScrollController.dispose();
    _progressReportNotifier.dispose();
    _renderStateController.dispose();
    _searchFocusNode.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.watch(activeAdvancedThemeProvider);
    final palette = resolveAdvancedThemePalette(
      theme.colorScheme,
      ref.read(activeAdvancedThemeProvider).valueOrNull,
    );
    final backdrop = resolveAdvancedThemeBackdrop(
      theme.colorScheme,
      ref.read(activeAdvancedThemeProvider).valueOrNull,
    );
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final canPopRoute = context.canPop();
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return PopScope<void>(
      canPop: canPopRoute,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !mounted) return;
        context.go('/bookshelf');
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
          titleSpacing:
              widget.hideTopSearchBar ? NavigationToolbar.kMiddleSpacing : 0,
          title:
              widget.hideTopSearchBar
                  ? const Text('搜索')
                  : _buildSearchBar(context, palette),
        ),
        body: DecoratedBox(
          decoration: buildAdvancedThemeBackdropDecoration(backdrop),
          child: LayoutBuilder(
            builder: (context, _) {
              final maxWidth = AppLayout.pageContentMaxWidth(
                context,
                maxWidth: AppLayout.searchContentMaxWidth,
              );

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: ScrollConfiguration(
                    behavior: const MaterialScrollBehavior().copyWith(
                      dragDevices: _dragDevices,
                    ),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _onScrollNotification,
                      child: CustomScrollView(
                        controller: _pageScrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        slivers: [
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              horizontal,
                              topInset + 12,
                              horizontal,
                              0,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: SearchInputCard(
                                isSearching: _isSearching,
                                searchContentMode: _searchContentMode,
                                isPreciseBookMatch: _isPreciseBookMatch,
                                selectedSourceCount: _selectedSourceIds.length,
                                availableSourceCount: _availableSourceCount,
                                isLoadingSourceCount: _isLoadingSourceCount,
                                modeActiveBackgroundColor: palette.primaryColor,
                                modeActiveForegroundColor:
                                    palette.buttonTextColor,
                                optionActiveBackgroundColor:
                                    palette.primaryContainerColor,
                                optionActiveForegroundColor:
                                    palette.textPrimaryColor,
                                onClearResults: _clearResults,
                                onContentModeChanged: _onContentModeChanged,
                                onPreciseMatchChanged: _onPreciseMatchChanged,
                                onOpenSourceFilter:
                                    () => unawaited(_showSourceFilterSheet()),
                                onClearSourceFilter: _clearSourceFilter,
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              horizontal,
                              0,
                              horizontal,
                              0,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: ValueListenableBuilder<
                                SearchExecutionReport?
                              >(
                                valueListenable: _progressReportNotifier,
                                builder: (context, report, _) {
                                  if (!_isSearching) {
                                    return const SizedBox.shrink();
                                  }
                                  return SearchProgressCard(
                                    report: report,
                                    isSearching: _isSearching,
                                  );
                                },
                              ),
                            ),
                          ),
                          ValueListenableBuilder<SearchRenderState?>(
                            valueListenable:
                                _renderStateController.renderStateNotifier,
                            builder: (context, renderState, _) {
                              if (renderState == null) {
                                if (_isSearching) {
                                  return SliverPadding(
                                    padding: EdgeInsets.only(
                                      bottom: 16 + bottomSafe,
                                    ),
                                    sliver: const SliverToBoxAdapter(
                                      child: SizedBox.shrink(),
                                    ),
                                  );
                                }
                                return SliverPadding(
                                  padding: EdgeInsets.fromLTRB(
                                    horizontal,
                                    8,
                                    horizontal,
                                    16 + bottomSafe,
                                  ),
                                  sliver: SliverToBoxAdapter(
                                    child: SearchEmptyState(
                                      history: _searchHistory,
                                      onHistoryTap: _onHistoryTap,
                                      onClearHistory: _onClearHistory,
                                      onRemoveHistoryItem: _onRemoveHistoryItem,
                                    ),
                                  ),
                                );
                              }

                              final report = renderState.report;
                              final books = renderState.visibleBooks;
                              final visibleCount = renderState
                                  .renderedResultCount
                                  .clamp(0, books.length);

                              if (books.isEmpty) {
                                return SliverPadding(
                                  padding: EdgeInsets.fromLTRB(
                                    horizontal,
                                    8,
                                    horizontal,
                                    16 + bottomSafe,
                                  ),
                                  sliver: SliverToBoxAdapter(
                                    child: SearchGroupedEmptyFallbackCard(
                                      canDisablePrecise:
                                          _isPreciseBookMatch &&
                                          report.books.isNotEmpty,
                                      canSwitchAllSources:
                                          _selectedSourceIds.isNotEmpty,
                                      onDisablePreciseMatch:
                                          _disablePreciseMatchFallback,
                                      onSwitchAllSources:
                                          () => unawaited(
                                            _switchToAllSourcesFallback(),
                                          ),
                                    ),
                                  ),
                                );
                              }

                              return SliverPadding(
                                padding: EdgeInsets.fromLTRB(
                                  horizontal,
                                  8,
                                  horizontal,
                                  16 + bottomSafe,
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    if (index == 0) {
                                      return Column(
                                        children: [
                                          SearchReportSummary(
                                            report: report,
                                            visibleBookCount: books.length,
                                            isPreciseBookMatch:
                                                _isPreciseBookMatch,
                                          ),
                                          if (report.failures.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            SearchFailureBanner(report: report),
                                          ],
                                          const SizedBox(height: 10),
                                        ],
                                      );
                                    }

                                    final book = books[index - 1];
                                    final sourceName =
                                        report.sourceNames[book.sourceId] ??
                                        book.sourceId;
                                    final heroTag = _buildBookCoverHeroTag(
                                      book: book,
                                      listIndex: index - 1,
                                    );

                                    return SearchBookCard(
                                      book: book,
                                      sourceName: sourceName,
                                      sourceHitCount: report.sourceHitCountOf(
                                        book,
                                      ),
                                      heroTag: heroTag,
                                      normalizedIntro:
                                          renderState.normalizedIntros[book.id],
                                      normalizedLatestChapter:
                                          renderState
                                              .normalizedLatestChapters[book
                                              .id],
                                      onTap: () async {
                                        final selected =
                                            await _pickSearchResultSource(
                                              report: report,
                                              primaryBook: book,
                                            );
                                        if (selected == null || !mounted) {
                                          return;
                                        }
                                        final selectedHeroTag =
                                            selected.id == book.id
                                                ? heroTag
                                                : _buildBookCoverHeroTag(
                                                  book: selected,
                                                  listIndex: index - 1,
                                                );
                                        await _openBookDetail(
                                          selected,
                                          heroTag: selectedHeroTag,
                                        );
                                      },
                                    );
                                  }, childCount: visibleCount + 1),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Navigation ──

  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/bookshelf');
  }

  Widget _buildSearchBar(
    BuildContext context,
    ResolvedAdvancedThemePalette palette,
  ) {
    final theme = Theme.of(context);
    final isMangaMode = _searchContentMode == SearchContentMode.manga;
    final hintText = isMangaMode ? '输入漫画名或作者' : '输入书名或作者';

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Hero(
        tag: kSearchEntryHeroTag,
        createRectTween:
            (begin, end) => MaterialRectCenterArcTween(begin: begin, end: end),
        child: Material(
          color: Colors.transparent,
          child: SizedBox(
            height: 42,
            child: TextField(
              controller: _keywordController,
              focusNode: _searchFocusNode,
              autofocus: false,
              textInputAction: TextInputAction.search,
              textAlignVertical: TextAlignVertical.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                height: 1.2,
              ),
              onSubmitted: (_) => _runSearch(),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  height: 1.2,
                  color: palette.textSecondaryColor,
                ),
                filled: true,
                fillColor: palette.searchFieldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: resolveAppBorderSide(
                    theme.colorScheme,
                    baseColor: palette.outlineColor,
                    containerColor: palette.searchFieldBackgroundColor,
                    tone: AppBorderTone.strong,
                    width: 1.2,
                  ),
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _keywordController,
                  builder: (_, value, __) {
                    if (_isSearching) {
                      return IconButton(
                        tooltip: '取消搜索',
                        onPressed: _runSearch,
                        icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      );
                    }
                    if (value.text.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return IconButton(
                      tooltip: '清空输入',
                      onPressed: () => _keywordController.clear(),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    );
                  },
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Callbacks for SearchInputCard ──

  void _onContentModeChanged(SearchContentMode mode) {
    setState(() {
      _searchContentMode = mode;
      _selectedSourceIds = <String>{};
    });
    _clearSearchOutput();
    unawaited(_refreshSourceCount());
  }

  void _onPreciseMatchChanged(bool value) {
    if (_isPreciseBookMatch == value) {
      return;
    }
    setState(() {
      _isPreciseBookMatch = value;
    });
    final report = _progressReportNotifier.value;
    if (report != null) {
      final sessionId = _searchSessionId;
      final token = _activeSearchToken;
      _schedulePrepareRenderState(
        report: report,
        sessionId: sessionId,
        token: token,
        force: true,
      );
    }
  }

  void _clearResults() {
    _keywordController.clear();
    _clearSearchOutput();
  }

  void _clearSourceFilter() {
    setState(() {
      _selectedSourceIds = <String>{};
    });
    _clearSearchOutput();
  }

  // ── Search History ──

  Future<void> _loadSearchSystemSettings() async {
    try {
      final enabled =
          await _searchSystemSettingsService
              .loadAggregateByTitleAuthorEnabled();
      final debugLogEnabled =
          await _searchSystemSettingsService.loadSearchDebugLogEnabled();
      final maxConcurrentSources =
          await _searchSystemSettingsService.loadMaxConcurrentSources();
      _searchService.setSearchDebugLoggingEnabled(debugLogEnabled);
      _searchService.setMaxConcurrentSources(maxConcurrentSources);
      if (!mounted) {
        return;
      }
      setState(() {
        _aggregateByTitleAuthorEnabled = enabled;
      });
    } catch (_) {
      // Keep default when settings loading fails.
    }
  }

  Future<void> _loadSearchHistory() async {
    final history = await _historyService.getAll();
    if (!mounted) return;
    setState(() {
      _searchHistory = history;
    });
  }

  void _onHistoryTap(String keyword) {
    _keywordController.text = keyword;
    _keywordController.selection = TextSelection.fromPosition(
      TextPosition(offset: keyword.length),
    );
    _runSearch();
  }

  void _onClearHistory() {
    unawaited(_historyService.clear());
    setState(() {
      _searchHistory = const <String>[];
    });
  }

  void _onRemoveHistoryItem(String keyword) {
    unawaited(
      _historyService.remove(keyword).then((_) => _loadSearchHistory()),
    );
    // Optimistic UI: remove immediately
    setState(() {
      _searchHistory = _searchHistory
          .where((item) => item != keyword)
          .toList(growable: false);
    });
  }

  // ── Source filter ──

  Future<void> _refreshSourceCount() async {
    if (!mounted) return;

    final requestedMode = _searchContentMode;

    setState(() {
      _isLoadingSourceCount = true;
    });

    try {
      final sources = await _loadAvailableScriptSourcesForUi(
        contentMode: requestedMode,
      ).timeout(_sourceCountLoadTimeout);

      if (!mounted || requestedMode != _searchContentMode) {
        return;
      }

      final availableSourceIds =
          sources.map((source) => source.runtime.id).toSet();
      final nextSelectedSourceIds =
          _selectedSourceIds.where(availableSourceIds.contains).toSet();

      setState(() {
        _availableSourceCount = sources.length;
        _selectedSourceIds = nextSelectedSourceIds;
      });
    } catch (error) {
      if (!mounted || requestedMode != _searchContentMode) {
        return;
      }

      debugPrint('Failed to load source count: $error');
      setState(() {
        _availableSourceCount = 0;
      });
    } finally {
      if (mounted && requestedMode == _searchContentMode) {
        setState(() {
          _isLoadingSourceCount = false;
        });
      }
    }
  }

  Future<void> _showSourceFilterSheet() async {
    final requestedMode = _searchContentMode;
    final sources = await _loadAvailableScriptSourcesForUi(
      contentMode: requestedMode,
    );
    if (!mounted || requestedMode != _searchContentMode) {
      return;
    }

    final filterItems = sources
        .map(
          (source) => _ScriptSourceFilterItem(
            id: source.runtime.id,
            name: source.runtime.name,
            group:
                source.runtime.group.trim().isEmpty
                    ? null
                    : source.runtime.group.trim(),
          ),
        )
        .toList(growable: false);
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder:
          (context) => _ScriptSourceFilterSheet(
            items: filterItems,
            initialSelectedIds: _selectedSourceIds,
          ),
    );

    if (!mounted || requestedMode != _searchContentMode || selected == null) {
      return;
    }
    final allowedIds = filterItems.map((item) => item.id).toSet();
    final normalized = selected.where(allowedIds.contains).toSet();

    setState(() {
      _selectedSourceIds = normalized;
    });
    _clearSearchOutput();
  }

  Future<List<RegisteredSource>> _loadAvailableScriptSourcesForUi({
    required SearchContentMode contentMode,
  }) async {
    var sources = _sourceRuntimeFacade.registeredScriptSources(
      enabledOnly: true,
    );
    if (sources.isEmpty) {
      final report = await _sourceRuntimeFacade.reloadScriptSources();
      sources = report.loaded;
    }

    final filtered = sources
        .where(
          (source) =>
              _matchesScriptSourceContentMode(source, contentMode: contentMode),
        )
        .toList(growable: false);
    filtered.sort((a, b) {
      final groupCompare = a.runtime.group.toLowerCase().compareTo(
        b.runtime.group.toLowerCase(),
      );
      if (groupCompare != 0) {
        return groupCompare;
      }
      return a.runtime.name.toLowerCase().compareTo(
        b.runtime.name.toLowerCase(),
      );
    });
    return filtered;
  }

  bool _matchesScriptSourceContentMode(
    RegisteredSource source, {
    required SearchContentMode contentMode,
  }) {
    final capabilities =
        source.definition.manifest.capabilities
            .map((item) => item.trim().toLowerCase())
            .where((item) => item.isNotEmpty)
            .toSet();
    final declaresManga =
        capabilities.contains('manga') ||
        capabilities.contains('comic') ||
        capabilities.contains('manhua') ||
        capabilities.contains('manhwa');
    final declaresNovel =
        capabilities.contains('novel') ||
        capabilities.contains('book') ||
        capabilities.contains('text');

    if (contentMode == SearchContentMode.manga) {
      return declaresManga;
    }

    if (declaresManga && !declaresNovel) {
      return false;
    }
    return true;
  }

  // ── Scroll pagination ──

  void _onPageScroll() {
    if (!_pageScrollController.hasClients || _isSearching) return;

    final position = _pageScrollController.position;
    if (position.pixels + _paginationTriggerDistance <
        position.maxScrollExtent) {
      return;
    }

    _appendMoreRenderedResults();
  }

  void _appendMoreRenderedResults() {
    if (_isAppendingResults) return;

    final renderState = _renderStateController.renderStateNotifier.value;
    if (renderState == null) return;

    final total = renderState.visibleBooks.length;
    if (total == 0 || renderState.renderedResultCount >= total) return;

    _isAppendingResults = true;
    _renderStateController.appendMoreResults();
    _isAppendingResults = false;
    _scheduleAutoAppendIfNeeded();
  }

  void _scheduleAutoAppendIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isSearching || _isAppendingResults) return;
      if (!_pageScrollController.hasClients) return;
      final renderState = _renderStateController.renderStateNotifier.value;
      if (renderState == null) return;
      if (renderState.renderedResultCount >= renderState.visibleBooks.length) {
        return;
      }

      final position = _pageScrollController.position;
      final isNearBottom =
          position.pixels + _paginationTriggerDistance >=
          position.maxScrollExtent;
      final isScrollable = position.maxScrollExtent > 0;

      if (!isScrollable || isNearBottom) {
        _appendMoreRenderedResults();
      }
    });
  }

  // ── Report preparation ──

  void _clearSearchOutput() {
    _clearProgressUiThrottle();
    _clearDeferredProgressUiUpdate();
    _clearPendingSearchCompletion();
    _progressReportNotifier.value = null;
    _renderStateController.clear();
  }

  Future<void> _prepareRenderState({
    required SearchExecutionReport report,
    required int sessionId,
    SearchCancellationToken? token,
    bool force = false,
  }) async {
    await _renderStateController.prepareRenderState(
      report: report,
      sessionId: sessionId,
      activeSessionId: _searchSessionId,
      preciseMatch: _isPreciseBookMatch,
      token: token,
      force: force,
    );
    _scheduleAutoAppendIfNeeded();
  }

  String _buildBookCoverHeroTag({required Book book, required int listIndex}) {
    return 'book_cover_${book.sourceId}_${book.id}_${book.detailUrl.hashCode}_$listIndex';
  }

  Future<Book?> _pickSearchResultSource({
    required SearchExecutionReport report,
    required Book primaryBook,
  }) async {
    final candidates = report.sourceHitsOf(primaryBook);
    if (candidates.length <= 1) {
      return primaryBook;
    }

    return showModalBottomSheet<Book>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '选择来源（${candidates.length}）',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder:
                      (context, _) => const Divider(height: 1, thickness: 0.5),
                  itemBuilder: (context, index) {
                    final candidate = candidates[index];
                    final sourceName =
                        report.sourceNames[candidate.sourceId] ??
                        candidate.sourceId;
                    final subtitle = candidate.latestChapter?.trim();
                    return ListTile(
                      title: Text(sourceName),
                      subtitle:
                          subtitle == null || subtitle.isEmpty
                              ? null
                              : Text(
                                '最新：$subtitle',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      onTap: () => Navigator.of(context).pop(candidate),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openBookDetail(Book book, {required String heroTag}) async {
    final route = buildBookDetailRoute(
      bookId: book.id,
      sourceId: book.sourceId,
      detailUrl: book.detailUrl,
      title: book.title,
      heroTag: heroTag,
    );
    _pauseActiveSearchIfNeeded();
    try {
      await context.push(route);
    } finally {
      if (mounted) {
        _resumeActiveSearchIfNeeded();
      }
    }
  }

  void _pauseActiveSearchIfNeeded() {
    final token = _activeSearchToken;
    if (token == null || token.isCancelled || token.isPaused) {
      return;
    }
    token.pause();
  }

  void _resumeActiveSearchIfNeeded() {
    final token = _activeSearchToken;
    if (token == null || token.isCancelled || !token.isPaused) {
      return;
    }
    token.resume();
  }

  void _disablePreciseMatchFallback() {
    if (!_isPreciseBookMatch) {
      return;
    }
    _onPreciseMatchChanged(false);
  }

  Future<void> _switchToAllSourcesFallback() async {
    if (_selectedSourceIds.isEmpty || _isSearching) {
      return;
    }
    setState(() {
      _selectedSourceIds = <String>{};
    });
    await _runSearch();
  }

  // ── Progress throttling ──

  void _clearProgressUiThrottle() {
    _progressUiTimer?.cancel();
    _progressUiTimer = null;
    _pendingProgressReport = null;
    _lastProgressUiUpdateAt = null;
  }

  void _updateProgressReportThrottled({
    required SearchExecutionReport report,
    required SearchCancellationToken token,
    required int sessionId,
  }) {
    final now = DateTime.now();
    final lastUpdateAt = _lastProgressUiUpdateAt;
    final shouldFlushNow =
        lastUpdateAt == null ||
        now.difference(lastUpdateAt) >= _progressUiThrottleWindow ||
        report.processedSourceCount >= report.sourceCount;

    if (shouldFlushNow) {
      _progressUiTimer?.cancel();
      _progressUiTimer = null;
      _pendingProgressReport = null;
      _lastProgressUiUpdateAt = now;
      _applyProgressReport(report: report, token: token, sessionId: sessionId);
      return;
    }

    _pendingProgressReport = report;
    if (_progressUiTimer?.isActive ?? false) return;

    final delay = _progressUiThrottleWindow - now.difference(lastUpdateAt);
    _progressUiTimer = Timer(delay, () {
      _progressUiTimer = null;
      final pending = _pendingProgressReport;
      _pendingProgressReport = null;
      if (pending == null ||
          !mounted ||
          token.isCancelled ||
          sessionId != _searchSessionId) {
        return;
      }

      _lastProgressUiUpdateAt = DateTime.now();
      _applyProgressReport(report: pending, token: token, sessionId: sessionId);
    });
  }

  void _applyProgressReport({
    required SearchExecutionReport report,
    required SearchCancellationToken token,
    required int sessionId,
    bool forceRenderState = false,
  }) {
    if (!mounted || token.isCancelled || sessionId != _searchSessionId) {
      return;
    }
    if (_isListScrollActive) {
      _deferredProgressUiUpdate = _DeferredProgressUiUpdate(
        report: report,
        token: token,
        sessionId: sessionId,
        forceRenderState:
            forceRenderState ||
            (_deferredProgressUiUpdate?.forceRenderState ?? false),
        isFinalReport: false,
      );
      _ensureDeferredProgressFlushDeadline();
      return;
    }
    _applyProgressReportNow(
      report: report,
      token: token,
      sessionId: sessionId,
      forceRenderState: forceRenderState,
    );
  }

  Future<bool> _applyFinalProgressReport({
    required SearchExecutionReport report,
    required SearchCancellationToken token,
    required int sessionId,
  }) async {
    if (!mounted || token.isCancelled || sessionId != _searchSessionId) {
      return true;
    }
    if (_isListScrollActive) {
      _deferredProgressUiUpdate = _DeferredProgressUiUpdate(
        report: report,
        token: token,
        sessionId: sessionId,
        forceRenderState: false,
        isFinalReport: true,
      );
      _ensureDeferredProgressFlushDeadline();
      return false;
    }
    await _applyFinalProgressReportNow(
      report: report,
      token: token,
      sessionId: sessionId,
      forceRenderState: false,
    );
    return true;
  }

  void _applyProgressReportNow({
    required SearchExecutionReport report,
    required SearchCancellationToken token,
    required int sessionId,
    required bool forceRenderState,
  }) {
    if (!mounted || token.isCancelled || sessionId != _searchSessionId) {
      return;
    }
    _progressReportNotifier.value = report;
    _schedulePrepareRenderState(
      report: report,
      sessionId: sessionId,
      token: token,
      force: forceRenderState,
    );
  }

  Future<void> _applyFinalProgressReportNow({
    required SearchExecutionReport report,
    required SearchCancellationToken token,
    required int sessionId,
    required bool forceRenderState,
  }) async {
    if (!mounted || token.isCancelled || sessionId != _searchSessionId) {
      return;
    }
    _progressReportNotifier.value = report;
    await _prepareRenderState(
      report: report,
      sessionId: sessionId,
      token: token,
      force: forceRenderState,
    );
    _completePendingSearchIfMatch(sessionId: sessionId, token: token);
  }

  void _ensureDeferredProgressFlushDeadline() {
    if (_scrollUiForceFlushTimer?.isActive ?? false) {
      return;
    }
    _scrollUiForceFlushTimer = Timer(_scrollUiMaxDeferredWindow, () {
      _scrollUiForceFlushTimer = null;
      _isListScrollActive = false;
      unawaited(_flushDeferredProgressUiUpdate());
    });
  }

  void _schedulePrepareRenderState({
    required SearchExecutionReport report,
    required int sessionId,
    SearchCancellationToken? token,
    bool force = false,
  }) {
    unawaited(
      _prepareRenderState(
        report: report,
        sessionId: sessionId,
        token: token,
        force: force,
      ).catchError((error, stackTrace) {
        debugPrint('Prepare render state failed: $error');
      }),
    );
  }

  // ── Search execution ──

  Future<void> _runSearch() async {
    if (_isSearching) {
      _cancelSearch();
      return;
    }

    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) {
      _showMessage('请输入关键词。');
      return;
    }

    FocusScope.of(context).unfocus();

    final sessionId = ++_searchSessionId;
    final token = SearchCancellationToken();
    _activeSearchToken = token;
    var pendingFinalUiCompletion = false;

    _clearSearchOutput();
    setState(() {
      _isSearching = true;
    });

    try {
      final report = await _searchService.search(
        keyword: keyword,
        contentMode: _searchContentMode,
        sourceIds:
            _selectedSourceIds.isEmpty
                ? null
                : _selectedSourceIds.toList(growable: false),
        aggregateByTitleAuthor: _aggregateByTitleAuthorEnabled,
        cancellationToken: token,
        onProgress: (progress) {
          if (!mounted || token.isCancelled || sessionId != _searchSessionId) {
            return;
          }
          _updateProgressReportThrottled(
            report: progress,
            token: token,
            sessionId: sessionId,
          );
        },
      );

      if (!mounted || token.isCancelled || sessionId != _searchSessionId) {
        return;
      }

      final finalApplied = await _applyFinalProgressReport(
        report: report,
        sessionId: sessionId,
        token: token,
      );
      pendingFinalUiCompletion = !finalApplied;
      if (pendingFinalUiCompletion) {
        _pendingSearchCompletionSessionId = sessionId;
        _pendingSearchCompletionToken = token;
      }

      // Save to search history
      unawaited(_historyService.add(keyword).then((_) => _loadSearchHistory()));

      if (report.books.isEmpty) {
        _showMessage('搜索完成，但没有命中结果。');
      }
    } on AppException catch (error) {
      if (!mounted || token.isCancelled || sessionId != _searchSessionId) {
        return;
      }
      _showMessage(error.briefMessage);
    } catch (error) {
      if (!mounted || token.isCancelled || sessionId != _searchSessionId) {
        return;
      }
      debugPrint('Search failed: $error');
      _showMessage('搜索失败，请稍后重试。');
    } finally {
      _clearProgressUiThrottle();
      if (mounted && sessionId == _searchSessionId) {
        final shouldDelayCompletion =
            pendingFinalUiCompletion &&
            _pendingSearchCompletionSessionId == sessionId &&
            identical(_pendingSearchCompletionToken, token);
        if (!shouldDelayCompletion) {
          setState(() {
            _isSearching = false;
            if (identical(_activeSearchToken, token)) {
              _activeSearchToken = null;
            }
          });
          _clearPendingSearchCompletion();
        }
      }
    }
  }

  void _cancelSearch() {
    if (!_isSearching) return;

    _activeSearchToken?.cancel();
    _clearProgressUiThrottle();
    _clearDeferredProgressUiUpdate();
    _clearPendingSearchCompletion();
    setState(() {
      _isSearching = false;
      _activeSearchToken = null;
    });
    _showMessage('已取消搜索。');
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) {
      return false;
    }
    if (notification is ScrollStartNotification ||
        notification is ScrollUpdateNotification ||
        notification is OverscrollNotification ||
        (notification is UserScrollNotification &&
            notification.direction != ScrollDirection.idle)) {
      _isListScrollActive = true;
      _scrollUiResumeTimer?.cancel();
      _scrollUiResumeTimer = null;
      return false;
    }
    if (notification is ScrollEndNotification ||
        (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle)) {
      _scheduleApplyDeferredUiUpdate();
    }
    return false;
  }

  void _scheduleApplyDeferredUiUpdate() {
    _scrollUiResumeTimer?.cancel();
    _scrollUiResumeTimer = Timer(_scrollUiResumeDelay, () {
      _scrollUiResumeTimer = null;
      _isListScrollActive = false;
      unawaited(_flushDeferredProgressUiUpdate());
    });
  }

  Future<void> _flushDeferredProgressUiUpdate() async {
    _scrollUiResumeTimer?.cancel();
    _scrollUiResumeTimer = null;
    _scrollUiForceFlushTimer?.cancel();
    _scrollUiForceFlushTimer = null;
    final deferred = _deferredProgressUiUpdate;
    if (deferred == null) {
      return;
    }
    _deferredProgressUiUpdate = null;
    if (!mounted ||
        deferred.token.isCancelled ||
        deferred.sessionId != _searchSessionId) {
      return;
    }
    if (deferred.isFinalReport) {
      await _applyFinalProgressReportNow(
        report: deferred.report,
        token: deferred.token,
        sessionId: deferred.sessionId,
        forceRenderState: deferred.forceRenderState,
      );
      return;
    }
    _applyProgressReportNow(
      report: deferred.report,
      token: deferred.token,
      sessionId: deferred.sessionId,
      forceRenderState: deferred.forceRenderState,
    );
  }

  void _completePendingSearchIfMatch({
    required int sessionId,
    required SearchCancellationToken token,
  }) {
    if (!mounted || sessionId != _searchSessionId) {
      return;
    }
    if (_pendingSearchCompletionSessionId != sessionId ||
        !identical(_pendingSearchCompletionToken, token)) {
      return;
    }
    setState(() {
      _isSearching = false;
      if (identical(_activeSearchToken, token)) {
        _activeSearchToken = null;
      }
    });
    _clearPendingSearchCompletion();
  }

  void _clearPendingSearchCompletion() {
    _pendingSearchCompletionSessionId = null;
    _pendingSearchCompletionToken = null;
  }

  void _clearDeferredProgressUiUpdate() {
    _scrollUiResumeTimer?.cancel();
    _scrollUiResumeTimer = null;
    _scrollUiForceFlushTimer?.cancel();
    _scrollUiForceFlushTimer = null;
    _deferredProgressUiUpdate = null;
    _isListScrollActive = false;
  }
}

class _DeferredProgressUiUpdate {
  const _DeferredProgressUiUpdate({
    required this.report,
    required this.token,
    required this.sessionId,
    required this.forceRenderState,
    required this.isFinalReport,
  });

  final SearchExecutionReport report;
  final SearchCancellationToken token;
  final int sessionId;
  final bool forceRenderState;
  final bool isFinalReport;
}

class _ScriptSourceFilterItem {
  const _ScriptSourceFilterItem({
    required this.id,
    required this.name,
    this.group,
  });

  final String id;
  final String name;
  final String? group;
}

class _ScriptSourceFilterSheet extends StatefulWidget {
  const _ScriptSourceFilterSheet({
    required this.items,
    required this.initialSelectedIds,
  });

  final List<_ScriptSourceFilterItem> items;
  final Set<String> initialSelectedIds;

  @override
  State<_ScriptSourceFilterSheet> createState() =>
      _ScriptSourceFilterSheetState();
}

class _ScriptSourceFilterSheetState extends State<_ScriptSourceFilterSheet> {
  late final Set<String> _allIds;
  late Set<String> _draftSelectedIds;
  final TextEditingController _filterController = TextEditingController();
  String _filterKeyword = '';

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _allIds = widget.items.map((item) => item.id).toSet();
    _draftSelectedIds =
        widget.initialSelectedIds.isEmpty
            ? <String>{..._allIds}
            : widget.initialSelectedIds.where(_allIds.contains).toSet();
    if (_allIds.isNotEmpty && _draftSelectedIds.isEmpty) {
      _draftSelectedIds = <String>{..._allIds};
    }
  }

  bool get _allSelected =>
      _allIds.isNotEmpty && _draftSelectedIds.length == _allIds.length;

  List<_ScriptSourceFilterItem> get _visibleItems {
    final keyword = _filterKeyword.trim().toLowerCase();
    if (keyword.isEmpty) {
      return widget.items;
    }
    return widget.items
        .where((item) {
          final group = item.group?.trim().toLowerCase() ?? '';
          return item.name.toLowerCase().contains(keyword) ||
              group.contains(keyword);
        })
        .toList(growable: false);
  }

  Set<String> _resultSelection() {
    if (_allIds.isEmpty || _draftSelectedIds.length == _allIds.length) {
      return <String>{};
    }
    return Set<String>.of(_draftSelectedIds);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('指定书源', style: theme.textTheme.titleMedium),
                  ),
                  Text(
                    '共 ${widget.items.length} 个',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (widget.items.isEmpty)
              Expanded(
                child: Center(
                  child: Text('当前模式下没有可用书源', style: theme.textTheme.bodyMedium),
                ),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        controller: _filterController,
                        onChanged: (value) {
                          setState(() {
                            _filterKeyword = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: '筛选书源名称或分组',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 18,
                          ),
                          suffixIcon:
                              _filterKeyword.isEmpty
                                  ? null
                                  : IconButton(
                                    tooltip: '清空筛选',
                                    onPressed: () {
                                      _filterController.clear();
                                      setState(() {
                                        _filterKeyword = '';
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                    ),
                                  ),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            _draftSelectedIds.isEmpty
                                ? '当前未勾选，应用后将恢复全部书源'
                                : '已选 ${_draftSelectedIds.length} / ${widget.items.length}',
                            style: theme.textTheme.bodySmall,
                          ),
                          const Spacer(),
                          Opacity(
                            opacity: _draftSelectedIds.isNotEmpty ? 1 : 0.45,
                            child: TextButton(
                              onPressed:
                                  _draftSelectedIds.isNotEmpty
                                      ? () {
                                        setState(() {
                                          _draftSelectedIds.clear();
                                        });
                                      }
                                      : null,
                              child: const Text('清空勾选'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child:
                          _visibleItems.isEmpty
                              ? Center(
                                child: Text(
                                  '没有匹配的书源',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              )
                              : ListView(
                                children: [
                                  CheckboxListTile(
                                    value: _allSelected,
                                    title: Text(
                                      '全部书源 (${widget.items.length})',
                                    ),
                                    subtitle:
                                        _draftSelectedIds.isEmpty
                                            ? const Text('不指定时默认搜索全部书源')
                                            : null,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          _draftSelectedIds = <String>{
                                            ..._allIds,
                                          };
                                        } else {
                                          _draftSelectedIds.clear();
                                        }
                                      });
                                    },
                                  ),
                                  ..._visibleItems.map((item) {
                                    final selected = _draftSelectedIds.contains(
                                      item.id,
                                    );
                                    return CheckboxListTile(
                                      value: selected,
                                      title: Text(item.name),
                                      subtitle:
                                          item.group == null ||
                                                  item.group!.trim().isEmpty
                                              ? null
                                              : Text(item.group!),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      onChanged: (value) {
                                        setState(() {
                                          if (value == true) {
                                            _draftSelectedIds.add(item.id);
                                          } else {
                                            _draftSelectedIds.remove(item.id);
                                          }
                                        });
                                      },
                                    );
                                  }),
                                ],
                              ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (_draftSelectedIds.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请至少勾选一个书源')),
                          );
                          return;
                        }
                        Navigator.of(context).pop(_resultSelection());
                      },
                      child: const Text('应用筛选'),
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
}
