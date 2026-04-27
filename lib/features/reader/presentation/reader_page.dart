import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
import '../../../app/platform/app_input_focus_behavior.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../app/theme/app_theme_provider.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/switch_source_candidate_sheet.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/media/image_selection_service.dart';
import '../../../domain/entities/app_advanced_theme.dart';
import '../../../domain/entities/bookmark.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reader_document.dart';
import '../../../domain/entities/reader_settings.dart';
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
import '../application/reader_animation_policy.dart';
import '../application/reader_cache_feedback_resolver.dart';
import '../application/reader_content_session.dart';
import '../application/reader_content_mode_resolver.dart';
import '../application/reader_content_session_resolver.dart';
import '../application/reader_mode_capabilities.dart';
import '../application/reader_catalog_search_service.dart';
import '../application/reader_chapter_cache_decoder.dart';
import '../application/reader_chapter_load_planner.dart';
import '../application/reader_chapter_flow.dart';
import '../application/reader_chapter_navigation.dart';
import '../application/reader_document_render_model.dart';
import '../application/reader_font_registry_service.dart';
import '../application/reader_jump_facade.dart';
import '../application/reader_jump_planner.dart';
import '../application/reader_layout_resolver.dart';
import '../application/reader_navigation_entry_resolver.dart';
import '../application/reader_pagination_cache_service.dart';
import '../application/reader_pagination_engine.dart';
import '../application/reader_pagination_models.dart';
import '../application/reader_pagination_spec.dart';
import '../application/reader_settings_groups.dart';
import '../application/reader_settings_preset_service.dart';
import '../application/reader_surface_policy_resolver.dart';
import '../application/reader_surface_metrics.dart';
import '../application/reader_logical_position.dart';
import '../application/reader_preferences_service.dart';
import '../application/reader_session_state.dart';
import '../application/reader_session_state_resolver.dart';
import '../application/reader_source_switch_coordinator.dart';
import '../application/reader_source_switch_target_resolver.dart';
import '../application/reader_reading_record_coordinator.dart';
import '../application/reader_screen_brightness_bridge.dart';
import '../application/reading_record_service.dart';
import '../application/reader_error_center_service.dart';
import '../application/reader_system_settings_service.dart';
import '../application/reader_typography_resolver.dart';
import '../application/reader_typography_metrics_resolver.dart';
import '../application/text_reader_renderer.dart';
import '../application/reader_volume_key_page_bridge.dart';
import '../application/source_switch_score_service.dart';
import '../application/switch_source_shared.dart';
import '../application/local/local_book_workflow_policy.dart';
import '../application/local/local_book_storage_service.dart';
import '../application/reader_cached_chapter_store.dart';
import '../application/reader_dependencies_provider.dart';
import 'chapter_cache_sheets.dart';
import 'paged_animation/curl_paged_animation_renderer.dart';
import 'paged_animation/paged_animation_renderer_registry.dart';
import 'reader_catalog_sheet.dart';
import 'reader_annotated_text.dart';
import 'reader_annotation_interaction.dart';
import 'reader_body_region.dart';
import 'reader_chrome_widgets.dart';
import 'reader_content_loading_controller.dart';
import 'reader_content_loading_presenter.dart';
import 'reader_manga_view.dart';
import 'reader_selection_state.dart';
import 'reader_settings_sheet.dart';
import 'reader_shell.dart';
import 'reader_source_switch_controller.dart';
import 'reader_text_offset_mapper.dart' as text_offset_mapper;
import 'reader_text_block_presentation.dart';
import 'reader_text_paged_view.dart';
import 'reader_text_scroll_view.dart';

part 'reader_page_content_loading.dart';
part 'reader_page_selection.dart';
part 'reader_page_bootstrap.dart';
part 'reader_page_navigation.dart';
part 'reader_page_runtime.dart';
part 'reader_page_shell.dart';
part 'reader_page_source_switch.dart';

enum _ReaderSettingsTab { interface, reading }

enum _ReaderViewportKind { textPaged, textScroll, mangaPaged, mangaContinuous }

