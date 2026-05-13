import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/layout/app_adaptive.dart';
import '../../../app/images/local_file_image.dart';
import '../../../app/motion/app_motion_widgets.dart';
import '../../../app/platform/app_platform_capabilities.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../app/theme/app_theme_provider.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/import_export_task_overlay.dart';
import '../../../app/widgets/resolved_book_cover.dart';
import '../../../app/widgets/switch_source_candidate_sheet.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/media/image_selection_service.dart';
import '../../../core/storage/local_file_stat.dart';
import '../../../domain/entities/app_advanced_theme.dart';
import '../../../domain/entities/bookmark.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reader_document.dart';
import '../../../domain/entities/reader_settings.dart';
import '../../../domain/entities/reader_visual_overrides.dart';
import '../../../domain/entities/source_health.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/entities/reader_toc_snapshot.dart';
import '../../../domain/repositories/local_book_repository.dart';
import '../../../domain/repositories/bookmark_repository.dart';
import '../../../domain/repositories/book_metadata_override_repository.dart';
import '../../bookshelf/application/bookshelf_service.dart';
import '../../book/application/book_metadata_presentation_resolver.dart';
import '../../book/application/book_detail_service.dart';
import '../../book/presentation/book_detail_route.dart';
import '../../mine/application/advanced_theme_provider.dart';
import '../../mine/application/cover_gallery_provider.dart';
import '../../mine/application/reader_background_service.dart';
import '../../search/application/search_hit_cache_service.dart';
import '../../search/application/search_service.dart';
import '../../source/application/source_health_service.dart';
import '../../source/application/source_runtime_facade.dart';
import '../../source/application/source_runtime_task_conflict_service.dart';
import '../../source/application/source_runtime_scheduler_service.dart';
import '../application/content_provider.dart';
import '../application/chapter_content_service.dart';
import '../application/local/local_reader_identity.dart';
import '../application/paged_transition_controller.dart';
import '../application/reader_auto_read_coordinator.dart';
import '../application/reader_cache_feedback_resolver.dart';
import '../application/reader_content_session.dart';
import '../application/reader_content_mode_resolver.dart';
import '../application/reader_content_session_resolver.dart';
import '../application/reader_mode_capabilities.dart';
import '../application/reader_mode_model.dart';
import '../application/reader_mode_resolver.dart';
import '../application/reader_catalog_search_service.dart';
import '../application/reader_chapter_cache_decoder.dart';
import '../application/reader_chapter_load_planner.dart';
import '../application/reader_chapter_window_controller.dart';
import '../application/reader_chapter_flow.dart';
import '../application/reader_chapter_navigation.dart';
import '../application/reader_document_render_model.dart';
import '../application/reader_font_registry_service.dart';
import '../application/reader_image_decode_budget.dart';
import '../application/reader_jump_facade.dart';
import '../application/reader_jump_planner.dart';
import '../application/reader_layout_resolver.dart';
import '../application/reader_navigation_entry_resolver.dart';
import '../application/reader_pagination_cache_service.dart';
import '../application/reader_pagination_engine.dart';
import '../application/reader_pagination_models.dart';
import '../application/reader_pagination_spec.dart';
import '../application/reader_platform_bridge_service.dart';
import '../application/reader_settings_groups.dart';
import '../application/reader_settings_resolution_service.dart';
import '../application/reader_surface_policy_resolver.dart';
import '../application/reader_surface_metrics.dart';
import '../application/reader_logical_position.dart';
import '../application/reader_session_controller.dart';
import '../application/reader_preferences_service.dart';
import '../application/reader_preload_controller.dart';
import '../application/reader_resource_budget.dart';
import '../application/reader_runtime_wake_policy.dart';
import '../application/reader_visual_overrides_service.dart';
import '../application/reader_session_state.dart';
import '../application/reader_session_state_resolver.dart';
import '../application/reader_streaming_pagination_controller.dart';
import '../application/reader_source_switch_coordinator.dart';
import '../application/reader_source_switch_target_resolver.dart';
import '../application/reader_reading_record_coordinator.dart';
import '../application/reading_record_service.dart';
import '../application/reader_error_center_service.dart';
import '../application/reader_feedback_service.dart';
import '../application/reader_system_settings_service.dart';
import '../application/reader_theme_mode_service.dart';
import '../application/reader_typography_resolver.dart';
import '../application/reader_typography_metrics_resolver.dart';
import '../application/source_content_provider.dart';
import '../application/text_reader_renderer.dart';
import '../application/reader_volume_key_page_bridge.dart';
import '../application/source_switch_score_service.dart';
import '../application/switch_source_shared.dart';
import '../application/local/local_book_workflow_policy.dart';
import '../application/local/local_book_storage_service.dart';
import '../application/reader_cached_chapter_store.dart';
import '../application/reader_dependencies_provider.dart';
import 'chapter_cache_sheets.dart';
import 'reader_catalog_sheet.dart';
import 'reader_annotated_text.dart';
import 'reader_annotation_interaction.dart';
import 'reader_body_region.dart';
import 'reader_chrome_widgets.dart';
import 'reader_content_loading_controller.dart';
import 'reader_content_loading_presenter.dart';
import 'paged_animation/curl_paged_animation_renderer.dart';
import 'reader_page_lifecycle_delegate.dart';
import 'reader_selection_state.dart';
import 'reader_shell.dart';
import 'reader_source_switch_controller.dart';
import 'reader_settings_presenter.dart';
import 'reader_text_offset_mapper.dart' as text_offset_mapper;
import 'reader_text_block_presentation.dart';
import 'reader_paged_viewport_support.dart';
import 'reader_presentation_resolver.dart';
import 'reader_runtime_controller.dart';
import 'reader_text_paged_view.dart';
import 'reader_viewport_builder.dart';

part 'reader_page_content_loading.dart';
part 'reader_page_selection.dart';
part 'reader_page_background.dart';
part 'reader_page_bootstrap.dart';
part 'reader_page_content_rendering.dart';
part 'reader_page_lifecycle.dart';
part 'reader_page_navigation.dart';
part 'reader_page_runtime.dart';
part 'reader_page_shell.dart';
part 'reader_page_settings_panel.dart';
part 'reader_page_settings_sheet.dart';
part 'reader_page_source_switch.dart';
part 'reader_page_viewport.dart';

enum _ReaderSettingsTab { interface, reading }

enum _OverlayEdge { top, bottom }

enum _ReaderInteractionState { idle, dragging, animating, settling }

