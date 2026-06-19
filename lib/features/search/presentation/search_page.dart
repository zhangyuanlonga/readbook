import 'dart:async';

import 'package:circular_theme_reveal/circular_theme_reveal.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/layout/app_adaptive.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/navigation/search_entry_transition.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/theme/app_border_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../app/widgets/adaptive_overflow_toolbar.dart';
import '../../../app/widgets/adaptive_route_top_bar.dart';
import '../../../app/widgets/adaptive_search_bar.dart';
import '../../../app/widgets/foundation/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/logging/app_logger.dart';
import '../../../domain/entities/book.dart';
import '../../book/application/book_display_state.dart';
import '../../book/application/book_presentation_query_service.dart';
import '../../book/presentation/book_detail_route.dart';
import '../../mine/application/advanced_theme_provider.dart';
import '../application/search_execution_controller.dart';
import '../application/search_page_state.dart';
import '../application/search_service.dart';
import '../application/search_history_service.dart';
import '../application/server_online_search_service.dart';
import '../application/search_system_settings_service.dart';
import '../providers.dart';
import 'online_source_error_presentation.dart';
import 'search_render_state_controller.dart';
import 'widgets/search_empty_state.dart';
import 'widgets/search_failure_banner.dart';
import 'widgets/search_grouped_empty_fallback_card.dart';
import 'widgets/search_input_card.dart';
import 'widgets/search_results_sliver.dart';
import 'widgets/search_source_filter_sheet.dart';
import 'widgets/search_progress_card.dart';
import 'widgets/search_report_summary.dart';
import 'widgets/online_search_gate_card.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, this.hideTopSearchBar = false, this.entry});

  final bool hideTopSearchBar;
  final String? entry;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

enum _SearchMoreAction {
  togglePrecise,
  allSources,
  manageSources,
  serverSources,
  clearSourceFilter,
}

typedef _DeferredProgressUiUpdate = DeferredSearchProgressUiUpdate;

class _MobileSearchRouteTopBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _MobileSearchRouteTopBar({
    required this.onBack,
    required this.searchBar,
  });

  final VoidCallback onBack;
  final Widget searchBar;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    return AppBar(
      toolbarHeight: kToolbarHeight,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      titleSpacing: 0,
      title: Padding(
        padding: EdgeInsets.only(right: horizontal),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                tooltip: '返回',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(child: searchBar),
          ],
        ),
      ),
    );
  }
}

class _SearchMoreMenuItemContent extends StatelessWidget {
  const _SearchMoreMenuItemContent({
    required this.icon,
    required this.title,
    this.checked = false,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final bool checked;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final normalizedSubtitle = subtitle?.trim() ?? '';
    return SizedBox(
      width: 168,
      height: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 22,
            child: Icon(
              checked ? Icons.radio_button_checked_rounded : icon,
              size: 19,
              color:
                  checked ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (normalizedSubtitle.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    normalizedSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _keywordController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late final ServerOnlineSearchService _serverOnlineSearchService;
  late final SearchExecutionController _searchExecutionController;
  late final BookPresentationQueryService _bookPresentationQueryService;
  late final SearchHistoryService _historyService;
  late final SearchSystemSettingsService _searchSystemSettingsService;
  final OnlineSourceErrorPresentationAdapter _onlineSourceErrorAdapter =
      const OnlineSourceErrorPresentationAdapter();

  static const Duration _progressUiThrottleWindow = Duration(
    milliseconds: 1500,
  );
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

  final ValueNotifier<SearchExecutionReport?> _progressReportNotifier =
      ValueNotifier<SearchExecutionReport?>(null);
  final SearchRenderStateController _renderStateController =
      SearchRenderStateController(pageSize: _searchResultPageSize);
  SearchCancellationToken? _activeSearchToken;
  final ScrollController _pageScrollController = ScrollController();
  Timer? _progressUiTimer;
  Timer? _scrollUiResumeTimer;
  Timer? _scrollUiForceFlushTimer;
  SearchPageState get _pageState => ref.read(searchPageStateProvider);

  SearchPageStateNotifier get _pageStateNotifier =>
      ref.read(searchPageStateProvider.notifier);

  bool get _isSearching => _pageState.isSearching;
  set _isSearching(bool value) {
    _pageStateNotifier.update((state) => state.copyWith(isSearching: value));
  }

  int get _searchSessionId => _pageState.searchSessionId;
  set _searchSessionId(int value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(searchSessionId: value),
    );
  }

  SearchContentMode get _searchContentMode => _pageState.searchContentMode;
  set _searchContentMode(SearchContentMode value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(searchContentMode: value),
    );
  }

  bool get _isPreciseBookMatch => _pageState.isPreciseBookMatch;
  set _isPreciseBookMatch(bool value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(isPreciseBookMatch: value),
    );
  }

  bool get _aggregateByTitleAuthorEnabled =>
      _pageState.aggregateByTitleAuthorEnabled;
  set _aggregateByTitleAuthorEnabled(bool value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(aggregateByTitleAuthorEnabled: value),
    );
  }

  Set<String> get _selectedServerSourceIds =>
      _pageState.selectedServerSourceIds;
  set _selectedServerSourceIds(Set<String> value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(selectedServerSourceIds: value),
    );
  }