enum _OverlayEdge { top, bottom }

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
  });

  final String bookId;
  final String chapterId;
  final String? chapterUrl;
  final String? chapterTitle;
  final String? sourceId;
  final String? detailUrl;
  final int? chapterIndex;
  final String? bookmarkId;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const String _kBookmarkNoHighlightToken = '__none__';
  static const String _kBookmarkDefaultHighlightToken = '__highlight__';

  late final ContentProviderRegistry _contentProviderRegistry;
  late final ReaderPreferencesService _preferencesService;
  late final ReaderFontRegistryService _fontRegistryService;
  final ReaderTypographyResolver _typographyResolver =
      const ReaderTypographyResolver();
  final ReaderTypographyMetricsResolver _typographyMetricsResolver =
      const ReaderTypographyMetricsResolver();
  final ReaderAutoReadCoordinator _autoReadCoordinator =
      const ReaderAutoReadCoordinator();
  final ReaderAnimationPolicyResolver _animationPolicyResolver =
      const ReaderAnimationPolicyResolver();
  final ReaderCacheFeedbackResolver _readerCacheFeedbackResolver =
      const ReaderCacheFeedbackResolver();
  final ReaderContentLoadingController _contentLoadingController =
      const ReaderContentLoadingController();
  final ReaderContentLoadingPresenter _contentLoadingPresenter =
      const ReaderContentLoadingPresenter();
  final ReaderContentModeResolver _contentModeResolver =
      const ReaderContentModeResolver();
  final ReaderModeCapabilitiesResolver _modeCapabilitiesResolver =
      const ReaderModeCapabilitiesResolver();
  final ReaderChapterCacheDecoder _chapterCacheDecoder =
      const ReaderChapterCacheDecoder();
  final ReaderChapterLoadPlanner _chapterLoadPlanner =
      const ReaderChapterLoadPlanner();
  final ReaderChapterFlow _chapterFlow = const ReaderChapterFlow();
  final ReaderChapterNavigation _chapterNavigation =
      const ReaderChapterNavigation();
  final ReaderJumpFacade _jumpFacade = const ReaderJumpFacade();
  final ReaderJumpPlanner _jumpPlanner = const ReaderJumpPlanner();
  final ReaderNavigationEntryResolver _navigationEntryResolver =
      const ReaderNavigationEntryResolver();
  final ReaderLayoutResolver _layoutResolver = const ReaderLayoutResolver();
  final ReaderPaginationEngine _paginationEngine =
      const ReaderPaginationEngine();
  late final ReaderPaginationCacheService _paginationCacheService;
  final ReaderPaginationSpecResolver _paginationSpecResolver =
      const ReaderPaginationSpecResolver();
  final ReaderSurfacePolicyResolver _surfacePolicyResolver =
      const ReaderSurfacePolicyResolver();
  final PagedTransitionController _pagedTransitionLogic =
      const PagedTransitionController();
  final PagedAnimationRendererRegistry _pagedAnimationRendererRegistry =
      const PagedAnimationRendererRegistry();
  final CurlPagedAnimationRenderer _curlPagedAnimationRenderer =
      const CurlPagedAnimationRenderer();
  final ReaderCatalogSearchService _catalogSearchService =
      const ReaderCatalogSearchService();
  final ReaderReadingRecordCoordinator _readingRecordCoordinator =
      const ReaderReadingRecordCoordinator();
  final ReaderScreenBrightnessBridge _screenBrightnessBridge =
      ReaderScreenBrightnessBridge.instance;
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
  final ScrollController _scrollController = ScrollController();
  final PageController _mangaPageController = PageController();
  final GlobalKey _readerBodyKey = GlobalKey();
  final GlobalKey<SelectionAreaState> _selectionAreaKey =
      GlobalKey<SelectionAreaState>();
  final SelectionListenerNotifier _selectionNotifier =
      SelectionListenerNotifier();
  late final BookmarkRepository _bookmarkRepository;
  late final BookMetadataOverrideRepository _bookMetadataOverrideRepository;
  late final LocalBookRepository _localBookRepository;
  late final ReaderCachedChapterStore _cachedChapterStore;
  final BookMetadataPresentationResolver _bookMetadataPresentationResolver =
      const BookMetadataPresentationResolver();
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
  Timer? _readingRecordAutoCommitTimer;
  DateTime? _lastReaderSnackAt;
  String? _lastReaderSnackKey;
  StreamSubscription<ReaderVolumeKeyEvent>? _volumeKeyEventSubscription;
  final Battery _battery = Battery();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  DateTime _readerInfoNow = DateTime.now();
  int? _readerBatteryLevel;
  bool _readerBatteryReadFailed = false;
  bool _isSystemBrightnessOverrideActive = false;
  Future<bool>? _iosSimulatorCheck;
  int _autoReadTaskToken = 0;
  int _chapterContentRequestToken = 0;
  int _preloadTaskToken = 0;
  bool _isAutoReadRunning = false;
  bool _isAutoReadSessionEnabled = false;
  bool _isAutoReadAdvancingChapter = false;
  _ScrollEdgeAdvanceState _scrollEdgeAdvanceState =
      const _ScrollEdgeAdvanceState();
  double? _swipeDragStartDx;
  double? _swipeDragCurrentDx;
  int? _tapPointerId;
  Offset? _tapPointerDownPosition;
  DateTime? _tapPointerDownTime;
  bool _tapPointerMoved = false;
  bool _suppressNextReaderTap = false;
  DateTime? _lastBackNavigationAt;
  OverlayEntry? _bookmarkToolbarEntry;
  ReaderPageTurnMode _pageTurnModeBeforeAutoRead =
      ReaderPageTurnMode.tapAndSwipe;
  List<String> _customBackgroundImages = const [];
  List<int> _recentBodyTextColors = const [];
  String? _lightModeBackgroundImageBackup;
  String? _cachedBackgroundImageKey;
  MemoryImage? _cachedBackgroundImage;
  double? _bottomOverlayDraftProgressRatio;
  List<List<ReaderPagedSlice>> _pagedPages = const [];
  int _currentPageIndex = 0;
  ReaderPaginationSessionState _pagedPaginationState =
      const ReaderPaginationSessionState();
  int _paginationTaskId = 0;
  ReaderPaginationSpec? _lastPaginationSpec;
  bool _showChapterLoadingIndicator = false;
  bool _showBlockingLoadingCard = false;
  double? _measuredPinnedChapterHeaderWidth;
  PagedTransitionState _pagedTransition = PagedTransitionController.idleState;
  _CurlTransitionState _curlTransition = const _CurlTransitionState();
  bool _isSystemUiVisible = true;
  bool _isVolumeKeyPageInterceptionEnabled = false;
  ProviderSubscription<ThemeMode>? _appThemeModeSubscription;
  late final AnimationController _overlayControlsController;
  late final AnimationController _pagedTransitionController;
  late final AnimationController _curlAutoTurnController;
  ReaderReadingRecordSession? _activeReadingRecordSession;
  final Map<String, Uint8List> _backgroundPresetBytes = <String, Uint8List>{};
  final Map<String, String> _backgroundPresetBase64 = <String, String>{};
  final Map<String, Uint8List> _customBackgroundPreviewBytes =
      <String, Uint8List>{};
  final List<_ReaderBackgroundPreset> _backgroundPresets =
      <_ReaderBackgroundPreset>[];
  String? _catalogSearchCacheFingerprint;
  Map<String, List<ReaderCatalogSearchEntry>> _catalogSearchEntriesCache =
      const <String, List<ReaderCatalogSearchEntry>>{};
  final Map<String, GlobalKey> _continuousTextChapterKeys =
      <String, GlobalKey>{};
  List<_ContinuousTextChapter> _continuousTextChapters =
      const <_ContinuousTextChapter>[];

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
  static const double _kSystemBackGestureGuardMin = 44;
  static const double _kSystemBackGestureGuardRatio = 0.06;
  static const Duration _kBackNavigationInteractionCooldown = Duration(
    milliseconds: 520,
  );
  static const double _kCurlPreviewStartThreshold = 8;
  static const double _kOverlayScrimMaxAlpha = 0.14;
  static const Duration _kOverlayControlsShowDuration = Duration(
    milliseconds: 280,
  );
  static const Duration _kOverlayControlsHideDuration = Duration(
    milliseconds: 220,
  );
  static const double _kShellOverlayTranslateDistance = 18;
  static const double _kShellOverlayCollapsedScale = 0.985;
  static const Duration _kCurlAutoTurnDuration = Duration(milliseconds: 560);
  static const Duration _kPagedScrollTurnDuration = Duration(milliseconds: 300);
  static const Duration _kMangaPagedTurnDuration = Duration(milliseconds: 320);
  static const Duration _kAutoReadStepDuration = Duration(milliseconds: 520);
  static const Duration _kAutoReadResumeDelay = Duration(milliseconds: 420);
  static const Duration _kChapterLoadingIndicatorDelay = Duration(
    milliseconds: 260,
  );
  static const Duration _kBlockingLoadingCardDelay = Duration(
    milliseconds: 520,
  );
  static const Duration _kReaderSnackDuration = Duration(milliseconds: 1800);
  static const Duration _kReaderBoundarySnackDuration = Duration(
    milliseconds: 1200,
  );
  static const Duration _kReaderSnackActionDuration = Duration(
    milliseconds: 2600,
  );
  static const Duration _kReaderSnackDedupWindow = Duration(milliseconds: 900);
  static const Duration _kReadingRecordAutoCommitInterval = Duration(
    minutes: 2,
  );
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
  bool get _isPagedTransitionAnimating => _pagedTransition.isAnimating;
  bool _pageTurnIncludesTap(ReaderPageTurnMode mode) {
    return mode == ReaderPageTurnMode.tap ||
        mode == ReaderPageTurnMode.tapAndSwipe ||
        mode == ReaderPageTurnMode.tapAndScroll;
  }

  bool _pageTurnIncludesSwipe(ReaderPageTurnMode mode) {
    return mode == ReaderPageTurnMode.swipe ||
        mode == ReaderPageTurnMode.tapAndSwipe;
  }

  bool _pageTurnUsesScroll(ReaderPageTurnMode mode) {
    return mode == ReaderPageTurnMode.scroll ||
        mode == ReaderPageTurnMode.tapAndScroll;
  }

  bool get _shouldUseContinuousTextFlow => _isTextScrollViewport;

  ReaderPageTurnMode _composePageTurnMode({
    required bool tapEnabled,
    required bool swipeEnabled,
    required bool scrollEnabled,
  }) {
    if (scrollEnabled) {
      return tapEnabled
          ? ReaderPageTurnMode.tapAndScroll
          : ReaderPageTurnMode.scroll;
    }
    if (swipeEnabled) {
      return tapEnabled
          ? ReaderPageTurnMode.tapAndSwipe
          : ReaderPageTurnMode.swipe;
    }
    return ReaderPageTurnMode.tap;
  }

  ReaderPageTurnMode _applyPageTurnToggle(
    ReaderPageTurnMode current, {
    bool? tapEnabled,
    bool? swipeEnabled,
    bool? scrollEnabled,
  }) {
    var nextTapEnabled = _pageTurnIncludesTap(current);
    var nextSwipeEnabled = _pageTurnIncludesSwipe(current);
    var nextScrollEnabled = _pageTurnUsesScroll(current);

    if (tapEnabled != null) {
      nextTapEnabled = tapEnabled;
    }
    if (swipeEnabled != null) {
      nextSwipeEnabled = swipeEnabled;
      if (nextSwipeEnabled) {
        nextScrollEnabled = false;
      }
    }
    if (scrollEnabled != null) {
      nextScrollEnabled = scrollEnabled;
      if (nextScrollEnabled) {
        nextSwipeEnabled = false;
      }
    }

    if (nextSwipeEnabled && nextScrollEnabled) {
      nextScrollEnabled = false;
    }
    if (!nextTapEnabled && !nextSwipeEnabled && !nextScrollEnabled) {
      nextTapEnabled = true;
    }

    return _composePageTurnMode(
      tapEnabled: nextTapEnabled,
      swipeEnabled: nextSwipeEnabled,
      scrollEnabled: nextScrollEnabled,
    );
  }

  TextAlign _paragraphTextAlign(ReaderSettings settings) {
    return settings.textFullJustifyEnabled
        ? TextAlign.justify
        : TextAlign.start;
  }

  bool _isPagedTextReaderEnabledFor(ReaderSettings settings) {
    if (!_readerModeCapabilities.canUsePagedText) {
      return false;
    }
    return !_pageTurnUsesScroll(settings.pageTurnMode);
  }

  bool _isPagedTextReaderEnabled() {
    return _isPagedTextReaderEnabledFor(_settings);
  }

  TextReaderRenderer get _activeTextRenderer =>
      _isPagedTextReaderEnabled() ? _pagedTextRenderer : _scrollTextRenderer;

  ReaderRenderMetrics _currentTextRenderMetrics() {
    if (_isPagedTextReaderEnabled()) {
      return ReaderRenderMetrics(
        pageCount: _pagedPages.length,
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
    return _currentViewportKind == _ReaderViewportKind.textPaged &&
        _pageTurnIncludesSwipe(_settings.pageTurnMode);
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

  _ReaderViewportKind get _currentViewportKind {
    if (_isMangaChapter) {
      return _isMangaPagedMode
          ? _ReaderViewportKind.mangaPaged
          : _ReaderViewportKind.mangaContinuous;
    }
    return _isPagedTextReaderEnabled()
        ? _ReaderViewportKind.textPaged
        : _ReaderViewportKind.textScroll;
  }

  bool get _isTextPagedViewport =>
      _currentViewportKind == _ReaderViewportKind.textPaged;

  bool get _isTextScrollViewport =>
      _currentViewportKind == _ReaderViewportKind.textScroll;

  bool get _isMangaViewport =>
      _currentViewportKind == _ReaderViewportKind.mangaPaged ||
      _currentViewportKind == _ReaderViewportKind.mangaContinuous;

  ReaderModeCapabilities get _readerModeCapabilities =>
      _modeCapabilitiesResolver.resolve(
        contentMode: _currentContentMode,
        contentCapabilities: _contentCapabilities,
        hasInlineImageParagraphs: _currentChapterHasInlineImageParagraphs(),
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

  bool _showsOuterPinnedChapterHeaderFor(_ReaderViewportKind viewportKind) {
    return viewportKind != _ReaderViewportKind.textPaged &&
        _layoutResolver.showsPinnedChapterHeader(_settings);
  }

  bool _showsPagedPinnedChapterHeaderFor(_ReaderViewportKind viewportKind) {
    return viewportKind == _ReaderViewportKind.textPaged &&
        _layoutResolver.showsPinnedChapterHeader(_settings);
  }

  bool _showsOuterInfoBarsFor(_ReaderViewportKind viewportKind) {
    return viewportKind == _ReaderViewportKind.textScroll;
  }

  bool _showsPagedHeaderInfoBarFor(_ReaderViewportKind viewportKind) {
    return false;
  }

  bool get _hasReaderInfoItems =>
      _settings.infoShowProgress ||
      _settings.infoShowTime ||
      _settings.infoShowBattery ||
      _settings.infoShowChapter;

  bool _showsOuterFooterInfoBarFor(_ReaderViewportKind viewportKind) {
    return _showsOuterInfoBarsFor(viewportKind) &&
        (_settings.infoFooterEnabled ||
            (!_settings.infoHeaderEnabled &&
                !_settings.infoFooterEnabled &&
                _hasReaderInfoItems));
  }

  bool _reservesPinnedHeaderSpaceFor(_ReaderViewportKind viewportKind) {
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
    _ReaderViewportKind? viewportKind,
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
    _ReaderViewportKind? viewportKind,
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
    required Widget child,
  }) {
    final floatingColor = readerModalTheme.colorScheme.surface.withValues(
      alpha: 0.9,
    );
    final borderColor = readerModalTheme.colorScheme.outlineVariant.withValues(
      alpha: 0.35,
    );
    final useEdgeToEdgeSheet = MediaQuery.sizeOf(context).width < 840;
    final radius = useEdgeToEdgeSheet ? 24.0 : 28.0;
    final horizontalInset = useEdgeToEdgeSheet ? 8.0 : sheetHorizontal;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(
        left: horizontalInset,
        right: horizontalInset,
        top: useEdgeToEdgeSheet ? 0 : 48,
        bottom:
            keyboardInset +
            (useEdgeToEdgeSheet ? 0 : max(12.0, safeBottom * 0.55)),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: heightFactor,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: useEdgeToEdgeSheet ? double.infinity : maxWidth,
            ),
            child: ClipRRect(
              borderRadius:
                  useEdgeToEdgeSheet
                      ? BorderRadius.vertical(top: Radius.circular(radius))
                      : BorderRadius.circular(radius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: floatingColor,
                    borderRadius:
                        useEdgeToEdgeSheet
                            ? BorderRadius.vertical(
                              top: Radius.circular(radius),
                            )
                            : BorderRadius.circular(radius),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 28,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

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
    return _hasReaderInfoItems;
  }

  String _formatLayoutMarginValue(double value) {
    final normalized = value.clamp(
      ReaderSettings.minLayoutMargin,
      ReaderSettings.maxLayoutMargin,
    );
    final rounded = normalized.roundToDouble();
    if ((normalized - rounded).abs() < 0.001) {
      return rounded.toInt().toString();
    }
    return normalized.toStringAsFixed(1);
  }

  void _bindDependencies() {
    final dependenciesFactory = ref.read(
      readerFeatureDependenciesFactoryProvider,
    );
    final dependencies = dependenciesFactory();
    _contentProviderRegistry = dependencies.contentProviderRegistry;
    _preferencesService = dependencies.preferencesService;
    _fontRegistryService = dependencies.fontRegistryService;
    _paginationCacheService = dependencies.paginationCacheService;
    _systemSettingsService = dependencies.systemSettingsService;
    _readerBackgroundService = dependencies.readerBackgroundService;
    _localBookStorageService = dependencies.localBookStorageService;
    _readerErrorCenterService = dependencies.readerErrorCenterService;
    _readingRecordService = dependencies.readingRecordService;
    _imageSelectionService = dependencies.imageSelectionService;
    _bookshelfService = dependencies.bookshelfService;
    _switchSourceSearchService = dependencies.switchSourceSearchService;
    _searchHitCacheService = dependencies.searchHitCacheService;
    _sourceHealthService = dependencies.sourceHealthService;
    _sourceRuntimeFacade = dependencies.sourceRuntimeFacade;
    _taskConflictService = dependencies.taskConflictService;
    _taskScheduler = dependencies.taskScheduler;
    _bookmarkRepository = dependencies.bookmarkRepository;
    _bookMetadataOverrideRepository =
        dependencies.bookMetadataOverrideRepository;
    _localBookRepository = dependencies.localBookRepository;
    _cachedChapterStore = dependencies.cachedChapterStore;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bindDependencies();
    _chapterId = widget.chapterId;
    _chapterUrl = widget.chapterUrl?.trim();
    _chapterTitle = widget.chapterTitle?.trim();
    _sourceId = widget.sourceId?.trim();
    _detailUrl = widget.detailUrl?.trim();
    _activeBookId = widget.bookId.trim();
    _cancelBackgroundRefreshConflictForCurrentBook();
    _bookTitle = widget.chapterTitle?.trim() ?? '';
    _currentIndex = widget.chapterIndex;
    final incomingBookmarkId = widget.bookmarkId?.trim() ?? '';
    if (incomingBookmarkId.isNotEmpty) {
      _pendingBookmarkId = incomingBookmarkId;
    }
    _overlayControlsController = AnimationController(
      vsync: this,
      duration: _kOverlayControlsShowDuration,
      reverseDuration: _kOverlayControlsHideDuration,
      value: _showOverlayControls ? 1 : 0,
    );
    _pagedTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pagedTransitionController.addStatusListener(_onPagedTransitionStatus);
    _curlAutoTurnController = AnimationController(
      vsync: this,
      duration: _kCurlAutoTurnDuration,
    );
    _curlAutoTurnController.addStatusListener(_onCurlAutoTurnStatus);
    _scrollController.addListener(_onScrollChanged);
    _selectionNotifier.addListener(_handleSelectionNotifierChanged);
    _appThemeModeSubscription = ref.listenManual<ThemeMode>(
      appThemeModeProvider,
      (previous, next) {
        unawaited(_syncReaderThemeModeWithAppTheme(next));
      },
    );
    if (ReaderVolumeKeyPageBridge.instance.isSupported) {
      _volumeKeyEventSubscription = ReaderVolumeKeyPageBridge.instance.events
          .listen(
            (event) => unawaited(_handleVolumeKeyEvent(event)),
            onError: (_) {},
          );
    }
    unawaited(_syncVolumeKeyPageInterception());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncSystemUiVisibility(force: true);
    });
    unawaited(_refreshReaderInfoSnapshot(force: true));
    _readerInfoClockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) {
        return;
      }
      unawaited(_refreshReaderInfoSnapshot());
    });

    _bootstrap();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    final appThemeMode = ref.read(appThemeModeProvider);
    if (appThemeMode != ThemeMode.system) {
      return;
    }
    unawaited(_syncReaderThemeModeWithAppTheme(appThemeMode));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appThemeModeSubscription?.close();
    _appThemeModeSubscription = null;
    _cancelActiveSwitchSourceSearch();
    _chapterContentRequestToken += 1;
    final sourceId = (_sourceId ?? '').trim();
    if (sourceId.isNotEmpty) {
      _sourceRuntimeFacade.clearReadingFlow(
        sourceId: sourceId,
        detailUrl: (_detailUrl ?? '').trim(),
        title: _bookTitle.trim(),
      );
    }
    _commitReadingRecordSession();
    _syncSystemUiVisibility(force: true, visible: true);
    unawaited(_restoreSystemReaderBrightness());
    _overlayControlsController.stop();
    _pagedTransitionController.stop();
    _curlAutoTurnController.stop();
    _pagedTransition = PagedTransitionController.idleState;
    _curlTransition = const _CurlTransitionState();
    _progressDebounceTimer?.cancel();
    _autoReadResumeTimer?.cancel();
    _readerInfoClockTimer?.cancel();
    _chapterLoadingIndicatorTimer?.cancel();
    _blockingLoadingCardTimer?.cancel();
    _readingRecordAutoCommitTimer?.cancel();
    _volumeKeyEventSubscription?.cancel();
    _volumeKeyEventSubscription = null;
    _scrollController.removeListener(_onScrollChanged);
    _selectionNotifier.removeListener(_handleSelectionNotifierChanged);
    _selectionNotifier.dispose();
    unawaited(_setVolumeKeyPageInterceptionEnabled(false));
    _stopAutoRead();
    _scrollController.dispose();
    _mangaPageController.dispose();
    _disposeMangaTransformControllers();
    _overlayControlsController.dispose();
    _pagedTransitionController.dispose();
    _curlAutoTurnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _resolveThemeColors(_effectiveReaderThemeMode(), _settings);
    final canPopRoute = context.canPop();

    return PopScope<void>(
      canPop: canPopRoute,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !mounted) {
          return;
        }
        context.go('/bookshelf');
      },
      child: Builder(
        builder: (context) {
          final shellSession =
              _currentContentSession() ??
              ReaderContentSession(
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
              );
          final viewportKind = switch (_currentViewportKind) {
            _ReaderViewportKind.textPaged =>
              ReaderPresentationViewportKind.textPaged,
            _ReaderViewportKind.textScroll =>
              ReaderPresentationViewportKind.textScroll,
            _ReaderViewportKind.mangaPaged =>
              ReaderPresentationViewportKind.mangaPaged,
            _ReaderViewportKind.mangaContinuous =>
              ReaderPresentationViewportKind.mangaContinuous,
          };
          final shellModel = ReaderShellModel(
            contentSession: shellSession,
            settings: _settings,
            surfaceMetrics: _resolveReaderSurfaceMetrics(context),
            viewportKind: viewportKind,
            palette: ReaderPresentationPalette.fromColorScheme(
              Theme.of(context).colorScheme,
            ),
            background: _buildBackgroundLayer(colors),
            chrome: ReaderShellChromeSlots(
              backgroundOverlay:
                  _readerBrightnessOverlayAlpha() > 0.001
                      ? IgnorePointer(
                        child: ColoredBox(
                          color: Colors.black.withValues(
                            alpha: _readerBrightnessOverlayAlpha(),
                          ),
                        ),
                      )
                      : null,
              foregroundOverlay: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  _buildChapterLoadingIndicator(colors),
                  _buildOverlayScrim(),
                  _buildTopOverlay(colors),
                  _buildBottomOverlay(colors),
                ],
              ),
            ),
          );

          return Scaffold(
            backgroundColor: colors.background,
            body: SafeArea(
              top: false,
              bottom: false,
              child: ClipRect(
                child: ReaderShell(
                  model: shellModel,
                  child: _buildReaderContent(colors),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  double _readerBrightnessOverlayAlpha() {
    if (_isSystemBrightnessOverrideActive) {
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

  void _debugLogReaderBackground(String tag, ReaderSettings settings) {
    final raw = settings.backgroundImageBase64?.trim();
    final hasBackgroundImage = raw != null && raw.isNotEmpty;
    final isManaged = _isManagedBackgroundPath(raw);
    final fileExists =
        isManaged
            ? (raw!.startsWith('file://')
                ? File(Uri.parse(raw).toFilePath()).existsSync()
                : File(raw).existsSync())
            : null;
    debugPrint(
      '[reader-bg][$tag] image=$raw '
      'hasImage=$hasBackgroundImage '
      'isManaged=$isManaged '
      'fileExists=$fileExists '
      'style=${settings.backgroundStyle.name} '
      'tone=${settings.backgroundTone.name} '
      'mode=${settings.themeMode.name} '
      'brightness=${settings.brightness.toStringAsFixed(3)} '
      'overlayAlpha=${_readerBrightnessOverlayAlpha().toStringAsFixed(3)}',
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_setVolumeKeyPageInterceptionEnabled(false));
      unawaited(_restoreSystemReaderBrightness());
      _commitReadingRecordSession();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(_syncVolumeKeyPageInterception());
      unawaited(_applySystemReaderBrightness());
      _maybeStartReadingRecordSession(initialRatio: _currentScrollRatio());
    }
  }

  Future<void> _applySystemReaderBrightness([double? brightness]) async {
    final applied = await _screenBrightnessBridge.setReaderBrightness(
      brightness ?? _settings.brightness,
    );
    if (!mounted) {
      _isSystemBrightnessOverrideActive = applied;
      return;
    }
    if (_isSystemBrightnessOverrideActive == applied) {
      return;
    }
    setState(() {
      _isSystemBrightnessOverrideActive = applied;
    });
  }

  Future<void> _restoreSystemReaderBrightness() async {
    await _screenBrightnessBridge.resetReaderBrightness();
    _isSystemBrightnessOverrideActive = false;
  }

  void _updateReaderState(VoidCallback mutation) {
    if (!mounted) {
      return;
    }
    setState(mutation);
  }

  Decoration _buildReaderBackgroundDecoration(_ReaderThemeColors colors) {
    final resolvedBackground = _resolveReaderBackgroundVisual();
    final (backgroundColor, surfaceColor) = switch (_settings.backgroundStyle) {
      ReaderBackgroundStyle.plain => (colors.background, colors.background),
      ReaderBackgroundStyle.paper => (
        _shiftLightness(colors.background, 0.03),
        _shiftLightness(colors.background, -0.02),
      ),
      ReaderBackgroundStyle.warm => (
        _shiftLightness(colors.background, 0.03),
        _shiftLightness(colors.background, -0.02),
      ),
    };
    return buildImageBackdropDecoration(
      backgroundColor: backgroundColor,
      surfaceColor: surfaceColor,
      imageProvider: resolvedBackground?.imageProvider,
      imageOpacity: resolvedBackground?.opacity ?? 1,
      imageBlurSigma: resolvedBackground?.blurSigma ?? 0,
      imageFit: resolvedBackground?.fit ?? BoxFit.cover,
      overlayColor: colors.background,
      overlayOpacity: resolvedBackground?.overlayOpacity ?? 0,
    );
  }

  _ResolvedReaderBackgroundVisual? _resolveReaderBackgroundVisual() {
    final raw = _effectiveReaderBackgroundPath();
    if (raw == null || raw.isEmpty) {
      _cachedBackgroundImageKey = null;
      _cachedBackgroundImage = null;
      return null;
    }
    final themeModeConfig = _effectiveReaderBackgroundThemeConfig();
    final fit = switch (themeModeConfig?.readerWallpaperFit) {
      AppAdvancedThemeWallpaperFit.fill => BoxFit.fill,
      AppAdvancedThemeWallpaperFit.cover || null => BoxFit.cover,
    };
    final opacity = (themeModeConfig?.readerWallpaperOpacity ?? 1).clamp(
      0.0,
      1.0,
    );
    final blurSigma = (themeModeConfig?.readerWallpaperBlurSigma ?? 0).clamp(
      0.0,
      24.0,
    );
    final overlayOpacity = (themeModeConfig?.readerWallpaperOverlayOpacity ?? 0)
        .clamp(0.0, 1.0);

    if (_isPresetBackgroundAssetPath(raw)) {
      _cachedBackgroundImageKey = null;
      _cachedBackgroundImage = null;
      return _ResolvedReaderBackgroundVisual(
        imageProvider: AssetImage(raw),
        fit: fit,
        opacity: opacity,
        blurSigma: blurSigma,
        overlayOpacity: overlayOpacity,
      );
    }

    if (_isManagedBackgroundPath(raw)) {
      final file =
          raw.startsWith('file://')
              ? File(Uri.parse(raw).toFilePath())
              : File(raw);
      if (!file.existsSync()) {
        _cachedBackgroundImageKey = null;
        _cachedBackgroundImage = null;
        return null;
      }
      return _ResolvedReaderBackgroundVisual(
        imageProvider: FileImage(file),
        fit: fit,
        opacity: opacity,
        blurSigma: blurSigma,
        overlayOpacity: overlayOpacity,
      );
    }

    if (_cachedBackgroundImageKey != raw || _cachedBackgroundImage == null) {
      final bytes = _tryDecodeBase64(raw);
      if (bytes == null) {
        _cachedBackgroundImageKey = null;
        _cachedBackgroundImage = null;
        return null;
      }
      _cachedBackgroundImageKey = raw;
      _cachedBackgroundImage = MemoryImage(bytes);
    }

    return _ResolvedReaderBackgroundVisual(
      imageProvider: _cachedBackgroundImage!,
      fit: fit,
      opacity: opacity,
      blurSigma: blurSigma,
      overlayOpacity: overlayOpacity,
    );
  }

  Uint8List? _tryDecodeBase64(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    try {
      final bytes = base64Decode(normalized);
      if (bytes.isEmpty) {
        return null;
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  bool _isManagedBackgroundPath(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return false;
    }
    return normalized.startsWith('/') || normalized.startsWith('file://');
  }

  bool _isPresetBackgroundValue(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return false;
    }
    return _isPresetBackgroundAssetPath(normalized) ||
        _backgroundPresetBytes.containsKey(normalized) ||
        _backgroundPresetBase64.values.contains(normalized);
  }

  bool _isPresetBackgroundAssetPath(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return false;
    }
    if (_kFallbackBackgroundPresetPaths.contains(normalized)) {
      return true;
    }
    for (final preset in _backgroundPresets) {
      if (preset.assetPath == normalized) {
        return true;
      }
    }
    return normalized.startsWith('assets/reader/backgrounds/');
  }

  Future<void> _preloadCustomBackgroundPreviews(List<String> sources) async {
    final normalizedSources =
        sources
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .toSet();
    _customBackgroundPreviewBytes.removeWhere(
      (key, _) => !normalizedSources.contains(key),
    );

    for (final source in normalizedSources) {
      if (_customBackgroundPreviewBytes.containsKey(source)) {
        continue;
      }
      final preview = await _loadBackgroundPreviewBytes(source);
      if (preview != null) {
        _customBackgroundPreviewBytes[source] = preview;
      }
    }
  }

  Future<Uint8List?> _loadBackgroundPreviewBytes(String source) async {
    final normalized = source.trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (_isManagedBackgroundPath(normalized)) {
      try {
        final file =
            normalized.startsWith('file://')
                ? File(Uri.parse(normalized).toFilePath())
                : File(normalized);
        if (!await file.exists()) {
          return null;
        }
        final bytes = await file.readAsBytes();
        return _resizeImageBytes(
          bytes,
          maxDimension: _kCustomBackgroundPreviewMaxDimension,
          quality: 72,
        );
      } catch (_) {
        return null;
      }
    }
    return _tryDecodeBase64(normalized);
  }

  Uint8List? _resizeImageBytes(
    Uint8List bytes, {
    required int maxDimension,
    required int quality,
  }) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return bytes;
      }
      img.Image processed = decoded;
      final width = decoded.width;
      final height = decoded.height;
      final longestSide = width > height ? width : height;
      if (longestSide > maxDimension) {
        if (width >= height) {
          processed = img.copyResize(decoded, width: maxDimension);
        } else {
          processed = img.copyResize(decoded, height: maxDimension);
        }
      }
      return Uint8List.fromList(
        img.encodeJpg(processed, quality: quality.clamp(1, 100)),
      );
    } catch (_) {
      return bytes;
    }
  }

  Future<String?> _storeCustomBackgroundImage(Uint8List bytes) async {
    final storedBytes = _resizeImageBytes(
      bytes,
      maxDimension: _kCustomBackgroundStoreMaxDimension,
      quality: _kCustomBackgroundStoreQuality,
    );
    if (storedBytes == null || storedBytes.isEmpty) {
      return null;
    }
    final filePath = await _readerBackgroundService.importBackground(
      bytes: storedBytes,
      fileName: 'bg_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}.jpg',
    );
    _customBackgroundPreviewBytes[filePath] =
        _resizeImageBytes(
          storedBytes,
          maxDimension: _kCustomBackgroundPreviewMaxDimension,
          quality: 72,
        ) ??
        storedBytes;
    return filePath;
  }

  Future<void> _deleteManagedBackgroundFileIfNeeded(String source) async {
    final normalized = source.trim();
    if (!_isManagedBackgroundPath(normalized)) {
      return;
    }
    try {
      final resolved =
          normalized.startsWith('file://')
              ? Uri.parse(normalized).toFilePath()
              : normalized;
      await _readerBackgroundService.deleteBackground(resolved);
    } catch (_) {
      // ignore cleanup failure
    } finally {
      _customBackgroundPreviewBytes.remove(normalized);
    }
  }

  Future<List<String>> _loadUnifiedCustomBackgrounds() async {
    final stored = await _preferencesService.loadCustomBackgroundImages();
    final managed = await _readerBackgroundService.loadBackgroundPaths();
    final merged = <String>[];
    for (final path in [...managed, ...stored]) {
      final normalized = path.trim();
      if (normalized.isEmpty || merged.contains(normalized)) {
        continue;
      }
      merged.add(normalized);
    }
    return merged;
  }

  Future<void> _refreshSharedReaderAssets({
    void Function(VoidCallback fn)? updateModalState,
  }) async {
    final fonts = await _fontRegistryService.listRegisteredFonts();
    final backgrounds = await _loadUnifiedCustomBackgrounds();
    if (!mounted) {
      return;
    }
    setState(() {
      _customFonts = fonts;
      _customBackgroundImages = backgrounds;
    });
    updateModalState?.call(() {
      _customFonts = fonts;
      _customBackgroundImages = backgrounds;
    });
    unawaited(_preloadCustomBackgroundPreviews(backgrounds));
    await _preferencesService.saveCustomBackgroundImages(backgrounds);
  }

  Widget _buildReaderContent(_ReaderThemeColors colors) {
    return Column(
      children: [
        if (_showsPinnedChapterHeader) _buildPinnedChapterHeader(colors),
        Expanded(child: _buildBody(colors)),
        if (_showsReaderFooterInfoBar)
          _buildReaderInfoBar(colors, isHeader: false),
      ],
    );
  }

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
    final items = _buildReaderInfoItems()
        .map((item) => ReaderInfoBarItemData.text(item))
        .toList(growable: false);
    return ReaderInfoBar(
      model: ReaderInfoBarModel.fromSettings(
        settings: _settings,
        layoutResolver: _layoutResolver,
        placement:
            isHeader
                ? ReaderInfoBarPlacement.header
                : ReaderInfoBarPlacement.footer,
        role: switch ((_currentViewportKind, isHeader)) {
          (_ReaderViewportKind.textScroll, true) =>
            ReaderChromeRole.scrollHeader,
          (_ReaderViewportKind.textScroll, false) =>
            ReaderChromeRole.scrollFooter,
          (_, true) => ReaderChromeRole.pagedHeader,
          (_, false) => ReaderChromeRole.pagedFooter,
        },
        centerItems: items,
      ),
      palette: _chromePalette(colors),
    );
  }

  String _formatReaderInfoTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  List<String> _buildReaderInfoItems() {
    final items = <String>[];
    if (_settings.infoShowTime) {
      items.add(_formatReaderInfoTime(_readerInfoNow));
    }
    if (_settings.infoShowBattery) {
      items.add(_readerBatteryLabel());
    }
    if (_settings.infoShowProgress) {
      items.add('进度 ${(_currentScrollRatio() * 100).round()}%');
    }
    if (_settings.infoShowChapter &&
        (_chapterTitle?.trim().isNotEmpty ?? false)) {
      items.add(_chapterTitle!.trim());
    }
    return items;
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

  Widget _buildBody(_ReaderThemeColors colors) {
    final palette = ReaderBodyRegionPalette(
      textColor: colors.text,
      metaColor: colors.meta,
      overlayColor: colors.overlay,
      dividerColor: colors.divider,
    );
    if (_shouldShowBlockingReaderLoading) {
      return _buildTapAwareBody(
        child: ReaderBodyRegion(
          model: const ReaderBodyRegionModel.stateCard(
            stateCard: ReaderBodyRegionStateCard(
              title: '正在加载正文',
              message: '请稍候，马上为你展开章节内容。',
              icon: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          palette: palette,
        ),
      );
    }

    if ((_isBootstrapping || _isLoadingContent) && !_hasVisibleReaderContent) {
      return ReaderBodyRegion(
        model: const ReaderBodyRegionModel.hidden(),
        palette: palette,
      );
    }

    if (_errorText != null) {
      final canSwitchSource = _canSwitchSource;
      return _buildTapAwareBody(
        child: ReaderBodyRegion(
          model: ReaderBodyRegionModel.stateCard(
            stateCard: ReaderBodyRegionStateCard(
              title: '加载失败',
              message: _errorText!,
              icon: Icon(
                Icons.warning_amber_rounded,
                color: colors.meta,
                size: 20,
              ),
              action: Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.tonal(
                    onPressed:
                        _isSwitchSourceLoading
                            ? null
                            : () =>
                                _loadCurrentChapter(initialScrollRatio: null),
                    child: const Text('重试'),
                  ),
                  if (_isLocalContent)
                    OutlinedButton.icon(
                      onPressed: _copyLocalReaderDiagnostics,
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('复制诊断信息'),
                    ),
                  if (canSwitchSource)
                    OutlinedButton.icon(
                      onPressed:
                          _isSwitchSourceLoading
                              ? null
                              : () => unawaited(_showSwitchSourceSheet()),
                      icon:
                          _isSwitchSourceLoading
                              ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.swap_horiz_rounded),
                      label: Text(_isSwitchSourceLoading ? '换源中...' : '切换书源'),
                    ),
                ],
              ),
            ),
          ),
          palette: palette,
        ),
      );
    }

    if (_content.trim().isEmpty && _chapterImageUrls.isEmpty) {
      return _buildTapAwareBody(
        child: ReaderBodyRegion(
          model: ReaderBodyRegionModel.stateCard(
            stateCard: ReaderBodyRegionStateCard(
              title: '暂无正文',
              message: '当前章节没有可展示的内容。',
              icon: Icon(Icons.article_outlined, color: colors.meta, size: 20),
            ),
          ),
          palette: palette,
        ),
      );
    }

    return _buildTapAwareBody(
      child: ReaderBodyRegion(
        model: const ReaderBodyRegionModel.content(),
        palette: palette,
        child: switch (_currentViewportKind) {
          _ReaderViewportKind.mangaPaged ||
          _ReaderViewportKind.mangaContinuous => _buildMangaReader(colors),
          _ReaderViewportKind.textPaged => _buildPagedReader(colors),
          _ReaderViewportKind.textScroll => _buildReaderList(colors),
        },
      ),
    );
  }

  Widget _buildReaderList(_ReaderThemeColors colors) {
    if (_shouldUseContinuousTextFlow && _continuousTextChapters.isNotEmpty) {
      return _buildContinuousTextReader(colors);
    }
    return _buildStandardReaderList(colors);
  }

  Widget _buildStandardReaderList(_ReaderThemeColors colors) {
    final surfaceMetrics = _resolveReaderSurfaceMetrics(context);
    final bodyPadding = surfaceMetrics.scrollBodyPadding;
    final contentSession = _currentContentSession();
    final scrollView = NotificationListener<ScrollNotification>(
      onNotification: _onReaderScrollNotification,
      child: ReaderTextScrollView(
        model: ReaderTextScrollViewModel(
          contentSession:
              contentSession ??
              ReaderContentSession(
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
          settings: _settings,
          document: _document,
          surfaceMetrics: surfaceMetrics,
          palette: ReaderPresentationPalette.fromColorScheme(
            Theme.of(context).colorScheme,
          ),
          renderItems: _renderItems,
          contentPadding: bodyPadding,
        ),
        scrollController: _scrollController,
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
      ),
    );

    return KeyedSubtree(
      key: _readerBodyKey,
      child: _wrapSelectionArea(child: scrollView),
    );
  }

  Widget _buildContinuousTextReader(_ReaderThemeColors colors) {
    final surfaceMetrics = _resolveReaderSurfaceMetrics(context);
    final bodyPadding = surfaceMetrics.scrollBodyPadding;
    final contentSession = _currentContentSession();

    final listView = NotificationListener<ScrollNotification>(
      onNotification: _onReaderScrollNotification,
      child: ListView.separated(
        controller: _scrollController,
        cacheExtent: 1800,
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

    if (contentSession == null) {
      return Stack(
        key: _readerBodyKey,
        children: [
          listView,
          if (_isAutoReadSessionEnabled) _buildAutoReadIndicator(colors),
        ],
      );
    }

    return ReaderTextScrollView(
      model: ReaderTextScrollViewModel(
        contentSession: contentSession,
        settings: _settings,
        document: _document,
        surfaceMetrics: surfaceMetrics,
        palette: ReaderPresentationPalette.fromColorScheme(
          Theme.of(context).colorScheme,
        ),
      ),
      content: listView,
      overlay:
          _isAutoReadSessionEnabled ? _buildAutoReadIndicator(colors) : null,
    );
  }

  Widget _buildContinuousTextChapterSection({
    required _ContinuousTextChapter chapter,
    required bool isActive,
    required _ReaderThemeColors colors,
  }) {
    final renderItems = buildReaderRenderBlockItems(chapter.document);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (renderItems.isEmpty)
          isActive
              ? _buildSelectableParagraphItem(
                paragraph: chapter.content,
                paragraphIndex: 0,
                isLast: true,
                colors: colors,
              )
              : _buildStaticParagraphItem(
                paragraph: chapter.content,
                isLast: true,
                colors: colors,
              )
        else
          for (var index = 0; index < renderItems.length; index += 1)
            isActive
                ? _buildSelectableReaderBlockItem(
                  item: renderItems[index],
                  isLast: index == renderItems.length - 1,
                  colors: colors,
                )
                : _buildStaticReaderBlockItem(
                  item: renderItems[index],
                  isLast: index == renderItems.length - 1,
                  colors: colors,
                ),
      ],
    );

    return KeyedSubtree(
      key: _continuousTextChapterKey(chapter),
      child: isActive ? _wrapSelectionArea(child: body) : body,
    );
  }

  Widget _buildStaticParagraphItem({
    required String paragraph,
    required bool isLast,
    required _ReaderThemeColors colors,
  }) {
    final inlineImageUrl = _tryParseInlineImageParagraph(paragraph);
    if (inlineImageUrl != null) {
      return _buildInlineImageParagraphItem(
        imageUrl: inlineImageUrl,
        isLast: isLast,
        colors: colors,
      );
    }

    final textStyle = _paragraphTextStyle(colors);
    final paddingBottom =
        isLast
            ? 0.0
            : _typographyMetricsResolver.resolveParagraphSpacingPixels(
              settings: _settings,
            );

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(bottom: paddingBottom),
        child: ReaderAnnotatedText(
          displayText: _applyParagraphIndent(paragraph),
          indentLength: _paragraphIndentLength(),
          baseStyle: textStyle,
          textAlign: _paragraphTextAlign(_settings),
          textDirection: Directionality.of(context),
          highlightColor: colors.text,
          wavyColor: colors.text.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  ReaderRenderTextItem? _readerRenderTextItemForParagraphIndex(
    int paragraphIndex,
  ) {
    return _renderTextItemsByParagraph[paragraphIndex];
  }

  AppAdvancedThemeModeConfig? _effectiveReaderBackgroundThemeConfig() {
    final activeThemeAsync = ref.read(activeAdvancedThemeProvider);
    final activeTheme = activeThemeAsync.valueOrNull;
    if (activeTheme != null) {
      final colorScheme = Theme.of(context).colorScheme;
      final modeConfig = activeTheme.configFor(
        colorScheme.brightness == Brightness.dark
            ? AppAdvancedThemeMode.dark
            : AppAdvancedThemeMode.light,
      );
      final themeReaderWallpaper = modeConfig.readerWallpaperPath?.trim();
      if (themeReaderWallpaper != null && themeReaderWallpaper.isNotEmpty) {
        return modeConfig;
      }
    }
    return null;
  }

  String? _effectiveReaderBackgroundPath() {
    final themeModeConfig = _effectiveReaderBackgroundThemeConfig();
    if (themeModeConfig != null) {
      return themeModeConfig.readerWallpaperPath?.trim();
    }
    final ownBackground = _settings.backgroundImageBase64?.trim();
    if (ownBackground == null || ownBackground.isEmpty) {
      return null;
    }
    return ownBackground;
  }

  Widget _buildStaticReaderBlockItem({
    required ReaderRenderBlockItem item,
    required bool isLast,
    required _ReaderThemeColors colors,
  }) {
    if (item is ReaderRenderImageItem) {
      return _buildInlineImageParagraphItem(
        imageUrl: item.imageUrl,
        isLast: isLast,
        colors: colors,
      );
    }
    if (item is! ReaderRenderTextItem) {
      return const SizedBox.shrink();
    }

    final textStyle = _readerBlockTextStyle(item, colors);
    final displayText = _displayTextForRenderItem(item);
    final indentLength = _indentLengthForRenderItem(item);

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: _readerBlockSpacing(item, isLast: isLast),
        ),
        child: ReaderAnnotatedText(
          displayText: displayText,
          indentLength: indentLength,
          baseStyle: textStyle,
          textAlign: _textAlignForRenderItem(item),
          textDirection: Directionality.of(context),
          highlightColor: colors.text,
          wavyColor: colors.text.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildSelectableReaderBlockItem({
    required ReaderRenderBlockItem item,
    required bool isLast,
    required _ReaderThemeColors colors,
  }) {
    if (item is ReaderRenderImageItem) {
      return _buildInlineImageParagraphItem(
        imageUrl: item.imageUrl,
        isLast: isLast,
        colors: colors,
      );
    }
    if (item is! ReaderRenderTextItem) {
      return const SizedBox.shrink();
    }
    if (item.kind == ReaderRenderTextKind.paragraph) {
      return _buildSelectableParagraphItem(
        paragraph: item.text,
        paragraphIndex: item.paragraphIndex ?? 0,
        isLast: isLast,
        colors: colors,
      );
    }

    final textStyle = _readerBlockTextStyle(item, colors);
    final displayText = _displayTextForRenderItem(item);
    final indentLength = _indentLengthForRenderItem(item);

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: _readerBlockSpacing(item, isLast: isLast),
        ),
        child: ReaderAnnotatedText(
          displayText: displayText,
          indentLength: indentLength,
          baseStyle: textStyle,
          textAlign: _textAlignForRenderItem(item),
          textDirection: Directionality.of(context),
          highlightColor: colors.text,
          wavyColor: colors.text.withValues(alpha: 0.7),
          annotationRanges: (_bookmarkRangesByParagraph[item.paragraphIndex ??
                      0] ??
                  const <_BookmarkRange>[])
              .map(
                (range) => ReaderTextAnnotationRange(
                  range.start,
                  range.end,
                  hasHighlight: range.hasHighlight,
                  isBold: range.isBold,
                  isUnderline: range.isUnderline,
                  isWavy: range.isWavy,
                ),
              )
              .toList(growable: false),
          onTapUp: (details) {
            final renderBox = context.findRenderObject();
            final maxWidth =
                renderBox is RenderBox ? renderBox.size.width : 0.0;
            final handled = _handleBookmarkTap(
              paragraphIndex: item.paragraphIndex ?? 0,
              paragraphText: item.text,
              localPosition: details.localPosition,
              maxWidth: maxWidth,
              textStyle: textStyle,
              textAlign: _textAlignForRenderItem(item),
            );
            if (handled) {
              _suppressNextReaderTap = true;
            }
          },
        ),
      ),
    );
  }

  Widget _buildSelectableParagraphItem({
    required String paragraph,
    required int paragraphIndex,
    required bool isLast,
    required _ReaderThemeColors colors,
  }) {
    final inlineImageUrl = _tryParseInlineImageParagraph(paragraph);
    if (inlineImageUrl != null) {
      return _buildInlineImageParagraphItem(
        imageUrl: inlineImageUrl,
        isLast: isLast,
        colors: colors,
      );
    }

    final textStyle = _paragraphTextStyle(colors);
    final paddingBottom =
        isLast
            ? 0.0
            : _typographyMetricsResolver.resolveParagraphSpacingPixels(
              settings: _settings,
            );

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(bottom: paddingBottom),
        child: ReaderAnnotatedText(
          displayText: _applyParagraphIndent(paragraph),
          indentLength: _paragraphIndentLength(),
          baseStyle: textStyle,
          textAlign: _paragraphTextAlign(_settings),
          textDirection: Directionality.of(context),
          highlightColor: colors.text,
          wavyColor: colors.text.withValues(alpha: 0.7),
          annotationRanges: (_bookmarkRangesByParagraph[paragraphIndex] ??
                  const <_BookmarkRange>[])
              .map(
                (range) => ReaderTextAnnotationRange(
                  range.start,
                  range.end,
                  hasHighlight: range.hasHighlight,
                  isBold: range.isBold,
                  isUnderline: range.isUnderline,
                  isWavy: range.isWavy,
                ),
              )
              .toList(growable: false),
          bodyDecorationEnabled:
              _settings.bodyTextDecorationStyle !=
              ReaderBodyTextDecorationStyle.none,
          bodyDecorationColor: Color(
            _settings.bodyTextDecorationColorValue ?? colors.text.toARGB32(),
          ),
          bodyDecorationStyle: _settings.bodyTextDecorationStyle,
          bodyDecorationThickness: _settings.bodyTextUnderlineThickness,
          bodyDecorationGap: _settings.bodyTextUnderlineGap,
          bodyDecorationDashLength: _settings.bodyTextUnderlineDashLength,
          bodyDecorationDashGapRatio: _settings.bodyTextUnderlineDashGapRatio,
          onTapUp: (details) {
            final renderBox = context.findRenderObject();
            final maxWidth =
                renderBox is RenderBox ? renderBox.size.width : 0.0;
            final handled = _handleBookmarkTap(
              paragraphIndex: paragraphIndex,
              paragraphText: paragraph,
              localPosition: details.localPosition,
              maxWidth: maxWidth,
              textStyle: textStyle,
              textAlign: _paragraphTextAlign(_settings),
            );
            if (handled) {
              _suppressNextReaderTap = true;
            }
          },
        ),
      ),
    );
  }

  Widget _buildAutoReadIndicator(_ReaderThemeColors colors) {
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxHeight = constraints.maxHeight;
            if (maxHeight <= 1) {
              return const SizedBox.shrink();
            }
            return AnimatedBuilder(
              animation: _scrollController,
              builder: (context, _) {
                if (!_scrollController.hasClients || !_isTextScrollViewport) {
                  return const SizedBox.shrink();
                }

                final ratio = _autoReadProgressRatio();
                final top =
                    (maxHeight * ratio).clamp(2.0, maxHeight - 2.0).toDouble();

                return Stack(
                  children: [
                    Positioned(
                      top: top - 14,
                      left: 10,
                      right: 10,
                      child: Container(
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              colors.meta.withValues(alpha: 0.08),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: top,
                      left: 16,
                      right: 16,
                      child: Container(
                        height: 1.8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              colors.meta.withValues(alpha: 0.28),
                              colors.text.withValues(alpha: 0.52),
                              colors.meta.withValues(alpha: 0.28),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildInlineImageParagraphItem({
    required String imageUrl,
    required bool isLast,
    required _ReaderThemeColors colors,
  }) {
    final paddingBottom =
        isLast
            ? 0.0
            : _typographyMetricsResolver.resolveParagraphSpacingPixels(
              settings: _settings,
            );
    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(bottom: paddingBottom),
        child: _buildInlineReaderImageCard(imageUrl: imageUrl, colors: colors),
      ),
    );
  }

  Widget _buildInlineReaderImageCard({
    required String imageUrl,
    required _ReaderThemeColors colors,
  }) {
    final retryNonce = _mangaImageRetryNonce[imageUrl] ?? 0;
    final requestUrl = _buildMangaImageUrl(imageUrl, retryNonce);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: colors.overlay,
        child: _buildReaderImageWidget(
          requestUrl: requestUrl,
          sourceUrl: imageUrl,
          colors: colors,
          retryNonce: retryNonce,
        ),
      ),
    );
  }

  String? _tryParseInlineImageParagraph(String paragraph) {
    return ReaderDocument.tryParseInlineImageParagraph(paragraph);
  }

  bool _isInlineImageParagraph(String paragraph) {
    return _tryParseInlineImageParagraph(paragraph) != null;
  }

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
        _updateScrollEdgeAdvanceState(isArmed: true, actionDirection: -1);
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
        _updateScrollEdgeAdvanceState(isArmed: true, actionDirection: -1);
      }
    }

    if (notification is OverscrollNotification &&
        notification.dragDetails != null) {
      final direction =
          notification.overscroll > 0 && atBottom
              ? 1
              : notification.overscroll < 0 && atTop
              ? -1
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
      var shouldAdvance = _scrollEdgeAdvanceState.isArmed;
      var actionDirection = _scrollEdgeAdvanceState.actionDirection;
      final isDragEnd =
          notification is ScrollEndNotification &&
          notification.dragDetails != null;
      final endVelocityDy =
          notification is ScrollEndNotification
              ? (notification.dragDetails?.velocity.pixelsPerSecond.dy ?? 0)
              : 0;
      // When a drag lands exactly on the chapter edge, immediately continue
      // to next/previous chapter instead of requiring another overscroll.
      if (!shouldAdvance && isDragEnd) {
        if (actionDirection == 0 && endVelocityDy.abs() >= 36) {
          actionDirection = endVelocityDy < 0 ? 1 : -1;
          shouldAdvance = true;
        } else if (atBottom) {
          shouldAdvance = true;
          actionDirection = 1;
        } else if (atTop) {
          shouldAdvance = true;
          actionDirection = -1;
        }
      }
      _resetScrollEdgeAdvanceState();
      if (shouldAdvance && actionDirection != 0) {
        unawaited(_handleScrollEdgeChapterAction(actionDirection));
      }
    }

    return false;
  }

  Future<void> _handleScrollEdgeChapterAction(int direction) async {
    if (direction == 0) {
      return;
    }
    if (_shouldUseContinuousTextFlow) {
      await _loadAdjacentContinuousTextChapter(forward: direction > 0);
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

  Widget _buildMangaReader(_ReaderThemeColors colors) {
    final contentSession =
        _currentContentSession() ??
        ReaderContentSession(
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
        );
    final surfaceMetrics = _resolveReaderSurfaceMetrics(context);
    final bottomInset = _effectiveBottomSafeInset(context);
    return ReaderMangaView(
      model: ReaderMangaViewModel(
        contentSession: contentSession,
        settings: _settings,
        surfaceMetrics: surfaceMetrics,
        palette: ReaderPresentationPalette.fromColorScheme(
          Theme.of(context).colorScheme,
        ),
        imageUrls: _chapterImageUrls,
        currentIndex: _mangaPageIndex,
        continuousPadding: EdgeInsets.fromLTRB(
          _settings.mangaImagePadding,
          12,
          _settings.mangaImagePadding,
          96 + bottomInset,
        ),
        pagedPagePadding: EdgeInsets.fromLTRB(
          _settings.mangaImagePadding,
          12,
          _settings.mangaImagePadding,
          6,
        ),
        continuousCacheExtent: _resolveMangaCacheExtent(),
      ),
      scrollController: _scrollController,
      pageController: _mangaPageController,
      onPageChanged: (index) {
        if (!mounted) {
          return;
        }
        setState(() {
          _mangaPageIndex = index;
        });
        _syncActiveReadingRecordSessionProgress();
        _scheduleProgressSave();
      },
      imageBuilder: (_, item) {
        final imageUrl = item.imageUrl;
        final retryNonce = _mangaImageRetryNonce[imageUrl] ?? 0;
        return _buildReaderImageWidget(
          requestUrl: _buildMangaImageUrl(imageUrl, retryNonce),
          sourceUrl: imageUrl,
          colors: colors,
          retryNonce: retryNonce,
        );
      },
      pagedViewportBuilder: (context, viewport, child) {
        final overlayIndex = _mangaPageIndex.clamp(
          0,
          _safePageUpperBound(viewport.itemCount),
        );
        return Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 94 + bottomInset),
              child: child,
            ),
            _buildPageIndexOverlay(
              colors: colors,
              index: overlayIndex,
              total: viewport.itemCount,
              bottomInset: bottomInset,
            ),
          ],
        );
      },
    );
  }

  Widget _buildReaderImageWidget({
    required String requestUrl,
    required String sourceUrl,
    required _ReaderThemeColors colors,
    required int retryNonce,
  }) {
    final uri = Uri.tryParse(requestUrl);
    if (_isSvgImageUrl(requestUrl)) {
      return _buildSvgImageWidget(
        requestUrl: requestUrl,
        colors: colors,
        sourceUrl: sourceUrl,
        retryNonce: retryNonce,
      );
    }
    if (requestUrl.startsWith('data:image/')) {
      return _buildDataUriImage(
        dataUri: requestUrl,
        colors: colors,
        sourceUrl: sourceUrl,
        retryNonce: retryNonce,
      );
    }
    if (uri != null && uri.scheme == 'file') {
      return Image.file(
        File.fromUri(uri),
        fit: BoxFit.fitWidth,
        filterQuality: _resolveMangaFilterQuality(),
        errorBuilder: (context, error, stackTrace) {
          return _buildMangaImageError(colors, sourceUrl, retryNonce);
        },
      );
    }

    return Image.network(
      requestUrl,
      headers: _chapterImageHeaders.isEmpty ? null : _chapterImageHeaders,
      fit: BoxFit.fitWidth,
      filterQuality: _resolveMangaFilterQuality(),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }

        return AspectRatio(
          aspectRatio: 3 / 4,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.meta,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildMangaImageError(colors, sourceUrl, retryNonce);
      },
    );
  }

  bool _isSvgImageUrl(String imageUrl) {
    if (imageUrl.startsWith('data:image/svg+xml')) {
      return true;
    }
    final uri = Uri.tryParse(imageUrl);
    final path = uri?.path.toLowerCase() ?? imageUrl.toLowerCase();
    return path.endsWith('.svg') || path.endsWith('.svgz');
  }

  Widget _buildSvgImageWidget({
    required String requestUrl,
    required _ReaderThemeColors colors,
    required String sourceUrl,
    required int retryNonce,
  }) {
    final uri = Uri.tryParse(requestUrl);
    Widget placeholderBuilder(BuildContext context) {
      return AspectRatio(
        aspectRatio: 3 / 4,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: colors.meta),
        ),
      );
    }

    Widget errorBuilder(
      BuildContext context,
      Object error,
      StackTrace stackTrace,
    ) {
      return _buildMangaImageError(colors, sourceUrl, retryNonce);
    }

    try {
      if (requestUrl.startsWith('data:image/svg+xml')) {
        final decoded = _decodeDataUriImage(dataUri: requestUrl);
        if (decoded == null) {
          throw const FormatException('Invalid SVG data URI');
        }
        return SvgPicture.string(
          decoded.text,
          fit: BoxFit.fitWidth,
          placeholderBuilder: placeholderBuilder,
          errorBuilder: errorBuilder,
        );
      }
      if (uri != null && uri.scheme == 'file') {
        return SvgPicture.file(
          File.fromUri(uri),
          fit: BoxFit.fitWidth,
          placeholderBuilder: placeholderBuilder,
          errorBuilder: errorBuilder,
        );
      }
      return SvgPicture.network(
        requestUrl,
        headers: _chapterImageHeaders.isEmpty ? null : _chapterImageHeaders,
        fit: BoxFit.fitWidth,
        placeholderBuilder: placeholderBuilder,
        errorBuilder: errorBuilder,
      );
    } catch (_) {
      return _buildMangaImageError(colors, sourceUrl, retryNonce);
    }
  }

  Widget _buildDataUriImage({
    required String dataUri,
    required _ReaderThemeColors colors,
    required String sourceUrl,
    required int retryNonce,
  }) {
    try {
      final decoded = _decodeDataUriImage(dataUri: dataUri);
      if (decoded == null) {
        throw const FormatException('Invalid data URI');
      }
      return Image.memory(
        decoded.bytes,
        fit: BoxFit.fitWidth,
        filterQuality: _resolveMangaFilterQuality(),
        errorBuilder: (context, error, stackTrace) {
          return _buildMangaImageError(colors, sourceUrl, retryNonce);
        },
      );
    } catch (_) {
      return _buildMangaImageError(colors, sourceUrl, retryNonce);
    }
  }

  _DecodedDataUriImage? _decodeDataUriImage({required String dataUri}) {
    final commaIndex = dataUri.indexOf(',');
    if (commaIndex <= 0) {
      return null;
    }
    final metadata = dataUri.substring(5, commaIndex);
    final encoded = dataUri.substring(commaIndex + 1);
    final isBase64 = metadata.toLowerCase().contains(';base64');
    final mediaType = metadata.split(';').first.trim().toLowerCase();
    final bytes =
        isBase64
            ? base64Decode(encoded)
            : Uint8List.fromList(utf8.encode(Uri.decodeComponent(encoded)));
    return _DecodedDataUriImage(
      mediaType: mediaType,
      bytes: bytes,
      text: utf8.decode(bytes, allowMalformed: true),
    );
  }

  Widget _buildMangaImageError(
    _ReaderThemeColors colors,
    String imageUrl,
    int retryNonce,
  ) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: InkWell(
        onTap: () {
          setState(() {
            _mangaImageRetryNonce[imageUrl] = retryNonce + 1;
          });
        },
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '图片加载失败，点击重试',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.meta),
            ),
          ),
        ),
      ),
    );
  }

  double _resolveMangaCacheExtent() {
    return switch (_settings.mangaLoadStrategy) {
      ReaderMangaLoadStrategy.balanced => 1800,
      ReaderMangaLoadStrategy.smooth => 3200,
      ReaderMangaLoadStrategy.saveData => 900,
    };
  }

  FilterQuality _resolveMangaFilterQuality() {
    return switch (_settings.mangaLoadStrategy) {
      ReaderMangaLoadStrategy.balanced => FilterQuality.medium,
      ReaderMangaLoadStrategy.smooth => FilterQuality.high,
      ReaderMangaLoadStrategy.saveData => FilterQuality.low,
    };
  }

  ReaderThemeMode _effectiveReaderThemeMode() {
    return _settings.themeMode;
  }

  ReaderThemeMode _readerThemeModeForAppTheme(ThemeMode appThemeMode) {
    final brightness = switch (appThemeMode) {
      ThemeMode.dark => Brightness.dark,
      ThemeMode.light => Brightness.light,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
    return brightness == Brightness.dark
        ? ReaderThemeMode.dark
        : ReaderThemeMode.light;
  }

  Future<void> _syncReaderThemeModeWithAppTheme(
    ThemeMode appThemeMode, {
    bool persist = true,
  }) async {
    final targetMode = _readerThemeModeForAppTheme(appThemeMode);
    if (_settings.themeMode == targetMode) {
      return;
    }

    final nextSettings = _settings.copyWith(themeMode: targetMode);
    if (mounted) {
      setState(() {
        _settings = nextSettings;
      });
    } else {
      _settings = nextSettings;
    }

    if (persist) {
      await _preferencesService.saveSettings(nextSettings);
    }
  }

  ReaderPageAnimationStyle _currentPagedAnimationStyle() {
    return _pagedTextRenderer.resolveAnimationStyle(_settings);
  }

  ReaderAnimationPolicy _resolveAnimationPolicy({
    ReaderContentMode? modeOverride,
    ReaderPageTurnMode? pageTurnModeOverride,
  }) {
    final effectiveMode = modeOverride ?? _currentContentMode;
    final effectivePageTurnMode =
        pageTurnModeOverride ?? _settings.pageTurnMode;
    return _animationPolicyResolver.resolve(
      contentMode: effectiveMode,
      hasInlineImageParagraphs: _currentChapterHasInlineImageParagraphs(),
      usesScrollTrigger: _pageTurnUsesScroll(effectivePageTurnMode),
    );
  }

  bool _currentChapterHasInlineImageParagraphs() {
    return _paragraphs.any(_isInlineImageParagraph);
  }

  String? _pageAnimationInactiveReason({
    ReaderPageTurnMode? modeOverride,
    bool? isMangaChapterOverride,
  }) {
    final contentMode =
        (isMangaChapterOverride ?? _isMangaChapter)
            ? ReaderContentMode.comic
            : ReaderContentMode.text;
    return _resolveAnimationPolicy(
      modeOverride: contentMode,
      pageTurnModeOverride: modeOverride,
    ).inactiveReason;
  }

  Widget _buildPagedReader(_ReaderThemeColors colors) {
    final paragraphs =
        _paragraphs.isEmpty ? <String>[_content.trim()] : _paragraphs;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutMetrics = _resolvePagedLayoutMetrics(context, constraints);
        final paginationSpec = _resolvePaginationSpec(
          surfaceMetrics: layoutMetrics,
        );
        _lastPaginationSpec = paginationSpec;
        final pagedViewModel = ReaderTextPagedViewModel(
          contentSession:
              _currentContentSession() ??
              ReaderContentSession(
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
          settings: _settings,
          surfaceMetrics: layoutMetrics,
          paginationSpec: paginationSpec,
          palette: ReaderPresentationPalette.fromColorScheme(
            Theme.of(context).colorScheme,
          ),
          pageCount: _pagedPages.length,
          currentPageIndex: _currentPageIndex,
          document: _document,
          paragraphs: _paragraphs,
          pagedPages: _pagedPages,
          textItemsByParagraph: _renderTextItemsByParagraph,
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ensurePagination(spec: paginationSpec);
        });

        if (_pagedPaginationState.isPaginating || _pagedPages.isEmpty) {
          return Column(
            children: [
              if (_showsPagedPinnedChapterHeaderFor(_currentViewportKind))
                _buildPinnedChapterHeader(colors),
              if (layoutMetrics.pagedHeaderReserve > 0)
                _buildPagedHeaderSection(colors, layoutMetrics),
              Expanded(
                child: Padding(
                  padding: layoutMetrics.effectivePagePadding,
                  child: ReaderBodyRegion(
                    model: ReaderBodyRegionModel.stateCard(
                      stateCard: ReaderBodyRegionStateCard(
                        title: '正在分页',
                        message:
                            paragraphs.length <= 1
                                ? '正在为你生成阅读页面...'
                                : '正在生成 ${paragraphs.length} 段正文的分页...',
                        icon: const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    palette: ReaderBodyRegionPalette(
                      textColor: colors.text,
                      metaColor: colors.meta,
                      overlayColor: colors.overlay,
                      dividerColor: colors.divider,
                    ),
                  ),
                ),
              ),
              _buildPagedFooterSection(
                colors: colors,
                index: 0,
                total: max(1, _pagedPages.length),
                layoutMetrics: layoutMetrics,
              ),
            ],
          );
        }

        final pageCount = _pagedPages.length;
        final safeIndex = _currentPageIndex.clamp(
          0,
          _safePageUpperBound(pageCount),
        );
        final pagedSize = constraints.biggest;

        final animationStyle = _currentPagedAnimationStyle();
        final motion = _pagedTextRenderer.motionSpecForStyle(animationStyle);

        final pageStack = _buildPagedTransitionStack(
          colors: colors,
          animationStyle: animationStyle,
          pageCount: pageCount,
          safeIndex: safeIndex,
          pagedSize: pagedSize,
          pagedViewModel: pagedViewModel,
          switchDuration: motion.duration,
          switchInCurve: motion.switchInCurve,
          switchOutCurve: motion.switchOutCurve,
        );
        return ReaderTextPagedView(model: pagedViewModel, content: pageStack);
      },
    );
  }

  Widget _buildPagedTransitionStack({
    required _ReaderThemeColors colors,
    required ReaderPageAnimationStyle animationStyle,
    required int pageCount,
    required int safeIndex,
    required Size pagedSize,
    required ReaderTextPagedViewModel pagedViewModel,
    required Duration switchDuration,
    required Curve switchInCurve,
    required Curve switchOutCurve,
  }) {
    final renderedAnimationStyle =
        _isPagedTransitionAnimating ? _pagedTransition.style : animationStyle;
    final pageStack = switch (renderedAnimationStyle) {
      ReaderPageAnimationStyle.curl => _buildCustomCurlPageStack(
        colors: colors,
        pageCount: pageCount,
        safeIndex: safeIndex,
        pagedSize: pagedSize,
        pagedViewModel: pagedViewModel,
      ),
      ReaderPageAnimationStyle.none => _buildStaticPagedPage(
        colors: colors,
        pageIndex: safeIndex,
        pageSize: pagedSize,
        pagedViewModel: pagedViewModel,
        total: pageCount,
      ),
      _ => _buildAnimatedPagedPageTransition(
        colors: colors,
        animationStyle: renderedAnimationStyle,
        safeIndex: safeIndex,
        pagedSize: pagedSize,
        pagedViewModel: pagedViewModel,
        total: pageCount,
        switchDuration: switchDuration,
        switchInCurve: switchInCurve,
        switchOutCurve: switchOutCurve,
      ),
    };

    if (renderedAnimationStyle == ReaderPageAnimationStyle.curl &&
        (_isCurlAutoTurning || _isCurlPreviewActive)) {
      return SelectionContainer.disabled(child: pageStack);
    }
    return _wrapSelectionArea(child: pageStack);
  }

  Widget _buildStaticPagedPage({
    required _ReaderThemeColors colors,
    required int pageIndex,
    required Size pageSize,
    required ReaderTextPagedViewModel pagedViewModel,
    required int total,
    bool includeBackgroundDecoration = false,
  }) {
    return KeyedSubtree(
      key: ValueKey<int>(pageIndex),
      child: _buildPagedPageContainer(
        colors: colors,
        pageIndex: pageIndex,
        total: total,
        pageSize: pageSize,
        pagedViewModel: pagedViewModel,
        includeBackgroundDecoration: includeBackgroundDecoration,
      ),
    );
  }

  Widget _buildAnimatedPagedPageTransition({
    required _ReaderThemeColors colors,
    required ReaderPageAnimationStyle animationStyle,
    required int safeIndex,
    required Size pagedSize,
    required ReaderTextPagedViewModel pagedViewModel,
    required int total,
    required Duration switchDuration,
    required Curve switchInCurve,
    required Curve switchOutCurve,
  }) {
    if (!_isPagedTransitionAnimating ||
        _pagedTransition.style != animationStyle ||
        _pagedTransition.fromIndex == _pagedTransition.toIndex) {
      return _buildStaticPagedPage(
        colors: colors,
        pageIndex: safeIndex,
        pageSize: pagedSize,
        pagedViewModel: pagedViewModel,
        total: total,
        includeBackgroundDecoration: true,
      );
    }

    if (_pagedTransition.fromIndex < 0 ||
        _pagedTransition.fromIndex >= _pagedPages.length ||
        _pagedTransition.toIndex < 0 ||
        _pagedTransition.toIndex >= _pagedPages.length) {
      return _buildStaticPagedPage(
        colors: colors,
        pageIndex: safeIndex,
        pageSize: pagedSize,
        pagedViewModel: pagedViewModel,
        total: total,
        includeBackgroundDecoration: true,
      );
    }

    final fromPage = SelectionContainer.disabled(
      child: _buildStaticPagedPage(
        colors: colors,
        pageIndex: _pagedTransition.fromIndex,
        pageSize: pagedSize,
        pagedViewModel: pagedViewModel,
        total: total,
        includeBackgroundDecoration: true,
      ),
    );
    final toPage = SelectionContainer.disabled(
      child: _buildStaticPagedPage(
        colors: colors,
        pageIndex: _pagedTransition.toIndex,
        pageSize: pagedSize,
        pagedViewModel: pagedViewModel,
        total: total,
        includeBackgroundDecoration: true,
      ),
    );
    final effectRenderer = _pagedAnimationRendererRegistry.resolve(
      animationStyle,
    );

    return AnimatedBuilder(
      animation: _pagedTransitionController,
      builder: (context, _) {
        final progress = switchInCurve.transform(
          _pagedTransitionController.value.clamp(0.0, 1.0),
        );
        return effectRenderer.build(
          fromPage: fromPage,
          toPage: toPage,
          progress: progress,
          direction: _pagedTransition.direction.toDouble(),
        );
      },
    );
  }

  Widget _buildPagedPageContainer({
    required _ReaderThemeColors colors,
    required int pageIndex,
    required int total,
    required Size pageSize,
    required ReaderTextPagedViewModel pagedViewModel,
    bool includeBackgroundDecoration = false,
  }) {
    final pages = pagedViewModel.pagedPages;
    final layoutMetrics = pagedViewModel.surfaceMetrics;
    if (pageIndex < 0 || pageIndex >= pages.length) {
      return const SizedBox.shrink();
    }

    final content = Column(
      children: [
        if (_showsPagedPinnedChapterHeaderFor(_currentViewportKind))
          SelectionContainer.disabled(child: _buildPinnedChapterHeader(colors)),
        if (layoutMetrics.pagedHeaderReserve > 0)
          SelectionContainer.disabled(
            child: _buildPagedHeaderSection(colors, layoutMetrics),
          ),
        Expanded(
          child: ReaderPagedPageContent(
            model: pagedViewModel,
            pageIndex: pageIndex,
            paddingResolver: (_) => layoutMetrics.effectivePagePadding,
            resolvedSliceBuilder:
                (context, slice, defaultSlice) =>
                    _buildPagedResolvedSliceContent(
                      context: context,
                      slice: slice,
                      colors: colors,
                    ),
          ),
        ),
        SelectionContainer.disabled(
          child: _buildPagedFooterSection(
            colors: colors,
            index: pageIndex,
            total: total,
            layoutMetrics: layoutMetrics,
          ),
        ),
      ],
    );

    return SizedBox(
      width: pageSize.width,
      height: pageSize.height,
      child:
          includeBackgroundDecoration
              ? DecoratedBox(
                decoration: _buildReaderBackgroundDecoration(colors),
                child: content,
              )
              : content,
    );
  }

  Widget _buildPagedHeaderSection(
    _ReaderThemeColors colors,
    ReaderSurfaceMetrics layoutMetrics,
  ) {
    return const SizedBox.shrink();
  }

  Widget _buildPagedFooterSection({
    required _ReaderThemeColors colors,
    required int index,
    required int total,
    required ReaderSurfaceMetrics layoutMetrics,
  }) {
    if (layoutMetrics.pagedFooterReserve <= 0) {
      return const SizedBox.shrink();
    }
    final overlayModel = ReaderPageIndexOverlayModel.fromSettings(
      settings: _settings,
      layoutResolver: _layoutResolver,
      index: index,
      total: total,
      bottomInset: 0,
      safeBottomInset: 0,
      fadeProgress: _overlayControlsFadeProgress,
      rightItems: <String>[
        if (_settings.infoShowTime) _formatReaderInfoTime(_readerInfoNow),
        if (_settings.infoShowBattery) _readerBatteryLabel(),
      ],
    );
    final footerTopPadding =
        layoutMetrics.footerPadding.top +
        _settings.infoFooterPadding
            .clamp(
              ReaderSettings.minInfoBarPadding,
              ReaderSettings.maxInfoBarPadding,
            )
            .toDouble();
    final footerBottomPadding =
        layoutMetrics.safeInsets.bottom + layoutMetrics.footerPadding.bottom;
    final footer = SizedBox(
      height: layoutMetrics.pagedFooterReserve,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          overlayModel.horizontalPadding,
          footerTopPadding,
          overlayModel.horizontalPadding,
          footerBottomPadding,
        ),
        child: Opacity(
          opacity: overlayModel.opacity,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (overlayModel.showProgress)
                ReaderPageIndexBadge(
                  model: overlayModel.badge,
                  palette: _chromePalette(colors),
                ),
              if (overlayModel.rightLabel.isNotEmpty)
                Expanded(
                  child: Text(
                    overlayModel.rightLabel,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: colors.meta.withValues(alpha: 0.9),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else
                const Spacer(),
            ],
          ),
        ),
      ),
    );
    if (!_settings.infoFooterDividerEnabled) {
      return footer;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.divider.withValues(alpha: 0.4)),
        ),
      ),
      child: footer,
    );
  }

  Widget _buildPageIndexOverlay({
    required _ReaderThemeColors colors,
    required int index,
    required int total,
    required double bottomInset,
    double? safeBottomInset,
  }) {
    return AnimatedBuilder(
      animation: _overlayControlsController,
      builder: (context, _) {
        return ReaderPageIndexOverlay(
          model: ReaderPageIndexOverlayModel.fromSettings(
            settings: _settings,
            layoutResolver: _layoutResolver,
            index: index,
            total: total,
            bottomInset: bottomInset,
            safeBottomInset:
                safeBottomInset ?? _effectiveBottomSafeInset(context),
            fadeProgress: _overlayControlsFadeProgress,
            rightItems: <String>[
              if (_settings.infoShowTime) _formatReaderInfoTime(_readerInfoNow),
              if (_settings.infoShowBattery) _readerBatteryLabel(),
            ],
          ),
          palette: _chromePalette(colors),
        );
      },
    );
  }

  Widget _buildPagedResolvedSliceContent({
    required BuildContext context,
    required ReaderPagedResolvedSlice slice,
    required _ReaderThemeColors colors,
  }) {
    final paragraphIndex = slice.paragraphIndex;
    if (paragraphIndex == null ||
        paragraphIndex < 0 ||
        paragraphIndex >= _paragraphs.length) {
      return const SizedBox.shrink();
    }

    final paragraph = _paragraphs[paragraphIndex];
    final ranges =
        _bookmarkRangesByParagraph[paragraphIndex] ?? const <_BookmarkRange>[];
    final localRanges = <_BookmarkRange>[];
    if (ranges.isNotEmpty) {
      for (final range in ranges) {
        final overlapStart = max(range.start, slice.slice.start);
        final overlapEnd = min(range.end, slice.slice.end);
        if (overlapEnd <= overlapStart) {
          continue;
        }
        localRanges.add(
          _BookmarkRange(
            overlapStart - slice.slice.start,
            overlapEnd - slice.slice.start,
            hasHighlight: range.hasHighlight,
            isBold: range.isBold,
            isUnderline: range.isUnderline,
            isWavy: range.isWavy,
          ),
        );
      }
    }

    return Padding(
      padding: EdgeInsets.only(bottom: slice.spacingAfter),
      child: SizedBox(
        height: slice.measuredHeight > 0 ? slice.measuredHeight : null,
        child: Align(
          alignment: Alignment.topLeft,
          child: ReaderAnnotatedText(
            displayText: slice.displayText,
            indentLength: slice.indentLength,
            baseStyle: slice.textStyle,
            textAlign: slice.textAlign,
            textDirection: Directionality.of(context),
            highlightColor: colors.text,
            wavyColor: colors.text.withValues(alpha: 0.7),
            annotationRanges: localRanges
                .map(
                  (range) => ReaderTextAnnotationRange(
                    range.start,
                    range.end,
                    hasHighlight: range.hasHighlight,
                    isBold: range.isBold,
                    isUnderline: range.isUnderline,
                    isWavy: range.isWavy,
                  ),
                )
                .toList(growable: false),
            bodyDecorationEnabled:
                _settings.bodyTextDecorationStyle !=
                ReaderBodyTextDecorationStyle.none,
            bodyDecorationColor: Color(
              _settings.bodyTextDecorationColorValue ?? colors.text.toARGB32(),
            ),
            bodyDecorationStyle: _settings.bodyTextDecorationStyle,
            bodyDecorationThickness: _settings.bodyTextUnderlineThickness,
            bodyDecorationGap: _settings.bodyTextUnderlineGap,
            bodyDecorationDashLength: _settings.bodyTextUnderlineDashLength,
            bodyDecorationDashGapRatio: _settings.bodyTextUnderlineDashGapRatio,
            onTapUp: (details) {
              final renderBox = context.findRenderObject();
              final maxWidth =
                  renderBox is RenderBox ? renderBox.size.width : 0.0;
              final handled = _handleBookmarkTapInSlice(
                slice: slice.slice,
                paragraphText: paragraph,
                localPosition: details.localPosition,
                maxWidth: maxWidth,
                textStyle: slice.textStyle,
                textAlign: slice.textAlign,
              );
              if (handled) {
                _suppressNextReaderTap = true;
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCurlPageWidget({
    required _ReaderThemeColors colors,
    required int pageIndex,
    required int total,
    required Size pageSize,
    required ReaderTextPagedViewModel pagedViewModel,
    bool includeBackgroundDecoration = false,
  }) {
    final pages = pagedViewModel.pagedPages;
    final layoutMetrics = pagedViewModel.surfaceMetrics;
    if (pageIndex < 0 || pageIndex >= pages.length) {
      return const SizedBox.shrink();
    }

    final content = Column(
      children: [
        SelectionContainer.disabled(child: _buildPinnedChapterHeader(colors)),
        if (layoutMetrics.pagedHeaderReserve > 0)
          SelectionContainer.disabled(
            child: _buildPagedHeaderSection(colors, layoutMetrics),
          ),
        Expanded(
          child: ReaderPagedPageContent(
            model: pagedViewModel,
            pageIndex: pageIndex,
            paddingResolver: (_) => layoutMetrics.effectivePagePadding,
            resolvedSliceBuilder:
                (context, slice, defaultSlice) =>
                    _buildPagedResolvedSliceContent(
                      context: context,
                      slice: slice,
                      colors: colors,
                    ),
          ),
        ),
        SelectionContainer.disabled(
          child: _buildPagedFooterSection(
            colors: colors,
            index: pageIndex,
            total: total,
            layoutMetrics: layoutMetrics,
          ),
        ),
      ],
    );

    return SizedBox(
      width: pageSize.width,
      height: pageSize.height,
      child:
          includeBackgroundDecoration
              ? DecoratedBox(
                decoration: _buildReaderBackgroundDecoration(colors),
                child: content,
              )
              : content,
    );
  }

  Widget _buildCustomCurlPageStack({
    required _ReaderThemeColors colors,
    required int pageCount,
    required int safeIndex,
    required Size pagedSize,
    required ReaderTextPagedViewModel pagedViewModel,
  }) {
    final hasActiveCurlTarget =
        (_isCurlPreviewActive || _isCurlAutoTurning) &&
        pageCount > 0 &&
        _curlAnimationFromIndex >= 0 &&
        _curlAnimationFromIndex < pageCount &&
        _curlAnimationToIndex >= 0 &&
        _curlAnimationToIndex < pageCount &&
        _curlAnimationFromIndex != _curlAnimationToIndex;

    if (!hasActiveCurlTarget) {
      return _buildCurlPageWidget(
        colors: colors,
        pageIndex: safeIndex,
        total: pageCount,
        pageSize: pagedSize,
        pagedViewModel: pagedViewModel,
      );
    }

    final targetPage = SelectionContainer.disabled(
      child: _buildCurlPageWidget(
        colors: colors,
        pageIndex: _curlAnimationToIndex,
        total: pageCount,
        pageSize: pagedSize,
        pagedViewModel: pagedViewModel,
        includeBackgroundDecoration: true,
      ),
    );
    final currentPage = SelectionContainer.disabled(
      child: _buildCurlPageWidget(
        colors: colors,
        pageIndex: _curlAnimationFromIndex,
        total: pageCount,
        pageSize: pagedSize,
        pagedViewModel: pagedViewModel,
        includeBackgroundDecoration: true,
      ),
    );

    return AnimatedBuilder(
      animation: _curlAutoTurnController,
      child: targetPage,
      builder: (context, child) {
        final activeProgress =
            _isCurlPreviewActive
                ? _curlPreviewProgress
                : _curlAutoTurnController.value;
        if (activeProgress <= 0) {
          return currentPage;
        }
        final progress = activeProgress.clamp(0.0, 1.0).toDouble();
        return _curlPagedAnimationRenderer.build(
          currentPage: currentPage,
          targetPage: child ?? targetPage,
          progress: progress,
          direction: _curlAutoDirection,
          colors: CurlRendererColors(
            backgroundColor: colors.background,
            dividerColor: colors.divider,
            overlayColor: colors.overlay,
          ),
        );
      },
    );
  }

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

    final pages = _pagedPages;
    if (pages.isEmpty) {
      return;
    }

    final direction = delta < 0 ? 1 : -1;
    final currentIndex = _currentPageIndex.clamp(0, pages.length - 1);
    final targetIndex = currentIndex + direction;
    if (targetIndex < 0 || targetIndex >= pages.length) {
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
      final pageCount = _pagedPages.length;
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

    final pageCount = _pagedPages.length;
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
  }

  Future<void> _autoTurnCurlPage(int direction) async {
    if (_isCurlAutoTurning) {
      return;
    }

    final pages = _pagedPages;
    if (pages.isEmpty) {
      return;
    }

    final currentIndex = _currentPageIndex.clamp(0, pages.length - 1);
    if (direction < 0 && currentIndex <= 0) {
      await _jumpToAdjacentReadableChapter(forward: false);
      return;
    }

    if (direction > 0 && currentIndex >= pages.length - 1) {
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

  void _ensurePagination({required ReaderPaginationSpec spec}) {
    if (!mounted || !_isTextPagedViewport) {
      return;
    }
    final plan = _paginationEngine.buildEnsurePlan(
      ReaderPaginationEnsureRequest(
        spec: spec,
        signature: _buildPaginationSignature(spec: spec),
        currentState: _pagedPaginationState,
        hasExistingPages: _pagedPages.isNotEmpty,
        currentProgressRatio: _currentScrollRatio(),
      ),
    );
    if (!plan.shouldPaginate) {
      return;
    }

    final taskId = ++_paginationTaskId;
    _resetPagedTransitionState();
    _resetCurlAnimationState();

    setState(() {
      _pagedPaginationState = plan.buildLoadingState();
      _pagedPages = const [];
      _currentPageIndex = 0;
    });

    unawaited(
      _paginateCurrentChapter(
        taskId: taskId,
        spec: spec,
        signature: plan.signature,
      ),
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
    final result = await _paginationEngine.paginateParagraphs(
      ReaderPaginationRequest(
        paragraphs: paragraphs,
        spec: spec,
        paragraphStyle: _paragraphTextStyle(
          colors,
        ).copyWith(color: Colors.black),
        paragraphModels: _buildPaginationParagraphModels(colors, paragraphs),
        textScaler: MediaQuery.textScalerOf(context),
        shouldAbort: () => !mounted || taskId != _paginationTaskId,
      ),
    );
    if (result == null) {
      return;
    }
    final pages = result.pages;

    if (pages.isEmpty) {
      if (!mounted || taskId != _paginationTaskId) {
        return;
      }
      setState(() {
        _pagedPaginationState = _pagedPaginationState.copyWith(
          isPaginating: false,
          pendingRestoreRatio: null,
        );
        _pagedPages = const [];
        _resetCurlAnimationState();
      });
      return;
    }

    if (!mounted || taskId != _paginationTaskId) {
      return;
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
      );
      _pagedPages = pages;
      _currentPageIndex = targetIndex;
    });

    _scheduleProgressSave();
  }

  Widget _buildTapAwareBody({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gestureInsets = MediaQuery.systemGestureInsetsOf(context);
        final enableSwipeTurn = _isSwipePaginationEnabled();
        final enableCurlPreview =
            enableSwipeTurn &&
            _currentPagedAnimationStyle() == ReaderPageAnimationStyle.curl;
        return Listener(
          behavior: HitTestBehavior.translucent,
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
              _swipeDragCurrentDx = event.localPosition.dx;
            }
          },
          onPointerMove: (event) {
            if (event.pointer != _tapPointerId) {
              return;
            }
            if (enableSwipeTurn) {
              _swipeDragCurrentDx = event.localPosition.dx;
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
            final size = constraints.biggest;
            final downTime = _tapPointerDownTime;
            final elapsedMs =
                downTime == null
                    ? 0
                    : DateTime.now().difference(downTime).inMilliseconds;
            final dx =
                (_swipeDragCurrentDx ?? event.localPosition.dx) -
                (_swipeDragStartDx ?? event.localPosition.dx);
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
    _swipeDragCurrentDx = null;

    if (!_isSwipePaginationEnabled() || startDx == null || currentDx == null) {
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
    _swipeDragCurrentDx = null;
  }

  bool _isPrimaryReaderPointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.touch) {
      return true;
    }
    return event.buttons == kPrimaryButton;
  }

  TextStyle _paragraphTextStyle(_ReaderThemeColors colors) {
    final customColorValue = _settings.bodyTextColorValue;
    return _typographyResolver.resolveBodyStyle(
      settings: _settings,
      color: customColorValue == null ? colors.text : Color(customColorValue),
    );
  }

  TextStyle _readerBlockTextStyle(
    ReaderRenderTextItem item,
    _ReaderThemeColors colors,
  ) {
    return resolveReaderTextBlockPresentation(
      settings: _settings,
      primaryTextColor: colors.text,
      secondaryTextColor: colors.meta,
      item: item,
      isLast: false,
    ).textStyle;
  }

  double _readerBlockSpacing(
    ReaderRenderTextItem item, {
    required bool isLast,
  }) {
    final colors = _resolveThemeColors(_effectiveReaderThemeMode(), _settings);
    return resolveReaderTextBlockPresentation(
      settings: _settings,
      primaryTextColor: colors.text,
      secondaryTextColor: colors.meta,
      item: item,
      isLast: isLast,
    ).spacingAfter;
  }

  TextAlign _textAlignForRenderItem(ReaderRenderTextItem item) {
    final colors = _resolveThemeColors(_effectiveReaderThemeMode(), _settings);
    return resolveReaderTextBlockPresentation(
      settings: _settings,
      primaryTextColor: colors.text,
      secondaryTextColor: colors.meta,
      item: item,
      isLast: false,
    ).textAlign;
  }

  String _displayTextForRenderItem(ReaderRenderTextItem item) {
    final colors = _resolveThemeColors(_effectiveReaderThemeMode(), _settings);
    return resolveReaderTextBlockPresentation(
      settings: _settings,
      primaryTextColor: colors.text,
      secondaryTextColor: colors.meta,
      item: item,
      isLast: false,
    ).displayText;
  }

  int _indentLengthForRenderItem(ReaderRenderTextItem item) {
    final colors = _resolveThemeColors(_effectiveReaderThemeMode(), _settings);
    return resolveReaderTextBlockPresentation(
      settings: _settings,
      primaryTextColor: colors.text,
      secondaryTextColor: colors.meta,
      item: item,
      isLast: false,
    ).indentLength;
  }

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
    if (sourceId == null || sourceId.isEmpty || _chapters.isEmpty) {
      if (!mounted) {
        return;
      }
      _showMessage('缺少目录信息，无法缓存。');
      return;
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
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
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
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
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
    final scale = lerpDouble(_kShellOverlayCollapsedScale, 1.0, slideProgress)!;

    return Transform.translate(
      offset: Offset(0, translateY),
      child: Opacity(
        opacity: fadeProgress,
        child: Transform.scale(scale: scale, child: child),
      ),
    );
  }

  Future<void> _toggleDayNightMode() async {
    final isDarkMode = _settings.themeMode == ReaderThemeMode.dark;
    final currentBackgroundImage = _settings.backgroundImageBase64?.trim();
    if (!isDarkMode &&
        currentBackgroundImage != null &&
        currentBackgroundImage.isNotEmpty) {
      _lightModeBackgroundImageBackup = currentBackgroundImage;
    }

    final nextSettings = switch (isDarkMode) {
      true => _settings.copyWith(
        themeMode: ReaderThemeMode.light,
        backgroundStyle: ReaderBackgroundStyle.plain,
        backgroundTone: ReaderBackgroundTone.surface,
        backgroundImageBase64:
            (_settings.backgroundImageBase64?.trim().isEmpty ?? true)
                ? _lightModeBackgroundImageBackup
                : _settings.backgroundImageBase64,
      ),
      false => _settings.copyWith(
        themeMode: ReaderThemeMode.dark,
        backgroundStyle: ReaderBackgroundStyle.plain,
        backgroundTone: ReaderBackgroundTone.pureBlack,
        clearBackgroundImage: true,
      ),
    };

    if (!mounted) {
      return;
    }

    setState(() {
      _settings = nextSettings;
    });

    await _preferencesService.saveSettings(nextSettings);
    await ref
        .read(appThemeModeProvider.notifier)
        .setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);
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

  String _bodyMarginDisplayValue(ReaderSettings settings) {
    return '上${settings.bodyMarginTop.round()} 下${settings.bodyMarginBottom.round()} 左${settings.bodyMarginLeft.round()} 右${settings.bodyMarginRight.round()}';
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
    return AppLayout.sheetHeightFactor(
      context,
      compact: compact,
      regular: regular,
      large: large,
    );
  }

  Future<_ChapterLoadSnapshot> _fetchChapterContentSnapshot({
    required String sourceId,
    required String chapterId,
    required String chapterUrl,
    required String? chapterTitle,
    required int? chapterIndex,
  }) async {
    final contentProvider = _requireContentProvider(
      sourceId: sourceId,
      stage: ErrorStage.content,
    );
    final contentResult = await contentProvider.loadChapterContent(
      sourceId: sourceId,
      chapterUrl: chapterUrl,
      bookId: _currentBookId,
      bookTitle: _bookTitle,
      detailUrl: _detailUrl,
      chapterId: chapterId,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
    );

    return _ChapterLoadSnapshot(
      result: contentResult,
      isCached: contentResult.fromCache,
    );
  }

  Future<void> _applyLoadedChapterSnapshot({
    required _ChapterLoadSnapshot snapshot,
    required String chapterId,
    required String chapterUrl,
    required String? chapterTitle,
    required int? chapterIndex,
    required double targetRatio,
    required int requestToken,
    bool commitChapterIdentity = false,
  }) async {
    if (!_isActiveChapterContentRequest(requestToken)) {
      return;
    }

    final resolvedContinuousIndex = _chapterLoadPlanner
        .resolveContinuousChapterIndex(
          chapterIndex: chapterIndex,
          chapters: _chapters,
          chapterId: chapterId,
          chapterUrl: chapterUrl,
        );
    final resolvedContinuousChapter =
        resolvedContinuousIndex >= 0 &&
                resolvedContinuousIndex < _chapters.length
            ? _chapters[resolvedContinuousIndex]
            : null;

    List<String>? precomputedParagraphs;
    List<List<ReaderPagedSlice>>? precomputedPagedPages;
    int? precomputedPageIndex;
    String? precomputedPaginationSignature;

    final canPrepaginate = _chapterLoadPlanner.canPrepaginate(
      isPagedTextReaderEnabled: _isPagedTextReaderEnabled(),
      hasImages: snapshot.result.imageUrls.isNotEmpty,
      content: snapshot.result.content,
      maxWidth: _lastPaginationSpec?.contentWidth,
      maxHeight: _lastPaginationSpec?.contentHeight,
    );

    if (canPrepaginate) {
      final paragraphs = snapshot.result.document.paragraphs;
      final effectiveParagraphs =
          paragraphs.isEmpty ? <String>[snapshot.result.content] : paragraphs;
      final paginationSpec = _lastPaginationSpec;
      if (paginationSpec != null) {
        final textScaler = MediaQuery.textScalerOf(context);
        final signature = _buildPaginationSignature(
          spec: paginationSpec,
          chapterIdOverride: commitChapterIdentity ? chapterId : _chapterId,
        );
        final cachedLayout = await _loadPrecomputedChapterLayout(
          sourceId: _sourceId ?? '',
          chapterUrl: chapterUrl,
          signature: signature,
        );
        if (cachedLayout != null) {
          precomputedParagraphs = cachedLayout.paragraphs;
          precomputedPagedPages = cachedLayout.pagedPages;
          precomputedPageIndex = _chapterLoadPlanner.resolvePageIndexByRatio(
            targetRatio: targetRatio,
            pageCount: cachedLayout.pagedPages.length,
          );
          precomputedPaginationSignature = cachedLayout.paginationSignature;
        } else {
          final colors = _resolveThemeColors(
            _effectiveReaderThemeMode(),
            _settings,
          );
          final paginationResult = await _paginationEngine.paginateParagraphs(
            ReaderPaginationRequest(
              paragraphs: effectiveParagraphs,
              spec: paginationSpec,
              paragraphStyle: _paragraphTextStyle(
                colors,
              ).copyWith(color: Colors.black),
              paragraphModels: _buildPaginationParagraphModels(
                colors,
                effectiveParagraphs,
              ),
              textScaler: textScaler,
            ),
          );
          if (!_isActiveChapterContentRequest(requestToken)) {
            return;
          }
          final pages = paginationResult?.pages;
          if (pages != null && pages.isNotEmpty) {
            precomputedParagraphs = effectiveParagraphs;
            precomputedPagedPages = pages;
            precomputedPageIndex = _chapterLoadPlanner.resolvePageIndexByRatio(
              targetRatio: targetRatio,
              pageCount: pages.length,
            );
            precomputedPaginationSignature = signature;
          }
        }
      }
    }

    setState(() {
      if (commitChapterIdentity) {
        _currentIndex = chapterIndex;
        _chapterId = chapterId;
        _chapterUrl = chapterUrl;
        _chapterTitle = _chapterLoadPlanner.resolveChapterTitleAfterLoad(
          commitChapterIdentity: true,
          loadedDisplayChapterTitle: snapshot.result.displayChapterTitle,
          targetChapterTitle: chapterTitle,
          currentChapterTitle: _chapterTitle,
        );
      }
      if (!commitChapterIdentity) {
        _chapterTitle = _chapterLoadPlanner.resolveChapterTitleAfterLoad(
          commitChapterIdentity: false,
          loadedDisplayChapterTitle: snapshot.result.displayChapterTitle,
          targetChapterTitle: chapterTitle,
          currentChapterTitle: _chapterTitle,
        );
      }
      _isCurrentChapterCached = snapshot.isCached;
      _errorText = null;
      _setContent(
        snapshot.result.content,
        imageUrls: snapshot.result.imageUrls,
        imageHeaders: snapshot.result.imageHeaders,
        document: snapshot.result.document,
        precomputedParagraphs: precomputedParagraphs,
        precomputedPagedPages: precomputedPagedPages,
        precomputedCurrentPageIndex: precomputedPageIndex,
        precomputedPaginationSignature: precomputedPaginationSignature,
      );
      if (resolvedContinuousChapter != null) {
        _replaceContinuousTextFlowWithCurrentChapter(
          chapter: resolvedContinuousChapter,
          chapterIndex: resolvedContinuousIndex,
          snapshot: snapshot,
        );
      } else {
        _continuousTextChapters = const <_ContinuousTextChapter>[];
      }
      _pagedPaginationState = ReaderPaginationSessionState(
        signature: precomputedPaginationSignature,
        pendingRestoreRatio:
            precomputedPaginationSignature == null ? targetRatio : null,
      );
    });

    _restoreScrollPosition(targetRatio);

    await _saveProgress();
    _hasPromptedMissingSourceSwitch = false;
    final preloadTaskToken = ++_preloadTaskToken;
    unawaited(_preloadNeighbors(taskToken: preloadTaskToken));
  }

  Future<bool> _tryHydrateVisibleContentFromCache() async {
    final sourceId = (_sourceId ?? '').trim();
    final chapterUrl = (_chapterUrl ?? '').trim();
    if (sourceId.isEmpty || chapterUrl.isEmpty) {
      return false;
    }

    try {
      final payload = await _cachedChapterStore.getCachedPayload(
        sourceId: sourceId,
        chapterUrl: chapterUrl,
      );
      if (payload == null || payload.isEmpty) {
        return false;
      }

      final decoded = _chapterCacheDecoder.decode(payload);
      final previewProgress = _bootstrapProgressForCurrentChapter();
      var previewRatio = 0.0;
      if (!mounted) {
        return false;
      }

      final resolvedCurrentChapter =
          _currentIndex != null &&
                  _currentIndex! >= 0 &&
                  _currentIndex! < _chapters.length
              ? _chapters[_currentIndex!]
              : null;

      setState(() {
        _isCurrentChapterCached = true;
        _errorText = null;
        _setContent(
          decoded.content,
          imageUrls: decoded.imageUrls,
          imageHeaders: decoded.imageHeaders,
        );
        previewRatio = _resolveDocumentRestoreRatio(progress: previewProgress);
        if (resolvedCurrentChapter != null &&
            _shouldUseContinuousTextFlow &&
            decoded.imageUrls.isEmpty &&
            decoded.content.trim().isNotEmpty) {
          _continuousTextChapters = <_ContinuousTextChapter>[
            _ContinuousTextChapter(
              chapterId: _chapterId,
              chapterUrl: (_chapterUrl ?? '').trim(),
              chapterTitle: resolvedCurrentChapter.title.trim(),
              displayTitle:
                  (_chapterTitle ?? resolvedCurrentChapter.title).trim(),
              chapterIndex: _currentIndex!,
              content: decoded.content,
              document: _document,
              paragraphs:
                  _paragraphs.isEmpty
                      ? List<String>.unmodifiable(<String>[decoded.content])
                      : List<String>.unmodifiable(_paragraphs),
              isCached: true,
            ),
          ];
        } else {
          _continuousTextChapters = const <_ContinuousTextChapter>[];
        }
        _pagedPaginationState = _pagedPaginationState.copyWith(
          pendingRestoreRatio: previewRatio,
        );
      });

      if (previewProgress != null) {
        _bootstrapProgress = null;
      }
      _restoreScrollPosition(previewRatio);
      _scheduleReadingRecordSessionStart(initialRatio: previewRatio);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _loadCurrentChapter({
    double? initialScrollRatio,
    ReaderLogicalPosition? initialLogicalPosition,
    String? sourceIdOverride,
    String? chapterIdOverride,
    String? chapterUrlOverride,
    String? chapterTitleOverride,
    int? chapterIndexOverride,
    bool commitChapterIdentity = false,
  }) async {
    if (!mounted) {
      return false;
    }
    _cancelBackgroundRefreshConflictForCurrentBook();
    final lease = await _taskScheduler.acquire(
      scene: SourceRuntimeSchedulerScene.reader,
      conflictKeys: _currentConflictKeys(),
    );
    if (lease == null) {
      return false;
    }
    final requestToken = ++_chapterContentRequestToken;

    double? readingRecordStartRatio;
    final request = _chapterLoadPlanner.resolveLoadRequest(
      sourceIdOverride: sourceIdOverride,
      chapterIdOverride: chapterIdOverride,
      chapterUrlOverride: chapterUrlOverride,
      chapterTitleOverride: chapterTitleOverride,
      currentSourceId: _sourceId,
      currentChapterId: _chapterId,
      currentChapterUrl: _chapterUrl,
      currentChapterTitle: _chapterTitle,
    );
    if (request == null) {
      _stopAutoRead();
      setState(() {
        _errorText = '当前章节信息不完整。';
      });
      return false;
    }

    final suppressLoadingUi = await _shouldSuppressChapterLoadingUi(
      sourceId: request.sourceId,
      chapterUrl: request.chapterUrl,
    );

    _stopAutoRead();
    _resetScrollEdgeAdvanceState();
    _commitReadingRecordSession();
    setState(() {
      _isLoadingContent = true;
      _errorText = null;
    });
    if (suppressLoadingUi) {
      _clearDelayedLoadingUi();
    } else {
      _scheduleBlockingLoadingCard();
      _scheduleChapterLoadingIndicator();
    }

    try {
      final resolvedIndex = _chapterLoadPlanner.resolveFetchChapterIndex(
        chapterIndexOverride: chapterIndexOverride,
        currentChapterIndex: _currentIndex,
        chapters: _chapters,
        chapterUrl: request.chapterUrl,
      );
      final snapshot = await _fetchChapterContentSnapshot(
        sourceId: request.sourceId,
        chapterId: request.chapterId,
        chapterUrl: request.chapterUrl,
        chapterTitle: request.chapterTitle,
        chapterIndex: resolvedIndex,
      );

      if (!_isActiveChapterContentRequest(requestToken)) {
        return false;
      }

      final targetRatio = _resolveDocumentRestoreRatio(
        document: snapshot.result.document,
        logicalPosition: initialLogicalPosition,
        fallback: initialScrollRatio ?? 0.0,
      );
      await _applyLoadedChapterSnapshot(
        snapshot: snapshot,
        chapterId: request.chapterId,
        chapterUrl: request.chapterUrl,
        chapterTitle: request.chapterTitle,
        chapterIndex: resolvedIndex,
        targetRatio: targetRatio,
        requestToken: requestToken,
        commitChapterIdentity: commitChapterIdentity,
      );
      if (!_isActiveChapterContentRequest(requestToken)) {
        return false;
      }
      readingRecordStartRatio = targetRatio;
      return true;
    } on AppException catch (error) {
      if (!_isActiveChapterContentRequest(requestToken)) {
        return false;
      }
      final readableError = _toUserReadableError(error);
      _recordReaderFailure(message: readableError, errorCode: error.code);
      setState(() {
        _errorText = readableError;
      });
      _maybePromptSwitchSourceForMissingSource(error.code);
      final switched = await _tryAutoSwitchSourceOnFailure();
      return switched;
    } catch (_) {
      if (!_isActiveChapterContentRequest(requestToken)) {
        return false;
      }
      const fallbackError = '加载正文失败。';
      _recordReaderFailure(message: fallbackError);
      setState(() {
        _errorText = fallbackError;
      });
      final switched = await _tryAutoSwitchSourceOnFailure();
      return switched;
    } finally {
      if (_isActiveChapterContentRequest(requestToken)) {
        _clearDelayedLoadingUi();
        setState(() {
          _isLoadingContent = false;
        });
        unawaited(_syncVolumeKeyPageInterception());
        if (readingRecordStartRatio != null) {
          _scheduleReadingRecordSessionStart(
            initialRatio: readingRecordStartRatio,
          );
        }
        _reconcileAutoRead(restart: true);
      }
      lease.release();
    }
  }

  bool _isActiveChapterContentRequest(int requestToken) {
    return mounted && requestToken == _chapterContentRequestToken;
  }

  Future<bool> _shouldSuppressChapterLoadingUi({
    required String sourceId,
    required String chapterUrl,
  }) async {
    final normalizedSourceId = sourceId.trim();
    final normalizedChapterUrl = chapterUrl.trim();
    if (normalizedSourceId.isEmpty || normalizedChapterUrl.isEmpty) {
      return false;
    }
    if (LocalReaderIdentity.isLocalSourceId(normalizedSourceId)) {
      return true;
    }
    try {
      return await _cachedChapterStore.hasCachedPayload(
        sourceId: normalizedSourceId,
        chapterUrl: normalizedChapterUrl,
      );
    } catch (_) {
      return false;
    }
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

  Future<void> _preloadNeighbors({required int taskToken}) async {
    final sourceId = _sourceId;
    final currentIndex = _currentIndex;
    if (sourceId == null || currentIndex == null || _chapters.isEmpty) {
      return;
    }

    final normalizedSourceId = sourceId.trim();
    if (normalizedSourceId.isEmpty) {
      return;
    }
    final isLocalSource = LocalReaderIdentity.isLocalSourceId(
      normalizedSourceId,
    );
    final forwardPreloadCount =
        !isLocalSource && _isInBookshelf
            ? _kBookshelfForwardCacheChapterCount
            : _kForwardPreloadChapterCount;

    final preloadIndexes = <int>{};

    for (var offset = 1; offset <= _kBackwardPreloadChapterCount; offset++) {
      final index = currentIndex - offset;
      if (index >= 0) {
        preloadIndexes.add(index);
      }
    }

    for (var offset = 1; offset <= forwardPreloadCount; offset++) {
      final index = currentIndex + offset;
      if (index < _chapters.length) {
        preloadIndexes.add(index);
      }
    }

    if (preloadIndexes.isEmpty) {
      return;
    }

    final orderedIndexes = preloadIndexes.toList(growable: false)..sort();

    for (final index in orderedIndexes) {
      if (!mounted || taskToken != _preloadTaskToken) {
        return;
      }

      final chapter = _chapters[index];
      final chapterUrl = chapter.chapterUrl.trim();
      if (chapterUrl.isEmpty) {
        continue;
      }

      final nextChapterUrl =
          index < _chapters.length - 1
              ? _chapters[index + 1].chapterUrl.trim()
              : '';

      try {
        final preloadProvider = _requireContentProvider(
          sourceId: normalizedSourceId,
          stage: ErrorStage.content,
        );
        final result = await preloadProvider.loadChapterContent(
          sourceId: normalizedSourceId,
          chapterUrl: chapterUrl,
          bookId: _currentBookId,
          bookTitle: _bookTitle,
          detailUrl: _detailUrl,
          chapterId: chapter.id,
          chapterIndex: index,
          chapterTitle: chapter.title,
          nextChapterUrl: nextChapterUrl.isEmpty ? null : nextChapterUrl,
        );
        if (_isTextPagedViewport &&
            result.imageUrls.isEmpty &&
            result.content.trim().isNotEmpty &&
            _lastPaginationSpec != null &&
            _lastPaginationSpec!.contentWidth >= 20 &&
            _lastPaginationSpec!.contentHeight >= 40) {
          final paragraphs = result.document.paragraphs;
          final effectiveParagraphs =
              paragraphs.isEmpty ? <String>[result.content] : paragraphs;
          final signature = _buildPaginationSignature(
            spec: _lastPaginationSpec!,
            chapterIdOverride: chapter.id,
          );
          if (!mounted) {
            return;
          }
          final textScaler = MediaQuery.textScalerOf(context);
          if (await _loadPrecomputedChapterLayout(
                sourceId: normalizedSourceId,
                chapterUrl: chapterUrl,
                signature: signature,
              ) ==
              null) {
            final colors = _resolveThemeColors(
              _effectiveReaderThemeMode(),
              _settings,
            );
            final paginationResult = await _paginationEngine.paginateParagraphs(
              ReaderPaginationRequest(
                paragraphs: effectiveParagraphs,
                spec: _lastPaginationSpec!,
                paragraphStyle: _paragraphTextStyle(
                  colors,
                ).copyWith(color: Colors.black),
                paragraphModels: _buildPaginationParagraphModels(
                  colors,
                  effectiveParagraphs,
                ),
                textScaler: textScaler,
                shouldAbort: () => !mounted || taskToken != _preloadTaskToken,
              ),
            );
            final pages = paginationResult?.pages;
            if (pages != null && pages.isNotEmpty) {
              _storePrecomputedChapterLayout(
                sourceId: normalizedSourceId,
                chapterUrl: chapterUrl,
                layout: ReaderPrecomputedChapterLayout(
                  paragraphs: effectiveParagraphs,
                  pagedPages: pages,
                  paginationSignature: signature,
                ),
              );
            }
          }
        }
      } catch (_) {
        // Preload failures should not interrupt active reading.
      }
    }
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

  void _showMessage(
    String text, {
    Duration duration = _kReaderSnackDuration,
    String? dedupeKey,
  }) {
    _showReaderSnackBar(text: text, duration: duration, dedupeKey: dedupeKey);
  }

  void _showChapterBoundaryHint({required bool isFirst}) {
    if (_isBackNavigationInteractionCoolingDown) {
      return;
    }
    _showMessage(
      isFirst ? '已经是第一章。' : '已经是最后一章。',
      duration: _kReaderBoundarySnackDuration,
      dedupeKey: isFirst ? 'boundary_first_chapter' : 'boundary_last_chapter',
    );
  }

  void _showReaderSnackBar({
    required String text,
    Duration duration = _kReaderSnackDuration,
    String? dedupeKey,
    String? actionLabel,
    VoidCallback? onActionPressed,
    bool replaceCurrent = true,
  }) {
    if (!mounted) {
      return;
    }

    final now = DateTime.now();
    final resolvedKey = (dedupeKey ?? text).trim();
    if (resolvedKey.isNotEmpty &&
        _lastReaderSnackKey == resolvedKey &&
        _lastReaderSnackAt != null &&
        now.difference(_lastReaderSnackAt!) < _kReaderSnackDedupWindow) {
      return;
    }
    if (resolvedKey.isNotEmpty) {
      _lastReaderSnackKey = resolvedKey;
      _lastReaderSnackAt = now;
    }

    final messenger = ScaffoldMessenger.of(context);
    if (replaceCurrent) {
      messenger.hideCurrentSnackBar();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    SnackBarAction? snackAction;
    final normalizedActionLabel = actionLabel?.trim() ?? '';
    if (normalizedActionLabel.isNotEmpty && onActionPressed != null) {
      snackAction = SnackBarAction(
        label: normalizedActionLabel,
        textColor: colorScheme.primary,
        onPressed: onActionPressed,
      );
    }

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 12 + bottomSafe),
        elevation: 0,
        duration: duration,
        dismissDirection: DismissDirection.down,
        backgroundColor: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        content: Text(
          text,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        action: snackAction,
      ),
    );
  }

  void _recordReaderFailure({required String message, ErrorCode? errorCode}) {
    _readerErrorCenterService.addFailure(
      bookId: _currentBookId,
      chapterId: _chapterId,
      chapterTitle: _chapterTitle ?? '',
      message: message,
      bookTitle: _bookTitle,
      sourceId: _sourceId,
      detailUrl: _detailUrl,
      chapterUrl: _chapterUrl,
      errorCode: errorCode,
    );
  }

  void _maybePromptSwitchSourceForMissingSource(ErrorCode? code) {
    if (!_canSwitchSource) {
      return;
    }
    if (code != ErrorCode.unknownSource ||
        !mounted ||
        _hasPromptedMissingSourceSwitch ||
        _isSwitchSourceLoading) {
      return;
    }
    _hasPromptedMissingSourceSwitch = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _isSwitchSourceLoading) {
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('当前书源不可用'),
            content: const Text('该书源可能已被删除或停用，是否现在切换到其他书源？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('稍后'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('立即换源'),
              ),
            ],
          );
        },
      );
      if (confirmed == true && mounted) {
        await _showSwitchSourceSheet();
      }
    });
  }

  Future<void> showSettingsSheetGroupedPreview({
    _ReaderSettingsTab initialTab = _ReaderSettingsTab.reading,
  }) async {
    _stopAutoReadSession();
    final shouldRestoreOverlay = _showOverlayControls;
    if (shouldRestoreOverlay) {
      _hideOverlayControls(resumeAutoRead: false, syncSystemUi: false);
    }

    var draft = _settings;
    var isPersistingDraft = false;
    var activeSettingsTab =
        initialTab == _ReaderSettingsTab.interface
            ? ReaderSettingsSheetTab.basic
            : ReaderSettingsSheetTab.advanced;
    String? activeSettingsGroupKey;
    Timer? persistDraftTimer;
    const settingsPresetService = ReaderSettingsPresetService();

    String fingerprint(ReaderSettings settings) {
      return jsonEncode(settings.copyWith(autoReadEnabled: false).toJson());
    }

    var persistedFingerprint = fingerprint(_settings);

    Future<void> persistDraftNow(ReaderSettings settings) async {
      final normalized = settings.copyWith(autoReadEnabled: false);
      final nextFingerprint = fingerprint(normalized);
      if (nextFingerprint == persistedFingerprint || isPersistingDraft) {
        return;
      }
      isPersistingDraft = true;
      try {
        await _preferencesService.saveSettings(normalized);
        persistedFingerprint = nextFingerprint;
      } catch (_) {
        // Keep in-memory preview even when persistence fails.
      } finally {
        isPersistingDraft = false;
      }
    }

    void schedulePersistDraft() {
      persistDraftTimer?.cancel();
      persistDraftTimer = Timer(const Duration(milliseconds: 220), () {
        if (!mounted) {
          return;
        }
        unawaited(persistDraftNow(draft));
      });
    }

    void previewDraftSettings() {
      if (!mounted) {
        return;
      }
      schedulePersistDraft();
      final currentFingerprint = fingerprint(_settings);
      final draftFingerprint = fingerprint(draft);
      if (currentFingerprint == draftFingerprint) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || fingerprint(_settings) == fingerprint(draft)) {
          return;
        }
        _applyReaderSettingsWithModeRestore(nextSettings: draft);
      });
    }

    String currentFontLabel() {
      if (draft.fontSource == ReaderFontSource.custom) {
        final familyKey = draft.fontFamilyKey;
        if (familyKey != null) {
          for (final entry in _customFonts) {
            if (entry.fontFamilyKey == familyKey) {
              return entry.displayName;
            }
          }
        }
        return '自定义字体';
      }
      return switch (draft.systemFontPreset) {
        ReaderSystemFontPreset.defaultSans => '系统默认',
        ReaderSystemFontPreset.serif => '衬线',
        ReaderSystemFontPreset.monospace => '等宽',
      };
    }

    final readerModalTheme = _readerModalTheme();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: false,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.04),
      builder: (bottomSheetContext) {
        return Theme(
          data: readerModalTheme,
          child: StatefulBuilder(
            builder: (sheetContext, setModalState) {
              final mediaQuery = MediaQuery.of(sheetContext);
              final keyboardInset = mediaQuery.viewInsets.bottom;
              final safeBottom = mediaQuery.padding.bottom;
              final width = mediaQuery.size.width;
              final sheetHorizontal = width >= 840 ? 24.0 : 12.0;
              final textSheetMaxWidth = AppLayout.pageContentMaxWidth(
                sheetContext,
                maxWidth: 760,
              );

              void updateDraft(ReaderSettings next) {
                setModalState(() {
                  draft = next;
                });
                previewDraftSettings();
              }

              final settingsSheetState = ReaderSettingsSheetState.fromSettings(
                settings: draft,
                showInterfaceSettings:
                    activeSettingsTab == ReaderSettingsSheetTab.basic,
                currentFontLabel: currentFontLabel(),
                activeGroupKey: activeSettingsGroupKey,
                activeTab: activeSettingsTab,
                showsPinnedChapterHeader: _showsPinnedChapterHeader,
                showsBatteryWarning: draft.infoShowBattery,
              );
              final settingsSheetCallbacks = ReaderSettingsSheetCallbacks(
                onBack: () {
                  setModalState(() {
                    activeSettingsGroupKey = null;
                  });
                },
                onTabChanged: (tab) {
                  setModalState(() {
                    activeSettingsTab = tab;
                    activeSettingsGroupKey = null;
                  });
                },
                onAdvancedGroupChanged: (group) {
                  setModalState(() {
                    activeSettingsGroupKey =
                        group == null
                            ? null
                            : readerSettingsSheetGroupStorageKey(group);
                  });
                },
                onSettingsChanged: updateDraft,
                onTypographyPresetSelected:
                    (preset) => updateDraft(
                      settingsPresetService.applyTypographyPreset(
                        draft,
                        preset,
                      ),
                    ),
                onSpacingPresetSelected:
                    (preset) => updateDraft(
                      settingsPresetService.applySpacingPreset(draft, preset),
                    ),
                onChapterHeaderPresetSelected:
                    (preset) => updateDraft(
                      settingsPresetService.applyChapterHeaderPreset(
                        draft,
                        preset,
                      ),
                    ),
                onInfoStylePresetSelected:
                    (preset) => updateDraft(
                      settingsPresetService.applyInfoStylePreset(draft, preset),
                    ),
                onFontPresetSelected:
                    (preset) => updateDraft(
                      settingsPresetService.applyFontPreset(draft, preset),
                    ),
              );

              return _buildFloatingReaderSettingsSheet(
                context: sheetContext,
                readerModalTheme: readerModalTheme,
                keyboardInset: keyboardInset,
                safeBottom: safeBottom,
                sheetHorizontal: sheetHorizontal,
                maxWidth: textSheetMaxWidth,
                heightFactor: _adaptiveReaderSheetHeightFactor(
                  sheetContext,
                  compact: 0.66,
                  regular: 0.6,
                  large: 0.56,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: Column(
                    children: [
                      Container(
                        width: 42,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            sheetContext,
                          ).colorScheme.outlineVariant.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      Expanded(
                        child: ReaderSettingsSheet(
                          title:
                              settingsSheetState.activeGroupDescriptor?.title ??
                              (activeSettingsTab == ReaderSettingsSheetTab.basic
                                  ? '基础设置'
                                  : '高级设置'),
                          state: settingsSheetState,
                          callbacks: settingsSheetCallbacks,
                          onBack: settingsSheetCallbacks.onBack,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    persistDraftTimer?.cancel();
    await persistDraftNow(draft);
    if (mounted && shouldRestoreOverlay) {
      _setOverlayControlsVisibility(true);
    }
  }

  Future<void> _showSettingsSheet({
    _ReaderSettingsTab initialTab = _ReaderSettingsTab.reading,
  }) async {
    _stopAutoReadSession();
    final shouldRestoreOverlay = _showOverlayControls;
    if (shouldRestoreOverlay) {
      _hideOverlayControls(resumeAutoRead: false, syncSystemUi: false);
    }

    var draft = _settings;
    final isMangaChapter = _isMangaChapter;
    var availableCustomFonts = List<ReaderCustomFontEntry>.from(_customFonts);
    var startAutoReadAfterApply = false;
    var isPersistingDraft = false;
    var activeSettingsTab =
        initialTab == _ReaderSettingsTab.interface
            ? ReaderSettingsSheetTab.basic
            : ReaderSettingsSheetTab.advanced;
    String? activeSettingsGroupKey;
    Timer? persistDraftTimer;
    const settingsGroupingService = ReaderSettingsGroupingService();

    String fingerprint(ReaderSettings settings) {
      return jsonEncode(settings.copyWith(autoReadEnabled: false).toJson());
    }

    var persistedFingerprint = fingerprint(_settings);

    Future<void> persistDraftNow(ReaderSettings settings) async {
      final normalized = settings.copyWith(autoReadEnabled: false);
      final nextFingerprint = fingerprint(normalized);
      if (nextFingerprint == persistedFingerprint || isPersistingDraft) {
        return;
      }

      isPersistingDraft = true;
      try {
        await _preferencesService.saveSettings(normalized);
        persistedFingerprint = nextFingerprint;
      } catch (_) {
        // Keep in-memory preview even when persistence fails.
      } finally {
        isPersistingDraft = false;
      }
    }

    void schedulePersistDraft() {
      persistDraftTimer?.cancel();
      persistDraftTimer = Timer(const Duration(milliseconds: 220), () {
        if (!mounted) {
          return;
        }
        unawaited(persistDraftNow(draft));
      });
    }

    await _ensureBackgroundPresetsReady();
    if (!mounted) {
      return;
    }
    final activeBackgroundBase64 = _settings.backgroundImageBase64?.trim();
    final hasActiveBackground =
        activeBackgroundBase64 != null && activeBackgroundBase64.isNotEmpty;
    final isActivePreset =
        hasActiveBackground && _isPresetBackgroundValue(activeBackgroundBase64);
    if (hasActiveBackground && !isActivePreset) {
      final nextCustoms = List<String>.from(_customBackgroundImages);
      if (!nextCustoms.contains(activeBackgroundBase64)) {
        nextCustoms.add(activeBackgroundBase64);
        _customBackgroundImages = nextCustoms;
        unawaited(_preferencesService.saveCustomBackgroundImages(nextCustoms));
      }
    }
    final readerModalTheme = _readerModalTheme();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: readerModalTheme.colorScheme.surface,
      builder: (context) {
        return Theme(
          data: readerModalTheme,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final activeBackgroundBase64 =
                  draft.backgroundImageBase64?.trim();
              final hasBackgroundImage =
                  activeBackgroundBase64 != null &&
                  activeBackgroundBase64.isNotEmpty;
              final isPresetBackground =
                  hasBackgroundImage &&
                  _backgroundPresetBase64.values.contains(
                    activeBackgroundBase64,
                  );
              final customBackgrounds = _customBackgroundImages;
              Future<void> openMineFontManagement() async {
                if (!context.mounted) {
                  return;
                }
                await context.push('/font-management');
                await _refreshSharedReaderAssets(
                  updateModalState: setModalState,
                );
              }

              Future<void> openMineReaderBackgroundManagement() async {
                if (!context.mounted) {
                  return;
                }
                await context.push('/appearance/reader-background');
                await _refreshSharedReaderAssets(
                  updateModalState: setModalState,
                );
              }

              void updateCustomBackgrounds(List<String> nextCustoms) {
                if (mounted) {
                  setState(() {
                    _customBackgroundImages = nextCustoms;
                  });
                } else {
                  _customBackgroundImages = nextCustoms;
                }
                unawaited(_preloadCustomBackgroundPreviews(nextCustoms));
                unawaited(
                  _preferencesService.saveCustomBackgroundImages(nextCustoms),
                );
              }

              void updateCustomBackgroundsInSheet(List<String> nextCustoms) {
                setModalState(() {
                  _customBackgroundImages = nextCustoms;
                });
                updateCustomBackgrounds(nextCustoms);
              }

              Future<void> rememberBodyTextColor(int value) async {
                final nextColors = <int>[value, ..._recentBodyTextColors];
                nextColors.removeWhere((entry) => entry == value);
                nextColors.insert(0, value);
                if (nextColors.length > 8) {
                  nextColors.removeRange(8, nextColors.length);
                }
                if (mounted) {
                  setState(() {
                    _recentBodyTextColors = nextColors;
                  });
                } else {
                  _recentBodyTextColors = nextColors;
                }
                await _preferencesService.saveRecentBodyTextColors(nextColors);
              }

              void previewDraftSettings() {
                if (!mounted) {
                  return;
                }

                schedulePersistDraft();
                final currentFingerprint = fingerprint(_settings);
                final draftFingerprint = fingerprint(draft);
                if (currentFingerprint == draftFingerprint) {
                  return;
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted ||
                      fingerprint(_settings) == fingerprint(draft)) {
                    return;
                  }
                  _applyReaderSettingsWithModeRestore(nextSettings: draft);
                });
              }

              void updateDraft(ReaderSettings next) {
                setModalState(() {
                  draft = next;
                });
                previewDraftSettings();
              }

              Future<void> persistBackgroundDraftNow(
                ReaderSettings nextDraft,
              ) async {
                if (mounted) {
                  setState(() {
                    _settings = nextDraft;
                  });
                  unawaited(_syncVolumeKeyPageInterception());
                } else {
                  _settings = nextDraft;
                }
                _debugLogReaderBackground('persist', nextDraft);
                await persistDraftNow(nextDraft);
              }

              Future<void> applyCustomBackgroundImage() async {
                final storedPath = await _pickBackgroundImagePath();
                if (storedPath == null || !context.mounted) {
                  return;
                }

                final nextCustoms =
                    List<String>.from(_customBackgroundImages)
                      ..removeWhere((entry) => entry == storedPath)
                      ..add(storedPath);

                updateDraft(draft.copyWith(backgroundImageBase64: storedPath));
                setModalState(() {
                  _customBackgroundImages = nextCustoms;
                });
                updateCustomBackgrounds(nextCustoms);
              }

              Future<void> applyStoredCustomBackground(String source) async {
                final normalized = source.trim();
                if (normalized.isEmpty) {
                  return;
                }
                updateDraft(draft.copyWith(backgroundImageBase64: normalized));
              }

              Future<void> removeActiveBackground() async {
                final active = draft.backgroundImageBase64?.trim();
                final isActivePreset =
                    active != null &&
                    active.isNotEmpty &&
                    _isPresetBackgroundValue(active);

                updateDraft(draft.copyWith(clearBackgroundImage: true));

                if (active != null &&
                    active.isNotEmpty &&
                    !isActivePreset &&
                    _customBackgroundImages.contains(active)) {
                  final nextCustoms = List<String>.from(_customBackgroundImages)
                    ..removeWhere((entry) => entry == active);
                  updateCustomBackgroundsInSheet(nextCustoms);
                  unawaited(_deleteManagedBackgroundFileIfNeeded(active));
                }
              }

              Future<ReaderCustomFontEntry?> importCustomFont() async {
                try {
                  final imported =
                      await _fontRegistryService.pickAndImportFont();
                  if (imported == null || !context.mounted) {
                    return null;
                  }
                  final refreshedFonts =
                      await _fontRegistryService.listRegisteredFonts();
                  setModalState(() {
                    availableCustomFonts = refreshedFonts;
                    draft = draft.copyWith(
                      fontSource: ReaderFontSource.custom,
                      fontFamilyKey: imported.fontFamilyKey,
                      customFontPath: imported.filePath,
                    );
                  });
                  if (mounted) {
                    setState(() {
                      _customFonts = refreshedFonts;
                    });
                  }
                  return imported;
                } on PlatformException catch (error) {
                  _showMessage('导入字体失败：${error.message ?? error.code}');
                  return null;
                } on ReaderFontRegistryException catch (error) {
                  _showMessage(error.message);
                  return null;
                } catch (error) {
                  _showMessage('导入字体失败：$error');
                  return null;
                }
              }

              ReaderCustomFontEntry? resolveSelectedCustomFont(
                ReaderSettings settings,
              ) {
                if (settings.fontSource != ReaderFontSource.custom) {
                  return null;
                }
                final familyKey = settings.fontFamilyKey;
                if (familyKey == null || familyKey.isEmpty) {
                  return null;
                }
                for (final entry in availableCustomFonts) {
                  if (entry.fontFamilyKey == familyKey) {
                    return entry;
                  }
                }
                return null;
              }

              String systemFontPresetLabel(ReaderSystemFontPreset preset) {
                return switch (preset) {
                  ReaderSystemFontPreset.defaultSans => '系统默认',
                  ReaderSystemFontPreset.serif => '衬线',
                  ReaderSystemFontPreset.monospace => '等宽',
                };
              }

              String currentFontLabel() {
                final selectedCustomFont = resolveSelectedCustomFont(draft);
                if (selectedCustomFont != null) {
                  return selectedCustomFont.displayName;
                }
                return systemFontPresetLabel(draft.systemFontPreset);
              }

              ReaderSettingsGroups semanticGroups() =>
                  settingsGroupingService.split(draft);

              Future<void> openFontPickerSheet() async {
                if (!context.mounted) {
                  return;
                }

                await showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  useSafeArea: true,
                  backgroundColor: readerModalTheme.colorScheme.surface,
                  builder: (sheetContext) {
                    bool isImporting = false;
                    return StatefulBuilder(
                      builder: (sheetContext, setFontSheetState) {
                        Widget buildFontChoiceTile({
                          required String label,
                          required bool selected,
                          required Future<void> Function()? onTap,
                          IconData? icon,
                          bool loading = false,
                        }) {
                          final colorScheme =
                              Theme.of(sheetContext).colorScheme;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap:
                                  onTap == null
                                      ? null
                                      : () => unawaited(onTap()),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                curve: Curves.easeOutCubic,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color:
                                      selected
                                          ? colorScheme.primaryContainer
                                          : colorScheme.surfaceContainerLow,
                                  border: Border.all(
                                    color:
                                        selected
                                            ? colorScheme.primary.withValues(
                                              alpha: 0.45,
                                            )
                                            : colorScheme.outlineVariant
                                                .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (loading)
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colorScheme.primary,
                                        ),
                                      )
                                    else if (icon != null)
                                      Icon(
                                        icon,
                                        size: 14,
                                        color:
                                            selected
                                                ? colorScheme.onPrimaryContainer
                                                : colorScheme.onSurfaceVariant,
                                      ),
                                    if (icon != null || loading)
                                      const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(
                                          sheetContext,
                                        ).textTheme.labelMedium?.copyWith(
                                          color:
                                              selected
                                                  ? colorScheme
                                                      .onPrimaryContainer
                                                  : colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        Future<void> selectSystemFont(
                          ReaderSystemFontPreset preset,
                        ) async {
                          setModalState(() {
                            draft = draft.copyWith(
                              fontSource: ReaderFontSource.system,
                              systemFontPreset: preset,
                              clearFontFamilyKey: true,
                              clearCustomFontPath: true,
                            );
                          });
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        }

                        Future<void> selectCustomFont(
                          ReaderCustomFontEntry entry,
                        ) async {
                          setModalState(() {
                            draft = draft.copyWith(
                              fontSource: ReaderFontSource.custom,
                              fontFamilyKey: entry.fontFamilyKey,
                              customFontPath: entry.filePath,
                            );
                          });
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        }

                        Future<void> importCustomFontFromSheet() async {
                          if (isImporting) {
                            return;
                          }
                          setFontSheetState(() {
                            isImporting = true;
                          });
                          final imported = await importCustomFont();
                          if (!sheetContext.mounted) {
                            return;
                          }
                          setFontSheetState(() {
                            isImporting = false;
                          });
                          if (imported != null && sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                        }

                        final selectedCustomFont = resolveSelectedCustomFont(
                          draft,
                        );

                        final children = <Widget>[
                          buildFontChoiceTile(
                            label: systemFontPresetLabel(
                              ReaderSystemFontPreset.serif,
                            ),
                            selected:
                                draft.fontSource == ReaderFontSource.system &&
                                draft.systemFontPreset ==
                                    ReaderSystemFontPreset.serif,
                            icon: Icons.format_shapes_rounded,
                            onTap:
                                () => selectSystemFont(
                                  ReaderSystemFontPreset.serif,
                                ),
                          ),
                          buildFontChoiceTile(
                            label: systemFontPresetLabel(
                              ReaderSystemFontPreset.monospace,
                            ),
                            selected:
                                draft.fontSource == ReaderFontSource.system &&
                                draft.systemFontPreset ==
                                    ReaderSystemFontPreset.monospace,
                            icon: Icons.code_rounded,
                            onTap:
                                () => selectSystemFont(
                                  ReaderSystemFontPreset.monospace,
                                ),
                          ),
                          ...availableCustomFonts.map(
                            (entry) => buildFontChoiceTile(
                              label: entry.displayName,
                              selected:
                                  selectedCustomFont?.fontFamilyKey ==
                                  entry.fontFamilyKey,
                              icon: Icons.font_download_outlined,
                              onTap: () => selectCustomFont(entry),
                            ),
                          ),
                          buildFontChoiceTile(
                            label: '自定义',
                            selected: false,
                            loading: isImporting,
                            icon: Icons.upload_file_rounded,
                            onTap: importCustomFontFromSheet,
                          ),
                        ];

                        return SizedBox(
                          height: 320,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  '选择字体',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '支持系统默认、衬线、等宽和自定义字体。',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(
                                    sheetContext,
                                  ).textTheme.bodySmall?.copyWith(
                                    color:
                                        Theme.of(
                                          sheetContext,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () async {
                                      Navigator.of(sheetContext).pop();
                                      await openMineFontManagement();
                                    },
                                    icon: const Icon(
                                      Icons.open_in_new_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('去我的管理字体'),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: GridView.count(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 2.35,
                                    children: children,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              }

              String fontWeightLevelLabel(ReaderFontWeightLevel level) {
                return switch (level) {
                  ReaderFontWeightLevel.light => '细',
                  ReaderFontWeightLevel.regular => '常规',
                  ReaderFontWeightLevel.medium => '粗',
                };
              }

              String decorationStyleLabel(ReaderBodyTextDecorationStyle style) {
                return switch (style) {
                  ReaderBodyTextDecorationStyle.none => '无',
                  ReaderBodyTextDecorationStyle.solid => '实线',
                  ReaderBodyTextDecorationStyle.dashed => '虚线',
                };
              }

              int fontWeightValueForLevel(ReaderFontWeightLevel level) {
                return switch (level) {
                  ReaderFontWeightLevel.light => 400,
                  ReaderFontWeightLevel.regular => 500,
                  ReaderFontWeightLevel.medium => 600,
                };
              }

              ReaderFontWeightLevel nearestFontWeightLevel(int value) {
                if (value <= 450) {
                  return ReaderFontWeightLevel.light;
                }
                if (value >= 550) {
                  return ReaderFontWeightLevel.medium;
                }
                return ReaderFontWeightLevel.regular;
              }

              int effectiveFontWeightValue(ReaderSettings settings) {
                return settings.fontWeightValue ??
                    fontWeightValueForLevel(settings.fontWeightLevel);
              }

              String fontWeightDisplayLabel(ReaderSettings settings) {
                final value = effectiveFontWeightValue(settings);
                final mappedLevel = nearestFontWeightLevel(value);
                final presetValue = fontWeightValueForLevel(mappedLevel);
                if (value == presetValue) {
                  return fontWeightLevelLabel(mappedLevel);
                }
                return '$value';
              }

              Widget buildReadingActionTab({
                required String label,
                String? value,
                required VoidCallback onTap,
              }) {
                final colorScheme = Theme.of(context).colorScheme;
                final displayText =
                    value == null || value.isEmpty ? label : '$label · $value';
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: onTap,
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: colorScheme.surfaceContainerLow,
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: Text(
                          displayText,
                          style: Theme.of(
                            context,
                          ).textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              Future<void> showFloatingReaderSubSheet({
                required Widget Function(
                  BuildContext sheetContext,
                  StateSetter setSheetState,
                )
                builder,
                double maxWidth = 680,
                double heightFactor = 0.5,
              }) async {
                if (!context.mounted) {
                  return;
                }

                await showGeneralDialog<void>(
                  context: context,
                  barrierLabel: 'reader-sub-sheet',
                  barrierDismissible: true,
                  barrierColor: Colors.black.withValues(alpha: 0.03),
                  pageBuilder: (dialogContext, _, __) {
                    return Theme(
                      data: readerModalTheme,
                      child: StatefulBuilder(
                        builder: (sheetContext, setSheetState) {
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap:
                                      () => Navigator.of(dialogContext).pop(),
                                  child: const SizedBox.shrink(),
                                ),
                              ),
                              _buildFloatingReaderSettingsSheet(
                                context: sheetContext,
                                readerModalTheme: readerModalTheme,
                                keyboardInset:
                                    MediaQuery.viewInsetsOf(
                                      sheetContext,
                                    ).bottom,
                                safeBottom: _bottomSafeInset(sheetContext),
                                sheetHorizontal: AppSpacing.pageHorizontal(
                                  sheetContext,
                                ),
                                maxWidth: maxWidth,
                                heightFactor: heightFactor,
                                child: builder(sheetContext, setSheetState),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 180),
                  transitionBuilder: (context, animation, _, child) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    );
                    return FadeTransition(
                      opacity: curved,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.06),
                          end: Offset.zero,
                        ).animate(curved),
                        child: child,
                      ),
                    );
                  },
                );
              }

              Future<void> openFontWeightTabSheet() async {
                if (!context.mounted) {
                  return;
                }

                await showFloatingReaderSubSheet(
                  maxWidth: 560,
                  heightFactor: 0.34,
                  builder: (sheetContext, setFontWeightState) {
                    final currentValue = effectiveFontWeightValue(draft);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 42,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(sheetContext)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          Text(
                            '字重',
                            textAlign: TextAlign.center,
                            style: Theme.of(sheetContext).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '当前 $currentValue',
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              sheetContext,
                            ).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(
                                    sheetContext,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: ReaderFontWeightLevel.values
                                .map(
                                  (level) => ChoiceChip(
                                    label: Text(fontWeightLevelLabel(level)),
                                    selected:
                                        currentValue ==
                                        fontWeightValueForLevel(level),
                                    onSelected: (_) {
                                      setModalState(() {
                                        draft = draft.copyWith(
                                          fontWeightLevel: level,
                                          fontWeightValue:
                                              fontWeightValueForLevel(level),
                                        );
                                      });
                                      setFontWeightState(() {});
                                    },
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          const SizedBox(height: 12),
                          Slider(
                            min: ReaderSettings.minFontWeightValue.toDouble(),
                            max: ReaderSettings.maxFontWeightValue.toDouble(),
                            divisions:
                                (ReaderSettings.maxFontWeightValue -
                                    ReaderSettings.minFontWeightValue) ~/
                                50,
                            value: currentValue.toDouble(),
                            label: '$currentValue',
                            onChanged: (value) {
                              final normalized = (value / 50).round() * 50;
                              setModalState(() {
                                draft = draft.copyWith(
                                  fontWeightLevel: nearestFontWeightLevel(
                                    normalized,
                                  ),
                                  fontWeightValue: normalized,
                                );
                              });
                              setFontWeightState(() {});
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              }

              Future<void> openHorizontalPaddingTabSheet() async {
                if (!context.mounted) {
                  return;
                }

                await showFloatingReaderSubSheet(
                  maxWidth: 720,
                  heightFactor: 0.72,
                  builder: (sheetContext, setPaddingState) {
                    final colorScheme = Theme.of(sheetContext).colorScheme;
                    final textTheme = Theme.of(sheetContext).textTheme;

                    void updatePaddingSettings(ReaderSettings next) {
                      setModalState(() {
                        draft = next;
                      });
                      setPaddingState(() {});
                    }

                    void updateBodyMargins({
                      double? top,
                      double? bottom,
                      double? left,
                      double? right,
                    }) {
                      final next = draft.copyWith(
                        bodyMarginMode: ReaderBodyMarginMode.custom,
                        bodyMarginTop: top ?? draft.bodyMarginTop,
                        bodyMarginBottom: bottom ?? draft.bodyMarginBottom,
                        bodyMarginLeft: left ?? draft.bodyMarginLeft,
                        bodyMarginRight: right ?? draft.bodyMarginRight,
                      );
                      updatePaddingSettings(next);
                    }

                    void resetBodyMarginsToDefault() {
                      updatePaddingSettings(
                        draft.copyWith(
                          bodyMarginMode: ReaderBodyMarginMode.custom,
                          bodyMarginTop: 6,
                          bodyMarginBottom: 6,
                          bodyMarginLeft: 16,
                          bodyMarginRight: 16,
                        ),
                      );
                    }

                    Future<double?> promptExactMarginValue({
                      required String label,
                      required double currentValue,
                    }) async {
                      var draftValue = _formatLayoutMarginValue(currentValue);
                      String? errorText;

                      final result = await showDialog<double>(
                        context: sheetContext,
                        builder: (dialogContext) {
                          return StatefulBuilder(
                            builder: (dialogContext, setDialogState) {
                              void submit() {
                                final raw = draftValue.trim();
                                final parsed = double.tryParse(raw);
                                if (parsed == null) {
                                  setDialogState(() {
                                    errorText = '请输入数字';
                                  });
                                  return;
                                }
                                if (parsed < ReaderSettings.minLayoutMargin ||
                                    parsed > ReaderSettings.maxLayoutMargin) {
                                  setDialogState(() {
                                    errorText =
                                        '请输入 ${ReaderSettings.minLayoutMargin.toInt()} - ${ReaderSettings.maxLayoutMargin.toInt()}';
                                  });
                                  return;
                                }
                                Navigator.of(dialogContext).pop(parsed);
                              }

                              return AlertDialog(
                                title: Text('$label 精确输入'),
                                content: TextFormField(
                                  initialValue: draftValue,
                                  autofocus: appEnableAutoFocusForTextInput,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: '边距数值',
                                    helperText:
                                        '范围 ${ReaderSettings.minLayoutMargin.toInt()} - ${ReaderSettings.maxLayoutMargin.toInt()}',
                                    errorText: errorText,
                                  ),
                                  onChanged: (value) {
                                    draftValue = value;
                                    if (errorText != null) {
                                      setDialogState(() {
                                        errorText = null;
                                      });
                                    }
                                  },
                                  onFieldSubmitted: (_) => submit(),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(dialogContext).pop(),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: submit,
                                    child: const Text('应用'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );

                      if (result == null) {
                        return null;
                      }
                      return ((result * 2).round() / 2).toDouble();
                    }

                    Widget buildMarginControlRow({
                      required String label,
                      required double value,
                      required ValueChanged<double> onChanged,
                    }) {
                      final safeValue =
                          value
                              .clamp(
                                ReaderSettings.minLayoutMargin,
                                ReaderSettings.maxLayoutMargin,
                              )
                              .toDouble();

                      void nudge(double delta) {
                        final next =
                            (safeValue + delta)
                                .clamp(
                                  ReaderSettings.minLayoutMargin,
                                  ReaderSettings.maxLayoutMargin,
                                )
                                .toDouble();
                        onChanged(next);
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 52,
                              child: Text(label, style: textTheme.bodyMedium),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => nudge(-_kMarginControlStep),
                              icon: const Icon(Icons.remove_rounded),
                            ),
                            Expanded(
                              child: Slider(
                                min: ReaderSettings.minLayoutMargin,
                                max: ReaderSettings.maxLayoutMargin,
                                divisions:
                                    ((ReaderSettings.maxLayoutMargin -
                                                ReaderSettings
                                                    .minLayoutMargin) /
                                            _kMarginControlStep)
                                        .round(),
                                value: safeValue,
                                onChanged: onChanged,
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => nudge(_kMarginControlStep),
                              icon: const Icon(Icons.add_rounded),
                            ),
                            SizedBox(
                              width: 52,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () async {
                                  final exact = await promptExactMarginValue(
                                    label: label,
                                    currentValue: safeValue,
                                  );
                                  if (exact == null) {
                                    return;
                                  }
                                  onChanged(exact);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    _formatLayoutMarginValue(safeValue),
                                    textAlign: TextAlign.right,
                                    style: textTheme.labelLarge?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    Widget buildSectionTitle({
                      required String title,
                      bool? dividerEnabled,
                      ValueChanged<bool>? onDividerChanged,
                      bool dividerInteractive = true,
                    }) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 4),
                        child: Row(
                          children: [
                            Text(
                              title,
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            if (dividerEnabled != null &&
                                onDividerChanged != null)
                              FilterChip(
                                label: const Text('显示分隔线'),
                                selected: dividerInteractive && dividerEnabled,
                                showCheckmark: false,
                                onSelected:
                                    dividerInteractive
                                        ? onDividerChanged
                                        : null,
                              ),
                          ],
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 42,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.7,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          Text(
                            '边距',
                            textAlign: TextAlign.center,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView(
                              children: [
                                buildSectionTitle(title: '正文边距'),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: resetBodyMarginsToDefault,
                                    icon: const Icon(
                                      Icons.restart_alt_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('恢复默认'),
                                  ),
                                ),
                                buildMarginControlRow(
                                  label: '上边距',
                                  value: draft.bodyMarginTop,
                                  onChanged:
                                      (value) => updateBodyMargins(top: value),
                                ),
                                buildMarginControlRow(
                                  label: '下边距',
                                  value: draft.bodyMarginBottom,
                                  onChanged:
                                      (value) =>
                                          updateBodyMargins(bottom: value),
                                ),
                                buildMarginControlRow(
                                  label: '左边距',
                                  value: draft.bodyMarginLeft,
                                  onChanged:
                                      (value) => updateBodyMargins(left: value),
                                ),
                                buildMarginControlRow(
                                  label: '右边距',
                                  value: draft.bodyMarginRight,
                                  onChanged:
                                      (value) =>
                                          updateBodyMargins(right: value),
                                ),
                                const SizedBox(height: 8),
                                Builder(
                                  builder: (context) {
                                    final margins =
                                        draft.effectiveBodyMarginValues;
                                    return Text(
                                      '当前正文边距：上 ${margins.top.round()} / 下 ${margins.bottom.round()} / 左 ${margins.left.round()} / 右 ${margins.right.round()}',
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                buildSectionTitle(title: '信息栏精调'),
                                buildSectionTitle(
                                  title: '页脚',
                                  dividerEnabled:
                                      draft.infoFooterDividerEnabled,
                                  dividerInteractive: draft.infoFooterEnabled,
                                  onDividerChanged: (selected) {
                                    updatePaddingSettings(
                                      draft.copyWith(
                                        infoFooterDividerEnabled: selected,
                                      ),
                                    );
                                  },
                                ),
                                buildMarginControlRow(
                                  label: '上边距',
                                  value: draft.infoFooterMarginTop,
                                  onChanged: (value) {
                                    updatePaddingSettings(
                                      draft.copyWith(
                                        infoFooterMarginTop: value,
                                      ),
                                    );
                                  },
                                ),
                                buildMarginControlRow(
                                  label: '下边距',
                                  value: draft.infoFooterMarginBottom,
                                  onChanged: (value) {
                                    updatePaddingSettings(
                                      draft.copyWith(
                                        infoFooterMarginBottom: value,
                                      ),
                                    );
                                  },
                                ),
                                buildMarginControlRow(
                                  label: '左边距',
                                  value: draft.infoFooterMarginLeft,
                                  onChanged: (value) {
                                    updatePaddingSettings(
                                      draft.copyWith(
                                        infoFooterMarginLeft: value,
                                      ),
                                    );
                                  },
                                ),
                                buildMarginControlRow(
                                  label: '右边距',
                                  value: draft.infoFooterMarginRight,
                                  onChanged: (value) {
                                    updatePaddingSettings(
                                      draft.copyWith(
                                        infoFooterMarginRight: value,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }

              final showInterfaceSection =
                  initialTab == _ReaderSettingsTab.interface;
              final showReadingSection =
                  initialTab == _ReaderSettingsTab.reading;
              final presetTileScale =
                  (AppLayout.pageContentMaxWidth(context, maxWidth: 760) /
                          360.0)
                      .clamp(0.94, 1.18)
                      .toDouble();
              final presetBackgroundTiles = <Widget>[];
              for (final preset in _backgroundPresets) {
                final previewBytes = _backgroundPresetBytes[preset.assetPath];
                final presetBase64 = _backgroundPresetBase64[preset.assetPath];
                if (previewBytes == null) {
                  continue;
                }
                presetBackgroundTiles.add(
                  Padding(
                    padding: EdgeInsets.only(right: 8 * presetTileScale),
                    child: _buildBackgroundTile(
                      label: preset.label,
                      selected:
                          activeBackgroundBase64 == preset.assetPath ||
                          (presetBase64 != null &&
                              activeBackgroundBase64 == presetBase64),
                      previewBytes: previewBytes,
                      showLabel: false,
                      scale: presetTileScale,
                      onTap: () {
                        updateDraft(
                          draft.copyWith(
                            backgroundImageBase64: preset.assetPath,
                          ),
                        );
                      },
                    ),
                  ),
                );
              }
              final customBackgroundTiles = <Widget>[];
              for (
                var index = 0;
                index < customBackgrounds.length;
                index += 1
              ) {
                final source = customBackgrounds[index];
                final previewBytes = _customBackgroundPreviewBytes[source];
                final isSelected =
                    hasBackgroundImage &&
                    !isPresetBackground &&
                    activeBackgroundBase64 == source;
                customBackgroundTiles.add(
                  Padding(
                    padding: EdgeInsets.only(right: 8 * presetTileScale),
                    child: _buildBackgroundTile(
                      label: '自定义${index + 1}',
                      selected: isSelected,
                      previewBytes: previewBytes,
                      showLabel: true,
                      scale: presetTileScale,
                      icon:
                          previewBytes == null
                              ? Icons.broken_image_outlined
                              : null,
                      onTap:
                          () => unawaited(applyStoredCustomBackground(source)),
                    ),
                  ),
                );
              }
              final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
              final safeBottom = _bottomSafeInset(context);
              final sheetHeightFactor = _adaptiveReaderSheetHeightFactor(
                context,
                compact: 0.70,
                regular: 0.70,
                large: 0.70,
              );
              final sheetHorizontal = AppSpacing.pageHorizontal(context);
              final maxSheetWidth = AppLayout.pageContentMaxWidth(
                context,
                maxWidth: showReadingSection && !isMangaChapter ? 700 : 640,
              );
              final compactSheetBaseWidth = 360.0;
              final compactSheetVisualWidth = min(
                AppLayout.pageContentMaxWidth(context, maxWidth: 760),
                max(
                  320.0,
                  MediaQuery.sizeOf(context).width - (sheetHorizontal * 2),
                ),
              );
              final compactSheetScale =
                  (compactSheetVisualWidth / compactSheetBaseWidth)
                      .clamp(0.88, 1.08)
                      .toDouble();
              double compactScaleValue(double value) =>
                  value * compactSheetScale;
              final disablePageAnimationSelection =
                  !isMangaChapter && _pageTurnUsesScroll(draft.pageTurnMode);
              final pageAnimationInactiveReason = _pageAnimationInactiveReason(
                modeOverride: draft.pageTurnMode,
                isMangaChapterOverride: isMangaChapter,
              );
              final animationPolicy = _resolveAnimationPolicy(
                modeOverride:
                    isMangaChapter
                        ? ReaderContentMode.comic
                        : ReaderContentMode.text,
                pageTurnModeOverride: draft.pageTurnMode,
              );
              Widget buildPageAnimationSelector() {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: const [
                          ReaderPageAnimationStyle.curl,
                          ReaderPageAnimationStyle.cover,
                          ReaderPageAnimationStyle.translate,
                          ReaderPageAnimationStyle.vertical,
                          ReaderPageAnimationStyle.fade,
                          ReaderPageAnimationStyle.none,
                        ]
                        .map(
                          (style) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Opacity(
                              opacity:
                                  disablePageAnimationSelection ? 0.45 : 1.0,
                              child: Tooltip(
                                message:
                                    disablePageAnimationSelection
                                        ? '滚动触发模式下不支持分页动画'
                                        : _pageAnimationLabel(style),
                                child: ChoiceChip(
                                  label: Text(_pageAnimationLabel(style)),
                                  selected: draft.pageAnimationStyle == style,
                                  showCheckmark: false,
                                  onSelected:
                                      disablePageAnimationSelection
                                          ? null
                                          : (_) {
                                            setModalState(() {
                                              draft = draft.copyWith(
                                                pageAnimationStyle: style,
                                              );
                                            });
                                          },
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                );
              }

              Widget buildTypographySliderRow({
                required String label,
                required double value,
                required double min,
                required double max,
                required int divisions,
                required String valueLabel,
                required ValueChanged<double> onChanged,
                double step = 1,
                bool showValueLabel = true,
              }) {
                final safeValue = value.clamp(min, max).toDouble();

                void nudge(double delta) {
                  final next = (safeValue + delta).clamp(min, max).toDouble();
                  onChanged(next);
                }

                return Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: compactScaleValue(0.5),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: compactScaleValue(28),
                        child: Text(
                          label,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            fontSize:
                                (Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.fontSize ??
                                    12) *
                                compactSheetScale *
                                0.95,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: BoxConstraints(
                          minWidth: compactScaleValue(28),
                          minHeight: compactScaleValue(28),
                        ),
                        onPressed: () => nudge(-step),
                        icon: Icon(
                          Icons.remove_rounded,
                          size: compactScaleValue(16),
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          min: min,
                          max: max,
                          divisions: divisions,
                          value: safeValue,
                          onChanged: onChanged,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: BoxConstraints(
                          minWidth: compactScaleValue(28),
                          minHeight: compactScaleValue(28),
                        ),
                        onPressed: () => nudge(step),
                        icon: Icon(
                          Icons.add_rounded,
                          size: compactScaleValue(16),
                        ),
                      ),
                      if (showValueLabel)
                        SizedBox(
                          width: compactScaleValue(54),
                          child: Text(
                            valueLabel,
                            textAlign: TextAlign.right,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              fontSize:
                                  (Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.fontSize ??
                                      12) *
                                  compactSheetScale *
                                  0.94,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }

              Widget buildSettingsSectionCard({
                required IconData icon,
                required String title,
                String? subtitle,
                required List<Widget> children,
              }) {
                final colorScheme = Theme.of(context).colorScheme;
                final textTheme = Theme.of(context).textTheme;

                return Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: compactScaleValue(8)),
                  padding: EdgeInsets.fromLTRB(
                    compactScaleValue(10),
                    compactScaleValue(10),
                    compactScaleValue(10),
                    compactScaleValue(10),
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(compactScaleValue(16)),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.42),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: compactScaleValue(26),
                            height: compactScaleValue(26),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withValues(
                                alpha: 0.76,
                              ),
                              borderRadius: BorderRadius.circular(
                                compactScaleValue(9),
                              ),
                            ),
                            child: Icon(
                              icon,
                              size: compactScaleValue(14),
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          SizedBox(width: compactScaleValue(8)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize:
                                        (textTheme.titleSmall?.fontSize ?? 14) *
                                        compactSheetScale *
                                        0.92,
                                  ),
                                ),
                                if (subtitle != null &&
                                    subtitle.trim().isNotEmpty) ...[
                                  SizedBox(height: compactScaleValue(1)),
                                  Text(
                                    subtitle,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      height: 1.35,
                                      fontSize:
                                          (textTheme.bodySmall?.fontSize ??
                                              12) *
                                          compactSheetScale *
                                          0.92,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: compactScaleValue(10)),
                      ...children,
                    ],
                  ),
                );
              }

              Widget buildSettingsGroupEntryCard({
                required IconData icon,
                required String title,
                required String subtitle,
                required VoidCallback onTap,
              }) {
                final colorScheme = Theme.of(context).colorScheme;
                return InkWell(
                  borderRadius: BorderRadius.circular(compactScaleValue(16)),
                  onTap: onTap,
                  child: Ink(
                    padding: EdgeInsets.fromLTRB(
                      compactScaleValue(12),
                      compactScaleValue(10),
                      compactScaleValue(12),
                      compactScaleValue(10),
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(
                        compactScaleValue(16),
                      ),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.38,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: compactScaleValue(28),
                          height: compactScaleValue(28),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(
                              alpha: 0.72,
                            ),
                            borderRadius: BorderRadius.circular(
                              compactScaleValue(10),
                            ),
                          ),
                          child: Icon(
                            icon,
                            size: compactScaleValue(14),
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        SizedBox(width: compactScaleValue(9)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(
                                  context,
                                ).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize:
                                      (Theme.of(
                                            context,
                                          ).textTheme.titleSmall?.fontSize ??
                                          14) *
                                      compactSheetScale *
                                      0.92,
                                ),
                              ),
                              SizedBox(height: compactScaleValue(2)),
                              Text(
                                subtitle,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.3,
                                  fontSize:
                                      (Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.fontSize ??
                                          12) *
                                      compactSheetScale *
                                      0.92,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: compactScaleValue(6)),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colorScheme.onSurfaceVariant,
                          size: compactScaleValue(18),
                        ),
                      ],
                    ),
                  ),
                );
              }

              Widget buildCompactToggleRow({
                required String label,
                required bool value,
                required ValueChanged<bool>? onChanged,
                bool isSaving = false,
              }) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: compactScaleValue(1)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize:
                                (Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.fontSize ??
                                    14) *
                                compactSheetScale *
                                0.94,
                          ),
                        ),
                      ),
                      if (isSaving)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      Switch.adaptive(value: value, onChanged: onChanged),
                    ],
                  ),
                );
              }

              Widget buildSectionDivider() {
                return Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: compactScaleValue(2.5),
                  ),
                  child: Divider(
                    height: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                );
              }

              Widget buildTextReaderSettingsSheet() {
                int enabledInfoItemCount() {
                  var count = 0;
                  if (draft.infoShowTime) {
                    count += 1;
                  }
                  if (draft.infoShowBattery) {
                    count += 1;
                  }
                  if (draft.infoShowProgress) {
                    count += 1;
                  }
                  return count;
                }

                Widget buildCompactSectionTitle(
                  String title, {
                  Widget? trailing,
                }) {
                  final colorScheme = Theme.of(context).colorScheme;
                  return Row(
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                          fontSize:
                              (Theme.of(
                                    context,
                                  ).textTheme.titleSmall?.fontSize ??
                                  14) *
                              compactSheetScale *
                              0.9,
                        ),
                      ),
                      const Spacer(),
                      if (trailing != null) trailing,
                    ],
                  );
                }

                Widget buildCompactSettingsCard(List<Widget> children) {
                  final colorScheme = Theme.of(context).colorScheme;
                  return Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(bottom: compactScaleValue(8)),
                    padding: EdgeInsets.fromLTRB(
                      compactScaleValue(12),
                      compactScaleValue(12),
                      compactScaleValue(12),
                      compactScaleValue(12),
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(
                        compactScaleValue(18),
                      ),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.32,
                        ),
                      ),
                    ),
                    child: Column(children: children),
                  );
                }

                Widget buildInterfaceCapsuleEntry({
                  required IconData icon,
                  required String title,
                  required VoidCallback onTap,
                  EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 10),
                }) {
                  final colorScheme = Theme.of(context).colorScheme;
                  return Padding(
                    padding: margin,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: onTap,
                        child: Ink(
                          padding: EdgeInsets.symmetric(
                            horizontal: compactScaleValue(10),
                            vertical: compactScaleValue(7),
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.38,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: compactScaleValue(22),
                                height: compactScaleValue(22),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer
                                      .withValues(alpha: 0.8),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  icon,
                                  size: compactScaleValue(12),
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                              SizedBox(width: compactScaleValue(7)),
                              Expanded(
                                child: Text(
                                  title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize:
                                        (Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.fontSize ??
                                            14) *
                                        compactSheetScale *
                                        0.9,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: colorScheme.onSurfaceVariant,
                                size: compactScaleValue(18),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                Widget buildInterfaceInlineCapsule({
                  required Widget child,
                  EdgeInsetsGeometry? padding,
                  Color? backgroundColor,
                  Color? borderColor,
                }) {
                  final colorScheme = Theme.of(context).colorScheme;
                  return Container(
                    padding:
                        padding ??
                        EdgeInsets.symmetric(
                          horizontal: compactScaleValue(12),
                          vertical: compactScaleValue(8),
                        ),
                    decoration: BoxDecoration(
                      color: backgroundColor ?? colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color:
                            borderColor ??
                            colorScheme.outlineVariant.withValues(alpha: 0.38),
                      ),
                    ),
                    child: child,
                  );
                }

                Widget buildInterfaceSecondaryCapsule({
                  required IconData icon,
                  required String title,
                  required VoidCallback onTap,
                }) {
                  final colorScheme = Theme.of(context).colorScheme;
                  return buildInterfaceInlineCapsule(
                    padding: EdgeInsets.zero,
                    child: SizedBox(
                      height: compactScaleValue(38),
                      child: TextButton(
                        onPressed: onTap,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.symmetric(
                            horizontal: compactScaleValue(8),
                            vertical: compactScaleValue(6),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: compactScaleValue(20),
                              height: compactScaleValue(20),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withValues(
                                  alpha: 0.8,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                icon,
                                size: compactScaleValue(11),
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            SizedBox(width: compactScaleValue(6)),
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize:
                                      (Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.fontSize ??
                                          14) *
                                      compactSheetScale *
                                      0.88,
                                ),
                              ),
                            ),
                            SizedBox(width: compactScaleValue(2)),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: compactScaleValue(14),
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                Widget buildInterfaceIconCapsule({
                  required IconData icon,
                  required String tooltip,
                  required VoidCallback onTap,
                }) {
                  final colorScheme = Theme.of(context).colorScheme;
                  return buildInterfaceInlineCapsule(
                    padding: EdgeInsets.zero,
                    child: SizedBox(
                      height: compactScaleValue(38),
                      width: compactScaleValue(38),
                      child: IconButton(
                        tooltip: tooltip,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: onTap,
                        icon: Icon(
                          icon,
                          size: compactScaleValue(16),
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }

                List<Widget> buildQuickMarginCards() {
                  final marginDivisions =
                      ((ReaderSettings.maxLayoutMargin -
                                  ReaderSettings.minLayoutMargin) /
                              _kMarginControlStep)
                          .round();
                  final effectiveMargins = draft.effectiveBodyMarginValues;
                  final groups = semanticGroups();
                  return <Widget>[
                    buildCompactSettingsCard([
                      Row(
                        children: [
                          Expanded(child: buildCompactSectionTitle('正文边距')),
                          TextButton.icon(
                            onPressed: () {
                              setModalState(() {
                                draft = draft.copyWith(
                                  bodyMarginMode: ReaderBodyMarginMode.custom,
                                  bodyMarginTop: 6,
                                  bodyMarginBottom: 6,
                                  bodyMarginLeft: 16,
                                  bodyMarginRight: 16,
                                );
                              });
                            },
                            icon: const Icon(
                              Icons.restart_alt_rounded,
                              size: 16,
                            ),
                            label: const Text('恢复默认'),
                          ),
                        ],
                      ),
                      Text(
                        '当前：上 ${groups.bodyLayout.bodyMarginTop.toStringAsFixed(0)} / 下 ${groups.bodyLayout.bodyMarginBottom.toStringAsFixed(0)} / 左 ${groups.bodyLayout.bodyMarginLeft.toStringAsFixed(0)} / 右 ${groups.bodyLayout.bodyMarginRight.toStringAsFixed(0)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      buildTypographySliderRow(
                        label: '上',
                        min: ReaderSettings.minLayoutMargin,
                        max: ReaderSettings.maxLayoutMargin,
                        divisions: marginDivisions,
                        value: draft.bodyMarginTop,
                        step: _kMarginControlStep,
                        valueLabel: _formatLayoutMarginValue(
                          draft.bodyMarginTop,
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(
                              bodyMarginMode: ReaderBodyMarginMode.custom,
                              bodyMarginTop: value,
                            );
                          });
                        },
                      ),
                      buildTypographySliderRow(
                        label: '下',
                        min: ReaderSettings.minLayoutMargin,
                        max: ReaderSettings.maxLayoutMargin,
                        divisions: marginDivisions,
                        value: draft.bodyMarginBottom,
                        step: _kMarginControlStep,
                        valueLabel: _formatLayoutMarginValue(
                          draft.bodyMarginBottom,
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(
                              bodyMarginMode: ReaderBodyMarginMode.custom,
                              bodyMarginBottom: value,
                            );
                          });
                        },
                      ),
                      buildTypographySliderRow(
                        label: '左',
                        min: ReaderSettings.minLayoutMargin,
                        max: ReaderSettings.maxLayoutMargin,
                        divisions: marginDivisions,
                        value: draft.bodyMarginLeft,
                        step: _kMarginControlStep,
                        valueLabel: _formatLayoutMarginValue(
                          draft.bodyMarginLeft,
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(
                              bodyMarginMode: ReaderBodyMarginMode.custom,
                              bodyMarginLeft: value,
                            );
                          });
                        },
                      ),
                      buildTypographySliderRow(
                        label: '右',
                        min: ReaderSettings.minLayoutMargin,
                        max: ReaderSettings.maxLayoutMargin,
                        divisions: marginDivisions,
                        value: draft.bodyMarginRight,
                        step: _kMarginControlStep,
                        valueLabel: _formatLayoutMarginValue(
                          draft.bodyMarginRight,
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(
                              bodyMarginMode: ReaderBodyMarginMode.custom,
                              bodyMarginRight: value,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '直接调整正文四边留白，默认口径对齐成熟阅读器的页面 padding。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '当前正文边距：上 ${effectiveMargins.top.round()} / 下 ${effectiveMargins.bottom.round()} / 左 ${effectiveMargins.left.round()} / 右 ${effectiveMargins.right.round()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ]),
                    buildCompactSettingsCard([
                      Row(
                        children: [
                          Expanded(child: buildCompactSectionTitle('阅读排版')),
                          TextButton.icon(
                            onPressed: () {
                              setModalState(() {
                                draft = draft.copyWith(
                                  lineHeight: 1.67,
                                  paragraphSpacing: 2,
                                  paragraphIndent: 2,
                                  letterSpacing:
                                      ReaderSettings.defaultLetterSpacing,
                                );
                              });
                            },
                            icon: const Icon(
                              Icons.restart_alt_rounded,
                              size: 16,
                            ),
                            label: const Text('恢复默认'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      buildTypographySliderRow(
                        label: '字距',
                        min: 0,
                        max: 100,
                        divisions: 100,
                        value: _letterSpacingSliderValue(draft),
                        step: 1,
                        valueLabel: _letterSpacingValueLabel(draft),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(
                              letterSpacing: _letterSpacingFromSliderValue(
                                value,
                              ),
                            );
                          });
                        },
                      ),
                      buildTypographySliderRow(
                        label: '行距',
                        min: 0,
                        max: 20,
                        divisions: 20,
                        value: _lineHeightSliderValue(draft),
                        step: 1,
                        valueLabel: _lineHeightValueLabel(draft),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(
                              lineHeight: _lineHeightFromSliderValue(
                                sliderValue: value,
                                settings: draft,
                              ),
                            );
                          });
                        },
                      ),
                      buildTypographySliderRow(
                        label: '段距',
                        min: 0,
                        max: 20,
                        divisions: 20,
                        value: draft.paragraphSpacing,
                        step: 1,
                        valueLabel: _paragraphSpacingValueLabel(draft),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(paragraphSpacing: value);
                          });
                        },
                      ),
                      buildTypographySliderRow(
                        label: '缩进',
                        min: 0,
                        max: 4,
                        divisions: 4,
                        value: draft.paragraphIndent.clamp(0, 4).toDouble(),
                        step: 1,
                        valueLabel: _paragraphIndentValueLabel(draft),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(
                              paragraphIndent:
                                  value.round().clamp(0, 4).toDouble(),
                            );
                          });
                        },
                      ),
                    ]),
                    buildCompactSettingsCard([
                      Row(
                        children: [
                          Expanded(child: buildCompactSectionTitle('章节头')),
                          TextButton.icon(
                            onPressed: () {
                              setModalState(() {
                                draft = draft.copyWith(
                                  chapterHeaderHorizontalOffset: 0,
                                  chapterHeaderVerticalOffset: 0,
                                );
                              });
                            },
                            icon: const Icon(
                              Icons.restart_alt_rounded,
                              size: 16,
                            ),
                            label: const Text('恢复默认'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      buildTypographySliderRow(
                        label: '横向',
                        min: ReaderSettings.minPinnedHeaderOffsetX,
                        max: ReaderSettings.maxPinnedHeaderOffsetX,
                        divisions: 100,
                        value: draft.chapterHeaderHorizontalOffset,
                        step: 0.01,
                        valueLabel:
                            (draft.chapterHeaderHorizontalOffset * 100)
                                .round()
                                .toString(),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(
                              chapterHeaderHorizontalOffset: value,
                            );
                          });
                        },
                      ),
                      buildTypographySliderRow(
                        label: '纵向',
                        min: ReaderSettings.minChapterHeaderSpacing,
                        max: ReaderSettings.maxChapterHeaderSpacing,
                        divisions: 20,
                        value: draft.chapterHeaderVerticalOffset,
                        step: 1,
                        valueLabel:
                            draft.chapterHeaderVerticalOffset
                                .round()
                                .toString(),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(
                              chapterHeaderVerticalOffset: value,
                            );
                          });
                        },
                      ),
                    ]),
                  ];
                }

                final quickToggleCard = buildSettingsSectionCard(
                  icon: Icons.toggle_on_rounded,
                  title: '快捷开关',
                  children: [
                    buildCompactToggleRow(
                      label: '文字两端对齐',
                      value: draft.textFullJustifyEnabled,
                      onChanged: (enabled) {
                        setModalState(() {
                          draft = draft.copyWith(
                            textFullJustifyEnabled: enabled,
                          );
                        });
                      },
                    ),
                    buildSectionDivider(),
                    buildCompactToggleRow(
                      label: '音量键翻页',
                      value: draft.volumeKeyPageEnabled,
                      onChanged:
                          ReaderVolumeKeyPageBridge.instance.isSupported
                              ? (enabled) {
                                setModalState(() {
                                  draft = draft.copyWith(
                                    volumeKeyPageEnabled: enabled,
                                  );
                                });
                              }
                              : null,
                    ),
                    if (!ReaderVolumeKeyPageBridge.instance.isSupported) ...[
                      const SizedBox(height: 4),
                      Text(
                        _volumeKeyPageSupportDescription,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                );

                final showInterfaceSettings =
                    activeSettingsTab == ReaderSettingsSheetTab.basic;
                final selectedCards = switch (activeSettingsGroupKey) {
                  null =>
                    showInterfaceSettings
                        ? <Widget>[
                          Row(
                            children: [
                              Text(
                                '亮度',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Slider(
                                  min: 0.2,
                                  max: 1,
                                  divisions: 8,
                                  value: draft.brightness,
                                  onChanged: (value) {
                                    setModalState(() {
                                      draft = draft.copyWith(brightness: value);
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 48,
                                child: TextButton.icon(
                                  onPressed: () {
                                    final selected =
                                        draft.themeMode !=
                                        ReaderThemeMode.sepia;
                                    setModalState(() {
                                      draft = draft.copyWith(
                                        themeMode:
                                            selected
                                                ? ReaderThemeMode.sepia
                                                : ReaderThemeMode.light,
                                        backgroundStyle:
                                            selected
                                                ? ReaderBackgroundStyle.warm
                                                : ReaderBackgroundStyle.plain,
                                        backgroundTone:
                                            selected
                                                ? ReaderBackgroundTone.container
                                                : ReaderBackgroundTone.surface,
                                      );
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: compactScaleValue(6),
                                      vertical: compactScaleValue(10),
                                    ),
                                  ),
                                  icon: Icon(
                                    draft.themeMode == ReaderThemeMode.sepia
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_outlined,
                                    size: compactScaleValue(16),
                                    color:
                                        draft.themeMode == ReaderThemeMode.sepia
                                            ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                            : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                  ),
                                  label: Text(
                                    '护眼',
                                    style: TextStyle(
                                      color:
                                          draft.themeMode ==
                                                  ReaderThemeMode.sepia
                                              ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                              : null,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: compactScaleValue(8)),
                          Row(
                            children: [
                              Expanded(
                                child: buildInterfaceCapsuleEntry(
                                  icon: Icons.format_size_rounded,
                                  title: '字体',
                                  margin: EdgeInsets.zero,
                                  onTap:
                                      () => setModalState(() {
                                        activeSettingsGroupKey = 'typography';
                                      }),
                                ),
                              ),
                              SizedBox(width: compactScaleValue(8)),
                              Expanded(
                                child: buildInterfaceCapsuleEntry(
                                  icon: Icons.fit_screen_rounded,
                                  title: '边距',
                                  margin: EdgeInsets.zero,
                                  onTap:
                                      () => setModalState(() {
                                        activeSettingsGroupKey =
                                            'quick_margins';
                                      }),
                                ),
                              ),
                              SizedBox(width: compactScaleValue(8)),
                              Expanded(
                                child: buildInterfaceCapsuleEntry(
                                  icon: Icons.info_outline_rounded,
                                  title: '信息',
                                  margin: EdgeInsets.zero,
                                  onTap:
                                      () => setModalState(() {
                                        activeSettingsGroupKey = 'info';
                                      }),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: compactScaleValue(8)),
                          Padding(
                            padding: EdgeInsets.only(
                              left: compactScaleValue(2),
                            ),
                            child: Text(
                              '字号',
                              style: Theme.of(
                                context,
                              ).textTheme.labelMedium?.copyWith(
                                fontSize:
                                    (Theme.of(
                                          context,
                                        ).textTheme.labelMedium?.fontSize ??
                                        12) *
                                    compactSheetScale *
                                    0.9,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          SizedBox(height: compactScaleValue(4)),
                          Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: buildInterfaceInlineCapsule(
                                  padding: EdgeInsets.zero,
                                  child: SizedBox(
                                    height: compactScaleValue(38),
                                    child: Row(
                                      children: [
                                        SizedBox(width: compactScaleValue(6)),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          constraints: BoxConstraints(
                                            minWidth: compactScaleValue(26),
                                            minHeight: compactScaleValue(26),
                                          ),
                                          padding: EdgeInsets.zero,
                                          onPressed: () {
                                            final next =
                                                (draft.fontSize - 1)
                                                    .clamp(5, 50)
                                                    .toDouble();
                                            setModalState(() {
                                              draft = draft.copyWith(
                                                fontSize: next,
                                              );
                                            });
                                          },
                                          icon: Icon(
                                            Icons.remove_rounded,
                                            size: compactScaleValue(15),
                                          ),
                                        ),
                                        Expanded(
                                          child: Center(
                                            child: Text(
                                              draft.fontSize.toStringAsFixed(0),
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                height: 1,
                                                fontSize:
                                                    (Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.fontSize ??
                                                        14) *
                                                    compactSheetScale *
                                                    0.95,
                                              ),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          constraints: BoxConstraints(
                                            minWidth: compactScaleValue(26),
                                            minHeight: compactScaleValue(26),
                                          ),
                                          padding: EdgeInsets.zero,
                                          onPressed: () {
                                            final next =
                                                (draft.fontSize + 1)
                                                    .clamp(5, 50)
                                                    .toDouble();
                                            setModalState(() {
                                              draft = draft.copyWith(
                                                fontSize: next,
                                              );
                                            });
                                          },
                                          icon: Icon(
                                            Icons.add_rounded,
                                            size: compactScaleValue(15),
                                          ),
                                        ),
                                        SizedBox(width: compactScaleValue(6)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: compactScaleValue(6)),
                              Expanded(
                                flex: 4,
                                child: buildInterfaceSecondaryCapsule(
                                  icon: Icons.format_size_rounded,
                                  title: currentFontLabel(),
                                  onTap: openFontPickerSheet,
                                ),
                              ),
                              SizedBox(width: compactScaleValue(6)),
                              buildInterfaceIconCapsule(
                                icon: Icons.tune_rounded,
                                tooltip: '更多',
                                onTap:
                                    () => setModalState(() {
                                      activeSettingsGroupKey = 'interaction';
                                    }),
                              ),
                            ],
                          ),
                          SizedBox(height: compactScaleValue(14)),
                          buildCompactSectionTitle('背景色'),
                          SizedBox(height: compactScaleValue(10)),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _readerBackgroundColorOptions()
                                  .map(
                                    (option) => _buildThemeColorDot(
                                      draft: draft,
                                      color: option.previewColor,
                                      label: option.label,
                                      mode: option.mode,
                                      backgroundStyle: option.backgroundStyle,
                                      backgroundTone: option.backgroundTone,
                                      scale: compactSheetScale,
                                      onChanged: updateDraft,
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                          SizedBox(height: compactScaleValue(14)),
                          buildCompactSectionTitle('背景图'),
                          SizedBox(height: compactScaleValue(10)),
                          ScrollConfiguration(
                            behavior: ScrollConfiguration.of(
                              context,
                            ).copyWith(dragDevices: _kScrollDragDevices),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildBackgroundTile(
                                    label: '无背景',
                                    selected: !hasBackgroundImage,
                                    icon: Icons.hide_image_outlined,
                                    scale: compactSheetScale,
                                    onTap: () {
                                      updateDraft(
                                        draft.copyWith(
                                          clearBackgroundImage: true,
                                        ),
                                      );
                                    },
                                  ),
                                  SizedBox(width: compactScaleValue(8)),
                                  ...presetBackgroundTiles,
                                  ...customBackgroundTiles,
                                  _buildBackgroundTile(
                                    label: '自定义',
                                    selected: false,
                                    icon: Icons.upload_file_rounded,
                                    showLabel: true,
                                    scale: compactSheetScale,
                                    onTap: applyCustomBackgroundImage,
                                  ),
                                  SizedBox(width: compactScaleValue(8)),
                                  OutlinedButton.icon(
                                    onPressed:
                                        () => unawaited(
                                          openMineReaderBackgroundManagement(),
                                        ),
                                    icon: const Icon(
                                      Icons.open_in_new_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('去我的管理'),
                                  ),
                                  if (hasBackgroundImage) ...[
                                    SizedBox(width: compactScaleValue(8)),
                                    OutlinedButton(
                                      onPressed:
                                          () => unawaited(
                                            removeActiveBackground(),
                                          ),
                                      child: const Text('移除'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          buildCompactSectionTitle('翻页动画'),
                          const SizedBox(height: 10),
                          if (pageAnimationInactiveReason != null)
                            Text(
                              pageAnimationInactiveReason,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            )
                          else
                            buildPageAnimationSelector(),
                        ]
                        : <Widget>[
                          buildSettingsGroupEntryCard(
                            icon: Icons.toggle_on_rounded,
                            title: '阅读行为',
                            subtitle: '对齐、按键行为等常用开关',
                            onTap:
                                () => setModalState(() {
                                  activeSettingsGroupKey = 'behavior';
                                }),
                          ),
                          const SizedBox(height: 10),
                          buildSettingsGroupEntryCard(
                            icon: Icons.auto_awesome_motion_outlined,
                            title: '自动阅读',
                            subtitle: '启动方式、速度与本次自动阅读行为',
                            onTap:
                                () => setModalState(() {
                                  activeSettingsGroupKey = 'auto_read';
                                }),
                          ),
                        ],
                  'quick_margins' => buildQuickMarginCards(),
                  'typography' => <Widget>[
                    buildCompactSectionTitle('字体样式'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          currentFontLabel(),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: () => unawaited(openFontWeightTabSheet()),
                          child: Text(fontWeightDisplayLabel(draft)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => unawaited(openMineFontManagement()),
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text('去我的管理'),
                        ),
                      ],
                    ),
                    buildSectionDivider(),
                    buildCompactSectionTitle(
                      '颜色样式',
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                draft = draft.copyWith(
                                  clearBodyTextColor: true,
                                );
                              });
                            },
                            child: const Text('跟随主题'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () async {
                              final selectedColor =
                                  await _showBodyTextColorPickerDialog(
                                    context,
                                    initialColorValue: draft.bodyTextColorValue,
                                  );
                              if (selectedColor == null || !context.mounted) {
                                return;
                              }
                              setModalState(() {
                                draft = draft.copyWith(
                                  bodyTextColorValue: selectedColor,
                                );
                              });
                              unawaited(rememberBodyTextColor(selectedColor));
                            },
                            icon: const Icon(Icons.colorize_rounded, size: 16),
                            label: const Text('自定义'),
                          ),
                        ],
                      ),
                    ),
                    if (draft.bodyTextColorValue != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color(draft.bodyTextColorValue!),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                    buildSectionDivider(),
                    buildCompactSectionTitle('字体细节'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('斜体'),
                          selected: draft.bodyTextItalicEnabled,
                          showCheckmark: false,
                          onSelected: (selected) {
                            setModalState(() {
                              draft = draft.copyWith(
                                bodyTextItalicEnabled: selected,
                              );
                            });
                          },
                        ),
                        FilterChip(
                          label: const Text('阴影'),
                          selected: draft.bodyTextShadowEnabled,
                          showCheckmark: false,
                          onSelected: (selected) {
                            setModalState(() {
                              draft = draft.copyWith(
                                bodyTextShadowEnabled: selected,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                    if (draft.bodyTextShadowEnabled) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final selectedColor =
                                  await _showBodyTextShadowColorPickerDialog(
                                    context,
                                    initialColorValue:
                                        draft.bodyTextShadowColorValue,
                                  );
                              if (selectedColor == null || !context.mounted) {
                                return;
                              }
                              setModalState(() {
                                draft = draft.copyWith(
                                  bodyTextShadowColorValue: selectedColor,
                                );
                              });
                            },
                            icon: const Icon(Icons.blur_on_rounded, size: 16),
                            label: const Text('阴影颜色'),
                          ),
                          if (draft.bodyTextShadowColorValue != null) ...[
                            const SizedBox(width: 10),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Color(draft.bodyTextShadowColorValue!),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      buildTypographySliderRow(
                        label: '模糊',
                        min: 0,
                        max: 32,
                        divisions: 32,
                        value: draft.bodyTextShadowBlurRadius,
                        step: 1,
                        valueLabel:
                            draft.bodyTextShadowBlurRadius.round().toString(),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(
                              bodyTextShadowBlurRadius: value,
                            );
                          });
                        },
                      ),
                      buildTypographySliderRow(
                        label: 'X轴',
                        min: -24,
                        max: 24,
                        divisions: 48,
                        value: draft.bodyTextShadowOffsetDx,
                        step: 1,
                        valueLabel: draft.bodyTextShadowOffsetDx
                            .toStringAsFixed(0),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(
                              bodyTextShadowOffsetDx: value,
                            );
                          });
                        },
                      ),
                      buildTypographySliderRow(
                        label: 'Y轴',
                        min: -24,
                        max: 24,
                        divisions: 48,
                        value: draft.bodyTextShadowOffsetDy,
                        step: 1,
                        valueLabel: draft.bodyTextShadowOffsetDy
                            .toStringAsFixed(0),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(
                              bodyTextShadowOffsetDy: value,
                            );
                          });
                        },
                      ),
                    ],
                    buildSectionDivider(),
                    buildCompactSectionTitle('下划线'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('下划线'),
                          selected:
                              draft.bodyTextDecorationStyle !=
                              ReaderBodyTextDecorationStyle.none,
                          showCheckmark: false,
                          onSelected: (selected) {
                            setModalState(() {
                              draft = draft.copyWith(
                                bodyTextDecorationStyle:
                                    selected
                                        ? ReaderBodyTextDecorationStyle.solid
                                        : ReaderBodyTextDecorationStyle.none,
                              );
                            });
                          },
                        ),
                        FilterChip(
                          label: const Text('虚线'),
                          selected:
                              draft.bodyTextDecorationStyle ==
                              ReaderBodyTextDecorationStyle.dashed,
                          showCheckmark: false,
                          onSelected:
                              draft.bodyTextDecorationStyle ==
                                      ReaderBodyTextDecorationStyle.none
                                  ? null
                                  : (selected) {
                                    setModalState(() {
                                      draft = draft.copyWith(
                                        bodyTextDecorationStyle:
                                            selected
                                                ? ReaderBodyTextDecorationStyle
                                                    .dashed
                                                : ReaderBodyTextDecorationStyle
                                                    .solid,
                                      );
                                    });
                                  },
                        ),
                      ],
                    ),
                    if (draft.bodyTextDecorationStyle !=
                        ReaderBodyTextDecorationStyle.none) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              setModalState(() {
                                draft = draft.copyWith(
                                  clearBodyTextDecorationColor: true,
                                );
                              });
                            },
                            icon: const Icon(Icons.format_color_reset_rounded),
                            label: const Text('下划线颜色'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final selectedColor =
                                  await _showBodyTextDecorationColorPickerDialog(
                                    context,
                                    initialColorValue:
                                        draft.bodyTextDecorationColorValue,
                                  );
                              if (selectedColor == null || !context.mounted) {
                                return;
                              }
                              setModalState(() {
                                draft = draft.copyWith(
                                  bodyTextDecorationColorValue: selectedColor,
                                );
                              });
                            },
                            icon: const Icon(Icons.colorize_rounded, size: 16),
                            label: const Text('自定义颜色'),
                          ),
                          if (draft.bodyTextDecorationColorValue != null) ...[
                            const SizedBox(width: 10),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Color(
                                  draft.bodyTextDecorationColorValue!,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      buildTypographySliderRow(
                        label: '线段高度',
                        min: 1,
                        max: 10,
                        divisions: 18,
                        value: draft.bodyTextUnderlineThickness,
                        step: 0.5,
                        valueLabel: draft.bodyTextUnderlineThickness
                            .toStringAsFixed(1),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(
                              bodyTextUnderlineThickness: value,
                            );
                          });
                        },
                      ),
                      buildTypographySliderRow(
                        label: '离字间距',
                        min: 0,
                        max: 16,
                        divisions: 16,
                        value: draft.bodyTextUnderlineGap,
                        step: 1,
                        valueLabel:
                            draft.bodyTextUnderlineGap.round().toString(),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(bodyTextUnderlineGap: value);
                          });
                        },
                      ),
                      if (draft.bodyTextDecorationStyle ==
                          ReaderBodyTextDecorationStyle.dashed) ...[
                        buildTypographySliderRow(
                          label: '线段长',
                          min: 1,
                          max: 24,
                          divisions: 23,
                          value: draft.bodyTextUnderlineDashLength,
                          step: 1,
                          valueLabel:
                              draft.bodyTextUnderlineDashLength
                                  .round()
                                  .toString(),
                          onChanged: (value) {
                            setModalState(() {
                              draft = draft.copyWith(
                                bodyTextUnderlineDashLength: value,
                              );
                            });
                          },
                        ),
                        buildTypographySliderRow(
                          label: '空隙比例',
                          min: 1,
                          max: 12,
                          divisions: 11,
                          value: draft.bodyTextUnderlineDashGapRatio,
                          step: 1,
                          valueLabel:
                              draft.bodyTextUnderlineDashGapRatio
                                  .round()
                                  .toString(),
                          onChanged: (value) {
                            setModalState(() {
                              draft = draft.copyWith(
                                bodyTextUnderlineDashGapRatio: value,
                              );
                            });
                          },
                        ),
                      ],
                    ],
                    buildSectionDivider(),
                  ],
                  'interaction' => <Widget>[
                    buildCompactSettingsCard([
                      buildCompactSectionTitle('触发方式'),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            FilterChip(
                              label: const Text('点按'),
                              selected: _pageTurnIncludesTap(
                                draft.pageTurnMode,
                              ),
                              showCheckmark: false,
                              onSelected: (selected) {
                                setModalState(() {
                                  draft = draft.copyWith(
                                    pageTurnMode: _applyPageTurnToggle(
                                      draft.pageTurnMode,
                                      tapEnabled: selected,
                                    ),
                                  );
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: const Text('滑动'),
                              selected: _pageTurnIncludesSwipe(
                                draft.pageTurnMode,
                              ),
                              showCheckmark: false,
                              onSelected: (selected) {
                                setModalState(() {
                                  draft = draft.copyWith(
                                    pageTurnMode: _applyPageTurnToggle(
                                      draft.pageTurnMode,
                                      swipeEnabled: selected,
                                    ),
                                  );
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: const Text('滚动'),
                              selected: _pageTurnUsesScroll(draft.pageTurnMode),
                              showCheckmark: false,
                              onSelected: (selected) {
                                setModalState(() {
                                  draft = draft.copyWith(
                                    pageTurnMode: _applyPageTurnToggle(
                                      draft.pageTurnMode,
                                      scrollEnabled: selected,
                                    ),
                                  );
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      buildSectionDivider(),
                      buildCompactSectionTitle('翻页动画'),
                      const SizedBox(height: 10),
                      if (pageAnimationInactiveReason != null)
                        Text(
                          pageAnimationInactiveReason,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        )
                      else
                        buildPageAnimationSelector(),
                      buildSectionDivider(),
                      buildCompactSectionTitle('音量键翻页'),
                      const SizedBox(height: 10),
                      buildCompactToggleRow(
                        label: '启用',
                        value: draft.volumeKeyPageEnabled,
                        onChanged:
                            ReaderVolumeKeyPageBridge.instance.isSupported
                                ? (enabled) {
                                  setModalState(() {
                                    draft = draft.copyWith(
                                      volumeKeyPageEnabled: enabled,
                                    );
                                  });
                                }
                                : null,
                      ),
                    ]),
                  ],
                  'info' => <Widget>[
                    buildCompactSettingsCard([
                      buildCompactSectionTitle('信息位'),
                      const SizedBox(height: 10),
                      buildCompactToggleRow(
                        label: '显示页脚',
                        value: draft.infoFooterEnabled,
                        onChanged: (enabled) {
                          setModalState(() {
                            draft = draft.copyWith(
                              infoFooterEnabled: enabled,
                              infoFooterDividerEnabled:
                                  enabled
                                      ? draft.infoFooterDividerEnabled
                                      : false,
                            );
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('时间'),
                            selected: draft.infoShowTime,
                            onSelected: (selected) {
                              setModalState(() {
                                draft = draft.copyWith(
                                  infoShowTime: selected,
                                  infoShowProgress:
                                      !selected &&
                                              !draft.infoShowBattery &&
                                              !draft.infoShowProgress
                                          ? true
                                          : draft.infoShowProgress,
                                );
                              });
                            },
                          ),
                          FilterChip(
                            label: const Text('电量'),
                            selected: draft.infoShowBattery,
                            onSelected: (selected) {
                              setModalState(() {
                                draft = draft.copyWith(
                                  infoShowBattery: selected,
                                  infoShowProgress:
                                      !selected &&
                                              !draft.infoShowTime &&
                                              !draft.infoShowProgress
                                          ? true
                                          : draft.infoShowProgress,
                                );
                              });
                            },
                          ),
                          FilterChip(
                            label: const Text('进度'),
                            selected: draft.infoShowProgress,
                            onSelected: (selected) {
                              setModalState(() {
                                draft = draft.copyWith(
                                  infoShowProgress:
                                      selected ||
                                              (!draft.infoShowTime &&
                                                  !draft.infoShowBattery)
                                          ? true
                                          : selected,
                                );
                              });
                            },
                          ),
                          FilterChip(
                            label: const Text('章节'),
                            selected: draft.infoShowChapter,
                            onSelected: (selected) {
                              setModalState(() {
                                draft = draft.copyWith(
                                  infoShowChapter: selected,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      buildCompactSectionTitle('页脚样式'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('页脚分隔线'),
                            selected:
                                draft.infoFooterEnabled &&
                                draft.infoFooterDividerEnabled,
                            showCheckmark: false,
                            onSelected:
                                draft.infoFooterEnabled
                                    ? (selected) {
                                      setModalState(() {
                                        draft = draft.copyWith(
                                          infoFooterDividerEnabled: selected,
                                        );
                                      });
                                    }
                                    : null,
                          ),
                        ],
                      ),
                      buildTypographySliderRow(
                        label: '页脚内距',
                        min: ReaderSettings.minInfoBarPadding,
                        max: ReaderSettings.maxInfoBarPadding,
                        divisions: 24,
                        value: draft.infoFooterPadding,
                        step: 1,
                        valueLabel: draft.infoFooterPadding.round().toString(),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(infoFooterPadding: value);
                          });
                        },
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed:
                              () => unawaited(openHorizontalPaddingTabSheet()),
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: const Text('页脚与正文边距'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '当前启用 ${enabledInfoItemCount()} 项信息，控制正文页底部/角落的信息显示。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                      if (draft.infoShowBattery) ...[
                        const SizedBox(height: 6),
                        Text(
                          _readerBatteryReadFailed
                              ? '当前平台未返回电量值，已显示为 N/A。'
                              : '电量为实时读取，约每 30 秒刷新一次。',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ]),
                  ],
                  'behavior' => <Widget>[
                    buildCompactSettingsCard([quickToggleCard]),
                  ],
                  'auto_read' => <Widget>[
                    buildCompactSettingsCard([
                      buildCompactSectionTitle('自动阅读'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              startAutoReadAfterApply
                                  ? '关闭弹窗后立即启动自动阅读'
                                  : '本次不启动自动阅读',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Switch.adaptive(
                            value: startAutoReadAfterApply,
                            onChanged: (enabled) {
                              setModalState(() {
                                startAutoReadAfterApply = enabled;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '速度 ${draft.autoReadSpeed.round()} px/s',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Slider(
                        min: ReaderSettings.minAutoReadSpeed,
                        max: ReaderSettings.maxAutoReadSpeed,
                        divisions: 20,
                        label: '${draft.autoReadSpeed.round()}',
                        value:
                            draft.autoReadSpeed
                                .clamp(
                                  ReaderSettings.minAutoReadSpeed,
                                  ReaderSettings.maxAutoReadSpeed,
                                )
                                .toDouble(),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(autoReadSpeed: value);
                          });
                        },
                      ),
                    ]),
                  ],
                  _ => const <Widget>[],
                };
                final sheetTitle = switch (activeSettingsGroupKey) {
                  'quick_margins' => '边距与排版',
                  'typography' => '字体',
                  'interaction' => '翻页与动画',
                  'info' => '信息排版',
                  'behavior' => '阅读行为',
                  'auto_read' => '自动阅读',
                  _ => showInterfaceSettings ? '界面设置' : '设置',
                };
                final textSheetMaxWidth = AppLayout.pageContentMaxWidth(
                  context,
                  maxWidth: 760,
                );

                return AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.only(bottom: keyboardInset + safeBottom),
                  child: SafeArea(
                    child: FractionallySizedBox(
                      heightFactor: _adaptiveReaderSheetHeightFactor(
                        context,
                        compact: 0.84,
                        regular: 0.76,
                        large: 0.7,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: textSheetMaxWidth,
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              sheetHorizontal,
                              8,
                              sheetHorizontal,
                              14,
                            ),
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 40,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      if (activeSettingsGroupKey != null)
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: IconButton(
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: () {
                                              setModalState(() {
                                                activeSettingsGroupKey = null;
                                              });
                                            },
                                            icon: const Icon(
                                              Icons.arrow_back_rounded,
                                            ),
                                          ),
                                        ),
                                      Center(
                                        child: Text(
                                          sheetTitle,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: ListView(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    children: selectedCards,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              previewDraftSettings();

              if (!isMangaChapter) {
                return buildTextReaderSettingsSheet();
              }

              return AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(bottom: keyboardInset + safeBottom),
                child: SafeArea(
                  child: FractionallySizedBox(
                    heightFactor: sheetHeightFactor,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxSheetWidth),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            sheetHorizontal,
                            8,
                            sheetHorizontal,
                            14,
                          ),
                          child: Column(
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  showInterfaceSection
                                      ? _readerModeCapabilities
                                          .interfaceSettingsTitle
                                      : _readerModeCapabilities
                                          .readingSettingsTitle,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: ListView(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  children: [
                                    if (showInterfaceSection) ...[
                                      _buildSettingLine(
                                        context: context,
                                        label: '亮度',
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Slider(
                                                    min: 0.2,
                                                    max: 1,
                                                    divisions: 8,
                                                    value: draft.brightness,
                                                    label:
                                                        '${(draft.brightness * 100).round()}%',
                                                    onChanged: (value) {
                                                      setModalState(() {
                                                        draft = draft.copyWith(
                                                          brightness: value,
                                                        );
                                                      });
                                                      previewDraftSettings();
                                                    },
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 44,
                                                  child: Text(
                                                    '${(draft.brightness * 100).round()}%',
                                                    textAlign: TextAlign.right,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelMedium
                                                        ?.copyWith(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurfaceVariant,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                    _createReaderBackgroundColorOption(
                                                      label: '浅色',
                                                      mode:
                                                          ReaderThemeMode.light,
                                                      backgroundStyle:
                                                          ReaderBackgroundStyle
                                                              .plain,
                                                      backgroundTone:
                                                          ReaderBackgroundTone
                                                              .surface,
                                                    ),
                                                    _createReaderBackgroundColorOption(
                                                      label: '护眼',
                                                      mode:
                                                          ReaderThemeMode.sepia,
                                                      backgroundStyle:
                                                          ReaderBackgroundStyle
                                                              .warm,
                                                      backgroundTone:
                                                          ReaderBackgroundTone
                                                              .container,
                                                    ),
                                                    _createReaderBackgroundColorOption(
                                                      label: '深色',
                                                      mode:
                                                          ReaderThemeMode.dark,
                                                      backgroundStyle:
                                                          ReaderBackgroundStyle
                                                              .plain,
                                                      backgroundTone:
                                                          ReaderBackgroundTone
                                                              .pureBlack,
                                                    ),
                                                    _createReaderBackgroundColorOption(
                                                      label: '纸张',
                                                      mode:
                                                          ReaderThemeMode.light,
                                                      backgroundStyle:
                                                          ReaderBackgroundStyle
                                                              .paper,
                                                      backgroundTone:
                                                          ReaderBackgroundTone
                                                              .containerHigh,
                                                    ),
                                                  ]
                                                  .map((option) {
                                                    final normalizedTone =
                                                        normalizeReaderBackgroundTone(
                                                          mode: draft.themeMode,
                                                          tone:
                                                              draft
                                                                  .backgroundTone,
                                                        );
                                                    final selected =
                                                        draft.themeMode ==
                                                            option.mode &&
                                                        draft.backgroundStyle ==
                                                            option
                                                                .backgroundStyle &&
                                                        normalizedTone ==
                                                            option
                                                                .backgroundTone;
                                                    return ChoiceChip(
                                                      label: Text(option.label),
                                                      selected: selected,
                                                      showCheckmark: false,
                                                      onSelected: (_) {
                                                        setModalState(() {
                                                          draft = draft.copyWith(
                                                            themeMode:
                                                                option.mode,
                                                            backgroundStyle:
                                                                option
                                                                    .backgroundStyle,
                                                            backgroundTone:
                                                                option
                                                                    .backgroundTone,
                                                          );
                                                        });
                                                        previewDraftSettings();
                                                      },
                                                    );
                                                  })
                                                  .toList(growable: false),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isMangaChapter) ...[
                                        const Divider(height: 1),
                                        _buildSettingLine(
                                          context: context,
                                          label: '字号',
                                          child: Row(
                                            children: [
                                              IconButton.filledTonal(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                onPressed: () {
                                                  final next =
                                                      (draft.fontSize - 1)
                                                          .clamp(5, 50)
                                                          .toDouble();
                                                  setModalState(() {
                                                    draft = draft.copyWith(
                                                      fontSize: next,
                                                    );
                                                  });
                                                },
                                                icon: const Icon(Icons.remove),
                                              ),
                                              SizedBox(
                                                width: 40,
                                                child: Center(
                                                  child: Text(
                                                    draft.fontSize
                                                        .toStringAsFixed(0),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              IconButton.filledTonal(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                onPressed: () {
                                                  final next =
                                                      (draft.fontSize + 1)
                                                          .clamp(5, 50)
                                                          .toDouble();
                                                  setModalState(() {
                                                    draft = draft.copyWith(
                                                      fontSize: next,
                                                    );
                                                  });
                                                },
                                                icon: const Icon(Icons.add),
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: OutlinedButton(
                                                  onPressed:
                                                      openFontPickerSheet,
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                        alignment:
                                                            Alignment.center,
                                                      ),
                                                  child: Text(
                                                    currentFontLabel(),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const Divider(height: 1),
                                      _buildSettingLine(
                                        context: context,
                                        label: '背景颜色',
                                        labelWidth: 72,
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children:
                                                _readerBackgroundColorOptions()
                                                    .map(
                                                      (
                                                        option,
                                                      ) => _buildThemeColorDot(
                                                        draft: draft,
                                                        color:
                                                            option.previewColor,
                                                        label: option.label,
                                                        mode: option.mode,
                                                        backgroundStyle:
                                                            option
                                                                .backgroundStyle,
                                                        backgroundTone:
                                                            option
                                                                .backgroundTone,
                                                        onChanged: (next) {
                                                          setModalState(() {
                                                            draft = next;
                                                          });
                                                        },
                                                      ),
                                                    )
                                                    .toList(growable: false),
                                          ),
                                        ),
                                      ),
                                      const Divider(height: 1),
                                      _buildSettingLine(
                                        context: context,
                                        label: '背景',
                                        child: ScrollConfiguration(
                                          behavior: ScrollConfiguration.of(
                                            context,
                                          ).copyWith(
                                            dragDevices: _kScrollDragDevices,
                                          ),
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children: [
                                                _buildBackgroundTile(
                                                  label: '无背景',
                                                  selected: !hasBackgroundImage,
                                                  icon:
                                                      Icons.hide_image_outlined,
                                                  onTap: () {
                                                    setModalState(() {
                                                      draft = draft.copyWith(
                                                        clearBackgroundImage:
                                                            true,
                                                      );
                                                    });
                                                    unawaited(
                                                      persistBackgroundDraftNow(
                                                        draft,
                                                      ),
                                                    );
                                                  },
                                                ),
                                                const SizedBox(width: 8),
                                                ...presetBackgroundTiles,
                                                ...customBackgroundTiles,
                                                _buildBackgroundTile(
                                                  label: '自定义',
                                                  selected: false,
                                                  icon:
                                                      Icons.upload_file_rounded,
                                                  showLabel: true,
                                                  onTap:
                                                      applyCustomBackgroundImage,
                                                ),
                                                if (hasBackgroundImage) ...[
                                                  const SizedBox(width: 8),
                                                  OutlinedButton(
                                                    onPressed:
                                                        () => unawaited(
                                                          removeActiveBackground(),
                                                        ),
                                                    child: const Text('移除'),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (showReadingSection) ...[
                                      if (showInterfaceSection)
                                        const Divider(height: 1),
                                      if (!isMangaChapter)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children: [
                                                buildReadingActionTab(
                                                  label: '字重',
                                                  value: fontWeightDisplayLabel(
                                                    draft,
                                                  ),
                                                  onTap:
                                                      () => unawaited(
                                                        openFontWeightTabSheet(),
                                                      ),
                                                ),
                                                buildReadingActionTab(
                                                  label: '边距',
                                                  value:
                                                      _bodyMarginDisplayValue(
                                                        draft,
                                                      ),
                                                  onTap:
                                                      () => unawaited(
                                                        openHorizontalPaddingTabSheet(),
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      if (!isMangaChapter)
                                        const Divider(height: 1),
                                      if (!isMangaChapter)
                                        _buildSettingLine(
                                          context: context,
                                          label: '排版',
                                          child: Column(
                                            children: [
                                              Row(
                                                children: [
                                                  const Spacer(),
                                                  Switch.adaptive(
                                                    value:
                                                        draft
                                                            .textFullJustifyEnabled,
                                                    onChanged: (enabled) {
                                                      setModalState(() {
                                                        draft = draft.copyWith(
                                                          textFullJustifyEnabled:
                                                              enabled,
                                                        );
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  Text(
                                                    '斜体',
                                                    style:
                                                        Theme.of(
                                                          context,
                                                        ).textTheme.bodyMedium,
                                                  ),
                                                  const Spacer(),
                                                  Switch.adaptive(
                                                    value:
                                                        draft
                                                            .bodyTextItalicEnabled,
                                                    onChanged: (enabled) {
                                                      setModalState(() {
                                                        draft = draft.copyWith(
                                                          bodyTextItalicEnabled:
                                                              enabled,
                                                        );
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  Text(
                                                    '阴影',
                                                    style:
                                                        Theme.of(
                                                          context,
                                                        ).textTheme.bodyMedium,
                                                  ),
                                                  const Spacer(),
                                                  Switch.adaptive(
                                                    value:
                                                        draft
                                                            .bodyTextShadowEnabled,
                                                    onChanged: (enabled) {
                                                      setModalState(() {
                                                        draft = draft.copyWith(
                                                          bodyTextShadowEnabled:
                                                              enabled,
                                                        );
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                              if (draft.bodyTextShadowEnabled)
                                                buildTypographySliderRow(
                                                  label: '模糊',
                                                  min: 0,
                                                  max: 32,
                                                  divisions: 32,
                                                  value:
                                                      draft
                                                          .bodyTextShadowBlurRadius,
                                                  step: 1,
                                                  valueLabel:
                                                      draft
                                                          .bodyTextShadowBlurRadius
                                                          .round()
                                                          .toString(),
                                                  onChanged: (value) {
                                                    setModalState(() {
                                                      draft = draft.copyWith(
                                                        bodyTextShadowBlurRadius:
                                                            value,
                                                      );
                                                    });
                                                  },
                                                ),
                                              const SizedBox(height: 4),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: ReaderBodyTextDecorationStyle
                                                    .values
                                                    .map(
                                                      (style) => ChoiceChip(
                                                        label: Text(
                                                          decorationStyleLabel(
                                                            style,
                                                          ),
                                                        ),
                                                        selected:
                                                            draft
                                                                .bodyTextDecorationStyle ==
                                                            style,
                                                        onSelected: (_) {
                                                          setModalState(() {
                                                            draft = draft.copyWith(
                                                              bodyTextDecorationStyle:
                                                                  style,
                                                            );
                                                          });
                                                        },
                                                      ),
                                                    )
                                                    .toList(growable: false),
                                              ),
                                              if (draft
                                                      .bodyTextDecorationStyle !=
                                                  ReaderBodyTextDecorationStyle
                                                      .none)
                                                Row(
                                                  children: [
                                                    OutlinedButton(
                                                      onPressed: () {
                                                        setModalState(() {
                                                          draft = draft.copyWith(
                                                            clearBodyTextDecorationColor:
                                                                true,
                                                          );
                                                        });
                                                      },
                                                      child: const Text(
                                                        '下划线跟随文字',
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    OutlinedButton(
                                                      onPressed: () async {
                                                        final selectedColor =
                                                            await _showBodyTextDecorationColorPickerDialog(
                                                              context,
                                                              initialColorValue:
                                                                  draft
                                                                      .bodyTextDecorationColorValue,
                                                            );
                                                        if (selectedColor ==
                                                                null ||
                                                            !context.mounted) {
                                                          return;
                                                        }
                                                        setModalState(() {
                                                          draft = draft.copyWith(
                                                            bodyTextDecorationColorValue:
                                                                selectedColor,
                                                          );
                                                        });
                                                      },
                                                      child: const Text(
                                                        '下划线颜色',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              if (draft
                                                      .bodyTextDecorationStyle !=
                                                  ReaderBodyTextDecorationStyle
                                                      .none)
                                                buildTypographySliderRow(
                                                  label: '粗细',
                                                  min: 1,
                                                  max: 10,
                                                  divisions: 18,
                                                  value:
                                                      draft
                                                          .bodyTextUnderlineThickness,
                                                  step: 0.5,
                                                  valueLabel: draft
                                                      .bodyTextUnderlineThickness
                                                      .toStringAsFixed(1),
                                                  onChanged: (value) {
                                                    setModalState(() {
                                                      draft = draft.copyWith(
                                                        bodyTextUnderlineThickness:
                                                            value,
                                                      );
                                                    });
                                                  },
                                                ),
                                              if (draft
                                                      .bodyTextDecorationStyle !=
                                                  ReaderBodyTextDecorationStyle
                                                      .none)
                                                buildTypographySliderRow(
                                                  label: '间距',
                                                  min: 0,
                                                  max: 16,
                                                  divisions: 16,
                                                  value:
                                                      draft
                                                          .bodyTextUnderlineGap,
                                                  step: 1,
                                                  valueLabel:
                                                      draft.bodyTextUnderlineGap
                                                          .round()
                                                          .toString(),
                                                  onChanged: (value) {
                                                    setModalState(() {
                                                      draft = draft.copyWith(
                                                        bodyTextUnderlineGap:
                                                            value,
                                                      );
                                                    });
                                                  },
                                                ),
                                              if (draft
                                                      .bodyTextDecorationStyle ==
                                                  ReaderBodyTextDecorationStyle
                                                      .dashed)
                                                buildTypographySliderRow(
                                                  label: '线长',
                                                  min: 1,
                                                  max: 24,
                                                  divisions: 23,
                                                  value:
                                                      draft
                                                          .bodyTextUnderlineDashLength,
                                                  step: 1,
                                                  valueLabel:
                                                      draft
                                                          .bodyTextUnderlineDashLength
                                                          .round()
                                                          .toString(),
                                                  onChanged: (value) {
                                                    setModalState(() {
                                                      draft = draft.copyWith(
                                                        bodyTextUnderlineDashLength:
                                                            value,
                                                      );
                                                    });
                                                  },
                                                ),
                                              if (draft
                                                      .bodyTextDecorationStyle ==
                                                  ReaderBodyTextDecorationStyle
                                                      .dashed)
                                                buildTypographySliderRow(
                                                  label: '比例',
                                                  min: 1,
                                                  max: 12,
                                                  divisions: 11,
                                                  value:
                                                      draft
                                                          .bodyTextUnderlineDashGapRatio,
                                                  step: 1,
                                                  valueLabel:
                                                      draft
                                                          .bodyTextUnderlineDashGapRatio
                                                          .round()
                                                          .toString(),
                                                  onChanged: (value) {
                                                    setModalState(() {
                                                      draft = draft.copyWith(
                                                        bodyTextUnderlineDashGapRatio:
                                                            value,
                                                      );
                                                    });
                                                  },
                                                ),
                                              const SizedBox(height: 8),
                                              buildTypographySliderRow(
                                                label: '字号',
                                                min: 5,
                                                max: 50,
                                                divisions: 45,
                                                value: draft.fontSize,
                                                step: 1,
                                                valueLabel: _fontSizeValueLabel(
                                                  draft,
                                                ),
                                                showValueLabel: false,
                                                onChanged: (value) {
                                                  setModalState(() {
                                                    draft = draft.copyWith(
                                                      fontSize: value,
                                                    );
                                                  });
                                                },
                                              ),
                                              buildTypographySliderRow(
                                                label: '字距',
                                                min: 0,
                                                max: 100,
                                                divisions: 100,
                                                value:
                                                    _letterSpacingSliderValue(
                                                      draft,
                                                    ),
                                                step: 1,
                                                valueLabel:
                                                    _letterSpacingValueLabel(
                                                      draft,
                                                    ),
                                                onChanged: (value) {
                                                  setModalState(() {
                                                    draft = draft.copyWith(
                                                      letterSpacing:
                                                          _letterSpacingFromSliderValue(
                                                            value,
                                                          ),
                                                    );
                                                  });
                                                },
                                              ),
                                              buildTypographySliderRow(
                                                label: '行距',
                                                min: 0,
                                                max: 20,
                                                divisions: 20,
                                                value: _lineHeightSliderValue(
                                                  draft,
                                                ),
                                                step: 1,
                                                valueLabel:
                                                    _lineHeightValueLabel(
                                                      draft,
                                                    ),
                                                onChanged: (value) {
                                                  setModalState(() {
                                                    draft = draft.copyWith(
                                                      lineHeight:
                                                          _lineHeightFromSliderValue(
                                                            sliderValue: value,
                                                            settings: draft,
                                                          ),
                                                    );
                                                  });
                                                },
                                              ),
                                              buildTypographySliderRow(
                                                label: '段距',
                                                min: 0,
                                                max: 20,
                                                divisions: 20,
                                                value: draft.paragraphSpacing,
                                                step: 1,
                                                valueLabel:
                                                    _paragraphSpacingValueLabel(
                                                      draft,
                                                    ),
                                                onChanged: (value) {
                                                  setModalState(() {
                                                    draft = draft.copyWith(
                                                      paragraphSpacing: value,
                                                    );
                                                  });
                                                },
                                              ),
                                              buildTypographySliderRow(
                                                label: '缩进',
                                                min: 0,
                                                max: 8,
                                                divisions: 8,
                                                value:
                                                    draft.paragraphIndent
                                                        .clamp(0, 8)
                                                        .toDouble(),
                                                step: 1,
                                                valueLabel:
                                                    _paragraphIndentValueLabel(
                                                      draft,
                                                    ),
                                                onChanged: (value) {
                                                  setModalState(() {
                                                    draft = draft.copyWith(
                                                      paragraphIndent:
                                                          value
                                                              .round()
                                                              .toDouble(),
                                                    );
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (!isMangaChapter)
                                        const Divider(height: 1),
                                      if (!isMangaChapter)
                                        _buildSettingLine(
                                          context: context,
                                          label: '触发',
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children: [
                                                FilterChip(
                                                  label: const Text('点按'),
                                                  selected:
                                                      _pageTurnIncludesTap(
                                                        draft.pageTurnMode,
                                                      ),
                                                  showCheckmark: false,
                                                  onSelected: (selected) {
                                                    setModalState(() {
                                                      draft = draft.copyWith(
                                                        pageTurnMode:
                                                            _applyPageTurnToggle(
                                                              draft
                                                                  .pageTurnMode,
                                                              tapEnabled:
                                                                  selected,
                                                            ),
                                                      );
                                                    });
                                                  },
                                                ),
                                                const SizedBox(width: 8),
                                                FilterChip(
                                                  label: const Text('滑动'),
                                                  selected:
                                                      _pageTurnIncludesSwipe(
                                                        draft.pageTurnMode,
                                                      ),
                                                  showCheckmark: false,
                                                  onSelected: (selected) {
                                                    setModalState(() {
                                                      draft = draft.copyWith(
                                                        pageTurnMode:
                                                            _applyPageTurnToggle(
                                                              draft
                                                                  .pageTurnMode,
                                                              swipeEnabled:
                                                                  selected,
                                                            ),
                                                      );
                                                    });
                                                  },
                                                ),
                                                const SizedBox(width: 8),
                                                FilterChip(
                                                  label: const Text('滚动'),
                                                  selected: _pageTurnUsesScroll(
                                                    draft.pageTurnMode,
                                                  ),
                                                  showCheckmark: false,
                                                  onSelected: (selected) {
                                                    setModalState(() {
                                                      draft = draft.copyWith(
                                                        pageTurnMode:
                                                            _applyPageTurnToggle(
                                                              draft
                                                                  .pageTurnMode,
                                                              scrollEnabled:
                                                                  selected,
                                                            ),
                                                      );
                                                    });
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      if (!isMangaChapter)
                                        const Divider(height: 1),
                                      _buildSettingLine(
                                        context: context,
                                        label: !isMangaChapter ? '动画' : '翻页',
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (pageAnimationInactiveReason !=
                                                null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 6,
                                                ),
                                                child: Text(
                                                  pageAnimationInactiveReason,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                      ),
                                                ),
                                              ),
                                            if (animationPolicy
                                                .supportsTextPageTurnAnimations)
                                              buildPageAnimationSelector()
                                            else
                                              Text(
                                                animationPolicy
                                                        .inactiveReason ??
                                                    '当前模式不使用正文翻页动画。',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall?.copyWith(
                                                  color:
                                                      Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                  height: 1.35,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 1),
                                      _buildSettingLine(
                                        context: context,
                                        label: '音量键翻页',
                                        labelWidth: 96,
                                        stackOnCompact: true,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    draft.volumeKeyPageEnabled
                                                        ? '音量上键上一页，音量下键下一页'
                                                        : '保留系统音量键行为',
                                                    style:
                                                        Theme.of(
                                                          context,
                                                        ).textTheme.bodyMedium,
                                                  ),
                                                ),
                                                Switch.adaptive(
                                                  value:
                                                      draft
                                                          .volumeKeyPageEnabled,
                                                  onChanged:
                                                      ReaderVolumeKeyPageBridge
                                                              .instance
                                                              .isSupported
                                                          ? (enabled) {
                                                            setModalState(() {
                                                              draft = draft
                                                                  .copyWith(
                                                                    volumeKeyPageEnabled:
                                                                        enabled,
                                                                  );
                                                            });
                                                          }
                                                          : null,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _volumeKeyPageSupportDescription,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelSmall?.copyWith(
                                                color:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 1),
                                      _buildSettingLine(
                                        context: context,
                                        label: isMangaChapter ? '其他' : '自动读',
                                        child:
                                            isMangaChapter
                                                ? Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children: ReaderMangaReadMode
                                                          .values
                                                          .map(
                                                            (
                                                              mode,
                                                            ) => ChoiceChip(
                                                              label: Text(
                                                                _mangaReadModeLabel(
                                                                  mode,
                                                                ),
                                                              ),
                                                              selected:
                                                                  draft
                                                                      .mangaReadMode ==
                                                                  mode,
                                                              onSelected: (_) {
                                                                setModalState(() {
                                                                  draft = draft
                                                                      .copyWith(
                                                                        mangaReadMode:
                                                                            mode,
                                                                      );
                                                                });
                                                              },
                                                            ),
                                                          )
                                                          .toList(
                                                            growable: false,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      '留白',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelMedium
                                                          ?.copyWith(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children: const [
                                                            0.0,
                                                            4.0,
                                                            8.0,
                                                            12.0,
                                                            16.0,
                                                          ]
                                                          .map(
                                                            (
                                                              value,
                                                            ) => ChoiceChip(
                                                              label: Text(
                                                                '${value.toInt()}',
                                                              ),
                                                              selected:
                                                                  (draft.mangaImagePadding -
                                                                          value)
                                                                      .abs() <
                                                                  0.2,
                                                              onSelected: (_) {
                                                                setModalState(() {
                                                                  draft = draft
                                                                      .copyWith(
                                                                        mangaImagePadding:
                                                                            value,
                                                                      );
                                                                });
                                                              },
                                                            ),
                                                          )
                                                          .toList(
                                                            growable: false,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      '图间距',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelMedium
                                                          ?.copyWith(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children: const [
                                                            0.0,
                                                            6.0,
                                                            10.0,
                                                            14.0,
                                                            18.0,
                                                          ]
                                                          .map(
                                                            (
                                                              value,
                                                            ) => ChoiceChip(
                                                              label: Text(
                                                                '${value.toInt()}',
                                                              ),
                                                              selected:
                                                                  (draft.mangaImageSpacing -
                                                                          value)
                                                                      .abs() <
                                                                  0.2,
                                                              onSelected: (_) {
                                                                setModalState(() {
                                                                  draft = draft
                                                                      .copyWith(
                                                                        mangaImageSpacing:
                                                                            value,
                                                                      );
                                                                });
                                                              },
                                                            ),
                                                          )
                                                          .toList(
                                                            growable: false,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      '背景颜色',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelMedium
                                                          ?.copyWith(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children: _readerBackgroundColorOptions()
                                                          .map(
                                                            (
                                                              option,
                                                            ) => _buildBackgroundColorChoiceChip(
                                                              draft: draft,
                                                              option: option,
                                                              onChanged: (
                                                                next,
                                                              ) {
                                                                setModalState(
                                                                  () {
                                                                    draft =
                                                                        next;
                                                                  },
                                                                );
                                                              },
                                                            ),
                                                          )
                                                          .toList(
                                                            growable: false,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      '加载策略',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelMedium
                                                          ?.copyWith(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children: ReaderMangaLoadStrategy
                                                          .values
                                                          .map(
                                                            (
                                                              strategy,
                                                            ) => ChoiceChip(
                                                              label: Text(
                                                                _mangaLoadStrategyLabel(
                                                                  strategy,
                                                                ),
                                                              ),
                                                              selected:
                                                                  draft
                                                                      .mangaLoadStrategy ==
                                                                  strategy,
                                                              onSelected: (_) {
                                                                setModalState(() {
                                                                  draft = draft
                                                                      .copyWith(
                                                                        mangaLoadStrategy:
                                                                            strategy,
                                                                      );
                                                                });
                                                              },
                                                            ),
                                                          )
                                                          .toList(
                                                            growable: false,
                                                          ),
                                                    ),
                                                  ],
                                                )
                                                : Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            startAutoReadAfterApply
                                                                ? '关闭弹窗后立即启动自动阅读'
                                                                : '本次不启动自动阅读',
                                                            style:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .bodyMedium,
                                                          ),
                                                        ),
                                                        Switch.adaptive(
                                                          value:
                                                              startAutoReadAfterApply,
                                                          onChanged: (enabled) {
                                                            setModalState(() {
                                                              startAutoReadAfterApply =
                                                                  enabled;
                                                            });
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '一次性操作，不会保存为默认状态',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '自动阅读速度：${_autoReadSpeedLevelLabel(draft.autoReadSpeed)} · ${draft.autoReadSpeed.round()} px/s',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelMedium
                                                          ?.copyWith(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                          ),
                                                    ),
                                                    Slider(
                                                      min:
                                                          ReaderSettings
                                                              .minAutoReadSpeed,
                                                      max:
                                                          ReaderSettings
                                                              .maxAutoReadSpeed,
                                                      divisions: 20,
                                                      label:
                                                          '${draft.autoReadSpeed.round()}',
                                                      value:
                                                          draft.autoReadSpeed
                                                              .clamp(
                                                                ReaderSettings
                                                                    .minAutoReadSpeed,
                                                                ReaderSettings
                                                                    .maxAutoReadSpeed,
                                                              )
                                                              .toDouble(),
                                                      onChanged: (value) {
                                                        setModalState(() {
                                                          draft = draft
                                                              .copyWith(
                                                                autoReadSpeed:
                                                                    value,
                                                              );
                                                        });
                                                      },
                                                    ),
                                                    Row(
                                                      children: [
                                                        Text(
                                                          '慢',
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .labelSmall,
                                                        ),
                                                        const Spacer(),
                                                        Text(
                                                          '快',
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .labelSmall,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                      ),
                                    ],
                                  ],
                                ),
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
        );
      },
    );

    persistDraftTimer?.cancel();
    await persistDraftNow(draft);

    if (!mounted) {
      return;
    }

    if (shouldRestoreOverlay) {
      _setOverlayControlsVisibility(true);
    }

    final shouldEnableAutoRead = !isMangaChapter && startAutoReadAfterApply;
    final selectedResult = draft;
    var appliedResult = selectedResult.copyWith(autoReadEnabled: false);
    var refreshedCustomFonts = _customFonts;

    try {
      appliedResult = await _fontRegistryService.normalizeCustomFontSettings(
        appliedResult,
      );
    } catch (_) {
      appliedResult = appliedResult.copyWith(
        fontSource: ReaderFontSource.system,
        clearFontFamilyKey: true,
        clearCustomFontPath: true,
      );
    }

    if (selectedResult.fontSource == ReaderFontSource.custom &&
        appliedResult.fontSource != ReaderFontSource.custom) {
      _showMessage('自定义字体不可用，已自动切回系统字体。');
    }

    try {
      refreshedCustomFonts = await _fontRegistryService.listRegisteredFonts();
    } catch (_) {
      refreshedCustomFonts = const <ReaderCustomFontEntry>[];
    }

    setState(() {
      _settings = appliedResult;
      _customFonts = refreshedCustomFonts;
    });
    _syncContinuousTextFlowAfterSettingsApplied();
    _clearSelectionState();
    await _preferencesService.saveSettings(appliedResult);

    if (shouldEnableAutoRead && mounted) {
      await _toggleAutoReadSession();
    }
  }

  Future<void> _ensureBackgroundPresetsReady() async {
    if (_backgroundPresets.isEmpty) {
      final discoveredPaths = await _loadBackgroundPresetAssetPaths();
      final presetPaths = <String>[];

      void addPresetPath(String path) {
        final normalized = path.trim();
        if (normalized.isEmpty) {
          return;
        }
        if (!presetPaths.contains(normalized)) {
          presetPaths.add(normalized);
        }
      }

      for (final fallbackPath in _kFallbackBackgroundPresetPaths) {
        addPresetPath(fallbackPath);
      }
      for (final discoveredPath in discoveredPaths) {
        addPresetPath(discoveredPath);
      }

      for (var index = 0; index < presetPaths.length; index += 1) {
        _backgroundPresets.add(
          _ReaderBackgroundPreset(
            label: '预设${index + 1}',
            assetPath: presetPaths[index],
          ),
        );
      }
    }

    for (final preset in _backgroundPresets) {
      final path = preset.assetPath;
      if (_backgroundPresetBytes.containsKey(path) &&
          _backgroundPresetBase64.containsKey(path)) {
        continue;
      }
      try {
        final data = await rootBundle.load(path);
        final bytes = data.buffer.asUint8List();
        if (bytes.isEmpty) {
          continue;
        }
        _backgroundPresetBytes[path] = bytes;
        _backgroundPresetBase64[path] = base64Encode(bytes);
      } catch (error) {
        debugPrint('Load reader preset background failed: $path, $error');
      }
    }
  }

  Future<List<String>> _loadBackgroundPresetAssetPaths() async {
    List<String> filterBackgroundPaths(Iterable<String> candidates) {
      final filtered = candidates
          .where((path) => path.startsWith('assets/reader/backgrounds/'))
          .where((path) {
            final lowerPath = path.toLowerCase();
            return lowerPath.endsWith('.jpg') ||
                lowerPath.endsWith('.jpeg') ||
                lowerPath.endsWith('.png') ||
                lowerPath.endsWith('.webp');
          })
          .toList(growable: false);
      filtered.sort();
      return filtered;
    }

    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final discovered = filterBackgroundPaths(manifest.listAssets());
      if (discovered.isNotEmpty) {
        return discovered;
      }
    } catch (_) {
      // Keep backward compatibility with runtimes that only expose JSON manifest.
    }

    try {
      final rawManifest = await rootBundle.loadString('AssetManifest.json');
      final decoded = jsonDecode(rawManifest);
      if (decoded is! Map<String, dynamic>) {
        return const <String>[];
      }
      return filterBackgroundPaths(decoded.keys);
    } catch (_) {
      return const <String>[];
    }
  }

  Widget _buildSettingLine({
    required BuildContext context,
    required String label,
    required Widget child,
    double labelWidth = 42,
    String? helpText,
    bool stackOnCompact = false,
  }) {
    final useStackLayout =
        stackOnCompact && AppLayout.isBelowPhoneLargeWidth(context);
    final labelWidget = _buildSettingLineLabel(
      context: context,
      label: label,
      helpText: helpText,
      maxLines: useStackLayout ? 2 : 1,
    );

    if (useStackLayout) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [labelWidget, const SizedBox(height: 8), child],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: labelWidget,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildSettingLineLabel({
    required BuildContext context,
    required String label,
    String? helpText,
    required int maxLines,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (helpText != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 1),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                showDialog<void>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: Text(label),
                        content: Text(helpText),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('知道了'),
                          ),
                        ],
                      ),
                );
              },
              child: Icon(
                Icons.help_outline_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  List<_ReaderBackgroundColorOption> _readerBackgroundColorOptions() {
    return <_ReaderBackgroundColorOption>[
      _createReaderBackgroundColorOption(
        label: '明亮',
        mode: ReaderThemeMode.light,
        backgroundStyle: ReaderBackgroundStyle.plain,
        backgroundTone: ReaderBackgroundTone.surface,
      ),
      _createReaderBackgroundColorOption(
        label: '护眼',
        mode: ReaderThemeMode.sepia,
        backgroundStyle: ReaderBackgroundStyle.warm,
        backgroundTone: ReaderBackgroundTone.container,
      ),
      _createReaderBackgroundColorOption(
        label: '浅灰',
        mode: ReaderThemeMode.light,
        backgroundStyle: ReaderBackgroundStyle.paper,
        backgroundTone: ReaderBackgroundTone.containerHigh,
      ),
      _createReaderThemePaletteBackgroundColorOption(
        themeOption: appThemeFlameOrangeOption,
        backgroundTone: ReaderBackgroundTone.flameOrangeTint,
      ),
      _createReaderThemePaletteBackgroundColorOption(
        themeOption: appThemePineGreenOption,
        backgroundTone: ReaderBackgroundTone.pineGreenTint,
      ),
      _createReaderThemePaletteBackgroundColorOption(
        themeOption: appThemeSeaBlueOption,
        backgroundTone: ReaderBackgroundTone.seaBlueTint,
      ),
      _createReaderThemePaletteBackgroundColorOption(
        themeOption: appThemeNightPurpleOption,
        backgroundTone: ReaderBackgroundTone.nightPurpleTint,
      ),
      _createReaderThemePaletteBackgroundColorOption(
        themeOption: appThemeMistTealOption,
        backgroundTone: ReaderBackgroundTone.mistTealTint,
      ),
      _createReaderThemePaletteBackgroundColorOption(
        themeOption: appThemeBerryRoseOption,
        backgroundTone: ReaderBackgroundTone.berryRoseTint,
      ),
      _createReaderThemePaletteBackgroundColorOption(
        themeOption: appThemeAmberGoldOption,
        backgroundTone: ReaderBackgroundTone.amberGoldTint,
      ),
      _createReaderBackgroundColorOption(
        label: '夜间',
        mode: ReaderThemeMode.dark,
        backgroundStyle: ReaderBackgroundStyle.plain,
        backgroundTone: ReaderBackgroundTone.pureBlack,
      ),
    ];
  }

  _ReaderBackgroundColorOption _createReaderBackgroundColorOption({
    required String label,
    required ReaderThemeMode mode,
    required ReaderBackgroundStyle backgroundStyle,
    required ReaderBackgroundTone backgroundTone,
  }) {
    final previewSettings = ReaderSettings(
      themeMode: mode,
      backgroundStyle: backgroundStyle,
      backgroundTone: backgroundTone,
    );
    final previewColors = _resolveThemeColors(mode, previewSettings);
    return _ReaderBackgroundColorOption(
      label: label,
      previewColor: previewColors.background,
      mode: mode,
      backgroundStyle: backgroundStyle,
      backgroundTone: backgroundTone,
    );
  }

  _ReaderBackgroundColorOption _createReaderThemePaletteBackgroundColorOption({
    required AppThemeSeedOption themeOption,
    required ReaderBackgroundTone backgroundTone,
  }) {
    return _createReaderBackgroundColorOption(
      label: themeOption.label,
      mode: ReaderThemeMode.light,
      backgroundStyle: ReaderBackgroundStyle.paper,
      backgroundTone: backgroundTone,
    );
  }

  ReaderSettings _applyReaderBackgroundColorOption(
    ReaderSettings settings,
    _ReaderBackgroundColorOption option,
  ) {
    return settings.copyWith(
      themeMode: option.mode,
      backgroundStyle: option.backgroundStyle,
      backgroundTone: option.backgroundTone,
      clearBackgroundImage: true,
    );
  }

  bool _isReaderBackgroundColorOptionSelected(
    ReaderSettings settings,
    _ReaderBackgroundColorOption option,
  ) {
    final normalizedTone = normalizeReaderBackgroundTone(
      mode: settings.themeMode,
      tone: settings.backgroundTone,
    );
    return settings.themeMode == option.mode &&
        settings.backgroundStyle == option.backgroundStyle &&
        normalizedTone == option.backgroundTone;
  }

  Widget _buildBackgroundColorChoiceChip({
    required ReaderSettings draft,
    required _ReaderBackgroundColorOption option,
    required ValueChanged<ReaderSettings> onChanged,
  }) {
    return ChoiceChip(
      label: Text(option.label),
      selected: _isReaderBackgroundColorOptionSelected(draft, option),
      onSelected: (_) {
        onChanged(_applyReaderBackgroundColorOption(draft, option));
      },
    );
  }

  Color? _readerPaletteSeedColorForTone(ReaderBackgroundTone tone) {
    return switch (tone) {
      ReaderBackgroundTone.flameOrangeTint => appThemeFlameOrangeOption.color,
      ReaderBackgroundTone.pineGreenTint => appThemePineGreenOption.color,
      ReaderBackgroundTone.seaBlueTint => appThemeSeaBlueOption.color,
      ReaderBackgroundTone.nightPurpleTint => appThemeNightPurpleOption.color,
      ReaderBackgroundTone.mistTealTint => appThemeMistTealOption.color,
      ReaderBackgroundTone.berryRoseTint => appThemeBerryRoseOption.color,
      ReaderBackgroundTone.amberGoldTint => appThemeAmberGoldOption.color,
      _ => null,
    };
  }

  Widget _buildThemeColorDot({
    required ReaderSettings draft,
    required Color color,
    required String label,
    required ReaderThemeMode mode,
    required ReaderBackgroundStyle backgroundStyle,
    required ReaderBackgroundTone backgroundTone,
    required ValueChanged<ReaderSettings> onChanged,
    double scale = 1.0,
  }) {
    final normalizedTone = normalizeReaderBackgroundTone(
      mode: draft.themeMode,
      tone: draft.backgroundTone,
    );
    final selected =
        draft.themeMode == mode &&
        draft.backgroundStyle == backgroundStyle &&
        normalizedTone == backgroundTone;
    final iconColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : null;

    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: () {
          onChanged(
            draft.copyWith(
              themeMode: mode,
              backgroundStyle: backgroundStyle,
              backgroundTone: backgroundTone,
              clearBackgroundImage: true,
            ),
          );
        },
        child: Container(
          width: 30 * scale,
          height: 30 * scale,
          margin: EdgeInsets.only(right: 8 * scale),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
              width: (selected ? 2 : 1) * scale.clamp(1.0, 1.4),
            ),
          ),
          child:
              selected
                  ? Icon(
                    Icons.check_rounded,
                    size: 14 * scale,
                    color: iconColor,
                  )
                  : null,
        ),
      ),
    );
  }

  Widget _buildBackgroundTile({
    required String label,
    required bool selected,
    Uint8List? previewBytes,
    VoidCallback? onTap,
    bool showLabel = true,
    IconData? icon,
    double scale = 1.0,
  }) {
    final image =
        previewBytes == null
            ? null
            : DecorationImage(
              image: MemoryImage(previewBytes),
              fit: BoxFit.cover,
            );

    final tile = Container(
      width: _kBackgroundTileWidth * scale,
      height: _kBackgroundTileHeight * scale,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(
          color:
              selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
          width: (selected ? 2 : 1) * scale.clamp(1.0, 1.4),
        ),
        image: image,
      ),
      child:
          previewBytes == null
              ? (icon != null
                  ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 18 * scale,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      if (showLabel) ...[
                        SizedBox(height: 2 * scale),
                        Text(
                          label,
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(
                            fontSize:
                                (Theme.of(
                                      context,
                                    ).textTheme.labelSmall?.fontSize ??
                                    11) *
                                scale,
                          ),
                        ),
                      ],
                    ],
                  )
                  : Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize:
                          (Theme.of(context).textTheme.labelSmall?.fontSize ??
                              11) *
                          scale,
                    ),
                  ))
              : (!showLabel
                  ? const SizedBox.expand()
                  : Container(
                    width: double.infinity,
                    height: double.infinity,
                    alignment: Alignment.bottomCenter,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6 * scale),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0x7A000000)],
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 2 * scale),
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontSize:
                              (Theme.of(
                                    context,
                                  ).textTheme.labelSmall?.fontSize ??
                                  11) *
                              scale,
                        ),
                      ),
                    ),
                  )),
    );

    if (onTap == null) {
      return tile;
    }
    return GestureDetector(onTap: onTap, child: tile);
  }

  Future<String?> _pickBackgroundImagePath() async {
    try {
      debugPrint('[reader-bg][pick] start');
      final picked = await _imageSelectionService.pickImage(
        confirmButtonText: '选择背景',
      );
      if (picked == null) {
        debugPrint('[reader-bg][pick] cancelled');
        return null;
      }

      final Uint8List bytes = picked.bytes;
      if (bytes.isEmpty) {
        debugPrint('[reader-bg][pick] empty-bytes');
        _showMessage('背景图片读取失败。');
        return null;
      }
      final storedPath = await _storeCustomBackgroundImage(bytes);
      debugPrint('[reader-bg][pick] stored=$storedPath');
      return storedPath;
    } on ImageSelectionException catch (error) {
      debugPrint('[reader-bg][pick] image-selection-error=${error.message}');
      _showMessage(error.message);
      return null;
    } on PlatformException catch (error) {
      debugPrint(
        '[reader-bg][pick] platform-error=${error.message ?? error.code}',
      );
      _showMessage('选择背景失败：${error.message ?? error.code}');
      return null;
    } catch (error) {
      debugPrint('[reader-bg][pick] error=$error');
      _showMessage('选择背景失败：$error');
      return null;
    }
  }

  String _autoReadSpeedLevelLabel(double speed) {
    if (speed < 42) {
      return '慢速';
    }
    if (speed < 78) {
      return '中速';
    }
    return '快速';
  }

  String _formatTypographyValue({
    required double value,
    required int fractionDigits,
    String unit = '',
  }) {
    final normalized = value == 0 ? 0.0 : value;
    return '${normalized.toStringAsFixed(fractionDigits)}$unit';
  }

  String _fontSizeValueLabel(ReaderSettings settings) {
    return _formatTypographyValue(
      value: settings.fontSize,
      fractionDigits: 0,
      unit: 'px',
    );
  }

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

  String _pageAnimationLabel(ReaderPageAnimationStyle style) {
    return switch (style) {
      ReaderPageAnimationStyle.curl => '仿真',
      ReaderPageAnimationStyle.fade => '淡入淡出',
      ReaderPageAnimationStyle.cover => '覆盖',
      ReaderPageAnimationStyle.translate => '平移',
      ReaderPageAnimationStyle.vertical => '上下',
      ReaderPageAnimationStyle.none => '无动画',
    };
  }

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
  });

  final bool isAnimating;
  final bool isPreview;
  final int direction;
  final int fromIndex;
  final int toIndex;
  final double previewProgress;
  final bool commitOnAnimationEnd;

  _CurlTransitionState copyWith({
    bool? isAnimating,
    bool? isPreview,
    int? direction,
    int? fromIndex,
    int? toIndex,
    double? previewProgress,
    bool? commitOnAnimationEnd,
  }) {
    return _CurlTransitionState(
      isAnimating: isAnimating ?? this.isAnimating,
      isPreview: isPreview ?? this.isPreview,
      direction: direction ?? this.direction,
      fromIndex: fromIndex ?? this.fromIndex,
      toIndex: toIndex ?? this.toIndex,
      previewProgress: previewProgress ?? this.previewProgress,
      commitOnAnimationEnd: commitOnAnimationEnd ?? this.commitOnAnimationEnd,
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
