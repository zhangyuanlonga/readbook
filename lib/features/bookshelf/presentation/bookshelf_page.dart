import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:circular_theme_reveal/circular_theme_reveal.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/navigation/mobile_bottom_navigation_inset.dart';
import '../../../app/navigation/app_navigation_style_provider.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/theme/app_component_theme_tokens.dart';
import '../../../app/widgets/adaptive_bottom_sheet.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/app_task_bottom_sheet.dart';
import '../../../app/widgets/foundation/foundation.dart';
import '../../../app/widgets/import_export_task_overlay.dart';
import '../../../app/widgets/import_export_task_sheet.dart';
import '../../../app/widgets/resolved_book_cover.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/media/image_selection_service.dart';
import '../../../core/session/session_cancellation.dart';
import '../../../domain/entities/app_advanced_theme.dart';
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
import '../application/bookshelf_page_state.dart';
import '../application/bookshelf_presentation_query_service.dart';
import '../application/bookshelf_reader_open_service.dart';
import '../application/local_book_import_service.dart';
import '../providers.dart';
import '../../reader/application/reader_preferences_service.dart';
import '../../reader/application/local/local_book_index_service.dart';
import '../../reader/application/local/local_book_workflow_policy.dart';
import '../../book/application/book_reading_status_service.dart';
import '../../book/application/book_metadata_presentation_resolver.dart';
import '../../book/application/book_detail_service.dart';
import '../../book/application/custom_cover_storage_service.dart';
import '../../book/presentation/book_reading_status_presentation.dart';
import '../../announcement/application/announcement_service.dart';
import '../../announcement/application/announcement_read_state_service.dart';
import '../../mine/application/advanced_theme_provider.dart';
import '../../mine/application/cover_gallery_provider.dart';
import '../../source/application/external_import_catalog.dart';
import '../../source/application/external_import_diagnostics.dart';
import '../../source/application/external_source_import_bridge.dart';
import '../../source/application/remote_content_task_conflict_service.dart';
import 'bookshelf_book_action_controller.dart';
import 'bookshelf_cover_layout_resolver.dart';
import 'bookshelf_filter_header_presenter.dart';
import 'bookshelf_hero_tags.dart';
import 'bookshelf_initial_load_controller.dart';
import 'bookshelf_latest_info_refresh_controller.dart';
import 'bookshelf_page_models.dart';
import 'bookshelf_preference_mappers.dart';
import 'bookshelf_preference_restore_controller.dart';
import 'bookshelf_presentation_metadata_loader.dart';
import 'bookshelf_reading_queue_presentation.dart';
import 'bookshelf_reader_entry_controller.dart';
import 'widgets/bookshelf_book_more_menu_presenter.dart';
import 'widgets/bookshelf_grid_sliver.dart';
import 'widgets/bookshelf_grid_book_card.dart';
import 'widgets/bookshelf_library_sidebar.dart';
import 'widgets/bookshelf_list_book_card.dart';
import 'widgets/bookshelf_page_sections.dart';
import 'widgets/bookshelf_progress_indicator.dart';
import 'widgets/bookshelf_settings_switch_tile.dart';
import 'widgets/bookshelf_taxonomy_picker_surface.dart';

part 'bookshelf_page_sections.dart';
part 'bookshelf_page_flow.dart';
part 'bookshelf_page_selection.dart';

typedef _BookshelfFilter = BookshelfFilter;

typedef _BookshelfMoreAction = BookshelfMoreAction;

typedef _BookshelfSortMode = BookshelfSortMode;

typedef _BookshelfReadingStatus = BookReadingStatus;

typedef _BookshelfViewKind = BookshelfViewKind;

typedef _BookshelfGridVisualStyle = BookshelfGridVisualStyle;

typedef _BookshelfProgressInfoMode = BookshelfProgressInfoMode;

typedef _BookshelfBookMoreAction = BookshelfBookMoreAction;

typedef _BookTagEditorResult = BookTagEditorResult;

typedef _BookCategoryEditorResult = BookCategoryEditorResult;

typedef _BookshelfSearchQuickFilterContent = BookshelfSearchQuickFilterContent;

typedef _BookshelfBatchAction = BookshelfBatchAction;
typedef _BookshelfSelectionState = BookshelfSelectionState;

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

typedef _BookshelfViewSelection = BookshelfViewSelection;

typedef _BookshelfProgressDisplay = BookshelfProgressDisplay;

typedef _BookshelfBookCardState = BookshelfBookCardState;

class BookshelfPage extends ConsumerStatefulWidget {
  const BookshelfPage({super.key, this.prefetchAnnouncementOnInit = false});

  final bool prefetchAnnouncementOnInit;