class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({
    super.key,
    required this.bookId,
    required this.chapterId,
    this.chapterUrl,
    this.chapterTitle,
    this.sourceId,
    this.detailUrl,
    this.chapterIndex,
    this.bookmarkId,
    this.openRequestedAtMs,
    this.openRouteKind,
  });

  final String bookId;
  final String chapterId;
  final String? chapterUrl;
  final String? chapterTitle;
  final String? sourceId;
  final String? detailUrl;
  final int? chapterIndex;
  final String? bookmarkId;
  final int? openRequestedAtMs;
  final String? openRouteKind;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const String _kBookmarkNoHighlightToken = '__none__';
  static const String _kBookmarkDefaultHighlightToken = '__highlight__';

  late final ContentProviderRegistry _contentProviderRegistry;
  late final ReaderPreferencesService _preferencesService;
  late final ReaderVisualOverridesService _visualOverridesService;
  late final ReaderPlatformBridgeService _platformBridgeService;
  late final ReaderFontRegistryService _fontRegistryService;
  final ReaderTypographyResolver _typographyResolver =
      const ReaderTypographyResolver();
  final ReaderTypographyMetricsResolver _typographyMetricsResolver =
      const ReaderTypographyMetricsResolver();
  final ReaderAutoReadCoordinator _autoReadCoordinator =
      const ReaderAutoReadCoordinator();
  final ReaderCacheFeedbackResolver _readerCacheFeedbackResolver =
      const ReaderCacheFeedbackResolver();
  final ReaderContentLoadingController _contentLoadingController =
      const ReaderContentLoadingController();
  final ReaderContentLoadingPresenter _contentLoadingPresenter =
      const ReaderContentLoadingPresenter();
  final ReaderContentModeResolver _contentModeResolver =
      const ReaderContentModeResolver();
  final ReaderPresentationResolver _presentationResolver =
      const ReaderPresentationResolver();
  final ReaderViewportBuilder _viewportBuilder = const ReaderViewportBuilder();
  final ReaderModeCapabilitiesResolver _modeCapabilitiesResolver =
      const ReaderModeCapabilitiesResolver();
  final ReaderModeResolver _readerModeResolver = const ReaderModeResolver();
  final ReaderChapterCacheDecoder _chapterCacheDecoder =
      const ReaderChapterCacheDecoder();
  final ReaderChapterLoadPlanner _chapterLoadPlanner =
      const ReaderChapterLoadPlanner();
  final ReaderChapterFlow _chapterFlow = const ReaderChapterFlow();
  final ReaderChapterNavigation _chapterNavigation =
      const ReaderChapterNavigation();
  final ReaderChapterWindowController _chapterWindowController =
      const ReaderChapterWindowController();
  final ReaderJumpFacade _jumpFacade = const ReaderJumpFacade();
  final ReaderJumpPlanner _jumpPlanner = const ReaderJumpPlanner();
  final ReaderNavigationEntryResolver _navigationEntryResolver =
      const ReaderNavigationEntryResolver();
  final ReaderLayoutResolver _layoutResolver = const ReaderLayoutResolver();
  final ReaderPaginationEngine _paginationEngine =
      const ReaderPaginationEngine();
  final ReaderStreamingPaginationController _streamingPaginationController =
      const ReaderStreamingPaginationController();
  final ReaderImageDecodeBudgetResolver _imageDecodeBudgetResolver =
      const ReaderImageDecodeBudgetResolver();
  late final ReaderPaginationCacheService _paginationCacheService;
  final ReaderPaginationSpecResolver _paginationSpecResolver =
      const ReaderPaginationSpecResolver();
  final ReaderSurfacePolicyResolver _surfacePolicyResolver =
      const ReaderSurfacePolicyResolver();
  final PagedTransitionController _pagedTransitionLogic =
      const PagedTransitionController();
  final ReaderPagedViewportTransitionResolver _pagedViewportTransitionResolver =
      const ReaderPagedViewportTransitionResolver();
  final ReaderCatalogSearchService _catalogSearchService =
      const ReaderCatalogSearchService();
  final ReaderReadingRecordCoordinator _readingRecordCoordinator =
      const ReaderReadingRecordCoordinator();
  final ReaderRuntimeWakePolicy _runtimeWakePolicy =
      const ReaderRuntimeWakePolicy();
  final ReaderFeedbackService _readerFeedbackService =
      const ReaderFeedbackService();
  final ReaderThemeModeService _readerThemeModeService =
      const ReaderThemeModeService();
  final ReaderRuntimeController _readerRuntimeController =
      const ReaderRuntimeController();
  final ReaderPageLifecycleDelegate _lifecycleDelegate =
      const ReaderPageLifecycleDelegate();
  final ReaderSettingsPresenter _readerSettingsPresenter =
      const ReaderSettingsPresenter();
  final ReaderSettingsResolutionService _readerSettingsResolutionService =
      const ReaderSettingsResolutionService();
  final ReaderContentSessionResolver _contentSessionResolver =
      const ReaderContentSessionResolver();
  final ReaderSessionStateResolver _sessionStateResolver =
      const ReaderSessionStateResolver();
  late final ReaderSystemSettingsService _systemSettingsService;
  late final ReaderBackgroundService _readerBackgroundService;
  late final LocalBookStorageService _localBookStorageService;
  late final ReaderErrorCenterService _readerErrorCenterService;
  late final ReadingRecordService _readingRecordService;
  late final ImageSelectionService _imageSelectionService;
  late final BookshelfService _bookshelfService;
  late final SearchService _switchSourceSearchService;
  late final SearchHitCacheService _searchHitCacheService;
  final SourceSwitchScoreService _switchSourceScoreService =
      SourceSwitchScoreService();
  final ReaderSourceSwitchController _sourceSwitchController =
      const ReaderSourceSwitchController();
  late final SourceHealthService _sourceHealthService;
  late final SourceRuntimeFacade _sourceRuntimeFacade;
  late final SourceRuntimeTaskConflictService _taskConflictService;
  late final SourceRuntimeSchedulerService _taskScheduler;
  final ReaderSourceSwitchCoordinator _sourceSwitchCoordinator =
      const ReaderSourceSwitchCoordinator();
  final ReaderSourceSwitchTargetResolver _sourceSwitchTargetResolver =
      const ReaderSourceSwitchTargetResolver();
  final ScrollTextReaderRenderer _scrollTextRenderer =
      const ScrollTextReaderRenderer();
  final PagedTextReaderRenderer _pagedTextRenderer =
      const PagedTextReaderRenderer();
  final ReaderSessionController _readerSessionController =
      ReaderSessionController();
  final ReaderPreloadController _preloadController =
      const ReaderPreloadController();
  final ReaderPreloadFailureMemory _preloadFailureMemory =
      ReaderPreloadFailureMemory();
  late final ReaderResourceBudgetResolver _resourceBudgetResolver;
  late final AppLogger _logger;
  final ScrollController _scrollController = ScrollController();
  final PageController _mangaPageController = PageController();
  PageController? _staticPagedTextPageControllerInstance;
  final FocusNode _readerFocusNode = FocusNode(debugLabel: 'ReaderPage');
  final Set<String> _precachedInlineImageUrls = <String>{};
  final GlobalKey _readerBodyKey = GlobalKey();
  final GlobalKey<SelectionAreaState> _selectionAreaKey =
      GlobalKey<SelectionAreaState>();
  final SelectionListenerNotifier _selectionNotifier =
      SelectionListenerNotifier();
  late final BookmarkRepository _bookmarkRepository;
  late final BookMetadataOverrideRepository _bookMetadataOverrideRepository;
  late final LocalBookRepository _localBookRepository;
  late final ReaderCachedChapterStore _cachedChapterStore;
  final BookDisplayStateResolver _bookMetadataPresentationResolver =
      const BookDisplayStateResolver();
  final Uuid _uuid = const Uuid();

  late String _chapterId;
  String? _chapterUrl;
  String? _chapterTitle;
  String? _sourceId;
  String? _detailUrl;
  String? _pendingBookmarkId;
  late String _activeBookId;

  String _bookTitle = '';
  String? _bookAuthor;
  String? _bookCoverUrl;
  String? _bookCustomCoverPath;

  ReaderSettings _settings = const ReaderSettings();
  ReaderSettings _persistedReaderSettings = const ReaderSettings();
  ReaderVisualOverrides _visualOverrides = ReaderVisualOverrides.empty;
  List<Chapter> _chapters = const [];
  int? _currentIndex;

  bool _isBootstrapping = true;
  bool _isLoadingContent = false;
  bool _showOverlayControls = false;
  bool _isInBookshelf = false;
  bool _isCurrentChapterCached = false;
  bool _isShelfActionLoading = false;
  bool _isSwitchSourceLoading = false;
  bool _isAutoSwitchingSource = false;
  bool _autoSwitchSourceOnFailureEnabled = false;
  bool _readingRecordEnabled = true;
  bool _isScrollEdgeAdvancingChapter = false;
  bool _hasPromptedMissingSourceSwitch = false;
  SearchCancellationToken? _activeSwitchSourceCancellationToken;
  String? _errorText;
  ReaderDocument _document = ReaderDocument(blocks: const <ReaderBlock>[]);
  String _content = '';
  List<String> _paragraphs = const [];
  List<ReaderRenderBlockItem> _renderItems = const [];
  Map<int, ReaderRenderTextItem> _renderTextItemsByParagraph =
      const <int, ReaderRenderTextItem>{};
  List<String> _chapterImageUrls = const [];
  Map<String, String> _chapterImageHeaders = const {};
  bool _isEditingBookmarkNote = false;
  ReaderSelectionState _selectionState = const ReaderSelectionState();
  List<Bookmark> _chapterBookmarks = const [];
  Map<int, List<_BookmarkRange>> _bookmarkRangesByParagraph =
      const <int, List<_BookmarkRange>>{};
  List<ReaderCustomFontEntry> _customFonts = const [];
  final Map<String, int> _mangaImageRetryNonce = <String, int>{};
  int _mangaPageIndex = 0;
  ReadingProgress? _bootstrapProgress;
  Timer? _progressDebounceTimer;
  Timer? _autoReadResumeTimer;
  Timer? _readerInfoClockTimer;
  Timer? _chapterLoadingIndicatorTimer;
  Timer? _blockingLoadingCardTimer;
  Timer? _hiddenLoadingPlaceholderTimer;
  Timer? _readingRecordAutoCommitTimer;
  DateTime? _lastReaderSnackAt;
  String? _lastReaderSnackKey;
  StreamSubscription<ReaderVolumeKeyEvent>? _volumeKeyEventSubscription;
  ProviderSubscription<ThemeMode>? _appThemeModeSubscription;
  ProviderSubscription<AsyncValue<AppAdvancedTheme?>>?
  _activeAdvancedThemeSubscription;
  late final Battery _battery;
  late final DeviceInfoPlugin _deviceInfo;
  DateTime _readerInfoNow = DateTime.now();
  DateTime? _lastReaderBatteryRefreshAt;
  DateTime? _lastProgressSavedAt;
  int? _readerBatteryLevel;
  bool _readerBatteryReadFailed = false;
  bool _isSystemBrightnessOverrideActive = false;
  Future<bool>? _iosSimulatorCheck;
  int _autoReadTaskToken = 0;
  int get _chapterContentRequestToken =>
      _readerSessionController.chapterContentGeneration;

  int get _preloadTaskToken => _readerSessionController.preloadGeneration;

  bool _isAutoReadRunning = false;
  bool _isAutoReadSessionEnabled = false;
  bool _isAutoReadPausedByRuntime = false;
  bool _isReaderRuntimeVisible = true;
  bool _isAutoReadAdvancingChapter = false;
  bool _isScrollStepAnimating = false;
  _ScrollEdgeAdvanceState _scrollEdgeAdvanceState =
      const _ScrollEdgeAdvanceState();
  double? _swipeDragStartDx;
  double? _swipeDragStartDy;
  double? _swipeDragCurrentDx;
  double? _swipeDragCurrentDy;
  int? _tapPointerId;
  Offset? _tapPointerDownPosition;
  DateTime? _tapPointerDownTime;
  bool _tapPointerMoved = false;
  bool _suppressNextReaderTap = false;
  DateTime? _lastPointerScrollPageTurnAt;
  DateTime? _lastBackNavigationAt;
  DateTime? _readerInteractionUnlockAt;
  OverlayEntry? _bookmarkToolbarEntry;
  ReaderPageTurnMode _pageTurnModeBeforeAutoRead =
      ReaderPageTurnMode.tapAndSwipe;
  List<String> _customBackgroundImages = const [];
  List<int> _recentBodyTextColors = const [];
  String? _lightModeBackgroundImageBackup;
  final _ReaderBackgroundAssetStore _backgroundAssets =
      _ReaderBackgroundAssetStore();
  double? _bottomOverlayDraftProgressRatio;
  List<List<ReaderPagedSlice>> _pagedPages = const [];
  List<List<ReaderPagedBlock>> _pagedBlockPages = const [];
  String? _textPaginationFallbackDiagnostic;
  int _currentPageIndex = 0;
  int _pagedTextControllerSyncGeneration = 0;
  ReaderPaginationSessionState _pagedPaginationState =
      const ReaderPaginationSessionState();
  int get _paginationTaskId => _readerSessionController.paginationGeneration;
  ReaderPaginationSpec? _lastPaginationSpec;
  bool _showChapterLoadingIndicator = false;
  bool _showBlockingLoadingCard = false;
  bool _showHiddenLoadingPlaceholder = false;
  double? _measuredPinnedChapterHeaderWidth;
  PagedTransitionState _pagedTransition = PagedTransitionController.idleState;
  _CurlTransitionState _curlTransition = const _CurlTransitionState();
  Stopwatch? _firstPageTurnStopwatch;
  bool _hasLoggedFirstPageTurn = false;
  bool _isSystemUiVisible = true;
  bool _isVolumeKeyPageInterceptionEnabled = false;
  late final AnimationController _overlayControlsController;
  late final AnimationController _pagedTransitionController;
  late final AnimationController _curlAutoTurnController;
  ReaderReadingRecordSession? _activeReadingRecordSession;
  String? _catalogSearchCacheFingerprint;
  Map<String, List<ReaderCatalogSearchEntry>> _catalogSearchEntriesCache =
      const <String, List<ReaderCatalogSearchEntry>>{};
  final Map<String, GlobalKey> _continuousTextChapterKeys =
      <String, GlobalKey>{};
  List<_ContinuousTextChapter> _continuousTextChapters =
      const <_ContinuousTextChapter>[];
  DateTime? _lastInlineImagePrecacheAt;
  bool _deferredBootstrapWarmupStarted = false;
  _ReaderInteractionState _readerInteractionState =
      _ReaderInteractionState.idle;
  Timer? _readerInteractionSettleTimer;
  bool _deferredNeighborPreload = false;

  static const List<String> _kFallbackBackgroundPresetPaths = [
    'assets/reader/backgrounds/20260224-212555-700782.jpeg',
    'assets/reader/backgrounds/20260224-212555-b91cd8.jpeg',
    'assets/reader/backgrounds/20260224-212555-01b93d.jpeg',
    'assets/reader/backgrounds/Image_1768236174407.jpg',
  ];

  static const double _kPinnedHeaderTopPadding = 6;
  static const int _kCustomBackgroundPreviewMaxDimension = 480;
  static const int _kCustomBackgroundStoreMaxDimension = 1800;
  static const int _kCustomBackgroundStoreQuality = 82;
  static const double _kPinnedHeaderHeight = 40;
  static const double _kBottomProgressReserve = 12;
  static const double _kBottomOverlayReserve = 96;
  static const double _kMarginControlStep = 0.5;
  static const double _kBackgroundTileWidth = 72;
  static const double _kBackgroundTileHeight = 44;
  static const double _kSwipeTurnDistanceThreshold = 42;
  static const double _kSwipeTurnVelocityThreshold = 120;
  static const double _kPagedPullRefreshDistanceThreshold = 48;
  static const double _kSystemBackGestureGuardMin = 44;
  static const double _kSystemBackGestureGuardRatio = 0.06;
  static const Duration _kBackNavigationInteractionCooldown = Duration(
    milliseconds: 520,
  );
  static const double _kCurlPreviewStartThreshold = 8;
  static const double _kOverlayScrimMaxAlpha = 0.14;
  static const Duration _kOverlayControlsShowDuration = Duration(
    milliseconds: 220,
  );
  static const Duration _kOverlayControlsHideDuration = Duration(
    milliseconds: 180,
  );
  static const double _kShellOverlayTranslateDistance = 12;
  static const Duration _kCurlAutoTurnDuration = Duration(milliseconds: 760);
  static const Duration _kPagedScrollTurnDuration = Duration(milliseconds: 300);
  static const Duration _kMangaPagedTurnDuration = Duration(milliseconds: 320);
  static const Duration _kAutoReadStepDuration = Duration(milliseconds: 520);
  static const Duration _kAutoReadResumeDelay = Duration(milliseconds: 420);
  static const Duration _kInitialReaderInteractionCooldown = Duration(
    milliseconds: 320,
  );
  static const Duration _kChapterLoadingIndicatorDelay = Duration(
    milliseconds: 260,
  );
  static const Duration _kBlockingLoadingCardDelay = Duration(
    milliseconds: 320,
  );
  static const Duration _kHiddenLoadingPlaceholderDelay = Duration(
    milliseconds: 40,
  );
  static const Duration _kReaderSnackDuration = Duration(milliseconds: 1800);
  static const Duration _kReaderBoundarySnackDuration = Duration(
    milliseconds: 1200,
  );
  static const Duration _kReaderSnackActionDuration = Duration(
    milliseconds: 2600,
  );
  static const Duration _kReaderSnackDedupWindow = Duration(milliseconds: 900);
  static const int _kSwitchSourceCandidateLimit = 24;
  static const int _kSwitchSourceLagTolerance = 20;
  static const int _kSwitchSourceScoreStep = 6;
  static const int _kSwitchSourceHitCountCap = 12;
  static const int _kSwitchSourceHitCountWeight = 3;
  static const int _kAutoSwitchSourceTryLimit = 3;
  static const int _kForwardPreloadChapterCount = 2;
  static const int _kBackwardPreloadChapterCount = 1;
  static const int _kBookshelfForwardCacheChapterCount = 10;
  static const double _kScrollAdvanceOverscrollTrigger = 56;
  static const double _kScrollAdvanceEdgeTolerance = 2;
  static const double _kScrollAdvanceNearEdgeThreshold = 24;
  static const int _kScrollRefreshCurrentChapterAction = -2;
  static const Set<PointerDeviceKind> _kScrollDragDevices = <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };

  bool get _isCurlAutoTurning => _curlTransition.isAnimating;
  bool get _isCurlPreviewActive => _curlTransition.isPreview;
  int get _curlAutoDirection => _curlTransition.direction;
  int get _curlAnimationFromIndex => _curlTransition.fromIndex;
  int get _curlAnimationToIndex => _curlTransition.toIndex;
  double get _curlPreviewProgress => _curlTransition.previewProgress;
  bool get _curlCommitOnAnimationEnd => _curlTransition.commitOnAnimationEnd;
  bool get _isCurlCrossChapterTurn => _curlTransition.isCrossChapter;
  bool get _isPagedTransitionAnimating => _pagedTransition.isAnimating;
  bool get _shouldUseContinuousTextFlow => _isTextScrollViewport;
  int get _currentPagedPageCount =>
      max(_pagedPages.length, _pagedBlockPages.length);

  PageController? _resolveStaticPagedTextPageController(int pageCount) {
    if (pageCount <= 0) {
      return null;
    }
    final safePage = _currentPageIndex.clamp(0, _safePageUpperBound(pageCount));
    final controller = _staticPagedTextPageControllerInstance;
    if (controller == null) {
      _staticPagedTextPageControllerInstance = PageController(
        initialPage: safePage,
      );
      return _staticPagedTextPageControllerInstance;
    }
    if (!controller.hasClients && controller.initialPage != safePage) {
      controller.dispose();
      _staticPagedTextPageControllerInstance = PageController(
        initialPage: safePage,
      );
      return _staticPagedTextPageControllerInstance;
    }
    if (controller.hasClients) {
      final current = controller.page?.round() ?? controller.initialPage;
      if (current != safePage &&
          !_pagedTransition.isAnimating &&
          !_isCurlAutoTurning) {
        final syncGeneration = ++_pagedTextControllerSyncGeneration;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              syncGeneration != _pagedTextControllerSyncGeneration ||
              _staticPagedTextPageControllerInstance != controller ||
              !controller.hasClients ||
              _pagedTransition.isAnimating ||
              _isCurlAutoTurning) {
            return;
          }
          final target = _currentPageIndex.clamp(
            0,
            _safePageUpperBound(_currentPagedPageCount),
          );
          final currentPage =
              controller.page?.round() ?? controller.initialPage;
          if (currentPage != target) {
            controller.jumpToPage(target);
          }
        });
      }
    }
    return controller;
  }

  TextAlign _paragraphTextAlign(ReaderSettings settings) {
    return settings.textFullJustifyEnabled
        ? TextAlign.justify
        : TextAlign.start;
  }

  ReaderModeModel _resolveReaderModeFor(
    ReaderSettings settings, {
    ReaderContentMode? contentMode,
    bool? canUsePagedText,
  }) {
    final effectiveContentMode = contentMode ?? _currentContentMode;
    final effectiveCanUsePagedText =
        canUsePagedText ??
        _modeCapabilitiesResolver
            .resolve(
              contentMode: effectiveContentMode,
              contentCapabilities: _contentCapabilities,
              hasInlineImageParagraphs:
                  _currentChapterHasInlineImageParagraphs(),
              supportsSourceRuntime:
                  ref
                      .read(appPlatformCapabilitiesProvider)
                      .supportsSourceRuntime,
            )
            .canUsePagedText;
    return _readerModeResolver.resolve(
      contentMode: effectiveContentMode,
      settings: settings,
      canUsePagedText: effectiveCanUsePagedText,
    );
  }

  ReaderModeModel get _currentReaderMode => _resolveReaderModeFor(_settings);

  List<int> _neighborPreloadContentIndexes({
    required String normalizedSourceId,
    required int currentIndex,
    required int chapterCount,
    required ReaderResourceBudget budget,
  }) {
    final preloadPlan = _preloadController.buildChapterPlan(
      currentChapterIndex: currentIndex,
      chapterCount: chapterCount,
      budget: budget,
      isLocalSource: LocalReaderIdentity.isLocalSourceId(normalizedSourceId),
      isInBookshelf: _isInBookshelf,
      maxForwardChapterCount: _kForwardPreloadChapterCount,
      maxBackwardChapterCount: _kBackwardPreloadChapterCount,
      bookshelfForwardChapterCount: _kBookshelfForwardCacheChapterCount,
      failureMemory: _preloadFailureMemory,
    );
    return preloadPlan
        .chapterIndexesFor(ReaderPreloadTaskType.content)
        .toList(growable: false);
  }

  ReaderResourceBudget _currentResourceBudget({
    ReaderWorkScene scene = ReaderWorkScene.foregroundReading,
  }) {
    return _resourceBudgetResolver.resolve(
      ReaderResourceBudgetInput(
        batteryTier:
            (_readerBatteryLevel != null && _readerBatteryLevel! <= 20)
                ? ReaderBatteryTier.lowBattery
                : ReaderBatteryTier.normal,
        networkTier: ReaderNetworkTier.unmetered,
        scene: scene,
      ),
    );
  }

  ReaderImageDecodeBudget _readerImageDecodeBudget({
    required ReaderImageDecodeRole role,
    required double logicalWidth,
    double? logicalHeight,
  }) {
    return _imageDecodeBudgetResolver.resolve(
      role: role,
      resourceBudget: _currentResourceBudget(),
      logicalWidth: logicalWidth,
      logicalHeight: logicalHeight,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
  }

  void _scheduleInlineImagePrecache({int startIndex = 0, int limit = 4}) {
    if (!mounted || _renderItems.isEmpty) {
      return;
    }
    final safeStartIndex = max(0, startIndex);
    final mediaWidth = MediaQuery.sizeOf(context).width;
    final decodeBudget = _readerImageDecodeBudget(
      role: ReaderImageDecodeRole.epubInline,
      logicalWidth: mediaWidth,
    );
    final imageUrls = _renderItems
        .whereType<ReaderRenderImageItem>()
        .skip(safeStartIndex)
        .map((item) => item.imageUrl)
        .where((url) => url.trim().isNotEmpty)
        .take(limit)
        .toList(growable: false);
    if (imageUrls.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      for (final imageUrl in imageUrls) {
        if (!_precachedInlineImageUrls.add(imageUrl)) {
          continue;
        }
        final provider = _readerImageProviderForPrecache(
          imageUrl,
          decodeBudget,
        );
        if (provider == null) {
          continue;
        }
        precacheImage(provider, context).ignore();
      }
    });
  }

  ImageProvider? _readerImageProviderForPrecache(
    String imageUrl,
    ReaderImageDecodeBudget decodeBudget,
  ) {
    if (imageUrl.startsWith('data:image/svg+xml') || _isSvgImageUrl(imageUrl)) {
      return null;
    }
    if (imageUrl.startsWith('data:image/')) {
      final decoded = _decodeDataUriImage(
        dataUri: imageUrl,
        maxBytes: decodeBudget.maxDataUriBytes,
      );
      if (decoded == null) {
        return null;
      }
      return ResizeImage.resizeIfNeeded(
        decodeBudget.cacheWidth,
        decodeBudget.cacheHeight,
        MemoryImage(decoded.bytes),
      );
    }
    final uri = Uri.tryParse(imageUrl);
    if (uri != null && uri.scheme == 'file') {
      final fileProvider = resolveLocalFileImageProvider(
        localFilePathFromUri(uri),
      );
      if (fileProvider == null) {
        return null;
      }
      return ResizeImage.resizeIfNeeded(
        decodeBudget.cacheWidth,
        decodeBudget.cacheHeight,
        fileProvider,
      );
    }
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return ResizeImage.resizeIfNeeded(
      decodeBudget.cacheWidth,
      decodeBudget.cacheHeight,
      NetworkImage(
        imageUrl,
        headers: _chapterImageHeaders.isEmpty ? null : _chapterImageHeaders,
      ),
    );
  }

  void _scheduleInlineImagePrecacheNearProgress({int limit = 6}) {
    final imageCount = _renderItems.whereType<ReaderRenderImageItem>().length;
    if (imageCount <= 0) {
      return;
    }
    final now = DateTime.now();
    final lastPrecacheAt = _lastInlineImagePrecacheAt;
    if (lastPrecacheAt != null &&
        now.difference(lastPrecacheAt) < const Duration(milliseconds: 650)) {
      return;
    }
    _lastInlineImagePrecacheAt = now;
    final progressIndex = (_currentScrollRatio() * imageCount).floor();
    _scheduleInlineImagePrecache(
      startIndex: max(0, progressIndex - 1),
      limit: limit,
    );
  }

  bool _isPagedTextReaderEnabledFor(ReaderSettings settings) {
    final mode = _resolveReaderModeFor(settings);
    return mode.isText && mode.isPaged;
  }

  bool _isPagedTextReaderEnabled() {
    return _isPagedTextReaderEnabledFor(_settings);
  }

  TextReaderRenderer get _activeTextRenderer =>
      _isPagedTextReaderEnabled() ? _pagedTextRenderer : _scrollTextRenderer;

  ReaderRenderMetrics _currentTextRenderMetrics() {
    if (_isPagedTextReaderEnabled()) {
      return ReaderRenderMetrics(
        pageCount: _currentPagedPageCount,
        currentPageIndex: _currentPageIndex,
      );
    }
    return ReaderRenderMetrics(
      hasScrollClients: _scrollController.hasClients,
      maxScrollExtent:
          _scrollController.hasClients
              ? _scrollController.position.maxScrollExtent
              : 0,
      scrollOffset:
          _scrollController.hasClients ? _scrollController.position.pixels : 0,
    );
  }

  ReaderLogicalPosition? _currentLogicalPosition() {
    final chapterIndex = _currentIndex;
    if (chapterIndex == null) {
      return null;
    }
    return ReaderLogicalPosition.fromDocument(
      document: _document,
      chapterIndex: chapterIndex,
      chapterPositionRatio: _currentScrollRatio(),
      pageIndex: _isPagedTextReaderEnabled() ? _currentPageIndex : null,
    );
  }

  ReaderSessionState? _currentTextSessionState() {
    return _sessionStateResolver.resolve(
      chapterIndex: _currentIndex,
      chapterId: _chapterId,
      chapterUrl: _chapterUrl,
      chapterTitle: _chapterTitle,
      logicalPosition: _currentLogicalPosition(),
      rendererKind: _activeTextRenderer.kind,
      metrics: _currentTextRenderMetrics(),
      isAutoReading: _isAutoReadSessionEnabled,
      isChapterTransitioning: _isLoadingContent,
    );
  }

  ReaderContentSession? _currentContentSession() {
    final contentMode = _currentContentMode;
    return _contentSessionResolver.resolve(
      contentMode: contentMode,
      bookId: _activeBookId,
      sourceId: _sourceId,
      detailUrl: _detailUrl,
      bookTitle: _bookTitle,
      bookAuthor: _bookAuthor,
      bookCoverUrl: _bookCoverUrl,
      chapterId: _chapterId,
      chapterUrl: _chapterUrl,
      chapterTitle: _chapterTitle,
      chapterIndex: _currentIndex,
      chapters: _chapters,
      sessionState:
          contentMode == ReaderContentMode.text
              ? _currentTextSessionState()
              : null,
      bootstrapProgress: _bootstrapProgressForCurrentChapter(),
      readingRecordSession: _activeReadingRecordSession,
    );
  }

  ReaderContentSession _resolvedContentSession() {
    final current = _currentContentSession();
    if (current != null) {
      return current;
    }
    return _presentationResolver.resolveContentSession(
      seed: ReaderSessionSeed(
        contentMode: _currentContentMode,
        bookId: _activeBookId,
        sourceId: _sourceId ?? '',
        detailUrl: _detailUrl ?? '',
        bookTitle: _bookTitle,
        bookAuthor: _bookAuthor,
        bookCoverUrl: _bookCoverUrl,
        chapterId: _chapterId,
        chapterUrl: _chapterUrl,
        chapterTitle: _chapterTitle,
        chapterIndex: _currentIndex,
        chapters: _chapters,
      ),
    );
  }

  ReaderPresentationPalette _presentationPalette(BuildContext context) {
    return ReaderPresentationPalette.fromColorScheme(
      Theme.of(context).colorScheme,
    );
  }

  ReaderPresentationViewportKind get _presentationViewportKind {
    return switch (_currentViewportKind) {
      ReaderModeViewportKind.textPaged =>
        ReaderPresentationViewportKind.textPaged,
      ReaderModeViewportKind.textScroll =>
        ReaderPresentationViewportKind.textScroll,
      ReaderModeViewportKind.imagePaged =>
        ReaderPresentationViewportKind.mangaPaged,
      ReaderModeViewportKind.imageScroll =>
        ReaderPresentationViewportKind.mangaContinuous,
    };
  }

  ReadingProgress? _bootstrapProgressForCurrentChapter({bool consume = false}) {
    final progress = _bootstrapProgress;
    if (progress == null) {
      return null;
    }

    final currentChapterId = _chapterId.trim();
    final currentChapterUrl = (_chapterUrl ?? '').trim();
    final matchesChapter =
        progress.chapterId == currentChapterId ||
        progress.chapterUrl == currentChapterUrl;
    if (!matchesChapter) {
      return null;
    }

    if (consume) {
      _bootstrapProgress = null;
    }
    return progress;
  }

  double _resolveDocumentRestoreRatio({
    ReaderDocument? document,
    ReaderLogicalPosition? logicalPosition,
    ReadingProgress? progress,
    double fallback = 0,
  }) {
    final effectiveDocument = document ?? _document;
    final effectivePosition = logicalPosition ?? progress?.logicalPosition;
    if (effectivePosition != null && !effectiveDocument.isEmpty) {
      return effectivePosition.approximateRatio(effectiveDocument);
    }

    final ratio = progress?.chapterPositionRatio ?? fallback;
    return ratio.clamp(0.0, 1.0);
  }

  void _restoreTextPositionFromLogicalAnchor({
    required bool previousPagedTextEnabled,
    required ReaderLogicalPosition? logicalAnchor,
    required double fallbackRatio,
  }) {
    final nextPagedTextEnabled = _isPagedTextReaderEnabled();
    if (previousPagedTextEnabled == nextPagedTextEnabled) {
      return;
    }

    final anchorRatio = _resolveDocumentRestoreRatio(
      logicalPosition: logicalAnchor,
      fallback: fallbackRatio,
    );
    if (nextPagedTextEnabled) {
      _pagedPaginationState = _pagedPaginationState.copyWith(
        pendingRestoreRatio: anchorRatio,
      );
    }
    _restoreScrollPosition(anchorRatio);
    _scheduleProgressSave();
  }

  bool _isSwipePaginationEnabled() {
    return _currentReaderMode.viewportKind ==
            ReaderModeViewportKind.textPaged &&
        _currentReaderMode.swipeTurnEnabled;
  }

  bool get _isMixedMediaTextDocument =>
      _document.hasImageBlocks && !_document.isPureImageDocument;

  bool _shouldUseCurlGesturePreview() {
    return _isSwipePaginationEnabled() &&
        _currentPagedAnimationStyle() == ReaderPageAnimationStyle.curl &&
        !_isMixedMediaTextDocument;
  }

  ReaderContentMode get _currentContentMode {
    return _contentModeResolver.resolveFromDocument(_document);
  }

  bool get _isMangaChapter => _currentContentMode == ReaderContentMode.comic;

  bool get _isMangaPagedMode {
    if (!_isMangaChapter) {
      return false;
    }
    return _settings.mangaReadMode != ReaderMangaReadMode.continuous;
  }

  ReaderModeViewportKind get _currentViewportKind {
    final resolved = _currentReaderMode.viewportKind;
    if (resolved == ReaderModeViewportKind.textPaged &&
        _textPaginationFallbackDiagnostic != null) {
      return ReaderModeViewportKind.textScroll;
    }
    return resolved;
  }

  bool get _isTextPagedViewport =>
      _currentViewportKind == ReaderModeViewportKind.textPaged;

  bool get _isTextScrollViewport =>
      _currentViewportKind == ReaderModeViewportKind.textScroll;

  bool get _isMangaViewport =>
      _currentViewportKind == ReaderModeViewportKind.imagePaged ||
      _currentViewportKind == ReaderModeViewportKind.imageScroll;

  ReaderModeCapabilities get _readerModeCapabilities =>
      _modeCapabilitiesResolver.resolve(
        contentMode: _currentContentMode,
        contentCapabilities: _contentCapabilities,
        hasInlineImageParagraphs: _currentChapterHasInlineImageParagraphs(),
        supportsSourceRuntime:
            ref.read(appPlatformCapabilitiesProvider).supportsSourceRuntime,
      );

  bool get _supportsAutoRead => _readerModeCapabilities.canAutoRead;

  bool get _isTextSelectionActive => _selectionState.isActive;
  set _isTextSelectionActive(bool value) {
    _selectionState = _selectionState.copyWith(isActive: value);
  }

  SelectedContentRange? get _selectionRange => _selectionState.range;
  set _selectionRange(SelectedContentRange? value) {
    _selectionState = _selectionState.copyWith(range: value);
  }

  SelectionStatus get _selectionStatus => _selectionState.status;
  set _selectionStatus(SelectionStatus value) {
    _selectionState = _selectionState.copyWith(status: value);
  }

  int get _selectionStartOffset => _selectionState.startOffset;
  set _selectionStartOffset(int value) {
    _selectionState = _selectionState.copyWith(startOffset: value);
  }

  int get _selectionEndOffset => _selectionState.endOffset;
  set _selectionEndOffset(int value) {
    _selectionState = _selectionState.copyWith(endOffset: value);
  }

  String get _selectedSnippet => _selectionState.snippet;
  set _selectedSnippet(String value) {
    _selectionState = _selectionState.copyWith(snippet: value);
  }

  bool get _selectionHighlight => _selectionState.highlight;
  set _selectionHighlight(bool value) {
    _selectionState = _selectionState.copyWith(highlight: value);
  }

  bool get _selectionBold => _selectionState.bold;
  set _selectionBold(bool value) {
    _selectionState = _selectionState.copyWith(bold: value);
  }

  bool get _selectionUnderline => _selectionState.underline;
  set _selectionUnderline(bool value) {
    _selectionState = _selectionState.copyWith(underline: value);
  }

  bool get _selectionWavy => _selectionState.wavy;
  set _selectionWavy(bool value) {
    _selectionState = _selectionState.copyWith(wavy: value);
  }

  bool _showsOuterPinnedChapterHeaderFor(ReaderModeViewportKind viewportKind) {
    return viewportKind != ReaderModeViewportKind.textPaged &&
        _layoutResolver.showsPinnedChapterHeader(_settings);
  }

  bool _showsPagedPinnedChapterHeaderFor(ReaderModeViewportKind viewportKind) {
    return viewportKind == ReaderModeViewportKind.textPaged &&
        _layoutResolver.showsPinnedChapterHeader(_settings);
  }

  bool _showsOuterInfoBarsFor(ReaderModeViewportKind viewportKind) {
    return viewportKind == ReaderModeViewportKind.textScroll;
  }

  bool _showsPagedHeaderInfoBarFor(ReaderModeViewportKind viewportKind) {
    return false;
  }

  bool get _hasReaderInfoItems =>
      _settings.infoShowProgress ||
      _settings.infoShowTime ||
      _settings.infoShowBattery ||
      _settings.infoShowChapter;

  bool _showsOuterFooterInfoBarFor(ReaderModeViewportKind viewportKind) {
    return _showsOuterInfoBarsFor(viewportKind) && _settings.infoFooterEnabled;
  }

  bool _reservesPinnedHeaderSpaceFor(ReaderModeViewportKind viewportKind) {
    return _showsOuterPinnedChapterHeaderFor(viewportKind) ||
        _showsPagedPinnedChapterHeaderFor(viewportKind);
  }

  bool get _showsPinnedChapterHeader =>
      _showsOuterPinnedChapterHeaderFor(_currentViewportKind);

  bool get _showsReaderFooterInfoBar =>
      _showsOuterFooterInfoBarFor(_currentViewportKind);

  bool get _hasVisibleReaderContent =>
      _content.trim().isNotEmpty || !_document.isEmpty;

  bool get _needsBlockingLoadingUi {
    if (_isBootstrapping && !_hasVisibleReaderContent) {
      return true;
    }
    if (_isSwitchSourceLoading) {
      return true;
    }
    if (_isLoadingContent && !_hasVisibleReaderContent) {
      return true;
    }
    return false;
  }

  bool get _shouldShowBlockingReaderLoading {
    return _showBlockingLoadingCard && _needsBlockingLoadingUi;
  }

  bool get _supportsChapterPullToRefresh {
    return _errorText != null || !_hasVisibleReaderContent;
  }

  Future<void> _reloadCurrentChapterFromPullToRefresh() async {
    if (_isBootstrapping || _isLoadingContent || _isSwitchSourceLoading) {
      return;
    }
    final initialScrollRatio =
        _hasVisibleReaderContent ? _currentScrollRatio() : null;
    await _loadCurrentChapter(initialScrollRatio: initialScrollRatio);
  }

  void _resetScrollEdgeAdvanceState() {
    _scrollEdgeAdvanceState = const _ScrollEdgeAdvanceState();
  }

  void _updateScrollEdgeAdvanceState({
    double? overscrollDistance,
    bool? isArmed,
    int? actionDirection,
  }) {
    _scrollEdgeAdvanceState = _scrollEdgeAdvanceState.copyWith(
      overscrollDistance: overscrollDistance,
      isArmed: isArmed,
      actionDirection: actionDirection,
    );
  }

  double get _overlayControlsShiftProgress =>
      Curves.easeOutCubic.transform(_overlayControlsController.value);

  double get _overlayControlsFadeProgress =>
      Curves.easeOut.transform(_overlayControlsController.value);

  double _topSafeInset(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context).top;
    final gestureInsets = MediaQuery.systemGestureInsetsOf(context).top;
    return max(viewPadding, gestureInsets);
  }

  double _bottomSafeInset(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context).bottom;
    final gestureInsets = MediaQuery.systemGestureInsetsOf(context).bottom;
    return max(viewPadding, gestureInsets);
  }

  double _effectiveBottomSafeInset(BuildContext context) {
    final rawInset = _bottomSafeInset(context);
    final platform = Theme.of(context).platform;
    final minInset = platform == TargetPlatform.iOS ? 14.0 : 0.0;
    return max(rawInset, minInset);
  }

  EdgeInsets _readerSafeInsets(BuildContext context) {
    return EdgeInsets.only(
      top: _topSafeInset(context),
      bottom: _effectiveBottomSafeInset(context),
    );
  }

  int _safePageUpperBound(int pageCount) {
    return max(0, pageCount - 1);
  }

  double _pinnedHeaderTotalHeight(BuildContext context) {
    return _topSafeInset(context) +
        _kPinnedHeaderTopPadding +
        _layoutResolver.resolveChapterHeaderTopSpacing(_settings) +
        _kPinnedHeaderHeight +
        _layoutResolver.resolveChapterHeaderBottomSpacing(_settings);
  }

  _ReaderSurfaceReserves _resolveReaderSurfaceReserves(
    BuildContext context, {
    ReaderModeViewportKind? viewportKind,
  }) {
    final effectiveViewportKind = viewportKind ?? _currentViewportKind;
    final footerPadding = _layoutResolver.resolveInfoBarPadding(
      _settings,
      isHeader: false,
    );
    final headerPadding = _layoutResolver.resolveInfoBarPadding(
      _settings,
      isHeader: true,
    );
    final textStyle = Theme.of(context).textTheme.bodySmall;
    final fontSize = max(11.5, textStyle?.fontSize ?? 11.5);
    final lineHeightFactor = textStyle?.height ?? 1.2;
    final policy = _surfacePolicyResolver.resolve(
      showsReaderFooterInfoBar: _showsOuterFooterInfoBarFor(
        effectiveViewportKind,
      ),
      showsPagedHeaderInfoBar: _showsPagedHeaderInfoBarFor(
        effectiveViewportKind,
      ),
      hasPagedInfoOverlay: _hasPagedInfoOverlay(),
      effectiveBottomSafeInset: _effectiveBottomSafeInset(context),
      bottomProgressReserve: _kBottomProgressReserve,
      bottomOverlayReserve: _kBottomOverlayReserve,
      headerMarginTop: headerPadding.top,
      headerMarginBottom: headerPadding.bottom,
      footerMarginTop: footerPadding.top,
      footerMarginBottom: footerPadding.bottom,
      infoHeaderPadding:
          _settings.infoHeaderPadding
              .clamp(
                ReaderSettings.minInfoBarPadding,
                ReaderSettings.maxInfoBarPadding,
              )
              .toDouble(),
      infoFooterPadding:
          _settings.infoFooterPadding
              .clamp(
                ReaderSettings.minInfoBarPadding,
                ReaderSettings.maxInfoBarPadding,
              )
              .toDouble(),
      headerFontSize: fontSize,
      headerLineHeightFactor: lineHeightFactor,
      footerFontSize: fontSize,
      footerLineHeightFactor: lineHeightFactor,
    );
    return _ReaderSurfaceReserves(
      scrollBottomReserve: policy.scrollBottomReserve,
      pagedHeaderReserve: policy.pagedHeaderReserve,
      pagedBottomReserve: policy.pagedBottomReserve,
    );
  }

  ReaderSurfaceMetrics _resolveReaderSurfaceMetrics(
    BuildContext context, {
    ReaderModeViewportKind? viewportKind,
    Size? viewportSize,
    double? scrollBottomReserve,
    double? pagedBottomReserve,
  }) {
    final effectiveViewportKind = viewportKind ?? _currentViewportKind;
    final reserves = _resolveReaderSurfaceReserves(
      context,
      viewportKind: effectiveViewportKind,
    );
    return _layoutResolver.resolveSurfaceMetrics(
      settings: _settings,
      viewportSize: viewportSize ?? AppLayout.viewportSize(context),
      safeInsets: _readerSafeInsets(context),
      pinnedHeaderHeight:
          _reservesPinnedHeaderSpaceFor(effectiveViewportKind)
              ? _pinnedHeaderTotalHeight(context)
              : 0,
      pagedHeaderReserve: reserves.pagedHeaderReserve,
      scrollBottomReserve: scrollBottomReserve ?? reserves.scrollBottomReserve,
      pagedBottomReserve: pagedBottomReserve ?? reserves.pagedBottomReserve,
      maxContentWidth:
          AppLayout.isExpandedUp(context)
              ? ReaderLayoutResolver.desktopReadableContentMaxWidth
              : null,
    );
  }

  Widget _buildFloatingReaderSettingsSheet({
    required BuildContext context,
    required ThemeData readerModalTheme,
    required double keyboardInset,
    required double safeBottom,
    required double sheetHorizontal,
    required double maxWidth,
    required double heightFactor,
    Color? backgroundColor,
    required Widget child,
  }) => _buildFloatingReaderSettingsSheetImpl(
    context: context,
    readerModalTheme: readerModalTheme,
    keyboardInset: keyboardInset,
    safeBottom: safeBottom,
    sheetHorizontal: sheetHorizontal,
    maxWidth: maxWidth,
    heightFactor: heightFactor,
    backgroundColor: backgroundColor,
    child: child,
  );

  ReaderSurfaceMetrics _resolvePagedLayoutMetrics(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    return _resolveReaderSurfaceMetrics(
      context,
      viewportSize: constraints.biggest,
    );
  }

  ReaderPaginationSpec _resolvePaginationSpec({
    required ReaderSurfaceMetrics surfaceMetrics,
  }) {
    return _paginationSpecResolver.resolve(
      settings: _settings,
      surfaceMetrics: surfaceMetrics,
    );
  }

  bool _hasPagedInfoOverlay() {
    return _settings.infoFooterEnabled && _hasReaderInfoItems;
  }

  String _formatLayoutMarginValue(double value) =>
      _formatLayoutMarginValueImpl(value);

  void _bindDependencies() => _bindReaderDependencies();

  @override
  void initState() {
    super.initState();
    _initializeReaderPage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyReaderImageCacheBudget();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    _handlePlatformBrightnessChange();
  }

  @override
  void dispose() {
    _disposeReaderPage();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildReaderPageScaffold(context);

  double _readerBrightnessOverlayAlpha() {
    if (_settings.followSystemBrightness || _isSystemBrightnessOverrideActive) {
      return 0;
    }
    final alpha = (1 - _settings.brightness) * 0.6;
    final hasBackgroundImage =
        _settings.backgroundImageBase64?.trim().isNotEmpty ?? false;
    if (!hasBackgroundImage) {
      return alpha;
    }
    // Keep dimming available, but don't let it flatten background images.
    return alpha * 0.18;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _handleReaderAppLifecycleState(state);

  Future<void> _applySystemReaderBrightness([double? brightness]) =>
      _applySystemReaderBrightnessImpl(brightness);

  Future<void> _restoreSystemReaderBrightness() =>
      _restoreSystemReaderBrightnessImpl();

  void _updateReaderState(VoidCallback mutation) {
    if (!mounted) {
      return;
    }
    setState(mutation);
  }

  Decoration _buildReaderBackgroundDecoration(_ReaderThemeColors colors) =>
      _buildReaderBackgroundDecorationImpl(colors);

  bool _isPresetBackgroundValue(String? value) =>
      _isPresetBackgroundValueImpl(value);

  Future<void> _preloadCustomBackgroundPreviews(List<String> sources) =>
      _preloadCustomBackgroundPreviewsImpl(sources);

  Future<String?> _storeCustomBackgroundImage(Uint8List bytes) =>
      _storeCustomBackgroundImageImpl(bytes);

  Future<void> _deleteManagedBackgroundFileIfNeeded(String source) =>
      _deleteManagedBackgroundFileIfNeededImpl(source);

  Future<List<String>> _loadUnifiedCustomBackgrounds() =>
      _loadUnifiedCustomBackgroundsImpl();

  Future<void> _refreshSharedReaderAssets({
    void Function(VoidCallback fn)? updateModalState,
  }) => _refreshSharedReaderAssetsImpl(updateModalState: updateModalState);

  Widget _buildReaderContent(_ReaderThemeColors colors) =>
      _composeReaderContent(colors);

  ReaderChromePalette _chromePalette(_ReaderThemeColors colors) {
    return ReaderChromePalette(
      background: colors.background,
      text: colors.text,
      meta: colors.meta,
      divider: colors.divider,
      overlay: colors.overlay,
    );
  }

  Widget _buildPinnedChapterHeader(_ReaderThemeColors colors) {
    final chapterTitle =
        _chapterTitle?.isNotEmpty == true ? _chapterTitle! : '未命名章节';
    return ReaderPinnedChapterHeader(
      model: ReaderPinnedChapterHeaderModel(
        title: chapterTitle,
        mode:
            _settings.showChapterHeader
                ? ReaderChapterHeaderMode.start
                : ReaderChapterHeaderMode.hidden,
        horizontalProgress: _settings.chapterHeaderHorizontalOffset,
        topSafeInset: _topSafeInset(context),
        topPadding:
            _kPinnedHeaderTopPadding +
            _layoutResolver.resolveChapterHeaderTopSpacing(_settings),
        bottomSpacing: _layoutResolver.resolveChapterHeaderBottomSpacing(
          _settings,
        ),
        height: _kPinnedHeaderHeight,
        measuredWidth: _measuredPinnedChapterHeaderWidth,
      ),
      palette: _chromePalette(colors),
      onBackPressed: _handleBackNavigation,
      onMeasuredWidthChanged: (nextWidth) {
        final currentWidth = _measuredPinnedChapterHeaderWidth;
        if (currentWidth != null && (currentWidth - nextWidth).abs() < 0.5) {
          return;
        }
        if (!mounted) {
          return;
        }
        setState(() {
          _measuredPinnedChapterHeaderWidth = nextWidth;
        });
      },
    );
  }

  Widget _buildReaderInfoBar(
    _ReaderThemeColors colors, {
    required bool isHeader,
  }) {
    final footerItems = <ReaderInfoBarItemData>[
      if (_settings.infoShowProgress)
        ReaderInfoBarItemData.text(
          '进度 ${(_currentScrollRatio() * 100).round()}%',
        ),
      if (_settings.infoShowChapter &&
          (_chapterTitle?.trim().isNotEmpty ?? false))
        ReaderInfoBarItemData.text(_chapterTitle!.trim(), expand: true),
      if (_settings.infoShowTime)
        ReaderInfoBarItemData.text(_formatReaderInfoTime(_readerInfoNow)),
      if (_settings.infoShowBattery)
        ReaderInfoBarItemData.battery(
          batteryLevel: _readerBatteryLevel,
          batteryReadFailed: _readerBatteryReadFailed,
        ),
    ];
    return ReaderInfoBar(
      model: ReaderInfoBarModel.fromSettings(
        settings: _settings,
        layoutResolver: _layoutResolver,
        placement:
            isHeader
                ? ReaderInfoBarPlacement.header
                : ReaderInfoBarPlacement.footer,
        role: switch ((_currentViewportKind, isHeader)) {
          (ReaderModeViewportKind.textScroll, true) =>
            ReaderChromeRole.scrollHeader,
          (ReaderModeViewportKind.textScroll, false) =>
            ReaderChromeRole.scrollFooter,
          (_, true) => ReaderChromeRole.pagedHeader,
          (_, false) => ReaderChromeRole.pagedFooter,
        },
        leadingItems: const <ReaderInfoBarItemData>[],
        centerItems: isHeader ? const <ReaderInfoBarItemData>[] : footerItems,
        trailingItems: const <ReaderInfoBarItemData>[],
      ),
      palette: _chromePalette(colors),
    );
  }

  String _formatReaderInfoTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _readerBatteryLabel() {
    final level = _readerBatteryLevel;
    if (level != null) {
      return '电量 ${level.clamp(0, 100)}%';
    }
    if (_readerBatteryReadFailed) {
      return '电量 N/A';
    }
    return '电量 --';
  }

  Widget _buildBody(_ReaderThemeColors colors) => _composeReaderBody(colors);

  Widget _buildReaderList(_ReaderThemeColors colors) =>
      _buildReaderViewportContent(colors);

  Widget _buildStandardReaderList(_ReaderThemeColors colors) {
    final surfaceMetrics = _resolveReaderSurfaceMetrics(context);
    final scrollModel = _presentationResolver.buildTextScrollModel(
      contentSession: _resolvedContentSession(),
      settings: _settings,
      document: _document,
      surfaceMetrics: surfaceMetrics,
      palette: _presentationPalette(context),
      renderItems: _renderItems,
      contentPadding: surfaceMetrics.scrollBodyPadding,
      imageDecodeBudget: _readerImageDecodeBudget(
        role: ReaderImageDecodeRole.epubInline,
        logicalWidth: MediaQuery.sizeOf(context).width,
      ),
    );
    return _viewportBuilder.buildStandardTextViewport(
      model: scrollModel,
      scrollController: _scrollController,
      bodyKey: _readerBodyKey,
      selectionWrapper: ({required child}) => _wrapSelectionArea(child: child),
      onScrollNotification: _onReaderScrollNotification,
      imageBuilder:
          (_, item) => _buildInlineReaderImageCard(
            imageUrl: item.imageUrl,
            colors: colors,
          ),
      blockWrapper: (context, item, isLast, child) {
        if (item is ReaderRenderTextItem) {
          return _buildSelectableReaderBlockItem(
            item: item,
            isLast: isLast,
            colors: colors,
          );
        }
        if (item is ReaderRenderImageItem) {
          return _buildInlineImageParagraphItem(
            imageUrl: item.imageUrl,
            isLast: isLast,
            colors: colors,
          );
        }
        return child;
      },
      overlay:
          _isAutoReadSessionEnabled ? _buildAutoReadIndicator(colors) : null,
    );
  }

  Widget _buildContinuousTextReader(_ReaderThemeColors colors) {
    final surfaceMetrics = _resolveReaderSurfaceMetrics(context);
    final bodyPadding = surfaceMetrics.scrollBodyPadding;
    final contentSession = _resolvedContentSession();

    final listView = NotificationListener<ScrollNotification>(
      onNotification: _onReaderScrollNotification,
      child: ListView.separated(
        controller: _scrollController,
        cacheExtent: _document.hasImageBlocks ? 640 : 1800,
        padding: bodyPadding,
        itemCount: _continuousTextChapters.length,
        separatorBuilder:
            (_, __) => SizedBox(
              height: max(
                18.0,
                _typographyMetricsResolver.resolveParagraphSpacingPixels(
                      settings: _settings,
                    ) *
                    1.2,
              ),
            ),
        itemBuilder: (context, index) {
          final chapter = _continuousTextChapters[index];
          return _buildContinuousTextChapterSection(
            chapter: chapter,
            isActive: _isContinuousTextChapterActive(chapter),
            colors: colors,
          );
        },
      ),
    );

    return _viewportBuilder.buildContinuousTextViewport(
      listView: listView,
      bodyKey: _readerBodyKey,
      shellModel: _viewportBuilder.buildContinuousShellModel(
        contentSession: contentSession,
        settings: _settings,
        document: _document,
        surfaceMetrics: surfaceMetrics,
        palette: _presentationPalette(context),
      ),
      overlay:
          _isAutoReadSessionEnabled ? _buildAutoReadIndicator(colors) : null,
    );
  }

  Widget _buildContinuousTextChapterSection({
    required _ContinuousTextChapter chapter,
    required bool isActive,
    required _ReaderThemeColors colors,
  }) => _ReaderPageContentRenderingExtension(
    this,
  )._buildContinuousTextChapterSection(
    chapter: chapter,
    isActive: isActive,
    colors: colors,
  );

  ReaderRenderTextItem? _readerRenderTextItemForParagraphIndex(
    int paragraphIndex,
  ) => _ReaderPageContentRenderingExtension(
    this,
  )._readerRenderTextItemForParagraphIndex(paragraphIndex);

  Widget _buildSelectableReaderBlockItem({
    required ReaderRenderBlockItem item,
    required bool isLast,
    required _ReaderThemeColors colors,
  }) => _ReaderPageContentRenderingExtension(
    this,
  )._buildSelectableReaderBlockItem(item: item, isLast: isLast, colors: colors);

  Widget _buildAutoReadIndicator(_ReaderThemeColors colors) =>
      _ReaderPageContentRenderingExtension(
        this,
      )._buildAutoReadIndicator(colors);

  Widget _buildInlineImageParagraphItem({
    required String imageUrl,
    required bool isLast,
    required _ReaderThemeColors colors,
  }) =>
      _ReaderPageContentRenderingExtension(this)._buildInlineImageParagraphItem(
        imageUrl: imageUrl,
        isLast: isLast,
        colors: colors,
      );

  Widget _buildInlineReaderImageCard({
    required String imageUrl,
    required _ReaderThemeColors colors,
  }) => _ReaderPageContentRenderingExtension(
    this,
  )._buildInlineReaderImageCard(imageUrl: imageUrl, colors: colors);

  bool _isInlineImageParagraph(String paragraph) =>
      _ReaderPageContentRenderingExtension(
        this,
      )._isInlineImageParagraph(paragraph);

  int _clampInt(int value, int min, int max) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  int _paragraphIndentLength() {
    final indentCount = _typographyMetricsResolver.resolveParagraphIndentCount(
      _settings,
    );
    return indentCount <= 0 ? 0 : indentCount;
  }

  int _chapterTextLength() {
    final paragraphs =
        _paragraphs.isEmpty
            ? <String>[_content.trim()]
            : _paragraphs.toList(growable: false);
    if (paragraphs.isEmpty) {
      return 0;
    }
    final rawLength = paragraphs.fold<int>(0, (sum, item) => sum + item.length);
    return rawLength + max(0, paragraphs.length - 1) * 2;
  }

  int _resolveChapterOffsetFromDisplayOffset(int displayOffset) {
    final paragraphs =
        _paragraphs.isEmpty
            ? <String>[_content.trim()]
            : _paragraphs.toList(growable: false);
    return text_offset_mapper.resolveChapterOffsetFromDisplayOffset(
      paragraphs: paragraphs,
      pagedPages: _pagedPages,
      currentPageIndex: _currentPageIndex,
      paragraphIndentLength: _paragraphIndentLength(),
      displayOffset: displayOffset,
    );
  }

  int _resolveChapterOffsetFromParagraph({
    required int paragraphIndex,
    required int paragraphOffset,
  }) {
    final paragraphs =
        _paragraphs.isEmpty
            ? <String>[_content.trim()]
            : _paragraphs.toList(growable: false);
    return text_offset_mapper.resolveChapterOffsetFromParagraph(
      paragraphs: paragraphs,
      paragraphIndex: paragraphIndex,
      paragraphOffset: paragraphOffset,
    );
  }

  bool _onReaderScrollNotification(ScrollNotification notification) {
    if (!_isTextScrollViewport) {
      return false;
    }

    if (notification is ScrollStartNotification &&
        notification.dragDetails != null &&
        _isAutoReadSessionEnabled) {
      _stopAutoReadSession();
    }

    if (_isBootstrapping || _isLoadingContent || _errorText != null) {
      if (notification is ScrollStartNotification ||
          notification is ScrollEndNotification ||
          (notification is UserScrollNotification &&
              notification.direction == ScrollDirection.idle)) {
        _resetScrollEdgeAdvanceState();
      }
      return false;
    }

    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification is ScrollStartNotification) {
      _resetScrollEdgeAdvanceState();
      return false;
    }

    final atTop =
        metrics.pixels <=
        metrics.minScrollExtent + _kScrollAdvanceEdgeTolerance;
    final atBottom =
        metrics.pixels >=
        metrics.maxScrollExtent - _kScrollAdvanceEdgeTolerance;
    final nearTop =
        metrics.pixels <=
        metrics.minScrollExtent + _kScrollAdvanceNearEdgeThreshold;
    final nearBottom =
        metrics.pixels >=
        metrics.maxScrollExtent - _kScrollAdvanceNearEdgeThreshold;
    if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse && nearBottom) {
        _updateScrollEdgeAdvanceState(isArmed: true, actionDirection: 1);
      } else if (notification.direction == ScrollDirection.forward && nearTop) {
        _updateScrollEdgeAdvanceState(
          isArmed: true,
          actionDirection: _kScrollRefreshCurrentChapterAction,
        );
      } else if (notification.direction == ScrollDirection.forward) {
        _updateScrollEdgeAdvanceState(isArmed: false, actionDirection: 0);
      } else if (notification.direction == ScrollDirection.idle) {
        _updateScrollEdgeAdvanceState(isArmed: false, actionDirection: 0);
      }
    }

    if (!atBottom && !atTop) {
      _updateScrollEdgeAdvanceState(overscrollDistance: 0);
      if (notification is ScrollEndNotification ||
          (notification is UserScrollNotification &&
              notification.direction == ScrollDirection.idle)) {
        _updateScrollEdgeAdvanceState(isArmed: false, actionDirection: 0);
      }
      return false;
    }

    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null &&
        notification.scrollDelta != null) {
      final delta = notification.scrollDelta!;
      if (nearBottom && delta >= 0) {
        _updateScrollEdgeAdvanceState(isArmed: true, actionDirection: 1);
      } else if (nearTop && delta <= 0) {
        _updateScrollEdgeAdvanceState(
          isArmed: true,
          actionDirection: _kScrollRefreshCurrentChapterAction,
        );
      }
    }

    if (notification is OverscrollNotification &&
        notification.dragDetails != null) {
      final direction =
          notification.overscroll > 0 && atBottom
              ? 1
              : notification.overscroll < 0 && atTop
              ? _kScrollRefreshCurrentChapterAction
              : 0;
      if (direction != 0) {
        _updateScrollEdgeAdvanceState(
          isArmed: true,
          actionDirection: direction,
          overscrollDistance:
              _scrollEdgeAdvanceState.overscrollDistance +
              notification.overscroll.abs(),
        );
      }
      if (_scrollEdgeAdvanceState.overscrollDistance >=
              _kScrollAdvanceOverscrollTrigger &&
          _scrollEdgeAdvanceState.actionDirection != 0) {
        final actionDirection = _scrollEdgeAdvanceState.actionDirection;
        _resetScrollEdgeAdvanceState();
        unawaited(_handleScrollEdgeChapterAction(actionDirection));
      }
      return false;
    }

    if (notification is ScrollEndNotification ||
        (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle)) {
      final isDragEnd =
          notification is ScrollEndNotification &&
          notification.dragDetails != null;
      final double endVelocityDy =
          notification is ScrollEndNotification
              ? (notification.dragDetails?.velocity.pixelsPerSecond.dy ?? 0)
              : 0;
      final action = _readerRuntimeController.resolveScrollEdgeDragEndAction(
        isArmed: _scrollEdgeAdvanceState.isArmed,
        armedActionDirection: _scrollEdgeAdvanceState.actionDirection,
        atTop: atTop,
        atBottom: atBottom,
        isDragEnd: isDragEnd,
        velocityDy: endVelocityDy,
      );
      _resetScrollEdgeAdvanceState();
      if (action == ReaderScrollEdgeAction.nextChapter) {
        unawaited(_handleScrollEdgeChapterAction(1));
      } else if (action == ReaderScrollEdgeAction.refreshCurrent) {
        unawaited(
          _handleScrollEdgeChapterAction(_kScrollRefreshCurrentChapterAction),
        );
      }
    }

    return false;
  }

  Future<void> _handleScrollEdgeChapterAction(int direction) async {
    if (direction == 0) {
      return;
    }
    if (direction == _kScrollRefreshCurrentChapterAction) {
      await _reloadCurrentChapterFromPullToRefresh();
      return;
    }
    if (_shouldUseContinuousTextFlow) {
      _showMessage(
        direction > 0 ? '正在加载下一章...' : '正在加载上一章...',
        duration: const Duration(milliseconds: 900),
        dedupeKey:
            direction > 0 ? 'loading_next_chapter' : 'loading_prev_chapter',
      );
      final chapter = await _loadAdjacentContinuousTextChapter(
        forward: direction > 0,
      );
      if (chapter != null && mounted) {
        _activateContinuousTextChapterFlow(chapter);
      } else if (mounted) {
        final current = _currentIndex;
        final hasAdjacent =
            current != null &&
            _chapterNavigation.findReadableChapterIndex(
                  _chapters,
                  current + (direction > 0 ? 1 : -1),
                  forward: direction > 0,
                ) !=
                null;
        _showMessage(
          hasAdjacent
              ? (direction > 0 ? '下一章仍在加载，请稍后再试。' : '上一章仍在加载，请稍后再试。')
              : (direction > 0 ? '已经是最后一章。' : '已经是第一章。'),
          dedupeKey:
              hasAdjacent
                  ? (direction > 0
                      ? 'next_chapter_loading_pending'
                      : 'prev_chapter_loading_pending')
                  : (direction > 0
                      ? 'boundary_last_chapter'
                      : 'boundary_first_chapter'),
        );
      }
      return;
    }
    await _jumpChapterFromScrollEdge(forward: direction > 0);
  }

  Future<void> _jumpChapterFromScrollEdge({required bool forward}) async {
    if (_isScrollEdgeAdvancingChapter || _isAutoReadAdvancingChapter) {
      return;
    }

    _isScrollEdgeAdvancingChapter = true;
    try {
      await _jumpToAdjacentReadableChapter(forward: forward);
    } finally {
      _isScrollEdgeAdvancingChapter = false;
    }
  }

  String _buildMangaImageUrl(String imageUrl, int retryNonce) {
    if (retryNonce <= 0 || imageUrl.startsWith('data:image/')) {
      return imageUrl;
    }

    final uri = Uri.tryParse(imageUrl);
    if (uri == null || uri.scheme == 'file') {
      return imageUrl;
    }

    final updatedParameters = Map<String, String>.from(uri.queryParameters)
      ..['retry'] = '$retryNonce';
    return uri.replace(queryParameters: updatedParameters).toString();
  }

  Widget _buildMangaReader(_ReaderThemeColors colors) =>
      _buildMangaViewport(colors);

  Widget _buildReaderImageWidget({
    required String requestUrl,
    required String sourceUrl,
    required _ReaderThemeColors colors,
    required int retryNonce,
  }) => _ReaderPageContentRenderingExtension(this)._buildReaderImageWidget(
    requestUrl: requestUrl,
    sourceUrl: sourceUrl,
    colors: colors,
    retryNonce: retryNonce,
  );

  double _resolveMangaCacheExtent() =>
      _ReaderPageContentRenderingExtension(this)._resolveMangaCacheExtent();

  ReaderThemeMode _effectiveReaderThemeMode() {
    return _settings.themeMode;
  }

  Brightness _currentPlatformBrightness() {
    return WidgetsBinding.instance.platformDispatcher.platformBrightness;
  }

  ThemeMode _currentAppThemeMode() {
    return ref.read(appThemeModeProvider);
  }

  AppAdvancedTheme? _currentActiveAdvancedTheme() {
    return ref.read(activeAdvancedThemeProvider).valueOrNull;
  }

  Future<void> _syncAppThemeModeWithReaderTheme(ReaderThemeMode mode) async {
    final nextAppThemeMode = switch (mode) {
      ReaderThemeMode.dark => ThemeMode.dark,
      ReaderThemeMode.light => ThemeMode.light,
      ReaderThemeMode.sepia => null,
    };
    if (nextAppThemeMode == null) {
      return;
    }
    final currentAppThemeMode = _currentAppThemeMode();
    if (currentAppThemeMode == nextAppThemeMode) {
      return;
    }
    await ref
        .read(appThemeModeProvider.notifier)
        .setThemeMode(nextAppThemeMode);
  }

  void _handleAppThemeModeChanged(ThemeMode nextMode) {
    if (!mounted) {
      return;
    }
    _syncReaderThemeDependencies(appThemeMode: nextMode);
  }

  void _handleActiveAdvancedThemeChanged(
    AsyncValue<AppAdvancedTheme?> nextTheme,
  ) {
    if (!mounted || nextTheme.isLoading) {
      return;
    }
    _syncReaderThemeDependencies(activeTheme: nextTheme.valueOrNull);
  }

  void _syncReaderThemeDependencies({
    ThemeMode? appThemeMode,
    AppAdvancedTheme? activeTheme,
  }) {
    final nextResolved = _resolveReaderSettingsLayers(
      appThemeMode: appThemeMode,
      activeTheme: activeTheme,
    );
    final nextSettings = nextResolved.copyWith(
      pageTurnMode: _settings.pageTurnMode,
      autoReadEnabled: _settings.autoReadEnabled,
    );
    if (jsonEncode(nextSettings.toJson()) == jsonEncode(_settings.toJson())) {
      return;
    }
    _applyReaderSettingsWithModeRestore(nextSettings: nextSettings);
  }

  ReaderSettings _resolveReaderSettingsLayers({
    ReaderSettings? persistedSettings,
    ReaderVisualOverrides? visualOverrides,
    AppAdvancedTheme? activeTheme,
    ThemeMode? appThemeMode,
    Brightness? platformBrightness,
  }) {
    return _readerSettingsResolutionService.resolve(
      persistedSettings: persistedSettings ?? _persistedReaderSettings,
      visualOverrides: visualOverrides ?? _visualOverrides,
      activeTheme: activeTheme ?? _currentActiveAdvancedTheme(),
      appThemeMode: appThemeMode ?? _currentAppThemeMode(),
      platformBrightness: platformBrightness ?? _currentPlatformBrightness(),
    );
  }

  String? _normalizeOptionalVisualValue(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  bool _matchesThemeReaderFontBinding(
    ReaderSettings settings,
    String themeFontFamilyKey,
  ) {
    return settings.fontSource == ReaderFontSource.custom &&
        _normalizeOptionalVisualValue(settings.fontFamilyKey) ==
            themeFontFamilyKey &&
        _normalizeOptionalVisualValue(settings.customFontPath) == null;
  }

  Future<void> _persistResolvedReaderSettingsLayers(
    ReaderSettings resolvedSettings,
  ) async {
    final activeTheme = _currentActiveAdvancedTheme();
    final appThemeMode = _currentAppThemeMode();
    final platformBrightness = _currentPlatformBrightness();
    final themeReaderBackgroundPath = _readerSettingsResolutionService
        .resolveThemeReaderBackgroundPath(
          activeTheme: activeTheme,
          appThemeMode: appThemeMode,
          platformBrightness: platformBrightness,
        );
    final themeReaderFontFamilyKey = _readerSettingsResolutionService
        .resolveThemeReaderFontFamilyKey(activeTheme);

    var nextPersisted = resolvedSettings;
    var nextVisualOverrides = _visualOverrides;

    if (themeReaderBackgroundPath != null) {
      final persistedBackground = _normalizeOptionalVisualValue(
        _persistedReaderSettings.backgroundImageBase64,
      );
      nextPersisted = nextPersisted.copyWith(
        backgroundImageBase64: persistedBackground,
        clearBackgroundImage: persistedBackground == null,
      );

      final selectedBackground = _normalizeOptionalVisualValue(
        resolvedSettings.backgroundImageBase64,
      );
      if (selectedBackground == themeReaderBackgroundPath) {
        nextVisualOverrides = nextVisualOverrides.copyWith(
          clearBackgroundImageOverride: true,
        );
      } else {
        nextVisualOverrides = nextVisualOverrides.copyWith(
          hasBackgroundImageOverride: true,
          backgroundImageBase64: selectedBackground,
        );
      }
    } else {
      nextVisualOverrides = nextVisualOverrides.copyWith(
        clearBackgroundImageOverride: true,
      );
    }

    if (themeReaderFontFamilyKey != null) {
      final persistedFontFamilyKey = _normalizeOptionalVisualValue(
        _persistedReaderSettings.fontFamilyKey,
      );
      final persistedCustomFontPath = _normalizeOptionalVisualValue(
        _persistedReaderSettings.customFontPath,
      );
      nextPersisted = nextPersisted.copyWith(
        fontSource: _persistedReaderSettings.fontSource,
        systemFontPreset: _persistedReaderSettings.systemFontPreset,
        fontFamilyKey: persistedFontFamilyKey,
        clearFontFamilyKey: persistedFontFamilyKey == null,
        customFontPath: persistedCustomFontPath,
        clearCustomFontPath: persistedCustomFontPath == null,
      );

      if (_matchesThemeReaderFontBinding(
        resolvedSettings,
        themeReaderFontFamilyKey,
      )) {
        nextVisualOverrides = nextVisualOverrides.copyWith(
          clearFontSource: true,
          clearSystemFontPreset: true,
          clearFontFamilyKeyOverride: true,
          clearCustomFontPathOverride: true,
        );
      } else {
        nextVisualOverrides = nextVisualOverrides.copyWith(
          fontSource: resolvedSettings.fontSource,
          systemFontPreset: resolvedSettings.systemFontPreset,
          hasFontFamilyKeyOverride: true,
          fontFamilyKey: _normalizeOptionalVisualValue(
            resolvedSettings.fontFamilyKey,
          ),
          hasCustomFontPathOverride: true,
          customFontPath: _normalizeOptionalVisualValue(
            resolvedSettings.customFontPath,
          ),
        );
      }
    } else {
      nextVisualOverrides = nextVisualOverrides.copyWith(
        clearFontSource: true,
        clearSystemFontPreset: true,
        clearFontFamilyKeyOverride: true,
        clearCustomFontPathOverride: true,
      );
    }

    await _preferencesService.saveSettings(nextPersisted);
    await _visualOverridesService.saveOverrides(nextVisualOverrides);

    _persistedReaderSettings = nextPersisted;
    _visualOverrides = nextVisualOverrides;
    _settings = _resolveReaderSettingsLayers(
      persistedSettings: nextPersisted,
      visualOverrides: nextVisualOverrides,
      activeTheme: activeTheme,
      appThemeMode: appThemeMode,
      platformBrightness: platformBrightness,
    );
  }

  ReaderPageAnimationStyle _currentPagedAnimationStyle() {
    return _currentReaderMode.pageAnimationStyle ??
        ReaderPageAnimationStyle.none;
  }

  bool _currentChapterHasInlineImageParagraphs() {
    return _paragraphs.any(_isInlineImageParagraph);
  }

  Widget _buildPagedReader(_ReaderThemeColors colors) =>
      _buildPagedTextViewport(colors);

  Widget _buildPagedPageContainer({
    required _ReaderThemeColors colors,
    required int pageIndex,
    required int total,
    required Size pageSize,
    required ReaderTextPagedViewModel pagedViewModel,
    bool includeBackgroundDecoration = false,
  }) => _ReaderPageContentRenderingExtension(this)._buildPagedPageContainer(
    colors: colors,
    pageIndex: pageIndex,
    total: total,
    pageSize: pageSize,
    pagedViewModel: pagedViewModel,
    includeBackgroundDecoration: includeBackgroundDecoration,
  );

  Widget _buildPagedHeaderSection(
    _ReaderThemeColors colors,
    ReaderSurfaceMetrics layoutMetrics,
  ) => _ReaderPageContentRenderingExtension(
    this,
  )._buildPagedHeaderSection(colors, layoutMetrics);

  Widget _buildPagedFooterSection({
    required _ReaderThemeColors colors,
    required int index,
    required int total,
    required ReaderSurfaceMetrics layoutMetrics,
  }) => _ReaderPageContentRenderingExtension(this)._buildPagedFooterSection(
    colors: colors,
    index: index,
    total: total,
    layoutMetrics: layoutMetrics,
  );

  Widget _buildPageIndexOverlay({
    required _ReaderThemeColors colors,
    required int index,
    required int total,
    required double bottomInset,
    double? safeBottomInset,
  }) => _ReaderPageContentRenderingExtension(this)._buildPageIndexOverlay(
    colors: colors,
    index: index,
    total: total,
    bottomInset: bottomInset,
    safeBottomInset: safeBottomInset,
  );

  void _updateCurlPreviewProgress(Size viewportSize) {
    if (_isCurlAutoTurning) {
      return;
    }

    final startDx = _swipeDragStartDx;
    final currentDx = _swipeDragCurrentDx;
    if (startDx == null || currentDx == null) {
      return;
    }

    final delta = currentDx - startDx;
    if (delta.abs() < _kCurlPreviewStartThreshold) {
      if (_isCurlPreviewActive) {
        setState(() {
          _curlTransition = _curlTransition.copyWith(
            isPreview: false,
            previewProgress: 0,
          );
        });
      }
      return;
    }

    final pageCount = _currentPagedPageCount;
    if (pageCount <= 0) {
      return;
    }

    final direction = delta < 0 ? 1 : -1;
    final currentIndex = _currentPageIndex.clamp(0, pageCount - 1);
    final targetIndex = currentIndex + direction;
    if (targetIndex < 0 || targetIndex >= pageCount) {
      if (_isCurlPreviewActive) {
        setState(() {
          _curlTransition = _curlTransition.copyWith(
            isPreview: false,
            previewProgress: 0,
          );
        });
      }
      return;
    }

    final progress = (delta.abs() / max(viewportSize.width * 0.9, 1.0)).clamp(
      0.0,
      0.98,
    );
    if (_isCurlPreviewActive &&
        _curlAutoDirection == direction &&
        _curlAnimationFromIndex == currentIndex &&
        _curlAnimationToIndex == targetIndex &&
        (progress - _curlPreviewProgress).abs() < 0.01) {
      return;
    }

    setState(() {
      _curlTransition = _curlTransition.copyWith(
        direction: direction,
        fromIndex: currentIndex,
        toIndex: targetIndex,
        previewProgress: progress,
        isPreview: true,
      );
    });
  }

  void _finishCurlPreview({required bool commit}) {
    if (!_isCurlPreviewActive) {
      return;
    }

    final progress = _curlPreviewProgress.clamp(0.0, 1.0);
    if (progress <= 0) {
      setState(() {
        _curlTransition = _curlTransition.copyWith(
          isPreview: false,
          previewProgress: 0,
        );
      });
      return;
    }

    setState(() {
      _curlTransition = _curlTransition.copyWith(
        commitOnAnimationEnd: commit,
        isPreview: false,
        isAnimating: true,
      );
    });

    _curlAutoTurnController.value = progress;
    if (commit) {
      _curlAutoTurnController.forward();
    } else {
      _curlAutoTurnController.reverse();
    }
  }

  void _onCurlAutoTurnStatus(AnimationStatus status) {
    if (!_isCurlAutoTurning) {
      return;
    }

    if (status == AnimationStatus.dismissed && !_curlCommitOnAnimationEnd) {
      final pageCount = _currentPagedPageCount;
      final currentIndex =
          pageCount <= 0
              ? 0
              : _currentPageIndex.clamp(0, _safePageUpperBound(pageCount));
      setState(() {
        _curlTransition = _curlTransition.copyWith(
          isAnimating: false,
          isPreview: false,
          previewProgress: 0,
          fromIndex: currentIndex,
          toIndex: currentIndex,
        );
      });
      return;
    }

    if (status != AnimationStatus.completed || !_curlCommitOnAnimationEnd) {
      return;
    }

    if (_isCurlCrossChapterTurn) {
      setState(() {
        _curlTransition = const _CurlTransitionState();
      });
      _recordFirstPageTurnCompleted(mode: 'curl_cross_chapter');
      return;
    }

    final pageCount = _currentPagedPageCount;
    if (pageCount <= 0) {
      if (!mounted) {
        _curlTransition = const _CurlTransitionState();
        _currentPageIndex = 0;
        return;
      }
      setState(() {
        _curlTransition = const _CurlTransitionState();
        _currentPageIndex = 0;
      });
      return;
    }
    final nextIndex = _curlAnimationToIndex.clamp(
      0,
      _safePageUpperBound(pageCount),
    );

    setState(() {
      _curlTransition = _curlTransition.copyWith(
        isAnimating: false,
        isPreview: false,
        previewProgress: 0,
        fromIndex: nextIndex,
        toIndex: nextIndex,
      );
      _currentPageIndex = nextIndex;
    });
    _scheduleProgressSave();
    _recordFirstPageTurnCompleted(mode: 'curl');
  }

  Future<void> _autoTurnCurlPage(int direction) async {
    if (_isCurlAutoTurning) {
      return;
    }

    final pageCount = _currentPagedPageCount;
    if (pageCount <= 0) {
      return;
    }

    final currentIndex = _currentPageIndex.clamp(0, pageCount - 1);
    if (direction < 0 && currentIndex <= 0) {
      await _jumpToAdjacentReadableChapter(forward: false);
      return;
    }

    if (direction > 0 && currentIndex >= pageCount - 1) {
      await _jumpToAdjacentReadableChapter(forward: true);
      return;
    }

    setState(() {
      _curlTransition = _curlTransition.copyWith(
        direction: direction,
        fromIndex: currentIndex,
        toIndex: currentIndex + direction,
        commitOnAnimationEnd: true,
        isPreview: false,
        previewProgress: 0,
        isAnimating: true,
      );
    });

    _curlAutoTurnController.value = 0;
    _curlAutoTurnController.forward();
  }

  void _snapToPagedTextPage(int pageIndex) {
    final pageCount = _currentPagedPageCount;
    if (pageCount <= 0) {
      return;
    }
    final safeIndex = pageIndex.clamp(0, _safePageUpperBound(pageCount));
    _resetPagedTransitionState();
    _resetCurlAnimationState();
    _pagedTextControllerSyncGeneration += 1;
    final pageController = _staticPagedTextPageControllerInstance;
    if (pageController != null && pageController.hasClients) {
      pageController.jumpToPage(safeIndex);
    }
    setState(() {
      _currentPageIndex = safeIndex;
      _pagedPaginationState = _pagedPaginationState.copyWith(
        pendingRestoreRatio: safeIndex / max(1, pageCount - 1),
      );
    });
    _syncActiveReadingRecordSessionProgress();
    _scheduleProgressSave();
  }

  void _ensurePagination({required ReaderPaginationSpec spec}) {
    if (!mounted || !_isTextPagedViewport) {
      return;
    }
    final plan = _paginationEngine.buildEnsurePlan(
      ReaderPaginationEnsureRequest(
        spec: spec,
        signature: _buildPaginationSignature(spec: spec),
        currentState: _pagedPaginationState,
        hasExistingPages: _pagedPages.isNotEmpty || _pagedBlockPages.isNotEmpty,
        currentProgressRatio: _currentScrollRatio(),
      ),
    );
    if (!plan.shouldPaginate) {
      return;
    }

    final taskId =
        _readerSessionController
            .beginIntent(const ReaderSessionIntent.changeSettings())
            .paginationTaskToken!;
    unawaited(
      _restoreOrPaginateCurrentChapter(taskId: taskId, spec: spec, plan: plan),
    );
  }

  Future<void> _restoreOrPaginateCurrentChapter({
    required int taskId,
    required ReaderPaginationSpec spec,
    required ReaderPaginationEnsurePlan plan,
  }) async {
    final sourceId = (_sourceId ?? '').trim();
    final chapterUrl = (_chapterUrl ?? '').trim();

    if (sourceId.isNotEmpty && chapterUrl.isNotEmpty) {
      final cachedLayout = await _loadPrecomputedChapterLayout(
        sourceId: sourceId,
        chapterUrl: chapterUrl,
        signature: plan.signature,
      );
      if (!mounted || taskId != _paginationTaskId) {
        return;
      }
      if (cachedLayout != null && cachedLayout.pagedPages.isNotEmpty) {
        final targetIndex = _chapterLoadPlanner.resolvePageIndexByRatio(
          targetRatio: plan.preservedRatio,
          pageCount: cachedLayout.pagedPages.length,
        );
        setState(() {
          _pagedPages = cachedLayout.pagedPages;
          _currentPageIndex = targetIndex;
          _pagedPaginationState = ReaderPaginationSessionState(
            signature: cachedLayout.paginationSignature,
          );
          if (_paragraphs.isEmpty && cachedLayout.paragraphs.isNotEmpty) {
            _paragraphs = List<String>.unmodifiable(cachedLayout.paragraphs);
          }
          _resetPagedTransitionState();
          _resetCurlAnimationState();
        });
        return;
      }
    }

    _resetPagedTransitionState();
    _resetCurlAnimationState();

    setState(() {
      _textPaginationFallbackDiagnostic = null;
      _pagedPaginationState = plan.buildLoadingState();
      _pagedPages = const [];
      _currentPageIndex = 0;
    });

    await _paginateCurrentChapter(
      taskId: taskId,
      spec: spec,
      signature: plan.signature,
    );
  }

  void _resetCurlAnimationState() {
    _curlAutoTurnController.stop();
    _curlTransition = const _CurlTransitionState();
  }

  void _resetPagedTransitionState() {
    _pagedTransitionController.stop();
    _pagedTransition = PagedTransitionController.idleState;
  }

  String _buildPaginationSignature({
    required ReaderPaginationSpec spec,
    String? chapterIdOverride,
  }) {
    return _paginationSpecResolver.buildSignature(
      chapterId: chapterIdOverride ?? _chapterId,
      spec: spec,
    );
  }

  bool _canWarmNeighborPaginationCache() {
    final paginationSpec = _lastPaginationSpec;
    return _isTextPagedViewport &&
        !_pagedPaginationState.isPaginating &&
        _pagedPages.isNotEmpty &&
        paginationSpec != null &&
        paginationSpec.contentWidth >= 20 &&
        paginationSpec.contentHeight >= 40;
  }

  List<ReaderPaginationParagraph> _buildPaginationParagraphModels(
    _ReaderThemeColors colors,
    List<String> paragraphs,
  ) {
    return List<ReaderPaginationParagraph>.generate(paragraphs.length, (index) {
      final renderItem = _readerRenderTextItemForParagraphIndex(index);
      final resolved = resolveReaderTextBlockPresentation(
        settings: _settings,
        primaryTextColor: colors.text,
        secondaryTextColor: colors.meta,
        item: renderItem,
        isLast: false,
      );
      final style = resolved.textStyle.copyWith(color: Colors.black);
      final firstLinePrefix =
          renderItem == null ||
                  renderItem.kind == ReaderRenderTextKind.paragraph
              ? readerParagraphIndentPrefix(_settings)
              : '';
      return ReaderPaginationParagraph(
        text: paragraphs[index],
        paragraphStyle: style,
        textAlign: resolved.textAlign,
        firstLinePrefix: firstLinePrefix,
        spacingAfter: resolved.spacingAfter,
      );
    }, growable: false);
  }

  Future<void> _paginateCurrentChapter({
    required int taskId,
    required ReaderPaginationSpec spec,
    required String signature,
  }) async {
    final paragraphs =
        _paragraphs.isEmpty ? <String>[_content.trim()] : _paragraphs;
    final colors = _resolveThemeColors(_effectiveReaderThemeMode(), _settings);
    final request = ReaderPaginationRequest(
      paragraphs: paragraphs,
      spec: spec,
      paragraphStyle: _paragraphTextStyle(colors).copyWith(color: Colors.black),
      paragraphModels: _buildPaginationParagraphModels(colors, paragraphs),
      textScaler: MediaQuery.textScalerOf(context),
      shouldAbort: () => !mounted || taskId != _paginationTaskId,
    );
    if (_document.hasImageBlocks) {
      await for (final event in _streamingPaginationController.paginateBlocks(
        ReaderBlockPaginationRequest(
          renderItems: _renderItems,
          paragraphs: paragraphs,
          spec: spec,
          paragraphStyle: _paragraphTextStyle(
            colors,
          ).copyWith(color: Colors.black),
          paragraphModels: _buildPaginationParagraphModels(colors, paragraphs),
          textScaler: MediaQuery.textScalerOf(context),
          shouldAbort: () => !mounted || taskId != _paginationTaskId,
        ),
        targetRatio: _pagedPaginationState.pendingRestoreRatio ?? 0,
      )) {
        if (!mounted || taskId != _paginationTaskId) {
          return;
        }
        if (event.type == ReaderStreamingPaginationEventType.cancelled) {
          return;
        }
        final pages = event.pages;
        if (pages.isEmpty) {
          if (event.completed) {
            _fallbackTextPaginationToScroll(
              'block pagination completed with no pages',
            );
          }
          continue;
        }
        final pendingRatio = _pagedPaginationState.pendingRestoreRatio;
        final targetIndex =
            pendingRatio == null
                ? _currentPageIndex.clamp(0, pages.length - 1)
                : (pendingRatio.clamp(0.0, 1.0) * (pages.length - 1))
                    .round()
                    .clamp(0, pages.length - 1);
        setState(() {
          _textPaginationFallbackDiagnostic = null;
          _pagedPaginationState = ReaderPaginationSessionState(
            signature: signature,
            isPaginating: !event.completed,
          );
          _pagedPages = const <List<ReaderPagedSlice>>[];
          _pagedBlockPages = pages;
          _currentPageIndex = targetIndex;
          _resetCurlAnimationState();
        });
      }
      return;
    }

    await for (final event in _streamingPaginationController.paginateText(
      request,
      targetRatio: _pagedPaginationState.pendingRestoreRatio ?? 0,
    )) {
      if (!mounted || taskId != _paginationTaskId) {
        return;
      }
      if (event.type == ReaderStreamingPaginationEventType.cancelled) {
        return;
      }
      final pages = event.pages;
      if (pages.isEmpty) {
        setState(() {
          _pagedPaginationState = _pagedPaginationState.copyWith(
            isPaginating: false,
            pendingRestoreRatio: null,
          );
          _pagedPages = const [];
          _pagedBlockPages = const <List<ReaderPagedBlock>>[];
          _resetCurlAnimationState();
        });
        continue;
      }
      var targetIndex = 0;
      final pendingRatio = _pagedPaginationState.pendingRestoreRatio;
      if (pendingRatio != null && pages.isNotEmpty) {
        targetIndex = (pendingRatio.clamp(0.0, 1.0) * (pages.length - 1))
            .round()
            .clamp(0, pages.length - 1);
      }
      setState(() {
        _pagedPaginationState = ReaderPaginationSessionState(
          signature: signature,
          isPaginating: !event.completed,
        );
        _pagedPages = pages;
        _pagedBlockPages = const <List<ReaderPagedBlock>>[];
        _currentPageIndex = targetIndex;
        _resetCurlAnimationState();
      });
      if (event.completed) {
        if (_paginationCacheService.shouldPersistChapterLayout(
          sourceId: _sourceId ?? '',
          chapterUrl: _chapterUrl ?? '',
        )) {
          _storePrecomputedChapterLayout(
            sourceId: _sourceId ?? '',
            chapterUrl: _chapterUrl ?? '',
            layout: ReaderPrecomputedChapterLayout(
              paragraphs: paragraphs,
              pagedPages: pages,
              paginationSignature: signature,
            ),
          );
        }
      }
    }
    return;
  }

  void _fallbackTextPaginationToScroll(String diagnostic) {
    if (!mounted) {
      return;
    }
    _resetPagedTransitionState();
    _resetCurlAnimationState();
    setState(() {
      _textPaginationFallbackDiagnostic = diagnostic;
      _pagedPaginationState = const ReaderPaginationSessionState();
      _pagedPages = const <List<ReaderPagedSlice>>[];
      _pagedBlockPages = const <List<ReaderPagedBlock>>[];
      _currentPageIndex = 0;
    });
  }

  Widget _buildTapAwareBody({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gestureInsets = MediaQuery.systemGestureInsetsOf(context);
        final enableSwipeTurn = _isSwipePaginationEnabled();
        final enableCurlPreview = _shouldUseCurlGesturePreview();
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerSignal: _handleReaderPointerSignal,
          onPointerDown: (event) {
            if (!_isPrimaryReaderPointerDown(event)) {
              return;
            }
            if (_tapPointerId != null) {
              return;
            }
            _tapPointerId = event.pointer;
            _tapPointerDownPosition = event.localPosition;
            _tapPointerDownTime = DateTime.now();
            _tapPointerMoved = false;
            if (enableSwipeTurn) {
              _swipeDragStartDx = event.localPosition.dx;
              _swipeDragStartDy = event.localPosition.dy;
              _swipeDragCurrentDx = event.localPosition.dx;
              _swipeDragCurrentDy = event.localPosition.dy;
            }
          },
          onPointerMove: (event) {
            if (event.pointer != _tapPointerId) {
              return;
            }
            if (enableSwipeTurn) {
              _swipeDragCurrentDx = event.localPosition.dx;
              _swipeDragCurrentDy = event.localPosition.dy;
              if (enableCurlPreview) {
                _updateCurlPreviewProgress(constraints.biggest);
              }
            }
            final down = _tapPointerDownPosition;
            if (down != null && !_tapPointerMoved) {
              final moved = (event.localPosition - down).distance;
              if (moved > kTouchSlop) {
                _tapPointerMoved = true;
              }
            }
          },
          onPointerCancel: (event) {
            if (event.pointer != _tapPointerId) {
              return;
            }
            if (enableCurlPreview && _isCurlPreviewActive) {
              _finishCurlPreview(commit: false);
            }
            _resetPointerTracking();
          },
          onPointerUp: (event) {
            if (event.pointer != _tapPointerId) {
              return;
            }
            if (_isInitialReaderInteractionCoolingDown) {
              _resetPointerTracking();
              return;
            }
            final size = constraints.biggest;
            final downTime = _tapPointerDownTime;
            final elapsedMs =
                downTime == null
                    ? 0
                    : DateTime.now().difference(downTime).inMilliseconds;
            final dx =
                (_swipeDragCurrentDx ?? event.localPosition.dx) -
                (_swipeDragStartDx ?? event.localPosition.dx);
            final dy =
                (_swipeDragCurrentDy ?? event.localPosition.dy) -
                (_swipeDragStartDy ?? event.localPosition.dy);
            final velocity = elapsedMs <= 0 ? 0.0 : dx / (elapsedMs / 1000.0);

            if (enableSwipeTurn &&
                _swipeDragStartDx != null &&
                _swipeDragCurrentDx != null) {
              final isSwipe =
                  dx.abs() >= _kSwipeTurnDistanceThreshold ||
                  velocity.abs() >= _kSwipeTurnVelocityThreshold;
              if (enableCurlPreview && _isCurlPreviewActive) {
                _finishCurlPreview(commit: isSwipe);
                _resetPointerTracking();
                return;
              }
              if (isSwipe) {
                final dragDetails = DragEndDetails(
                  velocity: Velocity(pixelsPerSecond: Offset(velocity, 0)),
                  primaryVelocity: velocity,
                );
                _onSwipePaginationDragEnd(dragDetails, size);
                _resetPointerTracking();
                return;
              }
              final isPagedPullRefresh =
                  (_currentViewportKind == ReaderModeViewportKind.textPaged ||
                      _currentViewportKind ==
                          ReaderModeViewportKind.imagePaged) &&
                  dy >= _kPagedPullRefreshDistanceThreshold &&
                  dy.abs() > dx.abs() * 1.2;
              if (isPagedPullRefresh) {
                unawaited(_reloadCurrentChapterFromPullToRefresh());
                _resetPointerTracking();
                return;
              }
            }

            if (_suppressNextReaderTap) {
              _suppressNextReaderTap = false;
              _resetPointerTracking();
              return;
            }

            if (!_tapPointerMoved &&
                elapsedMs <= kLongPressTimeout.inMilliseconds &&
                !_isTextSelectionActive) {
              _onReaderTap(event.localPosition, size, gestureInsets);
            }
            _resetPointerTracking();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress:
                _isMangaViewport
                    ? () => unawaited(_openMangaPositionSheet())
                    : null,
            child: child,
          ),
        );
      },
    );
  }

  void _onSwipePaginationDragEnd(DragEndDetails details, Size viewportSize) {
    final startDx = _swipeDragStartDx;
    final currentDx = _swipeDragCurrentDx;
    _swipeDragStartDx = null;
    _swipeDragStartDy = null;
    _swipeDragCurrentDx = null;
    _swipeDragCurrentDy = null;

    if (!_isSwipePaginationEnabled() || startDx == null || currentDx == null) {
      return;
    }
    if (_isInitialReaderInteractionCoolingDown) {
      return;
    }
    if (_isBackNavigationInteractionCoolingDown) {
      return;
    }

    // Reserve system edge-swipe area for route back gestures, so returning to
    // bookshelf does not accidentally trigger chapter/page turning.
    if (context.canPop()) {
      final gestureInsets = MediaQuery.systemGestureInsetsOf(context);
      final leftGuard = max(
        _kSystemBackGestureGuardMin,
        gestureInsets.left + viewportSize.width * _kSystemBackGestureGuardRatio,
      );
      final rightGuard = max(
        _kSystemBackGestureGuardMin,
        gestureInsets.right +
            viewportSize.width * _kSystemBackGestureGuardRatio,
      );
      if (startDx <= leftGuard || startDx >= viewportSize.width - rightGuard) {
        return;
      }
    }

    if (_isAutoReadSessionEnabled) {
      _stopAutoReadSession(showMessage: true);
      return;
    }

    if (_showOverlayControls) {
      _hideOverlayControls(resumeAutoRead: true);
    }

    final delta = currentDx - startDx;
    final velocity = details.primaryVelocity ?? 0;
    final isLeftTurn =
        delta <= -_kSwipeTurnDistanceThreshold ||
        velocity <= -_kSwipeTurnVelocityThreshold;
    final isRightTurn =
        delta >= _kSwipeTurnDistanceThreshold ||
        velocity >= _kSwipeTurnVelocityThreshold;

    if (isLeftTurn && !isRightTurn) {
      unawaited(_turnPagedTextPage(direction: 1));
      return;
    }

    if (isRightTurn && !isLeftTurn) {
      unawaited(_turnPagedTextPage(direction: -1));
    }
  }

  void _resetPointerTracking() {
    _tapPointerId = null;
    _tapPointerDownPosition = null;
    _tapPointerDownTime = null;
    _tapPointerMoved = false;
    _swipeDragStartDx = null;
    _swipeDragStartDy = null;
    _swipeDragCurrentDx = null;
    _swipeDragCurrentDy = null;
  }

  bool _isPrimaryReaderPointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.touch) {
      return true;
    }
    return event.buttons == kPrimaryButton;
  }

  TextStyle _paragraphTextStyle(_ReaderThemeColors colors) =>
      _ReaderPageContentRenderingExtension(this)._paragraphTextStyle(colors);

  Future<int?> _showBodyTextColorPickerDialog(
    BuildContext context, {
    int? initialColorValue,
  }) async {
    Color draftColor = Color(
      initialColorValue ??
          _resolveThemeColors(_settings.themeMode, _settings).text.toARGB32(),
    );

    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final preview = draftColor;

            return AlertDialog(
              title: const Text('自定义正文字色'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '正文预览：山高月小，水落石出。',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: preview,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ColorPicker(
                      pickerColor: draftColor,
                      onColorChanged: (color) {
                        setDialogState(() {
                          draftColor = color;
                        });
                      },
                      enableAlpha: false,
                      displayThumbColor: true,
                      portraitOnly: true,
                      paletteType: PaletteType.hueWheel,
                      pickerAreaHeightPercent: 0.72,
                      labelTypes: const [],
                      hexInputBar: true,
                    ),
                    if (_recentBodyTextColors.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        '最近使用',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _recentBodyTextColors
                            .map((value) {
                              final color = Color(value);
                              final selected = draftColor.toARGB32() == value;
                              return GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    draftColor = color;
                                  });
                                },
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          selected
                                              ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                              : Theme.of(
                                                context,
                                              ).colorScheme.outlineVariant,
                                      width: selected ? 2 : 1,
                                    ),
                                  ),
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed:
                      () => Navigator.of(dialogContext).pop(preview.toARGB32()),
                  child: const Text('使用颜色'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<int?> _showBodyTextShadowColorPickerDialog(
    BuildContext context, {
    int? initialColorValue,
  }) async {
    Color draftColor = Color(
      initialColorValue ??
          _resolveThemeColors(_settings.themeMode, _settings).text.toARGB32(),
    );

    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final preview = draftColor;

            return AlertDialog(
              title: const Text('正文阴影颜色'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '阴影预览：山高月小，水落石出。',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.black,
                          shadows: [
                            Shadow(
                              color: preview,
                              blurRadius: 8,
                              offset: const Offset(1, 1),
                            ),
                          ],
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ColorPicker(
                      pickerColor: draftColor,
                      onColorChanged: (color) {
                        setDialogState(() {
                          draftColor = color;
                        });
                      },
                      enableAlpha: false,
                      displayThumbColor: true,
                      portraitOnly: true,
                      paletteType: PaletteType.hueWheel,
                      pickerAreaHeightPercent: 0.72,
                      labelTypes: const [],
                      hexInputBar: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed:
                      () => Navigator.of(dialogContext).pop(preview.toARGB32()),
                  child: const Text('使用颜色'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<int?> _showBodyTextDecorationColorPickerDialog(
    BuildContext context, {
    int? initialColorValue,
  }) async {
    Color draftColor = Color(
      initialColorValue ??
          _resolveThemeColors(_settings.themeMode, _settings).text.toARGB32(),
    );

    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final preview = draftColor;

            return AlertDialog(
              title: const Text('正文下划线颜色'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '下划线预览：山高月小，水落石出。',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.black,
                          decoration: TextDecoration.underline,
                          decorationColor: preview,
                          decorationThickness: 3,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ColorPicker(
                      pickerColor: draftColor,
                      onColorChanged: (color) {
                        setDialogState(() {
                          draftColor = color;
                        });
                      },
                      enableAlpha: false,
                      displayThumbColor: true,
                      portraitOnly: true,
                      paletteType: PaletteType.hueWheel,
                      pickerAreaHeightPercent: 0.72,
                      labelTypes: const [],
                      hexInputBar: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed:
                      () => Navigator.of(dialogContext).pop(preview.toARGB32()),
                  child: const Text('使用颜色'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _applyParagraphIndent(String paragraph) {
    final indentCount = _paragraphIndentLength();
    if (indentCount <= 0) {
      return paragraph;
    }

    return '${'　' * indentCount}$paragraph';
  }

  Future<void> _openChapterCache() async {
    final sourceId = _sourceId;
    if (sourceId == null || sourceId.isEmpty) {
      if (!mounted) {
        return;
      }
      _showMessage('缺少目录信息，无法缓存。');
      return;
    }
    if (_chapters.isEmpty) {
      await _hydrateCatalogAfterVisible();
      if (!mounted || _chapters.isEmpty) {
        _showMessage('缺少目录信息，无法缓存。');
        return;
      }
    }

    if (!_canCacheChapter) {
      _showMessage(
        _readerCacheFeedbackResolver.unsupportedMessage(
          isLocalContent: _isLocalContent,
        ),
      );
      return;
    }

    final readableChapters = _chapterNavigation.readableChapters(_chapters);
    if (readableChapters.isEmpty) {
      _showMessage(_readerCacheFeedbackResolver.missingCatalogMessage());
      return;
    }

    final total = readableChapters.length;
    final currentChapterId = _chapterId;
    final currentChapterUrl = (_chapterUrl ?? '').trim();
    final currentReadableIndex = readableChapters.indexWhere(
      (chapter) =>
          chapter.id == currentChapterId ||
          chapter.chapterUrl.trim() == currentChapterUrl,
    );
    final startIndex =
        (currentReadableIndex >= 0 ? currentReadableIndex : 0)
            .clamp(0, max(0, total - 1))
            .toInt();
    final endIndex = min(total - 1, startIndex + 49);

    await showChapterCacheFlow(
      context: context,
      bookId: _currentBookId,
      sourceId: sourceId,
      chapters: readableChapters,
      initialStartIndex: startIndex,
      initialEndIndex: endIndex,
      entryPoint: ChapterCacheEntryPoint.reader,
      bookTitle: _bookTitle,
    );
  }

  Widget _buildTopOverlay(_ReaderThemeColors colors) {
    final chapterTitle =
        _chapterTitle?.isNotEmpty == true ? _chapterTitle! : '阅读';

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_showOverlayControls,
        child: AnimatedBuilder(
          animation: _overlayControlsController,
          builder: (context, _) {
            final fade = _overlayControlsFadeProgress;
            return _buildShellOverlayTransition(
              edge: _OverlayEdge.top,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colors.overlay.withValues(alpha: 0.94),
                          colors.overlay.withValues(alpha: 0.84),
                        ],
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: colors.divider.withValues(alpha: 0.22),
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05 * fade),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: SizedBox(
                        height: 68,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          child: Row(
                            children: [
                              _buildTopActionButton(
                                icon: Icons.arrow_back_ios_new,
                                tooltip: '返回',
                                onPressed: _handleBackNavigation,
                                colors: colors,
                                emphasizeHitArea: true,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      chapterTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.text,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _chapterProgressLabel(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.meta,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (_canCacheChapter)
                                _buildTopActionButton(
                                  icon:
                                      _isCurrentChapterCached
                                          ? Icons.cloud_done_rounded
                                          : Icons.cloud_download_outlined,
                                  tooltip:
                                      _isCurrentChapterCached
                                          ? '已缓存章节'
                                          : '缓存章节',
                                  onPressed:
                                      () => unawaited(_openChapterCache()),
                                  colors: colors,
                                ),
                              if (_canSwitchSource) ...[
                                const SizedBox(width: 2),
                                _buildTopActionButton(
                                  icon: Icons.swap_horiz_rounded,
                                  tooltip:
                                      _isSwitchSourceLoading
                                          ? '换源中...'
                                          : '切换书源',
                                  onPressed:
                                      _isSwitchSourceLoading
                                          ? null
                                          : () => unawaited(
                                            _showSwitchSourceSheet(),
                                          ),
                                  colors: colors,
                                  loading: _isSwitchSourceLoading,
                                ),
                              ],
                              const SizedBox(width: 2),
                              _buildTopActionButton(
                                icon:
                                    _isInBookshelf
                                        ? Icons.bookmark_added
                                        : Icons.bookmark_add_outlined,
                                tooltip: _isInBookshelf ? '从书架移除' : '加入书架',
                                onPressed:
                                    _isShelfActionLoading
                                        ? null
                                        : () => unawaited(_toggleBookshelf()),
                                colors: colors,
                                loading: _isShelfActionLoading,
                              ),
                              const SizedBox(width: 2),
                              _buildTopActionButton(
                                icon: Icons.info_outline,
                                tooltip: '查看详情',
                                onPressed: _openDetailPage,
                                colors: colors,
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildBottomOverlay(_ReaderThemeColors colors) {
    const middleLabel = '界面';
    const middleIcon = Icons.palette_outlined;
    const trailingLabel = '设置';
    final isDarkMode = _effectiveReaderThemeMode() == ReaderThemeMode.dark;
    final dayNightLabel = isDarkMode ? '日间' : '夜间';
    final dayNightIcon =
        isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !_showOverlayControls,
        child: AnimatedBuilder(
          animation: _overlayControlsController,
          builder: (context, _) {
            final fade = _overlayControlsFadeProgress;
            return _buildShellOverlayTransition(
              edge: _OverlayEdge.bottom,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colors.overlay.withValues(alpha: 0.84),
                          colors.overlay.withValues(alpha: 0.94),
                        ],
                      ),
                      border: Border(
                        top: BorderSide(
                          color: colors.divider.withValues(alpha: 0.22),
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06 * fade),
                          blurRadius: 14,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildBottomProgressStrip(colors),
                            const SizedBox(height: 6),
                            Container(
                              height: 1,
                              color: colors.divider.withValues(alpha: 0.18),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildToolbarAction(
                                    icon: Icons.list_alt_outlined,
                                    label: '目录',
                                    onTap: _openCatalogSheetFromOverlay,
                                    colors: colors,
                                  ),
                                ),
                                Expanded(
                                  child: _buildToolbarAction(
                                    icon: middleIcon,
                                    label: middleLabel,
                                    onTap:
                                        () => _showSettingsSheet(
                                          initialTab:
                                              _ReaderSettingsTab.interface,
                                        ),
                                    colors: colors,
                                  ),
                                ),
                                Expanded(
                                  child: _buildToolbarAction(
                                    icon: dayNightIcon,
                                    label: dayNightLabel,
                                    onTap: _toggleDayNightMode,
                                    colors: colors,
                                    active: isDarkMode,
                                  ),
                                ),
                                Expanded(
                                  child: _buildToolbarAction(
                                    icon: Icons.tune,
                                    label: trailingLabel,
                                    onTap:
                                        () => _showSettingsSheet(
                                          initialTab:
                                              _ReaderSettingsTab.reading,
                                        ),
                                    colors: colors,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildBottomProgressStrip(_ReaderThemeColors colors) {
    final progressValue = (_bottomOverlayDraftProgressRatio ??
            _currentScrollRatio())
        .clamp(0.0, 1.0);
    final canNavigateChapters = _chapters.isNotEmpty;

    return Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          splashRadius: 20,
          tooltip: '上一章',
          onPressed:
              canNavigateChapters
                  ? () =>
                      unawaited(_jumpToAdjacentReadableChapter(forward: false))
                  : null,
          icon: Icon(Icons.skip_previous_rounded, color: colors.text, size: 22),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: colors.text,
              inactiveTrackColor: colors.divider.withValues(alpha: 0.34),
              thumbColor: colors.text,
            ),
            child: Slider(
              min: 0,
              max: 1,
              divisions: 100,
              value: progressValue,
              onChanged:
                  _hasVisibleReaderContent
                      ? (value) {
                        setState(() {
                          _bottomOverlayDraftProgressRatio = value;
                        });
                      }
                      : null,
              onChangeEnd:
                  _hasVisibleReaderContent
                      ? (value) {
                        setState(() {
                          _bottomOverlayDraftProgressRatio = null;
                        });
                        final request = _navigationEntryResolver
                            .resolveProgressSelection(scrollRatio: value);
                        _restoreScrollPosition(
                          request.initialScrollRatio ?? value,
                        );
                        _syncActiveReadingRecordSessionProgress(ratio: value);
                        _scheduleProgressSave();
                      }
                      : null,
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          splashRadius: 20,
          tooltip: '下一章',
          onPressed:
              canNavigateChapters
                  ? () =>
                      unawaited(_jumpToAdjacentReadableChapter(forward: true))
                  : null,
          icon: Icon(Icons.skip_next_rounded, color: colors.text, size: 22),
        ),
      ],
    );
  }

  Widget _buildShellOverlayTransition({
    required _OverlayEdge edge,
    required Widget child,
  }) {
    final slideProgress = _overlayControlsShiftProgress;
    final fadeProgress = _overlayControlsFadeProgress;
    final translateY =
        (edge == _OverlayEdge.top ? -1 : 1) *
        (1 - slideProgress) *
        _kShellOverlayTranslateDistance;

    return Transform.translate(
      offset: Offset(0, translateY),
      child: Opacity(opacity: fadeProgress, child: child),
    );
  }

  Widget _buildTopActionButton({
    required String tooltip,
    required VoidCallback? onPressed,
    required IconData icon,
    required _ReaderThemeColors colors,
    bool loading = false,
    bool emphasizeHitArea = false,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        foregroundColor: colors.text,
        backgroundColor: Colors.transparent,
        minimumSize: emphasizeHitArea ? const Size(44, 44) : const Size(34, 34),
        visualDensity: VisualDensity.compact,
        padding: emphasizeHitArea ? const EdgeInsets.all(4) : EdgeInsets.zero,
        tapTargetSize:
            emphasizeHitArea
                ? MaterialTapTargetSize.padded
                : MaterialTapTargetSize.shrinkWrap,
      ),
      icon:
          loading
              ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.text,
                ),
              )
              : Icon(icon, size: 18),
    );
  }

  Widget _buildToolbarAction({
    required IconData icon,
    required String label,
    required Future<void> Function() onTap,
    required _ReaderThemeColors colors,
    bool active = false,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () async {
          try {
            await onTap();
          } catch (_) {
            _showMessage('操作失败，请稍后重试。');
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color:
                active
                    ? colors.background.withValues(alpha: 0.52)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: colors.text),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _chapterProgressLabel() {
    if (_currentIndex == null || _chapters.isEmpty) {
      return _bookTitle.isEmpty ? '加载章节信息中' : _bookTitle;
    }

    final chapter = _currentIndex! + 1;
    final total = _chapters.length;
    if (_bookTitle.isEmpty) {
      return '第 $chapter / $total 章';
    }

    return '$_bookTitle · 第 $chapter / $total 章';
  }

  String _toUserReadableError(AppException error) {
    final message = error.briefMessage;
    if (_isLocalContent) {
      return LocalBookWorkflowPolicy.readerLoadError(message);
    }

    return switch (error.code) {
      ErrorCode.network when message.contains('状态码：403') =>
        '章节被源站拦截（403），请在书源配置 Referer/Origin/User-Agent 后重试。',
      ErrorCode.network when message.contains('状态码：404') =>
        '章节地址已失效（404），请刷新目录后重试。',
      ErrorCode.network when message.contains('超时') => '请求超时，请稍后重试或切换书源。',
      ErrorCode.network => '网络请求失败，请检查网络或更换书源。',
      ErrorCode.validation
          when message.contains('正文') && message.contains('缺少') =>
        '书源缺少正文解析配置，无法读取该章节。',
      ErrorCode.validation => '书源配置不完整，无法继续阅读。',
      ErrorCode.ruleParse => '书源脚本语法错误，正文解析失败。',
      ErrorCode.ruleMatchEmpty when message.contains('解析为空') =>
        '正文解析未命中，当前章节暂无可读内容。',
      ErrorCode.ruleMatchEmpty => '当前章节没有可读取内容，请切换章节或书源。',
      ErrorCode.decode => '正文解析失败，可能是编码或数据格式不兼容。',
      ErrorCode.unknownSource => '书源不存在或已被删除。',
      ErrorCode.unknown => '加载失败，请稍后重试。',
    };
  }

  bool _isBookmarkInCurrentChapter(Bookmark bookmark) {
    final chapterId = _chapterId.trim();
    if (chapterId.isNotEmpty && bookmark.chapterId.trim().isNotEmpty) {
      return bookmark.chapterId.trim() == chapterId;
    }
    final index = _currentIndex;
    if (index != null) {
      return bookmark.chapterIndex == index;
    }
    return false;
  }

  Map<int, List<_BookmarkRange>> _buildBookmarkRangesByParagraph(
    List<Bookmark> bookmarks,
  ) {
    final paragraphs =
        _paragraphs.isEmpty ? <String>[_content.trim()] : _paragraphs;
    if (paragraphs.isEmpty || bookmarks.isEmpty) {
      return const <int, List<_BookmarkRange>>{};
    }

    final totalLength =
        paragraphs.fold<int>(0, (sum, item) => sum + item.length) +
        max(0, paragraphs.length - 1) * 2;

    final starts = <int>[];
    var offset = 0;
    for (final paragraph in paragraphs) {
      starts.add(offset);
      offset += paragraph.length + 2;
    }

    final result = <int, List<_BookmarkRange>>{};
    for (final bookmark in bookmarks) {
      var start = _clampInt(bookmark.startOffset, 0, totalLength);
      var end = _clampInt(bookmark.endOffset, 0, totalLength);
      if (end < start) {
        final tmp = start;
        start = end;
        end = tmp;
      }
      if (end == start) {
        continue;
      }

      var startIndex = _findParagraphIndexByOffset(starts, paragraphs, start);
      var endIndex = _findParagraphIndexByOffset(starts, paragraphs, end);

      for (var index = startIndex; index <= endIndex; index++) {
        final paragraphStart = starts[index];
        final paragraphLength = paragraphs[index].length;
        final paragraphEnd = paragraphStart + paragraphLength;
        final localStart = index == startIndex ? start - paragraphStart : 0;
        final localEnd =
            index == endIndex
                ? min(end, paragraphEnd) - paragraphStart
                : paragraphLength;
        if (localEnd <= localStart) {
          continue;
        }
        final list = result.putIfAbsent(index, () => <_BookmarkRange>[]);
        list.add(
          _BookmarkRange(
            localStart,
            localEnd,
            hasHighlight: _bookmarkHasHighlight(bookmark),
            isBold: bookmark.isBold,
            isUnderline: bookmark.isUnderline,
            isWavy: bookmark.isWavy,
          ),
        );
      }
    }

    return result;
  }

  bool _bookmarkHasHighlight(Bookmark bookmark) {
    final color = bookmark.color?.trim();
    if (color == null || color.isEmpty) {
      return !bookmark.isUnderline && !bookmark.isWavy;
    }
    return color != _kBookmarkNoHighlightToken;
  }

  int _findParagraphIndexByOffset(
    List<int> starts,
    List<String> paragraphs,
    int offset,
  ) {
    for (var i = 0; i < starts.length; i++) {
      final start = starts[i];
      final end = start + paragraphs[i].length;
      if (offset < start) {
        return max(0, i - 1);
      }
      if (offset <= end) {
        return i;
      }
    }
    return max(0, paragraphs.length - 1);
  }

  Bookmark? _currentSelectionBookmark() {
    if (!_isTextSelectionActive || _selectedSnippet.isEmpty) {
      return null;
    }
    return _findBookmarkByOffsets(_selectionStartOffset, _selectionEndOffset);
  }

  Bookmark? _findBookmarkByOffsets(int startOffset, int endOffset) {
    if (_chapterBookmarks.isEmpty) {
      return null;
    }
    for (final bookmark in _chapterBookmarks) {
      if (!_isBookmarkInCurrentChapter(bookmark)) {
        continue;
      }
      if (bookmark.startOffset == startOffset &&
          bookmark.endOffset == endOffset) {
        return bookmark;
      }
    }
    return null;
  }

  double _adaptiveReaderSheetHeightFactor(
    BuildContext context, {
    required double compact,
    required double regular,
    required double large,
  }) {
    final metrics = AppAdaptiveMetrics.of(context);
    if (metrics.isLandscape && metrics.height < 420) {
      return max(compact, 0.92);
    }
    return switch (metrics.windowClass) {
      AppWindowClass.compact => metrics.isCompactDensity ? compact : regular,
      AppWindowClass.medium => regular,
      AppWindowClass.expanded => large,
    };
  }

  Future<void> _refreshBookshelfState() async {
    final sourceId = _sourceId;
    final detailUrl = _detailUrl;
    if (sourceId == null ||
        detailUrl == null ||
        sourceId.isEmpty ||
        detailUrl.isEmpty) {
      return;
    }

    final value = await _bookshelfService.contains(
      sourceId: sourceId,
      detailUrl: detailUrl,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isInBookshelf = value;
    });
  }

  void _cancelBackgroundRefreshConflictForCurrentBook() {
    final sourceId = (_sourceId ?? '').trim();
    final detailUrl = (_detailUrl ?? '').trim();
    final bookId = _currentBookId.trim();
    final conflictKey = _taskConflictService.conflictKeyForBook(
      sourceId: sourceId,
      detailUrl: detailUrl,
      bookId: bookId,
    );
    if (conflictKey.isEmpty) {
      return;
    }
    _taskConflictService.cancelBackgroundWorkFor(
      conflictKey: conflictKey,
      byScene: SourceRuntimeConflictScene.reader,
    );
  }

  List<String> _currentConflictKeys() {
    final sourceId = (_sourceId ?? '').trim();
    final detailUrl = (_detailUrl ?? '').trim();
    final bookId = _currentBookId.trim();
    return <String>[
      _taskConflictService.conflictKeyForSource(sourceId),
      _taskConflictService.conflictKeyForBook(
        sourceId: sourceId,
        detailUrl: detailUrl,
        bookId: bookId,
      ),
    ].where((item) => item.trim().isNotEmpty).toList(growable: false);
  }

  Future<void> _toggleBookshelf() async {
    final sourceId = _sourceId;
    final detailUrl = _detailUrl;
    if (sourceId == null ||
        detailUrl == null ||
        sourceId.isEmpty ||
        detailUrl.isEmpty) {
      _showMessage('缺少书源参数，无法操作书架。');
      return;
    }

    setState(() {
      _isShelfActionLoading = true;
    });

    try {
      final wasInBookshelf = _isInBookshelf;
      if (wasInBookshelf) {
        await _bookshelfService.remove(
          sourceId: sourceId,
          detailUrl: detailUrl,
        );
      } else {
        await _bookshelfService.upsert(
          BookshelfBook(
            bookId: _currentBookId,
            sourceId: sourceId,
            title:
                _bookTitle.isNotEmpty
                    ? _bookTitle
                    : (widget.chapterTitle ?? '未命名书籍'),
            detailUrl: detailUrl,
            author: _bookAuthor,
            coverUrl: _bookCoverUrl,
            latestChapter: _latestReadableChapterTitle(_chapters),
            addedAt: DateTime.now(),
          ),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isInBookshelf = !wasInBookshelf;
      });
      _showMessage(wasInBookshelf ? '已从书架移除。' : '已加入书架。');
    } catch (_) {
      _showMessage('书架操作失败，请重试。');
    } finally {
      if (mounted) {
        setState(() {
          _isShelfActionLoading = false;
        });
      }
    }
  }

  void _openDetailPage() {
    final sourceId = _sourceId;
    final detailUrl = _detailUrl;
    if (sourceId == null ||
        detailUrl == null ||
        sourceId.isEmpty ||
        detailUrl.isEmpty) {
      _showMessage('缺少详情参数，无法打开详情页。');
      return;
    }

    final route = buildBookDetailRoute(
      bookId: _currentBookId,
      sourceId: sourceId,
      detailUrl: detailUrl,
      title:
          _bookTitle.isNotEmpty ? _bookTitle : (widget.chapterTitle ?? '书籍详情'),
      author: _bookAuthor,
      coverUrl: _bookCustomCoverPath ?? _bookCoverUrl,
    );

    context.push(route);
  }

  List<ReaderCatalogSearchEntry>? _peekCatalogSearchEntries(
    String normalizedKeyword,
  ) {
    final fingerprint = _catalogSearchService.buildCacheFingerprint(
      chapterId: _chapterId,
      chapterUrl: _chapterUrl,
      currentChapterIndex: _currentIndex,
      chapters: _chapters,
      supportsContentSearch:
          _readerModeCapabilities.supportsCatalogContentSearch,
      chapterContent: _content,
      chapterParagraphCount: _paragraphs.length,
    );
    if (_catalogSearchCacheFingerprint != fingerprint) {
      _resetCatalogSearchCache();
      _catalogSearchCacheFingerprint = fingerprint;
    }
    return _catalogSearchEntriesCache[normalizedKeyword];
  }

  int? _resolveCatalogSearchEntryTargetIndex(ReaderCatalogSearchEntry entry) {
    final request = _navigationEntryResolver.resolveCatalogSearchEntry(
      entry: ReaderCatalogSearchEntryAdapter(
        chapterIndex: entry.chapterIndex,
        targetChapterIndex: entry.targetChapterIndex,
        isVolume: entry.isVolume,
        isContent: entry.isContent,
      ),
      chapters: _chapters,
    );
    return request?.targetChapterIndex;
  }

  int? _resolveCurrentIndex(List<Chapter> chapters) {
    if (chapters.isEmpty) {
      return null;
    }

    final byId = chapters.indexWhere((chapter) => chapter.id == _chapterId);
    if (byId >= 0) {
      return _chapterNavigation.resolveNearestReadableChapterIndex(
        chapters,
        byId,
        preferForward: true,
      );
    }

    final chapterUrl = _chapterUrl;
    if (chapterUrl != null && chapterUrl.isNotEmpty) {
      final byUrl = chapters.indexWhere(
        (chapter) => chapter.chapterUrl == chapterUrl,
      );
      if (byUrl >= 0) {
        return _chapterNavigation.resolveNearestReadableChapterIndex(
          chapters,
          byUrl,
          preferForward: true,
        );
      }
    }

    final fromRoute = widget.chapterIndex;
    if (fromRoute != null && fromRoute >= 0 && fromRoute < chapters.length) {
      return _chapterNavigation.resolveNearestReadableChapterIndex(
        chapters,
        fromRoute,
        preferForward: true,
      );
    }

    return _chapterNavigation.findReadableChapterIndex(
      chapters,
      0,
      forward: true,
    );
  }

  String? _latestReadableChapterTitle(List<Chapter> chapters) {
    for (var index = chapters.length - 1; index >= 0; index--) {
      final chapter = chapters[index];
      if (_chapterNavigation.isReadableChapter(chapter)) {
        return chapter.title;
      }
    }
    return null;
  }

  void _applyReaderSettingsWithModeRestore({
    required ReaderSettings nextSettings,
    VoidCallback? beforeStateUpdate,
    bool syncVolumeKeyPageInterception = true,
  }) {
    final previousSettings = _settings;
    final shouldSyncAppThemeMode =
        nextSettings.themeMode != previousSettings.themeMode;
    final previousPagedTextEnabled = _isPagedTextReaderEnabledFor(
      previousSettings,
    );
    final nextPagedTextEnabled = _isPagedTextReaderEnabledFor(nextSettings);
    final didSwitchTextRenderMode =
        !_isMangaChapter && previousPagedTextEnabled != nextPagedTextEnabled;
    final logicalAnchor =
        didSwitchTextRenderMode ? _currentLogicalPosition() : null;
    final anchorFallbackRatio =
        didSwitchTextRenderMode ? _currentScrollRatio() : 0.0;

    setState(() {
      beforeStateUpdate?.call();
      _settings = nextSettings;
      _textPaginationFallbackDiagnostic = null;
    });
    _syncContinuousTextFlowAfterSettingsApplied();
    if (didSwitchTextRenderMode) {
      _restoreTextPositionFromLogicalAnchor(
        previousPagedTextEnabled: previousPagedTextEnabled,
        logicalAnchor: logicalAnchor,
        fallbackRatio: anchorFallbackRatio,
      );
    }
    if (syncVolumeKeyPageInterception) {
      unawaited(_syncVolumeKeyPageInterception());
    }
    unawaited(_applySystemReaderBrightness(nextSettings.brightness));
    if (shouldSyncAppThemeMode) {
      unawaited(_syncAppThemeModeWithReaderTheme(nextSettings.themeMode));
    }
  }

  void _applyProgressFallback(ReadingProgress progress) {
    if ((_sourceId ?? '').trim().isEmpty) {
      _sourceId = progress.sourceId;
    }
    if ((_detailUrl ?? '').trim().isEmpty) {
      _detailUrl = progress.detailUrl;
    }
    if (_isPlaceholderChapterId(_chapterId)) {
      _chapterId = progress.chapterId;
    }
    if ((_chapterUrl ?? '').trim().isEmpty) {
      _chapterUrl = progress.chapterUrl;
    }
    if ((_chapterTitle ?? '').trim().isEmpty) {
      _chapterTitle = progress.chapterTitle;
    }
    if (_currentIndex == null || _currentIndex! < 0) {
      _currentIndex = progress.chapterIndex;
    }
  }

  void _applyLocalSchemeFallback() {
    final sourceId = (_sourceId ?? '').trim();
    final detailUrl = (_detailUrl ?? '').trim();
    final chapterUrl = (_chapterUrl ?? '').trim();

    if (sourceId.isEmpty &&
        (LocalReaderIdentity.isLocalSchemeUrl(detailUrl) ||
            LocalReaderIdentity.isLocalSchemeUrl(chapterUrl))) {
      _sourceId = LocalReaderIdentity.localSourceId;
    }

    if (!LocalReaderIdentity.isLocalSourceId(_sourceId)) {
      return;
    }

    if (detailUrl.isEmpty || !LocalReaderIdentity.isLocalSchemeUrl(detailUrl)) {
      _detailUrl = LocalReaderIdentity.buildBookDetailUrl(_currentBookId);
    }

    final normalizedChapterId = _chapterId.trim();
    if ((chapterUrl.isEmpty ||
            !LocalReaderIdentity.isLocalSchemeUrl(chapterUrl)) &&
        normalizedChapterId.isNotEmpty &&
        !_isPlaceholderChapterId(normalizedChapterId)) {
      _chapterUrl = LocalReaderIdentity.buildChapterUrl(normalizedChapterId);
    }
  }

  String _normalizeLocalDetailUrlForProgress(String detailUrl) {
    if (!_isLocalSource) {
      return detailUrl;
    }
    final normalized = detailUrl.trim();
    if (LocalReaderIdentity.isLocalSchemeUrl(normalized)) {
      return normalized;
    }
    final bookId = _currentBookId;
    if (bookId.isEmpty) {
      return normalized;
    }
    return LocalReaderIdentity.buildBookDetailUrl(bookId);
  }

  String _normalizeLocalChapterUrlForProgress(String chapterUrl) {
    if (!_isLocalSource) {
      return chapterUrl;
    }
    final normalized = chapterUrl.trim();
    if (LocalReaderIdentity.isLocalSchemeUrl(normalized)) {
      return normalized;
    }
    final chapterId = _chapterId.trim();
    if (chapterId.isEmpty || _isPlaceholderChapterId(chapterId)) {
      return normalized;
    }
    return LocalReaderIdentity.buildChapterUrl(chapterId);
  }

  bool _isPlaceholderChapterId(String chapterId) {
    final normalized = chapterId.trim();
    return normalized.isEmpty ||
        normalized == 'bootstrap' ||
        normalized == 'unknown-chapter' ||
        normalized == 'unknown-local-chapter';
  }

  ContentCapabilities get _contentCapabilities {
    final sourceId = _sourceId?.trim();
    if (sourceId == null || sourceId.isEmpty) {
      return const ContentCapabilities();
    }
    final provider = _contentProviderRegistry.findForSourceId(sourceId);
    return provider?.capabilities ?? const ContentCapabilities();
  }

  bool get _canSwitchSource => _readerModeCapabilities.canSwitchSource;
  bool get _canCacheChapter => _readerModeCapabilities.canCacheChapter;

  String get _currentBookId {
    final normalized = _activeBookId.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
    return widget.bookId.trim();
  }

  bool get _isLocalSource => LocalReaderIdentity.isLocalSourceId(_sourceId);
  bool get _isLocalContent =>
      _isLocalSource || _contentCapabilities.canReindexLocal;

  ContentProvider _requireContentProvider({
    required String? sourceId,
    ErrorStage stage = ErrorStage.unknown,
  }) {
    final normalized = (sourceId ?? '').trim();
    if (normalized.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: stage,
        briefMessage: '缺少 sourceId，无法加载内容。',
      );
    }

    final provider = _contentProviderRegistry.findForSourceId(normalized);
    if (provider == null) {
      throw AppException(
        code: ErrorCode.unknownSource,
        stage: stage,
        briefMessage: '未找到可用的内容提供者。',
      );
    }

    return provider;
  }

  bool get _isMissingCriticalParams {
    return _sourceId == null ||
        _sourceId!.isEmpty ||
        _detailUrl == null ||
        _detailUrl!.isEmpty;
  }

  Future<void> _showSettingsSheet({
    _ReaderSettingsTab initialTab = _ReaderSettingsTab.reading,
  }) => _ReaderPageSettingsSheetExtension(
    this,
  )._showSettingsSheet(initialTab: initialTab);
  double _letterSpacingSliderValue(ReaderSettings settings) {
    return ((settings.letterSpacing * 100) + 50).clamp(0, 100).toDouble();
  }

  double _letterSpacingFromSliderValue(double sliderValue) {
    return ((((sliderValue.clamp(0, 100).toDouble()) - 50) / 100).clamp(
      ReaderSettings.minLetterSpacing,
      ReaderSettings.maxLetterSpacing,
    )).toDouble();
  }

  String _letterSpacingValueLabel(ReaderSettings settings) {
    return _formatTypographyValue(
      value: settings.letterSpacing,
      fractionDigits: 2,
    );
  }

  double _lineHeightSliderValue(ReaderSettings settings) {
    return _typographyMetricsResolver.resolveLineSpacingExtra(settings);
  }

  double _lineHeightFromSliderValue({
    required double sliderValue,
    required ReaderSettings settings,
  }) {
    final safeFontSize = settings.fontSize <= 0 ? 18.0 : settings.fontSize;
    return ((safeFontSize + sliderValue) / safeFontSize).toDouble();
  }

  String _lineHeightValueLabel(ReaderSettings settings) {
    final md3Extra = _typographyMetricsResolver.resolveLineSpacingExtra(
      settings,
    );
    return md3Extra.round().toString();
  }

  String _paragraphSpacingValueLabel(ReaderSettings settings) {
    final md3Spacing = _typographyMetricsResolver.resolveParagraphSpacingUnits(
      settings,
    );
    return md3Spacing.toStringAsFixed(1);
  }

  String _paragraphIndentValueLabel(ReaderSettings settings) {
    return switch (_typographyMetricsResolver.resolveParagraphIndentCount(
      settings,
    )) {
      0 => '无缩进',
      1 => '一字符',
      2 => '二字符',
      3 => '三字符',
      _ => '四字符',
    };
  }

  String _mangaReadModeLabel(ReaderMangaReadMode mode) {
    return switch (mode) {
      ReaderMangaReadMode.continuous => '连续长图',
      ReaderMangaReadMode.paged => '分页图',
      ReaderMangaReadMode.horizontal => '横向翻页',
    };
  }

  String _mangaLoadStrategyLabel(ReaderMangaLoadStrategy strategy) {
    return switch (strategy) {
      ReaderMangaLoadStrategy.balanced => '平衡',
      ReaderMangaLoadStrategy.smooth => '流畅优先',
      ReaderMangaLoadStrategy.saveData => '省流量',
    };
  }

  String _pageAnimationLabel(ReaderPageAnimationStyle style) =>
      _readerSettingsPresenter.pageAnimationLabel(style);

  ThemeData _readerModalTheme() {
    final mode = _effectiveReaderThemeMode();
    final baseScheme = _colorSchemeForReaderMode(mode);
    final colors = _resolveThemeColors(mode, _settings);

    Color blendOverlay(double alpha) {
      return Color.alphaBlend(
        colors.overlay.withValues(alpha: alpha),
        colors.background,
      );
    }

    final tunedScheme = baseScheme.copyWith(
      surface: blendOverlay(0.18),
      surfaceContainerLowest: blendOverlay(0.08),
      surfaceContainerLow: blendOverlay(0.14),
      surfaceContainer: blendOverlay(0.22),
      surfaceContainerHigh: blendOverlay(0.32),
      surfaceContainerHighest: blendOverlay(0.40),
      onSurface: colors.text,
      onSurfaceVariant: colors.meta,
    );
    final theme = AppTheme.build(tunedScheme);
    final bottomSheetColor = tunedScheme.surfaceContainerHigh;

    return theme.copyWith(
      bottomSheetTheme: theme.bottomSheetTheme.copyWith(
        backgroundColor: bottomSheetColor,
        modalBackgroundColor: bottomSheetColor,
        dragHandleColor: colors.divider,
      ),
      dialogTheme: theme.dialogTheme.copyWith(
        backgroundColor: tunedScheme.surface,
      ),
    );
  }

  _ReaderThemeColors _resolveThemeColors(
    ReaderThemeMode mode,
    ReaderSettings settings,
  ) {
    if (_isClassicLightReaderBackground(mode, settings)) {
      return const _ReaderThemeColors(
        background: Color(0xFFFDFDFD),
        text: Color(0xFF111827),
        meta: Color(0xFF6B7280),
        divider: Color(0xFFE5E7EB),
        overlay: Color(0xFFF7F7F7),
      );
    }

    final scheme = _colorSchemeForReaderMode(mode);

    final baseBackground = _backgroundForTone(scheme, settings.backgroundTone);
    final baseOverlay = _overlayForTone(scheme, settings.backgroundTone);

    var background = baseBackground;
    var overlay = baseOverlay;
    var textColor = scheme.onSurface;
    var metaColor = scheme.onSurfaceVariant;
    final dividerColor = scheme.outlineVariant.withValues(alpha: 0.6);

    if (mode == ReaderThemeMode.sepia) {
      const targetBackground = Color(0xFFF7EEDC);
      const targetOverlay = Color(0xFFF0E3C7);
      background =
          Color.lerp(baseBackground, targetBackground, 0.72) ??
          targetBackground;
      overlay = Color.lerp(baseOverlay, targetOverlay, 0.72) ?? targetOverlay;
      textColor = const Color(0xFF3F2E1F);
      metaColor = const Color(0xFF6E563D);
    }

    return _ReaderThemeColors(
      background: background,
      text: textColor,
      meta: metaColor,
      divider: dividerColor,
      overlay: overlay,
    );
  }

  bool _isClassicLightReaderBackground(
    ReaderThemeMode mode,
    ReaderSettings settings,
  ) {
    return mode == ReaderThemeMode.light &&
        settings.backgroundStyle == ReaderBackgroundStyle.plain &&
        settings.backgroundTone == ReaderBackgroundTone.surface;
  }

  ColorScheme _colorSchemeForReaderMode(ReaderThemeMode mode) {
    final currentScheme = Theme.of(context).colorScheme;
    final targetBrightness =
        mode == ReaderThemeMode.dark ? Brightness.dark : Brightness.light;

    if (currentScheme.brightness == targetBrightness) {
      return currentScheme;
    }

    return ColorScheme.fromSeed(
      seedColor: currentScheme.primary,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
      brightness: targetBrightness,
    );
  }

  Color _backgroundForTone(ColorScheme scheme, ReaderBackgroundTone tone) {
    final paletteSeedColor = _readerPaletteSeedColorForTone(tone);
    if (paletteSeedColor != null) {
      return _blendReaderToneColor(
        base: scheme.surface,
        tint: paletteSeedColor,
        alpha: 0.12,
      );
    }

    return switch (tone) {
      ReaderBackgroundTone.surface => scheme.surface,
      ReaderBackgroundTone.containerLow => scheme.surfaceContainerLow,
      ReaderBackgroundTone.container => scheme.surfaceContainer,
      ReaderBackgroundTone.containerHigh => scheme.surfaceContainerHigh,
      ReaderBackgroundTone.containerHighest => scheme.surfaceContainerHighest,
      ReaderBackgroundTone.pureBlack => const Color(0xFF000000),
      ReaderBackgroundTone.primaryTint => scheme.surface,
      ReaderBackgroundTone.secondaryTint => scheme.surface,
      ReaderBackgroundTone.tertiaryTint => scheme.surface,
      ReaderBackgroundTone.flameOrangeTint => scheme.surface,
      ReaderBackgroundTone.pineGreenTint => scheme.surface,
      ReaderBackgroundTone.seaBlueTint => scheme.surface,
      ReaderBackgroundTone.nightPurpleTint => scheme.surface,
      ReaderBackgroundTone.mistTealTint => scheme.surface,
      ReaderBackgroundTone.berryRoseTint => scheme.surface,
      ReaderBackgroundTone.amberGoldTint => scheme.surface,
    };
  }

  Color _overlayForTone(ColorScheme scheme, ReaderBackgroundTone tone) {
    final paletteSeedColor = _readerPaletteSeedColorForTone(tone);
    if (paletteSeedColor != null) {
      return _blendReaderToneColor(
        base: scheme.surfaceContainerLow,
        tint: paletteSeedColor,
        alpha: 0.18,
      );
    }

    return switch (tone) {
      ReaderBackgroundTone.surface => scheme.surfaceContainerLow,
      ReaderBackgroundTone.containerLow => scheme.surfaceContainer,
      ReaderBackgroundTone.container => scheme.surfaceContainerHigh,
      ReaderBackgroundTone.containerHigh => scheme.surfaceContainerHighest,
      ReaderBackgroundTone.containerHighest => scheme.surfaceContainerHighest,
      ReaderBackgroundTone.pureBlack => const Color(0xFF0A0A0A),
      ReaderBackgroundTone.primaryTint => scheme.surfaceContainerLow,
      ReaderBackgroundTone.secondaryTint => scheme.surfaceContainerLow,
      ReaderBackgroundTone.tertiaryTint => scheme.surfaceContainerLow,
      ReaderBackgroundTone.flameOrangeTint => scheme.surfaceContainerLow,
      ReaderBackgroundTone.pineGreenTint => scheme.surfaceContainerLow,
      ReaderBackgroundTone.seaBlueTint => scheme.surfaceContainerLow,
      ReaderBackgroundTone.nightPurpleTint => scheme.surfaceContainerLow,
      ReaderBackgroundTone.mistTealTint => scheme.surfaceContainerLow,
      ReaderBackgroundTone.berryRoseTint => scheme.surfaceContainerLow,
      ReaderBackgroundTone.amberGoldTint => scheme.surfaceContainerLow,
    };
  }

  Color _blendReaderToneColor({
    required Color base,
    required Color tint,
    required double alpha,
  }) {
    return Color.alphaBlend(tint.withValues(alpha: alpha), base);
  }

  Color _shiftLightness(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final shifted = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(shifted).toColor();
  }
}

class _ReaderSourceSnapshot {
  const _ReaderSourceSnapshot({
    required this.contentSession,
    required this.errorText,
    required this.isInBookshelf,
    required this.isCurrentChapterCached,
    required this.content,
    required this.chapterImageUrls,
    required this.chapterImageHeaders,
    required this.scrollRatio,
  });

  final ReaderContentSession? contentSession;
  final String? errorText;
  final bool isInBookshelf;
  final bool isCurrentChapterCached;
  final String content;
  final List<String> chapterImageUrls;
  final Map<String, String> chapterImageHeaders;
  final double scrollRatio;

  String get bookId => contentSession?.bookId ?? '';
  String? get sourceId => contentSession?.sourceId;
  String? get detailUrl => contentSession?.detailUrl;
  String get bookTitle => contentSession?.bookTitle ?? '';
  String? get bookAuthor => contentSession?.bookAuthor;
  String? get bookCoverUrl => contentSession?.bookCoverUrl;
  List<Chapter> get chapters => contentSession?.chapters ?? const <Chapter>[];
  int? get currentIndex => contentSession?.chapterIndex;
  String get chapterId => contentSession?.chapterId ?? '';
  String? get chapterUrl => contentSession?.chapterUrl;
  String? get chapterTitle => contentSession?.chapterTitle;
}

class _ChapterLoadSnapshot {
  const _ChapterLoadSnapshot({required this.result, required this.isCached});

  final ChapterContentResult result;
  final bool isCached;
}

class _ContinuousTextChapter {
  const _ContinuousTextChapter({
    required this.chapterId,
    required this.chapterUrl,
    required this.chapterTitle,
    required this.displayTitle,
    required this.chapterIndex,
    required this.content,
    required this.document,
    required this.paragraphs,
    required this.isCached,
  });

  final String chapterId;
  final String chapterUrl;
  final String chapterTitle;
  final String displayTitle;
  final int chapterIndex;
  final String content;
  final ReaderDocument document;
  final List<String> paragraphs;
  final bool isCached;
}

class _ContinuousTextChapterLayout {
  const _ContinuousTextChapterLayout({
    required this.startOffset,
    required this.endOffset,
  });

  final double startOffset;
  final double endOffset;
}

class _ScrollEdgeAdvanceState {
  const _ScrollEdgeAdvanceState({
    this.overscrollDistance = 0,
    this.isArmed = false,
    this.actionDirection = 0,
  });

  final double overscrollDistance;
  final bool isArmed;
  final int actionDirection;

  _ScrollEdgeAdvanceState copyWith({
    double? overscrollDistance,
    bool? isArmed,
    int? actionDirection,
  }) {
    return _ScrollEdgeAdvanceState(
      overscrollDistance: overscrollDistance ?? this.overscrollDistance,
      isArmed: isArmed ?? this.isArmed,
      actionDirection: actionDirection ?? this.actionDirection,
    );
  }
}

class _ReaderThemeColors {
  const _ReaderThemeColors({
    required this.background,
    required this.text,
    required this.meta,
    required this.divider,
    required this.overlay,
  });

  final Color background;
  final Color text;
  final Color meta;
  final Color divider;
  final Color overlay;
}

class _ReaderBackgroundColorOption {
  const _ReaderBackgroundColorOption({
    required this.label,
    required this.previewColor,
    required this.mode,
    required this.backgroundStyle,
    required this.backgroundTone,
  });

  final String label;
  final Color previewColor;
  final ReaderThemeMode mode;
  final ReaderBackgroundStyle backgroundStyle;
  final ReaderBackgroundTone backgroundTone;
}

class _ReaderBackgroundPreset {
  const _ReaderBackgroundPreset({required this.label, required this.assetPath});

  final String label;
  final String assetPath;
}

class _ReaderSizeReporter extends StatefulWidget {
  const _ReaderSizeReporter({required this.child, required this.onSizeChanged});

  final Widget child;
  final ValueChanged<Size> onSizeChanged;

  @override
  State<_ReaderSizeReporter> createState() => _ReaderSizeReporterState();
}

class _ReaderSizeReporterState extends State<_ReaderSizeReporter> {
  Size? _lastSize;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final renderBox = context.findRenderObject();
      if (renderBox is! RenderBox || !renderBox.hasSize) {
        return;
      }
      final size = renderBox.size;
      if (_lastSize != null &&
          (_lastSize!.width - size.width).abs() < 0.5 &&
          (_lastSize!.height - size.height).abs() < 0.5) {
        return;
      }
      _lastSize = size;
      widget.onSizeChanged(size);
    });
    return widget.child;
  }
}

class _CurlTransitionState {
  const _CurlTransitionState({
    this.isAnimating = false,
    this.isPreview = false,
    this.direction = 1,
    this.fromIndex = 0,
    this.toIndex = 0,
    this.previewProgress = 0,
    this.commitOnAnimationEnd = true,
    this.isCrossChapter = false,
  });

  final bool isAnimating;
  final bool isPreview;
  final int direction;
  final int fromIndex;
  final int toIndex;
  final double previewProgress;
  final bool commitOnAnimationEnd;
  final bool isCrossChapter;

  _CurlTransitionState copyWith({
    bool? isAnimating,
    bool? isPreview,
    int? direction,
    int? fromIndex,
    int? toIndex,
    double? previewProgress,
    bool? commitOnAnimationEnd,
    bool? isCrossChapter,
  }) {
    return _CurlTransitionState(
      isAnimating: isAnimating ?? this.isAnimating,
      isPreview: isPreview ?? this.isPreview,
      direction: direction ?? this.direction,
      fromIndex: fromIndex ?? this.fromIndex,
      toIndex: toIndex ?? this.toIndex,
      previewProgress: previewProgress ?? this.previewProgress,
      commitOnAnimationEnd: commitOnAnimationEnd ?? this.commitOnAnimationEnd,
      isCrossChapter: isCrossChapter ?? this.isCrossChapter,
    );
  }
}

class _BookmarkRange {
  const _BookmarkRange(
    this.start,
    this.end, {
    required this.hasHighlight,
    required this.isBold,
    required this.isUnderline,
    required this.isWavy,
  });

  final int start;
  final int end;
  final bool hasHighlight;
  final bool isBold;
  final bool isUnderline;
  final bool isWavy;
}

class _ReaderInspirationSelectionState {
  const _ReaderInspirationSelectionState({
    required this.hasSelection,
    required this.existingBookmark,
    required this.isHighlight,
    required this.isBold,
    required this.isUnderline,
    required this.isWavy,
  });

  final bool hasSelection;
  final Bookmark? existingBookmark;
  final bool isHighlight;
  final bool isBold;
  final bool isUnderline;
  final bool isWavy;

  bool get hasExistingBookmark => existingBookmark != null;
}

class _ReaderInspirationActionItem {
  const _ReaderInspirationActionItem({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isActive;
}

class _ReaderInspirationActionChip extends StatelessWidget {
  const _ReaderInspirationActionChip({
    required this.action,
    required this.colorScheme,
  });

  final _ReaderInspirationActionItem action;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor =
        action.isActive
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerLow;
    final foregroundColor =
        action.isActive
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurface;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: action.onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 18, color: foregroundColor),
              const SizedBox(width: 6),
              Text(
                action.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DecodedDataUriImage {
  const _DecodedDataUriImage({
    required this.mediaType,
    required this.bytes,
    required this.text,
  });

  final String mediaType;
  final Uint8List bytes;
  final String text;
}

class _ResolvedReaderBackgroundVisual {
  const _ResolvedReaderBackgroundVisual({
    required this.imageProvider,
    required this.fit,
    required this.opacity,
    required this.blurSigma,
    required this.overlayOpacity,
  });

  final ImageProvider imageProvider;
  final BoxFit fit;
  final double opacity;
  final double blurSigma;
  final double overlayOpacity;
}

class _ReaderSurfaceReserves {
  const _ReaderSurfaceReserves({
    required this.scrollBottomReserve,
    required this.pagedHeaderReserve,
    required this.pagedBottomReserve,
  });

  final double scrollBottomReserve;
  final double pagedHeaderReserve;
  final double pagedBottomReserve;
}