  Set<String> get _selectedServerGroupNames =>
      _pageState.selectedServerGroupNames;
  set _selectedServerGroupNames(Set<String> value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(selectedServerGroupNames: value),
    );
  }

  bool get _hasServerSourceFilter =>
      _selectedServerSourceIds.isNotEmpty ||
      _selectedServerGroupNames.isNotEmpty;

  SearchSourceSelection get _serverSourceSelection => SearchSourceSelection(
    groupNames: Set<String>.of(_selectedServerGroupNames),
    sourceIds: Set<String>.of(_selectedServerSourceIds),
  );

  bool get _isAppendingResults => _pageState.isAppendingResults;
  set _isAppendingResults(bool value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(isAppendingResults: value),
    );
  }

  Map<String, BookDisplayState> get _bookPresentationByTargetKey =>
      _pageState.bookPresentationByTargetKey;
  set _bookPresentationByTargetKey(Map<String, BookDisplayState> value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(bookPresentationByTargetKey: value),
    );
  }

  SearchExecutionReport? get _pendingProgressReport =>
      _pageState.pendingProgressReport;
  set _pendingProgressReport(SearchExecutionReport? value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(pendingProgressReport: value),
    );
  }

  DateTime? get _lastProgressUiUpdateAt => _pageState.lastProgressUiUpdateAt;
  set _lastProgressUiUpdateAt(DateTime? value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(lastProgressUiUpdateAt: value),
    );
  }

  bool get _isListScrollActive => _pageState.isListScrollActive;
  set _isListScrollActive(bool value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(isListScrollActive: value),
    );
  }

  DeferredSearchProgressUiUpdate? get _deferredProgressUiUpdate =>
      _pageState.deferredProgressUiUpdate;
  set _deferredProgressUiUpdate(DeferredSearchProgressUiUpdate? value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(deferredProgressUiUpdate: value),
    );
  }

  int? get _pendingSearchCompletionSessionId =>
      _pageState.pendingSearchCompletionSessionId;
  set _pendingSearchCompletionSessionId(int? value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(pendingSearchCompletionSessionId: value),
    );
  }

  SearchCancellationToken? get _pendingSearchCompletionToken =>
      _pageState.pendingSearchCompletionToken;
  set _pendingSearchCompletionToken(SearchCancellationToken? value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(pendingSearchCompletionToken: value),
    );
  }

  bool get _isCheckingOnlineSearchAccess =>
      _pageState.isCheckingOnlineSearchAccess;
  set _isCheckingOnlineSearchAccess(bool value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(isCheckingOnlineSearchAccess: value),
    );
  }

  bool get _hasOnlineSearchAccess => _pageState.hasOnlineSearchAccess;
  set _hasOnlineSearchAccess(bool value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(hasOnlineSearchAccess: value),
    );
  }

  String? get _onlineSearchAccessMessage =>
      _pageState.onlineSearchAccessMessage;
  set _onlineSearchAccessMessage(String? value) {
    _pageStateNotifier.update(
      (state) => state.copyWith(onlineSearchAccessMessage: value),
    );
  }

  List<String> get _searchHistory => _pageState.searchHistory;
  set _searchHistory(List<String> value) {
    _pageStateNotifier.update((state) => state.copyWith(searchHistory: value));
  }

  String get _serverSourceMenuLabel {
    if (!_hasServerSourceFilter) {
      return '搜索范围：全部书源';
    }
    if (_selectedServerSourceIds.isNotEmpty) {
      return '搜索范围：已选 ${_selectedServerSourceIds.length} 个书源';
    }
    return '搜索范围：已选 ${_selectedServerGroupNames.length} 个分组';
  }

  @override
  void initState() {
    super.initState();
    _serverOnlineSearchService = ref.read(serverOnlineSearchServiceProvider);
    _searchExecutionController = ref.read(searchExecutionControllerProvider);
    _bookPresentationQueryService = ref.read(
      searchBookPresentationQueryServiceProvider,
    );
    _historyService = ref.read(searchHistoryServiceProvider);
    _searchSystemSettingsService = ref.read(
      searchSystemSettingsServiceProvider,
    );
    _pageScrollController.addListener(_onPageScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadOnlineSearchAccess());
      unawaited(_loadSearchHistory());
    });
  }

  @override
  void dispose() {
    _activeSearchToken?.cancel();
    // ConsumerState 进入 dispose 后不能再通过 ref 读写 provider。
    // 这里仅释放本地计时器/控制器，autoDispose provider 会自行回收页面状态。
    _clearProgressUiThrottle(updatePageState: false);
    _clearDeferredProgressUiUpdate(updatePageState: false);
    _clearPendingSearchCompletion(updatePageState: false);
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
    ref.watch(searchPageStateProvider);
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
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final canPopRoute = context.canPop();
    final canUseOnlineSearch =
        _hasOnlineSearchAccess && !_isCheckingOnlineSearchAccess;
    final routeTopBar = _buildRouteTopBar(
      context: context,
      palette: palette,
      canUseOnlineSearch: canUseOnlineSearch,
    );
    final topInset =
        MediaQuery.paddingOf(context).top + routeTopBar.preferredSize.height;

    return PopScope<void>(
      canPop: canPopRoute,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !mounted) return;
        context.go('/bookshelf');
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        extendBodyBehindAppBar: true,
        appBar: routeTopBar,
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
                          if (!canUseOnlineSearch)
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                horizontal,
                                topInset + 12,
                                horizontal,
                                bottomSafe + 24,
                              ),
                              sliver: SliverFillRemaining(
                                hasScrollBody: false,
                                child: _buildOnlineSearchGate(context),
                              ),
                            )
                          else ...[
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                horizontal,
                                topInset + 12,
                                horizontal,
                                0,
                              ),
                              sliver: SliverToBoxAdapter(
                                child: AppFadeSlideTransition(
                                  child: SearchInputCard(
                                    isSearching: _isSearching,
                                    searchContentMode: _searchContentMode,
                                    modeActiveBackgroundColor:
                                        palette.primaryColor,
                                    modeActiveForegroundColor:
                                        _readableForegroundFor(
                                          palette.primaryColor,
                                        ),
                                    onContentModeChanged: _onContentModeChanged,
                                  ),
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
                                    return AppAnimatedSwitcher(
                                      child:
                                          _isSearching
                                              ? SearchProgressCard(
                                                key: const ValueKey<String>(
                                                  'search_progress',
                                                ),
                                                report: report,
                                                isSearching: _isSearching,
                                              )
                                              : const SizedBox.shrink(
                                                key: ValueKey<String>(
                                                  'search_progress_hidden',
                                                ),
                                              ),
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
                                        bottom: 16 + bottomSafe + keyboardInset,
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
                                      16 + bottomSafe + keyboardInset,
                                    ),
                                    sliver: SliverToBoxAdapter(
                                      child: AppFadeSlideTransition(
                                        child: SearchEmptyState(
                                          history: _searchHistory,
                                          onHistoryTap: _onHistoryTap,
                                          onClearHistory: _onClearHistory,
                                          onRemoveHistoryItem:
                                              _onRemoveHistoryItem,
                                        ),
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
                                      16 + bottomSafe + keyboardInset,
                                    ),
                                    sliver: SliverToBoxAdapter(
                                      child: AppFadeSlideTransition(
                                        child: SearchGroupedEmptyFallbackCard(
                                          canDisablePrecise:
                                              _isPreciseBookMatch &&
                                              report.books.isNotEmpty,
                                          canSwitchAllSources:
                                              _hasServerSourceFilter,
                                          onDisablePreciseMatch:
                                              _disablePreciseMatchFallback,
                                          onSwitchAllSources:
                                              () => unawaited(
                                                _switchToAllSourcesFallback(),
                                              ),
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                return SliverMainAxisGroup(
                                  slivers: [
                                    SliverPadding(
                                      padding: EdgeInsets.fromLTRB(
                                        horizontal,
                                        8,
                                        horizontal,
                                        0,
                                      ),
                                      sliver: SliverToBoxAdapter(
                                        child: AppAnimatedSwitcher(
                                          child: Column(
                                            key: ValueKey<String>(
                                              'search_report_${books.length}_${report.failures.length}',
                                            ),
                                            children: [
                                              SearchReportSummary(
                                                report: report,
                                                visibleBookCount: books.length,
                                                isPreciseBookMatch:
                                                    _isPreciseBookMatch,
                                              ),
                                              if (report
                                                  .failures
                                                  .isNotEmpty) ...[
                                                const SizedBox(height: 8),
                                                SearchFailureBanner(
                                                  report: report,
                                                ),
                                              ],
                                              const SizedBox(height: 10),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    SliverPadding(
                                      padding: EdgeInsets.fromLTRB(
                                        horizontal,
                                        0,
                                        horizontal,
                                        16 + bottomSafe + keyboardInset,
                                      ),
                                      sliver: _buildSearchResultSliver(
                                        context: context,
                                        books: books,
                                        report: report,
                                        renderState: renderState,
                                        visibleCount: visibleCount,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
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

  Future<void> _handleBackNavigation() async {
    final entry = widget.entry?.trim().toLowerCase();
    if (entry == 'dock' && context.canPop()) {
      final overlay = CircularThemeRevealOverlay.of(context);
      if (overlay != null) {
        final mediaQuery = MediaQuery.of(context);
        final bottomInset = mediaQuery.viewPadding.bottom;
        final size = mediaQuery.size;
        final dockSearchCenter = Offset(
          size.width - 48,
          size.height - (bottomInset + 40),
        );
        await overlay.startTransition(
          center: dockSearchCenter,
          reverse: false,
          onThemeChange: () {
            context.pop();
          },
        );
        return;
      }
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/bookshelf');
  }

  PreferredSizeWidget _buildRouteTopBar({
    required BuildContext context,
    required ResolvedAdvancedThemePalette palette,
    required bool canUseOnlineSearch,
  }) {
    final showSearchBar = !widget.hideTopSearchBar && canUseOnlineSearch;
    final metrics = AppAdaptiveMetrics.of(context);
    if (showSearchBar && !metrics.isMediumUpWindow) {
      return _MobileSearchRouteTopBar(
        onBack: _handleBackNavigation,
        searchBar: _buildSearchBar(context, palette),
      );
    }
    return AdaptiveRouteTopBar(
      title: _routeTopBarTitle,
      subtitle: _routeTopBarSubtitle,
      leading: IconButton(
        onPressed: _handleBackNavigation,
        tooltip: '返回',
        icon: const Icon(Icons.arrow_back),
      ),
      middle:
          showSearchBar
              ? _buildSearchBar(context, palette, includeOptions: false)
              : null,
      bottom: null,
      actions: _buildDesktopTopBarActions(
        canUseOnlineSearch: canUseOnlineSearch,
      ),
      mobileActions: _buildMobileTopBarActions(
        canUseOnlineSearch: canUseOnlineSearch,
      ),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      dividerColor: Colors.transparent,
      desktopHeight: kToolbarHeight,
      titleMaxWidth: 180,
      middleMinWidth: 220,
      middleMaxWidth: 560,
    );
  }

  String get _routeTopBarTitle {
    if (_isSearching) {
      return '搜索中';
    }
    return '在线搜索';
  }

  String? get _routeTopBarSubtitle {
    if (!_hasOnlineSearchAccess) {
      return _onlineSearchAccessMessage;
    }
    if (_hasServerSourceFilter) {
      return _serverSourceMenuLabel;
    }
    return _aggregateByTitleAuthorEnabled ? '聚合同名同作者结果' : null;
  }

  List<AdaptiveOverflowToolbarItem> _buildDesktopTopBarActions({
    required bool canUseOnlineSearch,
  }) {
    if (!canUseOnlineSearch) {
      return <AdaptiveOverflowToolbarItem>[
        AdaptiveOverflowToolbarItem(
          icon: Icons.refresh_rounded,
          label: '重新检查',
          priority: 8,
          enabled: !_isCheckingOnlineSearchAccess,
          onPressed: _loadOnlineSearchAccess,
        ),
      ];
    }
    return <AdaptiveOverflowToolbarItem>[
      AdaptiveOverflowToolbarItem(
        icon: _isSearching ? Icons.stop_circle_outlined : Icons.search_rounded,
        label: _isSearching ? '取消搜索' : '搜索',
        priority: 20,
        onPressed: _runSearch,
      ),
      AdaptiveOverflowToolbarItem(
        icon: Icons.source_outlined,
        label: _serverSourceMenuLabel,
        priority: 10,
        enabled: !_isSearching,
        onPressed: () => unawaited(_showActiveSourceFilterSheet()),
      ),
      AdaptiveOverflowToolbarItem(
        icon:
            _isPreciseBookMatch
                ? Icons.check_circle_rounded
                : Icons.check_circle_outline_rounded,
        label: '精准搜索',
        priority: 8,
        enabled: !_isSearching,
        onPressed: () => _onPreciseMatchChanged(!_isPreciseBookMatch),
      ),
      if (_hasServerSourceFilter)
        AdaptiveOverflowToolbarItem(
          icon: Icons.filter_alt_off_outlined,
          label: '清空书源筛选',
          priority: 4,
          enabled: !_isSearching,
          onPressed: _clearActiveSourceFilter,
        ),
    ];
  }

  List<Widget> _buildMobileTopBarActions({required bool canUseOnlineSearch}) {
    if (!canUseOnlineSearch) {
      return <Widget>[
        IconButton(
          tooltip: '重新检查',
          onPressed:
              _isCheckingOnlineSearchAccess ? null : _loadOnlineSearchAccess,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ];
    }
    return const <Widget>[];
  }

  Widget _buildSearchBar(
    BuildContext context,
    ResolvedAdvancedThemePalette palette, {
    bool includeOptions = true,
  }) {
    final theme = Theme.of(context);
    final metrics = AppAdaptiveMetrics.of(context);
    final hintText = switch (_searchContentMode) {
      SearchContentMode.manga => '输入漫画名或作者',
      SearchContentMode.audio => '输入有声书名或作者',
      SearchContentMode.novel => '输入书名或作者',
    };

    return Padding(
      padding: EdgeInsets.only(
        right: includeOptions ? 0 : metrics.contentGap + 2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Hero(
              tag: kSearchEntryHeroTag,
              createRectTween:
                  (begin, end) =>
                      MaterialRectCenterArcTween(begin: begin, end: end),
              child: Material(
                color: Colors.transparent,
                child: AdaptiveSearchBar(
                  controller: _keywordController,
                  focusNode: _searchFocusNode,
                  hintText: hintText,
                  onChanged: (_) {},
                  onSubmitted: (_) => _runSearch(),
                  onClear: _keywordController.clear,
                  height: metrics.controlHeight,
                  borderRadius: metrics.cardRadius,
                  backgroundColor: palette.searchFieldBackgroundColor,
                  foregroundColor: palette.textPrimaryColor,
                  secondaryColor: palette.textSecondaryColor,
                  outlineColor:
                      resolveAppBorderSide(
                        theme.colorScheme,
                        baseColor: palette.outlineColor,
                        containerColor: palette.searchFieldBackgroundColor,
                        tone: AppBorderTone.strong,
                        width: 1.2,
                      ).color,
                  suffixBuilder: (context, value) {
                    if (_isSearching) {
                      return IconButton(
                        tooltip: '取消搜索',
                        onPressed: _runSearch,
                        icon: const Icon(Icons.stop_circle_outlined, size: 18),
                        visualDensity: VisualDensity.compact,
                      );
                    }
                    if (value.text.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return IconButton(
                      tooltip: '清空输入',
                      onPressed: _keywordController.clear,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                    );
                  },
                ),
              ),
            ),
          ),
          if (includeOptions) ...[
            const SizedBox(width: 2),
            SizedBox(
              width: 38,
              height: metrics.controlHeight,
              child: AppMenuButton<_SearchMoreAction>(
                tooltip: '更多选项',
                enabled: !_isSearching,
                padding: EdgeInsets.zero,
                icon: Icons.more_vert_rounded,
                iconSize: 20,
                onSelected: (action) {
                  switch (action) {
                    case _SearchMoreAction.togglePrecise:
                      _onPreciseMatchChanged(!_isPreciseBookMatch);
                    case _SearchMoreAction.allSources:
                      if (_hasServerSourceFilter) {
                        _clearActiveSourceFilter();
                      }
                    case _SearchMoreAction.manageSources:
                      unawaited(context.push('/mine/book-sources'));
                    case _SearchMoreAction.serverSources:
                      unawaited(_showActiveSourceFilterSheet());
                    case _SearchMoreAction.clearSourceFilter:
                      _clearActiveSourceFilter();
                  }
                },
                actions: [
                  AppMenuAction(
                    value: _SearchMoreAction.togglePrecise,
                    label: '精准搜索',
                    child: _SearchMoreMenuItemContent(
                      icon: Icons.radio_button_unchecked_rounded,
                      checked: _isPreciseBookMatch,
                      title: '精准搜索',
                    ),
                  ),
                  AppMenuAction(
                    value: _SearchMoreAction.allSources,
                    label: '全部书源',
                    child: _SearchMoreMenuItemContent(
                      icon: Icons.radio_button_unchecked_rounded,
                      checked: !_hasServerSourceFilter,
                      title: '全部书源',
                    ),
                  ),
                  const AppMenuAction(
                    value: _SearchMoreAction.manageSources,
                    label: '书源管理',
                    child: _SearchMoreMenuItemContent(
                      icon: Icons.source_outlined,
                      title: '书源管理',
                      subtitle: '进入我的书源',
                    ),
                  ),
                  AppMenuAction(
                    value: _SearchMoreAction.serverSources,
                    label: '搜索范围',
                    child: _SearchMoreMenuItemContent(
                      icon: Icons.manage_search_rounded,
                      title: '搜索范围',
                      subtitle: _serverSourceMenuLabel,
                    ),
                  ),
                  if (_hasServerSourceFilter)
                    const AppMenuAction(
                      value: _SearchMoreAction.clearSourceFilter,
                      label: '清空搜索范围',
                      dividerBefore: true,
                      child: _SearchMoreMenuItemContent(
                        icon: Icons.filter_alt_off_outlined,
                        title: '清空搜索范围',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Callbacks for SearchInputCard ──

  void _onContentModeChanged(SearchContentMode mode) {
    setState(() {
      _searchContentMode = mode;
      _selectedServerSourceIds = <String>{};
      _selectedServerGroupNames = <String>{};
    });
    _clearSearchOutput();
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

  void _clearActiveSourceFilter() {
    _clearServerSourceFilter();
  }

  void _clearServerSourceFilter() {
    setState(() {
      _selectedServerSourceIds = <String>{};
      _selectedServerGroupNames = <String>{};
    });
    _clearSearchOutput();
  }

  // ── Search History ──

  Future<void> _loadSearchSystemSettings() async {
    try {
      final enabled =
          await _searchSystemSettingsService
              .loadAggregateByTitleAuthorEnabled();
      await _searchSystemSettingsService.loadSearchDebugLogEnabled();
      if (!mounted) {
        return;
      }
      setState(() {
        _aggregateByTitleAuthorEnabled = enabled;
      });
    } catch (error, stackTrace) {
      AppLogger.instance.warn(
        'Search system settings load failed',
        context: <String, Object?>{
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }

  Future<void> _loadOnlineSearchAccess() async {
    await _refreshOnlineSearchAccess(showChecking: true);
  }

  Future<bool> _refreshOnlineSearchAccess({required bool showChecking}) async {
    if (!mounted) {
      return true;
    }
    setState(() {
      _hasOnlineSearchAccess = true;
      _isCheckingOnlineSearchAccess = false;
      _onlineSearchAccessMessage = null;
    });
    unawaited(_loadSearchSystemSettings());
    return true;
  }

  Widget _buildOnlineSearchGate(BuildContext context) {
    return OnlineSearchGateCard(
      isChecking: _isCheckingOnlineSearchAccess,
      message: _onlineSearchAccessMessage,
      onRetry: () => unawaited(_loadOnlineSearchAccess()),
    );
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

  Future<void> _showActiveSourceFilterSheet() async {
    await _showServerSourceFilterSheet();
  }

  Future<void> _showServerSourceFilterSheet() async {
    final requestedMode = _searchContentMode;
    final selected = await showAdaptiveActionSurface<SearchSourceSelection>(
      context: context,
      maxWidth: 680,
      maxHeightFactor: 0.86,
      padding: EdgeInsets.zero,
      builder:
          (context) => SearchSourceFilterSheet(
            loadSourcePage: _serverOnlineSearchService.loadSourcePage,
            loadSourceGroups: _serverOnlineSearchService.loadSourceGroupPage,
            contentMode: requestedMode,
            initialSelection: _serverSourceSelection,
          ),
    );

    if (!mounted || requestedMode != _searchContentMode || selected == null) {
      return;
    }

    setState(() {
      _selectedServerGroupNames = Set<String>.of(selected.groupNames);
      _selectedServerSourceIds = selected.effectiveSourceIds;
    });
    _clearSearchOutput();
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
    _bookPresentationByTargetKey = const <String, BookDisplayState>{};
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
    final renderState = _renderStateController.renderStateNotifier.value;
    if (renderState != null) {
      final presentationMap = await _bookPresentationQueryService
          .loadRemotePresentationMap(renderState.visibleBooks);
      if (!mounted || sessionId != _searchSessionId) {
        return;
      }
      setState(() {
        _bookPresentationByTargetKey = presentationMap;
      });
    }
    _scheduleAutoAppendIfNeeded();
  }

  Widget _buildSearchResultSliver({
    required BuildContext context,
    required List<Book> books,
    required SearchExecutionReport report,
    required SearchRenderState renderState,
    required int visibleCount,
  }) {
    return SearchResultsSliver(
      books: books,
      report: report,
      renderState: renderState,
      visibleCount: visibleCount,
      presentationByTargetKey: _bookPresentationByTargetKey,
      buildHeroTag:
          (book, listIndex) =>
              _buildBookCoverHeroTag(book: book, listIndex: listIndex),
      onBookTap: _handleSearchResultTap,
    );
  }

  Future<void> _handleSearchResultTap({
    required Book book,
    required int listIndex,
    required String heroTag,
  }) async {
    final renderState = _renderStateController.renderStateNotifier.value;
    if (renderState == null) {
      return;
    }
    final selected = await _pickSearchResultSource(
      report: renderState.report,
      primaryBook: book,
    );
    if (selected == null || !mounted) {
      return;
    }
    final selectedHeroTag =
        selected.id == book.id
            ? heroTag
            : _buildBookCoverHeroTag(book: selected, listIndex: listIndex);
    await _openBookDetail(selected, heroTag: selectedHeroTag);
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

    return showAdaptiveActionSurface<Book>(
      context: context,
      maxWidth: 560,
      maxHeightFactor: 0.78,
      padding: EdgeInsets.zero,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.58,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                      key: ValueKey<String>(
                        'search_source_candidate_${candidate.sourceId}_${candidate.detailUrl}_${candidate.id}',
                      ),
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
      author: book.author,
      coverUrl: book.coverUrl,
      heroTag: heroTag,
    );
    _pauseActiveSearchIfNeeded();
    try {
      await context.push(route, extra: book);
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
    if (!_hasServerSourceFilter || _isSearching) {
      return;
    }
    setState(() {
      _selectedServerSourceIds = <String>{};
      _selectedServerGroupNames = <String>{};
    });
    await _runSearch();
  }

  // ── Progress throttling ──

  void _clearProgressUiThrottle({bool updatePageState = true}) {
    _progressUiTimer?.cancel();
    _progressUiTimer = null;
    if (!updatePageState) {
      return;
    }
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
      if (!mounted) {
        return;
      }
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
      if (!mounted) {
        return;
      }
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

    final hasOnlineSearchAccess = await _refreshOnlineSearchAccess(
      showChecking: !_hasOnlineSearchAccess,
    );
    if (!mounted) {
      return;
    }
    if (!hasOnlineSearchAccess) {
      _showMessage(_onlineSearchAccessMessage ?? '在线搜索为会员服务。');
      return;
    }

    FocusScope.of(context).unfocus();

    final sessionId = ++_searchSessionId;
    final token = SearchCancellationToken();
    _activeSearchToken = token;
    var pendingFinalUiCompletion = false;
    final selectedServerSourceIds =
        _selectedServerSourceIds.isEmpty
            ? null
            : _selectedServerSourceIds.toList(growable: false);
    final selectedServerGroupNames =
        _selectedServerGroupNames.isEmpty
            ? null
            : _selectedServerGroupNames.toList(growable: false);

    _clearSearchOutput();
    setState(() {
      _isSearching = true;
    });

    try {
      final report = await _searchExecutionController.run(
        SearchExecutionRequest(
          keyword: keyword,
          contentMode: _searchContentMode,
          sourceIds: selectedServerSourceIds,
          groupNames: selectedServerGroupNames,
          preciseMatch: _isPreciseBookMatch,
          aggregateByTitleAuthor: _aggregateByTitleAuthorEnabled,
          cancellationToken: token,
          onProgress: (progress) {
            if (!mounted ||
                token.isCancelled ||
                sessionId != _searchSessionId) {
              return;
            }
            _updateProgressReportThrottled(
              report: progress,
              token: token,
              sessionId: sessionId,
            );
          },
        ),
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
    } on AppException catch (error, stackTrace) {
      if (!mounted || token.isCancelled || sessionId != _searchSessionId) {
        return;
      }
      AppLogger.instance.warn(
        'Online search app exception',
        context: <String, Object?>{
          'keyword': keyword,
          'sessionId': sessionId,
          'selectedSourceIds': selectedServerSourceIds,
          'selectedGroupNames': selectedServerGroupNames,
          'stage': error.stage.name,
          'code': error.code.name,
          'sourceId': error.sourceId,
          'requestUrl': error.requestUrl,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      _showMessage(_onlineSourceErrorAdapter.forException(error));
    } catch (error, stackTrace) {
      if (!mounted || token.isCancelled || sessionId != _searchSessionId) {
        return;
      }
      AppLogger.instance.warn(
        'Online search failed',
        context: <String, Object?>{
          'keyword': keyword,
          'sessionId': sessionId,
          'selectedSourceIds': selectedServerSourceIds,
          'selectedGroupNames': selectedServerGroupNames,
          'aggregateByTitleAuthor': _aggregateByTitleAuthorEnabled,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      _showMessage(
        _onlineSourceErrorAdapter.genericFailureForStage(ErrorStage.search),
      );
    } finally {
      _clearProgressUiThrottle(
        updatePageState: mounted && sessionId == _searchSessionId,
      );
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
    _progressReportNotifier.value = null;
    setState(() {
      _isSearching = false;
      _activeSearchToken = null;
    });
    _showMessage('已取消搜索。');
  }

  void _showMessage(String text) {
    if (!mounted) return;
    AppFeedback.showSnackBar(context, message: text, useHaptics: false);
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
      if (!mounted) {
        return;
      }
      _isListScrollActive = false;
      unawaited(_flushDeferredProgressUiUpdate());
    });
  }

  Future<void> _flushDeferredProgressUiUpdate() async {
    if (!mounted) {
      return;
    }
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

  void _clearPendingSearchCompletion({bool updatePageState = true}) {
    if (!updatePageState) {
      return;
    }
    _pendingSearchCompletionSessionId = null;
    _pendingSearchCompletionToken = null;
  }

  void _clearDeferredProgressUiUpdate({bool updatePageState = true}) {
    _scrollUiResumeTimer?.cancel();
    _scrollUiResumeTimer = null;
    _scrollUiForceFlushTimer?.cancel();
    _scrollUiForceFlushTimer = null;
    if (!updatePageState) {
      return;
    }
    _deferredProgressUiUpdate = null;
    _isListScrollActive = false;
  }
}

Color _readableForegroundFor(Color backgroundColor) {
  return ThemeData.estimateBrightnessForColor(backgroundColor) ==
          Brightness.dark
      ? Colors.white
      : Colors.black;
}
