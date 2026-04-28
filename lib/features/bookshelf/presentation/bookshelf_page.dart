import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../app/layout/app_spacing.dart';
import '../../../app/navigation/mobile_bottom_navigation_inset.dart';
import '../../../app/navigation/app_navigation_style_provider.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/resolved_book_cover.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/media/image_selection_service.dart';
import '../../../domain/entities/book_metadata_override.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/entities/reading_record.dart';
import '../../../domain/entities/reader_toc_snapshot.dart';
import '../../../domain/repositories/book_metadata_override_repository.dart';
import '../../../domain/repositories/local_book_repository.dart';
import '../application/bookshelf_service.dart';
import '../application/bookshelf_system_settings_service.dart';
import '../application/bookshelf_external_import_coordinator.dart';
import '../application/bookshelf_flow_coordinator.dart';
import '../application/bookshelf_page_route_service.dart';
import '../application/bookshelf_presentation_query_service.dart';
import '../application/bookshelf_reader_open_service.dart';
import '../application/local_book_import_service.dart';
import '../providers.dart';
import '../../reader/application/reader_preferences_service.dart';
import '../../reader/application/local/local_book_index_service.dart';
import '../../reader/application/local/local_book_workflow_policy.dart';
import '../../book/application/book_metadata_presentation_resolver.dart';
import '../../book/application/book_detail_service.dart';
import '../../book/application/custom_cover_storage_service.dart';
import '../../announcement/application/announcement_service.dart';
import '../../announcement/application/announcement_read_state_service.dart';
import '../../mine/application/advanced_theme_provider.dart';
import '../../mine/application/cover_gallery_provider.dart';
import '../../source/application/external_import_catalog.dart';
import '../../source/application/external_import_diagnostics.dart';
import '../../source/application/external_source_import_bridge.dart';
import '../../source/application/source_runtime_task_conflict_service.dart';
import '../../../runtime/sources/source_registry.dart';
import '../../../runtime/session/source_session.dart';
import 'widgets/bookshelf_grid_sliver.dart';
import 'widgets/bookshelf_page_sections.dart';

part 'bookshelf_page_sections.dart';
part 'bookshelf_page_flow.dart';
part 'bookshelf_page_selection.dart';

enum _BookshelfFilter { all, local, novel, manga, custom }

enum _BookshelfMoreAction {
  selectBooks,
  batchEditCover,
  sortBooks,
  settings,
  importLocal,
}

enum _BookshelfSortMode {
  defaultOrder,
  recentRead,
  readingProgress,
  createdAt,
  author,
  title,
}

enum _BookshelfViewKind { base, tag, category }

enum _BookshelfSearchQuickFilterContent { none, tags, categories }

enum _BookshelfBatchAction { delete, updateCover }

class _BookshelfSelectionState {
  const _BookshelfSelectionState({
    this.enabled = false,
    this.selectedKeys = const <String>{},
    this.activeAction,
  });

  final bool enabled;
  final Set<String> selectedKeys;
  final _BookshelfBatchAction? activeAction;

  bool get isBusy => activeAction != null;
  bool get isDeleting => activeAction == _BookshelfBatchAction.delete;
  bool get isUpdatingCover => activeAction == _BookshelfBatchAction.updateCover;
  int get selectedCount => selectedKeys.length;

  _BookshelfSelectionState copyWith({
    bool? enabled,
    Set<String>? selectedKeys,
    bool clearSelectedKeys = false,
    _BookshelfBatchAction? activeAction,
    bool clearActiveAction = false,
  }) {
    return _BookshelfSelectionState(
      enabled: enabled ?? this.enabled,
      selectedKeys:
          clearSelectedKeys
              ? const <String>{}
              : Set<String>.unmodifiable(selectedKeys ?? this.selectedKeys),
      activeAction:
          clearActiveAction ? null : (activeAction ?? this.activeAction),
    );
  }
}

List<String> mergeBookshelfTaxonomyNames({
  required Map<String, int> counts,
  required List<String> order,
}) {
  final names = <String>[];
  for (final item in order) {
    final normalized = item.trim();
    if (normalized.isEmpty || names.contains(normalized)) {
      continue;
    }
    names.add(normalized);
  }

  final remaining = counts.keys
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty && !names.contains(item))
      .toList(growable: false);
  remaining.sort((a, b) {
    final countCompare = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
    if (countCompare != 0) {
      return countCompare;
    }
    return a.compareTo(b);
  });

  return <String>[...names, ...remaining];
}

class _BookshelfViewSelection {
  const _BookshelfViewSelection.base(this.filter)
    : kind = _BookshelfViewKind.base,
      tag = null,
      category = null;

  const _BookshelfViewSelection.tag(this.tag)
    : kind = _BookshelfViewKind.tag,
      filter = _BookshelfFilter.custom,
      category = null;

  const _BookshelfViewSelection.category(this.category)
    : kind = _BookshelfViewKind.category,
      filter = _BookshelfFilter.custom,
      tag = null;

  final _BookshelfViewKind kind;
  final _BookshelfFilter filter;
  final String? tag;
  final String? category;

  bool get isTag => kind == _BookshelfViewKind.tag;
  bool get isCategory => kind == _BookshelfViewKind.category;
  bool get isUncategorized =>
      isCategory && (category == null || category!.isEmpty);

  @override
  bool operator ==(Object other) {
    return other is _BookshelfViewSelection &&
        other.kind == kind &&
        other.filter == filter &&
        other.tag == tag &&
        other.category == category;
  }

  @override
  int get hashCode => Object.hash(kind, filter, tag, category);
}

enum _BookshelfSettingsTab { list, grid }

class _BookshelfProgressDisplay {
  const _BookshelfProgressDisplay({
    required this.progressValue,
    required this.summaryText,
    required this.trailingLabel,
    required this.hasProgress,
  });

  final double progressValue;
  final String summaryText;
  final String trailingLabel;
  final bool hasProgress;
}

class _BookshelfBookCardState {
  const _BookshelfBookCardState({
    this.progress,
    this.latestCachedChapterTitle,
    this.cachedChapterCount = 0,
    this.localBook,
  });

  final ReadingProgress? progress;
  final String? latestCachedChapterTitle;
  final int cachedChapterCount;
  final LocalBook? localBook;

  _BookshelfBookCardState copyWith({
    ReadingProgress? progress,
    bool clearProgress = false,
    String? latestCachedChapterTitle,
    bool clearLatestCachedChapterTitle = false,
    int? cachedChapterCount,
    LocalBook? localBook,
    bool clearLocalBook = false,
  }) {
    return _BookshelfBookCardState(
      progress: clearProgress ? null : (progress ?? this.progress),
      latestCachedChapterTitle:
          clearLatestCachedChapterTitle
              ? null
              : (latestCachedChapterTitle ?? this.latestCachedChapterTitle),
      cachedChapterCount: cachedChapterCount ?? this.cachedChapterCount,
      localBook: clearLocalBook ? null : (localBook ?? this.localBook),
    );
  }
}

class BookshelfPage extends ConsumerStatefulWidget {
  const BookshelfPage({super.key, this.prefetchAnnouncementOnInit = false});

  final bool prefetchAnnouncementOnInit;

