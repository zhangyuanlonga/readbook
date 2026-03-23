import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/switch_source_candidate_sheet.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/media/image_selection_service.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/repositories/bookmark_repository_impl.dart';
import '../../../domain/entities/bookmark.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reader_replace_preference.dart';
import '../../../domain/entities/reader_replace_rule.dart';
import '../../../domain/entities/reader_settings.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/entities/reader_toc_snapshot.dart';
import '../../../domain/entities/source_definition.dart';
import '../../../domain/repositories/bookmark_repository.dart';
import '../../bookshelf/application/bookshelf_service.dart';
import '../../bookshelf/application/local_book_import_service.dart';
import '../../book/application/book_detail_service.dart';
import '../../book/presentation/book_detail_route.dart';
import '../../search/application/search_hit_cache_service.dart';
import '../../search/application/search_service.dart';
import '../application/content_provider.dart';
import '../application/chapter_content_service.dart';
import '../application/local_content_provider.dart';
import '../application/reader_font_registry_service.dart';
import '../application/reader_preferences_service.dart';
import '../application/reader_replace_rule_service.dart';
import '../application/reading_record_metrics.dart';
import '../application/reading_record_service.dart';
import '../application/reader_error_center_service.dart';
import '../application/reader_system_settings_service.dart';
import '../application/reader_typography_resolver.dart';
import '../application/reader_volume_key_page_bridge.dart';
import '../application/source_content_provider.dart';
import '../application/source_switch_score_service.dart';
import '../application/switch_source_shared.dart';
import '../application/switch_source_position_resolver.dart';
import 'chapter_cache_sheets.dart';