  @override
  ConsumerState<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends ConsumerState<BookshelfPage>
    with AutomaticKeepAliveClientMixin<BookshelfPage> {
  static const Duration _kBookshelfPressAnimDuration = Duration(
    milliseconds: 90,
  );
  static const double _kSelectionActionBarReservedHeight = 88;
  static const List<_BookshelfFilter> _kDefaultBaseFilters = <_BookshelfFilter>[
    _BookshelfFilter.all,
    _BookshelfFilter.local,
    _BookshelfFilter.novel,
    _BookshelfFilter.manga,
  ];
  static const List<_BookshelfFilter> _kDesktopLibraryStatusFilters =
      <_BookshelfFilter>[
        _BookshelfFilter.all,
        _BookshelfFilter.todo,
        _BookshelfFilter.unread,
        _BookshelfFilter.reading,
        _BookshelfFilter.finished,
      ];
  static const BookshelfHeroTagResolver _heroTags = BookshelfHeroTagResolver();
  static const BookshelfFilterHeaderPresenter _filterHeaderPresenter =
      BookshelfFilterHeaderPresenter();

  late final BookshelfService _bookshelfService;
  late final BookshelfSystemSettingsService _bookshelfSystemSettingsService;
  late final ReaderPreferencesService _readerPreferencesService;
  late final BookshelfPageRouteService _pageRouteService;
  late final LocalBookIndexService _localBookIndexService;
  final BookDisplayStateResolver _bookMetadataPresentationResolver =
      const BookDisplayStateResolver();
  late final BookDetailService _bookDetailService;
  late final BookReadingStatusService _bookReadingStatusService;
  late final BookshelfReaderOpenService _readerOpenService;
  late final BookshelfPreferenceRestoreController _preferenceRestoreController;
  late final BookshelfReaderEntryController _readerEntryController;
  late final AppLogger _logger;
  final TextEditingController _bookshelfSearchController =
      TextEditingController();
  final FocusNode _bookshelfSearchFocusNode = FocusNode();
  final ScrollController _bookshelfScrollController = ScrollController();
  final BookshelfCoverLayoutResolver _coverLayoutResolver =
      const BookshelfCoverLayoutResolver();
  final BookshelfBookActionController _bookActionController =
      const BookshelfBookActionController();
  final BookReadingStatusPresentationMapper _readingStatusPresentationMapper =
      const BookReadingStatusPresentationMapper();
  final BookshelfReadingQueuePresentationMapper
  _readingQueuePresentationMapper =
      const BookshelfReadingQueuePresentationMapper();
  final BookshelfInitialLoadController _initialLoadController =
      BookshelfInitialLoadController();
  late final LocalBookImportService _localBookImportService;
  late final LocalBookRepository _localBookRepository;
  late final BookMetadataOverrideRepository _bookMetadataOverrideRepository;
  late final BookshelfPresentationQueryService
  _bookshelfPresentationQueryService;
  late final BookshelfPresentationMetadataLoader _presentationMetadataLoader;
  late final BookshelfExternalImportCoordinator _externalImportCoordinator;
  late final BookshelfFlowCoordinator _flowCoordinator;
  late final ImageSelectionService _imageSelectionService;
  late final CustomCoverStorageService _customCoverStorageService;
  late final AnnouncementService _announcementService;
  late final AnnouncementReadStateService _announcementReadStateService;
  late final RemoteContentTaskConflictService _taskConflictService;
  late final BookshelfLatestInfoRefreshController _latestInfoRefreshController;
  StreamSubscription<BookshelfTaxonomyChange>? _taxonomyChangeSub;
  StreamSubscription<BookshelfCollectionChange>? _collectionChangeSub;
  StreamSubscription<List<LocalBook>>? _localBooksChangeSub;
  StreamSubscription<List<BookMetadataOverride>>? _metadataOverrideChangeSub;

  bool _isLoading = true;
  List<BookshelfBook> _books = const <BookshelfBook>[];
  Map<String, ReadingProgress> _progressByBookKey =
      const <String, ReadingProgress>{};
  Map<String, String> _latestCachedChapterByBookKey = const <String, String>{};
  Map<String, int> _cachedChapterCountByBookKey = const <String, int>{};
  String? _pressedBookKey;
  Map<String, int> _sourceTypeBySourceId = const <String, int>{};
  Map<String, LocalBook> _localBooksById = const <String, LocalBook>{};
  Map<String, BookMetadataOverride> _metadataOverridesByTargetKey =
      const <String, BookMetadataOverride>{};
  Map<String, BookDisplayState> _bookPresentationByKey =
      const <String, BookDisplayState>{};
  Map<String, String> _displayTitleByBookKey = const <String, String>{};
  Map<String, String> _displayAuthorByBookKey = const <String, String>{};
  Map<String, String> _titleTextByBookKey = const <String, String>{};
  Map<String, String> _authorLineByBookKey = const <String, String>{};
  Map<String, String> _latestLineByBookKey = const <String, String>{};
  Map<String, String> _searchTextByBookKey = const <String, String>{};
  Map<String, _BookshelfProgressDisplay> _progressDisplayByBookKey =
      const <String, _BookshelfProgressDisplay>{};
  Map<String, List<String>> _bookTagsByKey = const <String, List<String>>{};
  List<String> _tagOrder = const <String>[];
  Map<String, BookshelfTaxonomyItem> _tagItemByName =
      const <String, BookshelfTaxonomyItem>{};
  Map<String, String> _bookCategoriesByKey = const <String, String>{};
  List<String> _categoryOrder = const <String>[];
  Map<String, BookshelfTaxonomyItem> _categoryItemByName =
      const <String, BookshelfTaxonomyItem>{};
  bool _bookshelfMetadataReady = false;
  Object? _derivedBookshelfFingerprint;
  List<BookshelfBook> _filteredBooksCache = const <BookshelfBook>[];
  Map<String, int> _tagBookCountCache = const <String, int>{};
  Map<String, int> _categoryBookCountCache = const <String, int>{};
  List<String> _userTagsCache = const <String>[];
  List<String> _userCategoriesCache = const <String>[];
  bool _useGridView = false;
  bool _gridAdaptiveColumns = BookshelfService.defaultGridAdaptiveColumns;
  int _gridColumnCount = BookshelfService.defaultGridColumnCount;
  double _gridCrossSpacing = BookshelfService.defaultGridCrossSpacing;
  double _gridMainSpacing = BookshelfService.defaultGridMainSpacing;
  _BookshelfGridVisualStyle _gridVisualStyle =
      _BookshelfGridVisualStyle.standard;
  bool _gridShowTitle = BookshelfService.defaultGridShowTitle;
  bool _gridTitleCenter = BookshelfService.defaultGridTitleCenter;
  int _gridTitleMaxLines = BookshelfService.defaultGridTitleMaxLines;
  bool _gridCoverShadow = BookshelfService.defaultGridCoverShadow;
  bool _gridShowAuthor = BookshelfService.defaultGridShowAuthor;
  bool _gridShowLatestChapter = BookshelfService.defaultGridShowLatestChapter;
  bool _gridShowProgressBar = BookshelfService.defaultGridShowProgressBar;
  _BookshelfProgressInfoMode _gridProgressInfoMode =
      _BookshelfProgressInfoMode.progressBar;
  bool _gridShowSourceBadge = BookshelfService.defaultGridShowSourceBadge;
  bool _gridShowTaxonomyBadges = BookshelfService.defaultGridShowTaxonomyBadges;
  bool _gridAlwaysShowSearchBar =
      BookshelfService.defaultGridAlwaysShowSearchBar;
  bool _gridPinSearchBar = BookshelfService.defaultGridPinSearchBar;
  _BookshelfSearchQuickFilterContent _gridQuickFilterContent =
      _BookshelfSearchQuickFilterContent.none;
  bool _listShowTitle = BookshelfService.defaultListShowTitle;
  bool _listShowAuthor = BookshelfService.defaultListShowAuthor;
  bool _listShowLatestChapter = BookshelfService.defaultListShowLatestChapter;
  bool _listShowProgressBar = BookshelfService.defaultListShowProgressBar;
  _BookshelfProgressInfoMode _listProgressInfoMode =
      _BookshelfProgressInfoMode.progressBar;
  bool _listShowSourceBadge = BookshelfService.defaultListShowSourceBadge;
  bool _listShowTaxonomyBadges = BookshelfService.defaultListShowTaxonomyBadges;
  bool _listShowCover = BookshelfService.defaultListShowCover;
  bool _listCompactMode = BookshelfService.defaultListCompactMode;
  bool _listTwoColumnMode = BookshelfService.defaultListTwoColumnMode;
  bool _listShowRecentReadTime = BookshelfService.defaultListShowRecentReadTime;
  bool _listAlwaysShowSearchBar =
      BookshelfService.defaultListAlwaysShowSearchBar;
  bool _listPinSearchBar = BookshelfService.defaultListPinSearchBar;
  _BookshelfSearchQuickFilterContent _listQuickFilterContent =
      _BookshelfSearchQuickFilterContent.none;
  String _bookshelfSearchKeyword = '';
  bool _isBookshelfSearchExpanded = false;
  String? _openingBookId;
  String? _loadErrorText;
  bool _isCoverRefreshActive = false;
  bool _isConsumingExternalImportPayloads = false;
  ImportExportTaskStatus? _taskStatus;
  int _loadTicket = 0;
  bool _hasActiveAnnouncement = false;
  RouteInformationProvider? _routeInformationProvider;
  String _lastKnownRouteLocation = '';
  DateTime? _lastAutoRefreshAt;
  bool? _lastKnownAutoRefreshOnTabActiveEnabled;
  Object? _lastDesktopToolbarActionsFingerprint;
  Object? _lastDesktopLibraryActionsFingerprint;
  late final StateController<DesktopBookshelfToolbarActions?>
  _desktopToolbarActionsNotifier;
  late final StateController<DesktopBookshelfLibraryActions?>
  _desktopLibraryActionsNotifier;
  final Stopwatch _bookshelfOpenStopwatch = Stopwatch()..start();
  bool _hasLoggedBookshelfFirstVisible = false;
  bool _hasShownContinueReadingPrompt = false;
  ReadingRecord? _continueReadingRecord;
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
  static const Duration _kAutoRefreshDebounce = Duration(milliseconds: 800);
  static const Duration _kDuplicateLoadCooldown = Duration(milliseconds: 700);
  static const Duration _kContinueReadingPromptDuration = Duration(seconds: 6);
  static const double _kContinueReadingCardHeight = 92;
  static const double _kContinueReadingDockGap = 12;
  static const double _kContinueReadingStandardGap = 16;
  static const double _kContinueReadingIosExtraGap = 10;
  static const double _kDesktopOnlineSearchButtonSize = 48;
  static const Duration _kDeferredBookshelfWarmupDelay = Duration(
    milliseconds: 16,
  );
  static const Duration _kPostFirstPaintBookshelfMetadataDelay = Duration(
    milliseconds: 48,
  );
  static const Set<String> _kMangaCapabilityKeywords = <String>{
    'manga',
    'comic',
    'manhua',
    'manhwa',
  };

  BookshelfPageState get _bookshelfPageState =>
      ref.read(bookshelfPageStateProvider);

  BookshelfPageStateNotifier get _bookshelfPageStateNotifier =>
      ref.read(bookshelfPageStateProvider.notifier);

  List<_BookshelfFilter> get _baseFilterOrder =>
      _bookshelfPageState.baseFilterOrder;

  set _baseFilterOrder(List<_BookshelfFilter> value) {
    _bookshelfPageStateNotifier.setBaseFilterOrder(value);
  }

  _BookshelfSortMode get _sortMode => _bookshelfPageState.sortMode;

  set _sortMode(_BookshelfSortMode value) {
    _bookshelfPageStateNotifier.setSortMode(value);
  }

  _BookshelfViewSelection get _activeView => _bookshelfPageState.activeView;

  set _activeView(_BookshelfViewSelection value) {
    _bookshelfPageStateNotifier.setActiveView(value);
  }

  _BookshelfSelectionState get _selectionState => _bookshelfPageState.selection;

  set _selectionState(_BookshelfSelectionState value) {
    _bookshelfPageStateNotifier.setSelection(value);
  }

  @override
  void initState() {
    super.initState();
    _desktopToolbarActionsNotifier = ref.read(
      desktopBookshelfToolbarActionsProvider.notifier,
    );
    _desktopLibraryActionsNotifier = ref.read(
      desktopBookshelfLibraryActionsProvider.notifier,
    );
    final dependencies = ref.read(bookshelfPageDependenciesProvider);
    _bookshelfService = dependencies.bookshelfService;
    _preferenceRestoreController = BookshelfPreferenceRestoreController(
      _bookshelfService,
    );
    _bookshelfSystemSettingsService = dependencies.systemSettingsService;
    _readerPreferencesService = dependencies.readerPreferencesService;
    _pageRouteService = dependencies.pageRouteService;
    _localBookIndexService = dependencies.localBookIndexService;
    _bookDetailService = dependencies.bookDetailService;
    _bookReadingStatusService = dependencies.readingStatusService;
    _readerOpenService = dependencies.readerOpenService;
    _readerEntryController = BookshelfReaderEntryController(
      readerOpenService: _readerOpenService,
      pageRouteService: _pageRouteService,
      localBookSourceId: _kLocalBookSourceId,
    );
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
    _presentationMetadataLoader = BookshelfPresentationMetadataLoader(
      queryService: _bookshelfPresentationQueryService,
      localBookSourceId: _kLocalBookSourceId,
    );
    _externalImportCoordinator =
        ref.read(bookshelfExternalImportCoordinatorFactoryProvider)();
    _flowCoordinator = dependencies.flowCoordinator;
    _taskConflictService = ref.read(bookshelfTaskConflictServiceProvider);
    _latestInfoRefreshController = BookshelfLatestInfoRefreshController(
      _taskConflictService,
    );
    _bookshelfSearchFocusNode.addListener(_handleBookshelfSearchFocusChanged);
    _externalImportCoordinator.initialize(
      onPendingImportAvailable: () {
        unawaited(_consumePendingExternalImportPayloads());
      },
    );
    _taxonomyChangeSub = BookshelfService.watchTaxonomyChanges.listen(
      _handleTaxonomyChange,
    );
    _collectionChangeSub = BookshelfService.watchCollectionChanges.listen(
      _handleCollectionChange,
    );
    _localBooksChangeSub = _localBookRepository.watchAllBooks().listen(
      _handleLocalBooksChanged,
    );
    _metadataOverrideChangeSub = _bookMetadataOverrideRepository
        .watchAll()
        .listen(_handleMetadataOverridesChanged);
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
    _collectionChangeSub?.cancel();
    _localBooksChangeSub?.cancel();
    _metadataOverrideChangeSub?.cancel();
    _bookshelfSearchFocusNode.removeListener(
      _handleBookshelfSearchFocusChanged,
    );
    _bookshelfScrollController.dispose();
    _bookshelfSearchFocusNode.dispose();
    _bookshelfSearchController.dispose();
    _desktopToolbarActionsNotifier.state = null;
    _desktopLibraryActionsNotifier.state = null;
    super.dispose();
  }

  void _setPressedBookKey(String? value) {
    if (_pressedBookKey == value) {
      return;
    }
    if (!mounted) {
      _pressedBookKey = value;
      return;
    }
    setState(() {
      _pressedBookKey = value;
    });
  }

  void _applyDesktopBookshelfSearchKeyword(
    String value, {
    bool rebuild = false,
  }) {
    if (_bookshelfSearchKeyword == value) {
      return;
    }
    void apply() {
      _bookshelfSearchKeyword = value;
      _derivedBookshelfFingerprint = null;
      if (_bookshelfSearchController.text != value) {
        _bookshelfSearchController.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      }
    }

    if (rebuild) {
      setState(apply);
      return;
    }
    apply();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen<String>(desktopBookshelfSearchKeywordProvider, (_, next) {
      if (!mounted || !AppAdaptiveMetrics.of(context).isMediumUpWindow) {
        return;
      }
      _applyDesktopBookshelfSearchKeyword(next, rebuild: true);
    });
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
    final metrics = AppAdaptiveMetrics.of(context);
    final useDesktopLayout = metrics.isMediumUpWindow;
    final desktopSearchKeyword =
        useDesktopLayout
            ? ref.read(desktopBookshelfSearchKeywordProvider)
            : _bookshelfSearchKeyword;
    if (useDesktopLayout) {
      _applyDesktopBookshelfSearchKeyword(desktopSearchKeyword);
    }
    final showTopSearchAction =
        effectiveNavigationStyle != AppNavigationStyle.cupertinoDock;
    final filteredBooks = _filteredBooks;
    final continueReadingVisible =
        _continueReadingRecord != null && !_isSelectionMode;
    final showDesktopOnlineSearchAction = useDesktopLayout && !_isSelectionMode;
    final continueReadingBottomInset =
        _continueReadingBottomInset(
          effectiveNavigationStyle,
          navigationBottomInset: navigationBottomInset,
          platform: platform,
        ) +
        navigationComfortInset;
    final desktopOnlineSearchBottomInset =
        continueReadingBottomInset +
        (continueReadingVisible ? _kContinueReadingCardHeight + 16 : 0);
    final topInset =
        metrics.isMediumUpWindow
            ? 0.0
            : MediaQuery.paddingOf(context).top + kToolbarHeight;
    final continueReadingReservedSpace =
        continueReadingVisible
            ? _kContinueReadingCardHeight + continueReadingBottomInset
            : navigationBottomInset + navigationComfortInset;
    final selectionActionBarBottomInset =
        navigationBottomInset + navigationComfortInset;
    final selectionActionBarReservedSpace =
        _isSelectionMode ? _kSelectionActionBarReservedHeight : 0.0;
    final contentTopPadding =
        _shouldShowBookshelfSearchSliver ? 12.0 : topInset + 12;
    final contentMaxWidth = AppLayout.pageContentMaxWidth(
      context,
      maxWidth: AppLayout.bookshelfContentMaxWidth,
    );
    final contentHorizontal = math.max(
      horizontal,
      (AppLayout.screenWidth(context) - contentMaxWidth) / 2,
    );
    _scheduleDesktopToolbarActionsRegistration(
      filteredBooks: filteredBooks,
      enabled: useDesktopLayout && !_isSelectionMode,
    );
    _scheduleDesktopLibraryActionsRegistration(
      enabled: useDesktopLayout && !_isSelectionMode,
    );

    return ImportExportTaskOverlay(
      status: _taskStatus,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        extendBodyBehindAppBar: true,
        appBar:
            metrics.isMediumUpWindow
                ? null
                : AppBar(
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
                            child: AppProgressIndicator(
                              size: 18,
                              strokeWidth: 2,
                              semanticLabel: '批量处理中',
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink()
                    else ...[
                      _buildAnnouncementAction(),
                      if (showTopSearchAction)
                        Builder(
                          builder:
                              (searchButtonContext) => IconButton(
                                tooltip: '搜索书籍',
                                onPressed:
                                    () => unawaited(
                                      _openOnlineSearchWithReveal(
                                        searchButtonContext,
                                      ),
                                    ),
                                icon: const Icon(Icons.search_rounded),
                              ),
                        ),
                      AppMenuButton<_BookshelfMoreAction>(
                        tooltip: '更多功能',
                        onSelected: _handleMoreAction,
                        actions: [
                          AppMenuAction(
                            value: _BookshelfMoreAction.selectBooks,
                            label: '选择书籍',
                            icon: Icons.checklist_rounded,
                            enabled: !_isLoading && _filteredBooks.isNotEmpty,
                          ),
                          AppMenuAction(
                            value: _BookshelfMoreAction.sortBooks,
                            label: '书籍排序',
                            icon: Icons.sort_rounded,
                            enabled: !_isLoading && _books.isNotEmpty,
                          ),
                          const AppMenuAction(
                            value: _BookshelfMoreAction.settings,
                            label: '书架设置',
                            icon: Icons.tune_rounded,
                          ),
                          const AppMenuAction(
                            value: _BookshelfMoreAction.importLocal,
                            label: '导入图书',
                            icon: Icons.library_add_rounded,
                          ),
                        ],
                        icon: Icons.more_vert_rounded,
                      ),
                    ],
                  ],
                ),
        body: Stack(
          children: [
            _buildBookshelfBackdrop(
              child: AppRefreshIndicator(
                onRefresh: () => _loadBookshelf(force: true),
                child: CustomScrollView(
                  controller: _bookshelfScrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (_shouldShowBookshelfSearchSliver &&
                        (!useDesktopLayout || _shouldShowBookshelfQuickFilters))
                      _buildBookshelfSearchSliver(
                        horizontal: contentHorizontal,
                        topInset: topInset + 12,
                        showSearchBar: !useDesktopLayout,
                      ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        contentHorizontal,
                        useDesktopLayout
                            ? (_shouldShowBookshelfQuickFilters
                                ? metrics.contentGap * 0.6
                                : metrics.contentGap)
                            : contentTopPadding,
                        contentHorizontal,
                        16 +
                            continueReadingReservedSpace +
                            selectionActionBarReservedSpace,
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
            if (showDesktopOnlineSearchAction)
              Positioned(
                right: contentHorizontal,
                bottom: desktopOnlineSearchBottomInset,
                child: Builder(
                  builder:
                      (buttonContext) =>
                          _buildDesktopOnlineSearchButton(buttonContext),
                ),
              ),
            if (_isSelectionMode)
              Positioned(
                left: contentHorizontal,
                right: contentHorizontal,
                bottom: selectionActionBarBottomInset,
                child: _buildSelectionActionBar(filteredBooks: filteredBooks),
              ),
          ],
        ),
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

  List<DesktopBookshelfDisplaySettingOption> _desktopQuickFilterSettingOptions({
    required String modeGroup,
    required _BookshelfSearchQuickFilterContent currentValue,
    required ValueChanged<_BookshelfSearchQuickFilterContent> onSelected,
  }) {
    return [
      for (final content in _BookshelfSearchQuickFilterContent.values)
        DesktopBookshelfDisplaySettingOption(
          label: '快捷筛选: ${_searchQuickFilterContentLabel(content)}',
          selected: currentValue == content,
          modeGroup: modeGroup,
          icon: _quickFilterContentIcon(content),
          onChanged: (_) => onSelected(content),
        ),
    ];
  }

  IconData _quickFilterContentIcon(_BookshelfSearchQuickFilterContent content) {
    return switch (content) {
      _BookshelfSearchQuickFilterContent.none => Icons.visibility_off_outlined,
      _BookshelfSearchQuickFilterContent.readingStatus =>
        Icons.fact_check_outlined,
      _BookshelfSearchQuickFilterContent.categories =>
        Icons.folder_copy_outlined,
      _BookshelfSearchQuickFilterContent.tags => Icons.sell_outlined,
    };
  }

  void _scheduleDesktopToolbarActionsRegistration({
    required List<BookshelfBook> filteredBooks,
    required bool enabled,
  }) {
    final fingerprint = Object.hashAll([
      enabled,
      _books.length,
      filteredBooks.length,
      _useGridView,
      _listTwoColumnMode,
      _sortMode,
      _gridShowTitle,
      _gridShowAuthor,
      _gridShowLatestChapter,
      _gridShowProgressBar,
      _gridProgressInfoMode,
      _gridShowSourceBadge,
      _gridCoverShadow,
      _gridQuickFilterContent,
      _listShowCover,
      _listCompactMode,
      _listShowTitle,
      _listShowAuthor,
      _listShowLatestChapter,
      _listShowProgressBar,
      _listProgressInfoMode,
      _listShowSourceBadge,
      _listShowRecentReadTime,
      _listQuickFilterContent,
    ]);
    if (_lastDesktopToolbarActionsFingerprint == fingerprint) {
      return;
    }
    _lastDesktopToolbarActionsFingerprint = fingerprint;

    final actions =
        enabled
            ? DesktopBookshelfToolbarActions(
              hasBooks: _books.isNotEmpty,
              hasFilteredBooks: filteredBooks.isNotEmpty,
              useGridView: _useGridView,
              useListTwoColumnMode: _listTwoColumnMode,
              sortOptions: [
                for (final mode in _BookshelfSortMode.values)
                  DesktopBookshelfSortOption(
                    mode: mode,
                    label: _sortModeLabel(mode),
                    description: _sortModeDescription(mode),
                    selected: mode == _sortMode,
                  ),
              ],
              gridSettingOptions: [
                DesktopBookshelfDisplaySettingOption(
                  label: '显示书名',
                  selected: _gridShowTitle,
                  onChanged:
                      (value) => unawaited(_setDesktopGridShowTitle(value)),
                ),
                DesktopBookshelfDisplaySettingOption(
                  label: '显示作者',
                  selected: _gridShowAuthor,
                  onChanged:
                      (value) => unawaited(_setDesktopGridShowAuthor(value)),
                ),
                DesktopBookshelfDisplaySettingOption(
                  label: '显示最新章节',
                  selected: _gridShowLatestChapter,
                  onChanged:
                      (value) =>
                          unawaited(_setDesktopGridShowLatestChapter(value)),
                ),
                DesktopBookshelfDisplaySettingOption(
                  label: '显示阅读进度',
                  selected: _gridShowProgressBar,
                  onChanged:
                      (value) =>
                          unawaited(_setDesktopGridShowProgressBar(value)),
                ),
                DesktopBookshelfDisplaySettingOption(
                  label: '阅读信息: 进度条',
                  selected:
                      _gridProgressInfoMode ==
                      _BookshelfProgressInfoMode.progressBar,
                  modeGroup: 'grid_progress_info_mode',
                  onChanged:
                      (_) => unawaited(
                        _setDesktopGridProgressInfoMode(
                          _BookshelfProgressInfoMode.progressBar,
                        ),
                      ),
                ),
                DesktopBookshelfDisplaySettingOption(
                  label: '阅读信息: 未读章节数',
                  selected:
                      _gridProgressInfoMode ==
                      _BookshelfProgressInfoMode.unreadChapters,
                  modeGroup: 'grid_progress_info_mode',
                  onChanged:
                      (_) => unawaited(
                        _setDesktopGridProgressInfoMode(
                          _BookshelfProgressInfoMode.unreadChapters,
                        ),
                      ),
                ),
                DesktopBookshelfDisplaySettingOption(
                  label: '显示来源标记',
                  selected: _gridShowSourceBadge,
                  onChanged:
                      (value) =>
                          unawaited(_setDesktopGridShowSourceBadge(value)),
                ),
                DesktopBookshelfDisplaySettingOption(
                  label: '封面阴影',
                  selected: _gridCoverShadow,
                  onChanged:
                      (value) => unawaited(_setDesktopGridCoverShadow(value)),
                ),
                ..._desktopQuickFilterSettingOptions(
                  modeGroup: 'grid_quick_filter_content',
                  currentValue: _gridQuickFilterContent,
                  onSelected:
                      (value) =>
                          unawaited(_setDesktopGridQuickFilterContent(value)),
                ),
              ],
              listSettingOptions: [
                DesktopBookshelfDisplaySettingOption(
                  label: '桌面双列列表',
                  selected: _listTwoColumnMode,
                  onChanged:
                      (value) => unawaited(_setDesktopListTwoColumnMode(value)),
                ),
                DesktopBookshelfDisplaySettingOption(
                  label: '显示封面',
                  selected: _listShowCover,
                  onChanged:
                      (value) => unawaited(_setDesktopListShowCover(value)),
                ),
                DesktopBookshelfDisplaySettingOption(
                  label: '紧凑列表',
                  selected: _listCompactMode,
                  onChanged:
                      (value) => unawaited(_setDesktopListCompactMode(value)),
                ),
                DesktopBookshelfDisplaySettingOption(
                  label: '显示书名',
                  selected: _listShowTitle,
                  onChanged:
                      (value) => unawaited(_setDesktopListShowTitle(value)),
                ),
                DesktopBookshelfDisplaySettingOption(
                  label: '显示作者',
                  selected: _listShowAuthor,
                  onChanged:
                      (value) => unawaited(_setDesktopListShowAuthor(value)),
                ),
                DesktopBookshelfDisplaySettingOption(
                  label: '显示最新章节',
                  selected: _listShowLatestChapter,
                  onChanged:
                      (value) =>
                          unawaited(_setDesktopListShowLatestChapter(value)),
                ),
                DesktopBookshelfDisplaySettingOption(
                  label: '显示阅读进度',
                  selected: _listShowProgressBar,
                  onChanged:
                      (value) =>
                          unawaited(_setDesktopListShowProgressBar(value)),
                ),
                DesktopBookshelfDisplaySettingOption(
                  label: '阅读信息: 进度条',
                  selected:
                      _listProgressInfoMode ==
                      _BookshelfProgressInfoMode.progressBar,
                  modeGroup: 'list_progress_info_mode',
                  onChanged:
                      (_) => unawaited(
                        _setDesktopListProgressInfoMode(
                          _BookshelfProgressInfoMode.progressBar,
                        ),
                      ),
                ),
                DesktopBookshelfDisplaySettingOption(
                  label: '阅读信息: 未读章节数',
                  selected:
                      _listProgressInfoMode ==
                      _BookshelfProgressInfoMode.unreadChapters,
                  modeGroup: 'list_progress_info_mode',
                  onChanged:
                      (_) => unawaited(
                        _setDesktopListProgressInfoMode(
                          _BookshelfProgressInfoMode.unreadChapters,
                        ),
                      ),
                ),
                DesktopBookshelfDisplaySettingOption(
                  label: '显示来源标记',
                  selected: _listShowSourceBadge,
                  onChanged:
                      (value) =>
                          unawaited(_setDesktopListShowSourceBadge(value)),
                ),
                DesktopBookshelfDisplaySettingOption(
                  label: '显示最近阅读',
                  selected: _listShowRecentReadTime,
                  onChanged:
                      (value) =>
                          unawaited(_setDesktopListShowRecentReadTime(value)),
                ),
                ..._desktopQuickFilterSettingOptions(
                  modeGroup: 'list_quick_filter_content',
                  currentValue: _listQuickFilterContent,
                  onSelected:
                      (value) =>
                          unawaited(_setDesktopListQuickFilterContent(value)),
                ),
              ],
              onSortModeSelected:
                  (mode) => unawaited(_applyDesktopBookshelfSortMode(mode)),
              onViewModeSelected:
                  (useGridView) =>
                      unawaited(_setBookshelfViewMode(useGridView)),
              onListTwoColumnModeSelected:
                  (enabled) => unawaited(
                    _setDesktopListTwoColumnMode(enabled, activateList: true),
                  ),
              onSelectBooks: _startSelectionMode,
              onImportLocal: () => unawaited(_showImportLocalBooksSheet()),
            )
            : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _desktopToolbarActionsNotifier.state = actions;
    });
  }

  void _scheduleDesktopLibraryActionsRegistration({required bool enabled}) {
    final statusCounts = _buildDesktopLibraryFilterBookCounts(
      _kDesktopLibraryStatusFilters,
    );
    final baseFilterCounts = _buildDesktopLibraryFilterBookCounts(
      _kDefaultBaseFilters,
    );
    final tagBookCount = _buildTagBookCount();
    final categoryBookCount = _buildCategoryBookCount();
    final userTags = _userTags;
    final userCategories = _userCategories;
    final untaggedCount =
        _books.where((book) => _tagsOfBook(book).isEmpty).length;
    final uncategorizedCount =
        _books.where((book) => (_categoryOfBook(book) ?? '').isEmpty).length;
    final fingerprint = Object.hashAll([
      enabled,
      _activeView,
      _books.length,
      identityHashCode(_progressByBookKey),
      identityHashCode(_localBooksById),
      identityHashCode(_cachedChapterCountByBookKey),
      for (final filter in _kDefaultBaseFilters) baseFilterCounts[filter] ?? 0,
      for (final filter in _kDesktopLibraryStatusFilters)
        statusCounts[filter] ?? 0,
      untaggedCount,
      uncategorizedCount,
      for (final category in userCategories) ...[
        category,
        categoryBookCount[category] ?? 0,
        _categoryItem(category).colorValue,
      ],
      for (final tag in userTags) ...[
        tag,
        tagBookCount[tag] ?? 0,
        _tagItem(tag).colorValue,
      ],
    ]);
    if (_lastDesktopLibraryActionsFingerprint == fingerprint) {
      return;
    }
    _lastDesktopLibraryActionsFingerprint = fingerprint;

    final actions = buildDesktopBookshelfLibraryActions(
      enabled: enabled,
      activeLabel: _activeFilterLabel(),
      statusActions: [
        for (final filter in _kDesktopLibraryStatusFilters)
          BookshelfLibrarySidebarActionInput(
            filter: filter,
            label: _filterLabel(filter),
            count: statusCounts[filter] ?? 0,
            selected:
                !_activeView.isTag &&
                !_activeView.isCategory &&
                _activeView.filter == filter,
            icon: _desktopLibraryStatusIcon(filter),
            onSelected:
                () => _activateView(_BookshelfViewSelection.base(filter)),
          ),
      ],
      filterGroups: [
        DesktopBookshelfLibraryFilterGroup(
          title: '快捷入口',
          actions: [
            for (final filter in _kDefaultBaseFilters)
              DesktopBookshelfLibraryFilterAction(
                label: _filterLabel(filter),
                count: baseFilterCounts[filter] ?? 0,
                selected:
                    !_activeView.isTag &&
                    !_activeView.isCategory &&
                    _activeView.filter == filter,
                icon: _desktopLibraryStatusIcon(filter),
                onSelected:
                    () => _activateView(_BookshelfViewSelection.base(filter)),
              ),
          ],
        ),
        DesktopBookshelfLibraryFilterGroup(
          title: '阅读状态',
          actions: [
            for (final filter in const <_BookshelfFilter>[
              _BookshelfFilter.todo,
              _BookshelfFilter.unread,
              _BookshelfFilter.reading,
              _BookshelfFilter.finished,
            ])
              DesktopBookshelfLibraryFilterAction(
                label: _filterLabel(filter),
                count: statusCounts[filter] ?? 0,
                selected:
                    !_activeView.isTag &&
                    !_activeView.isCategory &&
                    _activeView.filter == filter,
                icon: _desktopLibraryStatusIcon(filter),
                onSelected:
                    () => _activateView(_BookshelfViewSelection.base(filter)),
              ),
          ],
        ),
        DesktopBookshelfLibraryFilterGroup(
          title: '分类',
          emptyLabel: '暂无分类',
          actions: [
            DesktopBookshelfLibraryFilterAction(
              label: '未分类',
              count: uncategorizedCount,
              selected: _activeView.isUncategorized,
              icon: Icons.folder_off_outlined,
              onSelected:
                  () => _activateView(
                    const _BookshelfViewSelection.category(null),
                  ),
            ),
            for (final category in userCategories)
              DesktopBookshelfLibraryFilterAction(
                label: category,
                count: categoryBookCount[category] ?? 0,
                selected:
                    _activeView.isCategory && _activeView.category == category,
                icon: Icons.folder_copy_outlined,
                accentColor: Color(_categoryItem(category).colorValue),
                onSelected:
                    () => _activateView(
                      _BookshelfViewSelection.category(category),
                    ),
              ),
          ],
        ),
        DesktopBookshelfLibraryFilterGroup(
          title: '标签',
          emptyLabel: '暂无标签',
          actions: [
            DesktopBookshelfLibraryFilterAction(
              label: '未打标签',
              count: untaggedCount,
              selected: _activeView.isTag && _activeView.tag == '',
              icon: Icons.sell_outlined,
              onSelected:
                  () => _activateView(const _BookshelfViewSelection.tag('')),
            ),
            for (final tag in userTags)
              DesktopBookshelfLibraryFilterAction(
                label: tag,
                count: tagBookCount[tag] ?? 0,
                selected: _activeView.isTag && _activeView.tag == tag,
                icon: Icons.sell_outlined,
                accentColor: Color(_tagItem(tag).colorValue),
                onSelected:
                    () => _activateView(_BookshelfViewSelection.tag(tag)),
              ),
          ],
        ),
      ],
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _desktopLibraryActionsNotifier.state = actions;
    });
  }

  Map<_BookshelfFilter, int> _buildDesktopLibraryFilterBookCounts(
    Iterable<_BookshelfFilter> filters,
  ) {
    final filterList = filters.toList(growable: false);
    final counts = <_BookshelfFilter, int>{
      for (final filter in filterList) filter: 0,
    };
    for (final book in _books) {
      for (final filter in filterList) {
        if (_bookMatchesStaticFilter(book, filter)) {
          counts[filter] = (counts[filter] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  IconData _desktopLibraryStatusIcon(_BookshelfFilter filter) {
    return switch (filter) {
      _BookshelfFilter.all => Icons.library_books_outlined,
      _BookshelfFilter.todo => Icons.playlist_add_check_rounded,
      _BookshelfFilter.unread => Icons.markunread_outlined,
      _BookshelfFilter.reading => Icons.menu_book_outlined,
      _BookshelfFilter.finished => Icons.task_alt_rounded,
      _BookshelfFilter.local => Icons.folder_outlined,
      _BookshelfFilter.novel => Icons.auto_stories_outlined,
      _BookshelfFilter.manga => Icons.photo_library_outlined,
      _BookshelfFilter.custom => Icons.sell_outlined,
    };
  }

  Future<void> _applyDesktopBookshelfSortMode(
    _BookshelfSortMode selected,
  ) async {
    if (selected == _sortMode || !mounted) {
      return;
    }
    _updateBookshelfState(() {
      _sortMode = selected;
      _derivedBookshelfFingerprint = null;
      _lastDesktopToolbarActionsFingerprint = null;
    });
    try {
      await _bookshelfService.saveSortMode(_sortModeStorageValue(selected));
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('书籍排序保存失败，请重试。');
    }
  }

  void _updateBookshelfState(VoidCallback mutation) {
    if (!mounted) {
      return;
    }
    setState(mutation);
  }

  Future<void> _setDesktopGridShowTitle(bool value) {
    return _setDesktopBookshelfDisplaySetting(
      currentValue: _gridShowTitle,
      value: value,
      applyValue: () => _gridShowTitle = value,
      saveValue: _bookshelfService.saveGridShowTitle,
    );
  }

  Future<void> _setDesktopGridShowAuthor(bool value) {
    return _setDesktopBookshelfDisplaySetting(
      currentValue: _gridShowAuthor,
      value: value,
      applyValue: () => _gridShowAuthor = value,
      saveValue: _bookshelfService.saveGridShowAuthor,
    );
  }

  Future<void> _setDesktopGridShowLatestChapter(bool value) {
    return _setDesktopBookshelfDisplaySetting(
      currentValue: _gridShowLatestChapter,
      value: value,
      applyValue: () => _gridShowLatestChapter = value,
      saveValue: _bookshelfService.saveGridShowLatestChapter,
    );
  }

  Future<void> _setDesktopGridShowProgressBar(bool value) {
    return _setDesktopBookshelfDisplaySetting(
      currentValue: _gridShowProgressBar,
      value: value,
      applyValue: () => _gridShowProgressBar = value,
      saveValue: _bookshelfService.saveGridShowProgressBar,
    );
  }

  Future<void> _setDesktopGridProgressInfoMode(
    _BookshelfProgressInfoMode value,
  ) {
    return _setDesktopBookshelfProgressInfoMode(
      currentValue: _gridProgressInfoMode,
      value: value,
      applyValue: () => _gridProgressInfoMode = value,
      saveValue: _bookshelfService.saveGridProgressInfoMode,
    );
  }

  Future<void> _setDesktopGridShowSourceBadge(bool value) {
    return _setDesktopBookshelfDisplaySetting(
      currentValue: _gridShowSourceBadge,
      value: value,
      applyValue: () => _gridShowSourceBadge = value,
      saveValue: _bookshelfService.saveGridShowSourceBadge,
    );
  }

  Future<void> _setDesktopGridCoverShadow(bool value) {
    return _setDesktopBookshelfDisplaySetting(
      currentValue: _gridCoverShadow,
      value: value,
      applyValue: () => _gridCoverShadow = value,
      saveValue: _bookshelfService.saveGridCoverShadow,
    );
  }

  Future<void> _setDesktopGridQuickFilterContent(
    _BookshelfSearchQuickFilterContent value,
  ) {
    return _setDesktopBookshelfQuickFilterContent(
      currentValue: _gridQuickFilterContent,
      value: value,
      applyValue: () => _gridQuickFilterContent = value,
      saveValue: _bookshelfService.saveGridQuickFilterContent,
    );
  }

  Future<void> _setDesktopListShowCover(bool value) {
    return _setDesktopBookshelfDisplaySetting(
      currentValue: _listShowCover,
      value: value,
      applyValue: () => _listShowCover = value,
      saveValue: _bookshelfService.saveListShowCover,
    );
  }

  Future<void> _setDesktopListCompactMode(bool value) {
    return _setDesktopBookshelfDisplaySetting(
      currentValue: _listCompactMode,
      value: value,
      applyValue: () => _listCompactMode = value,
      saveValue: _bookshelfService.saveListCompactMode,
    );
  }

  Future<void> _setDesktopListTwoColumnMode(
    bool value, {
    bool activateList = false,
  }) async {
    if (!mounted) {
      return;
    }
    if (_listTwoColumnMode == value && (!activateList || !_useGridView)) {
      return;
    }

    _updateBookshelfLayoutPreservingScroll(() {
      _updateBookshelfState(() {
        if (activateList) {
          _useGridView = false;
        }
        _listTwoColumnMode = value;
        _derivedBookshelfFingerprint = null;
        _lastDesktopToolbarActionsFingerprint = null;
      });
    });

    try {
      if (activateList) {
        await _bookshelfService.saveUseGridView(false);
      }
      await _bookshelfService.saveListTwoColumnMode(value);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('书架设置保存失败，请重试。');
    }
  }

  Future<void> _setDesktopListShowTitle(bool value) {
    return _setDesktopBookshelfDisplaySetting(
      currentValue: _listShowTitle,
      value: value,
      applyValue: () => _listShowTitle = value,
      saveValue: _bookshelfService.saveListShowTitle,
    );
  }

  Future<void> _setDesktopListShowAuthor(bool value) {
    return _setDesktopBookshelfDisplaySetting(
      currentValue: _listShowAuthor,
      value: value,
      applyValue: () => _listShowAuthor = value,
      saveValue: _bookshelfService.saveListShowAuthor,
    );
  }

  Future<void> _setDesktopListShowLatestChapter(bool value) {
    return _setDesktopBookshelfDisplaySetting(
      currentValue: _listShowLatestChapter,
      value: value,
      applyValue: () => _listShowLatestChapter = value,
      saveValue: _bookshelfService.saveListShowLatestChapter,
    );
  }

  Future<void> _setDesktopListShowProgressBar(bool value) {
    return _setDesktopBookshelfDisplaySetting(
      currentValue: _listShowProgressBar,
      value: value,
      applyValue: () => _listShowProgressBar = value,
      saveValue: _bookshelfService.saveListShowProgressBar,
    );
  }

  Future<void> _setDesktopListProgressInfoMode(
    _BookshelfProgressInfoMode value,
  ) {
    return _setDesktopBookshelfProgressInfoMode(
      currentValue: _listProgressInfoMode,
      value: value,
      applyValue: () => _listProgressInfoMode = value,
      saveValue: _bookshelfService.saveListProgressInfoMode,
    );
  }

  Future<void> _setDesktopListShowSourceBadge(bool value) {
    return _setDesktopBookshelfDisplaySetting(
      currentValue: _listShowSourceBadge,
      value: value,
      applyValue: () => _listShowSourceBadge = value,
      saveValue: _bookshelfService.saveListShowSourceBadge,
    );
  }

  Future<void> _setDesktopListShowRecentReadTime(bool value) {
    return _setDesktopBookshelfDisplaySetting(
      currentValue: _listShowRecentReadTime,
      value: value,
      applyValue: () => _listShowRecentReadTime = value,
      saveValue: _bookshelfService.saveListShowRecentReadTime,
    );
  }

  Future<void> _setDesktopListQuickFilterContent(
    _BookshelfSearchQuickFilterContent value,
  ) {
    return _setDesktopBookshelfQuickFilterContent(
      currentValue: _listQuickFilterContent,
      value: value,
      applyValue: () => _listQuickFilterContent = value,
      saveValue: _bookshelfService.saveListQuickFilterContent,
    );
  }

  Future<void> _setDesktopBookshelfDisplaySetting({
    required bool currentValue,
    required bool value,
    required VoidCallback applyValue,
    required Future<void> Function(bool value) saveValue,
  }) async {
    if (currentValue == value || !mounted) {
      return;
    }

    _updateBookshelfLayoutPreservingScroll(() {
      _updateBookshelfState(() {
        applyValue();
        _derivedBookshelfFingerprint = null;
        _lastDesktopToolbarActionsFingerprint = null;
      });
    });

    try {
      await saveValue(value);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('书架设置保存失败，请重试。');
    }
  }

  Future<void> _setDesktopBookshelfProgressInfoMode({
    required _BookshelfProgressInfoMode currentValue,
    required _BookshelfProgressInfoMode value,
    required VoidCallback applyValue,
    required Future<void> Function(String value) saveValue,
  }) async {
    if (currentValue == value || !mounted) {
      return;
    }

    _updateBookshelfLayoutPreservingScroll(() {
      _updateBookshelfState(() {
        applyValue();
        _lastDesktopToolbarActionsFingerprint = null;
      });
    });

    try {
      await saveValue(_progressInfoModeStorageValue(value));
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('书架设置保存失败，请重试。');
    }
  }

  Future<void> _setDesktopBookshelfQuickFilterContent({
    required _BookshelfSearchQuickFilterContent currentValue,
    required _BookshelfSearchQuickFilterContent value,
    required VoidCallback applyValue,
    required Future<void> Function(String value) saveValue,
  }) async {
    if (currentValue == value || !mounted) {
      return;
    }

    _updateBookshelfLayoutPreservingScroll(() {
      _updateBookshelfState(() {
        applyValue();
        _lastDesktopToolbarActionsFingerprint = null;
      });
    });

    try {
      await saveValue(_searchQuickFilterContentStorageValue(value));
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('书架设置保存失败，请重试。');
    }
  }

  void _handleBookMoreAction(
    BookshelfBook book,
    _BookshelfBookMoreAction action,
  ) {
    final intent = _bookActionController.resolve(
      action: action,
      actionsLocked: _isBatchDeleting || _isBatchUpdatingCovers,
    );
    if (intent == null) {
      return;
    }

    switch (intent) {
      case BookshelfBookActionIntent.openDetail:
        _openBookDetail(book);
      case BookshelfBookActionIntent.openEdit:
        _openBookDetail(book, initialEditMode: true);
      case BookshelfBookActionIntent.editTags:
        unawaited(_showBookTagEditor(book));
      case BookshelfBookActionIntent.editCategory:
        unawaited(_showBookCategoryEditor(book));
      case BookshelfBookActionIntent.toggleReadingQueue:
        unawaited(_setBookReadingQueue(book, !book.inReadingQueue));
      case BookshelfBookActionIntent.select:
        final key = _bookKey(book);
        if (key.isEmpty) {
          return;
        }
        _updateBookshelfState(
          () => _setSelectionEnabled(true, selectedKeys: <String>{key}),
        );
      case BookshelfBookActionIntent.delete:
        unawaited(_confirmAndRemoveBook(book));
    }
  }

  Future<void> _showBookTagEditor(BookshelfBook book) async {
    if (book.sourceId.trim().isEmpty || book.detailUrl.trim().isEmpty) {
      _showMessage('书籍信息不完整，暂不能设置标签。');
      return;
    }

    final bookKey = _bookKey(book);
    var selectedTags = _normalizeTags(_tagsOfBook(book));
    var createdItems = const <BookshelfTaxonomyItem>[];
    final createNameController = TextEditingController();
    var isCreating = false;
    var createColor = Color(BookshelfTaxonomyItem.defaultColorForName('新标签'));
    String? createErrorText;
    _BookTagEditorResult? result;
    try {
      result = await _showBookshelfBottomSheet<_BookTagEditorResult>(
        isScrollControlled: true,
        maxWidth: 560,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              void submitCreate() {
                final normalizedName = _firstNormalizedTaxonomyName([
                  createNameController.text,
                ]);
                if (normalizedName == null) {
                  setSheetState(() {
                    createErrorText = '请输入标签名称';
                  });
                  return;
                }
                final created = BookshelfTaxonomyItem(
                  name: normalizedName,
                  colorValue: createColor.toARGB32(),
                );
                setSheetState(() {
                  createdItems = _upsertDraftTaxonomyItem(
                    createdItems,
                    created,
                  );
                  selectedTags = _normalizeTags([
                    ...selectedTags,
                    created.name,
                  ]);
                  createNameController.clear();
                  createColor = Color(
                    BookshelfTaxonomyItem.defaultColorForName('新标签'),
                  );
                  createErrorText = null;
                  isCreating = false;
                });
              }

              final availableItems = _availableBookTagItems(
                selectedTags: selectedTags,
                createdItems: createdItems,
              );

              return BookshelfTaxonomyPickerSurface(
                icon: Icons.sell_rounded,
                title: '编辑标签',
                subtitle: _displayBookTitle(book),
                createLabel: '新增',
                onCreate: () {
                  setSheetState(() {
                    isCreating = !isCreating;
                    createErrorText = null;
                  });
                },
                onCancel: () => _dismissBookshelfBottomSheet(sheetContext),
                onSave: () {
                  _dismissBookshelfBottomSheet(
                    sheetContext,
                    _BookTagEditorResult(
                      tags: List<String>.unmodifiable(selectedTags),
                      createdItems: List<BookshelfTaxonomyItem>.unmodifiable(
                        createdItems,
                      ),
                    ),
                  );
                },
                createPanel:
                    isCreating
                        ? BookshelfInlineTaxonomyCreatePanel(
                          kind: BookshelfTaxonomyKind.tag,
                          nameController: createNameController,
                          color: createColor,
                          errorText: createErrorText,
                          formatColorLabel: _formatTaxonomyHex,
                          onColorChanged:
                              (color) => setSheetState(() {
                                createColor = color;
                              }),
                          onNameChanged:
                              (_) => setSheetState(() {
                                createErrorText = null;
                              }),
                          onSubmit: submitCreate,
                          onCancel:
                              () => setSheetState(() {
                                createNameController.clear();
                                createErrorText = null;
                                isCreating = false;
                              }),
                        )
                        : null,
                child: BookshelfTagPicker(
                  items: availableItems,
                  selectedTags: selectedTags,
                  normalizeTags: _normalizeTags,
                  onChanged: (tags) {
                    setSheetState(() {
                      selectedTags = _normalizeTags(tags);
                    });
                  },
                ),
              );
            },
          );
        },
      );
    } finally {
      createNameController.dispose();
    }

    if (result == null) {
      return;
    }

    await _saveBookTags(
      book: book,
      bookKey: bookKey,
      tags: result.tags,
      createdItems: result.createdItems,
    );
  }

  Future<void> _showBookCategoryEditor(BookshelfBook book) async {
    if (book.sourceId.trim().isEmpty || book.detailUrl.trim().isEmpty) {
      _showMessage('书籍信息不完整，暂不能设置分类。');
      return;
    }

    final bookKey = _bookKey(book);
    var selectedCategory = _categoryOfBook(book);
    var createdItems = const <BookshelfTaxonomyItem>[];
    final createNameController = TextEditingController();
    var isCreating = false;
    var createColor = Color(BookshelfTaxonomyItem.defaultColorForName('新分类'));
    String? createErrorText;
    _BookCategoryEditorResult? result;
    try {
      result = await _showBookshelfBottomSheet<_BookCategoryEditorResult>(
        isScrollControlled: true,
        maxWidth: 560,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              void submitCreate() {
                final normalizedName = _firstNormalizedTaxonomyName([
                  createNameController.text,
                ]);
                if (normalizedName == null) {
                  setSheetState(() {
                    createErrorText = '请输入分类名称';
                  });
                  return;
                }
                final created = BookshelfTaxonomyItem(
                  name: normalizedName,
                  colorValue: createColor.toARGB32(),
                );
                setSheetState(() {
                  createdItems = _upsertDraftTaxonomyItem(
                    createdItems,
                    created,
                  );
                  selectedCategory = created.name;
                  createNameController.clear();
                  createColor = Color(
                    BookshelfTaxonomyItem.defaultColorForName('新分类'),
                  );
                  createErrorText = null;
                  isCreating = false;
                });
              }

              final availableItems = _availableBookCategoryItems(
                selectedCategory: selectedCategory,
                createdItems: createdItems,
              );

              return BookshelfTaxonomyPickerSurface(
                icon: Icons.folder_rounded,
                title: '编辑分类',
                subtitle: _displayBookTitle(book),
                createLabel: '新增',
                onCreate: () {
                  setSheetState(() {
                    isCreating = !isCreating;
                    createErrorText = null;
                  });
                },
                onCancel: () => _dismissBookshelfBottomSheet(sheetContext),
                onSave: () {
                  _dismissBookshelfBottomSheet(
                    sheetContext,
                    _BookCategoryEditorResult(
                      category: _firstNormalizedTaxonomyName([
                        selectedCategory ?? '',
                      ]),
                      createdItems: List<BookshelfTaxonomyItem>.unmodifiable(
                        createdItems,
                      ),
                    ),
                  );
                },
                createPanel:
                    isCreating
                        ? BookshelfInlineTaxonomyCreatePanel(
                          kind: BookshelfTaxonomyKind.category,
                          nameController: createNameController,
                          color: createColor,
                          errorText: createErrorText,
                          formatColorLabel: _formatTaxonomyHex,
                          onColorChanged:
                              (color) => setSheetState(() {
                                createColor = color;
                              }),
                          onNameChanged:
                              (_) => setSheetState(() {
                                createErrorText = null;
                              }),
                          onSubmit: submitCreate,
                          onCancel:
                              () => setSheetState(() {
                                createNameController.clear();
                                createErrorText = null;
                                isCreating = false;
                              }),
                        )
                        : null,
                child: BookshelfCategoryPicker(
                  items: availableItems,
                  selectedCategory: selectedCategory,
                  onChanged: (category) {
                    setSheetState(() {
                      selectedCategory = _firstNormalizedTaxonomyName([
                        category ?? '',
                      ]);
                    });
                  },
                ),
              );
            },
          );
        },
      );
    } finally {
      createNameController.dispose();
    }

    if (result == null) {
      return;
    }

    await _saveBookCategory(
      book: book,
      bookKey: bookKey,
      category: result.category,
      createdItems: result.createdItems,
    );
  }

  String? _firstNormalizedTaxonomyName(Iterable<String> values) {
    final normalized = _normalizeTags(values);
    return normalized.isEmpty ? null : normalized.first;
  }

  List<BookshelfTaxonomyItem> _availableBookTagItems({
    required List<String> selectedTags,
    required List<BookshelfTaxonomyItem> createdItems,
  }) {
    final createdByName = <String, BookshelfTaxonomyItem>{
      for (final item in createdItems) item.name: item,
    };
    final counts = _buildTagBookCount();
    final names = mergeBookshelfTaxonomyNames(
      counts: counts,
      order: <String>[
        ..._tagOrder,
        ..._tagItemByName.keys,
        ...selectedTags,
        ...createdByName.keys,
      ],
    );
    return [for (final name in names) createdByName[name] ?? _tagItem(name)];
  }

  List<BookshelfTaxonomyItem> _availableBookCategoryItems({
    required String? selectedCategory,
    required List<BookshelfTaxonomyItem> createdItems,
  }) {
    final createdByName = <String, BookshelfTaxonomyItem>{
      for (final item in createdItems) item.name: item,
    };
    final counts = _buildCategoryBookCount();
    final names = mergeBookshelfTaxonomyNames(
      counts: counts,
      order: <String>[
        ..._categoryOrder,
        ..._categoryItemByName.keys,
        if (selectedCategory != null) selectedCategory,
        ...createdByName.keys,
      ],
    );
    return [
      for (final name in names) createdByName[name] ?? _categoryItem(name),
    ];
  }

  List<BookshelfTaxonomyItem> _upsertDraftTaxonomyItem(
    List<BookshelfTaxonomyItem> items,
    BookshelfTaxonomyItem item,
  ) {
    final normalizedName = _firstNormalizedTaxonomyName([item.name]);
    if (normalizedName == null) {
      return items;
    }

    final normalizedItem = item.copyWith(name: normalizedName);
    final next = List<BookshelfTaxonomyItem>.from(items);
    final index = next.indexWhere((entry) => entry.name == normalizedName);
    if (index < 0) {
      next.add(normalizedItem);
    } else {
      next[index] = normalizedItem;
    }
    return List<BookshelfTaxonomyItem>.unmodifiable(next);
  }

  Future<void> _saveBookTags({
    required BookshelfBook book,
    required String bookKey,
    required List<String> tags,
    required List<BookshelfTaxonomyItem> createdItems,
  }) async {
    final normalizedTags = _normalizeTags(tags);
    try {
      for (final item in createdItems) {
        await _bookshelfService.upsertTagItem(
          name: item.name,
          colorValue: item.colorValue,
        );
      }
      await _bookshelfService.setBookTags(
        sourceId: book.sourceId,
        detailUrl: book.detailUrl,
        tags: normalizedTags,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('标签保存失败，请重试。');
      return;
    }

    if (!mounted) {
      return;
    }
    _updateBookshelfLayoutPreservingScroll(() {
      _updateBookshelfState(() {
        _applyBookTagAssignment(
          bookKey: bookKey,
          tags: normalizedTags,
          createdItems: createdItems,
        );
      });
    });
    _showMessage(normalizedTags.isEmpty ? '已清除标签。' : '标签已更新。');
  }

  Future<void> _saveBookCategory({
    required BookshelfBook book,
    required String bookKey,
    required String? category,
    required List<BookshelfTaxonomyItem> createdItems,
  }) async {
    final normalizedCategory = _firstNormalizedTaxonomyName([category ?? '']);
    try {
      for (final item in createdItems) {
        await _bookshelfService.upsertCategoryItem(
          name: item.name,
          colorValue: item.colorValue,
        );
      }
      await _bookshelfService.setBookCategory(
        sourceId: book.sourceId,
        detailUrl: book.detailUrl,
        category: normalizedCategory,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('分类保存失败，请重试。');
      return;
    }

    if (!mounted) {
      return;
    }
    _updateBookshelfLayoutPreservingScroll(() {
      _updateBookshelfState(() {
        _applyBookCategoryAssignment(
          bookKey: bookKey,
          category: normalizedCategory,
          createdItems: createdItems,
        );
      });
    });
    _showMessage(normalizedCategory == null ? '已清除分类。' : '分类已更新。');
  }

  // 保存成功后先更新当前页缓存，让筛选、搜索、书籍角标立即响应；服务层事件随后会兜底刷新元数据。
  void _applyBookTagAssignment({
    required String bookKey,
    required List<String> tags,
    required List<BookshelfTaxonomyItem> createdItems,
  }) {
    final nextTagMap = Map<String, List<String>>.from(_bookTagsByKey);
    if (tags.isEmpty) {
      nextTagMap.remove(bookKey);
    } else {
      nextTagMap[bookKey] = List<String>.unmodifiable(tags);
    }
    _bookTagsByKey = Map<String, List<String>>.unmodifiable(nextTagMap);

    final nextItemByName = Map<String, BookshelfTaxonomyItem>.from(
      _tagItemByName,
    );
    for (final item in createdItems) {
      final normalizedName = _firstNormalizedTaxonomyName([item.name]);
      if (normalizedName == null) {
        continue;
      }
      nextItemByName[normalizedName] = item.copyWith(name: normalizedName);
    }
    _tagItemByName = Map<String, BookshelfTaxonomyItem>.unmodifiable(
      nextItemByName,
    );
    _tagOrder = List<String>.unmodifiable(
      _normalizeTags([..._tagOrder, ...createdItems.map((item) => item.name)]),
    );
    _derivedBookshelfFingerprint = null;
    _ensureFilterStillValid();
  }

  void _applyBookCategoryAssignment({
    required String bookKey,
    required String? category,
    required List<BookshelfTaxonomyItem> createdItems,
  }) {
    final nextCategoryMap = Map<String, String>.from(_bookCategoriesByKey);
    if (category == null) {
      nextCategoryMap.remove(bookKey);
    } else {
      nextCategoryMap[bookKey] = category;
    }
    _bookCategoriesByKey = Map<String, String>.unmodifiable(nextCategoryMap);

    _books = List<BookshelfBook>.unmodifiable(
      _books.map((entry) {
        if (_bookKey(entry) != bookKey) {
          return entry;
        }
        return entry.copyWith(
          category: category,
          clearCategory: category == null,
        );
      }),
    );

    final nextItemByName = Map<String, BookshelfTaxonomyItem>.from(
      _categoryItemByName,
    );
    for (final item in createdItems) {
      final normalizedName = _firstNormalizedTaxonomyName([item.name]);
      if (normalizedName == null) {
        continue;
      }
      nextItemByName[normalizedName] = item.copyWith(name: normalizedName);
    }
    _categoryItemByName = Map<String, BookshelfTaxonomyItem>.unmodifiable(
      nextItemByName,
    );
    _categoryOrder = List<String>.unmodifiable(
      _normalizeTags([
        ..._categoryOrder,
        ...createdItems.map((item) => item.name),
      ]),
    );
    _derivedBookshelfFingerprint = null;
    _ensureFilterStillValid();
  }

  Future<void> _setBookReadingQueue(
    BookshelfBook book,
    bool inReadingQueue,
  ) async {
    try {
      await _bookshelfService.setInReadingQueue(
        sourceId: book.sourceId,
        detailUrl: book.detailUrl,
        inReadingQueue: inReadingQueue,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage(_readingQueuePresentationMapper.failureMessage);
      return;
    }

    if (!mounted) {
      return;
    }
    _updateBookshelfLayoutPreservingScroll(() {
      _updateBookshelfState(() {
        _books = List<BookshelfBook>.unmodifiable(
          _books.map((entry) {
            if (_bookKey(entry) != _bookKey(book)) {
              return entry;
            }
            return entry.copyWith(inReadingQueue: inReadingQueue);
          }),
        );
        _derivedBookshelfFingerprint = null;
        _ensureFilterStillValid();
      });
    });
    _showMessage(
      _readingQueuePresentationMapper
          .resolve(inReadingQueue: inReadingQueue)
          .successMessage,
    );
  }

  Future<void> _markBookReadingStatus(
    BookshelfBook book,
    _BookshelfReadingStatus status,
  ) async {
    if (_readingStatusOfBook(book) == status) {
      _showMessage('当前已是${_readingStatusLabel(status)}。');
      return;
    }

    final bookKey = _bookKey(book);
    BookReadingStatusMarkResult? result;
    try {
      result = await _bookReadingStatusService.markBookshelfBookStatus(
        book: book,
        status: status,
        existingProgress: _progressByBookKey[bookKey],
        localBook: _bookshelfLocalBook(book),
        cachedChapterCount: _cachedChapterCountByBookKey[bookKey],
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('阅读状态保存失败，请重试。');
      return;
    }
    if (result == null) {
      if (mounted) {
        _showMessage('暂无可用章节，暂不能标记为${_readingStatusLabel(status)}。');
      }
      return;
    }
    final markResult = result;

    if (!mounted) {
      return;
    }
    _updateBookshelfLayoutPreservingScroll(() {
      _updateBookshelfState(() {
        final nextProgress = Map<String, ReadingProgress>.from(
          _progressByBookKey,
        );
        final progress = markResult.progress;
        if (progress == null) {
          nextProgress.remove(bookKey);
        } else {
          nextProgress[bookKey] = progress;
        }
        _progressByBookKey = Map<String, ReadingProgress>.unmodifiable(
          nextProgress,
        );
        final cachedChapterCount = markResult.cachedChapterCount;
        if (cachedChapterCount != null && cachedChapterCount > 0) {
          _cachedChapterCountByBookKey = Map<String, int>.unmodifiable(
            Map<String, int>.from(_cachedChapterCountByBookKey)
              ..[bookKey] = cachedChapterCount,
          );
        }
        _derivedBookshelfFingerprint = null;
        _ensureFilterStillValid();
      });
    });
    final nextProgress = markResult.progress;
    if (nextProgress == null) {
      _updateBookCardState(book, clearProgress: true);
      _showMessage('已标记为未读。');
    } else {
      _updateBookCardState(book, progress: nextProgress);
      _showMessage('已标记为${_readingStatusLabel(status)}。');
    }
  }

  String _readingStatusLabel(_BookshelfReadingStatus status) {
    return _readingStatusPresentationMapper.resolve(status).label;
  }

  Future<void> _confirmAndRemoveBook(BookshelfBook book) async {
    if (!mounted) {
      return;
    }
    final title = _displayBookTitle(book);
    final confirmed = await showAdaptiveActionSurface<bool>(
      context: context,
      maxWidth: 460,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final mediaQuery = MediaQuery.of(dialogContext);
        final safeBottom = math.max(
          mediaQuery.viewPadding.bottom,
          mediaQuery.systemGestureInsets.bottom,
        );
        return Padding(
          padding: EdgeInsets.only(bottom: safeBottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '删除书籍',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text('确定从书架删除「$title」吗？', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: '取消',
                    variant: AppButtonVariant.text,
                    size: AppButtonSize.compact,
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    label: '删除',
                    variant: AppButtonVariant.danger,
                    size: AppButtonSize.compact,
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    _removeBooksFromLocalState(
      <BookshelfBook>[book],
      clearSelection: true,
      exitSelectionMode: _isSelectionMode,
    );
    final result = await _bookActionController.removeBooks(
      <BookshelfBook>[book],
      removeBook:
          (book) => _removeBook(book, reload: false, showFeedback: false),
    );
    if (result.hasFailures) {
      await _loadBookshelf(force: true);
      if (!mounted) {
        return;
      }
      _showMessage(result.singleDeleteMessage);
      return;
    }
    if (mounted) {
      _showMessage(result.singleDeleteMessage);
    }
  }

  Widget _buildBookMoreButton(BookshelfBook book, {required bool compact}) {
    return BookshelfBookMoreMenuPresenter(
      book: book,
      compact: compact,
      currentReadingStatus: _readingStatusOfBook(book),
      onAction: (action) => _handleBookMoreAction(book, action),
      onReadingStatusSelected:
          (status) => unawaited(_markBookReadingStatus(book, status)),
    );
  }

  Future<void> _openOnlineSearchWithReveal(BuildContext sourceContext) async {
    final overlay = CircularThemeRevealOverlay.of(sourceContext);
    final center = CircularThemeRevealOverlay.getCenterFromContext(
      sourceContext,
    );
    const route = '/search?entry=bookshelf_top';
    if (overlay == null) {
      await context.push(route);
      return;
    }
    await overlay.startTransition(
      center: center,
      reverse: false,
      onThemeChange: () {
        context.push(route);
      },
    );
  }

  Widget _buildDesktopOnlineSearchButton(BuildContext buttonContext) {
    final colorScheme = Theme.of(context).colorScheme;
    final componentTokens = appComponentThemeTokensOf(context);
    final buttonRadius = BorderRadius.all(
      Radius.circular(componentTokens.navigation.standardFloatingRadius),
    );
    return Tooltip(
      message: '在线搜书',
      child: Material(
        key: const ValueKey<String>('desktop_bookshelf_online_search_fab'),
        color: colorScheme.primaryContainer,
        elevation: componentTokens.card.elevation,
        shadowColor: colorScheme.shadow.withValues(
          alpha: componentTokens.card.shadowAlpha,
        ),
        borderRadius: buttonRadius,
        child: InkWell(
          borderRadius: buttonRadius,
          onTap: () => unawaited(_openOnlineSearchWithReveal(buttonContext)),
          child: SizedBox.square(
            dimension: _kDesktopOnlineSearchButtonSize,
            child: Icon(
              Icons.travel_explore_rounded,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setBookshelfViewMode(bool useGridView) async {
    if (_useGridView == useGridView && (useGridView || !_listTwoColumnMode)) {
      return;
    }
    _updateBookshelfLayoutPreservingScroll(() {
      _updateBookshelfState(() {
        _useGridView = useGridView;
        if (!useGridView) {
          _listTwoColumnMode = false;
        }
        _lastDesktopToolbarActionsFingerprint = null;
      });
    });
    try {
      await _bookshelfService.saveUseGridView(useGridView);
      if (!useGridView) {
        await _bookshelfService.saveListTwoColumnMode(false);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('书架视图保存失败，请重试。');
    }
  }

  ResolvedAdvancedThemePalette _resolvedPalette(BuildContext context) {
    return resolveAdvancedThemePalette(
      Theme.of(context).colorScheme,
      ref.read(activeAdvancedThemeProvider).valueOrNull,
    );
  }

  ResolvedAdvancedThemeBackdrop _resolvedBackdrop(BuildContext context) {
    return _resolvedBackdropForTheme(
      context,
      ref.read(activeAdvancedThemeProvider).valueOrNull,
    );
  }

  ResolvedAdvancedThemeBackdrop _resolvedBackdropForTheme(
    BuildContext context,
    AppAdvancedTheme? activeTheme,
  ) {
    return resolveAdvancedThemeBackdrop(
      Theme.of(context).colorScheme,
      activeTheme,
    );
  }

  Widget _buildBookshelfBackdrop({required Widget child}) {
    return Consumer(
      child: child,
      builder: (context, ref, child) {
        final backdrop = _resolvedBackdropForTheme(
          context,
          ref.watch(activeAdvancedThemeProvider).valueOrNull,
        );
        return DecoratedBox(
          decoration: buildAdvancedThemeBackdropDecoration(backdrop),
          child: child,
        );
      },
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
                  BookshelfTaxonomyAction.metadataChanged ||
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
                  BookshelfTaxonomyAction.metadataChanged ||
                  BookshelfTaxonomyAction.orderChanged ||
                  BookshelfTaxonomyAction.assignmentChanged:
                break;
            }
          }
      }
    });

    unawaited(_loadBookshelfImmediateMetadata(_books, ticket: _loadTicket));
  }

  void _handleCollectionChange(BookshelfCollectionChange change) {
    if (!mounted) {
      return;
    }
    unawaited(_loadBookshelf(force: true));
  }

  void _handleLocalBooksChanged(List<LocalBook> books) {
    if (!mounted || _books.isEmpty) {
      return;
    }
    final nextById = <String, LocalBook>{
      for (final book in books)
        if (book.id.trim().isNotEmpty) book.id.trim(): book,
    };
    var changed = nextById.length != _localBooksById.length;
    if (!changed) {
      for (final entry in nextById.entries) {
        if (_localBooksById[entry.key] != entry.value) {
          changed = true;
          break;
        }
      }
    }
    if (!changed) {
      return;
    }
    _refreshBookshelfPresentationFromMetadata(localBooksById: nextById);
  }

  void _handleMetadataOverridesChanged(List<BookMetadataOverride> overrides) {
    if (!mounted || _books.isEmpty) {
      return;
    }
    final nextByKey = <String, BookMetadataOverride>{
      for (final override in overrides)
        if (override.targetKey.trim().isNotEmpty)
          override.targetKey.trim(): override,
    };
    var changed = nextByKey.length != _metadataOverridesByTargetKey.length;
    if (!changed) {
      for (final entry in nextByKey.entries) {
        if (_metadataOverridesByTargetKey[entry.key] != entry.value) {
          changed = true;
          break;
        }
      }
    }
    if (!changed) {
      return;
    }
    _refreshBookshelfPresentationFromMetadata(
      metadataOverridesByTargetKey: nextByKey,
    );
  }

  void _refreshBookshelfPresentationFromMetadata({
    Map<String, LocalBook>? localBooksById,
    Map<String, BookMetadataOverride>? metadataOverridesByTargetKey,
  }) {
    final nextLocalBooksById = localBooksById ?? _localBooksById;
    final nextOverridesByTargetKey =
        metadataOverridesByTargetKey ?? _metadataOverridesByTargetKey;
    final nextPresentationByKey = _bookshelfPresentationQueryService
        .buildBookshelfPresentationMap(
          books: _books,
          localBooksById: nextLocalBooksById,
          metadataOverridesByTargetKey: nextOverridesByTargetKey,
        );
    setState(() {
      _localBooksById = nextLocalBooksById;
      _metadataOverridesByTargetKey = nextOverridesByTargetKey;
      _bookPresentationByKey = nextPresentationByKey;
      _derivedBookshelfFingerprint = null;
    });
    _updateBookCardStatesForBooks(
      _books,
      localBooksById: nextLocalBooksById,
      presentationByKey: nextPresentationByKey,
    );
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
    final next = await _preferenceRestoreController.loadViewSelection();
    if (!mounted || next == null) {
      return;
    }

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
    final selectedCount = _selectedBookKeys.length;
    final isSelectionActionBusy = _isBatchDeleting || _isBatchUpdatingCovers;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: AppBatchActionBar(
        selectedCount: selectedCount,
        totalCount: filteredBooks.length,
        enabled: !isSelectionActionBusy,
        showWhenEmpty: true,
        onSelectAll: filteredBooks.isEmpty ? null : _selectAllBooks,
        onClearSelection: _exitSelectionMode,
        actions: [
          AppBatchAction(
            label: '封面',
            icon: Icons.image_outlined,
            enabled: selectedCount > 0,
            onPressed: _editSelectedBooksCover,
          ),
          AppBatchAction(
            label: '删除',
            icon: Icons.delete_outline_rounded,
            tone: AppBatchActionTone.destructive,
            enabled: selectedCount > 0,
            confirmation: AppBatchActionConfirmation(
              title: '删除书籍',
              message: '确定从书架删除选中的 $selectedCount 本书吗？此操作不可撤销。',
              confirmLabel: '删除',
            ),
            onPressed: _deleteSelectedBooks,
          ),
        ],
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
      findChildIndexCallback: (key) {
        final bookKey = _bookKeyFromBookshelfItemKey(key);
        if (bookKey == null) {
          return null;
        }
        final index = books.indexWhere((book) => _bookKey(book) == bookKey);
        return index < 0 ? null : index;
      },
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
    return _coverLayoutResolver.gridCardItemHeightExtra(
      visualStyle: _gridVisualStyle,
      showTitle: _gridShowTitle,
      showAuthor: _gridShowAuthor,
      showLatestChapter: _gridShowLatestChapter,
      showProgressBar: _gridShowProgressBar,
      titleMaxLines: _gridTitleMaxLines,
    );
  }

  Widget _buildBookTaxonomyStrip(
    BookshelfBook book, {
    required bool compact,
    int maxTags = 2,
    bool singleLine = false,
  }) {
    final category = _categoryOfBook(book);
    final tags = _tagsOfBook(book).take(maxTags).toList(growable: false);
    if ((category == null || category.isEmpty) && tags.isEmpty) {
      return const SizedBox.shrink();
    }
    final children = [
      if (category != null && category.isNotEmpty)
        _buildTaxonomyPill(
          item: _categoryItem(category),
          icon: Icons.folder_rounded,
          compact: compact,
        ),
      for (final tag in tags)
        _buildTaxonomyPill(
          item: _tagItem(tag),
          icon: Icons.sell_rounded,
          compact: compact,
        ),
    ];
    if (singleLine) {
      return SizedBox(
        height: compact ? 22 : 26,
        child: ClipRect(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  if (index > 0) SizedBox(width: compact ? 4 : 6),
                  children[index],
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Wrap(
      spacing: compact ? 4 : 6,
      runSpacing: compact ? 4 : 5,
      children: children,
    );
  }

  Widget _buildTaxonomyPill({
    required BookshelfTaxonomyItem item,
    required IconData icon,
    required bool compact,
  }) {
    final color = Color(item.colorValue);
    final componentTokens = appComponentThemeTokensOf(context);
    final pillRadius = BorderRadius.all(
      Radius.circular(componentTokens.selection.chipRadius),
    );
    return Container(
      constraints: BoxConstraints(maxWidth: compact ? 92 : 128),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: pillRadius,
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 10 : 12, color: color),
          SizedBox(width: compact ? 3 : 4),
          Flexible(
            child: Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontSize: compact ? 10 : null,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactiveGridCard(BookshelfBook book) {
    final bookKey = _bookKey(book);
    return Consumer(
      builder: (context, ref, _) {
        final cardState = ref.watch(
          bookshelfPageStateProvider.select(
            (state) =>
                state.cardStatesByKey[bookKey] ?? _createBookCardState(book),
          ),
        );
        return _buildGridCard(book, cardState: cardState);
      },
    );
  }

  Widget _buildReactiveBookCard(BookshelfBook book) {
    final bookKey = _bookKey(book);
    return Consumer(
      builder: (context, ref, _) {
        final cardState = ref.watch(
          bookshelfPageStateProvider.select(
            (state) =>
                state.cardStatesByKey[bookKey] ?? _createBookCardState(book),
          ),
        );
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
    final bookKey = _bookKey(book);
    if (totalCount > _kBooksModeSwitchDisableThreshold ||
        index >= _kBooksModeSwitchAnimatedItemLimit) {
      return RepaintBoundary(
        key: ValueKey<String>(
          'bookshelf_static_${_useGridView ? 'grid' : 'list'}_$bookKey',
        ),
        child: child,
      );
    }

    final delayMilliseconds =
        ((index % _kBooksModeSwitchStaggerGroup) *
                _kBooksModeSwitchStaggerStep *
                1000)
            .round();

    return RepaintBoundary(
      child: AppFadeSlideTransition(
        key: ValueKey<String>(
          'bookshelf_mode_${_useGridView ? 'grid' : 'list'}_$bookKey',
        ),
        duration: _kBooksModeSwitchItemDuration,
        delay: Duration(milliseconds: delayMilliseconds.clamp(0, 420)),
        child: child,
      ),
    );
  }

  Widget _buildGridCard(
    BookshelfBook book, {
    required _BookshelfBookCardState cardState,
  }) {
    const coverAspectRatio = BookshelfCoverLayoutResolver.coverAspectRatio;
    final progress = cardState.progress;
    final localBook = cardState.localBook;
    final bookKey = _bookKey(book);
    final progressDisplay =
        _progressDisplayByBookKey[bookKey] ??
        _resolveBookshelfProgressDisplay(
          book,
          progress: progress,
          localBook: localBook,
          cachedChapterCount: cardState.cachedChapterCount,
        );
    final colorScheme = Theme.of(context).colorScheme;
    final palette = _resolvedPalette(context);
    final isOpening = _openingBookId == book.bookId;
    final isSelected = _isBookSelected(book);
    final displayTitle =
        cardState.presentation?.displayTitle ??
        _displayBookTitle(book, localBook: localBook);
    final displayAuthor = _displayBookAuthor(
      book,
      localBook: localBook,
      presentation: cardState.presentation,
    );
    final titleText =
        _titleTextByBookKey[bookKey] ?? _toSingleLineText(displayTitle);
    final coverHeroTag = _buildBookCoverHeroTag(book);
    final titleHeroTag = _buildBookTitleHeroTag(book);
    final metaHeroTag = _buildBookMetaHeroTag(book);
    final authorLine = _authorLineByBookKey[bookKey] ?? '作者: 未知';
    final latestLine = _latestLineByBookKey[bookKey] ?? '最新: 暂无章节';
    final overlayTitle =
        _gridVisualStyle == _BookshelfGridVisualStyle.overlayTitle;
    final coverOnly = _gridVisualStyle == _BookshelfGridVisualStyle.coverOnly;
    final isPressed = _pressedBookKey == bookKey;

    return BookshelfGridBookCardShell(
      isPressed: isPressed,
      pressDuration: _kBookshelfPressAnimDuration,
      selectionMode: _isSelectionMode,
      batchDeleting: _isBatchDeleting,
      openingOrBusy: !_isSelectionMode && (isOpening || _isBatchDeleting),
      onTapDown: () {
        _setPressedBookKey(bookKey);
        unawaited(AppHaptics.success());
      },
      onTapCancel: () => _setPressedBookKey(null),
      onTapUp: () => _setPressedBookKey(null),
      onLongPress: () async {
        _setPressedBookKey(null);
        if (_isSelectionMode) {
          _toggleBookSelection(book);
          return;
        }
        await _openBookDetailFromLongPress(book, pressedKey: bookKey);
      },
      onTap: () async {
        if (_isSelectionMode) {
          _toggleBookSelection(book);
          return;
        }
        _setPressedBookKey(null);
        await _openFromBookshelf(book, progress: progress);
      },
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
                    boxShadow:
                        _gridCoverShadow
                            ? [
                              // UI-GOV-EXEMPT: box-shadow cover-depth
                              BoxShadow(
                                color: palette.shadowColor,
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                            : null,
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
                        presentation: cardState.presentation,
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                      );
                    },
                  ),
                ),
                if (!_isSelectionMode && _gridShowSourceBadge)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _buildSourceBadge(book, compact: true),
                  ),
                if (_isCoverRefreshActive)
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 8,
                    child: _buildCoverRefreshIndicator(),
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppProgressIndicator(
                              size: 10,
                              strokeWidth: 1.8,
                              color: colorScheme.onPrimary,
                              semanticLabel: '打开书籍中',
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '打开中',
                              style: TextStyle(
                                color: colorScheme.onPrimary,
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
                                  : palette.cardColor.withValues(alpha: 0.9),
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
                                  ? _readableForegroundFor(palette.primaryColor)
                                  : palette.textSecondaryColor,
                        ),
                      ),
                    ),
                  ),
                if (overlayTitle && !_isSelectionMode)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildGridCoverTitleOverlay(
                      titleText: titleText,
                      subtitleText: _gridShowAuthor ? displayAuthor : null,
                    ),
                  ),
              ],
            ),
          ),
          if (!coverOnly &&
              !overlayTitle &&
              (_gridShowTitle ||
                  _gridShowAuthor ||
                  _gridShowLatestChapter ||
                  _gridShowProgressBar))
            const SizedBox(height: 6),
          if (!coverOnly && !overlayTitle && _gridShowTitle) ...[
            SizedBox(
              width: double.infinity,
              child: Hero(
                tag: titleHeroTag,
                child: Text(
                  titleText,
                  maxLines: _gridTitleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  textAlign:
                      _gridTitleCenter ? TextAlign.center : TextAlign.start,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: palette.cardTextColor,
                  ),
                ),
              ),
            ),
          ],
          if (!coverOnly && !overlayTitle && _gridShowAuthor) ...[
            SizedBox(height: _gridShowTitle ? 2 : 0),
            Hero(
              tag: metaHeroTag,
              child: Text(
                authorLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.textSecondaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          if (!coverOnly && !overlayTitle && _gridShowLatestChapter) ...[
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
          if (!coverOnly && !overlayTitle && _gridShowProgressBar) ...[
            SizedBox(
              height:
                  (_gridShowTitle || _gridShowAuthor || _gridShowLatestChapter)
                      ? 4
                      : 0,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child:
                      _gridProgressInfoMode ==
                              _BookshelfProgressInfoMode.unreadChapters
                          ? _buildUnreadChapterLabel(
                            progressDisplay,
                            compact: true,
                          )
                          : BookshelfAnimatedProgressSection(
                            key: ValueKey<String>('grid_progress_$bookKey'),
                            progressDisplay: progressDisplay,
                            summaryStyle: null,
                            trailingStyle: Theme.of(
                              context,
                            ).textTheme.labelSmall?.copyWith(
                              color:
                                  progressDisplay.hasProgress
                                      ? palette.primaryColor
                                      : palette.textSecondaryColor,
                              fontWeight: FontWeight.w700,
                            ),
                            fillColor: palette.primaryColor,
                            backgroundColor: palette.elevatedSurfaceColor,
                            showSummaryText: false,
                            showTrailingText: false,
                            showBar: true,
                            minHeight: 3,
                            spacing: 4,
                          ),
                ),
                if (!_isSelectionMode) ...[
                  const SizedBox(width: 4),
                  _buildBookMoreButton(book, compact: true),
                ],
              ],
            ),
          ] else if (!coverOnly && !overlayTitle && !_isSelectionMode) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: _buildBookMoreButton(book, compact: true),
            ),
          ],
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildUnreadChapterLabel(
    _BookshelfProgressDisplay progressDisplay, {
    required bool compact,
  }) {
    final palette = _resolvedPalette(context);
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color:
          progressDisplay.hasUnreadChapters
              ? palette.primaryColor
              : palette.textSecondaryColor,
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 1 : 2),
      child: Text(
        progressDisplay.unreadLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }

  Widget _buildListProgressInfo(
    _BookshelfProgressDisplay progressDisplay,
    String bookKey,
  ) {
    final palette = _resolvedPalette(context);
    if (_listProgressInfoMode == _BookshelfProgressInfoMode.unreadChapters) {
      return _buildUnreadChapterLabel(
        progressDisplay,
        compact: _listCompactMode,
      );
    }

    return BookshelfAnimatedProgressSection(
      key: ValueKey<String>('list_progress_$bookKey'),
      progressDisplay: progressDisplay,
      summaryStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: palette.textSecondaryColor.withValues(alpha: 0.88),
        fontWeight: FontWeight.w600,
      ),
      trailingStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
        color:
            progressDisplay.hasProgress
                ? palette.primaryColor
                : palette.textSecondaryColor,
        fontWeight: FontWeight.w700,
      ),
      fillColor: palette.primaryColor,
      backgroundColor: palette.elevatedSurfaceColor,
      summaryText: '阅读进度',
      showSummaryText: true,
      showTrailingText: true,
      showBar: true,
      minHeight: 4,
      spacing: _listCompactMode ? 4 : 5,
    );
  }

  Widget _buildBookCard(
    BookshelfBook book, {
    required _BookshelfBookCardState cardState,
  }) {
    final progress = cardState.progress;
    final localBook = cardState.localBook;
    final presentation = cardState.presentation;
    final bookKey = _bookKey(book);
    final progressDisplay =
        _progressDisplayByBookKey[bookKey] ??
        _resolveBookshelfProgressDisplay(
          book,
          progress: progress,
          localBook: localBook,
          cachedChapterCount: cardState.cachedChapterCount,
        );
    final palette = _resolvedPalette(context);
    final isOpening = _openingBookId == book.bookId;
    final isSelected = _isBookSelected(book);
    final displayTitle =
        presentation?.displayTitle ??
        _displayBookTitle(book, localBook: localBook);
    final displayAuthor = _displayBookAuthor(
      book,
      localBook: localBook,
      presentation: presentation,
    );
    final titleText =
        _titleTextByBookKey[bookKey] ?? _toSingleLineText(displayTitle);
    final coverHeroTag = _buildBookCoverHeroTag(book);
    final titleHeroTag = _buildBookTitleHeroTag(book);
    final metaHeroTag = _buildBookMetaHeroTag(book);
    final authorLine = _authorLineByBookKey[bookKey] ?? '作者: 未知';
    final latestLine = _latestLineByBookKey[bookKey] ?? '最新: 暂无章节';
    final isEditingSelected = _isSelectionMode && isSelected;
    final coverLayout = _coverLayoutResolver.listCoverLayout(
      compactMode: _listCompactMode,
      showCover: _listShowCover,
      showLatestChapter: _listShowLatestChapter,
      showTaxonomyBadges: _listShowTaxonomyBadges,
      showProgressBar: _listShowProgressBar,
      showRecentReadTime: _listShowRecentReadTime && progress != null,
    );
    final fallbackCoverHeight = coverLayout.fallbackCoverHeight;
    final cardPadding =
        _listCompactMode
            ? const EdgeInsets.fromLTRB(12, 9, 12, 9)
            : const EdgeInsets.fromLTRB(14, 12, 14, 12);
    final minCardHeight = coverLayout.minCardHeight;
    final recentReadLine =
        _listShowRecentReadTime && progress != null
            ? '最近阅读: ${_formatRelativeReadTime(progress.updatedAt)}'
            : null;
    final isPressed = _pressedBookKey == bookKey;

    return BookshelfListBookCardShell(
      isPressed: isPressed,
      pressDuration: _kBookshelfPressAnimDuration,
      margin: EdgeInsets.only(bottom: _listCompactMode ? 7 : 10),
      cardColor:
          isEditingSelected
              ? palette.noticeSurfaceColor.withValues(alpha: 0.34)
              : palette.cardColor,
      borderColor:
          isEditingSelected
              ? palette.noticeAccentColor.withValues(alpha: 0.38)
              : palette.cardBorderColor.withValues(alpha: 0.56),
      selectionMode: _isSelectionMode,
      openingOrBusy: !_isSelectionMode && (isOpening || _isBatchDeleting),
      onTapDown: () {
        _setPressedBookKey(bookKey);
        unawaited(AppHaptics.success());
      },
      onTapCancel: () => _setPressedBookKey(null),
      onTapUp: () => _setPressedBookKey(null),
      onTap: () async {
        if (_isSelectionMode) {
          _toggleBookSelection(book);
          return;
        }
        _setPressedBookKey(null);
        await _openFromBookshelf(book, progress: progress);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final constrainedHeight =
              constraints.maxHeight.isFinite
                  ? constraints.maxHeight
                  : minCardHeight;
          final coverHeight =
              _listShowCover
                  ? coverLayout.coverHeight(
                    hasFiniteConstraint: constraints.maxHeight.isFinite,
                    constrainedHeight: constrainedHeight,
                    cardPaddingVertical: cardPadding.vertical,
                  )
                  : fallbackCoverHeight;
          final coverWidth =
              coverHeight * BookshelfCoverLayoutResolver.coverAspectRatio;

          return ConstrainedBox(
            constraints: BoxConstraints(minHeight: minCardHeight),
            child: Padding(
              padding: cardPadding,
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
                  if (_listShowCover) ...[
                    InkResponse(
                      onLongPress:
                          _isBatchDeleting
                              ? null
                              : () async {
                                _setPressedBookKey(null);
                                if (_isSelectionMode) {
                                  _toggleBookSelection(book);
                                  return;
                                }
                                await _openBookDetailFromLongPress(
                                  book,
                                  pressedKey: bookKey,
                                );
                              },
                      containedInkWell: true,
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: coverWidth,
                        height: coverHeight,
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
                                presentation: presentation,
                                width: coverWidth,
                                height: coverHeight,
                              ),
                            ),
                            if (_listShowSourceBadge)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: _buildSourceBadge(book, compact: true),
                              ),
                            if (_isCoverRefreshActive)
                              Positioned(
                                left: 7,
                                right: 7,
                                bottom: 6,
                                child: _buildCoverRefreshIndicator(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onLongPress:
                          _isBatchDeleting
                              ? null
                              : () async {
                                if (_isSelectionMode) {
                                  _toggleBookSelection(book);
                                  return;
                                }
                                await _openBookDetailFromLongPress(
                                  book,
                                  pressedKey: bookKey,
                                );
                              },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (_listShowTitle)
                                Expanded(
                                  child: Hero(
                                    tag: titleHeroTag,
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
                                  ),
                                )
                              else
                                const Spacer(),
                              if (!_isSelectionMode) ...[
                                const SizedBox(width: 8),
                                if (isOpening)
                                  const AppProgressIndicator(
                                    size: 18,
                                    strokeWidth: 1.9,
                                    semanticLabel: '打开书籍中',
                                  )
                                else
                                  _buildBookMoreButton(book, compact: false),
                              ],
                            ],
                          ),
                          if (_listShowAuthor) ...[
                            SizedBox(height: _listCompactMode ? 3 : 6),
                            Hero(
                              tag: metaHeroTag,
                              child: Text(
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
                            ),
                          ],
                          if (_listShowLatestChapter) ...[
                            SizedBox(
                              height:
                                  _listCompactMode
                                      ? 2
                                      : (_listShowAuthor ? 3 : 5),
                            ),
                            Text(
                              latestLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(
                                color: palette.textSecondaryColor.withValues(
                                  alpha: 0.82,
                                ),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                          if (recentReadLine != null) ...[
                            SizedBox(height: _listCompactMode ? 3 : 4),
                            Text(
                              recentReadLine,
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
                          if (_listShowTaxonomyBadges) ...[
                            SizedBox(height: _listCompactMode ? 5 : 7),
                            _buildBookTaxonomyStrip(
                              book,
                              compact: _listCompactMode,
                              maxTags: _listCompactMode ? 1 : 2,
                            ),
                          ],
                          if (_listShowProgressBar) ...[
                            SizedBox(height: _listCompactMode ? 5 : 7),
                            _buildListProgressInfo(progressDisplay, bookKey),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
                      ? _readableForegroundFor(palette.primaryColor)
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridCoverTitleOverlay({
    required String titleText,
    required String? subtitleText,
  }) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(12),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.72)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(7, 20, 7, 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titleText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
              if (subtitleText != null && subtitleText.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitleText.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverRefreshIndicator() {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        minHeight: 3,
        backgroundColor: colorScheme.scrim.withValues(alpha: 0.28),
        color: colorScheme.primary,
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
    final bookKey = _bookKey(book);
    final searchText = _searchTextByBookKey[bookKey] ?? '';
    return searchText.contains(keyword);
  }

  bool _bookMatchesStaticFilter(BookshelfBook book, _BookshelfFilter filter) {
    switch (filter) {
      case _BookshelfFilter.all:
        return true;
      case _BookshelfFilter.todo:
        return book.inReadingQueue;
      case _BookshelfFilter.unread:
        return _readingStatusOfBook(book) == _BookshelfReadingStatus.unread;
      case _BookshelfFilter.reading:
        return _readingStatusOfBook(book) == _BookshelfReadingStatus.reading;
      case _BookshelfFilter.finished:
        return _readingStatusOfBook(book) == _BookshelfReadingStatus.finished;
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

  _BookshelfProgressDisplay _progressDisplayForBook(BookshelfBook book) {
    final bookKey = _bookKey(book);
    return _progressDisplayByBookKey[bookKey] ??
        _resolveBookshelfProgressDisplay(
          book,
          progress: _progressByBookKey[bookKey],
          localBook: _bookshelfLocalBook(book),
          cachedChapterCount: _cachedChapterCountByBookKey[bookKey],
        );
  }

  _BookshelfReadingStatus _readingStatusOfBook(BookshelfBook book) {
    final display = _progressDisplayForBook(book);
    return _bookReadingStatusService.resolveStatus(
      progress: _progressByBookKey[_bookKey(book)],
      progressValue: display.progressValue,
      hasProgressDisplay: display.hasProgress,
    );
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
      identityHashCode(_bookPresentationByKey),
      identityHashCode(_progressByBookKey),
      identityHashCode(_latestCachedChapterByBookKey),
      identityHashCode(_cachedChapterCountByBookKey),
      identityHashCode(_sourceTypeBySourceId),
      identityHashCode(_localBooksById),
      identityHashCode(_bookTagsByKey),
      identityHashCode(_tagOrder),
      identityHashCode(_tagItemByName),
      identityHashCode(_bookCategoriesByKey),
      identityHashCode(_categoryOrder),
      identityHashCode(_categoryItemByName),
      _gridShowTaxonomyBadges,
      _listShowTaxonomyBadges,
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
    final displayTitles = <String, String>{};
    final displayAuthors = <String, String>{};
    final titleTexts = <String, String>{};
    final authorLines = <String, String>{};
    final latestLines = <String, String>{};
    final progressDisplays = <String, _BookshelfProgressDisplay>{};
    final searchTextByBookKey = <String, String>{};
    for (final book in _books) {
      final bookKey = _bookKey(book);
      if (bookKey.isEmpty) {
        continue;
      }
      final localBook = _bookshelfLocalBook(book);
      final presentation = _bookPresentationByKey[bookKey];
      final displayTitle =
          presentation?.displayTitle ??
          _displayBookTitle(book, localBook: localBook);
      final displayAuthor =
          (presentation?.displayAuthor ??
                  _displayBookAuthor(
                    book,
                    localBook: localBook,
                    presentation: presentation,
                  ) ??
                  '')
              .trim();
      final latestChapter =
          _latestCachedChapterByBookKey[bookKey] ?? book.latestChapter ?? '';
      final titleText = _toSingleLineText(displayTitle);
      final authorText = _toSingleLineText(displayAuthor);
      final latestChapterText = _toSingleLineText(latestChapter);
      final progressDisplay = _resolveBookshelfProgressDisplay(
        book,
        progress: _progressByBookKey[bookKey],
        localBook: localBook,
        cachedChapterCount: _cachedChapterCountByBookKey[bookKey],
      );
      displayTitles[bookKey] = displayTitle;
      displayAuthors[bookKey] = displayAuthor;
      titleTexts[bookKey] = titleText;
      authorLines[bookKey] =
          authorText.isNotEmpty ? '作者: $authorText' : '作者: 未知';
      latestLines[bookKey] =
          latestChapterText.isNotEmpty ? '最新: $latestChapterText' : '最新: 暂无章节';
      progressDisplays[bookKey] = progressDisplay;
      searchTextByBookKey[bookKey] = _normalizeBookshelfSearchText(
        <String>[
          displayTitle,
          displayAuthor,
          _categoryOfBook(book) ?? book.category ?? '',
          latestChapter,
          ..._tagsOfBook(book),
        ].join(' '),
      );
    }

    _tagBookCountCache = Map<String, int>.unmodifiable(counts);
    _categoryBookCountCache = Map<String, int>.unmodifiable(categoryCounts);
    _userTagsCache = List<String>.unmodifiable(tags);
    _userCategoriesCache = List<String>.unmodifiable(categories);
    _displayTitleByBookKey = Map<String, String>.unmodifiable(displayTitles);
    _displayAuthorByBookKey = Map<String, String>.unmodifiable(displayAuthors);
    _titleTextByBookKey = Map<String, String>.unmodifiable(titleTexts);
    _authorLineByBookKey = Map<String, String>.unmodifiable(authorLines);
    _latestLineByBookKey = Map<String, String>.unmodifiable(latestLines);
    _searchTextByBookKey = Map<String, String>.unmodifiable(
      searchTextByBookKey,
    );
    _progressDisplayByBookKey =
        Map<String, _BookshelfProgressDisplay>.unmodifiable(progressDisplays);
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
    final keyA = _bookKey(a);
    final keyB = _bookKey(b);
    final progressA =
        _progressDisplayByBookKey[keyA]?.progressValue ??
        _resolveBookshelfProgressDisplay(
          a,
          progress: _progressByBookKey[keyA],
          localBook: _bookshelfLocalBook(a),
          cachedChapterCount: _cachedChapterCountByBookKey[keyA],
        ).progressValue;
    final progressB =
        _progressDisplayByBookKey[keyB]?.progressValue ??
        _resolveBookshelfProgressDisplay(
          b,
          progress: _progressByBookKey[keyB],
          localBook: _bookshelfLocalBook(b),
          cachedChapterCount: _cachedChapterCountByBookKey[keyB],
        ).progressValue;
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

  Map<String, BookshelfTaxonomyItem> _taxonomyItemsByName(
    Iterable<BookshelfTaxonomyItem> items,
  ) {
    return Map<String, BookshelfTaxonomyItem>.unmodifiable(
      <String, BookshelfTaxonomyItem>{
        for (final item in items)
          if (item.name.trim().isNotEmpty) item.name.trim(): item,
      },
    );
  }

  BookshelfTaxonomyItem _tagItem(String tag) {
    final normalized = tag.trim();
    return _tagItemByName[normalized] ??
        BookshelfTaxonomyItem(
          name: normalized,
          colorValue: BookshelfTaxonomyItem.defaultColorForName(normalized),
        );
  }

  BookshelfTaxonomyItem _categoryItem(String category) {
    final normalized = category.trim();
    return _categoryItemByName[normalized] ??
        BookshelfTaxonomyItem(
          name: normalized,
          colorValue: BookshelfTaxonomyItem.defaultColorForName(normalized),
        );
  }

  String _filterLabel(_BookshelfFilter filter) {
    switch (filter) {
      case _BookshelfFilter.all:
        return '全部';
      case _BookshelfFilter.todo:
        return _readingQueuePresentationMapper.filterLabel;
      case _BookshelfFilter.unread:
        return '未读';
      case _BookshelfFilter.reading:
        return '阅读中';
      case _BookshelfFilter.finished:
        return '已读完';
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
          _BookshelfFilter.all => 'all',
          _BookshelfFilter.todo => 'todo',
          _BookshelfFilter.unread => 'unread',
          _BookshelfFilter.reading => 'reading',
          _BookshelfFilter.finished => 'finished',
          _BookshelfFilter.local => 'local',
          _BookshelfFilter.novel => 'novel',
          _BookshelfFilter.manga => 'manga',
          _BookshelfFilter.custom => 'all',
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
    BookDisplayState? presentation,
    double width = 78,
    double height = 108,
  }) {
    final normalizedBookId = (bookId ?? '').trim();
    final cachedPresentation =
        presentation ??
        _bookPresentationByKey[_bookKeyByParams(
          sourceId: sourceId,
          bookId: normalizedBookId,
          detailUrl: detailUrl,
        )];
    final resolvedPresentation =
        cachedPresentation ??
        _bookMetadataPresentationResolver.resolve(
          fallbackTitle: title,
          fallbackAuthor: author,
          realCoverUrl: realCoverUrl,
          localBook:
              normalizedBookId.isNotEmpty
                  ? _localBooksById[normalizedBookId]
                  : null,
          metadataOverride:
              normalizedBookId.isNotEmpty
                  ? (sourceId == _kLocalBookSourceId
                      ? _metadataOverridesByTargetKey[BookMetadataOverride.localTargetKey(
                        normalizedBookId,
                      )]
                      : _metadataOverridesByTargetKey[BookMetadataOverride.remoteTargetKey(
                        sourceId: sourceId ?? '',
                        detailUrl: detailUrl ?? '',
                      )])
                  : null,
        );
    final coverView = Consumer(
      builder: (context, ref, _) {
        final resolvedCover = resolveBookCover(
          realCoverUrl: resolvedPresentation.displayCover,
          activeTheme: ref.watch(activeAdvancedThemeProvider).valueOrNull,
          galleries: ref.watch(coverGalleriesProvider).valueOrNull ?? const [],
          brightness: Theme.of(context).brightness,
          bookId: bookId,
          sourceId: sourceId,
          detailUrl: detailUrl,
        );
        final coverDecodeSize = _resolveBookshelfCoverDecodeSize(
          context,
          width: width,
          height: height,
        );
        return ResolvedBookCoverView(
          cover: resolvedCover,
          title: resolvedPresentation.displayTitle,
          author: resolvedPresentation.displayAuthor,
          width: width,
          height: height,
          borderRadius: BorderRadius.circular(12),
          cacheWidth: coverDecodeSize.$1,
          cacheHeight: coverDecodeSize.$2,
        );
      },
    );
    if (heroTag == null || heroTag.trim().isEmpty) {
      return coverView;
    }
    return Hero(tag: heroTag.trim(), child: coverView);
  }

  (int?, int?) _resolveBookshelfCoverDecodeSize(
    BuildContext context, {
    required double width,
    required double height,
  }) {
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      return (null, null);
    }
    final ratio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
    final cacheWidth = math.min((width * ratio).round(), 512);
    final cacheHeight = math.min((height * ratio).round(), 768);
    return (cacheWidth, cacheHeight);
  }

  String _bookKeyByParams({
    required String? sourceId,
    required String? bookId,
    required String? detailUrl,
  }) {
    return '${(sourceId ?? '').trim()}::${(bookId ?? '').trim()}::${(detailUrl ?? '').trim()}';
  }

  _BookshelfBookCardState _createBookCardState(BookshelfBook book) {
    final key = _bookKey(book);
    return _BookshelfBookCardState(
      progress: _progressByBookKey[key],
      latestCachedChapterTitle: _latestCachedChapterByBookKey[key],
      cachedChapterCount: _cachedChapterCountByBookKey[key] ?? 0,
      localBook: _bookshelfLocalBook(book),
      presentation: _bookPresentationByKey[key],
    );
  }

  void _syncBookCardStateNotifiers(Iterable<BookshelfBook> books) {
    final booksByKey = <String, BookshelfBook>{
      for (final book in books)
        if (_bookKey(book).isNotEmpty) _bookKey(book): book,
    };
    _bookshelfPageStateNotifier.syncCardStates(
      validKeys: booksByKey.keys,
      resolveState: (key) => _createBookCardState(booksByKey[key]!),
    );
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
    BookDisplayState? presentation,
    bool clearPresentation = false,
  }) {
    final key = _bookKey(book);
    final currentState = _bookshelfPageStateNotifier.cardStateFor(
      key,
      _createBookCardState(book),
    );
    final nextState = currentState.copyWithCard(
      progress: progress,
      clearProgress: clearProgress,
      latestCachedChapterTitle: latestCachedChapterTitle,
      clearLatestCachedChapterTitle: clearLatestCachedChapterTitle,
      cachedChapterCount: cachedChapterCount,
      localBook: localBook,
      clearLocalBook: clearLocalBook,
      presentation: presentation,
      clearPresentation: clearPresentation,
    );
    _bookshelfPageStateNotifier.setCardState(key, nextState);
  }

  void _updateBookCardStatesForBooks(
    Iterable<BookshelfBook> books, {
    Map<String, ReadingProgress>? progressByKey,
    Map<String, String>? latestCachedChapterByKey,
    Map<String, int>? cachedChapterCountByKey,
    Map<String, LocalBook>? localBooksById,
    Map<String, BookDisplayState>? presentationByKey,
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
        presentation: presentationByKey == null ? null : presentationByKey[key],
        clearPresentation:
            presentationByKey != null && !presentationByKey.containsKey(key),
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
    final cachedTitle = _displayTitleByBookKey[_bookKey(book)];
    if (cachedTitle != null && cachedTitle.isNotEmpty) {
      return cachedTitle;
    }
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
    return _heroTags.cover(book);
  }

  String _buildBookTitleHeroTag(BookshelfBook book) {
    return _heroTags.title(book);
  }

  String _buildBookMetaHeroTag(BookshelfBook book) {
    return _heroTags.meta(book);
  }

  String? _displayBookAuthor(
    BookshelfBook book, {
    LocalBook? localBook,
    BookDisplayState? presentation,
  }) {
    final cachedAuthor = _displayAuthorByBookKey[_bookKey(book)];
    if (cachedAuthor != null) {
      return cachedAuthor.isEmpty ? null : cachedAuthor;
    }
    final resolvedPresentation =
        presentation ?? _bookPresentationByKey[_bookKey(book)];
    if (resolvedPresentation != null) {
      return resolvedPresentation.displayAuthor;
    }
    final fallbackPresentation = _bookMetadataPresentationResolver.resolve(
      fallbackTitle: book.title,
      fallbackAuthor: book.author,
      realCoverUrl: book.coverUrl,
      localBook: localBook ?? _bookshelfLocalBook(book),
      metadataOverride: _bookshelfMetadataOverride(book),
    );
    return fallbackPresentation.displayAuthor;
  }

  Widget _buildSourceBadge(BookshelfBook book, {bool compact = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = _resolvedPalette(context);
    final isLocal = book.sourceId == _kLocalBookSourceId;
    final localBook = isLocal ? _localBooksById[book.bookId.trim()] : null;
    final (label, background, foreground) =
        isLocal
            ? _localSourceBadgePresentation(colorScheme, localBook)
            : (
              '在线',
              palette.secondaryColor,
              _readableForegroundFor(palette.secondaryColor),
            );
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
    return _initialLoadController.load(
      force: force,
      isMounted: () => mounted,
      hasVisibleBooks: _books.isNotEmpty,
      duplicateLoadCooldown: _kDuplicateLoadCooldown,
      runCore: _loadBookshelfCore,
      setCoverRefreshActive: (value) {
        setState(() {
          _isCoverRefreshActive = value;
        });
      },
    );
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
      _recordBookshelfFirstVisible(booksCount: books.length);
      _syncBookCardStateNotifiers(books);
      _syncSelectionWithBooks();
      unawaited(_maybeShowContinueReadingPrompt(ticket: ticket));

      _scheduleBookshelfPostFirstPaintWork(books, ticket: ticket);
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

  void _scheduleBookshelfPostFirstPaintWork(
    List<BookshelfBook> books, {
    required int ticket,
  }) {
    unawaited(() async {
      await Future<void>.delayed(_kPostFirstPaintBookshelfMetadataDelay);
      if (!mounted || ticket != _loadTicket) {
        return;
      }
      await _loadBookshelfImmediateMetadata(books, ticket: ticket);
      if (!mounted || ticket != _loadTicket || books.isEmpty) {
        return;
      }
      await _runDeferredBookshelfWarmup(books, ticket: ticket);
    }());
  }

  void _recordBookshelfFirstVisible({required int booksCount}) {
    if (_hasLoggedBookshelfFirstVisible) {
      return;
    }
    _hasLoggedBookshelfFirstVisible = true;
    _logger.info(
      'Bookshelf first content visible',
      context: <String, Object?>{
        'chain': 'bookshelf',
        'step': 'first_visible',
        'bookCount': booksCount,
        'durationMs': _bookshelfOpenStopwatch.elapsedMilliseconds,
      },
    );
  }

  Future<void> _loadBookshelfImmediateMetadata(
    List<BookshelfBook> books, {
    required int ticket,
  }) async {
    final sourceTypeFuture = _loadSourceTypeMap();
    final rawTagMapFuture = _bookshelfService.getTagMap();
    final tagOrderFuture = _bookshelfService.getTagOrder();
    final tagItemsFuture = _bookshelfService.getTagItems();
    final rawCategoryMapFuture = _bookshelfService.getCategoryMap();
    final categoryOrderFuture = _bookshelfService.getCategoryOrder();
    final categoryItemsFuture = _bookshelfService.getCategoryItems();
    final baseFilterOrderNamesFuture = _bookshelfService.getBaseFilterOrder();

    try {
      await Future.wait<dynamic>([
        sourceTypeFuture,
        rawTagMapFuture,
        tagOrderFuture,
        tagItemsFuture,
        rawCategoryMapFuture,
        categoryOrderFuture,
        categoryItemsFuture,
        baseFilterOrderNamesFuture,
      ]);
    } catch (_) {
      return;
    }

    if (!mounted || ticket != _loadTicket) {
      return;
    }

    final sourceTypeMap = await sourceTypeFuture;
    final rawTagMap = await rawTagMapFuture;
    final tagOrder = await tagOrderFuture;
    final tagItems = await tagItemsFuture;
    final rawCategoryMap = await rawCategoryMapFuture;
    final categoryOrder = await categoryOrderFuture;
    final categoryItems = await categoryItemsFuture;
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
      _bookTagsByKey = tagMap;
      _tagOrder = _normalizeTags(tagOrder);
      _tagItemByName = _taxonomyItemsByName(tagItems);
      _bookCategoriesByKey = categoryMap;
      _categoryOrder = _normalizeTags(categoryOrder);
      _categoryItemByName = _taxonomyItemsByName(categoryItems);
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
    _syncSelectionWithBooks();
  }

  Future<void> _runDeferredBookshelfWarmup(
    List<BookshelfBook> books, {
    required int ticket,
  }) async {
    await Future<void>.delayed(_kDeferredBookshelfWarmupDelay);
    if (!mounted || ticket != _loadTicket) {
      return;
    }

    await _loadBookshelfPresentationMetadata(books, ticket: ticket);
    if (!mounted || ticket != _loadTicket) {
      return;
    }

    await _loadLatestCachedChapterMap(books, ticket: ticket);
    await _loadCachedChapterCountMap(books, ticket: ticket);
    await _loadProgressMapInBatches(books, ticket: ticket);
    if (_skipNextBackgroundLatestInfoRefresh) {
      _skipNextBackgroundLatestInfoRefresh = false;
    } else {
      final refreshEpoch = _latestInfoRefreshController.startRefresh();
      unawaited(
        _refreshOnlineBookshelfLatestInfo(
          books,
          ticket: ticket,
          refreshEpoch: refreshEpoch,
        ),
      );
    }
  }

  Future<void> _loadBookshelfPresentationMetadata(
    List<BookshelfBook> books, {
    required int ticket,
  }) async {
    final metadata = await _presentationMetadataLoader.loadPresentationMetadata(
      books,
    );
    if (metadata == null) {
      return;
    }
    if (!mounted || ticket != _loadTicket) {
      return;
    }

    final localBooksById = metadata.localBooksById;
    final metadataOverridesByTargetKey = metadata.metadataOverridesByTargetKey;
    final bookPresentationByKey = _bookshelfPresentationQueryService
        .buildBookshelfPresentationMap(
          books: books,
          localBooksById: localBooksById,
          metadataOverridesByTargetKey: metadataOverridesByTargetKey,
        );

    if (!mounted || ticket != _loadTicket) {
      return;
    }

    setState(() {
      _localBooksById = localBooksById;
      _metadataOverridesByTargetKey = metadataOverridesByTargetKey;
      _bookPresentationByKey = bookPresentationByKey;
      _derivedBookshelfFingerprint = null;
    });
    _updateBookCardStatesForBooks(
      books,
      localBooksById: localBooksById,
      presentationByKey: bookPresentationByKey,
    );
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

    final latestByBookSource = await _presentationMetadataLoader
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

    final countByBookSource = await _presentationMetadataLoader
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
        final preserveLocalCustomCover =
            _bookPresentationByKey[_bookKey(book)]?.displayCoverSource ==
            BookDisplayCoverSource.localManaged;
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
    _latestInfoRefreshController.cancel();
  }

  bool _isLatestInfoRefreshCancelled({
    required int ticket,
    required int refreshEpoch,
  }) {
    return _latestInfoRefreshController.isCancelled(
      ticket: ticket,
      loadTicket: _loadTicket,
      refreshEpoch: refreshEpoch,
      mounted: mounted,
      isBookshelfRoute: _isBookshelfRoute(_lastKnownRouteLocation),
    );
  }

  String _bookConflictKey({
    required String sourceId,
    required String detailUrl,
    required String bookId,
  }) {
    return _latestInfoRefreshController.bookConflictKey(
      sourceId: sourceId,
      detailUrl: detailUrl,
      bookId: bookId,
    );
  }

  void _cancelBackgroundRefreshForBook({
    required String sourceId,
    required String detailUrl,
    required String bookId,
    required RemoteContentConflictScene byScene,
  }) {
    _latestInfoRefreshController.cancelBackgroundRefreshForBook(
      sourceId: sourceId,
      detailUrl: detailUrl,
      bookId: bookId,
      byScene: byScene,
    );
  }

  Future<void> _restoreViewModePreference() async {
    final useGrid = await _preferenceRestoreController.loadUseGridView();
    if (!mounted || _useGridView == useGrid) {
      return;
    }
    setState(() {
      _useGridView = useGrid;
    });
  }

  Future<void> _restoreListPreferences() async {
    final loaded = await _preferenceRestoreController.loadListPreferences();
    if (!mounted) {
      return;
    }
    if (_listShowTitle == loaded.showTitle &&
        _listShowAuthor == loaded.showAuthor &&
        _listShowLatestChapter == loaded.showLatestChapter &&
        _listShowProgressBar == loaded.showProgressBar &&
        _listProgressInfoMode == loaded.progressInfoMode &&
        _listShowSourceBadge == loaded.showSourceBadge &&
        _listShowTaxonomyBadges == loaded.showTaxonomyBadges &&
        _listShowCover == loaded.showCover &&
        _listCompactMode == loaded.compactMode &&
        _listTwoColumnMode == loaded.twoColumnMode &&
        _listShowRecentReadTime == loaded.showRecentReadTime &&
        _listAlwaysShowSearchBar == loaded.alwaysShowSearchBar &&
        _listPinSearchBar == loaded.pinSearchBar &&
        _listQuickFilterContent == loaded.quickFilterContent) {
      return;
    }
    setState(() {
      _listShowTitle = loaded.showTitle;
      _listShowAuthor = loaded.showAuthor;
      _listShowLatestChapter = loaded.showLatestChapter;
      _listShowProgressBar = loaded.showProgressBar;
      _listProgressInfoMode = loaded.progressInfoMode;
      _listShowSourceBadge = loaded.showSourceBadge;
      _listShowTaxonomyBadges = loaded.showTaxonomyBadges;
      _listShowCover = loaded.showCover;
      _listCompactMode = loaded.compactMode;
      _listTwoColumnMode = loaded.twoColumnMode;
      _listShowRecentReadTime = loaded.showRecentReadTime;
      _listAlwaysShowSearchBar = loaded.alwaysShowSearchBar;
      _listPinSearchBar = loaded.pinSearchBar;
      _listQuickFilterContent = loaded.quickFilterContent;
    });
  }

  Future<void> _restoreSortModePreference() async {
    final loaded = await _preferenceRestoreController.loadSortMode();
    if (!mounted || _sortMode == loaded) {
      return;
    }
    setState(() {
      _sortMode = loaded;
    });
  }

  Future<void> _restoreGridPreferences() async {
    final loaded = await _preferenceRestoreController.loadGridPreferences();
    if (!mounted) {
      return;
    }
    if (_gridAdaptiveColumns == loaded.adaptiveColumns &&
        _gridColumnCount == loaded.columnCount &&
        _gridCrossSpacing == loaded.crossSpacing &&
        _gridMainSpacing == loaded.mainSpacing &&
        _gridVisualStyle == loaded.visualStyle &&
        _gridShowTitle == loaded.showTitle &&
        _gridTitleCenter == loaded.titleCenter &&
        _gridTitleMaxLines == loaded.titleMaxLines &&
        _gridCoverShadow == loaded.coverShadow &&
        _gridShowAuthor == loaded.showAuthor &&
        _gridShowLatestChapter == loaded.showLatestChapter &&
        _gridShowProgressBar == loaded.showProgressBar &&
        _gridProgressInfoMode == loaded.progressInfoMode &&
        _gridShowSourceBadge == loaded.showSourceBadge &&
        _gridShowTaxonomyBadges == loaded.showTaxonomyBadges &&
        _gridAlwaysShowSearchBar == loaded.alwaysShowSearchBar &&
        _gridPinSearchBar == loaded.pinSearchBar &&
        _gridQuickFilterContent == loaded.quickFilterContent) {
      return;
    }
    setState(() {
      _gridAdaptiveColumns = loaded.adaptiveColumns;
      _gridColumnCount = loaded.columnCount;
      _gridCrossSpacing = loaded.crossSpacing;
      _gridMainSpacing = loaded.mainSpacing;
      _gridVisualStyle = loaded.visualStyle;
      _gridShowTitle = loaded.showTitle;
      _gridTitleCenter = loaded.titleCenter;
      _gridTitleMaxLines = loaded.titleMaxLines;
      _gridCoverShadow = loaded.coverShadow;
      _gridShowAuthor = loaded.showAuthor;
      _gridShowLatestChapter = loaded.showLatestChapter;
      _gridShowProgressBar = loaded.showProgressBar;
      _gridProgressInfoMode = loaded.progressInfoMode;
      _gridShowSourceBadge = loaded.showSourceBadge;
      _gridShowTaxonomyBadges = loaded.showTaxonomyBadges;
      _gridAlwaysShowSearchBar = loaded.alwaysShowSearchBar;
      _gridPinSearchBar = loaded.pinSearchBar;
      _gridQuickFilterContent = loaded.quickFilterContent;
    });
  }

  String _gridVisualStyleStorageValue(_BookshelfGridVisualStyle value) {
    return gridVisualStyleStorageValue(value);
  }

  _BookshelfGridVisualStyle _gridVisualStyleFromStorageValue(String value) {
    return gridVisualStyleFromStorageValue(value);
  }

  String _progressInfoModeStorageValue(_BookshelfProgressInfoMode value) {
    return progressInfoModeStorageValue(value);
  }

  _BookshelfProgressInfoMode _progressInfoModeFromStorageValue(String value) {
    return progressInfoModeFromStorageValue(value);
  }

  String _progressInfoModeLabel(_BookshelfProgressInfoMode value) {
    return progressInfoModeLabel(value);
  }

  String _gridVisualStyleLabel(_BookshelfGridVisualStyle value) {
    return gridVisualStyleLabel(value);
  }

  String _sortModeStorageValue(_BookshelfSortMode mode) {
    return sortModeStorageValue(mode);
  }

  String _sortModeLabel(_BookshelfSortMode mode) {
    return sortModeLabel(mode);
  }

  String _sortModeDescription(_BookshelfSortMode mode) {
    return sortModeDescription(mode);
  }

  String _searchQuickFilterContentStorageValue(
    _BookshelfSearchQuickFilterContent value,
  ) {
    return searchQuickFilterContentStorageValue(value);
  }

  _BookshelfSearchQuickFilterContent _searchQuickFilterContentFromStorageValue(
    String value,
  ) {
    return searchQuickFilterContentFromStorageValue(value);
  }

  String _searchQuickFilterContentLabel(
    _BookshelfSearchQuickFilterContent value,
  ) {
    return searchQuickFilterContentLabel(value);
  }

  Future<Map<String, int>> _loadSourceTypeMap() async {
    return _bookshelfPresentationQueryService.loadSourceTypeMap(
      timeout: _kSourceMapLoadTimeout,
      inferPersistedSourceType: _inferScriptSourceTypeFromCode,
    );
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
            final progress = await _presentationMetadataLoader
                .loadProgress(
                  () => _readerPreferencesService.loadProgress(book.bookId),
                )
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
    final totalChapters = _resolveApproximateChapterCount(
      book,
      localBook: localBook,
      cachedChapterCount: cachedChapterCount,
    );
    if (progress == null) {
      if (totalChapters != null && totalChapters > 0) {
        final normalizedTotal = totalChapters.clamp(1, 999999);
        return _BookshelfProgressDisplay(
          progressValue: 0,
          summaryText: '已读 0 / $normalizedTotal 章 · 剩余 $normalizedTotal 章',
          trailingLabel: '0%',
          unreadLabel: '未读',
          hasProgress: false,
          hasUnreadChapters: false,
        );
      }
      return const _BookshelfProgressDisplay(
        progressValue: 0,
        summaryText: '阅读进度: 未开始',
        trailingLabel: '0%',
        unreadLabel: '未读',
        hasProgress: false,
        hasUnreadChapters: false,
      );
    }

    final currentChapterNo = (progress.chapterIndex + 1).clamp(1, 999999);
    if (totalChapters != null && totalChapters > 0) {
      final normalizedTotal = totalChapters.clamp(1, 999999);
      final normalizedIndex = progress.chapterIndex.clamp(
        0,
        normalizedTotal - 1,
      );
      final chapterProgress = progress.chapterPositionRatio.clamp(0.0, 1.0);
      var overallProgress =
          (normalizedIndex + chapterProgress) / normalizedTotal;
      if (normalizedIndex == normalizedTotal - 1 && chapterProgress >= 0.995) {
        overallProgress = 1;
      }
      final clampedOverallProgress = overallProgress.clamp(0.0, 1.0);
      final percentage = (clampedOverallProgress * 100).round();
      final normalizedChapterNo = (normalizedIndex + 1).clamp(
        1,
        normalizedTotal,
      );
      final remainingChapters = math.max(
        0,
        normalizedTotal - normalizedChapterNo,
      );
      return _BookshelfProgressDisplay(
        progressValue: clampedOverallProgress,
        summaryText:
            clampedOverallProgress >= 0.999
                ? '已读 $normalizedTotal / $normalizedTotal 章 · 已读完'
                : '读到第 $normalizedChapterNo / $normalizedTotal 章 · 剩余 $remainingChapters 章',
        trailingLabel: '$percentage%',
        unreadLabel: remainingChapters > 0 ? '未读 $remainingChapters 章' : '已读完',
        hasProgress: clampedOverallProgress > 0,
        hasUnreadChapters: remainingChapters > 0,
      );
    }

    final fallbackProgress = progress.chapterPositionRatio.clamp(0.0, 1.0);
    return _BookshelfProgressDisplay(
      progressValue: fallbackProgress,
      summaryText:
          fallbackProgress >= 0.999
              ? '已读完 · 第 $currentChapterNo 章'
              : '读到第 $currentChapterNo 章',
      trailingLabel: '${(fallbackProgress * 100).round()}%',
      unreadLabel:
          fallbackProgress >= 0.999 ? '已读完' : '读到第 $currentChapterNo 章',
      hasProgress: fallbackProgress > 0,
      hasUnreadChapters: false,
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

    AppFeedback.showSnackBar(context, message: text, useHaptics: false);
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
    final resolution = await _pageRouteService.resolveLatestReadingRecordRoute(
      record,
    );
    if (!mounted) {
      return;
    }
    final route = resolution.route;
    if (route == null || resolution.unavailable) {
      _showMessage(resolution.message ?? '本地图书暂不可用。');
      return;
    }
    context.push(route);
    if (resolution.message != null) {
      _showMessage(resolution.message!);
    }
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

    return BookshelfContinueReadingPromptCard(
      visible: visible,
      child:
          record == null
              ? const SizedBox.shrink()
              : _buildContinueReadingCard(record),
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
            // UI-GOV-EXEMPT: box-shadow continue-reading-card
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

  Future<void> _refreshBookProgressAfterReaderExit(BookshelfBook book) async {
    final normalizedBookId = book.bookId.trim();
    if (normalizedBookId.isEmpty) {
      return;
    }
    final latestProgress = await _readerPreferencesService.loadProgress(
      normalizedBookId,
    );
    if (!mounted) {
      return;
    }
    final bookKey = _bookKey(book);
    final matchedProgress = _readerEntryController.matchingProgressAfterExit(
      latestProgress: latestProgress,
      book: book,
    );
    final previousProgress = _progressByBookKey[bookKey];
    if (previousProgress == matchedProgress) {
      return;
    }
    setState(() {
      final nextMap = Map<String, ReadingProgress>.from(_progressByBookKey);
      if (matchedProgress == null) {
        nextMap.remove(bookKey);
      } else {
        nextMap[bookKey] = matchedProgress;
      }
      _progressByBookKey = nextMap;
      _derivedBookshelfFingerprint = null;
    });
    _updateBookCardState(
      book,
      progress: matchedProgress,
      clearProgress: matchedProgress == null,
    );
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
      byScene: RemoteContentConflictScene.reader,
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
      final plan = await _readerEntryController.resolveOpenPlan(
        book: book,
        openRequestedAtMs: openRequestedAtMs,
        progressHint: progress,
        localBookHint: localBook,
        onlinePlanTimeout: const Duration(milliseconds: 220),
        onOnlinePlanTimeout: () {
          _logger.info(
            'Bookshelf reader open plan timed out, using reader fallback route',
            context: <String, Object?>{
              'chain': 'reader_open',
              'step': 'plan_timeout',
              'bookId': book.bookId,
              'sourceId': book.sourceId,
              'detailUrl': book.detailUrl,
              'tapToTimeoutMs': openStopwatch.elapsedMilliseconds,
            },
          );
        },
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
          await context.push(route);
          if (!mounted) {
            return;
          }
          await _refreshBookProgressAfterReaderExit(book);
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
      _showMessage('当前书籍来源可能已失效，请重新搜索服务器书源版本。');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _openReaderFallbackForSourceSwitch(book);
      _showMessage('打开详情失败，请重新搜索服务器书源版本。');
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
      byScene: RemoteContentConflictScene.reader,
    );
    final route = _readerEntryController.fallbackPlan(book).readerRoute;
    if (route == null) {
      return;
    }
    context.push(route);
  }

  Future<void> _openBookDetailFromLongPress(
    BookshelfBook book, {
    String? pressedKey,
  }) async {
    if (_isBatchDeleting || _isBatchUpdatingCovers) {
      return;
    }
    final key = (pressedKey ?? _bookKey(book)).trim();
    if (key.isNotEmpty) {
      _setPressedBookKey(key);
    }
    unawaited(AppHaptics.success());
    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (!mounted) {
      return;
    }
    _setPressedBookKey(null);
    _openBookDetail(book);
  }

  void _openBookDetail(BookshelfBook book, {bool initialEditMode = false}) {
    _cancelBackgroundLatestInfoRefresh();
    _cancelBackgroundRefreshForBook(
      sourceId: book.sourceId,
      detailUrl: book.detailUrl,
      bookId: book.bookId,
      byScene: RemoteContentConflictScene.detail,
    );
    if (_isBatchDeleting || _isBatchUpdatingCovers) {
      return;
    }

    final route = _readerEntryController.resolveDetailRoute(
      book,
      heroTag: _buildBookCoverHeroTag(book),
      initialEditMode: initialEditMode,
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

Color _readableForegroundFor(Color backgroundColor) {
  return ThemeData.estimateBrightnessForColor(backgroundColor) ==
          Brightness.dark
      ? Colors.white
      : Colors.black;
}