  @override
  ConsumerState<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends ConsumerState<BookshelfPage>
    with AutomaticKeepAliveClientMixin<BookshelfPage> {
  static const List<_BookshelfFilter> _kDefaultBaseFilters = <_BookshelfFilter>[
    _BookshelfFilter.all,
    _BookshelfFilter.local,
    _BookshelfFilter.novel,
    _BookshelfFilter.manga,
  ];

  late final BookshelfService _bookshelfService;
  late final BookshelfSystemSettingsService _bookshelfSystemSettingsService;
  late final ReaderPreferencesService _readerPreferencesService;
  late final BookshelfPageRouteService _pageRouteService;
  late final LocalBookIndexService _localBookIndexService;
  final BookMetadataPresentationResolver _bookMetadataPresentationResolver =
      const BookMetadataPresentationResolver();
  late final BookDetailService _bookDetailService;
  late final BookshelfReaderOpenService _readerOpenService;
  late final AppLogger _logger;
  final TextEditingController _bookshelfSearchController =
      TextEditingController();
  final FocusNode _bookshelfSearchFocusNode = FocusNode();
  final ScrollController _bookshelfScrollController = ScrollController();
  late final LocalBookImportService _localBookImportService;
  late final LocalBookRepository _localBookRepository;
  late final BookMetadataOverrideRepository _bookMetadataOverrideRepository;
  late final BookshelfPresentationQueryService
  _bookshelfPresentationQueryService;
  late final BookshelfExternalImportCoordinator _externalImportCoordinator;
  late final BookshelfFlowCoordinator _flowCoordinator;
  late final ImageSelectionService _imageSelectionService;
  late final CustomCoverStorageService _customCoverStorageService;
  late final AnnouncementService _announcementService;
  late final AnnouncementReadStateService _announcementReadStateService;
  late final SourceRuntimeTaskConflictService _taskConflictService;
  StreamSubscription<BookshelfTaxonomyChange>? _taxonomyChangeSub;

  bool _isLoading = true;
  List<BookshelfBook> _books = const <BookshelfBook>[];
  Map<String, ReadingProgress> _progressByBookKey =
      const <String, ReadingProgress>{};
  Map<String, String> _latestCachedChapterByBookKey = const <String, String>{};
  Map<String, int> _cachedChapterCountByBookKey = const <String, int>{};
  final Map<String, ValueNotifier<_BookshelfBookCardState>>
  _bookCardStateNotifiers = <String, ValueNotifier<_BookshelfBookCardState>>{};
  Map<String, int> _sourceTypeBySourceId = const <String, int>{};
  Map<String, LocalBook> _localBooksById = const <String, LocalBook>{};
  Map<String, BookMetadataOverride> _metadataOverridesByTargetKey =
      const <String, BookMetadataOverride>{};
  Map<String, List<String>> _bookTagsByKey = const <String, List<String>>{};
  List<String> _tagOrder = const <String>[];
  Map<String, String> _bookCategoriesByKey = const <String, String>{};
  List<String> _categoryOrder = const <String>[];
  List<_BookshelfFilter> _baseFilterOrder = _kDefaultBaseFilters;
  bool _bookshelfMetadataReady = false;
  Object? _derivedBookshelfFingerprint;
  List<BookshelfBook> _filteredBooksCache = const <BookshelfBook>[];
  Map<String, int> _tagBookCountCache = const <String, int>{};
  Map<String, int> _categoryBookCountCache = const <String, int>{};
  List<String> _userTagsCache = const <String>[];
  List<String> _userCategoriesCache = const <String>[];
  bool _useGridView = false;
  _BookshelfSortMode _sortMode = _BookshelfSortMode.defaultOrder;
  bool _gridAdaptiveColumns = BookshelfService.defaultGridAdaptiveColumns;
  int _gridColumnCount = BookshelfService.defaultGridColumnCount;
  double _gridCrossSpacing = BookshelfService.defaultGridCrossSpacing;
  double _gridMainSpacing = BookshelfService.defaultGridMainSpacing;
  bool _gridShowTitle = BookshelfService.defaultGridShowTitle;
  bool _gridShowAuthor = BookshelfService.defaultGridShowAuthor;
  bool _gridShowLatestChapter = BookshelfService.defaultGridShowLatestChapter;
  bool _gridShowProgressBar = BookshelfService.defaultGridShowProgressBar;
  bool _gridAlwaysShowSearchBar =
      BookshelfService.defaultGridAlwaysShowSearchBar;
  bool _gridPinSearchBar = BookshelfService.defaultGridPinSearchBar;
  _BookshelfSearchQuickFilterContent _gridQuickFilterContent =
      _BookshelfSearchQuickFilterContent.none;
  bool _listShowTitle = BookshelfService.defaultListShowTitle;
  bool _listShowAuthor = BookshelfService.defaultListShowAuthor;
  bool _listShowLatestChapter = BookshelfService.defaultListShowLatestChapter;
  bool _listShowProgressBar = BookshelfService.defaultListShowProgressBar;
  bool _listAlwaysShowSearchBar =
      BookshelfService.defaultListAlwaysShowSearchBar;
  bool _listPinSearchBar = BookshelfService.defaultListPinSearchBar;
  _BookshelfSearchQuickFilterContent _listQuickFilterContent =
      _BookshelfSearchQuickFilterContent.none;
  _BookshelfViewSelection _activeView = const _BookshelfViewSelection.base(
    _BookshelfFilter.all,
  );
  String _bookshelfSearchKeyword = '';
  bool _isBookshelfSearchExpanded = false;
  String? _openingBookId;
  String? _loadErrorText;
  bool _isConsumingExternalImportPayloads = false;
  bool _isImportingLocal = false;
  _BookshelfSelectionState _selectionState = const _BookshelfSelectionState();
  int _loadTicket = 0;
  bool _hasActiveAnnouncement = false;
  RouteInformationProvider? _routeInformationProvider;
  String _lastKnownRouteLocation = '';
  DateTime? _lastAutoRefreshAt;
  DateTime? _lastBookshelfLoadRequestedAt;
  Future<void>? _activeBookshelfLoad;
  bool _reloadAfterActiveLoad = false;
  bool? _lastKnownAutoRefreshOnTabActiveEnabled;
  bool _hasShownContinueReadingPrompt = false;
  ReadingRecord? _continueReadingRecord;
  int _latestInfoRefreshEpoch = 0;
  bool _skipNextBackgroundLatestInfoRefresh = false;

  static const String _kLocalBookSourceId =
      LocalBookImportService.localBookSourceId;
  static const Duration _kBookshelfLoadTimeout = Duration(seconds: 8);
  static const Duration _kProgressLoadTimeout = Duration(seconds: 2);
  static const Duration _kSourceMapLoadTimeout = Duration(seconds: 2);
  static const Duration _kBooksModeSwitchItemDuration = Duration(
    milliseconds: 320,
  );
  static const int _kProgressBatchSize = 24;
  static const int _kProgressUiUpdateBatchInterval = 3;
  static const int _kBooksModeSwitchStaggerGroup = 8;
  static const int _kBooksModeSwitchAnimatedItemLimit = 24;
  static const int _kBooksModeSwitchDisableThreshold = 72;
  static const double _kBooksModeSwitchStaggerStep = 0.07;
  static const double _kBooksModeSwitchCurveSpan = 0.42;
  static const Duration _kAutoRefreshDebounce = Duration(milliseconds: 800);
  static const Duration _kDuplicateLoadCooldown = Duration(milliseconds: 700);
  static const Duration _kContinueReadingPromptDuration = Duration(seconds: 6);
  static const double _kContinueReadingCardHeight = 92;
  static const double _kContinueReadingDockGap = 12;
  static const double _kContinueReadingStandardGap = 16;
  static const double _kContinueReadingIosExtraGap = 10;
  static const Set<String> _kMangaCapabilityKeywords = <String>{
    'manga',
    'comic',
    'manhua',
    'manhwa',
  };

  @override
  void initState() {
    super.initState();
    final dependencies = ref.read(bookshelfPageDependenciesProvider);
    _bookshelfService = dependencies.bookshelfService;
    _bookshelfSystemSettingsService = dependencies.systemSettingsService;
    _readerPreferencesService = dependencies.readerPreferencesService;
    _pageRouteService = dependencies.pageRouteService;
    _localBookIndexService = dependencies.localBookIndexService;
    _bookDetailService = dependencies.bookDetailService;
    _readerOpenService = dependencies.readerOpenService;
    _logger = dependencies.logger;
    _localBookImportService = dependencies.localBookImportService;
    _imageSelectionService = dependencies.imageSelectionService;
    _customCoverStorageService = dependencies.customCoverStorageService;
    _announcementService = dependencies.announcementService;
    _announcementReadStateService = dependencies.announcementReadStateService;
    _localBookRepository = ref.read(bookshelfLocalBookRepositoryProvider);
    _bookMetadataOverrideRepository = ref.read(
      bookshelfMetadataOverrideRepositoryProvider,
    );
    _bookshelfPresentationQueryService = ref.read(
      bookshelfPresentationQueryServiceProvider,
    );
    _externalImportCoordinator =
        ref.read(bookshelfExternalImportCoordinatorFactoryProvider)();
    _flowCoordinator = dependencies.flowCoordinator;
    _taskConflictService = ref.read(bookshelfTaskConflictServiceProvider);
    _bookshelfSearchFocusNode.addListener(_handleBookshelfSearchFocusChanged);
    _externalImportCoordinator.initialize(
      onPendingImportAvailable: () {
        unawaited(_consumePendingExternalImportPayloads());
      },
    );
    _taxonomyChangeSub = BookshelfService.watchTaxonomyChanges.listen(
      _handleTaxonomyChange,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_consumePendingExternalImportPayloads());
      unawaited(_restoreViewModePreference());
      unawaited(_restoreListPreferences());
      unawaited(_restoreSortModePreference());
      unawaited(_restoreGridPreferences());
      unawaited(_restoreViewSelection());
      unawaited(_loadBookshelf());
      if (widget.prefetchAnnouncementOnInit) {
        unawaited(_prefetchLatestAnnouncement());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextProvider = GoRouter.of(context).routeInformationProvider;
    if (identical(_routeInformationProvider, nextProvider)) {
      return;
    }

    _routeInformationProvider?.removeListener(_handleRouteLocationChanged);
    _routeInformationProvider = nextProvider;
    _lastKnownRouteLocation = _routeLocationFrom(nextProvider.value);
    _routeInformationProvider?.addListener(_handleRouteLocationChanged);
  }

  @override
  void dispose() {
    _cancelBackgroundLatestInfoRefresh();
    _loadTicket += 1;
    _routeInformationProvider?.removeListener(_handleRouteLocationChanged);
    _routeInformationProvider = null;
    unawaited(_externalImportCoordinator.dispose());
    _taxonomyChangeSub?.cancel();
    _bookshelfSearchFocusNode.removeListener(
      _handleBookshelfSearchFocusChanged,
    );
    _bookshelfScrollController.dispose();
    _bookshelfSearchFocusNode.dispose();
    _bookshelfSearchController.dispose();
    for (final notifier in _bookCardStateNotifiers.values) {
      notifier.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.watch(activeAdvancedThemeProvider);
    ref.watch(coverGalleriesProvider);
    final backdrop = _resolvedBackdrop(context);
    final horizontal = AppSpacing.pageHorizontal(context);
    final platform = Theme.of(context).platform;
    final effectiveNavigationStyle = resolveAppNavigationStyle(
      ref.watch(appNavigationStylePreferenceProvider),
      isWeb: false,
      platform: platform,
    );
    final showNavigationLabels = ref.watch(
      appNavigationLabelVisibilityProvider,
    );
    final standardNavigationAppearance = ref.watch(
      appStandardNavigationBarAppearanceProvider,
    );
    final navigationBottomInset = mobileBottomNavigationContentInset(
      context,
      style: effectiveNavigationStyle,
      showNavigationLabels: showNavigationLabels,
      standardAppearance: standardNavigationAppearance,
    );
    final navigationComfortInset = mobileBottomNavigationComfortInset(
      style: effectiveNavigationStyle,
    );
    final showTopSearchAction =
        effectiveNavigationStyle != AppNavigationStyle.cupertinoDock;
    final filteredBooks = _filteredBooks;
    final continueReadingVisible =
        _continueReadingRecord != null && !_isSelectionMode;
    final continueReadingBottomInset =
        _continueReadingBottomInset(
          effectiveNavigationStyle,
          navigationBottomInset: navigationBottomInset,
          platform: platform,
        ) +
        navigationComfortInset;
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final continueReadingReservedSpace =
        continueReadingVisible
            ? _kContinueReadingCardHeight + continueReadingBottomInset
            : navigationBottomInset + navigationComfortInset;
    final contentTopPadding =
        _shouldShowBookshelfSearchSliver ? 12.0 : topInset + 12;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        leading:
            _isSelectionMode
                ? IconButton(
                  onPressed: _exitSelectionMode,
                  tooltip: '取消选择',
                  icon: const Icon(Icons.close),
                )
                : null,
        title:
            _isSelectionMode
                ? Text('已选择 ${_selectedBookKeys.length} 项')
                : _buildBookshelfViewTitle(),
        actions: [
          if (_isSelectionMode)
            if (_isBatchDeleting || _isBatchUpdatingCovers)
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
          else if (_isImportingLocal)
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
          else ...[
            _buildAnnouncementAction(),
            if (showTopSearchAction)
              IconButton(
                tooltip: '搜索书籍',
                onPressed: () => context.push('/search'),
                icon: const Icon(Icons.search_rounded),
              ),
            PopupMenuButton<_BookshelfMoreAction>(
              tooltip: '更多功能',
              onSelected: _handleMoreAction,
              itemBuilder:
                  (context) => [
                    PopupMenuItem<_BookshelfMoreAction>(
                      value: _BookshelfMoreAction.selectBooks,
                      enabled: !_isLoading && _filteredBooks.isNotEmpty,
                      child: const Row(
                        children: [
                          Icon(Icons.checklist_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('选择书籍'),
                        ],
                      ),
                    ),
                    PopupMenuItem<_BookshelfMoreAction>(
                      value: _BookshelfMoreAction.batchEditCover,
                      enabled: !_isLoading && _filteredBooks.isNotEmpty,
                      child: const Row(
                        children: [
                          Icon(Icons.collections_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('批量修改封面'),
                        ],
                      ),
                    ),
                    PopupMenuItem<_BookshelfMoreAction>(
                      value: _BookshelfMoreAction.sortBooks,
                      enabled: !_isLoading && _books.isNotEmpty,
                      child: const Row(
                        children: [
                          Icon(Icons.sort_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('书籍排序'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<_BookshelfMoreAction>(
                      value: _BookshelfMoreAction.settings,
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('书架设置'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<_BookshelfMoreAction>(
                      value: _BookshelfMoreAction.importLocal,
                      child: Row(
                        children: [
                          Icon(Icons.library_add_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('导入图书'),
                        ],
                      ),
                    ),
                  ],
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
        ],
      ),
      bottomNavigationBar:
          _isSelectionMode
              ? _buildSelectionActionBar(filteredBooks: filteredBooks)
              : null,
      body: Stack(
        children: [
          DecoratedBox(
            decoration: buildAdvancedThemeBackdropDecoration(backdrop),
            child: RefreshIndicator(
              onRefresh: () => _loadBookshelf(force: true),
              child: CustomScrollView(
                controller: _bookshelfScrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (_shouldShowBookshelfSearchSliver)
                    _buildBookshelfSearchSliver(
                      horizontal: horizontal,
                      topInset: topInset + 12,
                    ),
                  if (_books.isNotEmpty)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        contentTopPadding,
                        horizontal,
                        16 + continueReadingReservedSpace,
                      ),
                      sliver: _buildBooksContentSliver(filteredBooks),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        contentTopPadding,
                        horizontal,
                        16 + continueReadingReservedSpace,
                      ),
                      sliver: _buildBooksContentSliver(filteredBooks),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: horizontal,
            right: horizontal,
            bottom: continueReadingBottomInset,
            child: _buildContinueReadingPromptCard(),
          ),
        ],
      ),
    );
  }

  double _continueReadingBottomInset(
    AppNavigationStyle style, {
    required double navigationBottomInset,
    required TargetPlatform platform,
  }) {
    final platformExtraGap =
        platform == TargetPlatform.iOS ? _kContinueReadingIosExtraGap : 0.0;
    return switch (style) {
      AppNavigationStyle.standard =>
        navigationBottomInset + _kContinueReadingStandardGap + platformExtraGap,
      AppNavigationStyle.cupertinoDock =>
        navigationBottomInset + _kContinueReadingDockGap + platformExtraGap,
    };
  }

  bool get _isSelectionMode => _selectionState.enabled;

  bool get _isBatchDeleting => _selectionState.isDeleting;

  bool get _isBatchUpdatingCovers => _selectionState.isUpdatingCover;

  Set<String> get _selectedBookKeys => _selectionState.selectedKeys;

  @override
  bool get wantKeepAlive => true;

  void _updateBookshelfState(VoidCallback mutation) {
    if (!mounted) {
      return;
    }
    setState(mutation);
  }

  ResolvedAdvancedThemePalette _resolvedPalette(BuildContext context) {
    return resolveAdvancedThemePalette(
      Theme.of(context).colorScheme,
      ref.read(activeAdvancedThemeProvider).valueOrNull,
    );
  }

  ResolvedAdvancedThemeBackdrop _resolvedBackdrop(BuildContext context) {
    return resolveAdvancedThemeBackdrop(
      Theme.of(context).colorScheme,
      ref.read(activeAdvancedThemeProvider).valueOrNull,
    );
  }

  void _handleRouteLocationChanged() {
    final provider = _routeInformationProvider;
    if (provider == null) {
      return;
    }

    final nextLocation = _routeLocationFrom(provider.value);
    final wasOnBookshelf = _isBookshelfRoute(_lastKnownRouteLocation);
    final isOnBookshelf = _isBookshelfRoute(nextLocation);
    _lastKnownRouteLocation = nextLocation;

    if (wasOnBookshelf && !isOnBookshelf) {
      _cancelBackgroundLatestInfoRefresh();
    }

    if (!wasOnBookshelf && isOnBookshelf) {
      unawaited(_maybeAutoRefreshOnTabActivated());
    }
  }

  String _routeLocationFrom(RouteInformation routeInformation) {
    return routeInformation.uri.toString();
  }

  bool _isBookshelfRoute(String location) {
    return location.startsWith('/bookshelf');
  }

  void _handleTaxonomyChange(BookshelfTaxonomyChange change) {
    if (!mounted) {
      return;
    }

    setState(() {
      switch (change.kind) {
        case BookshelfTaxonomyKind.tag:
          if (_activeView.isTag && _activeView.tag == change.previousName) {
            switch (change.action) {
              case BookshelfTaxonomyAction.rename:
                final nextName = change.currentName?.trim();
                if (nextName != null && nextName.isNotEmpty) {
                  _activeView = _BookshelfViewSelection.tag(nextName);
                }
              case BookshelfTaxonomyAction.delete:
                _activeView = const _BookshelfViewSelection.base(
                  _BookshelfFilter.all,
                );
              case BookshelfTaxonomyAction.create ||
                  BookshelfTaxonomyAction.orderChanged ||
                  BookshelfTaxonomyAction.assignmentChanged:
                break;
            }
          }
        case BookshelfTaxonomyKind.category:
          if (_activeView.isCategory &&
              _activeView.category == change.previousName) {
            switch (change.action) {
              case BookshelfTaxonomyAction.rename:
                final nextName = change.currentName?.trim();
                if (nextName != null && nextName.isNotEmpty) {
                  _activeView = _BookshelfViewSelection.category(nextName);
                }
              case BookshelfTaxonomyAction.delete:
                _activeView = const _BookshelfViewSelection.base(
                  _BookshelfFilter.all,
                );
              case BookshelfTaxonomyAction.create ||
                  BookshelfTaxonomyAction.orderChanged ||
                  BookshelfTaxonomyAction.assignmentChanged:
                break;
            }
          }
      }
    });

    unawaited(_loadBookshelfMetadata(_books, ticket: _loadTicket));
  }

  Future<void> _maybeAutoRefreshOnTabActivated() async {
    if (!mounted) {
      return;
    }
    final now = DateTime.now();
    final lastRun = _lastAutoRefreshAt;
    if (lastRun != null && now.difference(lastRun) < _kAutoRefreshDebounce) {
      return;
    }

    final enabled = await _isAutoRefreshOnTabActiveEnabled();
    if (!mounted || !enabled || !_isBookshelfRoute(_lastKnownRouteLocation)) {
      return;
    }

    _lastAutoRefreshAt = now;
    await _loadBookshelf(force: true);
  }

  Future<void> _restoreViewSelection() async {
    final stored = await _bookshelfService.loadViewSelection();
    if (!mounted || stored == null) {
      return;
    }

    final kind = (stored['kind'] ?? '').trim();
    final value = (stored['value'] ?? '').trim();
    final next = switch (kind) {
      'tag' when value.isNotEmpty => _BookshelfViewSelection.tag(value),
      'category' =>
        value.isEmpty
            ? const _BookshelfViewSelection.category(null)
            : _BookshelfViewSelection.category(value),
      'local' => const _BookshelfViewSelection.base(_BookshelfFilter.local),
      'novel' => const _BookshelfViewSelection.base(_BookshelfFilter.novel),
      'manga' => const _BookshelfViewSelection.base(_BookshelfFilter.manga),
      _ => const _BookshelfViewSelection.base(_BookshelfFilter.all),
    };

    if (next == _activeView) {
      return;
    }
    setState(() {
      _activeView = next;
    });
  }

  Future<bool> _isAutoRefreshOnTabActiveEnabled() async {
    try {
      final enabled =
          await _bookshelfSystemSettingsService
              .loadAutoRefreshOnTabActiveEnabled();
      _lastKnownAutoRefreshOnTabActiveEnabled = enabled;
      return enabled;
    } catch (_) {
      return _lastKnownAutoRefreshOnTabActiveEnabled ?? false;
    }
  }

  Future<void> _prefetchLatestAnnouncement() async {
    try {
      final latest = await _announcementService.fetchLatestAnnouncement();
      if (latest == null) {
        return;
      }
      final isRead = await _announcementReadStateService.isRead(latest.id);
      if (!mounted) {
        return;
      }
      final active = latest.isActiveAt(DateTime.now().toUtc());
      final shouldShow = active && !isRead;
      if (shouldShow != _hasActiveAnnouncement) {
        setState(() {
          _hasActiveAnnouncement = shouldShow;
        });
      }
    } catch (_) {
      // ignore announcement prefetch failures to avoid blocking bookshelf
    }
  }

  Widget _buildSelectionActionBar({
    required List<BookshelfBook> filteredBooks,
  }) {
    final palette = _resolvedPalette(context);
    final selectedCount = _selectedBookKeys.length;
    final isSelectionActionBusy = _isBatchDeleting || _isBatchUpdatingCovers;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            border: Border.all(
              color: palette.cardBorderColor.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: palette.shadowColor,
                blurRadius: 14,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.checklist_rounded,
                      size: 18,
                      color: palette.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '已选 $selectedCount / ${filteredBooks.length}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: palette.textSecondaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            isSelectionActionBusy || filteredBooks.isEmpty
                                ? null
                                : _selectAllBooks,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.select_all_rounded),
                        label: const Text('全选'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed:
                            isSelectionActionBusy || _selectedBookKeys.isEmpty
                                ? null
                                : _editSelectedBooksCover,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('修改封面'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            isSelectionActionBusy || _selectedBookKeys.isEmpty
                                ? null
                                : _deleteSelectedBooks,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('删除'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookGridSliver(List<BookshelfBook> books) {
    return BookshelfGridSliver(
      itemCount: books.length,
      fixedCrossAxisCount: _gridAdaptiveColumns ? null : _gridColumnCount,
      crossSpacing: _gridCrossSpacing,
      mainSpacing: _gridMainSpacing,
      itemHeightExtra: _gridCardItemHeightExtra,
      itemBuilder: (context, index) {
        final book = books[index];
        return _buildModeSwitchAnimatedBookItem(
          book: book,
          index: index,
          totalCount: books.length,
          child: _buildReactiveGridCard(book),
        );
      },
    );
  }

  double get _gridCardItemHeightExtra {
    var extraHeight = 12.0;
    final hasMetaInfo =
        _gridShowTitle ||
        _gridShowAuthor ||
        _gridShowLatestChapter ||
        _gridShowProgressBar;
    if (hasMetaInfo) {
      extraHeight += 6;
    }
    if (_gridShowTitle) {
      extraHeight += 18;
    }
    if (_gridShowAuthor) {
      extraHeight += (_gridShowTitle ? 2 : 0) + 16;
    }
    if (_gridShowLatestChapter) {
      extraHeight += ((_gridShowTitle || _gridShowAuthor) ? 1 : 0) + 16;
    }
    if (_gridShowProgressBar) {
      extraHeight +=
          ((_gridShowTitle || _gridShowAuthor || _gridShowLatestChapter)
              ? 4
              : 0) +
          5;
    }
    return extraHeight;
  }

  Widget _buildReactiveGridCard(BookshelfBook book) {
    return ValueListenableBuilder<_BookshelfBookCardState>(
      valueListenable: _ensureBookCardStateNotifier(book),
      builder: (context, cardState, _) {
        return _buildGridCard(book, cardState: cardState);
      },
    );
  }

  Widget _buildReactiveBookCard(BookshelfBook book) {
    return ValueListenableBuilder<_BookshelfBookCardState>(
      valueListenable: _ensureBookCardStateNotifier(book),
      builder: (context, cardState, _) {
        return _buildBookCard(book, cardState: cardState);
      },
    );
  }

  Widget _buildModeSwitchAnimatedBookItem({
    required BookshelfBook book,
    required int index,
    required int totalCount,
    required Widget child,
  }) {
    if (totalCount > _kBooksModeSwitchDisableThreshold ||
        index >= _kBooksModeSwitchAnimatedItemLimit) {
      return RepaintBoundary(
        key: ValueKey<String>(
          'bookshelf_static_${_useGridView ? 'grid' : 'list'}_${book.bookId}',
        ),
        child: child,
      );
    }

    final delay =
        (index % _kBooksModeSwitchStaggerGroup) * _kBooksModeSwitchStaggerStep;
    final begin = delay.clamp(0.0, 1 - _kBooksModeSwitchCurveSpan);
    final end = begin + _kBooksModeSwitchCurveSpan;

    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
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
      ),
    );
  }

  Widget _buildGridCard(
    BookshelfBook book, {
    required _BookshelfBookCardState cardState,
  }) {
    const coverAspectRatio = 68 / 96;
    final progress = cardState.progress;
    final localBook = cardState.localBook;
    final progressDisplay = _resolveBookshelfProgressDisplay(
      book,
      progress: progress,
      localBook: localBook,
      cachedChapterCount: cardState.cachedChapterCount,
    );
    final colorScheme = Theme.of(context).colorScheme;
    final palette = _resolvedPalette(context);
    final isOpening = _openingBookId == book.bookId;
    final isSelected = _isBookSelected(book);
    final displayTitle = _displayBookTitle(book, localBook: localBook);
    final displayAuthor = _displayBookAuthor(book, localBook: localBook);
    final titleText = _toSingleLineText(displayTitle);
    final authorText = _toSingleLineText(displayAuthor ?? '');
    final latestChapterText = _toSingleLineText(
      cardState.latestCachedChapterTitle ?? book.latestChapter ?? '',
    );
    final coverHeroTag = _buildBookCoverHeroTag(book);
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
        child: SizedBox.expand(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: coverAspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: palette.shadowColor,
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return _buildCover(
                              realCoverUrl: book.coverUrl,
                              title: displayTitle,
                              author: displayAuthor,
                              bookId: book.bookId,
                              sourceId: book.sourceId,
                              detailUrl: book.detailUrl,
                              heroTag: coverHeroTag,
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                            );
                          },
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
                                        ? palette.primaryColor
                                        : palette.cardColor.withValues(
                                          alpha: 0.9,
                                        ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? palette.primaryColor
                                          : palette.cardBorderColor.withValues(
                                            alpha: 0.7,
                                          ),
                                ),
                              ),
                              child: Icon(
                                Icons.check,
                                size: 14,
                                color:
                                    isSelected
                                        ? palette.buttonTextColor
                                        : palette.textSecondaryColor,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_gridShowTitle ||
                    _gridShowAuthor ||
                    _gridShowLatestChapter ||
                    _gridShowProgressBar)
                  const SizedBox(height: 6),
                if (_gridShowTitle) ...[
                  Text(
                    titleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: palette.cardTextColor,
                    ),
                  ),
                ],
                if (_gridShowAuthor) ...[
                  SizedBox(height: _gridShowTitle ? 2 : 0),
                  Text(
                    authorLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: palette.textSecondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (_gridShowLatestChapter) ...[
                  SizedBox(height: (_gridShowTitle || _gridShowAuthor) ? 1 : 0),
                  Text(
                    latestLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: palette.textSecondaryColor,
                    ),
                  ),
                ],
                if (_gridShowProgressBar) ...[
                  SizedBox(
                    height:
                        (_gridShowTitle ||
                                _gridShowAuthor ||
                                _gridShowLatestChapter)
                            ? 4
                            : 0,
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progressDisplay.progressValue,
                      minHeight: 3,
                      backgroundColor: palette.elevatedSurfaceColor,
                    ),
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookCard(
    BookshelfBook book, {
    required _BookshelfBookCardState cardState,
  }) {
    final progress = cardState.progress;
    final localBook = cardState.localBook;
    final progressDisplay = _resolveBookshelfProgressDisplay(
      book,
      progress: progress,
      localBook: localBook,
      cachedChapterCount: cardState.cachedChapterCount,
    );
    final palette = _resolvedPalette(context);
    final isOpening = _openingBookId == book.bookId;
    final isSelected = _isBookSelected(book);
    final displayTitle = _displayBookTitle(book, localBook: localBook);
    final displayAuthor = _displayBookAuthor(book, localBook: localBook);
    final titleText = _toSingleLineText(displayTitle);
    final authorText = _toSingleLineText(displayAuthor ?? '');
    final latestChapterText = _toSingleLineText(
      cardState.latestCachedChapterTitle ?? book.latestChapter ?? '',
    );
    final coverHeroTag = _buildBookCoverHeroTag(book);
    final authorLine = authorText.isNotEmpty ? '作者: $authorText' : '作者: 未知';
    final latestLine =
        latestChapterText.isNotEmpty ? '最新: $latestChapterText' : '最新: 暂无章节';
    final progressLine = progressDisplay.summaryText;
    final isEditingSelected = _isSelectionMode && isSelected;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color:
          isEditingSelected
              ? palette.noticeSurfaceColor.withValues(alpha: 0.34)
              : palette.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color:
              isEditingSelected
                  ? palette.noticeAccentColor.withValues(alpha: 0.38)
                  : palette.cardBorderColor.withValues(alpha: 0.56),
        ),
      ),
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
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: _buildListSelectionIndicator(
                    selected: isSelected,
                    onTap: () => _toggleBookSelection(book),
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
                          _openBookDetail(book);
                        },
                containedInkWell: true,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 68,
                  height: 96,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _buildCover(
                          realCoverUrl: book.coverUrl,
                          title: displayTitle,
                          author: displayAuthor,
                          bookId: book.bookId,
                          sourceId: book.sourceId,
                          detailUrl: book.detailUrl,
                          heroTag: coverHeroTag,
                          width: 68,
                          height: 96,
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
              const SizedBox(width: 12),
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
                            _openBookDetail(book);
                          },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (_listShowTitle)
                            Expanded(
                              child: Text(
                                titleText,
                                style: Theme.of(
                                  context,
                                ).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: palette.cardTextColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          else
                            const Spacer(),
                          if (!_isSelectionMode) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  isOpening
                                      ? const CircularProgressIndicator(
                                        strokeWidth: 1.9,
                                      )
                                      : Container(
                                        decoration: BoxDecoration(
                                          color: palette.elevatedSurfaceColor,
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          Icons.chevron_right_rounded,
                                          size: 18,
                                          color: palette.textSecondaryColor,
                                        ),
                                      ),
                            ),
                          ],
                        ],
                      ),
                      if (_listShowAuthor) ...[
                        const SizedBox(height: 6),
                        Text(
                          authorLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: palette.textSecondaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (_listShowLatestChapter) ...[
                        SizedBox(height: _listShowAuthor ? 4 : 6),
                        Text(
                          latestLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: palette.textSecondaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        progressLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              progressDisplay.hasProgress
                                  ? palette.primaryColor
                                  : palette.textSecondaryColor,
                          fontWeight:
                              progressDisplay.hasProgress
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                        ),
                      ),
                      if (_listShowProgressBar) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progressDisplay.progressValue,
                            minHeight: 3,
                            backgroundColor: palette.elevatedSurfaceColor,
                          ),
                        ),
                      ],
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

  Widget _buildListSelectionIndicator({
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = _resolvedPalette(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color:
                  selected
                      ? palette.primaryColor
                      : colorScheme.surface.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    selected
                        ? palette.primaryColor
                        : palette.outlineColor.withValues(alpha: 0.68),
              ),
            ),
            child: Icon(
              Icons.check,
              size: 14,
              color:
                  selected
                      ? palette.buttonTextColor
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
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
    _ensureDerivedBookshelfState();
    return _filteredBooksCache;
  }

  bool _bookMatchesView(BookshelfBook book, _BookshelfViewSelection view) {
    switch (view.kind) {
      case _BookshelfViewKind.base:
        return _bookMatchesStaticFilter(book, view.filter);
      case _BookshelfViewKind.tag:
        final tag = view.tag;
        if (tag == null) {
          return true;
        }
        if (tag.isEmpty) {
          return _tagsOfBook(book).isEmpty;
        }
        return _tagsOfBook(book).contains(tag);
      case _BookshelfViewKind.category:
        final category = view.category;
        if (category == null || category.isEmpty) {
          return _categoryOfBook(book) == null;
        }
        return _categoryOfBook(book) == category;
    }
  }

  bool _bookMatchesSearchKeyword(BookshelfBook book, String keyword) {
    if (keyword.isEmpty) {
      return true;
    }

    final localBook = _bookshelfLocalBook(book);
    final bookKey = _bookKey(book);
    final candidates = <String>[
      _displayBookTitle(book, localBook: localBook),
      _displayBookAuthor(book, localBook: localBook) ?? '',
      _categoryOfBook(book) ?? book.category ?? '',
      _latestCachedChapterByBookKey[bookKey] ?? book.latestChapter ?? '',
      ..._tagsOfBook(book),
    ];

    return candidates.any(
      (candidate) => _normalizeBookshelfSearchText(candidate).contains(keyword),
    );
  }

  bool _bookMatchesStaticFilter(BookshelfBook book, _BookshelfFilter filter) {
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
        return false;
    }
  }

  List<String> get _userTags {
    _ensureDerivedBookshelfState();
    return _userTagsCache;
  }

  Map<String, int> _buildTagBookCount() {
    _ensureDerivedBookshelfState();
    return _tagBookCountCache;
  }

  Map<String, int> _buildCategoryBookCount() {
    _ensureDerivedBookshelfState();
    return _categoryBookCountCache;
  }

  List<String> get _userCategories {
    _ensureDerivedBookshelfState();
    return _userCategoriesCache;
  }

  void _ensureDerivedBookshelfState() {
    final searchKeyword = _normalizedBookshelfSearchKeyword;
    final fingerprint = Object.hash(
      _activeView,
      _sortMode,
      searchKeyword,
      identityHashCode(_books),
      identityHashCode(_progressByBookKey),
      identityHashCode(_latestCachedChapterByBookKey),
      identityHashCode(_cachedChapterCountByBookKey),
      identityHashCode(_sourceTypeBySourceId),
      identityHashCode(_localBooksById),
      identityHashCode(_bookTagsByKey),
      identityHashCode(_tagOrder),
      identityHashCode(_bookCategoriesByKey),
      identityHashCode(_categoryOrder),
      identityHashCode(_baseFilterOrder),
    );
    if (_derivedBookshelfFingerprint == fingerprint) {
      return;
    }

    final counts = <String, int>{};
    final categoryCounts = <String, int>{};
    for (final book in _books) {
      for (final tag in _tagsOfBook(book)) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
      final category = _categoryOfBook(book);
      if (category != null && category.isNotEmpty) {
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }
    }

    final tags = mergeBookshelfTaxonomyNames(counts: counts, order: _tagOrder);
    final categories = mergeBookshelfTaxonomyNames(
      counts: categoryCounts,
      order: _categoryOrder,
    );

    _tagBookCountCache = Map<String, int>.unmodifiable(counts);
    _categoryBookCountCache = Map<String, int>.unmodifiable(categoryCounts);
    _userTagsCache = List<String>.unmodifiable(tags);
    _userCategoriesCache = List<String>.unmodifiable(categories);
    final filteredBooks = _books
      .where(
        (book) =>
            _bookMatchesView(book, _activeView) &&
            _bookMatchesSearchKeyword(book, searchKeyword),
      )
      .toList(growable: true)..sort(_compareBookshelfBooks);
    _filteredBooksCache = List<BookshelfBook>.unmodifiable(filteredBooks);
    _derivedBookshelfFingerprint = fingerprint;
  }

  int _compareBookshelfBooks(BookshelfBook a, BookshelfBook b) {
    return switch (_sortMode) {
      _BookshelfSortMode.defaultOrder => _compareBookshelfBooksDefault(a, b),
      _BookshelfSortMode.recentRead => _compareBookshelfBooksByRecentRead(a, b),
      _BookshelfSortMode.readingProgress => _compareBookshelfBooksByProgress(
        a,
        b,
      ),
      _BookshelfSortMode.createdAt => _compareBookshelfBooksByCreatedAt(a, b),
      _BookshelfSortMode.author => _compareBookshelfBooksByAuthor(a, b),
      _BookshelfSortMode.title => _compareBookshelfBooksByTitle(a, b),
    };
  }

  int _compareBookshelfBooksDefault(BookshelfBook a, BookshelfBook b) {
    final progressA = _progressByBookKey[_bookKey(a)];
    final progressB = _progressByBookKey[_bookKey(b)];
    if (progressA != null && progressB != null) {
      final compare = progressB.updatedAt.compareTo(progressA.updatedAt);
      if (compare != 0) {
        return compare;
      }
    } else if (progressA != null) {
      return -1;
    } else if (progressB != null) {
      return 1;
    }

    final addedCompare = b.addedAt.compareTo(a.addedAt);
    if (addedCompare != 0) {
      return addedCompare;
    }
    return _displayBookTitle(a).compareTo(_displayBookTitle(b));
  }

  int _compareBookshelfBooksByRecentRead(BookshelfBook a, BookshelfBook b) {
    final progressA = _progressByBookKey[_bookKey(a)];
    final progressB = _progressByBookKey[_bookKey(b)];
    if (progressA != null && progressB != null) {
      final compare = progressB.updatedAt.compareTo(progressA.updatedAt);
      if (compare != 0) {
        return compare;
      }
    } else if (progressA != null) {
      return -1;
    } else if (progressB != null) {
      return 1;
    }
    return _compareBookshelfBooksDefault(a, b);
  }

  int _compareBookshelfBooksByProgress(BookshelfBook a, BookshelfBook b) {
    final progressA =
        _progressByBookKey[_bookKey(a)]?.chapterPositionRatio ?? 0;
    final progressB =
        _progressByBookKey[_bookKey(b)]?.chapterPositionRatio ?? 0;
    final compare = progressB.compareTo(progressA);
    if (compare != 0) {
      return compare;
    }
    return _compareBookshelfBooksByRecentRead(a, b);
  }

  int _compareBookshelfBooksByCreatedAt(BookshelfBook a, BookshelfBook b) {
    final createdCompare = b.addedAt.compareTo(a.addedAt);
    if (createdCompare != 0) {
      return createdCompare;
    }
    return _displayBookTitle(a).compareTo(_displayBookTitle(b));
  }

  int _compareBookshelfBooksByAuthor(BookshelfBook a, BookshelfBook b) {
    final authorA = (_displayBookAuthor(a) ?? '').trim();
    final authorB = (_displayBookAuthor(b) ?? '').trim();
    if (authorA.isNotEmpty && authorB.isNotEmpty) {
      final compare = authorA.compareTo(authorB);
      if (compare != 0) {
        return compare;
      }
    } else if (authorA.isNotEmpty) {
      return -1;
    } else if (authorB.isNotEmpty) {
      return 1;
    }
    return _compareBookshelfBooksByTitle(a, b);
  }

  int _compareBookshelfBooksByTitle(BookshelfBook a, BookshelfBook b) {
    final compare = _displayBookTitle(a).compareTo(_displayBookTitle(b));
    if (compare != 0) {
      return compare;
    }
    return _compareBookshelfBooksByCreatedAt(a, b);
  }

  List<String> _tagsOfBook(BookshelfBook book) {
    return _bookTagsByKey[_bookKey(book)] ?? const <String>[];
  }

  String? _categoryOfBook(BookshelfBook book) {
    return _bookCategoriesByKey[_bookKey(book)];
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
        return _activeView.tag ?? '标签';
    }
  }

  String _activeFilterLabel() {
    if (_activeView.isTag) {
      final tag = _activeView.tag;
      if (tag == null || tag.isEmpty) {
        return '未打标签';
      }
      return tag;
    }
    if (_activeView.isCategory) {
      final category = _activeView.category;
      if (category == null || category.isEmpty) {
        return '未分类';
      }
      return category;
    }
    return _filterLabel(_activeView.filter);
  }

  void _activateView(_BookshelfViewSelection view) {
    setState(() {
      _activeView = view;
      if (_isSelectionMode) {
        _clearSelectionState();
      }
    });
    unawaited(_persistViewSelection(view));
  }

  Future<void> _persistViewSelection(_BookshelfViewSelection view) async {
    switch (view.kind) {
      case _BookshelfViewKind.base:
        final kind = switch (view.filter) {
          _BookshelfFilter.local => 'local',
          _BookshelfFilter.novel => 'novel',
          _BookshelfFilter.manga => 'manga',
          _BookshelfFilter.all || _BookshelfFilter.custom => 'all',
        };
        await _bookshelfService.saveViewSelection(kind: kind);
      case _BookshelfViewKind.tag:
        await _bookshelfService.saveViewSelection(kind: 'tag', value: view.tag);
      case _BookshelfViewKind.category:
        await _bookshelfService.saveViewSelection(
          kind: 'category',
          value: view.category,
        );
    }
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

  String? _coverUrlCompareKey(String? url) {
    final normalized = url?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return normalized;
    }

    final query = Map<String, String>.from(uri.queryParameters);
    if (!query.containsKey('x-signature') && !query.containsKey('x-expires')) {
      return normalized;
    }

    query.remove('x-signature');
    query.remove('x-expires');
    return uri
        .replace(queryParameters: query.isEmpty ? null : query)
        .toString();
  }

  bool _hasUsableLocalCustomCover(String? url) {
    final normalized = url?.trim() ?? '';
    if (normalized.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.scheme != 'file') {
      return false;
    }
    final file = File.fromUri(uri);
    return file.existsSync();
  }

  String _toSingleLineText(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _normalizeBookshelfSearchText(String text) {
    return _toSingleLineText(text).toLowerCase();
  }

  String get _normalizedBookshelfSearchKeyword {
    return _normalizeBookshelfSearchText(_bookshelfSearchKeyword);
  }

  bool get _hasBookshelfSearchKeyword {
    return _normalizedBookshelfSearchKeyword.isNotEmpty;
  }

  Widget _buildCover({
    String? realCoverUrl,
    String? title,
    String? author,
    String? bookId,
    String? sourceId,
    String? detailUrl,
    String? heroTag,
    double width = 78,
    double height = 108,
  }) {
    final normalizedBookId = (bookId ?? '').trim();
    final localBook =
        normalizedBookId.isNotEmpty ? _localBooksById[normalizedBookId] : null;
    final override =
        normalizedBookId.isNotEmpty
            ? (sourceId == _kLocalBookSourceId
                ? _metadataOverridesByTargetKey[BookMetadataOverride.localTargetKey(
                  normalizedBookId,
                )]
                : _metadataOverridesByTargetKey[BookMetadataOverride.remoteTargetKey(
                  sourceId: sourceId ?? '',
                  detailUrl: detailUrl ?? '',
                )])
            : null;
    final presentation = _bookMetadataPresentationResolver.resolve(
      fallbackTitle: title,
      fallbackAuthor: author,
      realCoverUrl: realCoverUrl,
      localBook: localBook,
      metadataOverride: override,
    );
    final resolvedCover = resolveBookCover(
      realCoverUrl: presentation.displayCover,
      activeTheme: ref.read(activeAdvancedThemeProvider).valueOrNull,
      galleries: ref.read(coverGalleriesProvider).valueOrNull ?? const [],
      bookId: bookId,
      sourceId: sourceId,
      detailUrl: detailUrl,
    );
    final coverView = ResolvedBookCoverView(
      cover: resolvedCover,
      title: presentation.displayTitle,
      author: presentation.displayAuthor,
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(12),
    );
    if (heroTag == null || heroTag.trim().isEmpty) {
      return coverView;
    }
    return Hero(tag: heroTag.trim(), child: coverView);
  }

  ValueNotifier<_BookshelfBookCardState> _ensureBookCardStateNotifier(
    BookshelfBook book,
  ) {
    final key = _bookKey(book);
    return _bookCardStateNotifiers.putIfAbsent(
      key,
      () => ValueNotifier<_BookshelfBookCardState>(_createBookCardState(book)),
    );
  }

  _BookshelfBookCardState _createBookCardState(BookshelfBook book) {
    final key = _bookKey(book);
    return _BookshelfBookCardState(
      progress: _progressByBookKey[key],
      latestCachedChapterTitle: _latestCachedChapterByBookKey[key],
      cachedChapterCount: _cachedChapterCountByBookKey[key] ?? 0,
      localBook: _bookshelfLocalBook(book),
    );
  }

  void _syncBookCardStateNotifiers(Iterable<BookshelfBook> books) {
    final validKeys =
        books.map(_bookKey).where((key) => key.isNotEmpty).toSet();
    final staleKeys = _bookCardStateNotifiers.keys
        .where((key) => !validKeys.contains(key))
        .toList(growable: false);
    for (final key in staleKeys) {
      _bookCardStateNotifiers.remove(key)?.dispose();
    }
    for (final book in books) {
      final notifier = _ensureBookCardStateNotifier(book);
      notifier.value = _createBookCardState(book);
    }
  }

  void _updateBookCardState(
    BookshelfBook book, {
    ReadingProgress? progress,
    bool clearProgress = false,
    String? latestCachedChapterTitle,
    bool clearLatestCachedChapterTitle = false,
    int? cachedChapterCount,
    LocalBook? localBook,
    bool clearLocalBook = false,
  }) {
    final notifier = _ensureBookCardStateNotifier(book);
    notifier.value = notifier.value.copyWith(
      progress: progress,
      clearProgress: clearProgress,
      latestCachedChapterTitle: latestCachedChapterTitle,
      clearLatestCachedChapterTitle: clearLatestCachedChapterTitle,
      cachedChapterCount: cachedChapterCount,
      localBook: localBook,
      clearLocalBook: clearLocalBook,
    );
  }

  void _updateBookCardStatesForBooks(
    Iterable<BookshelfBook> books, {
    Map<String, ReadingProgress>? progressByKey,
    Map<String, String>? latestCachedChapterByKey,
    Map<String, int>? cachedChapterCountByKey,
    Map<String, LocalBook>? localBooksById,
  }) {
    for (final book in books) {
      final key = _bookKey(book);
      if (key.isEmpty) {
        continue;
      }
      _updateBookCardState(
        book,
        progress: progressByKey == null ? null : progressByKey[key],
        clearProgress: progressByKey != null && !progressByKey.containsKey(key),
        latestCachedChapterTitle:
            latestCachedChapterByKey == null
                ? null
                : latestCachedChapterByKey[key],
        clearLatestCachedChapterTitle:
            latestCachedChapterByKey != null &&
            !latestCachedChapterByKey.containsKey(key),
        cachedChapterCount:
            cachedChapterCountByKey == null
                ? null
                : (cachedChapterCountByKey[key] ?? 0),
        localBook:
            localBooksById == null ? null : localBooksById[book.bookId.trim()],
        clearLocalBook:
            localBooksById != null &&
            !localBooksById.containsKey(book.bookId.trim()),
      );
    }
  }

  LocalBook? _bookshelfLocalBook(BookshelfBook book) {
    if (book.sourceId != _kLocalBookSourceId) {
      return null;
    }
    return _localBooksById[book.bookId.trim()];
  }

  BookMetadataOverride? _bookshelfMetadataOverride(BookshelfBook book) {
    final key =
        book.sourceId == _kLocalBookSourceId
            ? BookMetadataOverride.localTargetKey(book.bookId)
            : BookMetadataOverride.remoteTargetKey(
              sourceId: book.sourceId,
              detailUrl: book.detailUrl,
            );
    return _metadataOverridesByTargetKey[key];
  }

  String _displayBookTitle(BookshelfBook book, {LocalBook? localBook}) {
    final presentation = _bookMetadataPresentationResolver.resolve(
      fallbackTitle: book.title,
      fallbackAuthor: book.author,
      realCoverUrl: book.coverUrl,
      localBook: localBook ?? _bookshelfLocalBook(book),
      metadataOverride: _bookshelfMetadataOverride(book),
    );
    return presentation.displayTitle;
  }

  String _buildBookCoverHeroTag(BookshelfBook book) {
    return 'book_cover_${book.sourceId.trim()}_${book.bookId.trim()}_${book.detailUrl.hashCode}';
  }

  String? _displayBookAuthor(BookshelfBook book, {LocalBook? localBook}) {
    final presentation = _bookMetadataPresentationResolver.resolve(
      fallbackTitle: book.title,
      fallbackAuthor: book.author,
      realCoverUrl: book.coverUrl,
      localBook: localBook ?? _bookshelfLocalBook(book),
      metadataOverride: _bookshelfMetadataOverride(book),
    );
    return presentation.displayAuthor;
  }

  Widget _buildSourceBadge(BookshelfBook book, {bool compact = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = _resolvedPalette(context);
    final isLocal = book.sourceId == _kLocalBookSourceId;
    final localBook = isLocal ? _localBooksById[book.bookId.trim()] : null;
    final (label, background, foreground) =
        isLocal
            ? _localSourceBadgePresentation(colorScheme, localBook)
            : ('在线', palette.secondaryColor, palette.buttonTextColor);
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

  (String, Color, Color) _localSourceBadgePresentation(
    ColorScheme colorScheme,
    LocalBook? localBook,
  ) {
    final palette = _resolvedPalette(context);
    final status = localBook?.indexStatus;
    return switch (status) {
      LocalBookIndexStatus.pending => (
        '待建立',
        palette.primaryContainerColor.withValues(alpha: 0.94),
        palette.textPrimaryColor,
      ),
      LocalBookIndexStatus.indexing => (
        '解析中',
        palette.elevatedSurfaceColor.withValues(alpha: 0.94),
        palette.textPrimaryColor,
      ),
      LocalBookIndexStatus.stale => (
        '需重建',
        palette.primaryContainerColor.withValues(alpha: 0.94),
        palette.textPrimaryColor,
      ),
      LocalBookIndexStatus.failed => (
        '失败',
        colorScheme.errorContainer.withValues(alpha: 0.94),
        colorScheme.onErrorContainer,
      ),
      _ => (
        '本地',
        palette.primaryContainerColor.withValues(alpha: 0.94),
        palette.textPrimaryColor,
      ),
    };
  }

  Future<void> _loadBookshelf({bool force = false}) {
    final inFlight = _activeBookshelfLoad;
    if (inFlight != null) {
      if (!force) {
        return inFlight;
      }
      _reloadAfterActiveLoad = true;
      return inFlight.whenComplete(() async {
        if (!_reloadAfterActiveLoad) {
          return;
        }
        _reloadAfterActiveLoad = false;
        if (!mounted) {
          return;
        }
        await _loadBookshelf(force: true);
      });
    }

    if (!mounted) {
      return Future<void>.value();
    }

    final now = DateTime.now();
    if (!force) {
      final lastRequestAt = _lastBookshelfLoadRequestedAt;
      if (lastRequestAt != null &&
          now.difference(lastRequestAt) < _kDuplicateLoadCooldown) {
        return Future<void>.value();
      }
    }
    _lastBookshelfLoadRequestedAt = now;

    final task = _loadBookshelfCore();
    _activeBookshelfLoad = task;
    return task.whenComplete(() {
      if (identical(_activeBookshelfLoad, task)) {
        _activeBookshelfLoad = null;
      }
    });
  }

  Future<void> _loadBookshelfCore() async {
    final ticket = ++_loadTicket;
    _cancelBackgroundLatestInfoRefresh();

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
      final retainedProgress = _retainProgressForBooks(
        source: _progressByBookKey,
        books: books,
      );
      final retainedCachedChapterTitles = _retainCachedChapterTitlesForBooks(
        source: _latestCachedChapterByBookKey,
        books: books,
      );

      if (!mounted || ticket != _loadTicket) {
        return;
      }

      setState(() {
        _books = books;
        _progressByBookKey = retainedProgress;
        _latestCachedChapterByBookKey = retainedCachedChapterTitles;
        _cachedChapterCountByBookKey = _retainCachedChapterCountsForBooks(
          source: _cachedChapterCountByBookKey,
          books: books,
        );
        _bookshelfMetadataReady = false;
        _isLoading = false;
        _ensureFilterStillValid();
      });
      _syncBookCardStateNotifiers(books);
      _syncSelectionWithBooks();
      unawaited(_maybeShowContinueReadingPrompt(ticket: ticket));

      await _loadBookshelfMetadata(books, ticket: ticket);

      if (books.isEmpty) {
        return;
      }

      await _loadLatestCachedChapterMap(books, ticket: ticket);
      await _loadCachedChapterCountMap(books, ticket: ticket);
      await _loadProgressMapInBatches(books, ticket: ticket);
      if (_skipNextBackgroundLatestInfoRefresh) {
        _skipNextBackgroundLatestInfoRefresh = false;
      } else {
        final refreshEpoch = ++_latestInfoRefreshEpoch;
        unawaited(
          _refreshOnlineBookshelfLatestInfo(
            books,
            ticket: ticket,
            refreshEpoch: refreshEpoch,
          ),
        );
      }
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

  Future<void> _loadBookshelfMetadata(
    List<BookshelfBook> books, {
    required int ticket,
  }) async {
    final sourceTypeFuture = _loadSourceTypeMap();
    final localBooksFuture = _loadLocalBookMap(books);
    final metadataOverridesFuture = _loadBookMetadataOverrideMap(books);
    final rawTagMapFuture = _bookshelfService.getTagMap();
    final tagOrderFuture = _bookshelfService.getTagOrder();
    final rawCategoryMapFuture = _bookshelfService.getCategoryMap();
    final categoryOrderFuture = _bookshelfService.getCategoryOrder();
    final baseFilterOrderNamesFuture = _bookshelfService.getBaseFilterOrder();

    try {
      await Future.wait<dynamic>([
        sourceTypeFuture,
        localBooksFuture,
        metadataOverridesFuture,
        rawTagMapFuture,
        tagOrderFuture,
        rawCategoryMapFuture,
        categoryOrderFuture,
        baseFilterOrderNamesFuture,
      ]);
    } catch (_) {
      return;
    }

    if (!mounted || ticket != _loadTicket) {
      return;
    }

    final sourceTypeMap = await sourceTypeFuture;
    final localBooksById = await localBooksFuture;
    final metadataOverridesByTargetKey = await metadataOverridesFuture;
    final rawTagMap = await rawTagMapFuture;
    final tagOrder = await tagOrderFuture;
    final rawCategoryMap = await rawCategoryMapFuture;
    final categoryOrder = await categoryOrderFuture;
    final baseFilterOrderNames = await baseFilterOrderNamesFuture;

    final validBookKeys = books.map(_bookKey).toSet();
    final tagMap = <String, List<String>>{};
    final categoryMap = <String, String>{};
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
    for (final entry in rawCategoryMap.entries) {
      if (!validBookKeys.contains(entry.key)) {
        continue;
      }
      final normalizedCategories = _normalizeTags([entry.value]);
      if (normalizedCategories.isEmpty) {
        continue;
      }
      categoryMap[entry.key] = normalizedCategories.first;
    }

    if (!mounted || ticket != _loadTicket) {
      return;
    }

    setState(() {
      _sourceTypeBySourceId = sourceTypeMap;
      _localBooksById = localBooksById;
      _metadataOverridesByTargetKey = metadataOverridesByTargetKey;
      _bookTagsByKey = tagMap;
      _tagOrder = _normalizeTags(tagOrder);
      _bookCategoriesByKey = categoryMap;
      _categoryOrder = _normalizeTags(categoryOrder);
      _baseFilterOrder = baseFilterOrderNames
          .map((name) {
            for (final filter in _kDefaultBaseFilters) {
              if (filter.name == name) {
                return filter;
              }
            }
            return null;
          })
          .whereType<_BookshelfFilter>()
          .toList(growable: false);
      _bookshelfMetadataReady = true;
      _ensureFilterStillValid();
    });
    _updateBookCardStatesForBooks(books, localBooksById: localBooksById);
    _syncSelectionWithBooks();
  }

  Future<Map<String, BookMetadataOverride>> _loadBookMetadataOverrideMap(
    List<BookshelfBook> books,
  ) async {
    if (books.isEmpty) {
      return const <String, BookMetadataOverride>{};
    }
    try {
      return await _bookshelfPresentationQueryService
          .loadBookMetadataOverrideMap(books);
    } catch (_) {
      return const <String, BookMetadataOverride>{};
    }
  }

  Future<Map<String, LocalBook>> _loadLocalBookMap(
    List<BookshelfBook> books,
  ) async {
    if (!books.any((book) => book.sourceId == _kLocalBookSourceId)) {
      return const <String, LocalBook>{};
    }

    try {
      return await _bookshelfPresentationQueryService.loadLocalBookMap(books);
    } catch (_) {
      return const <String, LocalBook>{};
    }
  }

  Future<void> _loadLatestCachedChapterMap(
    List<BookshelfBook> books, {
    required int ticket,
  }) async {
    final pairs = books
        .map((book) => MapEntry(book.bookId.trim(), book.sourceId.trim()))
        .where((entry) => entry.key.isNotEmpty && entry.value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (pairs.isEmpty) {
      return;
    }

    final latestByBookSource = await _bookshelfPresentationQueryService
        .loadLatestCachedChapterTitles(pairs);

    if (!mounted || ticket != _loadTicket) {
      return;
    }

    final latestByBookKey = <String, String>{};
    for (final book in books) {
      final bookKey = _bookKey(book);
      if (bookKey.isEmpty) {
        continue;
      }
      final pairKey = _cachedChapterBookSourceKey(
        bookId: book.bookId,
        sourceId: book.sourceId,
      );
      final title = latestByBookSource[pairKey]?.trim() ?? '';
      if (title.isEmpty) {
        continue;
      }
      latestByBookKey[bookKey] = title;
    }

    _latestCachedChapterByBookKey = latestByBookKey;
    _updateBookCardStatesForBooks(
      books,
      latestCachedChapterByKey: latestByBookKey,
    );
    if (_hasBookshelfSearchKeyword) {
      setState(() {
        _derivedBookshelfFingerprint = null;
      });
    }
  }

  Future<void> _loadCachedChapterCountMap(
    List<BookshelfBook> books, {
    required int ticket,
  }) async {
    final pairs = books
        .map((book) => MapEntry(book.bookId.trim(), book.sourceId.trim()))
        .where((entry) => entry.key.isNotEmpty && entry.value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (pairs.isEmpty) {
      return;
    }

    final countByBookSource = await _bookshelfPresentationQueryService
        .loadCachedChapterCounts(pairs);

    if (!mounted || ticket != _loadTicket) {
      return;
    }

    final countByBookKey = <String, int>{};
    for (final book in books) {
      final bookKey = _bookKey(book);
      if (bookKey.isEmpty) {
        continue;
      }
      final pairKey = _cachedChapterBookSourceKey(
        bookId: book.bookId,
        sourceId: book.sourceId,
      );
      final count = countByBookSource[pairKey] ?? 0;
      if (count <= 0) {
        continue;
      }
      countByBookKey[bookKey] = count;
    }

    _cachedChapterCountByBookKey = countByBookKey;
    _updateBookCardStatesForBooks(
      books,
      cachedChapterCountByKey: countByBookKey,
    );
  }

  Future<void> _refreshOnlineBookshelfLatestInfo(
    List<BookshelfBook> books, {
    required int ticket,
    required int refreshEpoch,
  }) async {
    final onlineBooks = books
        .where((book) => book.sourceId.trim() != _kLocalBookSourceId)
        .toList(growable: false);
    if (onlineBooks.isEmpty) {
      return;
    }

    final updatedBooksByKey = <String, BookshelfBook>{};
    for (final book in onlineBooks) {
      if (_isLatestInfoRefreshCancelled(
        ticket: ticket,
        refreshEpoch: refreshEpoch,
      )) {
        return;
      }

      try {
        final conflictKey = _bookConflictKey(
          sourceId: book.sourceId,
          detailUrl: book.detailUrl,
          bookId: book.bookId,
        );
        final sourceConflictKey = _taskConflictService.conflictKeyForSource(
          book.sourceId,
        );
        final capturedBookEpoch = _taskConflictService.captureBackgroundEpoch(
          conflictKey,
        );
        final capturedSourceEpoch = _taskConflictService.captureBackgroundEpoch(
          sourceConflictKey,
        );
        final detailResult = await _bookDetailService
            .loadForBackgroundRefresh(
              sourceId: book.sourceId,
              bookId: book.bookId,
              detailUrl: book.detailUrl,
              fallbackTitle: book.title,
              fallbackAuthor: book.author,
              cancellationHandle: SessionCancellationHandle(
                isCancelled:
                    () =>
                        _isLatestInfoRefreshCancelled(
                          ticket: ticket,
                          refreshEpoch: refreshEpoch,
                        ) ||
                        _taskConflictService.hasBackgroundConflictAdvanced(
                          conflictKey: conflictKey,
                          capturedEpoch: capturedBookEpoch,
                        ) ||
                        _taskConflictService.hasBackgroundConflictAdvanced(
                          conflictKey: sourceConflictKey,
                          capturedEpoch: capturedSourceEpoch,
                        ),
              ),
            )
            .timeout(const Duration(seconds: 8));
        if (detailResult == null) {
          continue;
        }
        await _saveBackgroundTocSnapshot(detailResult);

        final latestChapterTitle =
            detailResult.chapters
                .where(
                  (chapter) =>
                      !chapter.isVolume && chapter.chapterUrl.trim().isNotEmpty,
                )
                .map((chapter) => chapter.title.trim())
                .where((title) => title.isNotEmpty)
                .lastOrNull;
        final normalizedLatestChapter =
            latestChapterTitle == null || latestChapterTitle.isEmpty
                ? null
                : latestChapterTitle;
        final detailAuthor = detailResult.detail.author?.trim();
        final normalizedAuthor =
            detailAuthor == null || detailAuthor.isEmpty ? null : detailAuthor;
        final detailTitle = detailResult.detail.title.trim();
        final normalizedTitle =
            detailTitle.isEmpty ? book.title.trim() : detailTitle;
        final detailCoverUrl = detailResult.detail.coverUrl?.trim();
        final normalizedCoverUrl =
            detailCoverUrl == null || detailCoverUrl.isEmpty
                ? null
                : detailCoverUrl;
        final currentLatestChapter = book.latestChapter?.trim();
        final currentAuthor = book.author?.trim();
        final currentTitle = book.title.trim();
        final currentCoverUrl = book.coverUrl?.trim();
        final preserveLocalCustomCover = _hasUsableLocalCustomCover(
          currentCoverUrl,
        );
        final effectiveNextCoverUrl =
            preserveLocalCustomCover ? currentCoverUrl : normalizedCoverUrl;
        final normalizedCoverCompareKey = _coverUrlCompareKey(
          effectiveNextCoverUrl,
        );
        final currentCoverCompareKey = _coverUrlCompareKey(currentCoverUrl);

        final needsUpdate =
            normalizedTitle != currentTitle ||
            normalizedLatestChapter != currentLatestChapter ||
            normalizedAuthor != currentAuthor ||
            normalizedCoverCompareKey != currentCoverCompareKey;
        if (!needsUpdate) {
          continue;
        }

        final updatedBook = book.copyWith(
          title: normalizedTitle,
          latestChapter: normalizedLatestChapter,
          clearLatestChapter: normalizedLatestChapter == null,
          author: normalizedAuthor,
          clearAuthor: normalizedAuthor == null,
          coverUrl: effectiveNextCoverUrl,
          clearCoverUrl:
              effectiveNextCoverUrl == null || effectiveNextCoverUrl.isEmpty,
        );
        await _bookshelfService.upsert(updatedBook);
        updatedBooksByKey[_bookKey(book)] = updatedBook;
      } catch (_) {
        // Ignore per-book refresh failures to keep pull-to-refresh lightweight.
      }
    }

    if (updatedBooksByKey.isEmpty ||
        _isLatestInfoRefreshCancelled(
          ticket: ticket,
          refreshEpoch: refreshEpoch,
        )) {
      return;
    }

    if (!mounted || ticket != _loadTicket) {
      return;
    }

    setState(() {
      _books = _books
          .map((book) => updatedBooksByKey[_bookKey(book)] ?? book)
          .toList(growable: false);
      _derivedBookshelfFingerprint = null;
    });
    _syncBookCardStateNotifiers(_books);
  }

  Future<void> _saveBackgroundTocSnapshot(
    BookDetailLoadResult detailResult,
  ) async {
    final detail = detailResult.detail;
    final title = detail.title.trim();
    if (title.isEmpty || detailResult.chapters.isEmpty) {
      return;
    }

    try {
      await _readerPreferencesService.saveTocSnapshot(
        ReaderTocSnapshot(
          bookId: detail.id,
          sourceId: detail.sourceId,
          detailUrl: detail.detailUrl,
          title: title,
          author: detail.author?.trim(),
          coverUrl: detail.coverUrl?.trim(),
          chapters: detailResult.chapters,
          updatedAt: DateTime.now(),
        ),
      );
    } catch (_) {
      // Ignore toc snapshot write failures during lightweight shelf refresh.
    }
  }

  void _cancelBackgroundLatestInfoRefresh() {
    _latestInfoRefreshEpoch += 1;
  }

  bool _isLatestInfoRefreshCancelled({
    required int ticket,
    required int refreshEpoch,
  }) {
    return !mounted ||
        ticket != _loadTicket ||
        refreshEpoch != _latestInfoRefreshEpoch ||
        !_isBookshelfRoute(_lastKnownRouteLocation);
  }

  String _bookConflictKey({
    required String sourceId,
    required String detailUrl,
    required String bookId,
  }) {
    return _taskConflictService.conflictKeyForBook(
      sourceId: sourceId,
      detailUrl: detailUrl,
      bookId: bookId,
    );
  }

  void _cancelBackgroundRefreshForBook({
    required String sourceId,
    required String detailUrl,
    required String bookId,
    required SourceRuntimeConflictScene byScene,
  }) {
    final conflictKey = _bookConflictKey(
      sourceId: sourceId,
      detailUrl: detailUrl,
      bookId: bookId,
    );
    if (conflictKey.isEmpty) {
      return;
    }
    _taskConflictService.cancelBackgroundWorkFor(
      conflictKey: conflictKey,
      byScene: byScene,
    );
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

  Future<void> _restoreListPreferences() async {
    final showTitle = await _bookshelfService.loadListShowTitle();
    final showAuthor = await _bookshelfService.loadListShowAuthor();
    final showLatestChapter =
        await _bookshelfService.loadListShowLatestChapter();
    final showProgressBar = await _bookshelfService.loadListShowProgressBar();
    final alwaysShowSearchBar =
        await _bookshelfService.loadListAlwaysShowSearchBar();
    final pinSearchBar = await _bookshelfService.loadListPinSearchBar();
    final quickFilterContent = _searchQuickFilterContentFromStorageValue(
      await _bookshelfService.loadListQuickFilterContent(),
    );
    if (!mounted) {
      return;
    }
    if (_listShowTitle == showTitle &&
        _listShowAuthor == showAuthor &&
        _listShowLatestChapter == showLatestChapter &&
        _listShowProgressBar == showProgressBar &&
        _listAlwaysShowSearchBar == alwaysShowSearchBar &&
        _listPinSearchBar == pinSearchBar &&
        _listQuickFilterContent == quickFilterContent) {
      return;
    }
    setState(() {
      _listShowTitle = showTitle;
      _listShowAuthor = showAuthor;
      _listShowLatestChapter = showLatestChapter;
      _listShowProgressBar = showProgressBar;
      _listAlwaysShowSearchBar = alwaysShowSearchBar;
      _listPinSearchBar = pinSearchBar;
      _listQuickFilterContent = quickFilterContent;
    });
  }

  Future<void> _restoreSortModePreference() async {
    final loaded = _sortModeFromStorageValue(
      await _bookshelfService.loadSortMode(),
    );
    if (!mounted || _sortMode == loaded) {
      return;
    }
    setState(() {
      _sortMode = loaded;
    });
  }

  Future<void> _restoreGridPreferences() async {
    final adaptive = await _bookshelfService.loadGridAdaptiveColumns();
    final columns = await _bookshelfService.loadGridColumnCount();
    final crossSpacing = await _bookshelfService.loadGridCrossSpacing();
    final mainSpacing = await _bookshelfService.loadGridMainSpacing();
    final showTitle = await _bookshelfService.loadGridShowTitle();
    final showAuthor = await _bookshelfService.loadGridShowAuthor();
    final showLatestChapter =
        await _bookshelfService.loadGridShowLatestChapter();
    final showProgressBar = await _bookshelfService.loadGridShowProgressBar();
    final alwaysShowSearchBar =
        await _bookshelfService.loadGridAlwaysShowSearchBar();
    final pinSearchBar = await _bookshelfService.loadGridPinSearchBar();
    final quickFilterContent = _searchQuickFilterContentFromStorageValue(
      await _bookshelfService.loadGridQuickFilterContent(),
    );
    if (!mounted) {
      return;
    }
    if (_gridAdaptiveColumns == adaptive &&
        _gridColumnCount == columns &&
        _gridCrossSpacing == crossSpacing &&
        _gridMainSpacing == mainSpacing &&
        _gridShowTitle == showTitle &&
        _gridShowAuthor == showAuthor &&
        _gridShowLatestChapter == showLatestChapter &&
        _gridShowProgressBar == showProgressBar &&
        _gridAlwaysShowSearchBar == alwaysShowSearchBar &&
        _gridPinSearchBar == pinSearchBar &&
        _gridQuickFilterContent == quickFilterContent) {
      return;
    }
    setState(() {
      _gridAdaptiveColumns = adaptive;
      _gridColumnCount = columns;
      _gridCrossSpacing = crossSpacing;
      _gridMainSpacing = mainSpacing;
      _gridShowTitle = showTitle;
      _gridShowAuthor = showAuthor;
      _gridShowLatestChapter = showLatestChapter;
      _gridShowProgressBar = showProgressBar;
      _gridAlwaysShowSearchBar = alwaysShowSearchBar;
      _gridPinSearchBar = pinSearchBar;
      _gridQuickFilterContent = quickFilterContent;
    });
  }

  _BookshelfSortMode _sortModeFromStorageValue(String value) {
    return switch (value) {
      BookshelfService.recentReadSortMode => _BookshelfSortMode.recentRead,
      BookshelfService.readingProgressSortMode =>
        _BookshelfSortMode.readingProgress,
      BookshelfService.createdAtSortMode => _BookshelfSortMode.createdAt,
      BookshelfService.authorSortMode => _BookshelfSortMode.author,
      BookshelfService.titleSortMode => _BookshelfSortMode.title,
      _ => _BookshelfSortMode.defaultOrder,
    };
  }

  String _sortModeStorageValue(_BookshelfSortMode mode) {
    return switch (mode) {
      _BookshelfSortMode.defaultOrder => BookshelfService.defaultSortMode,
      _BookshelfSortMode.recentRead => BookshelfService.recentReadSortMode,
      _BookshelfSortMode.readingProgress =>
        BookshelfService.readingProgressSortMode,
      _BookshelfSortMode.createdAt => BookshelfService.createdAtSortMode,
      _BookshelfSortMode.author => BookshelfService.authorSortMode,
      _BookshelfSortMode.title => BookshelfService.titleSortMode,
    };
  }

  String _sortModeLabel(_BookshelfSortMode mode) {
    return switch (mode) {
      _BookshelfSortMode.defaultOrder => '默认排序',
      _BookshelfSortMode.recentRead => '最近阅读',
      _BookshelfSortMode.readingProgress => '阅读进度',
      _BookshelfSortMode.createdAt => '创建时间',
      _BookshelfSortMode.author => '作者',
      _BookshelfSortMode.title => '书名',
    };
  }

  String _sortModeDescription(_BookshelfSortMode mode) {
    return switch (mode) {
      _BookshelfSortMode.defaultOrder => '优先按最近阅读，其次按加入书架时间。',
      _BookshelfSortMode.recentRead => '最近打开或更新阅读位置的书籍排在前面。',
      _BookshelfSortMode.readingProgress => '按当前阅读进度从高到低排序。',
      _BookshelfSortMode.createdAt => '按加入书架时间从新到旧排序。',
      _BookshelfSortMode.author => '按作者名称排序，缺少作者信息的书排在后面。',
      _BookshelfSortMode.title => '按书名排序，相同书名再按加入时间兜底。',
    };
  }

  String _bookshelfSettingsTabLabel(_BookshelfSettingsTab tab) {
    return switch (tab) {
      _BookshelfSettingsTab.list => '列表',
      _BookshelfSettingsTab.grid => '网格',
    };
  }

  _BookshelfSearchQuickFilterContent _searchQuickFilterContentFromStorageValue(
    String value,
  ) {
    return switch (value) {
      'tags' => _BookshelfSearchQuickFilterContent.tags,
      'categories' => _BookshelfSearchQuickFilterContent.categories,
      _ => _BookshelfSearchQuickFilterContent.none,
    };
  }

  String _searchQuickFilterContentStorageValue(
    _BookshelfSearchQuickFilterContent value,
  ) {
    return switch (value) {
      _BookshelfSearchQuickFilterContent.tags => 'tags',
      _BookshelfSearchQuickFilterContent.categories => 'categories',
      _BookshelfSearchQuickFilterContent.none => 'none',
    };
  }

  String _searchQuickFilterContentLabel(
    _BookshelfSearchQuickFilterContent value,
  ) {
    return switch (value) {
      _BookshelfSearchQuickFilterContent.tags => '标签',
      _BookshelfSearchQuickFilterContent.categories => '分类',
      _BookshelfSearchQuickFilterContent.none => '不显示',
    };
  }

  Future<Map<String, int>> _loadSourceTypeMap() async {
    return _bookshelfPresentationQueryService.loadSourceTypeMap(
      timeout: _kSourceMapLoadTimeout,
      inferRuntimeSourceType: _inferScriptSourceType,
      inferPersistedSourceType: _inferScriptSourceTypeFromCode,
    );
  }

  int _inferScriptSourceType(RegisteredSource source) {
    final capabilities =
        source.definition.manifest.capabilities
            .map((item) => item.trim().toLowerCase())
            .where((item) => item.isNotEmpty)
            .toSet();
    return _isMangaCapabilities(capabilities) ? 2 : 0;
  }

  int _inferScriptSourceTypeFromCode(String sourceCode) {
    final capabilities = _extractCapabilitiesFromSourceCode(sourceCode);
    return _isMangaCapabilities(capabilities) ? 2 : 0;
  }

  bool _isMangaCapabilities(Set<String> capabilities) {
    return capabilities.any(_kMangaCapabilityKeywords.contains);
  }

  Set<String> _extractCapabilitiesFromSourceCode(String sourceCode) {
    final capabilitiesMatch = RegExp(
      r'\bcapabilities\s*:\s*\[([\s\S]*?)\]',
      caseSensitive: false,
    ).firstMatch(sourceCode);
    final rawCapabilities = capabilitiesMatch?.group(1);
    if (rawCapabilities == null || rawCapabilities.trim().isEmpty) {
      return const <String>{};
    }

    return RegExp(r'''['"]([^'"]+)['"]''')
        .allMatches(rawCapabilities)
        .map((match) => (match.group(1) ?? '').trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  Future<void> _loadProgressMapInBatches(
    List<BookshelfBook> books, {
    required int ticket,
  }) async {
    final validBookKeys =
        books.map(_bookKey).where((key) => key.isNotEmpty).toSet();
    final progressMap = <String, ReadingProgress>{
      for (final entry in _progressByBookKey.entries)
        if (validBookKeys.contains(entry.key)) entry.key: entry.value,
    };
    var batchesSinceUiUpdate = 0;
    var hasPendingUiUpdate = false;

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
          final bookKey = _bookKey(book);
          try {
            final progress = await _readerPreferencesService
                .loadProgress(book.bookId)
                .timeout(_kProgressLoadTimeout);
            return (
              book: book,
              bookKey: bookKey,
              progress: progress,
              failed: false,
            );
          } catch (_) {
            return (book: book, bookKey: bookKey, progress: null, failed: true);
          }
        }),
      );

      if (!mounted || ticket != _loadTicket) {
        return;
      }

      for (final entry in entries) {
        if (entry.failed) {
          // Keep previous progress on transient read failures to avoid flicker.
          continue;
        }
        final value = entry.progress;
        if (value != null && _isProgressMatchingBook(value, entry.book)) {
          if (progressMap[entry.bookKey] != value) {
            progressMap[entry.bookKey] = value;
            hasPendingUiUpdate = true;
          }
        } else {
          if (progressMap.remove(entry.bookKey) != null) {
            hasPendingUiUpdate = true;
          }
        }
      }

      batchesSinceUiUpdate += 1;
      final isLastBatch = end >= books.length;
      final shouldUpdateUi =
          hasPendingUiUpdate &&
          (batchesSinceUiUpdate >= _kProgressUiUpdateBatchInterval ||
              isLastBatch);
      if (shouldUpdateUi) {
        _progressByBookKey = Map<String, ReadingProgress>.from(progressMap);
        _updateBookCardStatesForBooks(batch, progressByKey: _progressByBookKey);
        final shouldResort =
            _sortMode == _BookshelfSortMode.defaultOrder ||
            _sortMode == _BookshelfSortMode.recentRead ||
            _sortMode == _BookshelfSortMode.readingProgress;
        if (shouldResort) {
          setState(() {
            _derivedBookshelfFingerprint = null;
          });
        }
        hasPendingUiUpdate = false;
        batchesSinceUiUpdate = 0;
      }

      if (end < books.length) {
        await Future<void>.delayed(Duration.zero);
      }
    }
  }

  Map<String, ReadingProgress> _retainProgressForBooks({
    required Map<String, ReadingProgress> source,
    required List<BookshelfBook> books,
  }) {
    if (source.isEmpty || books.isEmpty) {
      return const <String, ReadingProgress>{};
    }
    final validBookKeys =
        books.map(_bookKey).where((key) => key.isNotEmpty).toSet();
    final retained = <String, ReadingProgress>{};
    for (final entry in source.entries) {
      if (validBookKeys.contains(entry.key)) {
        retained[entry.key] = entry.value;
      }
    }
    return retained;
  }

  Map<String, String> _retainCachedChapterTitlesForBooks({
    required Map<String, String> source,
    required List<BookshelfBook> books,
  }) {
    if (source.isEmpty || books.isEmpty) {
      return const <String, String>{};
    }
    final validBookKeys =
        books.map(_bookKey).where((key) => key.isNotEmpty).toSet();
    final retained = <String, String>{};
    for (final entry in source.entries) {
      if (validBookKeys.contains(entry.key)) {
        retained[entry.key] = entry.value;
      }
    }
    return retained;
  }

  Map<String, int> _retainCachedChapterCountsForBooks({
    required Map<String, int> source,
    required List<BookshelfBook> books,
  }) {
    if (source.isEmpty || books.isEmpty) {
      return const <String, int>{};
    }
    final validBookKeys =
        books.map(_bookKey).where((key) => key.isNotEmpty).toSet();
    final retained = <String, int>{};
    for (final entry in source.entries) {
      if (validBookKeys.contains(entry.key)) {
        retained[entry.key] = entry.value;
      }
    }
    return retained;
  }

  String _cachedChapterBookSourceKey({
    required String bookId,
    required String sourceId,
  }) {
    return '${sourceId.trim()}\u0000${bookId.trim()}';
  }

  bool _isProgressMatchingBook(ReadingProgress progress, BookshelfBook book) {
    return progress.sourceId.trim() == book.sourceId.trim() &&
        progress.detailUrl.trim() == book.detailUrl.trim();
  }

  _BookshelfProgressDisplay _resolveBookshelfProgressDisplay(
    BookshelfBook book, {
    required ReadingProgress? progress,
    LocalBook? localBook,
    int? cachedChapterCount,
  }) {
    if (progress == null) {
      return const _BookshelfProgressDisplay(
        progressValue: 0,
        summaryText: '阅读进度: 未开始',
        trailingLabel: '未开始',
        hasProgress: false,
      );
    }

    final totalChapters = _resolveApproximateChapterCount(
      book,
      localBook: localBook,
      cachedChapterCount: cachedChapterCount,
    );
    final currentChapterNo = (progress.chapterIndex + 1).clamp(1, 999999);
    if (totalChapters != null && totalChapters > 0) {
      final normalizedTotal = totalChapters.clamp(1, 999999);
      final normalizedIndex = progress.chapterIndex.clamp(
        0,
        normalizedTotal - 1,
      );
      final overallProgress =
          (normalizedIndex + progress.chapterPositionRatio.clamp(0.0, 1.0)) /
          normalizedTotal;
      final percentage = (overallProgress.clamp(0.0, 1.0) * 100).round();
      return _BookshelfProgressDisplay(
        progressValue: overallProgress.clamp(0.0, 1.0),
        summaryText: '阅读进度: 第 $currentChapterNo / $normalizedTotal 章',
        trailingLabel: '$percentage%',
        hasProgress: true,
      );
    }

    return _BookshelfProgressDisplay(
      progressValue: progress.chapterPositionRatio.clamp(0.0, 1.0),
      summaryText: '阅读进度: 读到第 $currentChapterNo 章',
      trailingLabel: '第$currentChapterNo章',
      hasProgress: true,
    );
  }

  int? _resolveApproximateChapterCount(
    BookshelfBook book, {
    LocalBook? localBook,
    int? cachedChapterCount,
  }) {
    if (book.sourceId == _kLocalBookSourceId) {
      final localCount =
          (localBook ?? _localBooksById[book.bookId.trim()])?.chapterCount ?? 0;
      return localCount > 0 ? localCount : null;
    }

    final cachedCount =
        cachedChapterCount ?? _cachedChapterCountByBookKey[_bookKey(book)] ?? 0;
    return cachedCount > 0 ? cachedCount : null;
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _maybeShowContinueReadingPrompt({required int ticket}) async {
    if (_hasShownContinueReadingPrompt || !mounted || ticket != _loadTicket) {
      return;
    }
    if (!_isBookshelfRoute(_lastKnownRouteLocation)) {
      return;
    }

    _hasShownContinueReadingPrompt = true;

    List<ReadingRecord> records;
    try {
      records =
          await _bookshelfPresentationQueryService.listLatestReadingRecords();
    } catch (_) {
      return;
    }

    if (!mounted || ticket != _loadTicket || records.isEmpty) {
      return;
    }

    final latest = records.first;
    final title = latest.bookTitle.trim();
    if (title.isEmpty) {
      return;
    }

    if (!mounted || ticket != _loadTicket) {
      return;
    }

    setState(() {
      _continueReadingRecord = latest;
    });
    Future<void>.delayed(_kContinueReadingPromptDuration, () {
      if (!mounted || ticket != _loadTicket) {
        return;
      }
      if (_continueReadingRecord?.bookId != latest.bookId) {
        return;
      }
      _dismissContinueReadingPrompt();
    });
  }

  Future<void> _openLatestReadingRecord(ReadingRecord record) async {
    _dismissContinueReadingPrompt();
    final route = await _pageRouteService.resolveLatestReadingRecordRoute(
      record,
    );
    if (!mounted) {
      return;
    }
    context.push(route);
  }

  void _dismissContinueReadingPrompt() {
    if (!mounted || _continueReadingRecord == null) {
      return;
    }
    setState(() {
      _continueReadingRecord = null;
    });
  }

  Widget _buildContinueReadingPromptCard() {
    final record = _continueReadingRecord;
    final visible = record != null && !_isSelectionMode;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(0, 1.15),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: visible ? 1 : 0,
          child:
              record == null
                  ? const SizedBox.shrink()
                  : _buildContinueReadingCard(record),
        ),
      ),
    );
  }

  Widget _buildContinueReadingCard(ReadingRecord record) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = _resolvedPalette(context);
    final textTheme = Theme.of(context).textTheme;
    final cardBackground = Color.alphaBlend(
      palette.surfaceColor.withValues(alpha: 0.94),
      palette.cardColor,
    );
    final badgeBackground = Color.alphaBlend(
      palette.elevatedSurfaceColor.withValues(alpha: 0.96),
      palette.cardColor,
    );
    final title = _toSingleLineText(record.bookTitle);
    final author = _toSingleLineText(record.bookAuthor?.trim() ?? '');
    final chapterTitle = _toSingleLineText(
      record.lastChapterTitle?.trim() ?? '',
    );
    final relativeReadTime = _formatRelativeReadTime(record.lastReadAt);
    final chapterLabel = _buildContinueReadingChapterLabel(
      chapterIndex: record.lastChapterIndex,
      chapterTitle: chapterTitle,
    );
    final progressLabel = _buildContinueReadingProgressLabel(
      record.lastPositionRatio,
    );
    final secondaryText =
        chapterLabel ?? (author.isNotEmpty ? author : '回到上次阅读位置');

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: palette.cardBorderColor.withValues(alpha: 0.42),
          ),
          boxShadow: [
            BoxShadow(
              color: palette.shadowColor,
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => unawaited(_openLatestReadingRecord(record)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildCover(
                    realCoverUrl: record.coverUrl,
                    title: record.bookTitle,
                    author: record.bookAuthor,
                    bookId: record.bookId,
                    sourceId: record.sourceId,
                    detailUrl: record.detailUrl,
                    width: 44,
                    height: 62,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title.isEmpty ? '继续阅读' : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBackground,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '最近阅读',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(
                                color: palette.textPrimaryColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: palette.cardColor.withValues(
                                  alpha: 0.72,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                relativeReadTime,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.labelSmall?.copyWith(
                                  color: palette.textSecondaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            chapterLabel != null
                                ? Icons.auto_stories_outlined
                                : Icons.person_outline_rounded,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              secondaryText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall?.copyWith(
                                color: palette.textSecondaryColor,
                                height: 1.35,
                              ),
                            ),
                          ),
                          if (progressLabel != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: palette.noticeSurfaceColor.withValues(
                                  alpha: 0.88,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                progressLabel,
                                style: textTheme.labelSmall?.copyWith(
                                  color: palette.noticeAccentColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: palette.cardColor.withValues(alpha: 0.76),
                        border: Border.all(
                          color: palette.cardBorderColor.withValues(
                            alpha: 0.38,
                          ),
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _buildContinueReadingChapterLabel({
    required int? chapterIndex,
    required String chapterTitle,
  }) {
    final hasChapterIndex = chapterIndex != null && chapterIndex >= 0;
    if (hasChapterIndex && chapterTitle.isNotEmpty) {
      return '第 ${chapterIndex + 1} 章 · $chapterTitle';
    }
    if (hasChapterIndex) {
      return '第 ${chapterIndex + 1} 章';
    }
    if (chapterTitle.isNotEmpty) {
      return chapterTitle;
    }
    return null;
  }

  String? _buildContinueReadingProgressLabel(double ratio) {
    final normalized = ratio.clamp(0.0, 1.0);
    if (normalized <= 0) {
      return null;
    }
    return '${(normalized * 100).round()}%';
  }

  String _formatRelativeReadTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) {
      return '刚刚阅读';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes} 分钟前';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours} 小时前';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} 天前';
    }
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '$month-$day';
  }

  Future<void> _openFromBookshelf(
    BookshelfBook book, {
    ReadingProgress? progress,
  }) async {
    _cancelBackgroundLatestInfoRefresh();
    _cancelBackgroundRefreshForBook(
      sourceId: book.sourceId,
      detailUrl: book.detailUrl,
      bookId: book.bookId,
      byScene: SourceRuntimeConflictScene.reader,
    );
    if (_openingBookId != null) {
      return;
    }

    setState(() {
      _openingBookId = book.bookId;
    });

    try {
      final openRequestedAtMs = DateTime.now().millisecondsSinceEpoch;
      final openStopwatch = Stopwatch()..start();
      final localBook =
          book.sourceId == _kLocalBookSourceId
              ? (_localBooksById[book.bookId.trim()] ??
                  await _localBookRepository.getBookById(book.bookId.trim()))
              : null;
      final bookKey = _bookKey(book);
      final plan = await _readerOpenService.resolve(
        book: book,
        openRequestedAtMs: openRequestedAtMs,
        progressHint: progress,
        localBookHint: localBook,
      );

      final latestProgress = plan.latestProgress;
      if (mounted &&
          latestProgress != null &&
          _progressByBookKey[bookKey] != latestProgress) {
        setState(() {
          _progressByBookKey = Map<String, ReadingProgress>.from(
            _progressByBookKey,
          )..[bookKey] = latestProgress;
        });
      }

      if (plan.shouldStartBackgroundIndex && plan.localBook != null) {
        unawaited(() async {
          try {
            await _localBookIndexService.ensureIndexed(
              bookId: plan.localBook!.id,
            );
          } catch (_) {
            // Keep reading available even if background indexing fails.
          }
        }());
      }

      switch (plan.action) {
        case BookshelfReaderOpenAction.openDetail:
          _logger.info(
            'Bookshelf reader open delegated to detail',
            context: <String, Object?>{
              'chain': 'reader_open',
              'step': 'open_detail',
              'bookId': book.bookId,
              'sourceId': book.sourceId,
              'detailUrl': book.detailUrl,
              'kind': plan.kind.name,
              'tapToActionMs': openStopwatch.elapsedMilliseconds,
            },
          );
          _openBookDetail(book);
          if (plan.feedbackMessage != null) {
            _showMessage(plan.feedbackMessage!);
          }
          return;
        case BookshelfReaderOpenAction.openReader:
          final route = plan.readerRoute;
          if (route == null || !mounted) {
            return;
          }
          _logger.info(
            'Bookshelf reader route push',
            context: <String, Object?>{
              'chain': 'reader_open',
              'step': 'push',
              'bookId': book.bookId,
              'sourceId': book.sourceId,
              'detailUrl': book.detailUrl,
              'kind': plan.kind.name,
              'tapToPushMs': openStopwatch.elapsedMilliseconds,
            },
          );
          context.push(route);
          if (plan.feedbackMessage != null) {
            _showMessage(plan.feedbackMessage!);
          }
          return;
      }
    } on AppException {
      if (!mounted) {
        return;
      }
      _openReaderFallbackForSourceSwitch(book);
      _showMessage('当前书源可能不可用，可在阅读页直接换源。');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _openReaderFallbackForSourceSwitch(book);
      _showMessage('打开详情失败，已进入阅读页，可尝试换源。');
    } finally {
      if (mounted) {
        setState(() {
          _openingBookId = null;
        });
      }
    }
  }

  void _openReaderFallbackForSourceSwitch(BookshelfBook book) {
    _cancelBackgroundLatestInfoRefresh();
    _cancelBackgroundRefreshForBook(
      sourceId: book.sourceId,
      detailUrl: book.detailUrl,
      bookId: book.bookId,
      byScene: SourceRuntimeConflictScene.reader,
    );
    final route = _pageRouteService.resolveReaderFallbackRoute(book);
    context.push(route);
  }

  void _openBookDetail(BookshelfBook book) {
    _cancelBackgroundLatestInfoRefresh();
    _cancelBackgroundRefreshForBook(
      sourceId: book.sourceId,
      detailUrl: book.detailUrl,
      bookId: book.bookId,
      byScene: SourceRuntimeConflictScene.detail,
    );
    if (_isBatchDeleting || _isBatchUpdatingCovers) {
      return;
    }

    final route = _pageRouteService.resolveBookDetailRoute(
      book,
      heroTag: _buildBookCoverHeroTag(book),
    );
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
      await _loadBookshelf(force: true);
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

class _BookshelfPinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _BookshelfPinnedHeaderDelegate({
    required this.extent,
    required this.child,
  });

  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _BookshelfPinnedHeaderDelegate oldDelegate) {
    return oldDelegate.extent != extent || oldDelegate.child != child;
  }
}