enum _ReaderSettingsTab { interface, reading }

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
  final ContentProviderRegistry _contentProviderRegistry =
      ContentProviderRegistry(
        providers: [LocalContentProvider(), SourceContentProvider()],
      );
  final ReaderPreferencesService _preferencesService =
      ReaderPreferencesService();
  final ReaderFontRegistryService _fontRegistryService =
      ReaderFontRegistryService();
  final ReaderTypographyResolver _typographyResolver =
      const ReaderTypographyResolver();
  final ReaderReplaceRuleService _readerReplaceRuleService =
      ReaderReplaceRuleService();
  final ReaderSystemSettingsService _systemSettingsService =
      ReaderSystemSettingsService();
  final ReaderErrorCenterService _readerErrorCenterService =
      ReaderErrorCenterService.instance;
  final ReadingRecordService _readingRecordService = ReadingRecordService();
  final ImageSelectionService _imageSelectionService = ImageSelectionService();
  final BookshelfService _bookshelfService = BookshelfService();
  final SearchService _switchSourceSearchService = SearchService();
  final SearchHitCacheService _searchHitCacheService = SearchHitCacheService();
  final SourceSwitchScoreService _switchSourceScoreService =
      SourceSwitchScoreService();
  final SwitchSourcePositionResolver _switchSourcePositionResolver =
      const SwitchSourcePositionResolver();
  final ScrollController _scrollController = ScrollController();
  final PageController _mangaPageController = PageController();
  final GlobalKey _readerBodyKey = GlobalKey();
  final GlobalKey<SelectionAreaState> _selectionAreaKey =
      GlobalKey<SelectionAreaState>();
  final SelectionListenerNotifier _selectionNotifier =
      SelectionListenerNotifier();
  final BookmarkRepository _bookmarkRepository = BookmarkRepositoryImpl(
    AppDatabase.instance,
  );
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
  String _content = '';
  List<String> _paragraphs = const [];
  List<String> _chapterImageUrls = const [];
  Map<String, String> _chapterImageHeaders = const {};
  bool _isTextSelectionActive = false;
  SelectedContentRange? _selectionRange;
  SelectionStatus _selectionStatus = SelectionStatus.none;
  int _selectionStartOffset = 0;
  int _selectionEndOffset = 0;
  String _selectedSnippet = '';
  List<Bookmark> _chapterBookmarks = const [];
  List<ReaderReplaceRule> _effectiveReaderReplaceRules =
      const <ReaderReplaceRule>[];
  Map<int, List<_BookmarkRange>> _bookmarkRangesByParagraph =
      const <int, List<_BookmarkRange>>{};
  bool _selectionBold = false;
  bool _selectionUnderline = true;
  bool _selectionWavy = false;
  List<ReaderCustomFontEntry> _customFonts = const [];
  final Map<String, int> _mangaImageRetryNonce = <String, int>{};
  final Map<int, TransformationController> _mangaTransformControllers =
      <int, TransformationController>{};
  final Map<int, TapDownDetails> _mangaDoubleTapDetails =
      <int, TapDownDetails>{};
  final Set<int> _mangaZoomedPageIndexes = <int>{};
  static const String _inlineImageMarkerPrefix = '[[appread-image:';
  static const String _inlineImageMarkerSuffix = ']]';
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
  DateTime _readerInfoNow = DateTime.now();
  int? _readerBatteryLevel;
  bool _readerBatteryReadFailed = false;
  int _autoReadTaskToken = 0;
  int _preloadTaskToken = 0;
  bool _isAutoReadRunning = false;
  bool _isAutoReadSessionEnabled = false;
  bool _isAutoReadAdvancingChapter = false;
  double _scrollEdgeOverscrollDistance = 0;
  bool _scrollEdgeAdvanceArmed = false;
  int _scrollEdgeActionDirection = 0;
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
  String? _lightModeBackgroundImageBackup;
  String? _cachedBackgroundImageKey;
  MemoryImage? _cachedBackgroundImage;
  List<List<_PagedSlice>> _pagedPages = const [];
  int _currentPageIndex = 0;
  bool _isPaginatingPages = false;
  String? _paginationSignature;
  int _paginationTaskId = 0;
  double? _pendingPageRestoreRatio;
  double? _lastPaginationMaxWidth;
  double? _lastPaginationMaxHeight;
  bool _showChapterLoadingIndicator = false;
  bool _showBlockingLoadingCard = false;
  _PagedPageTransitionState _pagedTransition =
      const _PagedPageTransitionState();
  _CurlTransitionState _curlTransition = const _CurlTransitionState();
  bool _isSystemUiVisible = true;
  bool _isVolumeKeyPageInterceptionEnabled = false;
  late final AnimationController _overlayControlsController;
  late final AnimationController _pagedTransitionController;
  late final AnimationController _curlAutoTurnController;
  _ActiveReadingRecordSession? _activeReadingRecordSession;
  final Map<String, Uint8List> _backgroundPresetBytes = <String, Uint8List>{};
  final Map<String, String> _backgroundPresetBase64 = <String, String>{};
  final List<_ReaderBackgroundPreset> _backgroundPresets =
      <_ReaderBackgroundPreset>[];
  String? _catalogSearchCacheFingerprint;
  Map<String, List<_CatalogSearchEntry>> _catalogSearchEntriesCache =
      const <String, List<_CatalogSearchEntry>>{};
  final Map<String, _PrecomputedChapterLayout> _precomputedChapterLayouts =
      <String, _PrecomputedChapterLayout>{};
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
  static const double _kPinnedHeaderHeight = 40;
  static const double _kBottomProgressReserve = 24;
  static const double _kBackgroundTileWidth = 84;
  static const double _kBackgroundTileHeight = 52;
  static const int _kMaxCustomBackgrounds = 5;
  static const double _kSwipeTurnDistanceThreshold = 42;
  static const double _kSwipeTurnVelocityThreshold = 120;
  static const double _kSystemBackGestureGuardMin = 44;
  static const double _kSystemBackGestureGuardRatio = 0.06;
  static const Duration _kBackNavigationInteractionCooldown = Duration(
    milliseconds: 520,
  );
  static const double _kCurlPreviewStartThreshold = 8;
  static const double _kCoverEdgeShadowWidth = 20;
  static const double _kCoverEdgeShadowMaxAlpha = 0.22;
  static const double _kDarkBackgroundOverlayAlpha = 0.45;
  static const double _kOverlayScrimMaxAlpha = 0.14;
  static const Duration _kOverlayControlsShowDuration = Duration(
    milliseconds: 280,
  );
  static const Duration _kOverlayControlsHideDuration = Duration(
    milliseconds: 220,
  );
  static const Duration _kCurlAutoTurnDuration = Duration(milliseconds: 560);
  static const Duration _kPagedScrollTurnDuration = Duration(milliseconds: 300);
  static const Duration _kMangaPagedTurnDuration = Duration(milliseconds: 320);
  static const Duration _kAutoReadStepDuration = Duration(milliseconds: 520);
  static const Duration _kAutoReadResumeDelay = Duration(milliseconds: 420);
  static const Duration _kChapterLoadingIndicatorDelay = Duration(
    milliseconds: 150,
  );
  static const Duration _kBlockingLoadingCardDelay = Duration(
    milliseconds: 180,
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
  static const double _kScrollAdvanceOverscrollTrigger = 56;
  static const double _kScrollAdvanceEdgeTolerance = 2;
  static const double _kScrollAdvanceNearEdgeThreshold = 24;
  static const String _kCachedImagePayloadPrefix = '__appread_image_payload__:';
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
  static final RegExp _kSwitchSourceChapterPattern = RegExp(
    r'第?\s*(\d{1,5})\s*章',
  );
  static final RegExp _kSwitchSourceChapterEnglishPattern = RegExp(
    r'^(chapter|chap)\s*\d{1,5}\b',
  );

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

  bool get _shouldUseContinuousTextFlow =>
      _pageTurnUsesScroll(_settings.pageTurnMode) &&
      !_isMangaChapter &&
      !_isPagedTextReaderEnabled();

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

  bool get _shouldEnableVolumeKeyPageInterception {
    if (!ReaderVolumeKeyPageBridge.instance.isSupported) {
      return false;
    }
    if (!_settings.volumeKeyPageEnabled) {
      return false;
    }
    if (_showOverlayControls || _isTextSelectionActive) {
      return false;
    }
    if (_isBootstrapping || _isLoadingContent || _errorText != null) {
      return false;
    }
    return true;
  }

  String get _volumeKeyPageSupportDescription {
    if (!ReaderVolumeKeyPageBridge.instance.isSupported) {
      return '当前平台暂不支持音量键翻页。';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'iOS 真机支持音量键翻页；启用后会拦截按键并维持系统音量。';
    }
    return '仅在阅读态生效，打开菜单或弹层时不会拦截系统音量。';
  }

  Future<void> _syncVolumeKeyPageInterception() async {
    await _setVolumeKeyPageInterceptionEnabled(
      _shouldEnableVolumeKeyPageInterception,
    );
  }

  Future<void> _setVolumeKeyPageInterceptionEnabled(bool enabled) async {
    if (_isVolumeKeyPageInterceptionEnabled == enabled) {
      return;
    }
    _isVolumeKeyPageInterceptionEnabled = enabled;
    await ReaderVolumeKeyPageBridge.instance.setEnabled(enabled);
  }

  Future<void> _handleVolumeKeyEvent(ReaderVolumeKeyEvent event) async {
    if (!mounted || !_settings.volumeKeyPageEnabled) {
      return;
    }
    if (_showOverlayControls || _isTextSelectionActive) {
      return;
    }
    if (_isBootstrapping || _isLoadingContent || _errorText != null) {
      return;
    }
    if (event.repeatCount > 0) {
      return;
    }
    if (_isAutoReadSessionEnabled) {
      _stopAutoReadSession(showMessage: true);
      return;
    }

    if (event.direction == ReaderVolumeKeyDirection.up) {
      await _turnReaderBackwardByHardwareKey();
      return;
    }
    await _turnReaderForwardByHardwareKey();
  }

  Future<void> _turnReaderBackwardByHardwareKey() async {
    if (_isMangaPagedMode) {
      await _goToPreviousMangaPage();
      return;
    }
    if (_isPagedTextReaderEnabled()) {
      await _goToPreviousPage(MediaQuery.sizeOf(context).height);
      return;
    }
    await _advanceScrollReaderByStep(forward: false);
  }

  Future<void> _turnReaderForwardByHardwareKey() async {
    if (_isMangaPagedMode) {
      await _goToNextMangaPage();
      return;
    }
    if (_isPagedTextReaderEnabled()) {
      await _goToNextPage(MediaQuery.sizeOf(context).height);
      return;
    }
    await _advanceScrollReaderByStep(forward: true);
  }

  Future<void> _advanceScrollReaderByStep({required bool forward}) async {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    final distance =
        (position.viewportDimension * _settings.pageTurnStepRatio)
            .clamp(120.0, max(position.viewportDimension, 120.0))
            .toDouble();
    final current = position.pixels;
    final target =
        forward
            ? min(current + distance, position.maxScrollExtent)
            : max(current - distance, 0.0);

    if ((target - current).abs() >= 1.0) {
      try {
        await _scrollController.animateTo(
          target,
          duration: _kPagedScrollTurnDuration,
          curve: Curves.easeInOutCubic,
        );
      } catch (_) {
        // Ignore interrupted animations.
      }
      _scheduleProgressSave();
      return;
    }

    final index = _currentIndex;
    if (index == null) {
      return;
    }

    if (forward) {
      if (index >= _chapters.length - 1) {
        _showChapterBoundaryHint(isFirst: false);
        return;
      }
      await _jumpTo(index + 1, initialScrollRatio: 0);
      return;
    }

    if (index <= 0) {
      _showChapterBoundaryHint(isFirst: true);
      return;
    }
    await _jumpTo(index - 1, initialScrollRatio: 1);
  }

  Future<void> _goToPreviousMangaPage() async {
    if (!_isMangaPagedMode) {
      return;
    }
    if (_mangaPageIndex <= 0) {
      final index = _currentIndex;
      if (index == null || index <= 0) {
        _showChapterBoundaryHint(isFirst: true);
        return;
      }
      await _jumpTo(index - 1, initialScrollRatio: 1);
      return;
    }
    final target = _mangaPageIndex - 1;
    if (_mangaPageController.hasClients) {
      await _mangaPageController.animateToPage(
        target,
        duration: _kMangaPagedTurnDuration,
        curve: Curves.easeInOutCubic,
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _mangaPageIndex = target;
    });
    _syncActiveReadingRecordSessionProgress();
    _scheduleProgressSave();
  }

  Future<void> _goToNextMangaPage() async {
    if (!_isMangaPagedMode) {
      return;
    }
    final total = _chapterImageUrls.length;
    if (_mangaPageIndex >= total - 1) {
      final index = _currentIndex;
      if (index == null || index >= _chapters.length - 1) {
        _showChapterBoundaryHint(isFirst: false);
        return;
      }
      await _jumpTo(index + 1, initialScrollRatio: 0);
      return;
    }
    final target = _mangaPageIndex + 1;
    if (_mangaPageController.hasClients) {
      await _mangaPageController.animateToPage(
        target,
        duration: _kMangaPagedTurnDuration,
        curve: Curves.easeInOutCubic,
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _mangaPageIndex = target;
    });
    _syncActiveReadingRecordSessionProgress();
    _scheduleProgressSave();
  }

  bool _isPagedTextReaderEnabled() {
    if (_chapterImageUrls.isNotEmpty) {
      return false;
    }
    if (_paragraphs.any(_isInlineImageParagraph)) {
      return false;
    }
    return !_pageTurnUsesScroll(_settings.pageTurnMode);
  }

  bool _isSwipePaginationEnabled() {
    return _isPagedTextReaderEnabled() &&
        _pageTurnIncludesSwipe(_settings.pageTurnMode);
  }

  bool get _isMangaChapter => _chapterImageUrls.isNotEmpty;

  bool get _isMangaPagedMode {
    if (!_isMangaChapter) {
      return false;
    }
    return _settings.mangaReadMode != ReaderMangaReadMode.continuous;
  }

  bool get _hasVisibleReaderContent =>
      _content.trim().isNotEmpty || _chapterImageUrls.isNotEmpty;

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

  int _safePageUpperBound(int pageCount) {
    return max(0, pageCount - 1);
  }

  double _pinnedHeaderTotalHeight(BuildContext context) {
    return _topSafeInset(context) +
        _kPinnedHeaderTopPadding +
        _kPinnedHeaderHeight;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chapterId = widget.chapterId;
    _chapterUrl = widget.chapterUrl?.trim();
    _chapterTitle = widget.chapterTitle?.trim();
    _sourceId = widget.sourceId?.trim();
    _detailUrl = widget.detailUrl?.trim();
    _activeBookId = widget.bookId.trim();
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelActiveSwitchSourceSearch();
    _commitReadingRecordSession();
    _syncSystemUiVisibility(force: true, visible: true);
    _overlayControlsController.stop();
    _pagedTransitionController.stop();
    _curlAutoTurnController.stop();
    _pagedTransition = const _PagedPageTransitionState();
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
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          top: false,
          bottom: false,
          child: ClipRect(
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(child: _buildBackgroundLayer(colors)),
                Positioned.fill(child: _buildReaderContent(colors)),
                if (_settings.brightness < 0.99)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Colors.black.withValues(
                          alpha: (1 - _settings.brightness) * 0.6,
                        ),
                      ),
                    ),
                  ),
                _buildChapterLoadingIndicator(colors),
                _buildOverlayScrim(),
                _buildTopOverlay(colors),
                _buildBottomOverlay(colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_setVolumeKeyPageInterceptionEnabled(false));
      _commitReadingRecordSession();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(_syncVolumeKeyPageInterception());
      _maybeStartReadingRecordSession(initialRatio: _currentScrollRatio());
    }
  }

  void _handleBackNavigation() {
    _markBackNavigationTriggered();
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/bookshelf');
  }

  void _markBackNavigationTriggered() {
    _lastBackNavigationAt = DateTime.now();
    // Prevent this tap sequence from leaking into reader page-turn gestures.
    _suppressNextReaderTap = true;
  }

  bool get _isBackNavigationInteractionCoolingDown {
    final lastAt = _lastBackNavigationAt;
    if (lastAt == null) {
      return false;
    }
    return DateTime.now().difference(lastAt) <
        _kBackNavigationInteractionCooldown;
  }

  Widget _buildOverlayScrim() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _overlayControlsController,
        builder: (context, _) {
          final opacity = _overlayControlsFadeProgress * _kOverlayScrimMaxAlpha;
          return IgnorePointer(
            ignoring: opacity <= 0.001,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _hideOverlayControls,
              child: ColoredBox(color: Colors.black.withValues(alpha: opacity)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBackgroundLayer(_ReaderThemeColors colors) {
    final hasBackgroundImage =
        _settings.backgroundImageBase64?.trim().isNotEmpty ?? false;
    final decoration = _buildReaderBackgroundDecoration(colors);
    if (_settings.themeMode != ReaderThemeMode.dark || !hasBackgroundImage) {
      return DecoratedBox(decoration: decoration);
    }

    return Stack(
      children: [
        Positioned.fill(child: DecoratedBox(decoration: decoration)),
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: Colors.black.withValues(
                alpha: _kDarkBackgroundOverlayAlpha,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChapterLoadingIndicator(_ReaderThemeColors colors) {
    final showIndicator =
        _showChapterLoadingIndicator && !_shouldShowBlockingReaderLoading;
    final topInset = _topSafeInset(context);

    return AnimatedBuilder(
      animation: _overlayControlsController,
      builder: (context, _) {
        final overlayProgress = _overlayControlsShiftProgress;
        final topOffset =
            lerpDouble(topInset + 8, topInset + 60, overlayProgress)!;
        return Positioned(
          top: topOffset,
          left: 20,
          right: 20,
          child: IgnorePointer(
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              offset: showIndicator ? Offset.zero : const Offset(0, -0.35),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: showIndicator ? 1 : 0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor: colors.divider.withValues(alpha: 0.22),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colors.text.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  BoxDecoration _buildReaderBackgroundDecoration(_ReaderThemeColors colors) {
    final backgroundImage = _resolveBackgroundDecorationImage();
    return switch (_settings.backgroundStyle) {
      ReaderBackgroundStyle.plain => BoxDecoration(
        color: colors.background,
        image: backgroundImage,
      ),
      ReaderBackgroundStyle.paper => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _shiftLightness(colors.background, 0.03),
            _shiftLightness(colors.background, -0.02),
          ],
        ),
        image: backgroundImage,
      ),
      ReaderBackgroundStyle.warm => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _shiftLightness(colors.background, 0.03),
            _shiftLightness(colors.background, -0.02),
          ],
        ),
        image: backgroundImage,
      ),
    };
  }

  DecorationImage? _resolveBackgroundDecorationImage() {
    final raw = _settings.backgroundImageBase64?.trim();
    if (raw == null || raw.isEmpty) {
      _cachedBackgroundImageKey = null;
      _cachedBackgroundImage = null;
      return null;
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

    return DecorationImage(
      image: _cachedBackgroundImage!,
      fit: BoxFit.cover,
      colorFilter: ColorFilter.mode(
        Colors.black.withValues(
          alpha: _settings.themeMode == ReaderThemeMode.dark ? 0.12 : 0.08,
        ),
        BlendMode.darken,
      ),
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

  Widget _buildReaderContent(_ReaderThemeColors colors) {
    final isPaged = _isPagedTextReaderEnabled();
    // Paged mode already renders progress/time overlays and a pinned header.
    // Keep info bars for scroll text mode to avoid paged layout conflicts.
    final showInfoBar = !_isMangaChapter && !isPaged;

    return Column(
      children: [
        if (!isPaged) _buildPinnedChapterHeader(colors),
        if (showInfoBar && _settings.infoHeaderEnabled)
          _buildReaderInfoBar(colors, isHeader: true),
        Expanded(child: _buildBody(colors)),
        if (showInfoBar && _settings.infoFooterEnabled)
          _buildReaderInfoBar(colors, isHeader: false),
      ],
    );
  }

  Widget _buildPinnedChapterHeader(_ReaderThemeColors colors) {
    final chapterTitle =
        _chapterTitle?.isNotEmpty == true ? _chapterTitle! : '未命名章节';

    return Padding(
      padding: EdgeInsets.only(
        top: _topSafeInset(context) + _kPinnedHeaderTopPadding,
      ),
      child: SizedBox(
        height: _kPinnedHeaderHeight,
        child: Padding(
          padding: const EdgeInsets.only(left: 6, right: 12),
          child: Row(
            children: [
              IconButton(
                onPressed: _handleBackNavigation,
                tooltip: '返回',
                visualDensity: VisualDensity.standard,
                style: IconButton.styleFrom(
                  foregroundColor: colors.text,
                  backgroundColor: Colors.transparent,
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.all(8),
                  splashFactory: InkRipple.splashFactory,
                ),
                icon: const Icon(Icons.chevron_left_rounded, size: 22),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  chapterTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReaderInfoBar(
    _ReaderThemeColors colors, {
    required bool isHeader,
  }) {
    final infoItems = _buildReaderInfoItems();
    if (infoItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final innerPadding =
        (isHeader ? _settings.infoHeaderPadding : _settings.infoFooterPadding)
            .clamp(
              ReaderSettings.minInfoBarPadding,
              ReaderSettings.maxInfoBarPadding,
            )
            .toDouble();
    final marginTop =
        (isHeader
                ? _settings.infoHeaderMarginTop
                : _settings.infoFooterMarginTop)
            .clamp(
              ReaderSettings.minLayoutMargin,
              ReaderSettings.maxLayoutMargin,
            )
            .toDouble();
    final marginBottom =
        (isHeader
                ? _settings.infoHeaderMarginBottom
                : _settings.infoFooterMarginBottom)
            .clamp(
              ReaderSettings.minLayoutMargin,
              ReaderSettings.maxLayoutMargin,
            )
            .toDouble();
    final marginLeft =
        (isHeader
                ? _settings.infoHeaderMarginLeft
                : _settings.infoFooterMarginLeft)
            .clamp(
              ReaderSettings.minLayoutMargin,
              ReaderSettings.maxLayoutMargin,
            )
            .toDouble();
    final marginRight =
        (isHeader
                ? _settings.infoHeaderMarginRight
                : _settings.infoFooterMarginRight)
            .clamp(
              ReaderSettings.minLayoutMargin,
              ReaderSettings.maxLayoutMargin,
            )
            .toDouble();
    final showDivider =
        isHeader
            ? _settings.infoHeaderDividerEnabled
            : _settings.infoFooterDividerEnabled;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        marginLeft,
        marginTop,
        marginRight,
        marginBottom,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom:
                showDivider && isHeader
                    ? BorderSide(color: colors.divider.withValues(alpha: 0.4))
                    : BorderSide.none,
            top:
                showDivider && !isHeader
                    ? BorderSide(color: colors.divider.withValues(alpha: 0.4))
                    : BorderSide.none,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: innerPadding, vertical: 3),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < infoItems.length; index++) ...[
                  if (index > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '·',
                        style: TextStyle(
                          color: colors.meta.withValues(alpha: 0.8),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  Text(
                    infoItems[index],
                    style: TextStyle(
                      color: colors.meta,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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
    if (_settings.infoShowChapter) {
      items.add(_chapterInfoLabel());
    }
    if (_settings.infoShowProgress) {
      items.add('进度 ${(_currentScrollRatio() * 100).round()}%');
    }
    return items;
  }

  String _chapterInfoLabel() {
    if (_currentIndex == null || _chapters.isEmpty) {
      return '章节 --';
    }
    return '第 ${_currentIndex! + 1}/${_chapters.length} 章';
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

  Future<void> _refreshReaderInfoSnapshot({bool force = false}) async {
    final now = DateTime.now();

    int? batteryLevel;
    var batteryReadFailed = false;
    try {
      batteryLevel = await _battery.batteryLevel;
    } catch (_) {
      batteryReadFailed = true;
      batteryLevel = null;
    }

    if (!mounted) {
      return;
    }

    final shouldUpdateTime =
        force ||
        now.year != _readerInfoNow.year ||
        now.month != _readerInfoNow.month ||
        now.day != _readerInfoNow.day ||
        now.hour != _readerInfoNow.hour ||
        now.minute != _readerInfoNow.minute;

    final shouldUpdateBattery =
        force ||
        batteryLevel != _readerBatteryLevel ||
        batteryReadFailed != _readerBatteryReadFailed;

    if (!shouldUpdateTime && !shouldUpdateBattery) {
      return;
    }

    setState(() {
      _readerInfoNow = now;
      _readerBatteryLevel = batteryLevel;
      _readerBatteryReadFailed = batteryReadFailed;
    });
  }

  Widget _buildBody(_ReaderThemeColors colors) {
    if (_shouldShowBlockingReaderLoading) {
      return _buildTapAwareBody(
        child: _buildReaderStateCard(
          colors: colors,
          title: '正在加载正文',
          message: '请稍候，马上为你展开章节内容。',
          icon: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if ((_isBootstrapping || _isLoadingContent) && !_hasVisibleReaderContent) {
      return const SizedBox.expand();
    }

    if (_errorText != null) {
      final canSwitchSource = _canSwitchSource;
      return _buildTapAwareBody(
        child: _buildReaderStateCard(
          colors: colors,
          title: '加载失败',
          message: _errorText!,
          icon: Icon(Icons.warning_amber_rounded, color: colors.meta, size: 20),
          action: Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.tonal(
                onPressed:
                    _isSwitchSourceLoading
                        ? null
                        : () => _loadCurrentChapter(initialScrollRatio: null),
                child: const Text('重试'),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.swap_horiz_rounded),
                  label: Text(_isSwitchSourceLoading ? '换源中...' : '切换书源'),
                ),
            ],
          ),
        ),
      );
    }

    if (_content.trim().isEmpty && _chapterImageUrls.isEmpty) {
      return _buildTapAwareBody(
        child: _buildReaderStateCard(
          colors: colors,
          title: '暂无正文',
          message: '当前章节没有可展示的内容。',
          icon: Icon(Icons.article_outlined, color: colors.meta, size: 20),
        ),
      );
    }

    return _buildTapAwareBody(
      child:
          _chapterImageUrls.isNotEmpty
              ? _buildMangaReader(colors)
              : _isPagedTextReaderEnabled()
              ? _buildPagedReader(colors)
              : _buildReaderList(colors),
    );
  }

  Widget _buildReaderList(_ReaderThemeColors colors) {
    if (_shouldUseContinuousTextFlow && _continuousTextChapters.isNotEmpty) {
      return _buildContinuousTextReader(colors);
    }
    return _buildStandardReaderList(colors);
  }

  Widget _buildStandardReaderList(_ReaderThemeColors colors) {
    final paragraphs = _paragraphs;

    final bottomInset = _effectiveBottomSafeInset(context);
    final bodyLeft =
        _settings.bodyMarginLeft
            .clamp(
              ReaderSettings.minLayoutMargin,
              ReaderSettings.maxLayoutMargin,
            )
            .toDouble();
    final bodyTop =
        _settings.bodyMarginTop
            .clamp(
              ReaderSettings.minLayoutMargin,
              ReaderSettings.maxLayoutMargin,
            )
            .toDouble();
    final bodyRight =
        _settings.bodyMarginRight
            .clamp(
              ReaderSettings.minLayoutMargin,
              ReaderSettings.maxLayoutMargin,
            )
            .toDouble();
    final bodyBottom =
        _settings.bodyMarginBottom
            .clamp(
              ReaderSettings.minLayoutMargin,
              ReaderSettings.maxLayoutMargin,
            )
            .toDouble();

    final listView = NotificationListener<ScrollNotification>(
      onNotification: _onReaderScrollNotification,
      child: ListView.builder(
        key: ValueKey(_chapterId),
        controller: _scrollController,
        cacheExtent: 1200,
        padding: EdgeInsets.fromLTRB(
          bodyLeft,
          bodyTop,
          bodyRight,
          bodyBottom + 96 + bottomInset,
        ),
        itemCount: paragraphs.isEmpty ? 1 : paragraphs.length,
        itemBuilder: (context, index) {
          if (paragraphs.isEmpty) {
            return _buildSelectableParagraphItem(
              paragraph: _content,
              paragraphIndex: 0,
              isLast: true,
              colors: colors,
            );
          }

          final paragraph = paragraphs[index];
          final isLast = index == paragraphs.length - 1;

          return _buildSelectableParagraphItem(
            paragraph: paragraph,
            paragraphIndex: index,
            isLast: isLast,
            colors: colors,
          );
        },
      ),
    );

    return Stack(
      key: _readerBodyKey,
      children: [
        _wrapSelectionArea(child: listView),
        if (_isAutoReadSessionEnabled) _buildAutoReadIndicator(colors),
      ],
    );
  }

  Widget _buildContinuousTextReader(_ReaderThemeColors colors) {
    final bottomInset = _effectiveBottomSafeInset(context);
    final bodyLeft =
        _settings.bodyMarginLeft
            .clamp(
              ReaderSettings.minLayoutMargin,
              ReaderSettings.maxLayoutMargin,
            )
            .toDouble();
    final bodyTop =
        _settings.bodyMarginTop
            .clamp(
              ReaderSettings.minLayoutMargin,
              ReaderSettings.maxLayoutMargin,
            )
            .toDouble();
    final bodyRight =
        _settings.bodyMarginRight
            .clamp(
              ReaderSettings.minLayoutMargin,
              ReaderSettings.maxLayoutMargin,
            )
            .toDouble();
    final bodyBottom =
        _settings.bodyMarginBottom
            .clamp(
              ReaderSettings.minLayoutMargin,
              ReaderSettings.maxLayoutMargin,
            )
            .toDouble();

    final listView = NotificationListener<ScrollNotification>(
      onNotification: _onReaderScrollNotification,
      child: ListView.separated(
        controller: _scrollController,
        cacheExtent: 1800,
        padding: EdgeInsets.fromLTRB(
          bodyLeft,
          bodyTop,
          bodyRight,
          bodyBottom + 96 + bottomInset,
        ),
        itemCount: _continuousTextChapters.length,
        separatorBuilder:
            (_, __) =>
                SizedBox(height: max(18.0, _settings.paragraphSpacing * 1.2)),
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

    return Stack(
      key: _readerBodyKey,
      children: [
        listView,
        if (_isAutoReadSessionEnabled) _buildAutoReadIndicator(colors),
      ],
    );
  }

  Widget _buildContinuousTextChapterSection({
    required _ContinuousTextChapter chapter,
    required bool isActive,
    required _ReaderThemeColors colors,
  }) {
    final paragraphs =
        chapter.paragraphs.isEmpty
            ? <String>[chapter.content]
            : chapter.paragraphs;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < paragraphs.length; index += 1)
          isActive
              ? _buildSelectableParagraphItem(
                paragraph: paragraphs[index],
                paragraphIndex: index,
                isLast: index == paragraphs.length - 1,
                colors: colors,
              )
              : _buildStaticParagraphItem(
                paragraph: paragraphs[index],
                isLast: index == paragraphs.length - 1,
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
    final paddingBottom = isLast ? 0.0 : _settings.paragraphSpacing;

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(bottom: paddingBottom),
        child: Text(
          _applyParagraphIndent(paragraph),
          style: textStyle,
          textAlign: _paragraphTextAlign(_settings),
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
    final paddingBottom = isLast ? 0.0 : _settings.paragraphSpacing;

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(bottom: paddingBottom),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final displayText = _applyParagraphIndent(paragraph);
            final indentLength = displayText.length - paragraph.length;
            final bookmarkRanges =
                _bookmarkRangesByParagraph[paragraphIndex] ??
                const <_BookmarkRange>[];
            final wavyRanges = <_WavyRange>[];
            if (bookmarkRanges.isNotEmpty) {
              for (final range in bookmarkRanges) {
                if (!range.isWavy) {
                  continue;
                }
                final startDisplay = _clampInt(
                  range.start + indentLength,
                  0,
                  displayText.length,
                );
                final endDisplay = _clampInt(
                  range.end + indentLength,
                  0,
                  displayText.length,
                );
                if (endDisplay > startDisplay) {
                  wavyRanges.add(_WavyRange(startDisplay, endDisplay));
                }
              }
            }

            final textSpan =
                bookmarkRanges.isNotEmpty
                    ? _buildBookmarkTextSpan(
                      displayText: displayText,
                      ranges: bookmarkRanges,
                      indentLength: indentLength,
                      baseStyle: textStyle,
                      colors: colors,
                    )
                    : TextSpan(text: displayText, style: textStyle);

            final needsPainter = wavyRanges.isNotEmpty;
            final textPainter =
                needsPainter
                    ? _buildParagraphPainter(
                      displayText: displayText,
                      textStyle: textStyle,
                      maxWidth: constraints.maxWidth,
                      textDirection: Directionality.of(context),
                    )
                    : null;

            Widget textWidget = GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (details) {
                final handled = _handleBookmarkTap(
                  paragraphContext: context,
                  paragraphIndex: paragraphIndex,
                  paragraphText: paragraph,
                  localPosition: details.localPosition,
                  maxWidth: constraints.maxWidth,
                  textStyle: textStyle,
                );
                if (handled) {
                  _suppressNextReaderTap = true;
                }
              },
              child: Text.rich(
                textSpan,
                textAlign: _paragraphTextAlign(_settings),
                textDirection: Directionality.of(context),
              ),
            );

            if (wavyRanges.isNotEmpty && textPainter != null) {
              textWidget = CustomPaint(
                foregroundPainter: _WavyUnderlinePainter(
                  textPainter: textPainter,
                  ranges: wavyRanges,
                  color: colors.text.withValues(alpha: 0.7),
                  amplitude: (textStyle.fontSize ?? 18) * 0.26,
                  wavelength: (textStyle.fontSize ?? 18) * 1.6,
                  thickness: _decorationThickness(textStyle, wavy: true),
                ),
                child: textWidget,
              );
            }

            return textWidget;
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
                if (!_scrollController.hasClients ||
                    _isMangaChapter ||
                    _isPagedTextReaderEnabled()) {
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

  TextPainter _buildParagraphPainter({
    required String displayText,
    required TextStyle textStyle,
    required double maxWidth,
    required TextDirection textDirection,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: displayText, style: textStyle),
      textAlign: _paragraphTextAlign(_settings),
      textDirection: textDirection,
    );
    painter.layout(maxWidth: maxWidth);
    return painter;
  }

  Widget _buildInlineImageParagraphItem({
    required String imageUrl,
    required bool isLast,
    required _ReaderThemeColors colors,
  }) {
    final paddingBottom = isLast ? 0.0 : _settings.paragraphSpacing;
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
    final normalized = paragraph.trim();
    if (!normalized.startsWith(_inlineImageMarkerPrefix) ||
        !normalized.endsWith(_inlineImageMarkerSuffix)) {
      return null;
    }
    final raw = normalized.substring(
      _inlineImageMarkerPrefix.length,
      normalized.length - _inlineImageMarkerSuffix.length,
    );
    final imageUrl = raw.trim();
    return imageUrl.isEmpty ? null : imageUrl;
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

  double _decorationThickness(TextStyle baseStyle, {required bool wavy}) {
    final fontSize = baseStyle.fontSize ?? 18;
    final factor = wavy ? 0.28 : 0.14;
    return max(wavy ? 3.0 : 2.2, fontSize * factor);
  }

  TextSpan _buildBookmarkTextSpan({
    required String displayText,
    required List<_BookmarkRange> ranges,
    required int indentLength,
    required TextStyle baseStyle,
    required _ReaderThemeColors colors,
  }) {
    if (ranges.isEmpty) {
      return TextSpan(text: displayText, style: baseStyle);
    }

    final merged = _mergeBookmarkRanges(ranges);
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final range in merged) {
      final start = _clampInt(
        range.start + indentLength,
        0,
        displayText.length,
      );
      final end = _clampInt(range.end + indentLength, 0, displayText.length);
      if (start > cursor) {
        spans.add(
          TextSpan(
            text: displayText.substring(cursor, start),
            style: baseStyle,
          ),
        );
      }
      if (end > start) {
        final highlightStyle = _buildBookmarkHighlightStyle(
          baseStyle: baseStyle,
          colors: colors,
          range: range,
        );
        spans.add(
          TextSpan(
            text: displayText.substring(start, end),
            style: highlightStyle,
          ),
        );
        cursor = end;
      }
    }

    if (cursor < displayText.length) {
      spans.add(
        TextSpan(text: displayText.substring(cursor), style: baseStyle),
      );
    }

    return TextSpan(children: spans);
  }

  List<_BookmarkRange> _mergeBookmarkRanges(List<_BookmarkRange> ranges) {
    if (ranges.length <= 1) {
      return List<_BookmarkRange>.from(ranges);
    }

    final sorted = [...ranges]..sort((a, b) => a.start.compareTo(b.start));
    final merged = <_BookmarkRange>[];
    var current = sorted.first;
    for (var i = 1; i < sorted.length; i++) {
      final next = sorted[i];
      if (_canMergeBookmarkRanges(current, next)) {
        current = _BookmarkRange(
          current.start,
          max(current.end, next.end),
          isBold: current.isBold,
          isUnderline: current.isUnderline,
          isWavy: current.isWavy,
        );
      } else {
        merged.add(current);
        current = next;
      }
    }
    merged.add(current);
    return merged;
  }

  bool _canMergeBookmarkRanges(_BookmarkRange a, _BookmarkRange b) {
    if (b.start > a.end) {
      return false;
    }
    return a.isBold == b.isBold &&
        a.isUnderline == b.isUnderline &&
        a.isWavy == b.isWavy;
  }

  TextStyle _buildBookmarkHighlightStyle({
    required TextStyle baseStyle,
    required _ReaderThemeColors colors,
    required _BookmarkRange range,
  }) {
    final decorationEnabled = range.isUnderline && !range.isWavy;
    return baseStyle.copyWith(
      backgroundColor: colors.text.withValues(alpha: 0.12),
      fontWeight: range.isBold ? FontWeight.w800 : baseStyle.fontWeight,
      decoration:
          decorationEnabled ? TextDecoration.underline : TextDecoration.none,
      decorationStyle: TextDecorationStyle.solid,
      decorationColor: colors.text.withValues(alpha: 0.55),
      decorationThickness: _decorationThickness(baseStyle, wavy: false),
    );
  }

  int _paragraphIndentLength() {
    final indentCount = _settings.paragraphIndent.round();
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
    if (_isPagedTextReaderEnabled() && _pagedPages.isNotEmpty) {
      return _resolveChapterOffsetFromPagedDisplayOffset(displayOffset);
    }

    final paragraphs =
        _paragraphs.isEmpty
            ? <String>[_content.trim()]
            : _paragraphs.toList(growable: false);
    if (paragraphs.isEmpty) {
      return displayOffset;
    }

    final indentLength = _paragraphIndentLength();
    // Selection offsets are based on concatenated selectable text without
    // paragraph separators, so map back to chapter offsets with +2 gaps.
    final totalDisplayLength = paragraphs.fold<int>(
      0,
      (sum, item) => sum + item.length + indentLength,
    );
    var remaining = _clampInt(displayOffset, 0, totalDisplayLength);
    var chapterOffset = 0;
    for (var i = 0; i < paragraphs.length; i++) {
      final rawLength = paragraphs[i].length;
      final displayLength = rawLength + indentLength;
      if (remaining <= displayLength) {
        final localDisplay = remaining;
        final localRaw = _clampInt(localDisplay - indentLength, 0, rawLength);
        return chapterOffset + localRaw;
      }
      remaining -= displayLength;
      chapterOffset += rawLength + 2;
    }

    final last = paragraphs.last;
    return max(0, chapterOffset - 2 + last.length);
  }

  int _resolveChapterOffsetFromPagedDisplayOffset(int displayOffset) {
    final paragraphs =
        _paragraphs.isEmpty
            ? <String>[_content.trim()]
            : _paragraphs.toList(growable: false);
    if (paragraphs.isEmpty || _pagedPages.isEmpty) {
      return displayOffset;
    }

    final pageIndex = _currentPageIndex.clamp(0, _pagedPages.length - 1);
    final page = _pagedPages[pageIndex];
    if (page.isEmpty) {
      return displayOffset;
    }

    final starts = <int>[];
    var offset = 0;
    for (final paragraph in paragraphs) {
      starts.add(offset);
      offset += paragraph.length + 2;
    }

    final indentLength = _paragraphIndentLength();
    var totalDisplayLength = 0;
    for (final slice in page) {
      final sliceIndent = slice.start == 0 ? indentLength : 0;
      totalDisplayLength += (slice.end - slice.start) + sliceIndent;
    }

    var remaining = _clampInt(displayOffset, 0, totalDisplayLength);
    for (final slice in page) {
      final paragraphIndex = slice.paragraphIndex;
      if (paragraphIndex < 0 || paragraphIndex >= paragraphs.length) {
        continue;
      }

      final sliceIndent = slice.start == 0 ? indentLength : 0;
      final sliceDisplayLength = (slice.end - slice.start) + sliceIndent;
      if (remaining <= sliceDisplayLength) {
        final localDisplay = remaining;
        final localRaw = _clampInt(
          localDisplay - sliceIndent,
          0,
          slice.end - slice.start,
        );
        return starts[paragraphIndex] + slice.start + localRaw;
      }
      remaining -= sliceDisplayLength;
    }

    final lastSlice = page.last;
    final safeParagraphIndex = lastSlice.paragraphIndex.clamp(
      0,
      paragraphs.length - 1,
    );
    return starts[safeParagraphIndex] + lastSlice.end;
  }

  int _resolveChapterOffsetFromParagraph({
    required int paragraphIndex,
    required int paragraphOffset,
  }) {
    final paragraphs =
        _paragraphs.isEmpty
            ? <String>[_content.trim()]
            : _paragraphs.toList(growable: false);
    if (paragraphs.isEmpty) {
      return paragraphOffset;
    }

    final safeIndex = _clampInt(paragraphIndex, 0, paragraphs.length - 1);
    var offset = 0;
    for (var i = 0; i < safeIndex; i++) {
      offset += paragraphs[i].length + 2;
    }
    offset += _clampInt(paragraphOffset, 0, paragraphs[safeIndex].length);
    return offset;
  }

  Widget _wrapSelectionArea({required Widget child}) {
    return SelectionArea(
      key: _selectionAreaKey,
      contextMenuBuilder: _buildSelectionContextMenu,
      onSelectionChanged: _handleSelectionChanged,
      child: SelectionListener(
        selectionNotifier: _selectionNotifier,
        child: child,
      ),
    );
  }

  void _clearSystemSelection() {
    final selectionAreaState = _selectionAreaKey.currentState;
    if (selectionAreaState == null) {
      return;
    }
    selectionAreaState.selectableRegion.clearSelection();
  }

  bool _handleBookmarkTap({
    required BuildContext paragraphContext,
    required int paragraphIndex,
    required String paragraphText,
    required Offset localPosition,
    required double maxWidth,
    required TextStyle textStyle,
  }) {
    final ranges = _bookmarkRangesByParagraph[paragraphIndex];
    if (ranges == null || ranges.isEmpty) {
      return false;
    }

    final displayText = _applyParagraphIndent(paragraphText);
    if (displayText.isEmpty) {
      return false;
    }
    final indentLength = displayText.length - paragraphText.length;
    final painter = _buildParagraphPainter(
      displayText: displayText,
      textStyle: textStyle,
      maxWidth: maxWidth,
      textDirection: Directionality.of(context),
    );
    final position = painter.getPositionForOffset(localPosition);
    final displayIndex = _clampInt(position.offset, 0, displayText.length);
    final rawIndex = _clampInt(
      displayIndex - indentLength,
      0,
      paragraphText.length,
    );

    _BookmarkRange? hitRange;
    for (final range in ranges) {
      if (rawIndex >= range.start && rawIndex <= range.end) {
        if (hitRange == null ||
            (range.end - range.start) < (hitRange.end - hitRange.start)) {
          hitRange = range;
        }
      }
    }
    final resolvedRange = hitRange;
    if (resolvedRange == null) {
      return false;
    }

    final snippet =
        paragraphText.substring(resolvedRange.start, resolvedRange.end).trim();
    if (snippet.isEmpty) {
      return false;
    }

    final startOffset = _resolveChapterOffsetFromParagraph(
      paragraphIndex: paragraphIndex,
      paragraphOffset: resolvedRange.start,
    );
    final endOffset = _resolveChapterOffsetFromParagraph(
      paragraphIndex: paragraphIndex,
      paragraphOffset: resolvedRange.end,
    );
    final renderBox = paragraphContext.findRenderObject() as RenderBox?;
    final globalPosition =
        renderBox?.localToGlobal(localPosition) ?? Offset.zero;

    setState(() {
      _isTextSelectionActive = true;
      _selectionStartOffset = startOffset;
      _selectionEndOffset = endOffset;
      _selectedSnippet = snippet;
      _selectionBold = resolvedRange.isBold;
      _selectionUnderline = resolvedRange.isUnderline && !resolvedRange.isWavy;
      _selectionWavy = resolvedRange.isWavy;
    });
    unawaited(_syncVolumeKeyPageInterception());
    _showBookmarkToolbar(globalPosition);
    return true;
  }

  bool _handleBookmarkTapInSlice({
    required _PagedSlice slice,
    required String paragraphText,
    required BuildContext paragraphContext,
    required Offset localPosition,
    required double maxWidth,
    required TextStyle textStyle,
  }) {
    final ranges = _bookmarkRangesByParagraph[slice.paragraphIndex];
    if (ranges == null || ranges.isEmpty) {
      return false;
    }

    final rawText = paragraphText.substring(slice.start, slice.end);
    final displayText =
        slice.start == 0 ? _applyParagraphIndent(rawText) : rawText;
    if (displayText.isEmpty) {
      return false;
    }
    final indentLength = displayText.length - rawText.length;
    final painter = _buildParagraphPainter(
      displayText: displayText,
      textStyle: textStyle,
      maxWidth: maxWidth,
      textDirection: Directionality.of(context),
    );
    final position = painter.getPositionForOffset(localPosition);
    final displayIndex = _clampInt(position.offset, 0, displayText.length);
    final localRaw = _clampInt(
      displayIndex - (slice.start == 0 ? indentLength : 0),
      0,
      slice.end - slice.start,
    );
    final rawIndex = slice.start + localRaw;

    _BookmarkRange? hitRange;
    for (final range in ranges) {
      if (rawIndex >= range.start && rawIndex <= range.end) {
        if (hitRange == null ||
            (range.end - range.start) < (hitRange.end - hitRange.start)) {
          hitRange = range;
        }
      }
    }
    final resolvedRange = hitRange;
    if (resolvedRange == null) {
      return false;
    }

    final snippet =
        paragraphText.substring(resolvedRange.start, resolvedRange.end).trim();
    if (snippet.isEmpty) {
      return false;
    }

    final startOffset = _resolveChapterOffsetFromParagraph(
      paragraphIndex: slice.paragraphIndex,
      paragraphOffset: resolvedRange.start,
    );
    final endOffset = _resolveChapterOffsetFromParagraph(
      paragraphIndex: slice.paragraphIndex,
      paragraphOffset: resolvedRange.end,
    );
    final renderBox = paragraphContext.findRenderObject() as RenderBox?;
    final globalPosition =
        renderBox?.localToGlobal(localPosition) ?? Offset.zero;

    setState(() {
      _isTextSelectionActive = true;
      _selectionStartOffset = startOffset;
      _selectionEndOffset = endOffset;
      _selectedSnippet = snippet;
      _selectionBold = resolvedRange.isBold;
      _selectionUnderline = resolvedRange.isUnderline && !resolvedRange.isWavy;
      _selectionWavy = resolvedRange.isWavy;
    });
    unawaited(_syncVolumeKeyPageInterception());
    _showBookmarkToolbar(globalPosition);
    return true;
  }

  void _handleSelectionChanged(SelectedContent? content) {
    _selectedSnippet = content?.plainText.trim() ?? '';
    _syncSelectionState();
  }

  _SelectionStyle _resolveSelectionStyleByOverlap({
    required int startOffset,
    required int endOffset,
  }) {
    if (_chapterBookmarks.isEmpty) {
      return const _SelectionStyle(bold: false, underline: false, wavy: false);
    }

    var hasBold = false;
    var hasUnderline = false;
    var hasWavy = false;
    for (final bookmark in _chapterBookmarks) {
      if (!_isBookmarkInCurrentChapter(bookmark)) {
        continue;
      }
      final overlaps =
          endOffset > bookmark.startOffset && startOffset < bookmark.endOffset;
      if (!overlaps) {
        continue;
      }
      if (bookmark.isBold) {
        hasBold = true;
      }
      if (bookmark.isWavy) {
        hasWavy = true;
      }
      if (bookmark.isUnderline) {
        hasUnderline = true;
      }
    }

    if (hasWavy) {
      hasUnderline = false;
    }

    return _SelectionStyle(
      bold: hasBold,
      underline: hasUnderline,
      wavy: hasWavy,
    );
  }

  void _handleSelectionNotifierChanged() {
    if (!_selectionNotifier.registered) {
      return;
    }
    final details = _selectionNotifier.selection;
    _selectionStatus = details.status;
    try {
      _selectionRange = details.range;
    } catch (_) {
      _clearSelectionState();
      return;
    }
    _syncSelectionState();
  }

  void _syncSelectionState() {
    final range = _selectionRange;
    final snippet = _selectedSnippet.trim();
    final hasRange = range != null;
    final hasSnippet = snippet.isNotEmpty;
    final isActive =
        _selectionStatus == SelectionStatus.uncollapsed &&
        hasRange &&
        hasSnippet;

    if (!isActive) {
      if (_isTextSelectionActive &&
          (_selectionStatus != SelectionStatus.uncollapsed ||
              !hasRange ||
              !hasSnippet)) {
        _clearSelectionState();
      }
      return;
    }

    _hideBookmarkToolbar();

    final startOffset = _resolveChapterOffsetFromDisplayOffset(
      range.startOffset,
    );
    final endOffset = _resolveChapterOffsetFromDisplayOffset(range.endOffset);
    var safeStart = min(startOffset, endOffset);
    var safeEnd = max(startOffset, endOffset);
    final totalLength = _chapterTextLength();
    if (safeStart == safeEnd) {
      safeEnd = min(safeStart + 1, totalLength);
    }
    if (safeEnd <= safeStart) {
      _clearSelectionState();
      return;
    }

    final overlapStyle = _resolveSelectionStyleByOverlap(
      startOffset: safeStart,
      endOffset: safeEnd,
    );
    final nextBold = overlapStyle.bold;
    final nextWavy = overlapStyle.wavy;
    final nextUnderline = overlapStyle.underline;

    final wasActive = _isTextSelectionActive;
    setState(() {
      _isTextSelectionActive = true;
      _selectionStartOffset = safeStart;
      _selectionEndOffset = safeEnd;
      _selectionBold = nextBold;
      _selectionUnderline = nextUnderline;
      _selectionWavy = nextWavy;
    });
    unawaited(_syncVolumeKeyPageInterception());

    if (!wasActive) {
      if (_isAutoReadSessionEnabled) {
        _stopAutoReadSession(showMessage: true);
      }
      _hideOverlayControls(resumeAutoRead: false);
    }
  }

  void _clearSelectionState() {
    if (!_isTextSelectionActive && _selectedSnippet.isEmpty) {
      _selectionRange = null;
      _selectionStatus = SelectionStatus.none;
      return;
    }

    setState(() {
      _isTextSelectionActive = false;
      _selectionStartOffset = 0;
      _selectionEndOffset = 0;
      _selectedSnippet = '';
    });
    unawaited(_syncVolumeKeyPageInterception());
    _hideBookmarkToolbar();
    _selectionRange = null;
    _selectionStatus = SelectionStatus.none;
  }

  void _showBookmarkToolbar(Offset globalPosition) {
    if (!mounted) {
      return;
    }
    _hideBookmarkToolbar();

    final anchors = TextSelectionToolbarAnchors(
      primaryAnchor: globalPosition,
      secondaryAnchor: globalPosition,
    );

    _bookmarkToolbarEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _clearSelectionState,
                child: const SizedBox.shrink(),
              ),
            ),
            AdaptiveTextSelectionToolbar.buttonItems(
              anchors: anchors,
              buttonItems: [
                ContextMenuButtonItem(
                  label: '删除收藏',
                  onPressed: () {
                    _hideBookmarkToolbar();
                    final existing = _currentSelectionBookmark();
                    if (existing != null) {
                      unawaited(_onRemoveBookmarkPressed(existing));
                    } else {
                      _clearSelectionState();
                    }
                  },
                ),
                ContextMenuButtonItem(
                  label: _selectionBold ? '取消加粗' : '加粗',
                  onPressed: () {
                    unawaited(_toggleSelectionBold());
                  },
                ),
                ContextMenuButtonItem(
                  label: _selectionUnderline ? '取消下划线' : '下划线',
                  onPressed: () {
                    unawaited(_toggleSelectionUnderline());
                  },
                ),
                ContextMenuButtonItem(
                  label: _selectionWavy ? '取消波浪线' : '波浪线',
                  onPressed: () {
                    unawaited(_toggleSelectionWavy());
                  },
                ),
              ],
            ),
          ],
        );
      },
    );

    final overlay = Overlay.of(context, rootOverlay: true);
    overlay.insert(_bookmarkToolbarEntry!);
  }

  void _hideBookmarkToolbar() {
    _bookmarkToolbarEntry?.remove();
    _bookmarkToolbarEntry = null;
  }

  Widget _buildSelectionContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    if (!selectableRegionState.mounted) {
      return const SizedBox.shrink();
    }

    final hasSelection = _isTextSelectionActive && _selectedSnippet.isNotEmpty;
    final existingBookmark = _currentSelectionBookmark();
    final isBookmarked = existingBookmark != null;

    TextSelectionToolbarAnchors anchors;
    try {
      anchors = selectableRegionState.contextMenuAnchors;
    } catch (_) {
      return const SizedBox.shrink();
    }

    void hideToolbar() {
      selectableRegionState.hideToolbar();
    }

    final customItems = <ContextMenuButtonItem>[
      ContextMenuButtonItem(
        label: isBookmarked ? '删除收藏' : '保存收藏',
        onPressed:
            hasSelection
                ? () {
                  hideToolbar();
                  if (isBookmarked) {
                    unawaited(
                      _onRemoveBookmarkPressed(
                        existingBookmark,
                        clearSelectionState: selectableRegionState,
                      ),
                    );
                  } else {
                    unawaited(
                      _onSaveBookmarkPressed(
                        clearSelectionState: selectableRegionState,
                      ),
                    );
                  }
                }
                : null,
      ),
      ContextMenuButtonItem(
        label: _selectionBold ? '取消加粗' : '加粗',
        onPressed:
            hasSelection
                ? () {
                  unawaited(_toggleSelectionBold());
                }
                : null,
      ),
      ContextMenuButtonItem(
        label: _selectionUnderline ? '取消下划线' : '下划线',
        onPressed:
            hasSelection
                ? () {
                  unawaited(_toggleSelectionUnderline());
                }
                : null,
      ),
      ContextMenuButtonItem(
        label: _selectionWavy ? '取消波浪线' : '波浪线',
        onPressed:
            hasSelection
                ? () {
                  unawaited(_toggleSelectionWavy());
                }
                : null,
      ),
      ContextMenuButtonItem(
        label: '取消选择',
        onPressed:
            hasSelection
                ? () {
                  hideToolbar();
                  selectableRegionState.clearSelection();
                  _clearSelectionState();
                }
                : null,
      ),
    ];

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: anchors,
      buttonItems: [
        ...customItems,
        ...selectableRegionState.contextMenuButtonItems,
      ],
    );
  }

  Future<void> _toggleSelectionBold() async {
    if (!_isTextSelectionActive) {
      return;
    }
    setState(() {
      _selectionBold = !_selectionBold;
    });
    await _persistSelectionStyleForSelection(
      createdMessage: _selectionBold ? '已保存收藏并加粗' : '已保存收藏',
    );
  }

  Future<void> _toggleSelectionUnderline() async {
    if (!_isTextSelectionActive) {
      return;
    }
    setState(() {
      _selectionUnderline = !_selectionUnderline;
      if (_selectionUnderline) {
        _selectionWavy = false;
      }
    });
    await _persistSelectionStyleForSelection(
      createdMessage: _selectionUnderline ? '已保存收藏并添加下划线' : '已保存收藏',
    );
  }

  Future<void> _toggleSelectionWavy() async {
    if (!_isTextSelectionActive) {
      return;
    }
    setState(() {
      _selectionWavy = !_selectionWavy;
      if (_selectionWavy) {
        _selectionUnderline = false;
      }
    });
    await _persistSelectionStyleForSelection(
      createdMessage: _selectionWavy ? '已保存收藏并添加波浪线' : '已保存收藏',
    );
  }

  Future<void> _onSaveBookmarkPressed({
    SelectableRegionState? clearSelectionState,
  }) async {
    if (!_isTextSelectionActive || _selectedSnippet.isEmpty) {
      return;
    }

    final existing = _currentSelectionBookmark();
    if (existing != null) {
      _showMessage('收藏已存在');
      _clearSelectionState();
      clearSelectionState?.clearSelection();
      return;
    }

    await _saveSelectionBookmark(clearSelectionState: clearSelectionState);
    _showMessage('已保存收藏');
    _clearSelectionState();
  }

  Future<void> _onRemoveBookmarkPressed(
    Bookmark bookmark, {
    SelectableRegionState? clearSelectionState,
  }) async {
    await _bookmarkRepository.removeBookmark(bookmark.id);
    _showMessage('已删除收藏');
    unawaited(_refreshChapterBookmarks());
    _clearSelectionState();
    clearSelectionState?.clearSelection();
  }

  Future<void> _persistSelectionStyleForSelection({
    required String createdMessage,
  }) async {
    if (!_isTextSelectionActive || _selectedSnippet.isEmpty) {
      return;
    }
    final existing = _currentSelectionBookmark();
    await _saveSelectionBookmark(existing: existing, clearSelectionState: null);
    _bookmarkToolbarEntry?.markNeedsBuild();
    if (existing == null) {
      _showMessage(createdMessage);
    }
  }

  Future<void> _saveSelectionBookmark({
    Bookmark? existing,
    SelectableRegionState? clearSelectionState,
  }) async {
    if (!_isTextSelectionActive || _selectedSnippet.isEmpty) {
      return;
    }
    final now = DateTime.now();
    final startOffset = _selectionStartOffset;
    final endOffset = _selectionEndOffset;
    if (startOffset == endOffset) {
      return;
    }

    final isWavy = _selectionWavy;
    final isUnderline = isWavy ? false : _selectionUnderline;
    final bookmark = Bookmark(
      id: existing?.id ?? _uuid.v4().replaceAll('-', ''),
      bookId: _currentBookId,
      chapterId: _chapterId,
      chapterIndex: _currentIndex ?? 0,
      startOffset: startOffset,
      endOffset: endOffset,
      snippet: _selectedSnippet,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      isBold: _selectionBold,
      isUnderline: isUnderline,
      isWavy: isWavy,
      color: existing?.color,
    );

    await _bookmarkRepository.addBookmark(bookmark);
    unawaited(_refreshChapterBookmarks());
    clearSelectionState?.clearSelection();
  }

  bool _onReaderScrollNotification(ScrollNotification notification) {
    if (_isPagedTextReaderEnabled()) {
      return false;
    }

    if (notification is ScrollStartNotification &&
        notification.dragDetails != null &&
        _isAutoReadSessionEnabled) {
      _stopAutoReadSession();
    }

    if (!_pageTurnUsesScroll(_settings.pageTurnMode) ||
        _isMangaChapter ||
        _isBootstrapping ||
        _isLoadingContent ||
        _errorText != null) {
      if (notification is ScrollStartNotification ||
          notification is ScrollEndNotification ||
          (notification is UserScrollNotification &&
              notification.direction == ScrollDirection.idle)) {
        _scrollEdgeOverscrollDistance = 0;
        _scrollEdgeAdvanceArmed = false;
        _scrollEdgeActionDirection = 0;
      }
      return false;
    }

    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification is ScrollStartNotification) {
      _scrollEdgeOverscrollDistance = 0;
      _scrollEdgeAdvanceArmed = false;
      _scrollEdgeActionDirection = 0;
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
        _scrollEdgeAdvanceArmed = true;
        _scrollEdgeActionDirection = 1;
      } else if (notification.direction == ScrollDirection.forward && nearTop) {
        _scrollEdgeAdvanceArmed = true;
        _scrollEdgeActionDirection = -1;
      } else if (notification.direction == ScrollDirection.forward) {
        _scrollEdgeAdvanceArmed = false;
        _scrollEdgeActionDirection = 0;
      } else if (notification.direction == ScrollDirection.idle) {
        _scrollEdgeAdvanceArmed = false;
        _scrollEdgeActionDirection = 0;
      }
    }

    if (!atBottom && !atTop) {
      _scrollEdgeOverscrollDistance = 0;
      if (notification is ScrollEndNotification ||
          (notification is UserScrollNotification &&
              notification.direction == ScrollDirection.idle)) {
        _scrollEdgeAdvanceArmed = false;
        _scrollEdgeActionDirection = 0;
      }
      return false;
    }

    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null &&
        notification.scrollDelta != null) {
      final delta = notification.scrollDelta!;
      if (nearBottom && delta >= 0) {
        _scrollEdgeAdvanceArmed = true;
        _scrollEdgeActionDirection = 1;
      } else if (nearTop && delta <= 0) {
        _scrollEdgeAdvanceArmed = true;
        _scrollEdgeActionDirection = -1;
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
        _scrollEdgeAdvanceArmed = true;
        _scrollEdgeActionDirection = direction;
        _scrollEdgeOverscrollDistance += notification.overscroll.abs();
      }
      if (_scrollEdgeOverscrollDistance >= _kScrollAdvanceOverscrollTrigger &&
          _scrollEdgeActionDirection != 0) {
        _scrollEdgeOverscrollDistance = 0;
        _scrollEdgeAdvanceArmed = false;
        final actionDirection = _scrollEdgeActionDirection;
        _scrollEdgeActionDirection = 0;
        unawaited(_handleScrollEdgeChapterAction(actionDirection));
      }
      return false;
    }

    if (notification is ScrollEndNotification ||
        (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle)) {
      var shouldAdvance = _scrollEdgeAdvanceArmed;
      var actionDirection = _scrollEdgeActionDirection;
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
      _scrollEdgeOverscrollDistance = 0;
      _scrollEdgeAdvanceArmed = false;
      _scrollEdgeActionDirection = 0;
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
      if (direction > 0) {
        await _appendNextContinuousTextChapter();
      } else {
        await _prependPreviousContinuousTextChapter();
      }
      return;
    }
    if (direction > 0) {
      await _advanceChapterFromScrollEdge();
      return;
    }
    await _retreatChapterFromScrollEdge();
  }

  Future<void> _advanceChapterFromScrollEdge() async {
    if (_isScrollEdgeAdvancingChapter || _isAutoReadAdvancingChapter) {
      return;
    }

    final index = _currentIndex;
    if (index == null || index >= _chapters.length - 1) {
      return;
    }

    _isScrollEdgeAdvancingChapter = true;
    try {
      await _jumpTo(index + 1, initialScrollRatio: 0);
    } finally {
      _isScrollEdgeAdvancingChapter = false;
    }
  }

  Future<void> _retreatChapterFromScrollEdge() async {
    if (_isScrollEdgeAdvancingChapter || _isAutoReadAdvancingChapter) {
      return;
    }

    final index = _currentIndex;
    if (index == null || index <= 0) {
      return;
    }

    _isScrollEdgeAdvancingChapter = true;
    try {
      await _jumpTo(index - 1, initialScrollRatio: 1);
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
    return switch (_settings.mangaReadMode) {
      ReaderMangaReadMode.continuous => _buildMangaContinuousReader(colors),
      ReaderMangaReadMode.paged => _buildMangaPagedReader(
        colors,
        axis: Axis.vertical,
      ),
      ReaderMangaReadMode.horizontal => _buildMangaPagedReader(
        colors,
        axis: Axis.horizontal,
      ),
    };
  }

  Widget _buildMangaContinuousReader(_ReaderThemeColors colors) {
    final horizontalPadding = _settings.mangaImagePadding;

    final bottomInset = _effectiveBottomSafeInset(context);

    return ListView.separated(
      key: ValueKey('manga_$_chapterId'),
      controller: _scrollController,
      cacheExtent: _resolveMangaCacheExtent(),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        12,
        horizontalPadding,
        96 + bottomInset,
      ),
      itemCount: _chapterImageUrls.length,
      separatorBuilder:
          (_, __) => SizedBox(height: _settings.mangaImageSpacing),
      itemBuilder: (context, index) {
        return _buildMangaImageCard(colors: colors, index: index);
      },
    );
  }

  Widget _buildMangaPagedReader(
    _ReaderThemeColors colors, {
    required Axis axis,
  }) {
    final pageCount = _chapterImageUrls.length;
    if (pageCount == 0) {
      return const SizedBox.shrink();
    }

    final currentIndex = _mangaPageIndex.clamp(
      0,
      _safePageUpperBound(pageCount),
    );
    final physics =
        _mangaZoomedPageIndexes.contains(currentIndex)
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics();

    final bottomInset = _effectiveBottomSafeInset(context);

    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 94 + bottomInset),
          child: PageView.builder(
            key: ValueKey(
              'manga_${_chapterId}_${_settings.mangaReadMode.name}',
            ),
            controller: _mangaPageController,
            scrollDirection: axis,
            physics: physics,
            itemCount: pageCount,
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
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  _settings.mangaImagePadding,
                  12,
                  _settings.mangaImagePadding,
                  6,
                ),
                child: _buildMangaImageCard(colors: colors, index: index),
              );
            },
          ),
        ),
        _buildPageIndexOverlay(
          colors: colors,
          index: currentIndex,
          total: pageCount,
          bottomInset: bottomInset,
        ),
      ],
    );
  }

  Widget _buildMangaImageCard({
    required _ReaderThemeColors colors,
    required int index,
  }) {
    final imageUrl = _chapterImageUrls[index];
    final retryNonce = _mangaImageRetryNonce[imageUrl] ?? 0;
    final requestUrl = _buildMangaImageUrl(imageUrl, retryNonce);
    final transformController = _ensureMangaTransformController(index);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: colors.overlay,
        child: GestureDetector(
          onDoubleTapDown: (details) {
            _mangaDoubleTapDetails[index] = details;
          },
          onDoubleTap: () => _toggleMangaZoom(index),
          child: InteractiveViewer(
            transformationController: transformController,
            minScale: 1,
            maxScale: 4,
            panEnabled: true,
            onInteractionEnd: (_) => _syncMangaZoomState(index),
            child: _buildReaderImageWidget(
              requestUrl: requestUrl,
              sourceUrl: imageUrl,
              colors: colors,
              retryNonce: retryNonce,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReaderImageWidget({
    required String requestUrl,
    required String sourceUrl,
    required _ReaderThemeColors colors,
    required int retryNonce,
  }) {
    final uri = Uri.tryParse(requestUrl);
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

  Widget _buildDataUriImage({
    required String dataUri,
    required _ReaderThemeColors colors,
    required String sourceUrl,
    required int retryNonce,
  }) {
    try {
      final commaIndex = dataUri.indexOf(',');
      if (commaIndex <= 0) {
        throw const FormatException('Invalid data URI');
      }
      final encoded = dataUri.substring(commaIndex + 1);
      final bytes = base64Decode(encoded);
      return Image.memory(
        bytes,
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

  ReaderPageAnimationStyle _effectivePageAnimationStyle() {
    return _settings.pageAnimationStyle;
  }

  _PagedAnimationMotionSpec _pageSwitchMotionSpecForStyle(
    ReaderPageAnimationStyle style,
  ) {
    return switch (style) {
      ReaderPageAnimationStyle.curl => const _PagedAnimationMotionSpec(
        duration: _kCurlAutoTurnDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
      ),
      ReaderPageAnimationStyle.cover => const _PagedAnimationMotionSpec(
        duration: Duration(milliseconds: 520),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
      ),
      ReaderPageAnimationStyle.translate => const _PagedAnimationMotionSpec(
        duration: Duration(milliseconds: 430),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
      ),
      ReaderPageAnimationStyle.vertical => const _PagedAnimationMotionSpec(
        duration: Duration(milliseconds: 460),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
      ),
      ReaderPageAnimationStyle.fade => const _PagedAnimationMotionSpec(
        duration: Duration(milliseconds: 380),
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
      ),
      ReaderPageAnimationStyle.none => const _PagedAnimationMotionSpec(
        duration: Duration.zero,
        switchInCurve: Curves.linear,
        switchOutCurve: Curves.linear,
      ),
    };
  }

  Duration _pageSwitchDurationForStyle(ReaderPageAnimationStyle style) {
    return _pageSwitchMotionSpecForStyle(style).duration;
  }

  Curve _pageSwitchInCurveForStyle(ReaderPageAnimationStyle style) {
    return _pageSwitchMotionSpecForStyle(style).switchInCurve;
  }

  Curve _pageSwitchOutCurveForStyle(ReaderPageAnimationStyle style) {
    return _pageSwitchMotionSpecForStyle(style).switchOutCurve;
  }

  Widget _buildPagedReader(_ReaderThemeColors colors) {
    final paragraphs =
        _paragraphs.isEmpty ? <String>[_content.trim()] : _paragraphs;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bottomInset = _effectiveBottomSafeInset(context);
        final bodyLeft =
            _settings.bodyMarginLeft
                .clamp(
                  ReaderSettings.minLayoutMargin,
                  ReaderSettings.maxLayoutMargin,
                )
                .toDouble();
        final bodyTop =
            _settings.bodyMarginTop
                .clamp(
                  ReaderSettings.minLayoutMargin,
                  ReaderSettings.maxLayoutMargin,
                )
                .toDouble();
        final bodyRight =
            _settings.bodyMarginRight
                .clamp(
                  ReaderSettings.minLayoutMargin,
                  ReaderSettings.maxLayoutMargin,
                )
                .toDouble();
        final bodyBottom =
            _settings.bodyMarginBottom
                .clamp(
                  ReaderSettings.minLayoutMargin,
                  ReaderSettings.maxLayoutMargin,
                )
                .toDouble();
        final contentPadding = EdgeInsets.fromLTRB(
          bodyLeft,
          bodyTop,
          bodyRight,
          bodyBottom + bottomInset + _kBottomProgressReserve,
        );

        final maxWidth = (constraints.maxWidth - contentPadding.horizontal)
            .clamp(0.0, 2000.0);
        final maxHeight = (constraints.maxHeight -
                _pinnedHeaderTotalHeight(context) -
                contentPadding.vertical)
            .clamp(0.0, 4000.0);
        _lastPaginationMaxWidth = maxWidth;
        _lastPaginationMaxHeight = maxHeight;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ensurePagination(maxWidth: maxWidth, maxHeight: maxHeight);
        });

        if (_isPaginatingPages || _pagedPages.isEmpty) {
          return Column(
            children: [
              _buildPinnedChapterHeader(colors),
              Expanded(
                child: Padding(
                  padding: contentPadding,
                  child: _buildReaderStateCard(
                    colors: colors,
                    title: "正在分页",
                    message:
                        paragraphs.length <= 1
                            ? "正在为你生成阅读页面..."
                            : "正在生成 ${paragraphs.length} 段正文的分页...",
                    icon: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
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

        final animationStyle = _effectivePageAnimationStyle();
        final switchDuration = _pageSwitchDurationForStyle(animationStyle);
        final switchInCurve = _pageSwitchInCurveForStyle(animationStyle);
        final switchOutCurve = _pageSwitchOutCurveForStyle(animationStyle);

        return _buildPagedTransitionStack(
          colors: colors,
          animationStyle: animationStyle,
          pageCount: pageCount,
          safeIndex: safeIndex,
          pagedSize: pagedSize,
          contentPadding: contentPadding,
          bottomInset: bottomInset,
          switchDuration: switchDuration,
          switchInCurve: switchInCurve,
          switchOutCurve: switchOutCurve,
        );
      },
    );
  }

  Widget _buildPagedTransitionStack({
    required _ReaderThemeColors colors,
    required ReaderPageAnimationStyle animationStyle,
    required int pageCount,
    required int safeIndex,
    required Size pagedSize,
    required EdgeInsets contentPadding,
    required double bottomInset,
    required Duration switchDuration,
    required Curve switchInCurve,
    required Curve switchOutCurve,
  }) {
    final renderedAnimationStyle =
        _isPagedTransitionAnimating ? _pagedTransition.style : animationStyle;
    final pageStack = Stack(
      children: [
        Positioned.fill(
          child: switch (renderedAnimationStyle) {
            ReaderPageAnimationStyle.curl => _buildCustomCurlPageStack(
              colors: colors,
              pageCount: pageCount,
              safeIndex: safeIndex,
              pagedSize: pagedSize,
              contentPadding: contentPadding,
            ),
            ReaderPageAnimationStyle.none => _buildStaticPagedPage(
              colors: colors,
              pageIndex: safeIndex,
              pageSize: pagedSize,
              padding: contentPadding,
            ),
            _ => _buildAnimatedPagedPageTransition(
              colors: colors,
              animationStyle: renderedAnimationStyle,
              safeIndex: safeIndex,
              pagedSize: pagedSize,
              contentPadding: contentPadding,
              switchDuration: switchDuration,
              switchInCurve: switchInCurve,
              switchOutCurve: switchOutCurve,
            ),
          },
        ),
        if (pageCount > 1)
          SelectionContainer.disabled(
            child: _buildPageIndexOverlay(
              colors: colors,
              index: safeIndex,
              total: pageCount,
              bottomInset: bottomInset,
            ),
          ),
      ],
    );

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
    required EdgeInsets padding,
  }) {
    return KeyedSubtree(
      key: ValueKey<int>(pageIndex),
      child: _buildPagedPageContainer(
        colors: colors,
        pageIndex: pageIndex,
        pageSize: pageSize,
        padding: padding,
      ),
    );
  }

  Widget _buildAnimatedPagedPageTransition({
    required _ReaderThemeColors colors,
    required ReaderPageAnimationStyle animationStyle,
    required int safeIndex,
    required Size pagedSize,
    required EdgeInsets contentPadding,
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
        padding: contentPadding,
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
        padding: contentPadding,
      );
    }

    final fromPage = SelectionContainer.disabled(
      child: _buildStaticPagedPage(
        colors: colors,
        pageIndex: _pagedTransition.fromIndex,
        pageSize: pagedSize,
        padding: contentPadding,
      ),
    );
    final toPage = SelectionContainer.disabled(
      child: _buildStaticPagedPage(
        colors: colors,
        pageIndex: _pagedTransition.toIndex,
        pageSize: pagedSize,
        padding: contentPadding,
      ),
    );
    final effectRenderer = _resolvePagedAnimationEffectRenderer(animationStyle);

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
          coverBuilder:
              ({
                required Widget fromPage,
                required Widget toPage,
                required double progress,
                required double direction,
              }) => _buildCoverTransitionStack(
                fromPage: fromPage,
                toPage: toPage,
                progress: progress,
                direction: direction,
              ),
        );
      },
    );
  }

  _PagedAnimationEffectRenderer _resolvePagedAnimationEffectRenderer(
    ReaderPageAnimationStyle style,
  ) {
    return switch (style) {
      ReaderPageAnimationStyle.cover => const _CoverPagedAnimationEffect(),
      ReaderPageAnimationStyle.translate =>
        const _HorizontalSlidePagedAnimationEffect(),
      ReaderPageAnimationStyle.vertical =>
        const _VerticalSlidePagedAnimationEffect(),
      ReaderPageAnimationStyle.fade => const _FadePagedAnimationEffect(),
      ReaderPageAnimationStyle.curl ||
      ReaderPageAnimationStyle.none => const _FadePagedAnimationEffect(),
    };
  }

  Widget _buildCoverTransitionStack({
    required Widget fromPage,
    required Widget toPage,
    required double progress,
    required double direction,
  }) {
    final normalizedDirection = direction >= 0 ? 1.0 : -1.0;
    final fromRight = normalizedDirection > 0;
    final translateX = normalizedDirection * (1 - progress);
    final shadowAlpha = (1 - progress) * _kCoverEdgeShadowMaxAlpha;

    return Stack(
      fit: StackFit.expand,
      children: [
        fromPage,
        FractionalTranslation(
          translation: Offset(translateX, 0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              toPage,
              IgnorePointer(
                child: Align(
                  alignment:
                      fromRight ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    width: _kCoverEdgeShadowWidth,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin:
                            fromRight
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                        end:
                            fromRight
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                        colors: [
                          Colors.black.withValues(alpha: shadowAlpha),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPagedPageContainer({
    required _ReaderThemeColors colors,
    required int pageIndex,
    required Size pageSize,
    required EdgeInsets padding,
  }) {
    final pages = _pagedPages;
    if (pageIndex < 0 || pageIndex >= pages.length) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: pageSize.width,
      height: pageSize.height,
      child: DecoratedBox(
        decoration: _buildReaderBackgroundDecoration(colors),
        child: Column(
          children: [
            SelectionContainer.disabled(
              child: _buildPinnedChapterHeader(colors),
            ),
            Expanded(
              child: Padding(
                padding: padding,
                child: _buildPagedPage(colors: colors, page: pages[pageIndex]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagedPage({
    required _ReaderThemeColors colors,
    required List<_PagedSlice> page,
  }) {
    if (page.isEmpty) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < page.length; index++)
              Padding(
                padding: EdgeInsets.only(
                  bottom:
                      index == page.length - 1 ? 0 : _settings.paragraphSpacing,
                ),
                child: _buildPagedSliceContent(
                  slice: page[index],
                  colors: colors,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagedSliceContent({
    required _PagedSlice slice,
    required _ReaderThemeColors colors,
  }) {
    final paragraphs =
        _paragraphs.isEmpty ? <String>[_content.trim()] : _paragraphs;
    if (slice.paragraphIndex < 0 || slice.paragraphIndex >= paragraphs.length) {
      return const SizedBox.shrink();
    }

    final paragraph = paragraphs[slice.paragraphIndex];
    final rawText = paragraph.substring(slice.start, slice.end);
    final displayText =
        slice.start == 0 ? _applyParagraphIndent(rawText) : rawText;

    final textStyle = _paragraphTextStyle(colors);
    return LayoutBuilder(
      builder: (context, constraints) {
        final ranges =
            _bookmarkRangesByParagraph[slice.paragraphIndex] ??
            const <_BookmarkRange>[];
        final localRanges = <_BookmarkRange>[];
        if (ranges.isNotEmpty) {
          for (final range in ranges) {
            final overlapStart = max(range.start, slice.start);
            final overlapEnd = min(range.end, slice.end);
            if (overlapEnd <= overlapStart) {
              continue;
            }
            localRanges.add(
              _BookmarkRange(
                overlapStart - slice.start,
                overlapEnd - slice.start,
                isBold: range.isBold,
                isUnderline: range.isUnderline,
                isWavy: range.isWavy,
              ),
            );
          }
        }

        final indentLength = displayText.length - rawText.length;
        final mergedRanges =
            localRanges.isNotEmpty
                ? _mergeBookmarkRanges(localRanges)
                : const <_BookmarkRange>[];
        final textSpan =
            mergedRanges.isNotEmpty
                ? _buildBookmarkTextSpan(
                  displayText: displayText,
                  ranges: mergedRanges,
                  indentLength: indentLength,
                  baseStyle: textStyle,
                  colors: colors,
                )
                : TextSpan(text: displayText, style: textStyle);

        final wavyRanges = <_WavyRange>[];
        if (mergedRanges.isNotEmpty) {
          for (final range in mergedRanges) {
            if (!range.isWavy) {
              continue;
            }
            final startDisplay = _clampInt(
              range.start + indentLength,
              0,
              displayText.length,
            );
            final endDisplay = _clampInt(
              range.end + indentLength,
              0,
              displayText.length,
            );
            if (endDisplay > startDisplay) {
              wavyRanges.add(_WavyRange(startDisplay, endDisplay));
            }
          }
        }

        final needsPainter = wavyRanges.isNotEmpty;
        final textPainter =
            needsPainter
                ? _buildParagraphPainter(
                  displayText: displayText,
                  textStyle: textStyle,
                  maxWidth: constraints.maxWidth,
                  textDirection: Directionality.of(context),
                )
                : null;

        Widget textWidget = Text.rich(
          textSpan,
          textAlign: _paragraphTextAlign(_settings),
          textDirection: Directionality.of(context),
        );

        if (wavyRanges.isNotEmpty && textPainter != null) {
          textWidget = CustomPaint(
            foregroundPainter: _WavyUnderlinePainter(
              textPainter: textPainter,
              ranges: wavyRanges,
              color: colors.text.withValues(alpha: 0.7),
              amplitude: (textStyle.fontSize ?? 18) * 0.26,
              wavelength: (textStyle.fontSize ?? 18) * 1.6,
              thickness: _decorationThickness(textStyle, wavy: true),
            ),
            child: textWidget,
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) {
            final handled = _handleBookmarkTapInSlice(
              slice: slice,
              paragraphText: paragraph,
              paragraphContext: context,
              localPosition: details.localPosition,
              maxWidth: constraints.maxWidth,
              textStyle: textStyle,
            );
            if (handled) {
              _suppressNextReaderTap = true;
            }
          },
          child: textWidget,
        );
      },
    );
  }

  Widget _buildPageIndexBadge({
    required _ReaderThemeColors colors,
    required int index,
    required int total,
  }) {
    final safeTotal = total <= 0 ? 1 : total;
    final safeIndex = index.clamp(0, safeTotal - 1);
    final current = safeIndex + 1;
    final percent = (current / safeTotal) * 100;

    return Text(
      '$current/$safeTotal · ${percent.toStringAsFixed(2)}%',
      style: TextStyle(
        color: colors.text.withValues(alpha: 0.85),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildPageIndexOverlay({
    required _ReaderThemeColors colors,
    required int index,
    required int total,
    required double bottomInset,
  }) {
    final showProgress = _settings.infoShowProgress;
    final showTime = _settings.infoShowTime;
    final showBattery = _settings.infoShowBattery;
    final platform = Theme.of(context).platform;
    final safeBottomInset = max(
      bottomInset,
      _effectiveBottomSafeInset(context),
    );
    final collapsedTextBottomPadding =
        platform == TargetPlatform.iOS
            ? (safeBottomInset - 8).clamp(0.0, 64.0)
            : 4.0 + safeBottomInset;

    final rightItems = <String>[];
    if (showTime) {
      rightItems.add(_formatReaderInfoTime(_readerInfoNow));
    }
    if (showBattery) {
      rightItems.add(_readerBatteryLabel());
    }
    final rightLabel = rightItems.join(' · ');

    if (!showProgress && rightLabel.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _overlayControlsController,
      builder: (context, _) {
        final overlayFade = _overlayControlsFadeProgress;

        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Opacity(
              opacity: lerpDouble(1.0, 0.84, overlayFade)!,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  14,
                  0,
                  14,
                  collapsedTextBottomPadding,
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 160,
                      maxWidth: 520,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Row(
                        children: [
                          if (showProgress)
                            _buildPageIndexBadge(
                              colors: colors,
                              index: index,
                              total: total,
                            ),
                          if (showProgress && rightLabel.isNotEmpty)
                            const Spacer(),
                          if (rightLabel.isNotEmpty)
                            Text(
                              rightLabel,
                              style: TextStyle(
                                color: colors.meta.withValues(alpha: 0.9),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
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
    );
  }

  Widget _buildCurlPageWidget({
    required _ReaderThemeColors colors,
    required int pageIndex,
    required Size pageSize,
    required EdgeInsets padding,
  }) {
    final pages = _pagedPages;
    if (pageIndex < 0 || pageIndex >= pages.length) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: pageSize.width,
      height: pageSize.height,
      child: DecoratedBox(
        decoration: _buildReaderBackgroundDecoration(colors),
        child: Column(
          children: [
            SelectionContainer.disabled(
              child: _buildPinnedChapterHeader(colors),
            ),
            Expanded(
              child: Padding(
                padding: padding,
                child: _buildPagedPage(colors: colors, page: pages[pageIndex]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomCurlPageStack({
    required _ReaderThemeColors colors,
    required int pageCount,
    required int safeIndex,
    required Size pagedSize,
    required EdgeInsets contentPadding,
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
        pageSize: pagedSize,
        padding: contentPadding,
      );
    }

    final targetPage = SelectionContainer.disabled(
      child: _buildCurlPageWidget(
        colors: colors,
        pageIndex: _curlAnimationToIndex,
        pageSize: pagedSize,
        padding: contentPadding,
      ),
    );
    final currentPage = SelectionContainer.disabled(
      child: _buildCurlPageWidget(
        colors: colors,
        pageIndex: _curlAnimationFromIndex,
        pageSize: pagedSize,
        padding: contentPadding,
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
        final progress = activeProgress.clamp(0.0, 1.0);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (child != null) child,
            ClipPath(
              clipper: _CurlPageClipper(
                progress: progress,
                direction: _curlAutoDirection,
              ),
              child: currentPage,
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: _CurlOverlayPainter(
                  progress: progress,
                  direction: _curlAutoDirection,
                  backgroundColor: colors.background,
                  dividerColor: colors.divider,
                  overlayColor: colors.overlay,
                ),
              ),
            ),
          ],
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
      final index = _currentIndex;
      if (index == null || index <= 0) {
        _showChapterBoundaryHint(isFirst: true);
        return;
      }
      await _jumpTo(index - 1, initialScrollRatio: 1);
      return;
    }

    if (direction > 0 && currentIndex >= pages.length - 1) {
      final index = _currentIndex;
      if (index == null || index >= _chapters.length - 1) {
        _showChapterBoundaryHint(isFirst: false);
        return;
      }
      await _jumpTo(index + 1, initialScrollRatio: 0);
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

  void _ensurePagination({
    required double maxWidth,
    required double maxHeight,
  }) {
    if (!mounted) {
      return;
    }

    if (!_isPagedTextReaderEnabled()) {
      return;
    }

    final normalizedWidth = maxWidth.clamp(0.0, 2000.0);
    final normalizedHeight = maxHeight.clamp(0.0, 4000.0);

    if (normalizedWidth < 20 || normalizedHeight < 40) {
      return;
    }

    final signature = _buildPaginationSignature(
      maxWidth: normalizedWidth,
      maxHeight: normalizedHeight,
    );

    if (signature == _paginationSignature &&
        _pagedPages.isNotEmpty &&
        !_isPaginatingPages) {
      return;
    }

    if (signature == _paginationSignature && _isPaginatingPages) {
      return;
    }

    _paginationSignature = signature;
    final taskId = ++_paginationTaskId;
    _resetPagedTransitionState();
    _resetCurlAnimationState();

    setState(() {
      _isPaginatingPages = true;
      _pagedPages = const [];
      _currentPageIndex = 0;
    });

    unawaited(
      _paginateCurrentChapter(
        taskId: taskId,
        maxWidth: normalizedWidth,
        maxHeight: normalizedHeight,
      ),
    );
  }

  void _resetCurlAnimationState() {
    _curlAutoTurnController.stop();
    _curlTransition = const _CurlTransitionState();
  }

  void _resetPagedTransitionState() {
    _pagedTransitionController.stop();
    _pagedTransition = const _PagedPageTransitionState();
  }

  Future<List<List<_PagedSlice>>?> _paginateParagraphSlices({
    required List<String> paragraphs,
    required double maxWidth,
    required double maxHeight,
    bool Function()? shouldAbort,
  }) async {
    if (paragraphs.isEmpty || paragraphs.first.trim().isEmpty) {
      return const <List<_PagedSlice>>[];
    }

    final style = _paragraphTextStyle(
      _resolveThemeColors(_effectiveReaderThemeMode(), _settings),
    ).copyWith(color: Colors.black);
    final textScaler = MediaQuery.textScalerOf(context);

    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.start,
      textScaler: textScaler,
    );

    double measureHeight(String text) {
      painter.text = TextSpan(text: text, style: style);
      painter.layout(maxWidth: maxWidth);
      return painter.height;
    }

    int resolveFitLength(String paragraph, int start, double availableHeight) {
      if (availableHeight <= 0) {
        return 0;
      }

      final prefix = start == 0 ? '　' * _settings.paragraphIndent.round() : '';
      final remaining = paragraph.substring(start);
      final displayText = prefix + remaining;

      painter.text = TextSpan(text: displayText, style: style);
      painter.layout(maxWidth: maxWidth);

      if (painter.height <= availableHeight) {
        return remaining.length;
      }

      final lines = painter.computeLineMetrics();
      double? lastLineBottom;

      for (final line in lines) {
        final bottom = line.baseline + line.descent;
        if (bottom <= availableHeight) {
          lastLineBottom = bottom;
          continue;
        }
        break;
      }

      if (lastLineBottom == null) {
        return 0;
      }

      final offset =
          painter
              .getPositionForOffset(
                Offset(
                  (maxWidth - 1).clamp(0.0, maxWidth),
                  (lastLineBottom - 0.1).clamp(0.0, availableHeight),
                ),
              )
              .offset;
      final fit = (offset - prefix.length).clamp(0, remaining.length);
      return fit;
    }

    final pages = <List<_PagedSlice>>[];
    var currentPage = <_PagedSlice>[];
    var remainingHeight = maxHeight;

    for (
      var paragraphIndex = 0;
      paragraphIndex < paragraphs.length;
      paragraphIndex++
    ) {
      if (shouldAbort?.call() ?? false) {
        return null;
      }

      final paragraph = paragraphs[paragraphIndex];
      if (paragraph.trim().isEmpty) {
        continue;
      }

      var offset = 0;
      while (offset < paragraph.length) {
        if (shouldAbort?.call() ?? false) {
          return null;
        }

        if (currentPage.isNotEmpty) {
          if (remainingHeight <= _settings.paragraphSpacing) {
            pages.add(currentPage);
            currentPage = <_PagedSlice>[];
            remainingHeight = maxHeight;
            continue;
          }
          remainingHeight -= _settings.paragraphSpacing;
        }

        final fitLen = resolveFitLength(paragraph, offset, remainingHeight);
        if (fitLen <= 0) {
          if (currentPage.isNotEmpty) {
            pages.add(currentPage);
            currentPage = <_PagedSlice>[];
            remainingHeight = maxHeight;
            continue;
          }

          final forced = (paragraph.length - offset).clamp(1, 1);
          final end = offset + forced;
          final text = paragraph.substring(offset, end);
          remainingHeight -= measureHeight(
            offset == 0 ? _applyParagraphIndent(text) : text,
          );
          currentPage.add(
            _PagedSlice(
              paragraphIndex: paragraphIndex,
              start: offset,
              end: end,
            ),
          );
          offset = end;
          pages.add(currentPage);
          currentPage = <_PagedSlice>[];
          remainingHeight = maxHeight;
          continue;
        }

        final end = (offset + fitLen).clamp(0, paragraph.length);
        final segment = paragraph.substring(offset, end);
        remainingHeight -= measureHeight(
          offset == 0 ? _applyParagraphIndent(segment) : segment,
        );
        currentPage.add(
          _PagedSlice(paragraphIndex: paragraphIndex, start: offset, end: end),
        );

        offset = end;

        if (offset < paragraph.length) {
          pages.add(currentPage);
          currentPage = <_PagedSlice>[];
          remainingHeight = maxHeight;
        }
      }

      if (paragraphIndex % 8 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    if (currentPage.isNotEmpty) {
      pages.add(currentPage);
    }

    return pages;
  }

  String _buildPaginationSignature({
    required double maxWidth,
    required double maxHeight,
    String? chapterIdOverride,
  }) {
    return [
      chapterIdOverride ?? _chapterId,
      maxWidth.toStringAsFixed(1),
      maxHeight.toStringAsFixed(1),
      _settings.fontSize.toStringAsFixed(1),
      _settings.lineHeight.toStringAsFixed(2),
      _settings.bodyMarginTop.toStringAsFixed(1),
      _settings.bodyMarginBottom.toStringAsFixed(1),
      _settings.bodyMarginLeft.toStringAsFixed(1),
      _settings.bodyMarginRight.toStringAsFixed(1),
      _settings.paragraphSpacing.toStringAsFixed(1),
      _settings.paragraphIndent.toStringAsFixed(1),
      _settings.letterSpacing.toStringAsFixed(3),
      _settings.fontWeightLevel.name,
      _settings.fontSource.name,
      _settings.fontFamilyKey ?? '',
    ].join('|');
  }

  Future<void> _paginateCurrentChapter({
    required int taskId,
    required double maxWidth,
    required double maxHeight,
  }) async {
    final paragraphs =
        _paragraphs.isEmpty ? <String>[_content.trim()] : _paragraphs;
    final pages = await _paginateParagraphSlices(
      paragraphs: paragraphs,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      shouldAbort: () => !mounted || taskId != _paginationTaskId,
    );
    if (pages == null) {
      return;
    }

    if (pages.isEmpty) {
      if (!mounted || taskId != _paginationTaskId) {
        return;
      }
      setState(() {
        _isPaginatingPages = false;
        _pagedPages = const [];
        _resetCurlAnimationState();
      });
      return;
    }

    if (!mounted || taskId != _paginationTaskId) {
      return;
    }

    var targetIndex = 0;
    final pendingRatio = _pendingPageRestoreRatio;
    if (pendingRatio != null && pages.isNotEmpty) {
      targetIndex = (pendingRatio.clamp(0.0, 1.0) * (pages.length - 1))
          .round()
          .clamp(0, pages.length - 1);
    }

    setState(() {
      _isPaginatingPages = false;
      _pagedPages = pages;
      _pendingPageRestoreRatio = null;
      _currentPageIndex = targetIndex;
    });

    _scheduleProgressSave();
  }

  Widget _buildReaderStateCard({
    required _ReaderThemeColors colors,
    required String title,
    required String message,
    required Widget icon,
    Widget? action,
  }) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: colors.overlay.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(color: colors.text, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(color: colors.meta),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 12), action],
          ],
        ),
      ),
    );
  }

  Widget _buildTapAwareBody({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gestureInsets = MediaQuery.systemGestureInsetsOf(context);
        final enableSwipeTurn = _isSwipePaginationEnabled();
        final enableCurlPreview =
            enableSwipeTurn &&
            _effectivePageAnimationStyle() == ReaderPageAnimationStyle.curl;
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
                _isMangaChapter
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
      unawaited(_goToNextPage(viewportSize.height));
      return;
    }

    if (isRightTurn && !isLeftTurn) {
      unawaited(_goToPreviousPage(viewportSize.height));
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
    return _typographyResolver.resolveBodyStyle(
      settings: _settings,
      color: colors.text,
    );
  }

  String _applyParagraphIndent(String paragraph) {
    final indentCount = _paragraphIndentLength();
    if (indentCount <= 0) {
      return paragraph;
    }

    return '${'　' * indentCount}$paragraph';
  }

  List<String> _splitParagraphs(String content) {
    final normalized = content
        .replaceAll(r'\r\n', '\n')
        .replaceAll(r'\n', '\n')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    // Treat any explicit line break as paragraph boundary so indentation is
    // consistently applied even when upstream content uses single '\n'.
    final canonicalParagraphBreaks = normalized.replaceAll(
      RegExp(r'\n+'),
      '\n\n',
    );

    return canonicalParagraphBreaks
        .split(RegExp(r'\n{2,}'))
        .map((paragraph) => paragraph.trim())
        .where((paragraph) => paragraph.isNotEmpty)
        .toList(growable: false);
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
      _showMessage('当前书籍不支持缓存。');
      return;
    }

    final total = _chapters.length;
    final startIndex = (_currentIndex ?? 0).clamp(0, max(0, total - 1)).toInt();
    final endIndex = min(total - 1, startIndex + 49);

    await showChapterCacheFlow(
      context: context,
      bookId: _currentBookId,
      sourceId: sourceId,
      chapters: _chapters,
      initialStartIndex: startIndex,
      initialEndIndex: endIndex,
      entryPoint: ChapterCacheEntryPoint.reader,
      bookTitle: _bookTitle,
    );
  }

  Future<void> _showSwitchSourceSheet() async {
    if (_isSwitchSourceLoading) {
      return;
    }
    if (!_canSwitchSource) {
      _showMessage('当前书籍暂不支持换源。');
      return;
    }

    final currentSourceId = _sourceId?.trim();
    final currentDetailUrl = _detailUrl?.trim();
    if (currentSourceId == null ||
        currentSourceId.isEmpty ||
        currentDetailUrl == null ||
        currentDetailUrl.isEmpty) {
      _showMessage('缺少当前书源信息，暂时无法换源。');
      return;
    }

    final keyword = await _resolveSwitchSourceSearchKeyword(
      currentSourceId: currentSourceId,
      currentDetailUrl: currentDetailUrl,
    );
    if (!mounted) {
      return;
    }
    if (keyword == null) {
      _showMessage('当前书名为空或仍在加载，暂时无法换源。');
      return;
    }

    _SwitchSourceScope scope;
    try {
      scope = await _buildSwitchSourceScope(currentSourceId: currentSourceId);
      if (scope.sourceIds.isEmpty) {
        _showMessage('暂无可切换的同类型书源。');
        return;
      }
    } on AppException catch (error) {
      _showMessage('查找可切换书源失败：${error.briefMessage}');
      return;
    } catch (_) {
      _showMessage('查找可切换书源失败，请稍后重试。');
      return;
    }

    final scoreStore = await _loadSwitchSourceScoreStoreSafely();

    if (!mounted) {
      return;
    }

    const scoreRankingEnabled = true;
    final lookupStateNotifier = ValueNotifier<SwitchSourceLookupState>(
      SwitchSourceLookupState.loading(
        sourceCount: scope.sourceIds.length,
        scoreRankingEnabled: scoreRankingEnabled,
      ),
    );
    final cancellationToken = SearchCancellationToken();
    _cancelActiveSwitchSourceSearch();
    _activeSwitchSourceCancellationToken = cancellationToken;

    setState(() {
      _isSwitchSourceLoading = true;
    });

    final searchFuture = _loadSwitchSourceCandidatesProgressively(
      keyword: keyword,
      scope: scope,
      currentSourceId: currentSourceId,
      lookupStateNotifier: lookupStateNotifier,
      cancellationToken: cancellationToken,
      scoreStore: scoreStore,
      scoreRankingEnabled: scoreRankingEnabled,
    );

    SwitchSourceCandidate? selected;
    try {
      if (mounted) {
        selected = await _showSwitchSourceCandidateSheet(
          lookupStateNotifier,
          scoreStore: scoreStore,
          scoreRankingEnabled: scoreRankingEnabled,
        );
      }
    } finally {
      cancellationToken.cancel();
      if (identical(_activeSwitchSourceCancellationToken, cancellationToken)) {
        _activeSwitchSourceCancellationToken = null;
      }
      unawaited(searchFuture.whenComplete(lookupStateNotifier.dispose));
      if (mounted) {
        setState(() {
          _isSwitchSourceLoading = false;
        });
      }
    }

    if (selected == null || !mounted) {
      _scheduleAutoReadResume();
      return;
    }

    await _applySwitchSourceCandidate(selected);
  }

  Future<_SwitchSourceScope> _buildSwitchSourceScope({
    required String currentSourceId,
  }) async {
    final sources = await AppDatabase.instance.getAllSources();
    SourceDefinition? currentSource;
    for (final source in sources) {
      if (source.id == currentSourceId) {
        currentSource = source;
        break;
      }
    }
    final isMangaType = currentSource?.isMangaSource ?? _isMangaChapter;
    final sourceIds = sources
        .where(
          (source) =>
              source.enabled &&
              source.id != currentSourceId &&
              source.isMangaSource == isMangaType,
        )
        .map((source) => source.id)
        .toList(growable: false);

    return _SwitchSourceScope(
      sourceIds: sourceIds,
      contentMode:
          isMangaType ? SearchContentMode.manga : SearchContentMode.novel,
    );
  }

  Future<void> _loadSwitchSourceCandidatesProgressively({
    required String keyword,
    required _SwitchSourceScope scope,
    required String currentSourceId,
    required ValueNotifier<SwitchSourceLookupState> lookupStateNotifier,
    required SearchCancellationToken cancellationToken,
    required SourceSwitchScoreStore scoreStore,
    required bool scoreRankingEnabled,
  }) async {
    try {
      final hitCountBySource = await _loadSwitchSourceHitCountsSafely(
        title: keyword,
        author: _bookAuthor,
      );
      final report = await _switchSourceSearchService.search(
        keyword: keyword,
        pageSize: 16,
        contentMode: scope.contentMode,
        sourceIds: scope.sourceIds,
        cancellationToken: cancellationToken,
        onProgress: (progress) {
          if (cancellationToken.isCancelled) {
            return;
          }

          final candidates = _buildSwitchSourceCandidates(
            books: progress.books,
            sourceNames: progress.sourceNames,
            currentSourceId: currentSourceId,
            currentChapterCount: _chapters.length,
            targetTitle: keyword,
            targetAuthor: _bookAuthor,
            hitCountBySource: hitCountBySource,
            scoreStore: scoreStore,
            scoreRankingEnabled: scoreRankingEnabled,
          );

          lookupStateNotifier.value = SwitchSourceLookupState(
            isLoading: true,
            sourceCount: progress.sourceCount,
            processedSourceCount: progress.processedSourceCount,
            candidates: candidates,
            errorText: null,
            scoreRankingEnabled: scoreRankingEnabled,
          );
        },
      );

      if (cancellationToken.isCancelled) {
        return;
      }

      final candidates = _buildSwitchSourceCandidates(
        books: report.books,
        sourceNames: report.sourceNames,
        currentSourceId: currentSourceId,
        currentChapterCount: _chapters.length,
        targetTitle: keyword,
        targetAuthor: _bookAuthor,
        hitCountBySource: hitCountBySource,
        scoreStore: scoreStore,
        scoreRankingEnabled: scoreRankingEnabled,
      );
      lookupStateNotifier.value = SwitchSourceLookupState(
        isLoading: false,
        sourceCount: report.sourceCount,
        processedSourceCount: report.processedSourceCount,
        candidates: candidates,
        errorText: candidates.isEmpty ? '没有检索到可切换书源，请稍后重试。' : null,
        scoreRankingEnabled: scoreRankingEnabled,
      );
    } on AppException catch (error) {
      if (cancellationToken.isCancelled) {
        return;
      }
      lookupStateNotifier.value = SwitchSourceLookupState(
        isLoading: false,
        sourceCount: scope.sourceIds.length,
        processedSourceCount: 0,
        candidates: const <SwitchSourceCandidate>[],
        errorText: '查找可切换书源失败：${error.briefMessage}',
        scoreRankingEnabled: scoreRankingEnabled,
      );
    } catch (_) {
      if (cancellationToken.isCancelled) {
        return;
      }
      lookupStateNotifier.value = SwitchSourceLookupState(
        isLoading: false,
        sourceCount: scope.sourceIds.length,
        processedSourceCount: 0,
        candidates: const <SwitchSourceCandidate>[],
        errorText: '查找可切换书源失败，请稍后重试。',
        scoreRankingEnabled: scoreRankingEnabled,
      );
    }
  }

  Future<SourceSwitchScoreStore> _loadSwitchSourceScoreStoreSafely() async {
    try {
      return await _switchSourceScoreService.loadStore();
    } catch (_) {
      return SourceSwitchScoreStore(
        sourceScores: <String, int>{},
        bookScores: <String, int>{},
      );
    }
  }

  Future<Map<String, int>> _loadSwitchSourceHitCountsSafely({
    required String title,
    required String? author,
  }) async {
    try {
      return await _searchHitCacheService.loadSourceHitCounts(
        title: title,
        author: author,
      );
    } catch (_) {
      return <String, int>{};
    }
  }

  List<SwitchSourceCandidate> _buildSwitchSourceCandidates({
    required List<Book> books,
    required Map<String, String> sourceNames,
    required String currentSourceId,
    required int currentChapterCount,
    required String targetTitle,
    required String? targetAuthor,
    required Map<String, int> hitCountBySource,
    required SourceSwitchScoreStore scoreStore,
    required bool scoreRankingEnabled,
  }) {
    return buildSwitchSourceCandidates(
      books: books,
      sourceNames: sourceNames,
      currentSourceId: currentSourceId,
      currentChapterCount: currentChapterCount,
      targetTitle: targetTitle,
      targetAuthor: targetAuthor,
      hitCountBySource: hitCountBySource,
      scoreStore: scoreStore,
      scoreRankingEnabled: scoreRankingEnabled,
      buildBookScoreKey: _switchSourceScoreService.buildBookScoreKey,
      lagTolerance: _kSwitchSourceLagTolerance,
      hitCountCap: _kSwitchSourceHitCountCap,
      hitCountWeight: _kSwitchSourceHitCountWeight,
      candidateLimit: _kSwitchSourceCandidateLimit,
    );
  }

  Future<String?> _resolveSwitchSourceSearchKeyword({
    required String currentSourceId,
    required String currentDetailUrl,
  }) async {
    final currentTitle = _bookTitle.trim();
    if (_isSwitchSourceBookTitleUsable(currentTitle)) {
      return currentTitle;
    }

    final fallbackTitles = <String>[
      widget.chapterTitle ?? '',
      _chapterTitle ?? '',
    ];
    for (final candidate in fallbackTitles) {
      final normalized = candidate.trim();
      if (!_isSwitchSourceBookTitleUsable(normalized)) {
        continue;
      }
      if (mounted && normalized != _bookTitle) {
        setState(() {
          _bookTitle = normalized;
        });
      } else {
        _bookTitle = normalized;
      }
      return normalized;
    }

    try {
      final detailProvider = _requireContentProvider(
        sourceId: currentSourceId,
        stage: ErrorStage.detail,
      );
      final detailResult = await detailProvider.loadDetail(
        sourceId: currentSourceId,
        bookId: _currentBookId,
        detailUrl: currentDetailUrl,
        fallbackTitle: currentTitle.isEmpty ? null : currentTitle,
      );
      final refreshedTitle = detailResult.detail.title.trim();
      if (_isSwitchSourceBookTitleUsable(refreshedTitle)) {
        if (mounted && refreshedTitle != _bookTitle) {
          setState(() {
            _bookTitle = refreshedTitle;
          });
        } else {
          _bookTitle = refreshedTitle;
        }
        return refreshedTitle;
      }
    } catch (_) {
      // Fall through to null and let caller show user-facing message.
    }

    return null;
  }

  bool _isSwitchSourceBookTitleUsable(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    return !_looksLikeSwitchSourceChapterTitle(trimmed);
  }

  bool _looksLikeSwitchSourceChapterTitle(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (_kSwitchSourceChapterPattern.hasMatch(trimmed)) {
      return true;
    }
    final lower = trimmed.toLowerCase();
    return _kSwitchSourceChapterEnglishPattern.hasMatch(lower);
  }

  Future<SwitchSourceCandidate?> _showSwitchSourceCandidateSheet(
    ValueNotifier<SwitchSourceLookupState> lookupStateNotifier, {
    required SourceSwitchScoreStore scoreStore,
    required bool scoreRankingEnabled,
  }) async {
    _stopAutoReadSession();
    final shouldRestoreOverlay = _showOverlayControls;
    if (shouldRestoreOverlay) {
      _hideOverlayControls(resumeAutoRead: false, syncSystemUi: false);
    }

    final readerModalTheme = _readerModalTheme();
    final selected = await showSwitchSourceCandidateSheet(
      context: context,
      lookupStateNotifier: lookupStateNotifier,
      currentTitle: _bookTitle.trim(),
      currentChapterCount: _chapters.length,
      themeData: readerModalTheme,
      heightFactor: _adaptiveReaderSheetHeightFactor(
        context,
        compact: 0.92,
        regular: 0.88,
        large: 0.84,
      ),
      bottomInset: _bottomSafeInset(context),
      onScoreAction: (candidate, action) {
        return _applySwitchSourceScoreAction(
          candidate: candidate,
          action: action,
          lookupStateNotifier: lookupStateNotifier,
          scoreStore: scoreStore,
          scoreRankingEnabled: scoreRankingEnabled,
        );
      },
    );

    if (shouldRestoreOverlay && mounted) {
      _setOverlayControlsVisibility(true);
    }

    return selected;
  }

  Future<void> _applySwitchSourceScoreAction({
    required SwitchSourceCandidate candidate,
    required SwitchSourceScoreAction action,
    required ValueNotifier<SwitchSourceLookupState> lookupStateNotifier,
    required SourceSwitchScoreStore scoreStore,
    required bool scoreRankingEnabled,
  }) async {
    try {
      final update = switch (action) {
        SwitchSourceScoreAction.upvote => _switchSourceScoreService
            .adjustBookScore(
              sourceId: candidate.book.sourceId,
              title: candidate.book.title,
              author: candidate.book.author,
              delta: _kSwitchSourceScoreStep,
            ),
        SwitchSourceScoreAction.downvote => _switchSourceScoreService
            .adjustBookScore(
              sourceId: candidate.book.sourceId,
              title: candidate.book.title,
              author: candidate.book.author,
              delta: -_kSwitchSourceScoreStep,
            ),
        SwitchSourceScoreAction.reset => _switchSourceScoreService
            .resetBookScore(
              sourceId: candidate.book.sourceId,
              title: candidate.book.title,
              author: candidate.book.author,
            ),
      };
      final resolved = await update;

      if (resolved.sourceScore == 0) {
        scoreStore.sourceScores.remove(candidate.book.sourceId);
      } else {
        scoreStore.sourceScores[candidate.book.sourceId] = resolved.sourceScore;
      }
      if (resolved.bookScore == 0) {
        scoreStore.bookScores.remove(resolved.bookScoreKey);
      } else {
        scoreStore.bookScores[resolved.bookScoreKey] = resolved.bookScore;
      }

      final current = lookupStateNotifier.value;
      final nextCandidates = current.candidates
          .map(
            (item) => _rebuildSwitchSourceCandidateScore(
              item,
              scoreStore: scoreStore,
              scoreRankingEnabled: scoreRankingEnabled,
            ),
          )
          .toList(growable: false);
      lookupStateNotifier.value = current.copyWith(
        candidates: sortSwitchSourceCandidates(nextCandidates),
      );

      if (!mounted) {
        return;
      }

      final actionLabel = switch (action) {
        SwitchSourceScoreAction.upvote => '已推荐',
        SwitchSourceScoreAction.downvote => '已降权',
        SwitchSourceScoreAction.reset => '已重置',
      };
      _showMessage(
        '$actionLabel ${candidate.sourceName}（源评 ${_formatSignedScore(resolved.sourceScore)}，书评 ${_formatSignedScore(resolved.bookScore)}）',
      );
    } catch (_) {
      _showMessage('更新评分失败，请稍后重试。');
    }
  }

  SwitchSourceCandidate _rebuildSwitchSourceCandidateScore(
    SwitchSourceCandidate candidate, {
    required SourceSwitchScoreStore scoreStore,
    required bool scoreRankingEnabled,
  }) {
    return rebuildSwitchSourceCandidateScore(
      candidate,
      scoreStore: scoreStore,
      scoreRankingEnabled: scoreRankingEnabled,
      buildBookScoreKey: _switchSourceScoreService.buildBookScoreKey,
      hitCountCap: _kSwitchSourceHitCountCap,
      hitCountWeight: _kSwitchSourceHitCountWeight,
    );
  }

  String _formatSignedScore(int score) {
    if (score > 0) {
      return '+$score';
    }
    return '$score';
  }

  void _cancelActiveSwitchSourceSearch() {
    _activeSwitchSourceCancellationToken?.cancel();
    _activeSwitchSourceCancellationToken = null;
  }

  bool _canAutoSwitchSourceOnFailure() {
    if (!_canSwitchSource) {
      return false;
    }
    if (!_autoSwitchSourceOnFailureEnabled) {
      return false;
    }
    if (_isAutoSwitchingSource || _isSwitchSourceLoading) {
      return false;
    }
    final sourceId = _sourceId?.trim();
    final detailUrl = _detailUrl?.trim();
    if (sourceId == null ||
        sourceId.isEmpty ||
        detailUrl == null ||
        detailUrl.isEmpty) {
      return false;
    }
    return true;
  }

  Future<bool> _tryAutoSwitchSourceOnFailure() async {
    if (!_canAutoSwitchSourceOnFailure() || !mounted) {
      return false;
    }

    final currentSourceId = _sourceId!.trim();
    final currentDetailUrl = _detailUrl!.trim();

    final keyword = await _resolveSwitchSourceSearchKeyword(
      currentSourceId: currentSourceId,
      currentDetailUrl: currentDetailUrl,
    );
    if (!mounted || keyword == null || keyword.isEmpty) {
      return false;
    }

    _isAutoSwitchingSource = true;
    try {
      final scope = await _buildSwitchSourceScope(
        currentSourceId: currentSourceId,
      );
      if (scope.sourceIds.isEmpty) {
        return false;
      }

      final scoreStore = await _loadSwitchSourceScoreStoreSafely();
      final hitCountBySource = await _loadSwitchSourceHitCountsSafely(
        title: keyword,
        author: _bookAuthor,
      );
      final report = await _switchSourceSearchService.search(
        keyword: keyword,
        pageSize: 16,
        contentMode: scope.contentMode,
        sourceIds: scope.sourceIds,
      );

      final candidates = _buildSwitchSourceCandidates(
        books: report.books,
        sourceNames: report.sourceNames,
        currentSourceId: currentSourceId,
        currentChapterCount: _chapters.length,
        targetTitle: keyword,
        targetAuthor: _bookAuthor,
        hitCountBySource: hitCountBySource,
        scoreStore: scoreStore,
        scoreRankingEnabled: true,
      );
      if (candidates.isEmpty) {
        return false;
      }

      final upToDateCandidates = candidates
          .where((candidate) => !candidate.isPotentiallyOutdated)
          .toList(growable: false);
      final orderedCandidates =
          upToDateCandidates.isNotEmpty ? upToDateCandidates : candidates;

      for (final candidate in orderedCandidates.take(
        _kAutoSwitchSourceTryLimit,
      )) {
        final switched = await _applySwitchSourceCandidate(
          candidate,
          showResultMessage: false,
          promptWhenCoverageGap: false,
        );
        if (switched) {
          if (mounted) {
            _showMessage('检测到当前书源异常，已自动切换到 ${candidate.sourceName}。');
          }
          return true;
        }
      }
    } catch (_) {
      return false;
    } finally {
      _isAutoSwitchingSource = false;
    }

    return false;
  }

  Future<bool> _applySwitchSourceCandidate(
    SwitchSourceCandidate candidate, {
    bool showResultMessage = true,
    bool promptWhenCoverageGap = true,
  }) async {
    if (_isSwitchSourceLoading) {
      return false;
    }

    final snapshot = _ReaderSourceSnapshot(
      bookId: _activeBookId,
      sourceId: _sourceId,
      detailUrl: _detailUrl,
      bookTitle: _bookTitle,
      bookAuthor: _bookAuthor,
      bookCoverUrl: _bookCoverUrl,
      chapters: _chapters,
      currentIndex: _currentIndex,
      chapterId: _chapterId,
      chapterUrl: _chapterUrl,
      chapterTitle: _chapterTitle,
      errorText: _errorText,
      isInBookshelf: _isInBookshelf,
      isCurrentChapterCached: _isCurrentChapterCached,
      content: _content,
      chapterImageUrls: _chapterImageUrls,
      chapterImageHeaders: _chapterImageHeaders,
      scrollRatio: _currentScrollRatio(),
    );

    setState(() {
      _isSwitchSourceLoading = true;
    });

    try {
      final detailProvider = _requireContentProvider(
        sourceId: candidate.book.sourceId,
        stage: ErrorStage.detail,
      );
      final detailResult = await detailProvider.loadDetail(
        sourceId: candidate.book.sourceId,
        bookId: candidate.book.id,
        detailUrl: candidate.book.detailUrl,
        fallbackTitle: candidate.book.title,
        forceRefresh: true,
      );
      try {
        await _preferencesService.saveTocSnapshot(
          ReaderTocSnapshot(
            bookId: candidate.book.id.trim(),
            sourceId: candidate.book.sourceId,
            detailUrl: candidate.book.detailUrl,
            title: detailResult.detail.title,
            author: detailResult.detail.author,
            coverUrl: detailResult.detail.coverUrl,
            chapters: detailResult.chapters,
            updatedAt: DateTime.now(),
          ),
        );
      } catch (_) {
        // Ignore snapshot persistence failures during source switching.
      }

      final chapters = detailResult.chapters;
      if (chapters.isEmpty) {
        if (showResultMessage) {
          _showMessage('目标书源暂无可读章节，无法切换。');
        }
        return false;
      }
      final positionDecision = _switchSourcePositionResolver.resolve(
        currentChapters: snapshot.chapters,
        targetChapters: chapters,
        previousChapterTitle: snapshot.chapterTitle,
        previousChapterIndex: snapshot.currentIndex,
        lagTolerance: _kSwitchSourceLagTolerance,
      );

      if ((positionDecision.isBehindCurrentReading ||
              positionDecision.isSignificantlyBehind) &&
          mounted) {
        if (!promptWhenCoverageGap) {
          return false;
        }
        final shouldContinue = await _confirmSwitchSourceCoverage(
          sourceName: candidate.sourceName,
          currentChapterCount: snapshot.chapters.length,
          currentReadingChapterNo: positionDecision.currentReadingChapterNo,
          targetChapterCount: positionDecision.targetChapterCount,
          isBehindCurrentReading: positionDecision.isBehindCurrentReading,
        );
        if (!shouldContinue) {
          if (showResultMessage) {
            _showMessage('已取消切换：目标书源章节较少。');
          }
          return false;
        }
      }

      final targetIndex = positionDecision.targetIndex.clamp(
        0,
        chapters.length - 1,
      );
      final targetChapter = chapters[targetIndex];

      setState(() {
        _activeBookId = candidate.book.id.trim();
        _sourceId = candidate.book.sourceId;
        _detailUrl = candidate.book.detailUrl;
        _bookTitle = detailResult.detail.title;
        _bookAuthor = detailResult.detail.author;
        _bookCoverUrl = detailResult.detail.coverUrl;
        _chapters = chapters;
        _currentIndex = targetIndex;
        _chapterId = targetChapter.id;
        _chapterUrl = targetChapter.chapterUrl;
        _chapterTitle = targetChapter.title;
        _errorText = null;
      });

      final loaded = await _loadCurrentChapter(
        initialScrollRatio: snapshot.scrollRatio,
      );
      if (!loaded) {
        throw StateError('切换后正文加载失败。');
      }

      final previousSourceId = snapshot.sourceId?.trim() ?? '';
      final previousDetailUrl = snapshot.detailUrl?.trim() ?? '';
      var shouldMigrateBookshelf = false;
      if (previousSourceId.isNotEmpty && previousDetailUrl.isNotEmpty) {
        if (snapshot.isInBookshelf) {
          shouldMigrateBookshelf = true;
        } else {
          try {
            shouldMigrateBookshelf = await _bookshelfService.contains(
              sourceId: previousSourceId,
              detailUrl: previousDetailUrl,
            );
          } catch (_) {
            shouldMigrateBookshelf = false;
          }
        }
      }

      if (shouldMigrateBookshelf) {
        try {
          await _bookshelfService.replace(
            previousSourceId: previousSourceId,
            previousDetailUrl: previousDetailUrl,
            preserveTags: true,
            nextBook: BookshelfBook(
              bookId: _currentBookId,
              sourceId: candidate.book.sourceId,
              title:
                  _bookTitle.trim().isEmpty ? candidate.book.title : _bookTitle,
              detailUrl: candidate.book.detailUrl,
              author: _bookAuthor,
              coverUrl: _bookCoverUrl,
              addedAt: DateTime.now(),
            ),
          );
          if (mounted) {
            setState(() {
              _isInBookshelf = true;
            });
          }
        } catch (_) {
          await _refreshBookshelfState();
          if (showResultMessage) {
            _showMessage('已换源，但书架同步失败，请稍后重试。');
          }
        }
      } else {
        await _refreshBookshelfState();
      }

      if (showResultMessage) {
        _showMessage('已切换到 ${candidate.sourceName}。');
      }
      return true;
    } on AppException catch (error) {
      if (mounted) {
        _restoreSourceSnapshot(snapshot);
      }
      if (showResultMessage) {
        _showMessage('换源失败：${_toUserReadableError(error)}');
      }
      return false;
    } catch (_) {
      if (mounted) {
        _restoreSourceSnapshot(snapshot);
      }
      if (showResultMessage) {
        _showMessage('换源失败，请稍后重试。');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchSourceLoading = false;
        });
      }
    }
  }

  Future<bool> _confirmSwitchSourceCoverage({
    required String sourceName,
    required int currentChapterCount,
    required int currentReadingChapterNo,
    required int targetChapterCount,
    required bool isBehindCurrentReading,
  }) async {
    final shouldWarnByTotal =
        currentChapterCount > 0 &&
        targetChapterCount + _kSwitchSourceLagTolerance < currentChapterCount;
    final reasonText =
        isBehindCurrentReading
            ? '该书源目录无法覆盖你当前阅读章节。'
            : shouldWarnByTotal
            ? '该书源目录明显少于当前书源，可能更新较慢。'
            : '该书源章节数量存在明显差异。';
    final detailText =
        StringBuffer()
          ..writeln('当前书源：$currentChapterCount 章')
          ..writeln('当前阅读：第 $currentReadingChapterNo 章')
          ..writeln('目标书源：$targetChapterCount 章');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('切换到 $sourceName ?'),
          content: Text('$reasonText\n\n$detailText\n继续切换可能回退到较早章节。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('继续切换'),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  void _restoreSourceSnapshot(_ReaderSourceSnapshot snapshot) {
    setState(() {
      _activeBookId = snapshot.bookId;
      _sourceId = snapshot.sourceId;
      _detailUrl = snapshot.detailUrl;
      _bookTitle = snapshot.bookTitle;
      _bookAuthor = snapshot.bookAuthor;
      _bookCoverUrl = snapshot.bookCoverUrl;
      _chapters = snapshot.chapters;
      _currentIndex = snapshot.currentIndex;
      _chapterId = snapshot.chapterId;
      _chapterUrl = snapshot.chapterUrl;
      _chapterTitle = snapshot.chapterTitle;
      _errorText = snapshot.errorText;
      _isInBookshelf = snapshot.isInBookshelf;
      _isCurrentChapterCached = snapshot.isCurrentChapterCached;
      _setContent(
        snapshot.content,
        imageUrls: snapshot.chapterImageUrls,
        imageHeaders: snapshot.chapterImageHeaders,
      );
      _pendingPageRestoreRatio = snapshot.scrollRatio;
    });

    _restoreScrollPosition(snapshot.scrollRatio);
    _scheduleReadingRecordSessionStart(initialRatio: snapshot.scrollRatio);
    _scheduleAutoReadResume();
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
            final shift = _overlayControlsShiftProgress;
            final fade = _overlayControlsFadeProgress;
            return SlideTransition(
              position: AlwaysStoppedAnimation<Offset>(Offset(0, shift - 1)),
              child: Opacity(
                opacity: fade,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                if (_canCacheChapter) ...[
                                  _buildTopActionButton(
                                    icon:
                                        _isCurrentChapterCached
                                            ? Icons.cloud_done_rounded
                                            : Icons.cloud_download_outlined,
                                    tooltip:
                                        _isCurrentChapterCached
                                            ? '已缓存'
                                            : '缓存章节',
                                    onPressed: _openChapterCache,
                                    colors: colors,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (_canSwitchSource) ...[
                                  _buildTopActionButton(
                                    icon: Icons.swap_horiz_rounded,
                                    tooltip: '切换书源',
                                    onPressed:
                                        _isSwitchSourceLoading
                                            ? null
                                            : () => unawaited(
                                              _showSwitchSourceSheet(),
                                            ),
                                    loading: _isSwitchSourceLoading,
                                    colors: colors,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                _buildTopActionButton(
                                  icon:
                                      _isInBookshelf
                                          ? Icons.bookmark_added
                                          : Icons.bookmark_add_outlined,
                                  tooltip: _isInBookshelf ? '移出书架' : '加入书架',
                                  onPressed:
                                      _isShelfActionLoading
                                          ? null
                                          : _toggleBookshelf,
                                  loading: _isShelfActionLoading,
                                  colors: colors,
                                ),
                                const SizedBox(width: 6),
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
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomOverlay(_ReaderThemeColors colors) {
    final middleLabel = _isMangaChapter ? '定位' : '界面';
    final middleIcon =
        _isMangaChapter ? Icons.gps_fixed_rounded : Icons.palette_outlined;
    final trailingLabel = '设置';
    final isDarkMode = _settings.themeMode == ReaderThemeMode.dark;
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
            final shift = _overlayControlsShiftProgress;
            final fade = _overlayControlsFadeProgress;
            return SlideTransition(
              position: AlwaysStoppedAnimation<Offset>(Offset(0, 1 - shift)),
              child: Opacity(
                opacity: fade,
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
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          child: Row(
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
                                      _isMangaChapter
                                          ? _openMangaPositionSheet
                                          : () => _showSettingsSheet(
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
                                        initialTab: _ReaderSettingsTab.reading,
                                      ),
                                  colors: colors,
                                ),
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
        backgroundTone: ReaderBackgroundTone.containerHigh,
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

  Future<void> _bootstrap() async {
    _scheduleBlockingLoadingCard();
    try {
      final loadedSettings = await _preferencesService.loadSettings();
      var normalizedSettings = loadedSettings;
      var availableCustomFonts = const <ReaderCustomFontEntry>[];
      var storedCustomBackgrounds = const <String>[];

      try {
        storedCustomBackgrounds =
            await _preferencesService.loadCustomBackgroundImages();
      } catch (_) {
        storedCustomBackgrounds = const <String>[];
      }

      try {
        await _fontRegistryService.restoreRegisteredFonts();
        availableCustomFonts = await _fontRegistryService.listRegisteredFonts();
        normalizedSettings = await _fontRegistryService
            .normalizeCustomFontSettings(loadedSettings);
      } catch (_) {
        normalizedSettings = loadedSettings.copyWith(
          fontSource: ReaderFontSource.system,
          clearFontFamilyKey: true,
          clearCustomFontPath: true,
        );
      }

      var infoSettingsChanged = false;
      if (!normalizedSettings.infoShowTime &&
          !normalizedSettings.infoShowBattery &&
          !normalizedSettings.infoShowChapter &&
          !normalizedSettings.infoShowProgress) {
        normalizedSettings = normalizedSettings.copyWith(infoShowChapter: true);
        infoSettingsChanged = true;
      }
      if (!normalizedSettings.infoHeaderEnabled &&
          normalizedSettings.infoHeaderDividerEnabled) {
        normalizedSettings = normalizedSettings.copyWith(
          infoHeaderDividerEnabled: false,
        );
        infoSettingsChanged = true;
      }
      if (!normalizedSettings.infoFooterEnabled &&
          normalizedSettings.infoFooterDividerEnabled) {
        normalizedSettings = normalizedSettings.copyWith(
          infoFooterDividerEnabled: false,
        );
        infoSettingsChanged = true;
      }

      final fontSettingsChanged =
          normalizedSettings.fontSource != loadedSettings.fontSource ||
          normalizedSettings.fontFamilyKey != loadedSettings.fontFamilyKey ||
          normalizedSettings.customFontPath != loadedSettings.customFontPath;
      if (fontSettingsChanged || infoSettingsChanged) {
        await _preferencesService.saveSettings(normalizedSettings);
      }

      final bootSettings = normalizedSettings.copyWith(autoReadEnabled: false);
      if (mounted) {
        setState(() {
          _settings = bootSettings;
          _customFonts = availableCustomFonts;
          _customBackgroundImages = storedCustomBackgrounds;
        });
        unawaited(_syncVolumeKeyPageInterception());
      } else {
        _settings = bootSettings;
        _customFonts = availableCustomFonts;
        _customBackgroundImages = storedCustomBackgrounds;
      }
      try {
        _autoSwitchSourceOnFailureEnabled =
            await _systemSettingsService.loadAutoSwitchSourceOnFailureEnabled();
      } catch (_) {
        _autoSwitchSourceOnFailureEnabled = false;
      }
      try {
        _readingRecordEnabled =
            await _systemSettingsService.loadReadRecordEnabled();
      } catch (_) {
        _readingRecordEnabled = true;
      }

      final progress = await _preferencesService.loadProgress(_currentBookId);
      _bootstrapProgress = progress;

      if (progress != null) {
        _applyProgressFallback(progress);
      }

      _applyLocalSchemeFallback();
      final hydratedTocSnapshot = await _tryHydrateTocSnapshot();
      await _tryHydrateVisibleContentFromCache();

      if (hydratedTocSnapshot) {
        await _refreshBookshelfState();
        if (_hasVisibleReaderContent) {
          await _consumePendingBookmarkJump();
          return;
        }

        final loaded = await _loadCurrentChapter(
          initialScrollRatio: _consumeBootstrapScrollRatio(),
        );
        if (loaded) {
          await _consumePendingBookmarkJump();
        }
        return;
      }

      if (_isMissingCriticalParams) {
        if (!mounted) {
          return;
        }
        setState(() {
          _errorText = '缺少 sourceId/detailUrl，无法加载正文。';
          _isBootstrapping = false;
        });
        return;
      }

      final detailProvider = _requireContentProvider(
        sourceId: _sourceId,
        stage: ErrorStage.detail,
      );

      final detailResult = await detailProvider.loadDetail(
        sourceId: _sourceId!,
        bookId: _currentBookId,
        detailUrl: _detailUrl!,
        fallbackTitle: _chapterTitle,
      );
      await _persistTocSnapshot(detailResult);

      _bookTitle = detailResult.detail.title;
      _bookAuthor = detailResult.detail.author;
      _bookCoverUrl = detailResult.detail.coverUrl;
      _chapters = detailResult.chapters;
      _currentIndex = _resolveCurrentIndex(_chapters);

      if (_currentIndex != null) {
        final current = _chapters[_currentIndex!];
        _chapterId = current.id;
        _chapterUrl = current.chapterUrl;
        _chapterTitle = current.title;
      }

      await _refreshBookshelfState();
      final loaded = await _loadCurrentChapter(
        initialScrollRatio: _consumeBootstrapScrollRatio(),
      );
      if (loaded) {
        await _consumePendingBookmarkJump();
      }
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      final readableError = _toUserReadableError(error);
      _recordReaderFailure(message: readableError, errorCode: error.code);
      setState(() {
        _errorText = readableError;
      });
      _maybePromptSwitchSourceForMissingSource(error.code);
    } catch (_) {
      if (!mounted) {
        return;
      }
      const fallbackError = '阅读器初始化失败。';
      _recordReaderFailure(message: fallbackError);
      setState(() {
        _errorText = fallbackError;
      });
    } finally {
      _clearDelayedLoadingUi();
      if (mounted) {
        setState(() {
          _isBootstrapping = false;
        });
        _scheduleReadingRecordSessionStart(initialRatio: _currentScrollRatio());
        _reconcileAutoRead(restart: true);
      }
    }
  }

  void _scheduleReadingRecordSessionStart({double? initialRatio}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isBootstrapping || _isLoadingContent) {
        return;
      }
      _maybeStartReadingRecordSession(
        initialRatio: initialRatio ?? _currentScrollRatio(),
      );
    });
  }

  String _toUserReadableError(AppException error) {
    final message = error.briefMessage;
    if (_isLocalContent) {
      if (message.contains('本地文件不存在')) {
        return '本地文件不存在，请确认文件是否存在或重新导入。';
      }
      if (message.contains('未找到本地书籍')) {
        return '未找到本地书籍，请确认文件是否存在或重新导入。';
      }
      if (message.contains('索引失败')) {
        return '本地书籍索引失败，请在详情页重新索引。';
      }
      if (message.contains('文本文件为空') || message.contains('文本内容为空')) {
        return '本地文件内容为空，无法阅读。';
      }
      if (message.contains('没有可用章节') ||
          message.contains('章节为空') ||
          message.contains('解析完成但没有可用章节') ||
          message.contains('未解析出有效章节') ||
          message.contains('未找到本地章节内容')) {
        return '未解析到可读章节，请在详情页重新索引。';
      }
      if (message.contains('暂不支持')) {
        return '本地文件格式不受支持，请重新导入。';
      }
      if (message.contains('本地书籍信息缺失') || message.contains('bookId')) {
        return '本地书籍信息缺失，请重新进入或重新导入。';
      }
      return '本地书籍加载失败，请在详情页重新索引或重新导入。';
    }

    return switch (error.code) {
      ErrorCode.network when message.contains('状态码：403') =>
        '章节被源站拦截（403），请在书源配置 Referer/Origin/User-Agent 后重试。',
      ErrorCode.network when message.contains('状态码：404') =>
        '章节地址已失效（404），请刷新目录后重试。',
      ErrorCode.network when message.contains('超时') => '请求超时，请稍后重试或切换书源。',
      ErrorCode.network => '网络请求失败，请检查网络或更换书源。',
      ErrorCode.validation
          when message.contains('正文规则') || message.contains('ruleContent') =>
        '书源缺少正文规则（ruleContent），无法读取该章节。',
      ErrorCode.validation => '书源规则配置不完整，无法继续阅读。',
      ErrorCode.ruleParse => '书源规则语法错误，正文解析失败。',
      ErrorCode.ruleMatchEmpty when message.contains('解析为空') =>
        '正文规则未命中，当前章节暂无可读内容。',
      ErrorCode.ruleMatchEmpty => '当前章节没有可读取内容，请切换章节或书源。',
      ErrorCode.decode => '正文解析失败，可能是编码或数据格式不兼容。',
      ErrorCode.unknownSource => '书源不存在或已被删除。',
      ErrorCode.unknown => '加载失败，请稍后重试。',
    };
  }

  void _setContent(
    String content, {
    List<String> imageUrls = const [],
    Map<String, String> imageHeaders = const {},
    List<String>? precomputedParagraphs,
    List<List<_PagedSlice>>? precomputedPagedPages,
    int? precomputedCurrentPageIndex,
    String? precomputedPaginationSignature,
  }) {
    _stopAutoRead();
    _disposeMangaTransformControllers();
    _content = content;
    _chapterImageUrls = List.unmodifiable(imageUrls);
    _chapterImageHeaders = Map.unmodifiable(imageHeaders);
    _mangaImageRetryNonce.clear();
    _mangaPageIndex = 0;
    _isTextSelectionActive = false;
    _selectionRange = null;
    _selectionStatus = SelectionStatus.none;
    _selectionStartOffset = 0;
    _selectionEndOffset = 0;
    _selectedSnippet = '';
    _hideBookmarkToolbar();
    _chapterBookmarks = const [];
    _bookmarkRangesByParagraph = const <int, List<_BookmarkRange>>{};
    if (_mangaPageController.hasClients) {
      _mangaPageController.jumpToPage(0);
    }
    _paragraphs = precomputedParagraphs ?? _splitParagraphs(content);
    if (precomputedPagedPages != null && precomputedPagedPages.isNotEmpty) {
      _pagedPages = List<List<_PagedSlice>>.unmodifiable(
        precomputedPagedPages
            .map((page) => List<_PagedSlice>.unmodifiable(page))
            .toList(growable: false),
      );
      _currentPageIndex = precomputedCurrentPageIndex ?? 0;
      _paginationSignature = precomputedPaginationSignature;
    } else {
      _pagedPages = const [];
      _currentPageIndex = 0;
      _paginationSignature = null;
    }
    _isPaginatingPages = false;
    _resetCatalogSearchCache();
    _resetPagedTransitionState();
    _resetCurlAnimationState();
    unawaited(_refreshChapterBookmarks());
  }

  GlobalKey _continuousTextChapterKey(_ContinuousTextChapter chapter) {
    final identity =
        chapter.chapterUrl.trim().isNotEmpty
            ? chapter.chapterUrl.trim()
            : '${chapter.chapterIndex}:${chapter.chapterId}';
    return _continuousTextChapterKeys.putIfAbsent(identity, () => GlobalKey());
  }

  bool _shouldBuildContinuousTextFlowFor(ChapterContentResult result) {
    return _shouldUseContinuousTextFlow &&
        result.imageUrls.isEmpty &&
        result.content.trim().isNotEmpty;
  }

  _ContinuousTextChapter _buildContinuousTextChapter({
    required Chapter chapter,
    required int chapterIndex,
    required _ChapterLoadSnapshot snapshot,
  }) {
    final displayTitle =
        snapshot.result.displayChapterTitle?.trim().isNotEmpty == true
            ? snapshot.result.displayChapterTitle!.trim()
            : chapter.title.trim();
    final paragraphs = _splitParagraphs(snapshot.result.content);
    final effectiveParagraphs =
        paragraphs.isEmpty && snapshot.result.content.trim().isNotEmpty
            ? <String>[snapshot.result.content]
            : paragraphs;

    return _ContinuousTextChapter(
      chapterId: chapter.id,
      chapterUrl: chapter.chapterUrl.trim(),
      chapterTitle: chapter.title.trim(),
      displayTitle: displayTitle,
      chapterIndex: chapterIndex,
      content: snapshot.result.content,
      paragraphs: List<String>.unmodifiable(effectiveParagraphs),
      isCached: snapshot.isCached,
      effectiveReaderReplaceRules: List<ReaderReplaceRule>.unmodifiable(
        snapshot.result.effectiveReaderReplaceRules,
      ),
    );
  }

  void _replaceContinuousTextFlowWithCurrentChapter({
    required Chapter chapter,
    required int chapterIndex,
    required _ChapterLoadSnapshot snapshot,
  }) {
    if (!_shouldBuildContinuousTextFlowFor(snapshot.result)) {
      _continuousTextChapters = const <_ContinuousTextChapter>[];
      return;
    }

    _continuousTextChapters = <_ContinuousTextChapter>[
      _buildContinuousTextChapter(
        chapter: chapter,
        chapterIndex: chapterIndex,
        snapshot: snapshot,
      ),
    ];
  }

  Future<_ContinuousTextChapter?> _loadContinuousTextChapter(
    int chapterIndex,
  ) async {
    if (chapterIndex < 0 || chapterIndex >= _chapters.length) {
      return null;
    }

    final chapter = _chapters[chapterIndex];
    if (chapterIndex == _currentIndex &&
        _chapterImageUrls.isEmpty &&
        _content.trim().isNotEmpty) {
      final currentParagraphs =
          _paragraphs.isEmpty ? <String>[_content] : _paragraphs;
      return _ContinuousTextChapter(
        chapterId: _chapterId,
        chapterUrl: (_chapterUrl ?? '').trim(),
        chapterTitle: chapter.title.trim(),
        displayTitle: (_chapterTitle ?? chapter.title).trim(),
        chapterIndex: chapterIndex,
        content: _content,
        paragraphs: List<String>.unmodifiable(currentParagraphs),
        isCached: _isCurrentChapterCached,
        effectiveReaderReplaceRules: List<ReaderReplaceRule>.unmodifiable(
          _effectiveReaderReplaceRules,
        ),
      );
    }

    final chapterUrl = chapter.chapterUrl.trim();
    if (chapterUrl.isEmpty) {
      return null;
    }

    final snapshot = await _fetchChapterContentSnapshot(
      sourceId: (_sourceId ?? '').trim(),
      chapterId: chapter.id,
      chapterUrl: chapterUrl,
      chapterTitle: chapter.title,
      chapterIndex: chapterIndex,
    );
    if (!_shouldBuildContinuousTextFlowFor(snapshot.result)) {
      return null;
    }
    return _buildContinuousTextChapter(
      chapter: chapter,
      chapterIndex: chapterIndex,
      snapshot: snapshot,
    );
  }

  Future<void> _appendNextContinuousTextChapter() async {
    if (_isScrollEdgeAdvancingChapter ||
        !_shouldUseContinuousTextFlow ||
        _continuousTextChapters.isEmpty) {
      return;
    }

    final targetIndex = _continuousTextChapters.last.chapterIndex + 1;
    if (targetIndex >= _chapters.length) {
      return;
    }

    _isScrollEdgeAdvancingChapter = true;
    try {
      final chapter = await _loadContinuousTextChapter(targetIndex);
      if (!mounted || chapter == null) {
        return;
      }
      if (_continuousTextChapters.any(
        (item) => item.chapterIndex == chapter.chapterIndex,
      )) {
        return;
      }
      setState(() {
        _continuousTextChapters = List<_ContinuousTextChapter>.unmodifiable(
          <_ContinuousTextChapter>[..._continuousTextChapters, chapter],
        );
      });
    } finally {
      _isScrollEdgeAdvancingChapter = false;
    }
  }

  Future<void> _prependPreviousContinuousTextChapter() async {
    if (_isScrollEdgeAdvancingChapter ||
        !_shouldUseContinuousTextFlow ||
        _continuousTextChapters.isEmpty) {
      return;
    }

    final targetIndex = _continuousTextChapters.first.chapterIndex - 1;
    if (targetIndex < 0) {
      return;
    }

    _isScrollEdgeAdvancingChapter = true;
    try {
      final chapter = await _loadContinuousTextChapter(targetIndex);
      if (!mounted || chapter == null) {
        return;
      }
      if (_continuousTextChapters.any(
        (item) => item.chapterIndex == chapter.chapterIndex,
      )) {
        return;
      }
      setState(() {
        _continuousTextChapters = List<_ContinuousTextChapter>.unmodifiable(
          <_ContinuousTextChapter>[chapter, ..._continuousTextChapters],
        );
      });
    } finally {
      _isScrollEdgeAdvancingChapter = false;
    }
  }

  bool _isContinuousTextChapterActive(_ContinuousTextChapter chapter) {
    if (_currentIndex != null && chapter.chapterIndex == _currentIndex) {
      return true;
    }
    final chapterUrl = (_chapterUrl ?? '').trim();
    if (chapterUrl.isNotEmpty && chapter.chapterUrl == chapterUrl) {
      return true;
    }
    return chapter.chapterId.trim() == _chapterId.trim();
  }

  _ContinuousTextChapter? _findCurrentContinuousTextChapter() {
    for (final chapter in _continuousTextChapters) {
      if (_isContinuousTextChapterActive(chapter)) {
        return chapter;
      }
    }
    return null;
  }

  _ContinuousTextChapterLayout? _measureContinuousTextChapterLayout(
    _ContinuousTextChapter chapter,
  ) {
    if (!_scrollController.hasClients) {
      return null;
    }

    final context = _continuousTextChapterKey(chapter).currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }

    final viewport = RenderAbstractViewport.of(renderObject);
    final startOffset = viewport.getOffsetToReveal(renderObject, 0).offset;
    return _ContinuousTextChapterLayout(
      startOffset: startOffset,
      endOffset: startOffset + renderObject.size.height,
    );
  }

  double _continuousTextChapterScrollRatioFor(_ContinuousTextChapter chapter) {
    if (!_scrollController.hasClients) {
      return 0;
    }

    final layout = _measureContinuousTextChapterLayout(chapter);
    if (layout == null) {
      return 0;
    }

    final viewportExtent = _scrollController.position.viewportDimension;
    final available = (layout.endOffset - layout.startOffset - viewportExtent)
        .clamp(0.0, double.infinity);
    if (available <= 0) {
      if (_scrollController.position.pixels <= layout.startOffset) {
        return 0;
      }
      return 1;
    }

    final local = (_scrollController.position.pixels - layout.startOffset)
        .clamp(0.0, available);
    return (local / available).clamp(0.0, 1.0);
  }

  _ContinuousTextChapter? _resolveActiveContinuousTextChapter() {
    if (!_scrollController.hasClients || _continuousTextChapters.isEmpty) {
      return null;
    }

    final probeOffset =
        _scrollController.position.pixels +
        _scrollController.position.viewportDimension * 0.35;
    _ContinuousTextChapter? fallback;
    var fallbackDistance = double.infinity;

    for (final chapter in _continuousTextChapters) {
      final layout = _measureContinuousTextChapterLayout(chapter);
      if (layout == null) {
        continue;
      }
      if (probeOffset >= layout.startOffset && probeOffset < layout.endOffset) {
        return chapter;
      }

      final distance =
          probeOffset < layout.startOffset
              ? layout.startOffset - probeOffset
              : probeOffset - layout.endOffset;
      if (distance < fallbackDistance) {
        fallbackDistance = distance;
        fallback = chapter;
      }
    }

    return fallback;
  }

  void _activateContinuousTextChapter(_ContinuousTextChapter chapter) {
    if (_isContinuousTextChapterActive(chapter)) {
      return;
    }

    final initialRatio = _continuousTextChapterScrollRatioFor(chapter);
    _commitReadingRecordSession();
    if (!mounted) {
      return;
    }

    setState(() {
      _currentIndex = chapter.chapterIndex;
      _chapterId = chapter.chapterId;
      _chapterUrl = chapter.chapterUrl;
      _chapterTitle = chapter.displayTitle;
      _isCurrentChapterCached = chapter.isCached;
      _effectiveReaderReplaceRules = List<ReaderReplaceRule>.unmodifiable(
        chapter.effectiveReaderReplaceRules,
      );
      _setContent(chapter.content, precomputedParagraphs: chapter.paragraphs);
    });

    _scheduleReadingRecordSessionStart(initialRatio: initialRatio);
    _scheduleProgressSave();
    final preloadTaskToken = ++_preloadTaskToken;
    unawaited(_preloadNeighbors(taskToken: preloadTaskToken));
  }

  void _syncActiveContinuousTextChapterFromScroll() {
    if (!_shouldUseContinuousTextFlow || _continuousTextChapters.length <= 1) {
      return;
    }

    final resolved = _resolveActiveContinuousTextChapter();
    if (resolved == null || _isContinuousTextChapterActive(resolved)) {
      return;
    }
    _activateContinuousTextChapter(resolved);
  }

  void _syncContinuousTextFlowAfterSettingsApplied() {
    if (!_shouldUseContinuousTextFlow ||
        _chapterImageUrls.isNotEmpty ||
        _content.trim().isEmpty ||
        _currentIndex == null ||
        _currentIndex! < 0 ||
        _currentIndex! >= _chapters.length) {
      if (_continuousTextChapters.isEmpty) {
        return;
      }
      setState(() {
        _continuousTextChapters = const <_ContinuousTextChapter>[];
      });
      return;
    }

    if (_continuousTextChapters.isNotEmpty) {
      return;
    }

    final currentChapter = _chapters[_currentIndex!];
    final effectiveParagraphs =
        _paragraphs.isEmpty ? <String>[_content] : _paragraphs;
    setState(() {
      _continuousTextChapters = <_ContinuousTextChapter>[
        _ContinuousTextChapter(
          chapterId: _chapterId,
          chapterUrl: (_chapterUrl ?? '').trim(),
          chapterTitle: currentChapter.title.trim(),
          displayTitle: (_chapterTitle ?? currentChapter.title).trim(),
          chapterIndex: _currentIndex!,
          content: _content,
          paragraphs: List<String>.unmodifiable(effectiveParagraphs),
          isCached: _isCurrentChapterCached,
          effectiveReaderReplaceRules: List<ReaderReplaceRule>.unmodifiable(
            _effectiveReaderReplaceRules,
          ),
        ),
      ];
    });
  }

  void _resetCatalogSearchCache() {
    _catalogSearchCacheFingerprint = null;
    _catalogSearchEntriesCache = const <String, List<_CatalogSearchEntry>>{};
  }

  String _chapterLayoutCacheKey({
    required String sourceId,
    required String chapterUrl,
    required String signature,
  }) {
    return '${sourceId.trim()}|${chapterUrl.trim()}|$signature';
  }

  void _storePrecomputedChapterLayout({
    required String sourceId,
    required String chapterUrl,
    required _PrecomputedChapterLayout layout,
  }) {
    final key = _chapterLayoutCacheKey(
      sourceId: sourceId,
      chapterUrl: chapterUrl,
      signature: layout.paginationSignature,
    );
    _precomputedChapterLayouts[key] = layout;
    if (_precomputedChapterLayouts.length <= 6) {
      return;
    }
    final oldestKey = _precomputedChapterLayouts.keys.first;
    _precomputedChapterLayouts.remove(oldestKey);
  }

  _PrecomputedChapterLayout? _consumePrecomputedChapterLayout({
    required String sourceId,
    required String chapterUrl,
    required String signature,
  }) {
    final key = _chapterLayoutCacheKey(
      sourceId: sourceId,
      chapterUrl: chapterUrl,
      signature: signature,
    );
    return _precomputedChapterLayouts.remove(key);
  }

  void _disposeMangaTransformControllers() {
    for (final controller in _mangaTransformControllers.values) {
      controller.dispose();
    }
    _mangaTransformControllers.clear();
    _mangaDoubleTapDetails.clear();
    _mangaZoomedPageIndexes.clear();
  }

  TransformationController _ensureMangaTransformController(int index) {
    return _mangaTransformControllers.putIfAbsent(
      index,
      () => TransformationController(),
    );
  }

  void _syncMangaZoomState(int index) {
    final controller = _mangaTransformControllers[index];
    if (controller == null) {
      return;
    }
    final scale = controller.value.getMaxScaleOnAxis();
    final zoomed = scale > 1.02;

    if (zoomed == _mangaZoomedPageIndexes.contains(index)) {
      return;
    }

    setState(() {
      if (zoomed) {
        _mangaZoomedPageIndexes.add(index);
      } else {
        _mangaZoomedPageIndexes.remove(index);
      }
    });
  }

  void _toggleMangaZoom(int index) {
    final controller = _ensureMangaTransformController(index);
    final currentScale = controller.value.getMaxScaleOnAxis();

    if (currentScale > 1.02) {
      controller.value = Matrix4.identity();
      setState(() {
        _mangaZoomedPageIndexes.remove(index);
      });
      return;
    }

    final tapDetails = _mangaDoubleTapDetails[index];
    final tapPoint = tapDetails?.localPosition ?? const Offset(80, 120);
    const zoomScale = 2.1;

    controller.value =
        Matrix4.identity()
          ..translateByDouble(
            -tapPoint.dx * (zoomScale - 1),
            -tapPoint.dy * (zoomScale - 1),
            0,
            1,
          )
          ..scaleByDouble(zoomScale, zoomScale, 1, 1);

    setState(() {
      _mangaZoomedPageIndexes.add(index);
    });
  }

  double? _consumeBootstrapScrollRatio() {
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

    _bootstrapProgress = null;
    return progress.chapterPositionRatio;
  }

  double _previewBootstrapScrollRatio() {
    final progress = _bootstrapProgress;
    if (progress == null) {
      return 0;
    }

    final currentChapterId = _chapterId.trim();
    final currentChapterUrl = (_chapterUrl ?? '').trim();
    final matchesChapter =
        progress.chapterId == currentChapterId ||
        progress.chapterUrl == currentChapterUrl;
    if (!matchesChapter) {
      return 0;
    }

    return progress.chapterPositionRatio.clamp(0.0, 1.0);
  }

  void _restoreScrollPosition(double ratio) {
    final normalized = ratio.clamp(0.0, 1.0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (_isPagedTextReaderEnabled()) {
        final pages = _pagedPages;
        if (pages.isEmpty) {
          _pendingPageRestoreRatio = normalized;
          return;
        }

        final targetIndex = (normalized * (pages.length - 1)).round().clamp(
          0,
          pages.length - 1,
        );
        setState(() {
          _currentPageIndex = targetIndex;
        });
        return;
      }

      if (_isMangaPagedMode) {
        final total = _chapterImageUrls.length;
        if (total <= 1) {
          setState(() {
            _mangaPageIndex = 0;
          });
          return;
        }

        final target = (normalized * (total - 1)).round().clamp(0, total - 1);
        if (_mangaPageController.hasClients) {
          _mangaPageController.jumpToPage(target);
        }
        setState(() {
          _mangaPageIndex = target;
        });
        return;
      }

      if (!_scrollController.hasClients) {
        return;
      }

      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent <= 0) {
        _scrollController.jumpTo(0);
        return;
      }

      _scrollController.jumpTo(maxExtent * normalized);
    });
  }

  bool _canRunAutoReadNow() {
    if (!_isAutoReadSessionEnabled ||
        _isMangaChapter ||
        _isPagedTextReaderEnabled() ||
        _showOverlayControls ||
        _isBootstrapping ||
        _isLoadingContent ||
        _errorText != null ||
        _content.trim().isEmpty) {
      return false;
    }

    if (!_scrollController.hasClients) {
      return false;
    }

    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) {
      return false;
    }

    return position.pixels < position.maxScrollExtent - 0.8;
  }

  double _autoReadProgressRatio() {
    if (!_scrollController.hasClients) {
      return 0;
    }
    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) {
      return 1;
    }
    return (_scrollController.position.pixels / maxExtent).clamp(0.0, 1.0);
  }

  List<_BookmarkGroup> _groupBookmarksForSheet(List<Bookmark> bookmarks) {
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
      final title = _resolveBookmarkChapterTitle(bookmark);
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

  String _resolveBookmarkChapterTitle(Bookmark bookmark) {
    final chapterId = bookmark.chapterId.trim();
    if (chapterId.isNotEmpty) {
      Chapter? matched;
      for (final chapter in _chapters) {
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
    if (index >= 0 && index < _chapters.length) {
      final title = _chapters[index].title.trim();
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

  Future<void> _refreshChapterBookmarks() async {
    final bookId = _currentBookId;
    if (bookId.isEmpty) {
      return;
    }
    try {
      final all = await _bookmarkRepository.listBookmarks(bookId);
      final filtered = all
          .where(_isBookmarkInCurrentChapter)
          .toList(growable: false);
      final ranges = _buildBookmarkRangesByParagraph(filtered);
      if (!mounted) {
        return;
      }
      setState(() {
        _chapterBookmarks = filtered;
        _bookmarkRangesByParagraph = ranges;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _chapterBookmarks = const [];
        _bookmarkRangesByParagraph = const <int, List<_BookmarkRange>>{};
      });
    }
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
            isBold: bookmark.isBold,
            isUnderline: bookmark.isUnderline,
            isWavy: bookmark.isWavy,
          ),
        );
      }
    }

    return result;
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

  Future<void> _consumePendingBookmarkJump() async {
    final pendingId = _pendingBookmarkId?.trim() ?? '';
    if (pendingId.isEmpty) {
      return;
    }
    _pendingBookmarkId = null;

    try {
      final items = await _bookmarkRepository.listBookmarks(_currentBookId);
      Bookmark? target;
      for (final bookmark in items) {
        if (bookmark.id == pendingId) {
          target = bookmark;
          break;
        }
      }
      if (target == null) {
        _showMessage('未找到对应书签。');
        return;
      }
      await _jumpToBookmark(target);
    } catch (_) {
      _showMessage('书签定位失败，请稍后重试。');
    }
  }

  Future<void> _jumpToBookmark(Bookmark bookmark) async {
    final targetIndex = _resolveBookmarkChapterIndex(bookmark);
    if (targetIndex == null ||
        targetIndex < 0 ||
        targetIndex >= _chapters.length) {
      _showMessage('未找到书签所在章节。');
      return;
    }

    await _jumpTo(targetIndex, initialScrollRatio: 0);
    if (!mounted) {
      return;
    }
    if (_content.trim().isEmpty) {
      _showMessage('章节内容为空，无法定位书签。');
      return;
    }

    final ratio =
        _resolveBookmarkScrollRatio(bookmark) ??
        _findSnippetScrollRatio(bookmark.snippet);
    if (ratio != null) {
      _restoreScrollPosition(ratio);
      return;
    }

    _showMessage('未找到书签位置，已定位到章节开头。');
  }

  int? _resolveBookmarkChapterIndex(Bookmark bookmark) {
    final chapterId = bookmark.chapterId.trim();
    if (chapterId.isNotEmpty) {
      for (final chapter in _chapters) {
        if (chapter.id == chapterId) {
          return chapter.index;
        }
      }
    }

    final index = bookmark.chapterIndex;
    if (index >= 0 && index < _chapters.length) {
      return index;
    }
    return null;
  }

  double? _resolveBookmarkScrollRatio(Bookmark bookmark) {
    final length = _content.length;
    if (length <= 0) {
      return null;
    }
    final offset = bookmark.startOffset;
    if (offset < 0 || offset > length) {
      return null;
    }
    return (offset / length).clamp(0.0, 1.0);
  }

  double? _findSnippetScrollRatio(String snippet) {
    final text = _content;
    final normalized = snippet.trim();
    if (text.isEmpty || normalized.isEmpty) {
      return null;
    }
    final index = text.indexOf(normalized);
    if (index < 0) {
      return null;
    }
    return (index / text.length).clamp(0.0, 1.0);
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

  bool _isAutoReadAtChapterEnd() {
    if (!_scrollController.hasClients) {
      return false;
    }
    final position = _scrollController.position;
    final maxExtent = position.maxScrollExtent;
    if (maxExtent <= 0.8) {
      return true;
    }
    return position.pixels >= maxExtent - 0.8;
  }

  void _scheduleAutoReadResume() {
    if (!mounted) {
      return;
    }
    _autoReadResumeTimer?.cancel();
    if (!_isAutoReadSessionEnabled) {
      return;
    }
    _autoReadResumeTimer = Timer(_kAutoReadResumeDelay, () {
      _reconcileAutoRead();
    });
  }

  void _reconcileAutoRead({bool restart = false}) {
    if (!mounted) {
      return;
    }
    if (restart) {
      _stopAutoRead();
    }
    if (!_isAutoReadSessionEnabled) {
      _stopAutoRead();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_canRunAutoReadNow()) {
        _startAutoReadIfNeeded();
      } else {
        _stopAutoRead();
        unawaited(_tryAutoReadAdvanceChapter());
      }
    });
  }

  void _startAutoReadIfNeeded() {
    if (_isAutoReadRunning || !_canRunAutoReadNow()) {
      return;
    }

    _isAutoReadRunning = true;
    final token = ++_autoReadTaskToken;
    unawaited(_runAutoReadLoop(token));
  }

  Future<void> _runAutoReadLoop(int token) async {
    while (mounted && token == _autoReadTaskToken) {
      if (!_canRunAutoReadNow()) {
        break;
      }

      final position = _scrollController.position;
      final speed =
          _settings.autoReadSpeed
              .clamp(
                ReaderSettings.minAutoReadSpeed,
                ReaderSettings.maxAutoReadSpeed,
              )
              .toDouble();
      final distance = speed * (_kAutoReadStepDuration.inMilliseconds / 1000.0);
      final target = min(position.pixels + distance, position.maxScrollExtent);

      if ((target - position.pixels).abs() < 0.5) {
        break;
      }

      try {
        await _scrollController.animateTo(
          target,
          duration: _kAutoReadStepDuration,
          curve: Curves.linear,
        );
      } catch (_) {
        break;
      }
    }

    if (token == _autoReadTaskToken) {
      _isAutoReadRunning = false;
      unawaited(_tryAutoReadAdvanceChapter());
    }
  }

  Future<void> _tryAutoReadAdvanceChapter() async {
    if (!_isAutoReadSessionEnabled ||
        _isAutoReadAdvancingChapter ||
        _isMangaChapter ||
        _isPagedTextReaderEnabled() ||
        _showOverlayControls ||
        _isBootstrapping ||
        _isLoadingContent ||
        _errorText != null ||
        !_isAutoReadAtChapterEnd()) {
      return;
    }

    final currentIndex = _currentIndex;
    if (currentIndex == null || currentIndex >= _chapters.length - 1) {
      return;
    }

    _isAutoReadAdvancingChapter = true;
    try {
      await _jumpTo(currentIndex + 1, initialScrollRatio: 0);
    } finally {
      _isAutoReadAdvancingChapter = false;
    }
  }

  void _stopAutoRead() {
    _autoReadTaskToken += 1;
    _isAutoReadRunning = false;
    _autoReadResumeTimer?.cancel();
    _autoReadResumeTimer = null;
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final stableOffset = position.pixels.clamp(0.0, position.maxScrollExtent);
    try {
      _scrollController.jumpTo(stableOffset);
    } catch (_) {
      // ignore
    }
  }

  void _onScrollChanged() {
    if (_isPagedTextReaderEnabled()) {
      return;
    }
    if (_isBootstrapping || _isLoadingContent || _errorText != null) {
      return;
    }
    if ((_content.trim().isEmpty && _chapterImageUrls.isEmpty) ||
        _currentIndex == null) {
      return;
    }

    _syncActiveContinuousTextChapterFromScroll();
    _maybePrefetchContinuousTextNeighbors();
    _syncActiveReadingRecordSessionProgress();
    _scheduleProgressSave();
  }

  void _maybePrefetchContinuousTextNeighbors() {
    if (!_shouldUseContinuousTextFlow ||
        !_scrollController.hasClients ||
        _continuousTextChapters.isEmpty ||
        _isScrollEdgeAdvancingChapter ||
        _isAutoReadAdvancingChapter) {
      return;
    }

    final position = _scrollController.position;
    final prefetchBottomDistance = max(240.0, position.viewportDimension * 0.7);
    final prefetchTopDistance = max(120.0, position.viewportDimension * 0.3);
    final remainingBottom = position.maxScrollExtent - position.pixels;

    if (remainingBottom <= prefetchBottomDistance) {
      unawaited(_appendNextContinuousTextChapter());
    }
    if (position.pixels <= prefetchTopDistance) {
      unawaited(_prependPreviousContinuousTextChapter());
    }
  }

  void _scheduleProgressSave() {
    _progressDebounceTimer?.cancel();
    _progressDebounceTimer = Timer(const Duration(milliseconds: 420), () {
      unawaited(_saveProgress());
    });
  }

  bool get _canTrackReadingRecordSession {
    final sourceId = (_sourceId ?? '').trim();
    final detailUrl = (_detailUrl ?? '').trim();
    final title = _bookTitle.trim();
    if (!_readingRecordEnabled) {
      return false;
    }
    if (_isBootstrapping || _isLoadingContent || _errorText != null) {
      return false;
    }
    if (!_hasVisibleReaderContent) {
      return false;
    }
    return sourceId.isNotEmpty && detailUrl.isNotEmpty && title.isNotEmpty;
  }

  void _maybeStartReadingRecordSession({double? initialRatio}) {
    if (!_canTrackReadingRecordSession) {
      _readingRecordAutoCommitTimer?.cancel();
      _readingRecordAutoCommitTimer = null;
      return;
    }

    final chapterUrl = (_chapterUrl ?? '').trim();
    final existing = _activeReadingRecordSession;
    if (existing != null &&
        existing.bookId == _currentBookId &&
        existing.chapterId == _chapterId &&
        existing.chapterUrl == chapterUrl) {
      _syncActiveReadingRecordSessionProgress(
        ratio: initialRatio ?? _currentScrollRatio(),
      );
      _scheduleReadingRecordAutoCommit();
      return;
    }

    final startRatio = (initialRatio ?? _currentScrollRatio()).clamp(0.0, 1.0);
    _activeReadingRecordSession = _ActiveReadingRecordSession(
      bookId: _currentBookId,
      sourceId: _sourceId!.trim(),
      detailUrl: _detailUrl!.trim(),
      bookTitle: _bookTitle.trim(),
      bookAuthor: _bookAuthor?.trim(),
      coverUrl: _bookCoverUrl?.trim(),
      chapterId: _chapterId.trim(),
      chapterTitle: _chapterTitle?.trim(),
      chapterIndex: _currentIndex,
      chapterUrl: chapterUrl,
      startAt: DateTime.now(),
      startPositionRatio: startRatio.toDouble(),
      furthestPositionRatio: startRatio.toDouble(),
    );
    _scheduleReadingRecordAutoCommit();
  }

  void _syncActiveReadingRecordSessionProgress({double? ratio}) {
    final session = _activeReadingRecordSession;
    if (session == null) {
      return;
    }

    final currentRatio =
        (ratio ?? _currentScrollRatio()).clamp(0.0, 1.0).toDouble();
    if (currentRatio <= session.furthestPositionRatio) {
      return;
    }

    _activeReadingRecordSession = session.copyWith(
      furthestPositionRatio: currentRatio,
    );
  }

  void _scheduleReadingRecordAutoCommit() {
    _readingRecordAutoCommitTimer?.cancel();
    if (_activeReadingRecordSession == null) {
      _readingRecordAutoCommitTimer = null;
      return;
    }
    _readingRecordAutoCommitTimer = Timer(
      _kReadingRecordAutoCommitInterval,
      () {
        final restartRatio = _currentScrollRatio();
        _commitReadingRecordSession();
        _maybeStartReadingRecordSession(initialRatio: restartRatio);
      },
    );
  }

  void _commitReadingRecordSession() {
    _readingRecordAutoCommitTimer?.cancel();
    _readingRecordAutoCommitTimer = null;
    final session = _activeReadingRecordSession;
    _activeReadingRecordSession = null;
    if (session == null) {
      return;
    }
    if (!_readingRecordEnabled) {
      return;
    }

    final endAt = DateTime.now();
    final endRatio = _currentScrollRatio();
    final readChars = estimateSessionReadChars(
      chapterLength: _chapterTextLength(),
      startRatio: session.startPositionRatio,
      endRatio: endRatio,
      furthestRatio: session.furthestPositionRatio,
      countAsText: !_isMangaChapter,
    );
    unawaited(
      _readingRecordService.commitSession(
        ReadingRecordCommitInput(
          bookId: session.bookId,
          sourceId: session.sourceId,
          detailUrl: session.detailUrl,
          bookTitle: session.bookTitle,
          bookAuthor: session.bookAuthor,
          coverUrl: session.coverUrl,
          chapterId: session.chapterId,
          chapterTitle: session.chapterTitle,
          chapterIndex: session.chapterIndex,
          chapterUrl: session.chapterUrl,
          startAt: session.startAt,
          endAt: endAt,
          readChars: readChars,
          startPositionRatio: session.startPositionRatio,
          endPositionRatio: endRatio.clamp(0.0, 1.0).toDouble(),
        ),
      ),
    );
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

  double _currentScrollRatio() {
    if (_isPagedTextReaderEnabled()) {
      final pages = _pagedPages;
      if (pages.length <= 1) {
        return 0;
      }
      return (_currentPageIndex / (pages.length - 1)).clamp(0.0, 1.0);
    }

    if (_isMangaPagedMode) {
      final total = _chapterImageUrls.length;
      if (total <= 1) {
        return 0;
      }
      return (_mangaPageIndex / (total - 1)).clamp(0.0, 1.0);
    }

    if (_shouldUseContinuousTextFlow) {
      final currentChapter = _findCurrentContinuousTextChapter();
      if (currentChapter != null) {
        return _continuousTextChapterScrollRatioFor(currentChapter);
      }
    }

    if (!_scrollController.hasClients) {
      return 0;
    }

    final maxExtent = _scrollController.position.maxScrollExtent;
    if (maxExtent <= 0) {
      return 0;
    }

    return (_scrollController.position.pixels / maxExtent).clamp(0.0, 1.0);
  }

  void _showChapterSwitchFailedSnackbar(int targetIndex) {
    if (!mounted) {
      return;
    }

    _showReaderSnackBar(
      text: '切换章节失败，已回退到上一章。',
      duration: _kReaderSnackActionDuration,
      dedupeKey: 'chapter_switch_failed',
      actionLabel: '重试',
      onActionPressed: () => unawaited(_jumpTo(targetIndex)),
    );
  }

  void _scheduleBlockingLoadingCard() {
    _blockingLoadingCardTimer?.cancel();
    _blockingLoadingCardTimer = null;
    _showBlockingLoadingCard = false;

    if (!_needsBlockingLoadingUi) {
      return;
    }

    _blockingLoadingCardTimer = Timer(_kBlockingLoadingCardDelay, () {
      if (!mounted || !_needsBlockingLoadingUi) {
        return;
      }
      setState(() {
        _showBlockingLoadingCard = true;
      });
    });
  }

  void _clearDelayedLoadingUi() {
    _chapterLoadingIndicatorTimer?.cancel();
    _chapterLoadingIndicatorTimer = null;
    _blockingLoadingCardTimer?.cancel();
    _blockingLoadingCardTimer = null;
    _showChapterLoadingIndicator = false;
    _showBlockingLoadingCard = false;
  }

  void _scheduleChapterLoadingIndicator() {
    _chapterLoadingIndicatorTimer?.cancel();
    _chapterLoadingIndicatorTimer = null;
    _showChapterLoadingIndicator = false;

    if (_isBootstrapping ||
        _isSwitchSourceLoading ||
        !_hasVisibleReaderContent) {
      return;
    }

    _chapterLoadingIndicatorTimer = Timer(_kChapterLoadingIndicatorDelay, () {
      if (!mounted || !_isLoadingContent || _shouldShowBlockingReaderLoading) {
        return;
      }
      setState(() {
        _showChapterLoadingIndicator = true;
      });
    });
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
    bool commitChapterIdentity = false,
  }) async {
    if (!mounted) {
      return;
    }

    final resolvedContinuousIndex =
        chapterIndex ??
        _chapters.indexWhere(
          (item) =>
              item.id == chapterId ||
              item.chapterUrl.trim() == chapterUrl.trim(),
        );
    final resolvedContinuousChapter =
        resolvedContinuousIndex >= 0 &&
                resolvedContinuousIndex < _chapters.length
            ? _chapters[resolvedContinuousIndex]
            : null;

    List<String>? precomputedParagraphs;
    List<List<_PagedSlice>>? precomputedPagedPages;
    int? precomputedPageIndex;
    String? precomputedPaginationSignature;

    final canPrepaginate =
        _isPagedTextReaderEnabled() &&
        snapshot.result.imageUrls.isEmpty &&
        snapshot.result.content.trim().isNotEmpty &&
        _lastPaginationMaxWidth != null &&
        _lastPaginationMaxHeight != null &&
        _lastPaginationMaxWidth! >= 20 &&
        _lastPaginationMaxHeight! >= 40;

    if (canPrepaginate) {
      final paragraphs = _splitParagraphs(snapshot.result.content);
      final effectiveParagraphs =
          paragraphs.isEmpty ? <String>[snapshot.result.content] : paragraphs;
      final signature = _buildPaginationSignature(
        maxWidth: _lastPaginationMaxWidth!,
        maxHeight: _lastPaginationMaxHeight!,
        chapterIdOverride: commitChapterIdentity ? chapterId : _chapterId,
      );
      final cachedLayout = _consumePrecomputedChapterLayout(
        sourceId: _sourceId ?? '',
        chapterUrl: chapterUrl,
        signature: signature,
      );
      if (cachedLayout != null) {
        precomputedParagraphs = cachedLayout.paragraphs;
        precomputedPagedPages = cachedLayout.pagedPages;
        precomputedPageIndex = (targetRatio.clamp(0.0, 1.0) *
                (cachedLayout.pagedPages.length - 1))
            .round()
            .clamp(0, cachedLayout.pagedPages.length - 1);
        precomputedPaginationSignature = cachedLayout.paginationSignature;
      } else {
        final pages = await _paginateParagraphSlices(
          paragraphs: effectiveParagraphs,
          maxWidth: _lastPaginationMaxWidth!,
          maxHeight: _lastPaginationMaxHeight!,
        );
        if (pages != null && pages.isNotEmpty) {
          precomputedParagraphs = effectiveParagraphs;
          precomputedPagedPages = pages;
          precomputedPageIndex = (targetRatio.clamp(0.0, 1.0) *
                  (pages.length - 1))
              .round()
              .clamp(0, pages.length - 1);
          precomputedPaginationSignature = signature;
        }
      }
    }

    setState(() {
      if (commitChapterIdentity) {
        _currentIndex = chapterIndex;
        _chapterId = chapterId;
        _chapterUrl = chapterUrl;
        _chapterTitle =
            snapshot.result.displayChapterTitle?.trim().isNotEmpty == true
                ? snapshot.result.displayChapterTitle!.trim()
                : chapterTitle;
      }
      if (!commitChapterIdentity &&
          snapshot.result.displayChapterTitle?.trim().isNotEmpty == true) {
        _chapterTitle = snapshot.result.displayChapterTitle!.trim();
      }
      _isCurrentChapterCached = snapshot.isCached;
      _errorText = null;
      _effectiveReaderReplaceRules = List<ReaderReplaceRule>.unmodifiable(
        snapshot.result.effectiveReaderReplaceRules,
      );
      _setContent(
        snapshot.result.content,
        imageUrls: snapshot.result.imageUrls,
        imageHeaders: snapshot.result.imageHeaders,
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
      _pendingPageRestoreRatio =
          precomputedPaginationSignature == null ? targetRatio : null;
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
      final persisted = await AppDatabase.instance.getChapterCache(
        '$sourceId|$chapterUrl',
      );
      final payload = persisted?.content.trim() ?? '';
      if (payload.isEmpty) {
        return false;
      }

      final decoded = _decodePersistedChapterCache(payload);
      final previewRatio = _previewBootstrapScrollRatio();
      final titleResult = await _readerReplaceRuleService.applyTitleRules(
        title: (_chapterTitle ?? '').trim(),
        bookTitle: _bookTitle,
        sourceId: sourceId,
      );
      final contentResult = await _readerReplaceRuleService.applyContentRules(
        content: decoded.content,
        bookTitle: _bookTitle,
        sourceId: sourceId,
      );
      final effectiveRules = <ReaderReplaceRule>[
        ...titleResult.effectiveRules,
        ...contentResult.effectiveRules.where(
          (rule) =>
              !titleResult.effectiveRules.any(
                (titleRule) => titleRule.id == rule.id,
              ),
        ),
      ];
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
        if (titleResult.content.trim().isNotEmpty) {
          _chapterTitle = titleResult.content.trim();
        }
        _effectiveReaderReplaceRules = List<ReaderReplaceRule>.unmodifiable(
          effectiveRules,
        );
        _setContent(
          contentResult.content,
          imageUrls: decoded.imageUrls,
          imageHeaders: decoded.imageHeaders,
        );
        if (resolvedCurrentChapter != null &&
            _shouldUseContinuousTextFlow &&
            decoded.imageUrls.isEmpty &&
            contentResult.content.trim().isNotEmpty) {
          _continuousTextChapters = <_ContinuousTextChapter>[
            _ContinuousTextChapter(
              chapterId: _chapterId,
              chapterUrl: (_chapterUrl ?? '').trim(),
              chapterTitle: resolvedCurrentChapter.title.trim(),
              displayTitle:
                  (_chapterTitle ?? resolvedCurrentChapter.title).trim(),
              chapterIndex: _currentIndex!,
              content: contentResult.content,
              paragraphs:
                  _paragraphs.isEmpty
                      ? List<String>.unmodifiable(<String>[
                        contentResult.content,
                      ])
                      : List<String>.unmodifiable(_paragraphs),
              isCached: true,
              effectiveReaderReplaceRules: List<ReaderReplaceRule>.unmodifiable(
                effectiveRules,
              ),
            ),
          ];
        } else {
          _continuousTextChapters = const <_ContinuousTextChapter>[];
        }
        _pendingPageRestoreRatio = previewRatio;
      });

      _restoreScrollPosition(previewRatio);
      _scheduleReadingRecordSessionStart(initialRatio: previewRatio);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _tryHydrateTocSnapshot() async {
    final sourceId = (_sourceId ?? '').trim();
    final detailUrl = (_detailUrl ?? '').trim();
    if (sourceId.isEmpty || detailUrl.isEmpty) {
      return false;
    }

    try {
      final snapshot = await _preferencesService.loadTocSnapshot(
        sourceId: sourceId,
        detailUrl: detailUrl,
      );
      if (snapshot == null || snapshot.chapters.isEmpty) {
        return false;
      }

      final chapters = snapshot.chapters;
      final resolvedIndex = _resolveCurrentIndex(chapters);
      if (resolvedIndex == null) {
        return false;
      }
      final current = chapters[resolvedIndex];

      if (mounted) {
        setState(() {
          _bookTitle = snapshot.title;
          _bookAuthor = snapshot.author;
          _bookCoverUrl = snapshot.coverUrl;
          _chapters = chapters;
          _currentIndex = resolvedIndex;
          _chapterId = current.id;
          _chapterUrl = current.chapterUrl;
          _chapterTitle = current.title;
          _errorText = null;
        });
      } else {
        _bookTitle = snapshot.title;
        _bookAuthor = snapshot.author;
        _bookCoverUrl = snapshot.coverUrl;
        _chapters = chapters;
        _currentIndex = resolvedIndex;
        _chapterId = current.id;
        _chapterUrl = current.chapterUrl;
        _chapterTitle = current.title;
        _errorText = null;
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persistTocSnapshot(BookDetailLoadResult detailResult) async {
    final sourceId = (_sourceId ?? '').trim();
    final detailUrl = (_detailUrl ?? '').trim();
    if (sourceId.isEmpty ||
        detailUrl.isEmpty ||
        detailResult.chapters.isEmpty ||
        detailResult.detail.title.trim().isEmpty) {
      return;
    }

    try {
      await _preferencesService.saveTocSnapshot(
        ReaderTocSnapshot(
          bookId: _currentBookId,
          sourceId: sourceId,
          detailUrl: detailUrl,
          title: detailResult.detail.title,
          author: detailResult.detail.author,
          coverUrl: detailResult.detail.coverUrl,
          chapters: detailResult.chapters,
          updatedAt: DateTime.now(),
        ),
      );
    } catch (_) {
      // Ignore snapshot persistence failures.
    }
  }

  _DecodedReaderChapterCache _decodePersistedChapterCache(String payload) {
    final trimmed = payload.trim();
    if (!trimmed.startsWith(_kCachedImagePayloadPrefix)) {
      return _DecodedReaderChapterCache(content: trimmed);
    }

    final raw = trimmed.substring(_kCachedImagePayloadPrefix.length);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final urls = decoded
            .map((item) => item?.toString().trim() ?? '')
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
        return _DecodedReaderChapterCache(content: '', imageUrls: urls);
      }

      if (decoded is Map) {
        final urls =
            (decoded['imageUrls'] as List?)
                ?.map((item) => item?.toString().trim() ?? '')
                .where((item) => item.isNotEmpty)
                .toList(growable: false) ??
            const <String>[];
        final headers =
            (decoded['imageHeaders'] as Map?)
                ?.map(
                  (key, value) =>
                      MapEntry(key.toString(), value?.toString().trim() ?? ''),
                )
                .map((key, value) => MapEntry(key.trim(), value.trim()))
                .entries
                .where(
                  (entry) => entry.key.isNotEmpty && entry.value.isNotEmpty,
                )
                .fold<Map<String, String>>(
                  <String, String>{},
                  (result, entry) => result..[entry.key] = entry.value,
                ) ??
            const <String, String>{};

        return _DecodedReaderChapterCache(
          content: '',
          imageUrls: urls,
          imageHeaders: headers,
        );
      }
    } on FormatException {
      return _DecodedReaderChapterCache(content: trimmed);
    }

    return _DecodedReaderChapterCache(content: trimmed);
  }

  Future<bool> _loadCurrentChapter({
    double? initialScrollRatio,
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

    double? readingRecordStartRatio;
    final sourceId = sourceIdOverride ?? _sourceId;
    final chapterId = chapterIdOverride ?? _chapterId;
    final chapterUrl = chapterUrlOverride ?? _chapterUrl;
    final chapterTitle = chapterTitleOverride ?? _chapterTitle;

    if (sourceId == null ||
        sourceId.isEmpty ||
        chapterUrl == null ||
        chapterUrl.isEmpty) {
      _stopAutoRead();
      setState(() {
        _errorText = '当前章节信息不完整。';
      });
      return false;
    }

    _stopAutoRead();
    _commitReadingRecordSession();
    setState(() {
      _isLoadingContent = true;
      _errorText = null;
    });
    _scheduleBlockingLoadingCard();
    _scheduleChapterLoadingIndicator();

    try {
      final resolvedIndex =
          chapterIndexOverride ??
          _currentIndex ??
          _chapters.indexWhere((chapter) => chapter.chapterUrl == chapterUrl);
      final snapshot = await _fetchChapterContentSnapshot(
        sourceId: sourceId,
        chapterId: chapterId,
        chapterUrl: chapterUrl,
        chapterTitle: chapterTitle,
        chapterIndex: resolvedIndex >= 0 ? resolvedIndex : null,
      );

      if (!mounted) {
        return false;
      }

      final targetRatio = initialScrollRatio?.clamp(0.0, 1.0) ?? 0.0;
      await _applyLoadedChapterSnapshot(
        snapshot: snapshot,
        chapterId: chapterId,
        chapterUrl: chapterUrl,
        chapterTitle: chapterTitle,
        chapterIndex: resolvedIndex >= 0 ? resolvedIndex : null,
        targetRatio: targetRatio,
        commitChapterIdentity: commitChapterIdentity,
      );
      readingRecordStartRatio = targetRatio;
      return true;
    } on AppException catch (error) {
      if (!mounted) {
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
      if (!mounted) {
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
      _clearDelayedLoadingUi();
      if (mounted) {
        setState(() {
          _isLoadingContent = false;
        });
        if (readingRecordStartRatio != null) {
          _scheduleReadingRecordSessionStart(
            initialRatio: readingRecordStartRatio,
          );
        }
        _reconcileAutoRead(restart: true);
      }
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
    );

    context.push(route);
  }

  Future<void> _showEffectiveReaderReplaceRulesSheet() async {
    if (!mounted) {
      return;
    }

    final rules = _effectiveReaderReplaceRules;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: _readerModalTheme().colorScheme.surface,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        final textTheme = Theme.of(sheetContext).textTheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '本章净化',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                rules.isEmpty
                    ? '本章没有命中用户净化规则。'
                    : '本章共命中 ${rules.length} 条净化规则。',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              if (rules.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.42),
                    ),
                  ),
                  child: Text(
                    '你可以去“净化”里新增去广告、去水印、文本替换等规则。',
                    style: textTheme.bodySmall?.copyWith(height: 1.35),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: rules.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final rule = rules[index];
                      return Material(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            Navigator.of(sheetContext).pop();
                            await context.push(
                              '/reader-replace-rules/edit?id=${rule.id}',
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        rule.name,
                                        style: textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.secondaryContainer
                                            .withValues(alpha: 0.82),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        rule.isRegex ? '正则' : '普通',
                                        style: textTheme.labelSmall?.copyWith(
                                          color:
                                              colorScheme.onSecondaryContainer,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surface,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: colorScheme.outlineVariant
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Text(
                                        rule.scopeTitle && rule.scopeContent
                                            ? '标题+正文'
                                            : rule.scopeTitle
                                            ? '标题'
                                            : '正文',
                                        style: textTheme.labelSmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '匹配：${rule.pattern}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('关闭'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await context.push('/reader-replace-rules');
                      },
                      child: const Text('管理规则'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
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

    final preloadIndexes = <int>{};

    for (var offset = 1; offset <= _kBackwardPreloadChapterCount; offset++) {
      final index = currentIndex - offset;
      if (index >= 0) {
        preloadIndexes.add(index);
      }
    }

    for (var offset = 1; offset <= _kForwardPreloadChapterCount; offset++) {
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
          chapterId: chapter.id,
          chapterIndex: index,
          chapterTitle: chapter.title,
          nextChapterUrl: nextChapterUrl.isEmpty ? null : nextChapterUrl,
        );
        if (_isPagedTextReaderEnabled() &&
            result.imageUrls.isEmpty &&
            result.content.trim().isNotEmpty &&
            _lastPaginationMaxWidth != null &&
            _lastPaginationMaxHeight != null &&
            _lastPaginationMaxWidth! >= 20 &&
            _lastPaginationMaxHeight! >= 40) {
          final paragraphs = _splitParagraphs(result.content);
          final effectiveParagraphs =
              paragraphs.isEmpty ? <String>[result.content] : paragraphs;
          final signature = _buildPaginationSignature(
            maxWidth: _lastPaginationMaxWidth!,
            maxHeight: _lastPaginationMaxHeight!,
            chapterIdOverride: chapter.id,
          );
          if (_consumePrecomputedChapterLayout(
                sourceId: normalizedSourceId,
                chapterUrl: chapterUrl,
                signature: signature,
              ) ==
              null) {
            final pages = await _paginateParagraphSlices(
              paragraphs: effectiveParagraphs,
              maxWidth: _lastPaginationMaxWidth!,
              maxHeight: _lastPaginationMaxHeight!,
              shouldAbort: () => !mounted || taskToken != _preloadTaskToken,
            );
            if (pages != null && pages.isNotEmpty) {
              _storePrecomputedChapterLayout(
                sourceId: normalizedSourceId,
                chapterUrl: chapterUrl,
                layout: _PrecomputedChapterLayout(
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

  Future<void> _saveProgress() async {
    final sourceId = _sourceId;
    final detailUrl = _detailUrl;
    final chapterUrl = _chapterUrl;
    final chapterTitle = _chapterTitle;
    final currentIndex = _currentIndex;

    if (sourceId == null ||
        detailUrl == null ||
        chapterUrl == null ||
        chapterTitle == null ||
        currentIndex == null) {
      return;
    }

    final normalizedDetailUrl = _normalizeLocalDetailUrlForProgress(detailUrl);
    final normalizedChapterUrl = _normalizeLocalChapterUrlForProgress(
      chapterUrl,
    );

    await _preferencesService.saveProgress(
      ReadingProgress(
        bookId: _currentBookId,
        sourceId: sourceId,
        detailUrl: normalizedDetailUrl,
        chapterId: _chapterId,
        chapterUrl: normalizedChapterUrl,
        chapterTitle: chapterTitle,
        chapterIndex: currentIndex,
        updatedAt: DateTime.now(),
        chapterPositionRatio: _currentScrollRatio(),
      ),
    );
  }

  Future<void> _goToPreviousPage(double viewportHeight) {
    return _turnPagedTextPage(direction: -1);
  }

  Future<void> _goToNextPage(double viewportHeight) {
    return _turnPagedTextPage(direction: 1);
  }

  Future<void> _turnPagedTextPage({required int direction}) async {
    if (!_isPagedTextReaderEnabled()) {
      return;
    }

    _clearSelectionState();
    _clearSystemSelection();

    if (_isPaginatingPages) {
      return;
    }

    final pages = _pagedPages;
    if (pages.isEmpty) {
      return;
    }

    final safeDirection = direction >= 0 ? 1 : -1;
    final targetIndex = _currentPageIndex + safeDirection;
    if (targetIndex < 0 || targetIndex >= pages.length) {
      await _jumpPagedTextAcrossChapter(direction: safeDirection);
      return;
    }

    final animationStyle = _effectivePageAnimationStyle();
    if (animationStyle == ReaderPageAnimationStyle.curl) {
      await _autoTurnCurlPage(safeDirection);
      return;
    }

    if (animationStyle == ReaderPageAnimationStyle.none) {
      setState(() {
        _currentPageIndex = targetIndex;
      });
      _syncActiveReadingRecordSessionProgress();
      _scheduleProgressSave();
      return;
    }

    _startPagedPageTransition(
      style: animationStyle,
      direction: safeDirection,
      fromIndex: _currentPageIndex,
      toIndex: targetIndex,
    );
  }

  Future<void> _jumpPagedTextAcrossChapter({required int direction}) async {
    final currentChapterIndex = _currentIndex;
    if (currentChapterIndex == null) {
      return;
    }

    if (direction < 0) {
      if (currentChapterIndex <= 0) {
        _showChapterBoundaryHint(isFirst: true);
        return;
      }
      await _jumpTo(currentChapterIndex - 1, initialScrollRatio: 1);
      return;
    }

    if (currentChapterIndex >= _chapters.length - 1) {
      _showChapterBoundaryHint(isFirst: false);
      return;
    }
    await _jumpTo(currentChapterIndex + 1, initialScrollRatio: 0);
  }

  void _startPagedPageTransition({
    required ReaderPageAnimationStyle style,
    required int direction,
    required int fromIndex,
    required int toIndex,
  }) {
    if (_isPagedTransitionAnimating) {
      return;
    }

    final motion = _pageSwitchMotionSpecForStyle(style);
    _pagedTransitionController.duration = motion.duration;
    setState(() {
      _pagedTransition = _PagedPageTransitionState(
        isAnimating: true,
        style: style,
        direction: direction,
        fromIndex: fromIndex,
        toIndex: toIndex,
      );
    });
    _pagedTransitionController.value = 0;
    _pagedTransitionController.forward();
  }

  void _onPagedTransitionStatus(AnimationStatus status) {
    if (!_isPagedTransitionAnimating || status != AnimationStatus.completed) {
      return;
    }

    final nextIndex = _pagedTransition.toIndex;
    setState(() {
      _currentPageIndex = nextIndex;
      _pagedTransition = _PagedPageTransitionState(
        fromIndex: nextIndex,
        toIndex: nextIndex,
        style: _pagedTransition.style,
        direction: _pagedTransition.direction,
      );
    });
    _syncActiveReadingRecordSessionProgress();
    _scheduleProgressSave();
  }

  Future<void> _jumpTo(int index, {double? initialScrollRatio}) async {
    if (_isLoadingContent || index < 0 || index >= _chapters.length) {
      return;
    }

    _stopAutoRead();
    final chapter = _chapters[index];

    final success = await _loadCurrentChapter(
      initialScrollRatio: initialScrollRatio ?? 0,
      sourceIdOverride: _sourceId,
      chapterIdOverride: chapter.id,
      chapterUrlOverride: chapter.chapterUrl,
      chapterTitleOverride: chapter.title,
      chapterIndexOverride: index,
      commitChapterIdentity: true,
    );
    if (success || !mounted) {
      return;
    }

    setState(() {
      _errorText = null;
    });

    _maybeStartReadingRecordSession(initialRatio: _currentScrollRatio());
    _showChapterSwitchFailedSnackbar(index);
  }

  void _onReaderTap(Offset localPosition, Size size, EdgeInsets gestureInsets) {
    if (_isTextSelectionActive) {
      return;
    }
    if (_isBackNavigationInteractionCoolingDown) {
      return;
    }

    final leftGuard = max(22.0, gestureInsets.left + size.width * 0.02);
    final rightGuard = max(22.0, gestureInsets.right + size.width * 0.02);
    final topGuard = max(0.0, gestureInsets.top);
    final bottomGuard = max(0.0, gestureInsets.bottom);

    final centerLeft = max(size.width * 0.32, leftGuard + 12);
    final centerRight = min(size.width * 0.68, size.width - rightGuard - 12);
    final centerTop = max(size.height * 0.2, topGuard + 8);
    final centerBottom = min(size.height * 0.8, size.height - bottomGuard - 8);

    final isCenterTap =
        localPosition.dx >= centerLeft &&
        localPosition.dx <= centerRight &&
        localPosition.dy >= centerTop &&
        localPosition.dy <= centerBottom;

    if (_isAutoReadSessionEnabled) {
      _stopAutoReadSession(showMessage: true);
      return;
    }

    if (isCenterTap) {
      final nextShow = !_showOverlayControls;
      _setOverlayControlsVisibility(nextShow);
      if (!nextShow) {
        _scheduleAutoReadResume();
      }
      return;
    }

    if (_showOverlayControls) {
      _hideOverlayControls(resumeAutoRead: true);
      return;
    }

    if (!_pageTurnIncludesTap(_settings.pageTurnMode)) {
      return;
    }

    if (localPosition.dx <= leftGuard ||
        localPosition.dx >= size.width - rightGuard) {
      return;
    }

    final isPagedTextReader = _isPagedTextReaderEnabled();
    final isScrollTextReader =
        !_isMangaChapter && _pageTurnUsesScroll(_settings.pageTurnMode);

    if (localPosition.dx < centerLeft) {
      if (isPagedTextReader) {
        unawaited(_goToPreviousPage(size.height));
      } else if (isScrollTextReader) {
        unawaited(_advanceScrollReaderByStep(forward: false));
      }
      return;
    }

    if (localPosition.dx > centerRight) {
      if (isPagedTextReader) {
        unawaited(_goToNextPage(size.height));
      } else if (isScrollTextReader) {
        unawaited(_advanceScrollReaderByStep(forward: true));
      }
    }
  }

  void _hideOverlayControls({
    bool resumeAutoRead = true,
    bool syncSystemUi = true,
  }) {
    if (!_showOverlayControls || !mounted) {
      return;
    }

    if (syncSystemUi) {
      _setOverlayControlsVisibility(false);
    } else {
      setState(() {
        _showOverlayControls = false;
      });
      unawaited(_syncVolumeKeyPageInterception());
      _overlayControlsController.reverse();
    }
    if (resumeAutoRead) {
      _scheduleAutoReadResume();
    }
  }

  void _setOverlayControlsVisibility(bool visible) {
    if (!mounted || _showOverlayControls == visible) {
      return;
    }

    setState(() {
      _showOverlayControls = visible;
    });
    unawaited(_syncVolumeKeyPageInterception());
    if (visible) {
      _overlayControlsController.forward();
    } else {
      _overlayControlsController.reverse();
    }
    _syncSystemUiVisibility(visible: visible);
  }

  void _syncSystemUiVisibility({bool force = false, bool? visible}) {
    if (!mounted) {
      return;
    }
    final shouldShow = visible ?? _showOverlayControls;
    if (!force && _isSystemUiVisible == shouldShow) {
      return;
    }
    _isSystemUiVisible = shouldShow;

    if (shouldShow) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      return;
    }

    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.android) {
      // HarmonyOS reports as Android platform; immersiveSticky is more reliable
      // than manual overlay control on some vendor ROMs.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      return;
    }

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: const [SystemUiOverlay.bottom],
    );
  }

  Future<void> _openCatalogSheetFromOverlay() async {
    await _showCatalogSheet();
  }

  Future<void> _openMangaPositionSheet() async {
    if (!_isMangaChapter) {
      return;
    }

    final total = _chapterImageUrls.length;
    if (total <= 1 && !_scrollController.hasClients) {
      return;
    }

    final isPagedMode = _isMangaPagedMode;
    double draftRatio = _currentScrollRatio();
    final readerModalTheme = _readerModalTheme();

    final selectedRatio = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: readerModalTheme.colorScheme.surface,
      builder: (context) {
        return Theme(
          data: readerModalTheme,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final progressLabel = '${(draftRatio * 100).round()}%';
              final chapterLabel =
                  isPagedMode
                      ? '第 ${(_mangaPageIndex + 1).clamp(1, total)} / $total 张'
                      : '长图进度定位';

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  8,
                  18,
                  18 + _bottomSafeInset(context),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '长图定位',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$chapterLabel · $progressLabel',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Slider(
                      min: 0,
                      max: 1,
                      divisions: 100,
                      value: draftRatio,
                      onChanged: (value) {
                        setModalState(() {
                          draftRatio = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed:
                              () => Navigator.of(context).pop(draftRatio),
                          child: const Text('跳转'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (!mounted || selectedRatio == null) {
      return;
    }

    _restoreScrollPosition(selectedRatio);
    _scheduleProgressSave();
  }

  Future<void> _showCatalogSheet() async {
    if (_chapters.isEmpty) {
      _showMessage('当前书籍暂无目录。');
      return;
    }
    _stopAutoReadSession();

    const itemExtent = 58.0;
    final currentIndex = _currentIndex;
    final anchorIndex =
        currentIndex == null
            ? 0
            : (currentIndex - 2).clamp(0, _chapters.length - 1);
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
    double? selectedScrollRatio;
    final readerModalTheme = _readerModalTheme();
    var bookmarks = <Bookmark>[];
    var isBookmarkLoading = true;
    var hasBookmarkRequested = false;
    var bookmarkErrorText = '';
    var didTriggerBookmarkJump = false;
    var activeTabIndex = 0;
    var catalogDescending = false;

    Future<void> loadBookmarks(StateSetter setModalState) async {
      setModalState(() {
        isBookmarkLoading = true;
        bookmarkErrorText = '';
      });
      try {
        final items = await _bookmarkRepository.listBookmarks(_currentBookId);
        bookmarks = items;
      } catch (error) {
        bookmarkErrorText = '书签加载失败，请稍后重试。';
      } finally {
        setModalState(() {
          isBookmarkLoading = false;
        });
      }
    }

    Future<void> ensureBookmarksLoaded(StateSetter setModalState) async {
      if (hasBookmarkRequested) {
        return;
      }
      hasBookmarkRequested = true;
      await loadBookmarks(setModalState);
    }

    List<int> orderedChapterIndexes() {
      if (!catalogDescending) {
        return List<int>.generate(_chapters.length, (index) => index);
      }
      return List<int>.generate(
        _chapters.length,
        (index) => _chapters.length - 1 - index,
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
      final cachedEntries = _peekCatalogSearchEntries(normalizedKeyword);
      if (cachedEntries != null) {
        catalogSearchToken += 1;
        catalogSearchNotifier.value = _ReaderCatalogSearchState(
          keyword: keyword,
          entries: cachedEntries,
          isLoading: false,
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
        final entries = _lookupCatalogSearchEntries(keyword);
        if (token != catalogSearchToken) {
          return;
        }
        catalogSearchNotifier.value = _ReaderCatalogSearchState(
          keyword: keyword,
          entries: entries,
          isLoading: false,
        );
      });
    }

    searchController.addListener(() {
      scheduleCatalogSearch(searchController.text);
    });

    final selectedIndex = await showModalBottomSheet<int>(
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
              final sheetHeightFactor = _adaptiveReaderSheetHeightFactor(
                context,
                compact: 0.70,
                regular: 0.70,
                large: 0.70,
              );
              final sheetHorizontal = AppSpacing.pageHorizontal(context);

              Widget buildCatalogTab() {
                return ValueListenableBuilder<_ReaderCatalogSearchState>(
                  valueListenable: catalogSearchNotifier,
                  builder: (context, searchState, _) {
                    final isSearching = searchState.keyword.isNotEmpty;
                    final searchEntries = searchState.entries;
                    final orderedIndexes = orderedChapterIndexes();
                    final tocSearchEntries =
                        catalogDescending
                            ? ([...searchState.tocEntries]..sort(
                              (a, b) =>
                                  b.chapterIndex.compareTo(a.chapterIndex),
                            ))
                            : searchState.tocEntries;
                    final contentSearchEntries =
                        catalogDescending
                            ? ([...searchState.contentEntries]..sort(
                              (a, b) =>
                                  b.chapterIndex.compareTo(a.chapterIndex),
                            ))
                            : searchState.contentEntries;

                    return Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            sheetHorizontal,
                            6,
                            sheetHorizontal,
                            8,
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final locationButton =
                                  currentIndex == null
                                      ? null
                                      : FilledButton.tonalIcon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              colorScheme.primaryContainer,
                                          foregroundColor:
                                              colorScheme.onPrimaryContainer,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          minimumSize: const Size(0, 36),
                                          visualDensity: VisualDensity.compact,
                                          shape: const StadiumBorder(),
                                        ),
                                        onPressed: () {
                                          final currentDisplayIndex =
                                              orderedIndexes.indexOf(
                                                currentIndex,
                                              );
                                          final target =
                                              ((currentDisplayIndex - 2).clamp(
                                                        0,
                                                        _chapters.length - 1,
                                                      ) *
                                                      itemExtent)
                                                  .toDouble();
                                          scrollController.animateTo(
                                            target,
                                            duration: const Duration(
                                              milliseconds: 180,
                                            ),
                                            curve: Curves.easeOutCubic,
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.my_location_outlined,
                                          size: 17,
                                        ),
                                        label: Text('定位 ${currentIndex + 1}'),
                                      );
                              return _buildReaderCatalogSummaryCard(
                                context,
                                chapterCount: _chapters.length,
                                currentIndex: currentIndex,
                                locateButton: locationButton,
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            sheetHorizontal,
                            2,
                            sheetHorizontal,
                            10,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: searchController,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    filled: true,
                                    fillColor: colorScheme.surface,
                                    hintText: '搜索目录标题或当前章节正文',
                                    prefixIcon: Icon(
                                      Icons.search_rounded,
                                      size: 17,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: colorScheme.outlineVariant
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: colorScheme.primary.withValues(
                                          alpha: 0.9,
                                        ),
                                        width: 1.1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: catalogDescending ? '当前倒序' : '当前正序',
                                child: FilledButton.tonalIcon(
                                  onPressed: () {
                                    setModalState(() {
                                      catalogDescending = !catalogDescending;
                                    });
                                  },
                                  icon: Icon(
                                    catalogDescending
                                        ? Icons.south_rounded
                                        : Icons.north_rounded,
                                    size: 17,
                                  ),
                                  label: Text(catalogDescending ? '倒序' : '正序'),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 40),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 9,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        if (isSearching && searchState.isLoading)
                          const Expanded(
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          )
                        else if (isSearching && searchEntries.isEmpty)
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
                                      '当前仅支持搜索目录标题与本章正文。',
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
                            child: _buildCatalogSearchResultList(
                              context,
                              scrollController: scrollController,
                              tocEntries: tocSearchEntries,
                              contentEntries: contentSearchEntries,
                              onEntryTap: (entry) {
                                selectedScrollRatio = entry.scrollRatio;
                                Navigator.of(context).pop(entry.chapterIndex);
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
                                    8,
                                    12,
                                    10,
                                  ),
                                  itemBuilder: (context, index) {
                                    final chapterIndex = orderedIndexes[index];
                                    final chapter = _chapters[chapterIndex];
                                    final selected =
                                        chapterIndex == currentIndex;
                                    return _buildReaderCatalogChapterTile(
                                      context,
                                      chapter: chapter,
                                      index: chapterIndex,
                                      selected: selected,
                                      onTap:
                                          () => Navigator.of(
                                            context,
                                          ).pop(chapterIndex),
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
                  unawaited(ensureBookmarksLoaded(setModalState));
                }
                final bookmarkGroups = _groupBookmarksForSheet(bookmarks);
                final title =
                    isBookmarkLoading ? '书签' : '书签（${bookmarks.length}）';

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
                              '正在加载书签...',
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
                                  () => unawaited(loadBookmarks(setModalState)),
                              child: const Text('重试'),
                            ),
                          ],
                        )
                      else if (bookmarkGroups.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Text(
                            '当前书籍还没有书签。',
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
                                onTap: (bookmark) {
                                  didTriggerBookmarkJump = true;
                                  Navigator.of(context).pop();
                                  unawaited(_jumpToBookmark(bookmark));
                                },
                                onDelete: (bookmark) async {
                                  await _bookmarkRepository.removeBookmark(
                                    bookmark.id,
                                  );
                                  await loadBookmarks(setModalState);
                                  unawaited(_refreshChapterBookmarks());
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

              Tab buildCountTab({
                required String label,
                required String countText,
              }) {
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
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
                                      ensureBookmarksLoaded(setModalState),
                                    );
                                  }
                                },
                                tabs: [
                                  buildCountTab(
                                    label: '目录',
                                    countText: _chapters.length.toString(),
                                  ),
                                  buildCountTab(
                                    label: '书签',
                                    countText: bookmarkCountLabel,
                                  ),
                                ],
                              ),
                            ),
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

    if (didTriggerBookmarkJump) {
      return;
    }

    if (!mounted ||
        selectedIndex == null ||
        selectedIndex < 0 ||
        selectedIndex >= _chapters.length) {
      _scheduleAutoReadResume();
      return;
    }

    if (selectedIndex == _currentIndex) {
      if (selectedScrollRatio != null) {
        _restoreScrollPosition(selectedScrollRatio!);
      }
      _scheduleAutoReadResume();
      return;
    }

    await _jumpTo(selectedIndex);
  }

  List<_CatalogSearchEntry> _buildFullTextSearchEntries(String keyword) {
    if (keyword.isEmpty) {
      return const [];
    }

    final normalizedKeyword = keyword.toLowerCase();
    final entries = <_CatalogSearchEntry>[];

    for (var index = 0; index < _chapters.length; index++) {
      final title = _chapters[index].title;
      if (_containsKeyword(title, keyword, normalizedKeyword)) {
        entries.add(
          _CatalogSearchEntry(
            title: title,
            subtitle: '第 ${index + 1} 章 · 目录匹配',
            chapterIndex: index,
          ),
        );
      }
    }

    final currentIndex = _currentIndex;
    if (currentIndex == null || _content.trim().isEmpty) {
      return entries;
    }

    final paragraphs =
        _paragraphs.isEmpty ? _splitParagraphs(_content) : _paragraphs;
    if (paragraphs.isEmpty) {
      if (_containsKeyword(_content, keyword, normalizedKeyword)) {
        entries.add(
          _CatalogSearchEntry(
            title: '第 ${currentIndex + 1} 章正文',
            subtitle: _buildSearchSnippet(_content, keyword),
            chapterIndex: currentIndex,
            scrollRatio: 0,
            isContent: true,
          ),
        );
      }
      return entries;
    }

    for (var index = 0; index < paragraphs.length; index++) {
      final paragraph = paragraphs[index];
      if (!_containsKeyword(paragraph, keyword, normalizedKeyword)) {
        continue;
      }

      final ratio =
          paragraphs.length <= 1 ? 0.0 : index / (paragraphs.length - 1);
      entries.add(
        _CatalogSearchEntry(
          title: '第 ${currentIndex + 1} 章正文命中',
          subtitle: _buildSearchSnippet(paragraph, keyword),
          chapterIndex: currentIndex,
          scrollRatio: ratio,
          isContent: true,
        ),
      );
      if (entries.length >= 60) {
        break;
      }
    }

    return entries;
  }

  List<_CatalogSearchEntry>? _peekCatalogSearchEntries(
    String normalizedKeyword,
  ) {
    final fingerprint = _buildCatalogSearchCacheFingerprint();
    if (_catalogSearchCacheFingerprint != fingerprint) {
      _resetCatalogSearchCache();
      _catalogSearchCacheFingerprint = fingerprint;
    }
    return _catalogSearchEntriesCache[normalizedKeyword];
  }

  List<_CatalogSearchEntry> _lookupCatalogSearchEntries(String keyword) {
    final normalizedKeyword = keyword.trim().toLowerCase();
    if (normalizedKeyword.isEmpty) {
      return const <_CatalogSearchEntry>[];
    }

    final cached = _peekCatalogSearchEntries(normalizedKeyword);
    if (cached != null) {
      return cached;
    }

    final entries = List<_CatalogSearchEntry>.unmodifiable(
      _buildFullTextSearchEntries(keyword),
    );
    _catalogSearchEntriesCache = <String, List<_CatalogSearchEntry>>{
      ..._catalogSearchEntriesCache,
      normalizedKeyword: entries,
    };
    return entries;
  }

  String _buildCatalogSearchCacheFingerprint() {
    final firstChapterId = _chapters.isEmpty ? '' : _chapters.first.id;
    final lastChapterId = _chapters.isEmpty ? '' : _chapters.last.id;
    return [
      _chapterId,
      _chapterUrl ?? '',
      (_currentIndex ?? -1).toString(),
      _chapters.length.toString(),
      firstChapterId,
      lastChapterId,
      _content.hashCode.toString(),
      _paragraphs.length.toString(),
    ].join('|');
  }

  Widget _buildCatalogSearchResultList(
    BuildContext context, {
    required ScrollController scrollController,
    required List<_CatalogSearchEntry> tocEntries,
    required List<_CatalogSearchEntry> contentEntries,
    required ValueChanged<_CatalogSearchEntry> onEntryTap,
  }) {
    final children = <Widget>[];

    void appendSection(String title, List<_CatalogSearchEntry> entries) {
      if (entries.isEmpty) {
        return;
      }
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 8));
      }
      children.add(
        _buildCatalogSearchSectionHeader(
          context,
          title: title,
          count: entries.length,
        ),
      );
      children.add(const SizedBox(height: 6));
      for (final entry in entries) {
        children.add(
          _buildCatalogSearchEntryTile(
            context,
            entry: entry,
            onTap: () => onEntryTap(entry),
          ),
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

  Widget _buildReaderCatalogSummaryCard(
    BuildContext context, {
    required int chapterCount,
    required int? currentIndex,
    required Widget? locateButton,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentChapterTitle =
        currentIndex != null &&
                currentIndex >= 0 &&
                currentIndex < _chapters.length
            ? _chapters[currentIndex].title
            : '尚未定位到章节';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '阅读导航',
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '目录 $chapterCount 章',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      currentIndex == null
                          ? '可从目录或书签中快速定位'
                          : '当前阅读 · 第 ${currentIndex + 1} 章',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (locateButton != null) locateButton,
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 14,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    currentChapterTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (currentIndex != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '当前',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
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

  Widget _buildReaderCatalogChapterTile(
    BuildContext context, {
    required Chapter chapter,
    required int index,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final borderRadius = BorderRadius.circular(14);
    final selectedBackground = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: 0.15),
      colorScheme.surfaceContainerLow,
    );
    final unselectedBackground = colorScheme.surface.withValues(alpha: 0.78);

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
                        selected
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color:
                          selected
                              ? colorScheme.onPrimary
                              : colorScheme.onSurfaceVariant,
                    ),
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
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color:
                          selected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
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

  Widget _buildCatalogSearchSectionHeader(
    BuildContext context, {
    required String title,
    required int count,
  }) {
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

  Widget _buildCatalogSearchEntryTile(
    BuildContext context, {
    required _CatalogSearchEntry entry,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accentColor =
        entry.isContent ? colorScheme.tertiary : colorScheme.primary;

    return Material(
      color:
          entry.isContent
              ? colorScheme.tertiaryContainer.withValues(alpha: 0.32)
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
                  entry.isContent ? '正文' : '目录',
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

  bool _containsKeyword(String text, String keyword, String normalizedKeyword) {
    return text.contains(keyword) ||
        text.toLowerCase().contains(normalizedKeyword);
  }

  String _buildSearchSnippet(String source, String keyword) {
    final normalized = source.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return '未匹配到可展示内容';
    }

    if (normalized.length <= 56) {
      return normalized;
    }

    final keywordLower = keyword.toLowerCase();
    final lower = normalized.toLowerCase();
    final keywordIndex = lower.indexOf(keywordLower);
    if (keywordIndex < 0) {
      return '${normalized.substring(0, 56)}...';
    }

    final start = (keywordIndex - 14).clamp(0, normalized.length);
    final end = (keywordIndex + keyword.length + 22).clamp(
      0,
      normalized.length,
    );
    final snippet = normalized.substring(start, end);

    final prefix = start > 0 ? '...' : '';
    final suffix = end < normalized.length ? '...' : '';
    return '$prefix$snippet$suffix';
  }

  Future<void> _toggleAutoReadSession() async {
    if (_isAutoReadSessionEnabled) {
      _stopAutoReadSession(showMessage: true);
      return;
    }

    if (_isMangaChapter) {
      _showMessage('漫画模式暂不支持自动阅读。');
      return;
    }

    if (_showOverlayControls) {
      _hideOverlayControls(resumeAutoRead: false);
    }
    _startAutoReadSession(showMessage: true);
  }

  void _startAutoReadSession({bool showMessage = false}) {
    if (!mounted || _isMangaChapter) {
      return;
    }

    _autoReadResumeTimer?.cancel();
    _pageTurnModeBeforeAutoRead = _settings.pageTurnMode;
    setState(() {
      _isAutoReadSessionEnabled = true;
      _settings = _settings.copyWith(
        pageTurnMode: ReaderPageTurnMode.scroll,
        autoReadEnabled: false,
      );
    });
    _syncContinuousTextFlowAfterSettingsApplied();
    _reconcileAutoRead(restart: true);
    if (showMessage) {
      _showMessage('已开启自动阅读。');
    }
  }

  void _stopAutoReadSession({bool showMessage = false}) {
    if (!_isAutoReadSessionEnabled) {
      return;
    }
    _isAutoReadAdvancingChapter = false;
    _autoReadResumeTimer?.cancel();
    _stopAutoRead();

    if (mounted) {
      setState(() {
        _isAutoReadSessionEnabled = false;
        _settings = _settings.copyWith(
          pageTurnMode: _pageTurnModeBeforeAutoRead,
          autoReadEnabled: false,
        );
      });
      _syncContinuousTextFlowAfterSettingsApplied();
    } else {
      _isAutoReadSessionEnabled = false;
    }

    if (showMessage) {
      _showMessage('已停止自动阅读。');
    }
  }

  int? _resolveCurrentIndex(List<Chapter> chapters) {
    if (chapters.isEmpty) {
      return null;
    }

    final byId = chapters.indexWhere((chapter) => chapter.id == _chapterId);
    if (byId >= 0) {
      return byId;
    }

    final chapterUrl = _chapterUrl;
    if (chapterUrl != null && chapterUrl.isNotEmpty) {
      final byUrl = chapters.indexWhere(
        (chapter) => chapter.chapterUrl == chapterUrl,
      );
      if (byUrl >= 0) {
        return byUrl;
      }
    }

    final fromRoute = widget.chapterIndex;
    if (fromRoute != null && fromRoute >= 0 && fromRoute < chapters.length) {
      return fromRoute;
    }

    return 0;
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
        (_isLocalScheme(detailUrl) || _isLocalScheme(chapterUrl))) {
      _sourceId = LocalBookImportService.localBookSourceId;
    }

    if ((_sourceId ?? '').trim() != LocalBookImportService.localBookSourceId) {
      return;
    }

    if (detailUrl.isEmpty || !_isLocalScheme(detailUrl)) {
      _detailUrl = _buildLocalDetailUrl(_currentBookId);
    }

    final normalizedChapterId = _chapterId.trim();
    if ((chapterUrl.isEmpty || !_isLocalScheme(chapterUrl)) &&
        normalizedChapterId.isNotEmpty &&
        !_isPlaceholderChapterId(normalizedChapterId)) {
      _chapterUrl = _buildLocalChapterUrl(normalizedChapterId);
    }
  }

  String _normalizeLocalDetailUrlForProgress(String detailUrl) {
    if (!_isLocalSource) {
      return detailUrl;
    }
    final normalized = detailUrl.trim();
    if (_isLocalScheme(normalized)) {
      return normalized;
    }
    final bookId = _currentBookId;
    if (bookId.isEmpty) {
      return normalized;
    }
    return _buildLocalDetailUrl(bookId);
  }

  String _normalizeLocalChapterUrlForProgress(String chapterUrl) {
    if (!_isLocalSource) {
      return chapterUrl;
    }
    final normalized = chapterUrl.trim();
    if (_isLocalScheme(normalized)) {
      return normalized;
    }
    final chapterId = _chapterId.trim();
    if (chapterId.isEmpty || _isPlaceholderChapterId(chapterId)) {
      return normalized;
    }
    return _buildLocalChapterUrl(chapterId);
  }

  String _buildLocalDetailUrl(String bookId) {
    final normalized = bookId.trim();
    return 'local://book/$normalized';
  }

  String _buildLocalChapterUrl(String chapterId) {
    final normalized = chapterId.trim();
    return 'local://chapter/$normalized';
  }

  bool _isLocalScheme(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(normalized);
    return uri != null && uri.scheme == 'local';
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

  bool get _canSwitchSource => _contentCapabilities.canSwitchSource;
  bool get _canCacheChapter => _contentCapabilities.canCacheChapter;

  String get _currentBookId {
    final normalized = _activeBookId.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
    return widget.bookId.trim();
  }

  bool get _isLocalSource =>
      _sourceId?.trim() == LocalBookImportService.localBookSourceId;
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

  Future<void> _showSettingsSheet({
    _ReaderSettingsTab initialTab = _ReaderSettingsTab.reading,
  }) async {
    _stopAutoReadSession();
    final shouldRestoreOverlay = _showOverlayControls;
    if (shouldRestoreOverlay) {
      _hideOverlayControls(resumeAutoRead: false, syncSystemUi: false);
    }

    var draft = _settings;
    final isMangaChapter = _chapterImageUrls.isNotEmpty;
    var availableCustomFonts = List<ReaderCustomFontEntry>.from(_customFonts);
    var startAutoReadAfterApply = false;
    var draftAutoSwitchSourceOnFailureEnabled =
        _autoSwitchSourceOnFailureEnabled;
    var draftReaderReplaceRuleMode = ReaderReplaceRuleMode.inherit;
    var isSavingAutoSwitchSourceOnFailure = false;
    var isSavingReaderReplaceRuleMode = false;
    var isPersistingDraft = false;
    Timer? persistDraftTimer;

    final normalizedSourceId = (_sourceId ?? '').trim();
    final normalizedDetailUrl = (_detailUrl ?? '').trim();
    if (_currentBookId.trim().isNotEmpty &&
        normalizedSourceId.isNotEmpty &&
        normalizedDetailUrl.isNotEmpty) {
      final preference = await _readerReplaceRuleService.getBookPreference(
        bookId: _currentBookId,
        sourceId: normalizedSourceId,
        detailUrl: normalizedDetailUrl,
      );
      draftReaderReplaceRuleMode =
          preference?.mode ?? ReaderReplaceRuleMode.inherit;
    }

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
        hasActiveBackground &&
        _backgroundPresetBase64.values.contains(activeBackgroundBase64);
    if (hasActiveBackground && !isActivePreset) {
      final nextCustoms = List<String>.from(_customBackgroundImages);
      if (!nextCustoms.contains(activeBackgroundBase64)) {
        nextCustoms.add(activeBackgroundBase64);
        if (nextCustoms.length > _kMaxCustomBackgrounds) {
          nextCustoms.removeRange(
            0,
            nextCustoms.length - _kMaxCustomBackgrounds,
          );
        }
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
              void updateCustomBackgrounds(List<String> nextCustoms) {
                if (mounted) {
                  setState(() {
                    _customBackgroundImages = nextCustoms;
                  });
                } else {
                  _customBackgroundImages = nextCustoms;
                }
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

              void previewDraftSettings() {
                if (!mounted) {
                  return;
                }

                schedulePersistDraft();
                if (identical(_settings, draft)) {
                  return;
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || identical(_settings, draft)) {
                    return;
                  }
                  setState(() {
                    _settings = draft;
                  });
                  unawaited(_syncVolumeKeyPageInterception());
                });
              }

              Future<void> applyCustomBackgroundImage() async {
                final encoded = await _pickBackgroundImageBase64();
                if (encoded == null || !context.mounted) {
                  return;
                }

                final nextCustoms =
                    List<String>.from(_customBackgroundImages)
                      ..removeWhere((entry) => entry == encoded)
                      ..add(encoded);
                if (nextCustoms.length > _kMaxCustomBackgrounds) {
                  nextCustoms.removeRange(
                    0,
                    nextCustoms.length - _kMaxCustomBackgrounds,
                  );
                }

                setModalState(() {
                  draft = draft.copyWith(backgroundImageBase64: encoded);
                  _customBackgroundImages = nextCustoms;
                });
                updateCustomBackgrounds(nextCustoms);
              }

              void applyStoredCustomBackground(String base64) {
                final normalized = base64.trim();
                if (normalized.isEmpty) {
                  return;
                }
                setModalState(() {
                  draft = draft.copyWith(backgroundImageBase64: normalized);
                });
              }

              void removeActiveBackground() {
                final active = draft.backgroundImageBase64?.trim();
                final isActivePreset =
                    active != null &&
                    active.isNotEmpty &&
                    _backgroundPresetBase64.values.contains(active);

                setModalState(() {
                  draft = draft.copyWith(clearBackgroundImage: true);
                });

                if (active != null &&
                    active.isNotEmpty &&
                    !isActivePreset &&
                    _customBackgroundImages.contains(active)) {
                  final nextCustoms = List<String>.from(_customBackgroundImages)
                    ..removeWhere((entry) => entry == active);
                  updateCustomBackgroundsInSheet(nextCustoms);
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

              String currentFontLabel() {
                final selectedCustomFont = resolveSelectedCustomFont(draft);
                if (selectedCustomFont != null) {
                  return selectedCustomFont.displayName;
                }
                return '系统字体';
              }

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

                        Future<void> selectSystemFont() async {
                          setModalState(() {
                            draft = draft.copyWith(
                              fontSource: ReaderFontSource.system,
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
                            label: '系统字体',
                            selected:
                                draft.fontSource == ReaderFontSource.system,
                            icon: Icons.text_fields_rounded,
                            onTap: selectSystemFont,
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
                                  '每行三个，点击即可应用；自定义会打开文件上传。',
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

              Future<void> openFontWeightTabSheet() async {
                if (!context.mounted) {
                  return;
                }

                await showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  useSafeArea: true,
                  backgroundColor: readerModalTheme.colorScheme.surface,
                  builder: (sheetContext) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '字重',
                            textAlign: TextAlign.center,
                            style: Theme.of(sheetContext).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
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
                                    selected: draft.fontWeightLevel == level,
                                    onSelected: (_) {
                                      setModalState(() {
                                        draft = draft.copyWith(
                                          fontWeightLevel: level,
                                        );
                                      });
                                      if (sheetContext.mounted) {
                                        Navigator.of(sheetContext).pop();
                                      }
                                    },
                                  ),
                                )
                                .toList(growable: false),
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

                await showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  useSafeArea: true,
                  backgroundColor: readerModalTheme.colorScheme.surface,
                  builder: (sheetContext) {
                    return StatefulBuilder(
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
                            bodyMarginTop: top ?? draft.bodyMarginTop,
                            bodyMarginBottom: bottom ?? draft.bodyMarginBottom,
                            bodyMarginLeft: left ?? draft.bodyMarginLeft,
                            bodyMarginRight: right ?? draft.bodyMarginRight,
                          );
                          updatePaddingSettings(next);
                        }

                        Future<double?> promptExactMarginValue({
                          required String label,
                          required double currentValue,
                        }) async {
                          final controller = TextEditingController(
                            text: currentValue.round().toString(),
                          );
                          String? errorText;

                          final result = await showDialog<double>(
                            context: sheetContext,
                            builder: (dialogContext) {
                              return StatefulBuilder(
                                builder: (dialogContext, setDialogState) {
                                  void submit() {
                                    final raw = controller.text.trim();
                                    final parsed = double.tryParse(raw);
                                    if (parsed == null) {
                                      setDialogState(() {
                                        errorText = '请输入数字';
                                      });
                                      return;
                                    }
                                    if (parsed <
                                            ReaderSettings.minLayoutMargin ||
                                        parsed >
                                            ReaderSettings.maxLayoutMargin) {
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
                                    content: TextField(
                                      controller: controller,
                                      autofocus: true,
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
                                      onSubmitted: (_) => submit(),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () =>
                                                Navigator.of(
                                                  dialogContext,
                                                ).pop(),
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

                          controller.dispose();
                          return result;
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
                                  child: Text(
                                    label,
                                    style: textTheme.bodyMedium,
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => nudge(-1),
                                  icon: const Icon(Icons.remove_rounded),
                                ),
                                Expanded(
                                  child: Slider(
                                    min: ReaderSettings.minLayoutMargin,
                                    max: ReaderSettings.maxLayoutMargin,
                                    divisions:
                                        (ReaderSettings.maxLayoutMargin -
                                                ReaderSettings.minLayoutMargin)
                                            .round(),
                                    value: safeValue,
                                    onChanged: onChanged,
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => nudge(1),
                                  icon: const Icon(Icons.add_rounded),
                                ),
                                SizedBox(
                                  width: 52,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () async {
                                      final exact =
                                          await promptExactMarginValue(
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
                                        safeValue.round().toString(),
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
                                    selected:
                                        dividerInteractive && dividerEnabled,
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

                        return SizedBox(
                          height: 560,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
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
                                      buildSectionTitle(
                                        title: '页眉',
                                        dividerEnabled:
                                            draft.infoHeaderDividerEnabled,
                                        dividerInteractive:
                                            draft.infoHeaderEnabled,
                                        onDividerChanged: (selected) {
                                          updatePaddingSettings(
                                            draft.copyWith(
                                              infoHeaderDividerEnabled:
                                                  selected,
                                            ),
                                          );
                                        },
                                      ),
                                      buildMarginControlRow(
                                        label: '上边距',
                                        value: draft.infoHeaderMarginTop,
                                        onChanged: (value) {
                                          updatePaddingSettings(
                                            draft.copyWith(
                                              infoHeaderMarginTop: value,
                                            ),
                                          );
                                        },
                                      ),
                                      buildMarginControlRow(
                                        label: '下边距',
                                        value: draft.infoHeaderMarginBottom,
                                        onChanged: (value) {
                                          updatePaddingSettings(
                                            draft.copyWith(
                                              infoHeaderMarginBottom: value,
                                            ),
                                          );
                                        },
                                      ),
                                      buildMarginControlRow(
                                        label: '左边距',
                                        value: draft.infoHeaderMarginLeft,
                                        onChanged: (value) {
                                          updatePaddingSettings(
                                            draft.copyWith(
                                              infoHeaderMarginLeft: value,
                                            ),
                                          );
                                        },
                                      ),
                                      buildMarginControlRow(
                                        label: '右边距',
                                        value: draft.infoHeaderMarginRight,
                                        onChanged: (value) {
                                          updatePaddingSettings(
                                            draft.copyWith(
                                              infoHeaderMarginRight: value,
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      buildSectionTitle(title: '正文'),
                                      buildMarginControlRow(
                                        label: '上边距',
                                        value: draft.bodyMarginTop,
                                        onChanged:
                                            (value) =>
                                                updateBodyMargins(top: value),
                                      ),
                                      buildMarginControlRow(
                                        label: '下边距',
                                        value: draft.bodyMarginBottom,
                                        onChanged:
                                            (value) => updateBodyMargins(
                                              bottom: value,
                                            ),
                                      ),
                                      buildMarginControlRow(
                                        label: '左边距',
                                        value: draft.bodyMarginLeft,
                                        onChanged:
                                            (value) =>
                                                updateBodyMargins(left: value),
                                      ),
                                      buildMarginControlRow(
                                        label: '右边距',
                                        value: draft.bodyMarginRight,
                                        onChanged:
                                            (value) =>
                                                updateBodyMargins(right: value),
                                      ),
                                      const SizedBox(height: 8),
                                      buildSectionTitle(
                                        title: '页脚',
                                        dividerEnabled:
                                            draft.infoFooterDividerEnabled,
                                        dividerInteractive:
                                            draft.infoFooterEnabled,
                                        onDividerChanged: (selected) {
                                          updatePaddingSettings(
                                            draft.copyWith(
                                              infoFooterDividerEnabled:
                                                  selected,
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
                          ),
                        );
                      },
                    );
                  },
                );
              }

              Future<void> openInfoTabSheet() async {
                if (!context.mounted) {
                  return;
                }

                await showModalBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  useSafeArea: true,
                  backgroundColor: readerModalTheme.colorScheme.surface,
                  builder: (sheetContext) {
                    return StatefulBuilder(
                      builder: (sheetContext, setInfoState) {
                        final colorScheme = Theme.of(sheetContext).colorScheme;
                        final textTheme = Theme.of(sheetContext).textTheme;

                        bool hasAnyInfoItem(ReaderSettings settings) {
                          return settings.infoShowTime ||
                              settings.infoShowBattery ||
                              settings.infoShowChapter ||
                              settings.infoShowProgress;
                        }

                        void updateInfoSettings(
                          ReaderSettings next, {
                          bool ensureAtLeastOneInfoItem = false,
                        }) {
                          var normalized = next;
                          if (!normalized.infoHeaderEnabled &&
                              normalized.infoHeaderDividerEnabled) {
                            normalized = normalized.copyWith(
                              infoHeaderDividerEnabled: false,
                            );
                          }
                          if (!normalized.infoFooterEnabled &&
                              normalized.infoFooterDividerEnabled) {
                            normalized = normalized.copyWith(
                              infoFooterDividerEnabled: false,
                            );
                          }

                          if (ensureAtLeastOneInfoItem &&
                              !hasAnyInfoItem(normalized)) {
                            normalized = normalized.copyWith(
                              infoShowChapter: true,
                            );
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                _showMessage('至少保留一项信息位，已自动保留“章节”。');
                              }
                            });
                          }

                          setModalState(() {
                            draft = normalized;
                          });
                          setInfoState(() {});
                        }

                        final previewItems = <String>[];
                        if (draft.infoShowTime) {
                          previewItems.add(
                            _formatReaderInfoTime(_readerInfoNow),
                          );
                        }
                        if (draft.infoShowBattery) {
                          previewItems.add(_readerBatteryLabel());
                        }
                        if (draft.infoShowChapter) {
                          previewItems.add(_chapterInfoLabel());
                        }
                        if (draft.infoShowProgress) {
                          previewItems.add(
                            '进度 ${(_currentScrollRatio() * 100).round()}%',
                          );
                        }
                        final previewText =
                            previewItems.isEmpty
                                ? '未选择信息位'
                                : previewItems.join(' · ');

                        return SizedBox(
                          height: 440,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  '信息',
                                  textAlign: TextAlign.center,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: ListView(
                                    children: [
                                      SwitchListTile.adaptive(
                                        contentPadding: EdgeInsets.zero,
                                        title: const Text('显示页眉信息条'),
                                        value: draft.infoHeaderEnabled,
                                        onChanged: (value) {
                                          updateInfoSettings(
                                            draft.copyWith(
                                              infoHeaderEnabled: value,
                                            ),
                                          );
                                        },
                                      ),
                                      SwitchListTile.adaptive(
                                        contentPadding: EdgeInsets.zero,
                                        title: const Text('显示页脚信息条'),
                                        value: draft.infoFooterEnabled,
                                        onChanged: (value) {
                                          updateInfoSettings(
                                            draft.copyWith(
                                              infoFooterEnabled: value,
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '信息位',
                                        style: textTheme.labelMedium?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          FilterChip(
                                            label: const Text('时间'),
                                            selected: draft.infoShowTime,
                                            onSelected: (selected) {
                                              updateInfoSettings(
                                                draft.copyWith(
                                                  infoShowTime: selected,
                                                ),
                                                ensureAtLeastOneInfoItem: true,
                                              );
                                            },
                                          ),
                                          FilterChip(
                                            label: const Text('电量'),
                                            selected: draft.infoShowBattery,
                                            onSelected: (selected) {
                                              updateInfoSettings(
                                                draft.copyWith(
                                                  infoShowBattery: selected,
                                                ),
                                                ensureAtLeastOneInfoItem: true,
                                              );
                                            },
                                          ),
                                          FilterChip(
                                            label: const Text('章节'),
                                            selected: draft.infoShowChapter,
                                            onSelected: (selected) {
                                              updateInfoSettings(
                                                draft.copyWith(
                                                  infoShowChapter: selected,
                                                ),
                                                ensureAtLeastOneInfoItem: true,
                                              );
                                            },
                                          ),
                                          FilterChip(
                                            label: const Text('进度'),
                                            selected: draft.infoShowProgress,
                                            onSelected: (selected) {
                                              updateInfoSettings(
                                                draft.copyWith(
                                                  infoShowProgress: selected,
                                                ),
                                                ensureAtLeastOneInfoItem: true,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        '页眉内边距：${draft.infoHeaderPadding.round()}',
                                        style: textTheme.labelMedium?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      Slider(
                                        min: ReaderSettings.minInfoBarPadding,
                                        max: ReaderSettings.maxInfoBarPadding,
                                        divisions: 12,
                                        value:
                                            draft.infoHeaderPadding
                                                .clamp(
                                                  ReaderSettings
                                                      .minInfoBarPadding,
                                                  ReaderSettings
                                                      .maxInfoBarPadding,
                                                )
                                                .toDouble(),
                                        onChanged: (value) {
                                          updateInfoSettings(
                                            draft.copyWith(
                                              infoHeaderPadding: value,
                                            ),
                                          );
                                        },
                                      ),
                                      Text(
                                        '页脚内边距：${draft.infoFooterPadding.round()}',
                                        style: textTheme.labelMedium?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      Slider(
                                        min: ReaderSettings.minInfoBarPadding,
                                        max: ReaderSettings.maxInfoBarPadding,
                                        divisions: 12,
                                        value:
                                            draft.infoFooterPadding
                                                .clamp(
                                                  ReaderSettings
                                                      .minInfoBarPadding,
                                                  ReaderSettings
                                                      .maxInfoBarPadding,
                                                )
                                                .toDouble(),
                                        onChanged: (value) {
                                          updateInfoSettings(
                                            draft.copyWith(
                                              infoFooterPadding: value,
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '预览：$previewText',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      if (draft.infoShowBattery)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6,
                                          ),
                                          child: Text(
                                            _readerBatteryReadFailed
                                                ? '当前平台未返回电量值，已显示为 N/A。'
                                                : '电量为实时读取，约每 30 秒刷新一次。',
                                            style: textTheme.bodySmall
                                                ?.copyWith(
                                                  color:
                                                      colorScheme
                                                          .onSurfaceVariant,
                                                ),
                                          ),
                                        ),
                                    ],
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

              final showInterfaceSection =
                  initialTab == _ReaderSettingsTab.interface;
              final showReadingSection =
                  initialTab == _ReaderSettingsTab.reading;

              final presetBackgroundTiles = <Widget>[];
              for (final preset in _backgroundPresets) {
                final previewBytes = _backgroundPresetBytes[preset.assetPath];
                final presetBase64 = _backgroundPresetBase64[preset.assetPath];
                if (previewBytes == null || presetBase64 == null) {
                  continue;
                }
                presetBackgroundTiles.add(
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildBackgroundTile(
                      label: preset.label,
                      selected: activeBackgroundBase64 == presetBase64,
                      previewBytes: previewBytes,
                      showLabel: false,
                      onTap: () {
                        setModalState(() {
                          draft = draft.copyWith(
                            backgroundImageBase64: presetBase64,
                          );
                        });
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
                final base64 = customBackgrounds[index];
                final previewBytes = _tryDecodeBase64(base64);
                final isSelected =
                    hasBackgroundImage &&
                    !isPresetBackground &&
                    activeBackgroundBase64 == base64;
                customBackgroundTiles.add(
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildBackgroundTile(
                      label: '自定义${index + 1}',
                      selected: isSelected,
                      previewBytes: previewBytes,
                      showLabel: true,
                      icon:
                          previewBytes == null
                              ? Icons.broken_image_outlined
                              : null,
                      onTap: () => applyStoredCustomBackground(base64),
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
              final maxSheetWidth =
                  showReadingSection && !isMangaChapter ? 700.0 : 640.0;
              final disablePageAnimationSelection =
                  !isMangaChapter && _pageTurnUsesScroll(draft.pageTurnMode);
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
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => nudge(-step),
                        icon: const Icon(Icons.remove_rounded),
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
                        onPressed: () => nudge(step),
                        icon: const Icon(Icons.add_rounded),
                      ),
                      if (showValueLabel)
                        SizedBox(
                          width: 70,
                          child: Text(valueLabel, textAlign: TextAlign.right),
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
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
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
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withValues(
                                alpha: 0.76,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              icon,
                              size: 17,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (subtitle != null &&
                                    subtitle.trim().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...children,
                    ],
                  ),
                );
              }

              Widget buildSummaryAction({
                required IconData icon,
                required String label,
                required String value,
                required VoidCallback onTap,
              }) {
                final colorScheme = Theme.of(context).colorScheme;

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onTap,
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 16, color: colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            '$label · $value',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
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
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
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
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Divider(
                    height: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                );
              }

              Widget buildTextReaderSettingsSheet() {
                String infoBarValue() {
                  if (!draft.infoHeaderEnabled && !draft.infoFooterEnabled) {
                    return '未开启';
                  }
                  final parts = <String>[];
                  if (draft.infoHeaderEnabled) {
                    parts.add('页眉');
                  }
                  if (draft.infoFooterEnabled) {
                    parts.add('页脚');
                  }
                  return parts.join('+');
                }

                String bodyMarginValue() {
                  return '${draft.bodyMarginLeft.round()}/${draft.bodyMarginTop.round()}/${draft.bodyMarginRight.round()}/${draft.bodyMarginBottom.round()}';
                }

                int enabledInfoItemCount() {
                  var count = 0;
                  if (draft.infoShowTime) {
                    count += 1;
                  }
                  if (draft.infoShowBattery) {
                    count += 1;
                  }
                  if (draft.infoShowChapter) {
                    count += 1;
                  }
                  if (draft.infoShowProgress) {
                    count += 1;
                  }
                  return count;
                }

                final interfaceCards = <Widget>[
                  buildSettingsSectionCard(
                    icon: Icons.palette_outlined,
                    title: '外观',
                    subtitle: '亮度、背景色与背景图',
                    children: [
                      _buildSettingLine(
                        context: context,
                        label: '亮度',
                        labelWidth: 46,
                        child: Row(
                          children: [
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
                            const SizedBox(width: 6),
                            FilterChip(
                              label: const Text('护眼'),
                              selected:
                                  draft.themeMode == ReaderThemeMode.sepia,
                              onSelected: (selected) {
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
                            ),
                          ],
                        ),
                      ),
                      buildSectionDivider(),
                      _buildSettingLine(
                        context: context,
                        label: '背景色',
                        labelWidth: 54,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildThemeColorDot(
                                draft: draft,
                                color: const Color(0xFFFDFDFD),
                                label: '明亮',
                                mode: ReaderThemeMode.light,
                                backgroundStyle: ReaderBackgroundStyle.plain,
                                backgroundTone: ReaderBackgroundTone.surface,
                                onChanged: (next) {
                                  setModalState(() {
                                    draft = next;
                                  });
                                },
                              ),
                              _buildThemeColorDot(
                                draft: draft,
                                color: const Color(0xFFF7EEDC),
                                label: '护眼',
                                mode: ReaderThemeMode.sepia,
                                backgroundStyle: ReaderBackgroundStyle.warm,
                                backgroundTone: ReaderBackgroundTone.container,
                                onChanged: (next) {
                                  setModalState(() {
                                    draft = next;
                                  });
                                },
                              ),
                              _buildThemeColorDot(
                                draft: draft,
                                color: const Color(0xFFE8EDF5),
                                label: '浅灰',
                                mode: ReaderThemeMode.light,
                                backgroundStyle: ReaderBackgroundStyle.paper,
                                backgroundTone:
                                    ReaderBackgroundTone.containerHigh,
                                onChanged: (next) {
                                  setModalState(() {
                                    draft = next;
                                  });
                                },
                              ),
                              _buildThemeColorDot(
                                draft: draft,
                                color: const Color(0xFF242831),
                                label: '夜间',
                                mode: ReaderThemeMode.dark,
                                backgroundStyle: ReaderBackgroundStyle.plain,
                                backgroundTone:
                                    ReaderBackgroundTone.containerHigh,
                                onChanged: (next) {
                                  setModalState(() {
                                    draft = next;
                                  });
                                },
                              ),
                              _buildThemeColorDot(
                                draft: draft,
                                color: const Color(0xFF16181D),
                                label: '深夜',
                                mode: ReaderThemeMode.dark,
                                backgroundStyle: ReaderBackgroundStyle.plain,
                                backgroundTone:
                                    ReaderBackgroundTone.containerHighest,
                                onChanged: (next) {
                                  setModalState(() {
                                    draft = next;
                                  });
                                },
                              ),
                              _buildThemeColorDot(
                                draft: draft,
                                color: const Color(0xFF000000),
                                label: '纯黑',
                                mode: ReaderThemeMode.dark,
                                backgroundStyle: ReaderBackgroundStyle.plain,
                                backgroundTone: ReaderBackgroundTone.pureBlack,
                                onChanged: (next) {
                                  setModalState(() {
                                    draft = next;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      buildSectionDivider(),
                      _buildSettingLine(
                        context: context,
                        label: '背景',
                        child: ScrollConfiguration(
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
                                  onTap: () {
                                    setModalState(() {
                                      draft = draft.copyWith(
                                        clearBackgroundImage: true,
                                      );
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                ...presetBackgroundTiles,
                                ...customBackgroundTiles,
                                _buildBackgroundTile(
                                  label: '自定义',
                                  selected: false,
                                  icon: Icons.upload_file_rounded,
                                  showLabel: true,
                                  onTap: applyCustomBackgroundImage,
                                ),
                                if (hasBackgroundImage) ...[
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: removeActiveBackground,
                                    child: const Text('移除'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  buildSettingsSectionCard(
                    icon: Icons.touch_app_outlined,
                    title: '交互',
                    subtitle: '触发方式与翻页动画',
                    children: [
                      _buildSettingLine(
                        context: context,
                        label: '触发',
                        child: SingleChildScrollView(
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
                                selected: _pageTurnUsesScroll(
                                  draft.pageTurnMode,
                                ),
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
                      ),
                      buildSectionDivider(),
                      _buildSettingLine(
                        context: context,
                        label: '动画',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_pageTurnUsesScroll(draft.pageTurnMode))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '滚动触发模式下不使用分页动画',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelSmall?.copyWith(
                                    color:
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            buildPageAnimationSelector(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  buildSettingsSectionCard(
                    icon: Icons.info_outline_rounded,
                    title: '信息栏',
                    subtitle: '页眉页脚显示、分隔线与信息项',
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          buildSummaryAction(
                            icon: Icons.space_dashboard_outlined,
                            label: '信息栏',
                            value: infoBarValue(),
                            onTap: () => unawaited(openInfoTabSheet()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '当前启用 ${enabledInfoItemCount()} 项信息内容，页眉${draft.infoHeaderEnabled ? '开启' : '关闭'}，页脚${draft.infoFooterEnabled ? '开启' : '关闭'}。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ];

                final readingCards = <Widget>[
                  buildSettingsSectionCard(
                    icon: Icons.text_fields_rounded,
                    title: '字体',
                    subtitle: '字号、字体来源与字重',
                    children: [
                      _buildSettingLine(
                        context: context,
                        label: '字号',
                        child: Row(
                          children: [
                            IconButton.filledTonal(
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                final next =
                                    (draft.fontSize - 1)
                                        .clamp(5, 50)
                                        .toDouble();
                                setModalState(() {
                                  draft = draft.copyWith(fontSize: next);
                                });
                              },
                              icon: const Icon(Icons.remove),
                            ),
                            SizedBox(
                              width: 48,
                              child: Center(
                                child: Text(
                                  draft.fontSize.toStringAsFixed(0),
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            IconButton.filledTonal(
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                final next =
                                    (draft.fontSize + 1)
                                        .clamp(5, 50)
                                        .toDouble();
                                setModalState(() {
                                  draft = draft.copyWith(fontSize: next);
                                });
                              },
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ),
                      buildSectionDivider(),
                      _buildSettingLine(
                        context: context,
                        label: '快捷',
                        labelWidth: 46,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            buildSummaryAction(
                              icon: Icons.font_download_outlined,
                              label: '字体',
                              value: currentFontLabel(),
                              onTap: () => unawaited(openFontPickerSheet()),
                            ),
                            buildSummaryAction(
                              icon: Icons.format_bold_rounded,
                              label: '字重',
                              value: fontWeightLevelLabel(
                                draft.fontWeightLevel,
                              ),
                              onTap: () => unawaited(openFontWeightTabSheet()),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  buildSettingsSectionCard(
                    icon: Icons.subject_rounded,
                    title: '排版',
                    subtitle: '行距、段距、字距与缩进',
                    children: [
                      buildTypographySliderRow(
                        label: '缩进',
                        min: 0,
                        max: 8,
                        divisions: 8,
                        value: draft.paragraphIndent.clamp(0, 8).toDouble(),
                        step: 1,
                        valueLabel: _paragraphIndentValueLabel(draft),
                        onChanged: (value) {
                          setModalState(() {
                            draft = draft.copyWith(
                              paragraphIndent: value.round().toDouble(),
                            );
                          });
                        },
                      ),
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
                    ],
                  ),
                  buildSettingsSectionCard(
                    icon: Icons.crop_free_rounded,
                    title: '正文边距',
                    subtitle: '影响正文可视宽度与上下留白',
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          buildSummaryAction(
                            icon: Icons.tune_rounded,
                            label: '边距',
                            value: bodyMarginValue(),
                            onTap:
                                () =>
                                    unawaited(openHorizontalPaddingTabSheet()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '数值顺序为左/上/右/下，直接决定正文排版视口。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                  buildSettingsSectionCard(
                    icon: Icons.auto_awesome_motion_outlined,
                    title: '自动阅读',
                    subtitle: '一次性操作，关闭弹窗后按当前速度启动',
                    children: [
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
                      const SizedBox(height: 4),
                      Text(
                        '自动阅读速度：${_autoReadSpeedLevelLabel(draft.autoReadSpeed)} · ${draft.autoReadSpeed.round()} px/s',
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(
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
                      Row(
                        children: [
                          Text(
                            '慢',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const Spacer(),
                          Text(
                            '快',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ];

                Future<void> updateAutoSwitchSourceOnFailure(
                  bool enabled,
                ) async {
                  if (isSavingAutoSwitchSourceOnFailure) {
                    return;
                  }

                  setModalState(() {
                    draftAutoSwitchSourceOnFailureEnabled = enabled;
                    isSavingAutoSwitchSourceOnFailure = true;
                  });
                  if (mounted) {
                    setState(() {
                      _autoSwitchSourceOnFailureEnabled = enabled;
                    });
                  } else {
                    _autoSwitchSourceOnFailureEnabled = enabled;
                  }

                  try {
                    await _systemSettingsService
                        .saveAutoSwitchSourceOnFailureEnabled(enabled);
                  } catch (_) {
                    if (!mounted) {
                      return;
                    }
                    setModalState(() {
                      draftAutoSwitchSourceOnFailureEnabled = !enabled;
                    });
                    setState(() {
                      _autoSwitchSourceOnFailureEnabled = !enabled;
                    });
                    _showMessage('保存阅读容错失败，请重试。');
                  } finally {
                    if (mounted) {
                      setModalState(() {
                        isSavingAutoSwitchSourceOnFailure = false;
                      });
                    } else {
                      isSavingAutoSwitchSourceOnFailure = false;
                    }
                  }
                }

                String replaceRuleModeLabel(ReaderReplaceRuleMode mode) {
                  return switch (mode) {
                    ReaderReplaceRuleMode.inherit => '跟随全局',
                    ReaderReplaceRuleMode.enabled => '本书开启',
                    ReaderReplaceRuleMode.disabled => '本书关闭',
                  };
                }

                Future<void> updateReaderReplaceRuleMode(
                  ReaderReplaceRuleMode mode,
                ) async {
                  if (isSavingReaderReplaceRuleMode ||
                      _currentBookId.trim().isEmpty ||
                      normalizedSourceId.isEmpty ||
                      normalizedDetailUrl.isEmpty) {
                    return;
                  }

                  setModalState(() {
                    draftReaderReplaceRuleMode = mode;
                    isSavingReaderReplaceRuleMode = true;
                  });

                  try {
                    await _readerReplaceRuleService.saveBookPreference(
                      ReaderReplacePreference(
                        bookId: _currentBookId,
                        sourceId: normalizedSourceId,
                        detailUrl: normalizedDetailUrl,
                        mode: mode,
                        updatedAt: DateTime.now(),
                      ),
                    );
                    await _loadCurrentChapter(
                      initialScrollRatio: _currentScrollRatio(),
                    );
                  } catch (error) {
                    if (!mounted) {
                      return;
                    }
                    _showMessage('保存净化策略失败：$error');
                  } finally {
                    if (mounted) {
                      setModalState(() {
                        isSavingReaderReplaceRuleMode = false;
                      });
                    } else {
                      isSavingReaderReplaceRuleMode = false;
                    }
                  }
                }

                final quickToggleCard = buildSettingsSectionCard(
                  icon: Icons.toggle_on_rounded,
                  title: '快捷开关',
                  children: [
                    buildCompactToggleRow(
                      label: '自动换源',
                      value: draftAutoSwitchSourceOnFailureEnabled,
                      isSaving: isSavingAutoSwitchSourceOnFailure,
                      onChanged:
                          isSavingAutoSwitchSourceOnFailure
                              ? null
                              : (value) => unawaited(
                                updateAutoSwitchSourceOnFailure(value),
                              ),
                    ),
                    buildSectionDivider(),
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
                    initialTab == _ReaderSettingsTab.interface;
                final selectedCards =
                    showInterfaceSettings
                        ? <Widget>[
                          interfaceCards[0],
                          interfaceCards[1],
                          readingCards[0],
                          readingCards[1],
                          readingCards[2],
                        ]
                        : <Widget>[
                          buildSettingsSectionCard(
                            icon: Icons.cleaning_services_outlined,
                            title: '本章净化',
                            subtitle: '查看当前章节命中的用户净化规则',
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: ReaderReplaceRuleMode.values
                                    .map(
                                      (mode) => ChoiceChip(
                                        label: Text(replaceRuleModeLabel(mode)),
                                        selected:
                                            draftReaderReplaceRuleMode == mode,
                                        onSelected:
                                            isSavingReaderReplaceRuleMode
                                                ? null
                                                : (_) => unawaited(
                                                  updateReaderReplaceRuleMode(
                                                    mode,
                                                  ),
                                                ),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                              if (isSavingReaderReplaceRuleMode) ...[
                                const SizedBox(height: 8),
                                const LinearProgressIndicator(minHeight: 2),
                              ],
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  buildSummaryAction(
                                    icon: Icons.rule_folder_outlined,
                                    label: '命中',
                                    value:
                                        _effectiveReaderReplaceRules.isEmpty
                                            ? '无'
                                            : '${_effectiveReaderReplaceRules.length} 条',
                                    onTap:
                                        () => unawaited(
                                          _showEffectiveReaderReplaceRulesSheet(),
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '当前策略：${replaceRuleModeLabel(draftReaderReplaceRuleMode)}。\n'
                                '${_effectiveReaderReplaceRules.isEmpty ? '当前章节没有命中用户净化规则。' : '已命中：${_effectiveReaderReplaceRules.map((item) => item.name).join('、')}'}',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                          quickToggleCard,
                          interfaceCards[2],
                          readingCards[3],
                        ];
                final sheetTitle = showInterfaceSettings ? '界面设置' : '设置';

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
                          constraints: const BoxConstraints(maxWidth: 760),
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
                                    sheetTitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
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
                                  showInterfaceSection ? '界面' : '阅读设置',
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
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Slider(
                                                min: 0.2,
                                                max: 1,
                                                divisions: 8,
                                                value: draft.brightness,
                                                onChanged: (value) {
                                                  setModalState(() {
                                                    draft = draft.copyWith(
                                                      brightness: value,
                                                    );
                                                  });
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            FilterChip(
                                              label: const Text('护眼'),
                                              selected:
                                                  draft.themeMode ==
                                                  ReaderThemeMode.sepia,
                                              onSelected: (selected) {
                                                setModalState(() {
                                                  draft = draft.copyWith(
                                                    themeMode:
                                                        selected
                                                            ? ReaderThemeMode
                                                                .sepia
                                                            : ReaderThemeMode
                                                                .light,
                                                    backgroundStyle:
                                                        selected
                                                            ? ReaderBackgroundStyle
                                                                .warm
                                                            : ReaderBackgroundStyle
                                                                .plain,
                                                    backgroundTone:
                                                        selected
                                                            ? ReaderBackgroundTone
                                                                .container
                                                            : ReaderBackgroundTone
                                                                .surface,
                                                  );
                                                });
                                              },
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
                                            children: [
                                              _buildThemeColorDot(
                                                draft: draft,
                                                color: const Color(0xFFFDFDFD),
                                                label: '明亮',
                                                mode: ReaderThemeMode.light,
                                                backgroundStyle:
                                                    ReaderBackgroundStyle.plain,
                                                backgroundTone:
                                                    ReaderBackgroundTone
                                                        .surface,
                                                onChanged: (next) {
                                                  setModalState(() {
                                                    draft = next;
                                                  });
                                                },
                                              ),
                                              _buildThemeColorDot(
                                                draft: draft,
                                                color: const Color(0xFFF7EEDC),
                                                label: '护眼',
                                                mode: ReaderThemeMode.sepia,
                                                backgroundStyle:
                                                    ReaderBackgroundStyle.warm,
                                                backgroundTone:
                                                    ReaderBackgroundTone
                                                        .container,
                                                onChanged: (next) {
                                                  setModalState(() {
                                                    draft = next;
                                                  });
                                                },
                                              ),
                                              _buildThemeColorDot(
                                                draft: draft,
                                                color: const Color(0xFFE8EDF5),
                                                label: '浅灰',
                                                mode: ReaderThemeMode.light,
                                                backgroundStyle:
                                                    ReaderBackgroundStyle.paper,
                                                backgroundTone:
                                                    ReaderBackgroundTone
                                                        .containerHigh,
                                                onChanged: (next) {
                                                  setModalState(() {
                                                    draft = next;
                                                  });
                                                },
                                              ),
                                              _buildThemeColorDot(
                                                draft: draft,
                                                color: const Color(0xFF242831),
                                                label: '夜间',
                                                mode: ReaderThemeMode.dark,
                                                backgroundStyle:
                                                    ReaderBackgroundStyle.plain,
                                                backgroundTone:
                                                    ReaderBackgroundTone
                                                        .containerHigh,
                                                onChanged: (next) {
                                                  setModalState(() {
                                                    draft = next;
                                                  });
                                                },
                                              ),
                                              _buildThemeColorDot(
                                                draft: draft,
                                                color: const Color(0xFF16181D),
                                                label: '深夜',
                                                mode: ReaderThemeMode.dark,
                                                backgroundStyle:
                                                    ReaderBackgroundStyle.plain,
                                                backgroundTone:
                                                    ReaderBackgroundTone
                                                        .containerHighest,
                                                onChanged: (next) {
                                                  setModalState(() {
                                                    draft = next;
                                                  });
                                                },
                                              ),
                                              _buildThemeColorDot(
                                                draft: draft,
                                                color: const Color(0xFF000000),
                                                label: '纯黑',
                                                mode: ReaderThemeMode.dark,
                                                backgroundStyle:
                                                    ReaderBackgroundStyle.plain,
                                                backgroundTone:
                                                    ReaderBackgroundTone
                                                        .pureBlack,
                                                onChanged: (next) {
                                                  setModalState(() {
                                                    draft = next;
                                                  });
                                                },
                                              ),
                                            ],
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
                                                        removeActiveBackground,
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
                                                  value: fontWeightLevelLabel(
                                                    draft.fontWeightLevel,
                                                  ),
                                                  onTap:
                                                      () => unawaited(
                                                        openFontWeightTabSheet(),
                                                      ),
                                                ),
                                                buildReadingActionTab(
                                                  label: '边距',
                                                  value:
                                                      '${draft.bodyMarginLeft.round()}/${draft.bodyMarginRight.round()}',
                                                  onTap:
                                                      () => unawaited(
                                                        openHorizontalPaddingTabSheet(),
                                                      ),
                                                ),
                                                buildReadingActionTab(
                                                  label: '信息',
                                                  value:
                                                      draft.infoHeaderEnabled ||
                                                              draft
                                                                  .infoFooterEnabled
                                                          ? '开'
                                                          : '关',
                                                  onTap:
                                                      () => unawaited(
                                                        openInfoTabSheet(),
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
                                            if (!isMangaChapter &&
                                                _pageTurnUsesScroll(
                                                  draft.pageTurnMode,
                                                ))
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 6,
                                                ),
                                                child: Text(
                                                  '滚动触发模式下不使用分页动画',
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
                                            buildPageAnimationSelector(),
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
                                                      children: [
                                                        ChoiceChip(
                                                          label: const Text(
                                                            '日间',
                                                          ),
                                                          selected:
                                                              draft.themeMode ==
                                                                  ReaderThemeMode
                                                                      .light &&
                                                              draft.backgroundStyle ==
                                                                  ReaderBackgroundStyle
                                                                      .plain,
                                                          onSelected: (_) {
                                                            setModalState(() {
                                                              draft = draft.copyWith(
                                                                themeMode:
                                                                    ReaderThemeMode
                                                                        .light,
                                                                backgroundStyle:
                                                                    ReaderBackgroundStyle
                                                                        .plain,
                                                                backgroundTone:
                                                                    ReaderBackgroundTone
                                                                        .surface,
                                                                clearBackgroundImage:
                                                                    true,
                                                              );
                                                            });
                                                          },
                                                        ),
                                                        ChoiceChip(
                                                          label: const Text(
                                                            '护眼',
                                                          ),
                                                          selected:
                                                              draft.themeMode ==
                                                              ReaderThemeMode
                                                                  .sepia,
                                                          onSelected: (_) {
                                                            setModalState(() {
                                                              draft = draft.copyWith(
                                                                themeMode:
                                                                    ReaderThemeMode
                                                                        .sepia,
                                                                backgroundStyle:
                                                                    ReaderBackgroundStyle
                                                                        .warm,
                                                                backgroundTone:
                                                                    ReaderBackgroundTone
                                                                        .container,
                                                                clearBackgroundImage:
                                                                    true,
                                                              );
                                                            });
                                                          },
                                                        ),
                                                        ChoiceChip(
                                                          label: const Text(
                                                            '夜间',
                                                          ),
                                                          selected:
                                                              draft.themeMode ==
                                                              ReaderThemeMode
                                                                  .dark,
                                                          onSelected: (_) {
                                                            setModalState(() {
                                                              draft = draft.copyWith(
                                                                themeMode:
                                                                    ReaderThemeMode
                                                                        .dark,
                                                                backgroundStyle:
                                                                    ReaderBackgroundStyle
                                                                        .plain,
                                                                backgroundTone:
                                                                    ReaderBackgroundTone
                                                                        .containerHigh,
                                                                clearBackgroundImage:
                                                                    true,
                                                              );
                                                            });
                                                          },
                                                        ),
                                                        ChoiceChip(
                                                          label: const Text(
                                                            '纯黑',
                                                          ),
                                                          selected:
                                                              draft.themeMode ==
                                                                  ReaderThemeMode
                                                                      .dark &&
                                                              draft.backgroundTone ==
                                                                  ReaderBackgroundTone
                                                                      .pureBlack,
                                                          onSelected: (_) {
                                                            setModalState(() {
                                                              draft = draft.copyWith(
                                                                themeMode:
                                                                    ReaderThemeMode
                                                                        .dark,
                                                                backgroundStyle:
                                                                    ReaderBackgroundStyle
                                                                        .plain,
                                                                backgroundTone:
                                                                    ReaderBackgroundTone
                                                                        .pureBlack,
                                                                clearBackgroundImage:
                                                                    true,
                                                              );
                                                            });
                                                          },
                                                        ),
                                                      ],
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
    final restoredBackground = appliedResult.backgroundImageBase64?.trim();
    if (appliedResult.themeMode != ReaderThemeMode.dark &&
        restoredBackground != null &&
        restoredBackground.isNotEmpty) {
      _lightModeBackgroundImageBackup = restoredBackground;
    }
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
        stackOnCompact && MediaQuery.sizeOf(context).width < 430;
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

  Widget _buildThemeColorDot({
    required ReaderSettings draft,
    required Color color,
    required String label,
    required ReaderThemeMode mode,
    required ReaderBackgroundStyle backgroundStyle,
    required ReaderBackgroundTone backgroundTone,
    required ValueChanged<ReaderSettings> onChanged,
  }) {
    final selected =
        draft.themeMode == mode &&
        draft.backgroundStyle == backgroundStyle &&
        draft.backgroundTone == backgroundTone;

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
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child:
              selected
                  ? Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: mode == ReaderThemeMode.dark ? Colors.white : null,
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
  }) {
    final image =
        previewBytes == null
            ? null
            : DecorationImage(
              image: MemoryImage(previewBytes),
              fit: BoxFit.cover,
            );

    final tile = Container(
      width: _kBackgroundTileWidth,
      height: _kBackgroundTileHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
          width: selected ? 2 : 1,
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
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      if (showLabel) ...[
                        const SizedBox(height: 2),
                        Text(
                          label,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ],
                  )
                  : Text(label, style: Theme.of(context).textTheme.labelSmall))
              : (!showLabel
                  ? const SizedBox.expand()
                  : Container(
                    width: double.infinity,
                    height: double.infinity,
                    alignment: Alignment.bottomCenter,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0x7A000000)],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        label,
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: Colors.white),
                      ),
                    ),
                  )),
    );

    if (onTap == null) {
      return tile;
    }
    return GestureDetector(onTap: onTap, child: tile);
  }

  Future<String?> _pickBackgroundImageBase64() async {
    try {
      const maxBytes = 900 * 1024;
      final picked = await _imageSelectionService.pickImage(
        confirmButtonText: '选择背景',
      );
      if (picked == null) {
        return null;
      }

      final Uint8List bytes = picked.bytes;
      if (bytes.isEmpty) {
        _showMessage('背景图片读取失败。');
        return null;
      }

      if (bytes.length > maxBytes) {
        _showMessage('图片过大，请选择 900KB 以内图片。');
        return null;
      }

      return base64Encode(bytes);
    } on ImageSelectionException catch (error) {
      _showMessage(error.message);
      return null;
    } on PlatformException catch (error) {
      _showMessage('选择背景失败：${error.message ?? error.code}');
      return null;
    } catch (error) {
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
    required String unit,
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
      unit: 'em',
    );
  }

  double _lineHeightSliderValue(ReaderSettings settings) {
    final safeFontSize = settings.fontSize <= 0 ? 18.0 : settings.fontSize;
    return (((settings.lineHeight - 1) * safeFontSize).clamp(0, 20)).toDouble();
  }

  double _lineHeightFromSliderValue({
    required double sliderValue,
    required ReaderSettings settings,
  }) {
    final safeFontSize = settings.fontSize <= 0 ? 18.0 : settings.fontSize;
    return ((safeFontSize + sliderValue) / safeFontSize).toDouble();
  }

  String _lineHeightValueLabel(ReaderSettings settings) {
    return _formatTypographyValue(
      value: settings.lineHeight,
      fractionDigits: 2,
      unit: 'x',
    );
  }

  String _paragraphSpacingValueLabel(ReaderSettings settings) {
    return _formatTypographyValue(
      value: settings.paragraphSpacing,
      fractionDigits: 0,
      unit: 'px',
    );
  }

  String _paragraphIndentVisualLabel(int indentCount) {
    final safeCount = indentCount.clamp(0, 8).toInt();
    if (safeCount <= 0) {
      return '无缩进';
    }
    return '$safeCount格';
  }

  String _paragraphIndentValueLabel(ReaderSettings settings) {
    return _paragraphIndentVisualLabel(settings.paragraphIndent.round());
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
      ReaderPageAnimationStyle.curl => '卷页',
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
    return switch (tone) {
      ReaderBackgroundTone.surface => scheme.surface,
      ReaderBackgroundTone.containerLow => scheme.surfaceContainerLow,
      ReaderBackgroundTone.container => scheme.surfaceContainer,
      ReaderBackgroundTone.containerHigh => scheme.surfaceContainerHigh,
      ReaderBackgroundTone.containerHighest => scheme.surfaceContainerHighest,
      ReaderBackgroundTone.pureBlack => const Color(0xFF000000),
    };
  }

  Color _overlayForTone(ColorScheme scheme, ReaderBackgroundTone tone) {
    return switch (tone) {
      ReaderBackgroundTone.surface => scheme.surfaceContainerLow,
      ReaderBackgroundTone.containerLow => scheme.surfaceContainer,
      ReaderBackgroundTone.container => scheme.surfaceContainerHigh,
      ReaderBackgroundTone.containerHigh => scheme.surfaceContainerHighest,
      ReaderBackgroundTone.containerHighest => scheme.surfaceContainerHighest,
      ReaderBackgroundTone.pureBlack => const Color(0xFF0A0A0A),
    };
  }

  Color _shiftLightness(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final shifted = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(shifted).toColor();
  }
}

class _SwitchSourceScope {
  const _SwitchSourceScope({
    required this.sourceIds,
    required this.contentMode,
  });

  final List<String> sourceIds;
  final SearchContentMode contentMode;
}

class _ReaderSourceSnapshot {
  const _ReaderSourceSnapshot({
    required this.bookId,
    required this.sourceId,
    required this.detailUrl,
    required this.bookTitle,
    required this.bookAuthor,
    required this.bookCoverUrl,
    required this.chapters,
    required this.currentIndex,
    required this.chapterId,
    required this.chapterUrl,
    required this.chapterTitle,
    required this.errorText,
    required this.isInBookshelf,
    required this.isCurrentChapterCached,
    required this.content,
    required this.chapterImageUrls,
    required this.chapterImageHeaders,
    required this.scrollRatio,
  });

  final String bookId;
  final String? sourceId;
  final String? detailUrl;
  final String bookTitle;
  final String? bookAuthor;
  final String? bookCoverUrl;
  final List<Chapter> chapters;
  final int? currentIndex;
  final String chapterId;
  final String? chapterUrl;
  final String? chapterTitle;
  final String? errorText;
  final bool isInBookshelf;
  final bool isCurrentChapterCached;
  final String content;
  final List<String> chapterImageUrls;
  final Map<String, String> chapterImageHeaders;
  final double scrollRatio;
}

class _PagedSlice {
  const _PagedSlice({
    required this.paragraphIndex,
    required this.start,
    required this.end,
  });

  final int paragraphIndex;
  final int start;
  final int end;
}

class _CatalogSearchEntry {
  const _CatalogSearchEntry({
    required this.title,
    required this.subtitle,
    required this.chapterIndex,
    this.scrollRatio,
    this.isContent = false,
  });

  final String title;
  final String subtitle;
  final int chapterIndex;
  final double? scrollRatio;
  final bool isContent;
}

class _ReaderCatalogSearchState {
  const _ReaderCatalogSearchState({
    this.keyword = '',
    this.entries = const <_CatalogSearchEntry>[],
    this.isLoading = false,
  });

  final String keyword;
  final List<_CatalogSearchEntry> entries;
  final bool isLoading;

  List<_CatalogSearchEntry> get tocEntries =>
      entries.where((entry) => !entry.isContent).toList(growable: false);

  List<_CatalogSearchEntry> get contentEntries =>
      entries.where((entry) => entry.isContent).toList(growable: false);
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
    required this.paragraphs,
    required this.isCached,
    required this.effectiveReaderReplaceRules,
  });

  final String chapterId;
  final String chapterUrl;
  final String chapterTitle;
  final String displayTitle;
  final int chapterIndex;
  final String content;
  final List<String> paragraphs;
  final bool isCached;
  final List<ReaderReplaceRule> effectiveReaderReplaceRules;
}

class _ContinuousTextChapterLayout {
  const _ContinuousTextChapterLayout({
    required this.startOffset,
    required this.endOffset,
  });

  final double startOffset;
  final double endOffset;
}

class _DecodedReaderChapterCache {
  const _DecodedReaderChapterCache({
    required this.content,
    this.imageUrls = const [],
    this.imageHeaders = const {},
  });

  final String content;
  final List<String> imageUrls;
  final Map<String, String> imageHeaders;
}

class _PrecomputedChapterLayout {
  const _PrecomputedChapterLayout({
    required this.paragraphs,
    required this.pagedPages,
    required this.paginationSignature,
  });

  final List<String> paragraphs;
  final List<List<_PagedSlice>> pagedPages;
  final String paginationSignature;
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

class _ReaderBackgroundPreset {
  const _ReaderBackgroundPreset({required this.label, required this.assetPath});

  final String label;
  final String assetPath;
}

class _PagedPageTransitionState {
  const _PagedPageTransitionState({
    this.isAnimating = false,
    this.style = ReaderPageAnimationStyle.none,
    this.direction = 1,
    this.fromIndex = 0,
    this.toIndex = 0,
  });

  final bool isAnimating;
  final ReaderPageAnimationStyle style;
  final int direction;
  final int fromIndex;
  final int toIndex;

  _PagedPageTransitionState copyWith({
    bool? isAnimating,
    ReaderPageAnimationStyle? style,
    int? direction,
    int? fromIndex,
    int? toIndex,
  }) {
    return _PagedPageTransitionState(
      isAnimating: isAnimating ?? this.isAnimating,
      style: style ?? this.style,
      direction: direction ?? this.direction,
      fromIndex: fromIndex ?? this.fromIndex,
      toIndex: toIndex ?? this.toIndex,
    );
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

class _PagedAnimationMotionSpec {
  const _PagedAnimationMotionSpec({
    required this.duration,
    required this.switchInCurve,
    required this.switchOutCurve,
  });

  final Duration duration;
  final Curve switchInCurve;
  final Curve switchOutCurve;
}

typedef _CoverTransitionBuilder =
    Widget Function({
      required Widget fromPage,
      required Widget toPage,
      required double progress,
      required double direction,
    });

abstract class _PagedAnimationEffectRenderer {
  const _PagedAnimationEffectRenderer();

  Widget build({
    required Widget fromPage,
    required Widget toPage,
    required double progress,
    required double direction,
    required _CoverTransitionBuilder coverBuilder,
  });
}

class _CoverPagedAnimationEffect extends _PagedAnimationEffectRenderer {
  const _CoverPagedAnimationEffect();

  @override
  Widget build({
    required Widget fromPage,
    required Widget toPage,
    required double progress,
    required double direction,
    required _CoverTransitionBuilder coverBuilder,
  }) {
    return coverBuilder(
      fromPage: fromPage,
      toPage: toPage,
      progress: progress,
      direction: direction,
    );
  }
}

class _HorizontalSlidePagedAnimationEffect
    extends _PagedAnimationEffectRenderer {
  const _HorizontalSlidePagedAnimationEffect();

  @override
  Widget build({
    required Widget fromPage,
    required Widget toPage,
    required double progress,
    required double direction,
    required _CoverTransitionBuilder coverBuilder,
  }) {
    final outgoingTranslation = Offset(-direction * progress, 0);
    final incomingTranslation = Offset(direction * (1 - progress), 0);
    return Stack(
      fit: StackFit.expand,
      children: [
        FractionalTranslation(
          translation: outgoingTranslation,
          child: fromPage,
        ),
        FractionalTranslation(translation: incomingTranslation, child: toPage),
      ],
    );
  }
}

class _VerticalSlidePagedAnimationEffect extends _PagedAnimationEffectRenderer {
  const _VerticalSlidePagedAnimationEffect();

  @override
  Widget build({
    required Widget fromPage,
    required Widget toPage,
    required double progress,
    required double direction,
    required _CoverTransitionBuilder coverBuilder,
  }) {
    final outgoingTranslation = Offset(0, -direction * progress);
    final incomingTranslation = Offset(0, direction * (1 - progress));
    return Stack(
      fit: StackFit.expand,
      children: [
        FractionalTranslation(
          translation: outgoingTranslation,
          child: fromPage,
        ),
        FractionalTranslation(translation: incomingTranslation, child: toPage),
      ],
    );
  }
}

class _FadePagedAnimationEffect extends _PagedAnimationEffectRenderer {
  const _FadePagedAnimationEffect();

  @override
  Widget build({
    required Widget fromPage,
    required Widget toPage,
    required double progress,
    required double direction,
    required _CoverTransitionBuilder coverBuilder,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(opacity: (1 - progress).clamp(0.0, 1.0), child: fromPage),
        Opacity(opacity: progress.clamp(0.0, 1.0), child: toPage),
      ],
    );
  }
}

class _CurlVisualMetrics {
  const _CurlVisualMetrics({
    required this.boundaryX,
    required this.curveDepth,
    required this.shadowWidth,
    required this.highlightWidth,
  });

  final double boundaryX;
  final double curveDepth;
  final double shadowWidth;
  final double highlightWidth;

  factory _CurlVisualMetrics.resolve(
    Size size, {
    required double progress,
    required int direction,
  }) {
    final clamped = progress.clamp(0.0, 1.0);
    final eased = Curves.easeInOutCubic.transform(clamped);
    final curveDepth =
        lerpDouble(
          10,
          min(size.width * 0.16, 88.0),
          Curves.easeOutCubic.transform(clamped),
        )!;
    final shadowWidth = lerpDouble(18, min(size.width * 0.2, 110.0), clamped)!;
    final highlightWidth =
        lerpDouble(8, min(size.width * 0.07, 32.0), clamped)!;

    if (direction >= 0) {
      return _CurlVisualMetrics(
        boundaryX: lerpDouble(size.width, size.width * 0.08, eased)!,
        curveDepth: curveDepth,
        shadowWidth: shadowWidth,
        highlightWidth: highlightWidth,
      );
    }

    return _CurlVisualMetrics(
      boundaryX: lerpDouble(0, size.width * 0.92, eased)!,
      curveDepth: curveDepth,
      shadowWidth: shadowWidth,
      highlightWidth: highlightWidth,
    );
  }
}

class _CurlPageClipper extends CustomClipper<Path> {
  const _CurlPageClipper({required this.progress, required this.direction});

  final double progress;
  final int direction;

  @override
  Path getClip(Size size) {
    final metrics = _CurlVisualMetrics.resolve(
      size,
      progress: progress,
      direction: direction,
    );
    final path = Path();

    if (direction >= 0) {
      path
        ..moveTo(0, 0)
        ..lineTo(metrics.boundaryX, 0)
        ..quadraticBezierTo(
          metrics.boundaryX - metrics.curveDepth * 0.18,
          size.height * 0.22,
          metrics.boundaryX - metrics.curveDepth,
          size.height * 0.5,
        )
        ..quadraticBezierTo(
          metrics.boundaryX - metrics.curveDepth * 0.18,
          size.height * 0.78,
          metrics.boundaryX,
          size.height,
        )
        ..lineTo(0, size.height)
        ..close();
      return path;
    }

    path
      ..moveTo(metrics.boundaryX, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(metrics.boundaryX, size.height)
      ..quadraticBezierTo(
        metrics.boundaryX + metrics.curveDepth * 0.18,
        size.height * 0.78,
        metrics.boundaryX + metrics.curveDepth,
        size.height * 0.5,
      )
      ..quadraticBezierTo(
        metrics.boundaryX + metrics.curveDepth * 0.18,
        size.height * 0.22,
        metrics.boundaryX,
        0,
      )
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant _CurlPageClipper oldClipper) {
    return oldClipper.progress != progress || oldClipper.direction != direction;
  }
}

class _CurlOverlayPainter extends CustomPainter {
  const _CurlOverlayPainter({
    required this.progress,
    required this.direction,
    required this.backgroundColor,
    required this.dividerColor,
    required this.overlayColor,
  });

  final double progress;
  final int direction;
  final Color backgroundColor;
  final Color dividerColor;
  final Color overlayColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) {
      return;
    }

    final metrics = _CurlVisualMetrics.resolve(
      size,
      progress: progress,
      direction: direction,
    );
    final shadowAlpha = lerpDouble(0.0, 0.22, progress)!;
    final overlayAlpha = lerpDouble(0.0, 0.16, progress)!;
    final highlightAlpha = lerpDouble(0.0, 0.18, progress)!;

    if (direction >= 0) {
      final shadowRect = Rect.fromLTRB(
        max(0, metrics.boundaryX - metrics.shadowWidth),
        0,
        min(size.width, metrics.boundaryX + metrics.highlightWidth * 0.6),
        size.height,
      );
      canvas.drawRect(
        shadowRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              overlayColor.withValues(alpha: shadowAlpha * 0.55),
              backgroundColor.withValues(alpha: overlayAlpha),
              dividerColor.withValues(alpha: highlightAlpha),
            ],
            stops: const [0, 0.45, 0.78, 1],
          ).createShader(shadowRect),
      );

      final edgePath =
          Path()
            ..moveTo(metrics.boundaryX, 0)
            ..quadraticBezierTo(
              metrics.boundaryX - metrics.curveDepth * 0.18,
              size.height * 0.22,
              metrics.boundaryX - metrics.curveDepth,
              size.height * 0.5,
            )
            ..quadraticBezierTo(
              metrics.boundaryX - metrics.curveDepth * 0.18,
              size.height * 0.78,
              metrics.boundaryX,
              size.height,
            );
      canvas.drawPath(
        edgePath,
        Paint()
          ..color = dividerColor.withValues(alpha: highlightAlpha * 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = lerpDouble(0.8, 1.6, progress)!,
      );
      return;
    }

    final shadowRect = Rect.fromLTRB(
      max(0, metrics.boundaryX - metrics.highlightWidth * 0.6),
      0,
      min(size.width, metrics.boundaryX + metrics.shadowWidth),
      size.height,
    );
    canvas.drawRect(
      shadowRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            dividerColor.withValues(alpha: highlightAlpha),
            backgroundColor.withValues(alpha: overlayAlpha),
            overlayColor.withValues(alpha: shadowAlpha * 0.55),
            Colors.transparent,
          ],
          stops: const [0, 0.22, 0.55, 1],
        ).createShader(shadowRect),
    );

    final edgePath =
        Path()
          ..moveTo(metrics.boundaryX, 0)
          ..quadraticBezierTo(
            metrics.boundaryX + metrics.curveDepth * 0.18,
            size.height * 0.22,
            metrics.boundaryX + metrics.curveDepth,
            size.height * 0.5,
          )
          ..quadraticBezierTo(
            metrics.boundaryX + metrics.curveDepth * 0.18,
            size.height * 0.78,
            metrics.boundaryX,
            size.height,
          );
    canvas.drawPath(
      edgePath,
      Paint()
        ..color = dividerColor.withValues(alpha: highlightAlpha * 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = lerpDouble(0.8, 1.6, progress)!,
    );
  }

  @override
  bool shouldRepaint(covariant _CurlOverlayPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.direction != direction ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.dividerColor != dividerColor ||
        oldDelegate.overlayColor != overlayColor;
  }
}

class _BookmarkRange {
  const _BookmarkRange(
    this.start,
    this.end, {
    required this.isBold,
    required this.isUnderline,
    required this.isWavy,
  });

  final int start;
  final int end;
  final bool isBold;
  final bool isUnderline;
  final bool isWavy;
}

class _WavyRange {
  const _WavyRange(this.start, this.end);

  final int start;
  final int end;
}

class _WavyUnderlinePainter extends CustomPainter {
  _WavyUnderlinePainter({
    required this.textPainter,
    required this.ranges,
    required this.color,
    required this.amplitude,
    required this.wavelength,
    required this.thickness,
  });

  final TextPainter textPainter;
  final List<_WavyRange> ranges;
  final Color color;
  final double amplitude;
  final double wavelength;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    if (ranges.isEmpty) {
      return;
    }

    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.round;

    for (final range in ranges) {
      final boxes = textPainter.getBoxesForSelection(
        TextSelection(baseOffset: range.start, extentOffset: range.end),
      );
      for (final box in boxes) {
        final rect = box.toRect();
        if (rect.width <= 0) {
          continue;
        }
        final baseY = rect.bottom - thickness;
        final path = Path();
        double x = rect.left;
        final endX = rect.right;
        final step = max(2.0, wavelength / 6);
        path.moveTo(x, baseY);
        while (x <= endX) {
          final t = (x - rect.left) / wavelength * 2 * pi;
          final y = baseY + sin(t) * amplitude;
          path.lineTo(x, y);
          x += step;
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WavyUnderlinePainter oldDelegate) {
    return oldDelegate.ranges != ranges ||
        oldDelegate.color != color ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.wavelength != wavelength ||
        oldDelegate.thickness != thickness;
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

class _ActiveReadingRecordSession {
  const _ActiveReadingRecordSession({
    required this.bookId,
    required this.sourceId,
    required this.detailUrl,
    required this.bookTitle,
    this.bookAuthor,
    this.coverUrl,
    required this.chapterId,
    this.chapterTitle,
    this.chapterIndex,
    required this.chapterUrl,
    required this.startAt,
    required this.startPositionRatio,
    required this.furthestPositionRatio,
  });

  final String bookId;
  final String sourceId;
  final String detailUrl;
  final String bookTitle;
  final String? bookAuthor;
  final String? coverUrl;
  final String chapterId;
  final String? chapterTitle;
  final int? chapterIndex;
  final String chapterUrl;
  final DateTime startAt;
  final double startPositionRatio;
  final double furthestPositionRatio;

  _ActiveReadingRecordSession copyWith({
    String? bookId,
    String? sourceId,
    String? detailUrl,
    String? bookTitle,
    String? bookAuthor,
    String? coverUrl,
    String? chapterId,
    String? chapterTitle,
    int? chapterIndex,
    String? chapterUrl,
    DateTime? startAt,
    double? startPositionRatio,
    double? furthestPositionRatio,
  }) {
    return _ActiveReadingRecordSession(
      bookId: bookId ?? this.bookId,
      sourceId: sourceId ?? this.sourceId,
      detailUrl: detailUrl ?? this.detailUrl,
      bookTitle: bookTitle ?? this.bookTitle,
      bookAuthor: bookAuthor ?? this.bookAuthor,
      coverUrl: coverUrl ?? this.coverUrl,
      chapterId: chapterId ?? this.chapterId,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterUrl: chapterUrl ?? this.chapterUrl,
      startAt: startAt ?? this.startAt,
      startPositionRatio: startPositionRatio ?? this.startPositionRatio,
      furthestPositionRatio:
          furthestPositionRatio ?? this.furthestPositionRatio,
    );
  }
}

class _SelectionStyle {
  const _SelectionStyle({
    required this.bold,
    required this.underline,
    required this.wavy,
  });

  final bool bold;
  final bool underline;
  final bool wavy;
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
