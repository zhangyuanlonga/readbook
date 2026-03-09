import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:battery_plus/battery_plus.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_curl_effect/page_curl_effect.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/theme/app_theme.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reader_settings.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/entities/source_definition.dart';
import '../../book/application/book_detail_service.dart';
import '../../bookshelf/application/bookshelf_service.dart';
import '../../search/application/search_hit_cache_service.dart';
import '../../search/application/search_service.dart';
import '../application/chapter_content_service.dart';
import '../application/reader_font_registry_service.dart';
import '../application/reader_preferences_service.dart';
import '../application/reader_error_center_service.dart';
import '../application/reader_system_settings_service.dart';
import '../application/reader_typography_resolver.dart';
import '../application/source_switch_score_service.dart';
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
  });

  final String bookId;
  final String chapterId;
  final String? chapterUrl;
  final String? chapterTitle;
  final String? sourceId;
  final String? detailUrl;
  final int? chapterIndex;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage>
    with TickerProviderStateMixin {
  final BookDetailService _detailService = BookDetailService();
  final ChapterContentService _contentService = ChapterContentService();
  final ReaderPreferencesService _preferencesService =
      ReaderPreferencesService();
  final ReaderFontRegistryService _fontRegistryService =
      ReaderFontRegistryService();
  final ReaderTypographyResolver _typographyResolver =
      const ReaderTypographyResolver();
  final ReaderSystemSettingsService _systemSettingsService =
      ReaderSystemSettingsService();
  final ReaderErrorCenterService _readerErrorCenterService =
      ReaderErrorCenterService.instance;
  final BookshelfService _bookshelfService = BookshelfService();
  final SearchService _switchSourceSearchService = SearchService();
  final SearchHitCacheService _searchHitCacheService = SearchHitCacheService();
  final SourceSwitchScoreService _switchSourceScoreService =
      SourceSwitchScoreService();
  final SwitchSourcePositionResolver _switchSourcePositionResolver =
      const SwitchSourcePositionResolver();
  final ScrollController _scrollController = ScrollController();
  final PageController _mangaPageController = PageController();

  late String _chapterId;
  String? _chapterUrl;
  String? _chapterTitle;
  String? _sourceId;
  String? _detailUrl;

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
  SearchCancellationToken? _activeSwitchSourceCancellationToken;
  String? _errorText;
  String _content = '';
  List<String> _paragraphs = const [];
  List<String> _chapterImageUrls = const [];
  Map<String, String> _chapterImageHeaders = const {};
  List<ReaderCustomFontEntry> _customFonts = const [];
  final Map<String, int> _mangaImageRetryNonce = <String, int>{};
  final Map<int, TransformationController> _mangaTransformControllers =
      <int, TransformationController>{};
  final Map<int, TapDownDetails> _mangaDoubleTapDetails =
      <int, TapDownDetails>{};
  final Set<int> _mangaZoomedPageIndexes = <int>{};
  int _mangaPageIndex = 0;
  ReadingProgress? _bootstrapProgress;
  Timer? _progressDebounceTimer;
  Timer? _autoReadResumeTimer;
  Timer? _readerInfoClockTimer;
  final Battery _battery = Battery();
  DateTime _readerInfoNow = DateTime.now();
  int? _readerBatteryLevel;
  bool _readerBatteryReadFailed = false;
  int _autoReadTaskToken = 0;
  int _preloadTaskToken = 0;
  bool _isAutoReadRunning = false;
  bool _isAutoReadSessionEnabled = false;
  bool _isAutoReadAdvancingChapter = false;
  double? _swipeDragStartDx;
  double? _swipeDragCurrentDx;
  ReaderPageTurnMode _pageTurnModeBeforeAutoRead = ReaderPageTurnMode.tap;
  String? _dayModeBackgroundImageBackup;
  String? _cachedBackgroundImageKey;
  MemoryImage? _cachedBackgroundImage;
  List<List<_PagedSlice>> _pagedPages = const [];
  int _currentPageIndex = 0;
  int _pageSwitchDirection = 1;
  bool _isPaginatingPages = false;
  String? _paginationSignature;
  int _paginationTaskId = 0;
  double? _pendingPageRestoreRatio;
  PageCurlController? _pageCurlController;
  Size? _pageCurlPaperSize;
  bool _isCurlAutoTurning = false;
  bool _isSystemUiVisible = true;
  late final AnimationController _curlAutoTurnController;
  double _curlAutoStartX = 0;
  double _curlAutoEndX = 0;
  double _curlAutoY = 0;
  int _curlAutoDirection = 1;
  final Map<String, Uint8List> _backgroundPresetBytes = <String, Uint8List>{};
  final Map<String, String> _backgroundPresetBase64 = <String, String>{};
  final List<_ReaderBackgroundPreset> _backgroundPresets =
      <_ReaderBackgroundPreset>[];

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
  static const double _kSwipeTurnDistanceThreshold = 42;
  static const double _kSwipeTurnVelocityThreshold = 120;
  static const double _kCoverEdgeShadowWidth = 20;
  static const double _kCoverEdgeShadowMaxAlpha = 0.22;
  static const Duration _kCurlAutoTurnDuration = Duration(milliseconds: 460);
  static const Duration _kAutoReadStepDuration = Duration(milliseconds: 520);
  static const Duration _kAutoReadResumeDelay = Duration(milliseconds: 420);
  static const int _kSwitchSourceCandidateLimit = 24;
  static const int _kSwitchSourceLagTolerance = 20;
  static const int _kSwitchSourceScoreStep = 6;
  static const int _kSwitchSourceHitCountCap = 12;
  static const int _kSwitchSourceHitCountWeight = 3;
  static const int _kAutoSwitchSourceTryLimit = 3;
  static const int _kForwardPreloadChapterCount = 2;
  static const int _kBackwardPreloadChapterCount = 1;
  static final RegExp _kSwitchSourceSpacePattern = RegExp(r'[\u3000\s]+');
  static final RegExp _kSwitchSourceSymbolPattern = RegExp(
    r'''[·•\-_:：|/\\\(\)\[\]【】<>《》"'‘’,.，。!?！？]''',
  );
  static final RegExp _kSwitchSourceChapterPattern = RegExp(
    r'第?\s*(\d{1,5})\s*章',
  );
  static final RegExp _kSwitchSourceChapterEnglishPattern = RegExp(
    r'^(chapter|chap)\s*\d{1,5}\b',
  );
  static final RegExp _kSwitchSourceNumberPattern = RegExp(r'(\d{1,5})');

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

  bool _isPagedTextReaderEnabled() {
    if (_chapterImageUrls.isNotEmpty) {
      return false;
    }
    return !_pageTurnUsesScroll(_settings.pageTurnMode);
  }

  bool _isTapPaginationEnabled() {
    return _isPagedTextReaderEnabled() &&
        _pageTurnIncludesTap(_settings.pageTurnMode);
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

  double _pinnedHeaderTotalHeight(BuildContext context) {
    return _topSafeInset(context) +
        _kPinnedHeaderTopPadding +
        _kPinnedHeaderHeight;
  }

  @override
  void initState() {
    super.initState();
    _chapterId = widget.chapterId;
    _chapterUrl = widget.chapterUrl?.trim();
    _chapterTitle = widget.chapterTitle?.trim();
    _sourceId = widget.sourceId?.trim();
    _detailUrl = widget.detailUrl?.trim();
    _currentIndex = widget.chapterIndex;
    _curlAutoTurnController = AnimationController(
      vsync: this,
      duration: _kCurlAutoTurnDuration,
    );
    _curlAutoTurnController.addListener(_onCurlAutoTurnTick);
    _curlAutoTurnController.addStatusListener(_onCurlAutoTurnStatus);
    _scrollController.addListener(_onScrollChanged);
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
    _cancelActiveSwitchSourceSearch();
    _syncSystemUiVisibility(force: true, visible: true);
    _progressDebounceTimer?.cancel();
    _autoReadResumeTimer?.cancel();
    _readerInfoClockTimer?.cancel();
    _scrollController.removeListener(_onScrollChanged);
    _stopAutoRead();
    _scrollController.dispose();
    _mangaPageController.dispose();
    _disposeMangaTransformControllers();
    _pageCurlController?.dispose();
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
                if (_showOverlayControls)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _hideOverlayControls,
                      child: const ColoredBox(color: Color(0x28000000)),
                    ),
                  ),
                _buildTopOverlay(colors),
                _buildBottomOverlay(colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/bookshelf');
  }

  Widget _buildBackgroundLayer(_ReaderThemeColors colors) {
    return DecoratedBox(decoration: _buildReaderBackgroundDecoration(colors));
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
        Colors.black.withValues(alpha: 0.08),
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
    final showInfoBar = !_isMangaChapter;

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
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  foregroundColor: colors.text,
                  backgroundColor: Colors.transparent,
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

  String _formatReaderInfoTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
    if (_isBootstrapping || _isLoadingContent) {
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

    if (_errorText != null) {
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

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
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
                return Text(
                  _applyParagraphIndent(_content),
                  style: _paragraphTextStyle(colors),
                );
              }

              final paragraph = paragraphs[index];
              final isLast = index == paragraphs.length - 1;

              return RepaintBoundary(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: isLast ? 0 : _settings.paragraphSpacing,
                  ),
                  child: Text(
                    _applyParagraphIndent(paragraph),
                    style: _paragraphTextStyle(colors),
                  ),
                ),
              );
            },
          ),
        ),
        if (_isAutoReadSessionEnabled) _buildAutoReadIndicator(colors),
      ],
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
                final top = (maxHeight * ratio).clamp(2.0, maxHeight - 2.0);

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

  bool _onReaderScrollNotification(ScrollNotification notification) {
    if (!_isAutoReadSessionEnabled || _isPagedTextReaderEnabled()) {
      return false;
    }

    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _stopAutoReadSession();
    }

    return false;
  }

  String _buildMangaImageUrl(String imageUrl, int retryNonce) {
    if (retryNonce <= 0 || imageUrl.startsWith('data:image/')) {
      return imageUrl;
    }

    final uri = Uri.tryParse(imageUrl);
    if (uri == null) {
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

    final currentIndex = _mangaPageIndex.clamp(0, pageCount - 1);
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
            child: Image.network(
              requestUrl,
              headers:
                  _chapterImageHeaders.isEmpty ? null : _chapterImageHeaders,
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
              },
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

  Duration _pageSwitchDurationForStyle(ReaderPageAnimationStyle style) {
    return switch (style) {
      ReaderPageAnimationStyle.curl => _kCurlAutoTurnDuration,
      ReaderPageAnimationStyle.cover => const Duration(milliseconds: 420),
      ReaderPageAnimationStyle.translate => const Duration(milliseconds: 330),
      ReaderPageAnimationStyle.vertical => const Duration(milliseconds: 360),
      ReaderPageAnimationStyle.fade => const Duration(milliseconds: 300),
      ReaderPageAnimationStyle.none => Duration.zero,
    };
  }

  Curve _pageSwitchInCurveForStyle(ReaderPageAnimationStyle style) {
    return switch (style) {
      ReaderPageAnimationStyle.cover => Curves.linearToEaseOut,
      ReaderPageAnimationStyle.fade => Curves.easeInOut,
      ReaderPageAnimationStyle.none => Curves.linear,
      _ => Curves.easeInOutCubic,
    };
  }

  Curve _pageSwitchOutCurveForStyle(ReaderPageAnimationStyle style) {
    return switch (style) {
      ReaderPageAnimationStyle.fade => Curves.easeInOut,
      ReaderPageAnimationStyle.none => Curves.linear,
      _ => Curves.easeInOutCubic,
    };
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
        final safeIndex = _currentPageIndex.clamp(0, pageCount - 1);
        final pagedSize = constraints.biggest;
        _pageCurlPaperSize = pagedSize;

        final animationStyle = _effectivePageAnimationStyle();
        final switchDuration = _pageSwitchDurationForStyle(animationStyle);
        final switchInCurve = _pageSwitchInCurveForStyle(animationStyle);
        final switchOutCurve = _pageSwitchOutCurveForStyle(animationStyle);

        if (animationStyle == ReaderPageAnimationStyle.curl) {
          final controller = _ensurePageCurlController(
            paperSize: pagedSize,
            pageCount: pageCount,
            initialIndex: safeIndex,
          );

          return Stack(
            children: [
              Positioned.fill(
                child: PageCurlEffect(
                  pageCurlController: controller,
                  pageBuilder: (context, index) {
                    return _buildCurlPageWidget(
                      colors: colors,
                      pageIndex: index,
                      pageSize: pagedSize,
                      padding: contentPadding,
                    );
                  },
                  onForwardComplete: () => _onCurlDragComplete(forward: true),
                  onBackwardComplete: () => _onCurlDragComplete(forward: false),
                ),
              ),
              if (pageCount > 1)
                _buildPageIndexOverlay(
                  colors: colors,
                  index: safeIndex,
                  total: pageCount,
                  bottomInset: bottomInset,
                ),
            ],
          );
        }

        final pageChild = KeyedSubtree(
          key: ValueKey<int>(safeIndex),
          child: _buildPagedPageContainer(
            colors: colors,
            pageIndex: safeIndex,
            pageSize: pagedSize,
            padding: contentPadding,
          ),
        );

        if (animationStyle == ReaderPageAnimationStyle.none) {
          return Stack(
            children: [
              Positioned.fill(child: pageChild),
              _buildPageIndexOverlay(
                colors: colors,
                index: safeIndex,
                total: pageCount,
                bottomInset: bottomInset,
              ),
            ],
          );
        }

        Widget transitionBuilder(Widget child, Animation<double> animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: switchInCurve,
            reverseCurve: switchOutCurve,
          );
          final direction = _pageSwitchDirection.toDouble().clamp(-1.0, 1.0);

          switch (animationStyle) {
            case ReaderPageAnimationStyle.cover:
              if (animation.status == AnimationStatus.reverse) {
                return child;
              }
              return _buildCoverInTransition(
                child: child,
                animation: curved,
                direction: direction,
              );
            case ReaderPageAnimationStyle.translate:
              final begin =
                  animation.status == AnimationStatus.reverse
                      ? Offset(-direction, 0)
                      : Offset(direction, 0);
              return SlideTransition(
                position: Tween<Offset>(
                  begin: begin,
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              );
            case ReaderPageAnimationStyle.vertical:
              final begin =
                  animation.status == AnimationStatus.reverse
                      ? Offset(0, -direction)
                      : Offset(0, direction);
              return SlideTransition(
                position: Tween<Offset>(
                  begin: begin,
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              );
            case ReaderPageAnimationStyle.fade:
              return FadeTransition(opacity: curved, child: child);
            case ReaderPageAnimationStyle.curl:
            case ReaderPageAnimationStyle.none:
              return FadeTransition(opacity: curved, child: child);
          }
        }

        return Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: AnimatedSwitcher(
                  duration: switchDuration,
                  switchInCurve: switchInCurve,
                  switchOutCurve: switchOutCurve,
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
                  transitionBuilder: transitionBuilder,
                  child: pageChild,
                ),
              ),
            ),
            if (pageCount > 1)
              _buildPageIndexOverlay(
                colors: colors,
                index: safeIndex,
                total: pageCount,
                bottomInset: bottomInset,
              ),
          ],
        );
      },
    );
  }

  Widget _buildCoverInTransition({
    required Widget child,
    required Animation<double> animation,
    required double direction,
  }) {
    final normalizedDirection = direction >= 0 ? 1.0 : -1.0;
    final fromRight = normalizedDirection > 0;

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, animatedChild) {
        final progress = animation.value.clamp(0.0, 1.0);
        final translateX = normalizedDirection * (1 - progress);
        final shadowAlpha = (1 - progress) * _kCoverEdgeShadowMaxAlpha;

        return FractionalTranslation(
          translation: Offset(translateX, 0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (animatedChild != null) animatedChild,
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
        );
      },
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
            _buildPinnedChapterHeader(colors),
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

    return Text(displayText, style: _paragraphTextStyle(colors));
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
        color: colors.text.withValues(alpha: 0.78),
        fontSize: 12,
        fontWeight: FontWeight.w500,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndexOverlay({
    required _ReaderThemeColors colors,
    required int index,
    required int total,
    required double bottomInset,
  }) {
    final platform = Theme.of(context).platform;
    final safeBottomInset = max(
      bottomInset,
      _effectiveBottomSafeInset(context),
    );
    final collapsedTextBottomPadding =
        platform == TargetPlatform.iOS
            ? (safeBottomInset - 8).clamp(0.0, 64.0)
            : 4.0 + safeBottomInset;
    final collapsedStripHeight = collapsedTextBottomPadding + 22.0;
    final bottomOffset = _showOverlayControls ? 78.0 + safeBottomInset : 0.0;

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottomOffset,
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          opacity: _showOverlayControls ? 0.78 : 1,
          child:
              _showOverlayControls
                  ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: _buildPageIndexBadge(
                        colors: colors,
                        index: index,
                        total: total,
                      ),
                    ),
                  )
                  : SizedBox(
                    height: collapsedStripHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  colors.background.withValues(alpha: 0),
                                  colors.background.withValues(alpha: 0.72),
                                  colors.background.withValues(alpha: 0.96),
                                ],
                                stops: const [0, 0.55, 1],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 14,
                          bottom: collapsedTextBottomPadding,
                          child: _buildPageIndexBadge(
                            colors: colors,
                            index: index,
                            total: total,
                          ),
                        ),
                      ],
                    ),
                  ),
        ),
      ),
    );
  }

  PageCurlController _ensurePageCurlController({
    required Size paperSize,
    required int pageCount,
    required int initialIndex,
  }) {
    final safeIndex = initialIndex.clamp(0, pageCount - 1);
    final existing = _pageCurlController;

    final needsNewController =
        existing == null ||
        existing.paperSize != paperSize ||
        existing.numberOfPage != pageCount;

    if (needsNewController) {
      existing?.dispose();
      final controller = PageCurlController(
        paperSize,
        pageCurlIndex: safeIndex,
        numberOfPage: pageCount,
      );
      _pageCurlController = controller;
      _pageCurlPaperSize = paperSize;
      return controller;
    }

    if (existing.pageCurlIndex != safeIndex) {
      existing.pageCurlIndex = safeIndex;
    }
    _pageCurlPaperSize = paperSize;
    return existing;
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
            _buildPinnedChapterHeader(colors),
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

  void _onCurlDragComplete({required bool forward}) {
    if (!mounted) {
      return;
    }

    final controller = _pageCurlController;
    if (controller == null) {
      return;
    }

    final nextIndex = controller.pageCurlIndex.clamp(0, _pagedPages.length - 1);

    setState(() {
      _currentPageIndex = nextIndex;
    });
    _scheduleProgressSave();
  }

  void _onCurlAutoTurnTick() {
    if (!_isCurlAutoTurning) {
      return;
    }

    final controller = _pageCurlController;
    final size = _pageCurlPaperSize;
    if (controller == null || size == null) {
      return;
    }
    final t = Curves.easeInOutCubic.transform(_curlAutoTurnController.value);
    final x = _curlAutoStartX + (_curlAutoEndX - _curlAutoStartX) * t;

    try {
      controller.onAutoPanUpdate(Offset(x, _curlAutoY));
    } catch (error, stackTrace) {
      _abortCurlAutoTurn(
        controller: controller,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _onCurlAutoTurnStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_isCurlAutoTurning) {
      return;
    }

    final controller = _pageCurlController;
    if (controller == null || !mounted) {
      _isCurlAutoTurning = false;
      return;
    }

    controller.reset();
    if (_curlAutoDirection > 0) {
      controller.onForwardComplete();
    } else {
      controller.onBackwardComplete();
    }

    final pageCount = _pagedPages.length;
    final nextIndex = controller.pageCurlIndex.clamp(0, pageCount - 1);

    setState(() {
      _isCurlAutoTurning = false;
      _currentPageIndex = nextIndex;
    });
    _scheduleProgressSave();
  }

  void _abortCurlAutoTurn({
    required PageCurlController controller,
    required Object error,
    StackTrace? stackTrace,
  }) {
    if (!_isCurlAutoTurning) {
      return;
    }

    debugPrint("Page curl auto turn failed: ");
    if (stackTrace != null) {
      debugPrint("");
    }

    _curlAutoTurnController.stop();
    controller.reset();

    final pages = _pagedPages;
    final nextIndex = (_currentPageIndex + _curlAutoDirection).clamp(
      0,
      pages.isEmpty ? 0 : pages.length - 1,
    );

    if (pages.isNotEmpty) {
      controller.pageCurlIndex = nextIndex;
    }

    if (!mounted) {
      _isCurlAutoTurning = false;
      _currentPageIndex = nextIndex;
      return;
    }

    setState(() {
      _isCurlAutoTurning = false;
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

    final size = _pageCurlPaperSize;
    if (size == null) {
      setState(() {
        _currentPageIndex = (_currentPageIndex + direction).clamp(
          0,
          pages.length - 1,
        );
      });
      _scheduleProgressSave();
      return;
    }

    final currentIndex = _currentPageIndex.clamp(0, pages.length - 1);
    if (direction < 0 && currentIndex <= 0) {
      final index = _currentIndex;
      if (index == null || index <= 0) {
        _showMessage('已经是第一章。');
        return;
      }
      await _jumpTo(index - 1, initialScrollRatio: 1);
      return;
    }

    if (direction > 0 && currentIndex >= pages.length - 1) {
      final index = _currentIndex;
      if (index == null || index >= _chapters.length - 1) {
        _showMessage('已经是最后一章。');
        return;
      }
      await _jumpTo(index + 1, initialScrollRatio: 0);
      return;
    }

    final controller = _ensurePageCurlController(
      paperSize: size,
      pageCount: pages.length,
      initialIndex: currentIndex,
    );

    controller.reset();
    controller.pageCurlIndex = currentIndex;

    _curlAutoDirection = direction;

    final safeEdgePadding = (size.width * 0.05).clamp(28.0, 60.0).toDouble();
    _curlAutoY = (size.height * 0.5).clamp(24.0, size.height - 24.0).toDouble();
    _curlAutoStartX =
        direction > 0 ? size.width - safeEdgePadding : safeEdgePadding;
    _curlAutoEndX = direction > 0 ? -size.width : size.width;

    setState(() {
      _isCurlAutoTurning = true;
    });

    _curlAutoTurnController.forward(from: 0);
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

  String _buildPaginationSignature({
    required double maxWidth,
    required double maxHeight,
  }) {
    return [
      _chapterId,
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

    if (paragraphs.isEmpty || paragraphs.first.trim().isEmpty) {
      if (!mounted || taskId != _paginationTaskId) {
        return;
      }
      setState(() {
        _isPaginatingPages = false;
        _pagedPages = const [];
      });
      return;
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
      if (!mounted || taskId != _paginationTaskId) {
        return;
      }

      final paragraph = paragraphs[paragraphIndex];
      if (paragraph.trim().isEmpty) {
        continue;
      }

      var offset = 0;
      while (offset < paragraph.length) {
        if (!mounted || taskId != _paginationTaskId) {
          return;
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

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp:
              (details) => _onReaderTap(
                details.localPosition,
                constraints.biggest,
                gestureInsets,
              ),
          onHorizontalDragStart:
              enableSwipeTurn
                  ? (details) {
                    _swipeDragStartDx = details.localPosition.dx;
                    _swipeDragCurrentDx = details.localPosition.dx;
                  }
                  : null,
          onHorizontalDragUpdate:
              enableSwipeTurn
                  ? (details) {
                    _swipeDragCurrentDx = details.localPosition.dx;
                  }
                  : null,
          onHorizontalDragCancel:
              enableSwipeTurn
                  ? () {
                    _swipeDragStartDx = null;
                    _swipeDragCurrentDx = null;
                  }
                  : null,
          onHorizontalDragEnd:
              enableSwipeTurn
                  ? (details) =>
                      _onSwipePaginationDragEnd(details, constraints.biggest)
                  : null,
          onLongPress:
              _isMangaChapter
                  ? () => unawaited(_openMangaPositionSheet())
                  : null,
          child: child,
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

  TextStyle _paragraphTextStyle(_ReaderThemeColors colors) {
    return _typographyResolver.resolveBodyStyle(
      settings: _settings,
      color: colors.text,
    );
  }

  String _applyParagraphIndent(String paragraph) {
    final indentCount = _settings.paragraphIndent.round();
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

    return normalized
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('缺少目录信息，无法缓存。')));
      return;
    }

    final total = _chapters.length;
    final startIndex = (_currentIndex ?? 0).clamp(0, max(0, total - 1)).toInt();
    final endIndex = min(total - 1, startIndex + 49);

    await showChapterCacheFlow(
      context: context,
      bookId: widget.bookId,
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
    final lookupStateNotifier = ValueNotifier<_ReaderSwitchSourceLookupState>(
      _ReaderSwitchSourceLookupState.loading(
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

    _ReaderSourceSwitchCandidate? selected;
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
    required ValueNotifier<_ReaderSwitchSourceLookupState> lookupStateNotifier,
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

          lookupStateNotifier.value = _ReaderSwitchSourceLookupState(
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
      lookupStateNotifier.value = _ReaderSwitchSourceLookupState(
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
      lookupStateNotifier.value = _ReaderSwitchSourceLookupState(
        isLoading: false,
        sourceCount: scope.sourceIds.length,
        processedSourceCount: 0,
        candidates: const <_ReaderSourceSwitchCandidate>[],
        errorText: '查找可切换书源失败：${error.briefMessage}',
        scoreRankingEnabled: scoreRankingEnabled,
      );
    } catch (_) {
      if (cancellationToken.isCancelled) {
        return;
      }
      lookupStateNotifier.value = _ReaderSwitchSourceLookupState(
        isLoading: false,
        sourceCount: scope.sourceIds.length,
        processedSourceCount: 0,
        candidates: const <_ReaderSourceSwitchCandidate>[],
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

  List<_ReaderSourceSwitchCandidate> _buildSwitchSourceCandidates({
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
    final normalizedTargetTitle = _normalizeSwitchSourceText(targetTitle);
    final normalizedTargetAuthor = _normalizeSwitchSourceText(
      targetAuthor ?? '',
    );

    final bestBySource = <String, _ReaderSourceSwitchCandidate>{};
    for (final book in books) {
      if (book.sourceId == currentSourceId) {
        continue;
      }

      final baseScore = _scoreSwitchSourceCandidate(
        book,
        normalizedTargetTitle: normalizedTargetTitle,
        normalizedTargetAuthor: normalizedTargetAuthor,
      );
      final hitCount = hitCountBySource[book.sourceId] ?? 0;
      final sourceScore = scoreStore.sourceScores[book.sourceId] ?? 0;
      final bookScore =
          scoreStore.bookScores[_switchSourceScoreService.buildBookScoreKey(
            sourceId: book.sourceId,
            title: book.title,
            author: book.author,
          )] ??
          0;
      final score = _composeSwitchSourceCandidateScore(
        baseScore: baseScore,
        hitCount: hitCount,
        sourceScore: sourceScore,
        bookScore: bookScore,
        scoreRankingEnabled: scoreRankingEnabled,
      );
      final latestChapterLabel = _formatSwitchSourceLatestChapter(
        book.latestChapter,
      );
      final latestChapterNumber = _extractSwitchSourceChapterNumber(
        latestChapterLabel,
      );
      final isPotentiallyOutdated =
          currentChapterCount > 0 &&
          latestChapterNumber != null &&
          latestChapterNumber + _kSwitchSourceLagTolerance <
              currentChapterCount;

      final candidate = _ReaderSourceSwitchCandidate(
        book: book,
        sourceName: sourceNames[book.sourceId] ?? book.sourceId,
        baseScore: baseScore,
        score: score,
        hitCount: hitCount,
        sourceScore: sourceScore,
        bookScore: bookScore,
        latestChapterLabel: latestChapterLabel,
        latestChapterNumber: latestChapterNumber,
        isPotentiallyOutdated: isPotentiallyOutdated,
      );

      final existing = bestBySource[book.sourceId];
      if (existing == null || candidate.score > existing.score) {
        bestBySource[book.sourceId] = candidate;
      }
    }

    final candidates = _sortSwitchSourceCandidates(
      bestBySource.values.toList(growable: false),
    );

    if (candidates.length <= _kSwitchSourceCandidateLimit) {
      return candidates;
    }
    return candidates
        .take(_kSwitchSourceCandidateLimit)
        .toList(growable: false);
  }

  List<_ReaderSourceSwitchCandidate> _sortSwitchSourceCandidates(
    List<_ReaderSourceSwitchCandidate> candidates,
  ) {
    candidates.sort((a, b) {
      final scoreDiff = b.score.compareTo(a.score);
      if (scoreDiff != 0) {
        return scoreDiff;
      }
      final latestDiff = (b.latestChapterNumber ?? -1).compareTo(
        a.latestChapterNumber ?? -1,
      );
      if (latestDiff != 0) {
        return latestDiff;
      }
      return a.sourceName.compareTo(b.sourceName);
    });
    return candidates;
  }

  int _composeSwitchSourceCandidateScore({
    required int baseScore,
    required int hitCount,
    required int sourceScore,
    required int bookScore,
    required bool scoreRankingEnabled,
  }) {
    final hitBonus = _resolveSwitchSourceHitBonus(hitCount);
    if (!scoreRankingEnabled) {
      return baseScore + hitBonus;
    }
    return baseScore + hitBonus + sourceScore + bookScore;
  }

  int _resolveSwitchSourceHitBonus(int hitCount) {
    final normalizedCount = max(0, hitCount);
    final capped = min(_kSwitchSourceHitCountCap, normalizedCount);
    return capped * _kSwitchSourceHitCountWeight;
  }

  int _scoreSwitchSourceCandidate(
    Book book, {
    required String normalizedTargetTitle,
    required String normalizedTargetAuthor,
  }) {
    final normalizedTitle = _normalizeSwitchSourceText(book.title);
    var score = 0;

    if (normalizedTargetTitle.isEmpty) {
      score += 40;
    } else if (normalizedTitle == normalizedTargetTitle) {
      score += 140;
    } else if (normalizedTitle.startsWith(normalizedTargetTitle) ||
        normalizedTargetTitle.startsWith(normalizedTitle)) {
      score += 110;
    } else if (normalizedTitle.contains(normalizedTargetTitle) ||
        normalizedTargetTitle.contains(normalizedTitle)) {
      score += 85;
    } else {
      score += 50;
    }

    final normalizedAuthor = _normalizeSwitchSourceText(book.author ?? '');
    if (normalizedTargetAuthor.isNotEmpty && normalizedAuthor.isNotEmpty) {
      if (normalizedAuthor == normalizedTargetAuthor) {
        score += 24;
      } else if (normalizedAuthor.contains(normalizedTargetAuthor) ||
          normalizedTargetAuthor.contains(normalizedAuthor)) {
        score += 12;
      }
    }

    if (book.latestChapter?.trim().isNotEmpty == true) {
      score += 2;
    }

    return score;
  }

  Future<String?> _resolveSwitchSourceSearchKeyword({
    required String currentSourceId,
    required String currentDetailUrl,
  }) async {
    final currentTitle = _bookTitle.trim();
    if (_isSwitchSourceBookTitleUsable(currentTitle)) {
      return currentTitle;
    }

    try {
      final detailResult = await _detailService.load(
        sourceId: currentSourceId,
        bookId: widget.bookId,
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

  String _normalizeSwitchSourceText(String text) {
    return text
        .trim()
        .toLowerCase()
        .replaceAll(_kSwitchSourceSpacePattern, '')
        .replaceAll(_kSwitchSourceSymbolPattern, '');
  }

  String _formatSwitchSourceLatestChapter(String? latestChapter) {
    final normalized = latestChapter?.replaceAll(
      _kSwitchSourceSpacePattern,
      ' ',
    );
    final text = normalized?.trim() ?? '';
    if (text.isEmpty) {
      return '未知';
    }
    return text;
  }

  int? _extractSwitchSourceChapterNumber(String text) {
    final chapterMatch = _kSwitchSourceChapterPattern.firstMatch(text);
    if (chapterMatch != null) {
      return int.tryParse(chapterMatch.group(1)!);
    }
    final numberMatch = _kSwitchSourceNumberPattern.firstMatch(text);
    if (numberMatch != null) {
      return int.tryParse(numberMatch.group(1)!);
    }
    return null;
  }

  Future<_ReaderSourceSwitchCandidate?> _showSwitchSourceCandidateSheet(
    ValueNotifier<_ReaderSwitchSourceLookupState> lookupStateNotifier, {
    required SourceSwitchScoreStore scoreStore,
    required bool scoreRankingEnabled,
  }) async {
    _stopAutoReadSession();
    final shouldRestoreOverlay = _showOverlayControls;
    if (shouldRestoreOverlay) {
      _hideOverlayControls(resumeAutoRead: false, syncSystemUi: false);
    }

    final readerModalTheme = _readerModalTheme();
    final selected = await showModalBottomSheet<_ReaderSourceSwitchCandidate>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: readerModalTheme.colorScheme.surface,
      builder: (context) {
        final horizontal = AppSpacing.pageHorizontal(context);
        final bottomInset = _bottomSafeInset(context);
        final heightFactor = _adaptiveReaderSheetHeightFactor(
          context,
          compact: 0.92,
          regular: 0.88,
          large: 0.84,
        );

        return Theme(
          data: readerModalTheme,
          child: FractionallySizedBox(
            heightFactor: heightFactor,
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, 12),
              child: ValueListenableBuilder<_ReaderSwitchSourceLookupState>(
                valueListenable: lookupStateNotifier,
                builder: (context, lookupState, _) {
                  final candidates = lookupState.candidates;
                  final colorScheme = Theme.of(context).colorScheme;
                  final progressText =
                      lookupState.sourceCount <= 0
                          ? '正在准备书源列表...'
                          : '已扫描 ${lookupState.processedSourceCount}/${lookupState.sourceCount} 个书源';
                  final emptyMessage =
                      lookupState.errorText ?? '没有检索到可切换书源，请稍后重试。';

                  return Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '切换书源（${candidates.length}）',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '当前书名：${_bookTitle.trim().isEmpty ? '未知' : _bookTitle}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '当前目录：${_chapters.length} 章',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          progressText,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          lookupState.scoreRankingEnabled
                              ? '评分排序：已启用（匹配分 + 源评分 + 本书评分）'
                              : '评分排序：已关闭（仅按匹配分排序）',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child:
                            candidates.isEmpty
                                ? lookupState.isLoading
                                    ? _buildSwitchSourceLoadingPlaceholderList(
                                      colorScheme,
                                    )
                                    : Center(
                                      child: Text(
                                        emptyMessage,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    )
                                : ListView.separated(
                                  itemCount: candidates.length,
                                  separatorBuilder:
                                      (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final candidate = candidates[index];
                                    final author =
                                        candidate.book.author?.trim();
                                    final subtitle =
                                        (author == null || author.isEmpty)
                                            ? candidate.sourceName
                                            : '${candidate.sourceName} · $author';

                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        candidate.book.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '最新：${candidate.latestChapterLabel}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall?.copyWith(
                                              color:
                                                  candidate
                                                          .isPotentiallyOutdated
                                                      ? colorScheme.error
                                                      : colorScheme
                                                          .onSurfaceVariant,
                                              fontWeight:
                                                  candidate
                                                          .isPotentiallyOutdated
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            lookupState.scoreRankingEnabled
                                                ? '匹配:${candidate.baseScore} · 命中:${candidate.hitCount} · 源评:${_formatSignedScore(candidate.sourceScore)} · 书评:${_formatSignedScore(candidate.bookScore)}'
                                                : '匹配:${candidate.baseScore} · 命中:${candidate.hitCount}（评分排序关闭）',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (candidate
                                              .isPotentiallyOutdated) ...[
                                            Icon(
                                              Icons.warning_amber_rounded,
                                              color: colorScheme.error,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 2),
                                          ],
                                          PopupMenuButton<
                                            _ReaderSwitchSourceScoreAction
                                          >(
                                            tooltip: '评分',
                                            icon: const Icon(
                                              Icons.thumb_up_alt_outlined,
                                              size: 18,
                                            ),
                                            onSelected: (action) {
                                              unawaited(
                                                _applySwitchSourceScoreAction(
                                                  candidate: candidate,
                                                  action: action,
                                                  lookupStateNotifier:
                                                      lookupStateNotifier,
                                                  scoreStore: scoreStore,
                                                  scoreRankingEnabled:
                                                      scoreRankingEnabled,
                                                ),
                                              );
                                            },
                                            itemBuilder:
                                                (context) => const [
                                                  PopupMenuItem(
                                                    value:
                                                        _ReaderSwitchSourceScoreAction
                                                            .upvote,
                                                    child: Text('推荐 +1'),
                                                  ),
                                                  PopupMenuItem(
                                                    value:
                                                        _ReaderSwitchSourceScoreAction
                                                            .downvote,
                                                    child: Text('降权 -1'),
                                                  ),
                                                  PopupMenuItem(
                                                    value:
                                                        _ReaderSwitchSourceScoreAction
                                                            .reset,
                                                    child: Text('重置本书评分'),
                                                  ),
                                                ],
                                          ),
                                          const Icon(Icons.chevron_right),
                                        ],
                                      ),
                                      onTap:
                                          () => Navigator.of(
                                            context,
                                          ).pop(candidate),
                                    );
                                  },
                                ),
                      ),
                      if (lookupState.isLoading && candidates.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '正在继续检索其他书源...',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: bottomInset),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    if (shouldRestoreOverlay && mounted) {
      _setOverlayControlsVisibility(true);
    }

    return selected;
  }

  Future<void> _applySwitchSourceScoreAction({
    required _ReaderSourceSwitchCandidate candidate,
    required _ReaderSwitchSourceScoreAction action,
    required ValueNotifier<_ReaderSwitchSourceLookupState> lookupStateNotifier,
    required SourceSwitchScoreStore scoreStore,
    required bool scoreRankingEnabled,
  }) async {
    try {
      final update = switch (action) {
        _ReaderSwitchSourceScoreAction.upvote => _switchSourceScoreService
            .adjustBookScore(
              sourceId: candidate.book.sourceId,
              title: candidate.book.title,
              author: candidate.book.author,
              delta: _kSwitchSourceScoreStep,
            ),
        _ReaderSwitchSourceScoreAction.downvote => _switchSourceScoreService
            .adjustBookScore(
              sourceId: candidate.book.sourceId,
              title: candidate.book.title,
              author: candidate.book.author,
              delta: -_kSwitchSourceScoreStep,
            ),
        _ReaderSwitchSourceScoreAction.reset => _switchSourceScoreService
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
        candidates: _sortSwitchSourceCandidates(nextCandidates),
      );

      if (!mounted) {
        return;
      }

      final actionLabel = switch (action) {
        _ReaderSwitchSourceScoreAction.upvote => '已推荐',
        _ReaderSwitchSourceScoreAction.downvote => '已降权',
        _ReaderSwitchSourceScoreAction.reset => '已重置',
      };
      _showMessage(
        '$actionLabel ${candidate.sourceName}（源评 ${_formatSignedScore(resolved.sourceScore)}，书评 ${_formatSignedScore(resolved.bookScore)}）',
      );
    } catch (_) {
      _showMessage('更新评分失败，请稍后重试。');
    }
  }

  _ReaderSourceSwitchCandidate _rebuildSwitchSourceCandidateScore(
    _ReaderSourceSwitchCandidate candidate, {
    required SourceSwitchScoreStore scoreStore,
    required bool scoreRankingEnabled,
  }) {
    final sourceScore = scoreStore.sourceScores[candidate.book.sourceId] ?? 0;
    final bookScore =
        scoreStore.bookScores[_switchSourceScoreService.buildBookScoreKey(
          sourceId: candidate.book.sourceId,
          title: candidate.book.title,
          author: candidate.book.author,
        )] ??
        0;
    return candidate.copyWith(
      sourceScore: sourceScore,
      bookScore: bookScore,
      score: _composeSwitchSourceCandidateScore(
        baseScore: candidate.baseScore,
        hitCount: candidate.hitCount,
        sourceScore: sourceScore,
        bookScore: bookScore,
        scoreRankingEnabled: scoreRankingEnabled,
      ),
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

  Widget _buildSwitchSourceLoadingPlaceholderList(ColorScheme colorScheme) {
    final placeholderColor = colorScheme.surfaceContainerHigh;
    return ListView.separated(
      itemCount: 6,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final titleWidth = 110.0 + (index % 3) * 42.0;
        final subtitleWidth = 150.0 + (index % 2) * 56.0;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: titleWidth,
              height: 14,
              decoration: BoxDecoration(
                color: placeholderColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: subtitleWidth,
                height: 12,
                decoration: BoxDecoration(
                  color: placeholderColor.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          trailing: Icon(
            Icons.hourglass_top_rounded,
            color: colorScheme.onSurfaceVariant,
            size: 18,
          ),
        );
      },
    );
  }

  Future<bool> _applySwitchSourceCandidate(
    _ReaderSourceSwitchCandidate candidate, {
    bool showResultMessage = true,
    bool promptWhenCoverageGap = true,
  }) async {
    if (_isSwitchSourceLoading) {
      return false;
    }

    final snapshot = _ReaderSourceSnapshot(
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
      final detailResult = await _detailService.load(
        sourceId: candidate.book.sourceId,
        bookId: candidate.book.id,
        detailUrl: candidate.book.detailUrl,
        fallbackTitle: candidate.book.title,
        forceRefresh: true,
      );

      final chapters = detailResult.chapters;
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

      final targetChapter = chapters[positionDecision.targetIndex];

      setState(() {
        _sourceId = candidate.book.sourceId;
        _detailUrl = candidate.book.detailUrl;
        _bookTitle = detailResult.detail.title;
        _bookAuthor = detailResult.detail.author;
        _bookCoverUrl = detailResult.detail.coverUrl;
        _chapters = chapters;
        _currentIndex = positionDecision.targetIndex;
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
      final shouldMigrateBookshelf =
          snapshot.isInBookshelf &&
          previousSourceId.isNotEmpty &&
          previousDetailUrl.isNotEmpty;

      if (shouldMigrateBookshelf) {
        try {
          await _bookshelfService.remove(
            sourceId: previousSourceId,
            detailUrl: previousDetailUrl,
          );
          await _bookshelfService.upsert(
            BookshelfBook(
              bookId: widget.bookId,
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
    _scheduleAutoReadResume();
  }

  Widget _buildTopOverlay(_ReaderThemeColors colors) {
    final chapterTitle =
        _chapterTitle?.isNotEmpty == true ? _chapterTitle! : '阅读';

    final topInset = _topSafeInset(context);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_showOverlayControls,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          offset: _showOverlayControls ? Offset.zero : const Offset(0, -1),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: _showOverlayControls ? 1 : 0,
            child: Padding(
              padding: EdgeInsets.only(top: topInset),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.overlay.withValues(alpha: 0.96),
                  border: Border(
                    bottom: BorderSide(
                      color: colors.divider.withValues(alpha: 0.82),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    child: Row(
                      children: [
                        _buildTopActionButton(
                          icon: Icons.arrow_back_ios_new,
                          tooltip: '返回',
                          onPressed: _handleBackNavigation,
                          colors: colors,
                        ),
                        const SizedBox(width: 8),
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
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 1),
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
                        const SizedBox(width: 8),
                        _buildTopActionButton(
                          icon:
                              _isCurrentChapterCached
                                  ? Icons.cloud_done_rounded
                                  : Icons.cloud_download_outlined,
                          tooltip: _isCurrentChapterCached ? '已缓存' : '缓存章节',
                          onPressed: _openChapterCache,
                          colors: colors,
                        ),
                        const SizedBox(width: 4),
                        _buildTopActionButton(
                          icon: Icons.swap_horiz_rounded,
                          tooltip: '切换书源',
                          onPressed:
                              _isSwitchSourceLoading
                                  ? null
                                  : () => unawaited(_showSwitchSourceSheet()),
                          loading: _isSwitchSourceLoading,
                          colors: colors,
                        ),
                        const SizedBox(width: 4),
                        _buildTopActionButton(
                          icon:
                              _isInBookshelf
                                  ? Icons.bookmark_added
                                  : Icons.bookmark_add_outlined,
                          tooltip: _isInBookshelf ? '移出书架' : '加���������书架',
                          onPressed:
                              _isShelfActionLoading ? null : _toggleBookshelf,
                          loading: _isShelfActionLoading,
                          colors: colors,
                        ),
                        const SizedBox(width: 4),
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
  }

  Widget _buildBottomOverlay(_ReaderThemeColors colors) {
    final middleLabel = _isMangaChapter ? '定位' : '界面';
    final middleIcon =
        _isMangaChapter ? Icons.gps_fixed_rounded : Icons.palette_outlined;
    final isDarkMode = _settings.themeMode == ReaderThemeMode.dark;
    final dayNightLabel = isDarkMode ? '日间' : '夜间';
    final dayNightIcon =
        isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded;

    final bottomInset = _effectiveBottomSafeInset(context);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !_showOverlayControls,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          offset: _showOverlayControls ? Offset.zero : const Offset(0, 1),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: _showOverlayControls ? 1 : 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(22, 6, 22, 12 + bottomInset),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.overlay.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: colors.divider.withValues(alpha: 0.84),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
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
                              label: '设置',
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
        ),
      ),
    );
  }

  Future<void> _toggleDayNightMode() async {
    final isDarkMode = _settings.themeMode == ReaderThemeMode.dark;
    final nextSettings = switch (isDarkMode) {
      true => _settings.copyWith(
        themeMode: ReaderThemeMode.light,
        backgroundStyle: ReaderBackgroundStyle.plain,
        backgroundTone: ReaderBackgroundTone.surface,
        backgroundImageBase64:
            (_dayModeBackgroundImageBackup?.trim().isEmpty ?? true)
                ? _settings.backgroundImageBase64
                : _dayModeBackgroundImageBackup?.trim(),
        clearBackgroundImage: _dayModeBackgroundImageBackup == null,
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
      if (isDarkMode) {
        _dayModeBackgroundImageBackup = null;
      } else {
        final currentBackground = _settings.backgroundImageBase64?.trim();
        _dayModeBackgroundImageBackup =
            (currentBackground == null || currentBackground.isEmpty)
                ? null
                : currentBackground;
      }
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
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        foregroundColor: colors.text,
        backgroundColor: colors.background.withValues(alpha: 0.42),
        minimumSize: const Size(34, 34),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
    try {
      final loadedSettings = await _preferencesService.loadSettings();
      var normalizedSettings = loadedSettings;
      var availableCustomFonts = const <ReaderCustomFontEntry>[];

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

      final fontSettingsChanged =
          normalizedSettings.fontSource != loadedSettings.fontSource ||
          normalizedSettings.fontFamilyKey != loadedSettings.fontFamilyKey ||
          normalizedSettings.customFontPath != loadedSettings.customFontPath;
      if (fontSettingsChanged) {
        await _preferencesService.saveSettings(normalizedSettings);
      }

      final bootSettings = normalizedSettings.copyWith(autoReadEnabled: false);
      if (mounted) {
        setState(() {
          _settings = bootSettings;
          _customFonts = availableCustomFonts;
        });
      } else {
        _settings = bootSettings;
        _customFonts = availableCustomFonts;
      }
      try {
        _autoSwitchSourceOnFailureEnabled =
            await _systemSettingsService.loadAutoSwitchSourceOnFailureEnabled();
      } catch (_) {
        _autoSwitchSourceOnFailureEnabled = false;
      }

      final progress = await _preferencesService.loadProgress(widget.bookId);
      _bootstrapProgress = progress;

      if (_isMissingCriticalParams && progress != null) {
        _sourceId = progress.sourceId;
        _detailUrl = progress.detailUrl;
        _chapterId = progress.chapterId;
        _chapterUrl = progress.chapterUrl;
        _chapterTitle = progress.chapterTitle;
        _currentIndex = progress.chapterIndex;
      }

      if (_isMissingCriticalParams) {
        if (!mounted) {
          return;
        }
        setState(() {
          _errorText = '缺少 sourceId/detailUrl/chapterUrl，无法加载正文。';
          _isBootstrapping = false;
        });
        return;
      }

      final detailResult = await _detailService.load(
        sourceId: _sourceId!,
        bookId: widget.bookId,
        detailUrl: _detailUrl!,
        fallbackTitle: _chapterTitle,
      );

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
      await _loadCurrentChapter(
        initialScrollRatio: _consumeBootstrapScrollRatio(),
      );
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }
      final readableError = _toUserReadableError(error);
      _recordReaderFailure(message: readableError, errorCode: error.code);
      setState(() {
        _errorText = readableError;
      });
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
      if (mounted) {
        setState(() {
          _isBootstrapping = false;
        });
        _reconcileAutoRead(restart: true);
      }
    }
  }

  String _toUserReadableError(AppException error) {
    final message = error.briefMessage;

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
  }) {
    _stopAutoRead();
    _disposeMangaTransformControllers();
    _content = content;
    _chapterImageUrls = List.unmodifiable(imageUrls);
    _chapterImageHeaders = Map.unmodifiable(imageHeaders);
    _mangaImageRetryNonce.clear();
    _mangaPageIndex = 0;
    if (_mangaPageController.hasClients) {
      _mangaPageController.jumpToPage(0);
    }
    _paragraphs = _splitParagraphs(content);
    _pagedPages = const [];
    _currentPageIndex = 0;
    _paginationSignature = null;
    _isPaginatingPages = false;
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
          ..translate(
            -tapPoint.dx * (zoomScale - 1),
            -tapPoint.dy * (zoomScale - 1),
          )
          ..scale(zoomScale);

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

    _scheduleProgressSave();
  }

  void _scheduleProgressSave() {
    _progressDebounceTimer?.cancel();
    _progressDebounceTimer = Timer(const Duration(milliseconds: 420), () {
      unawaited(_saveProgress());
    });
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('切换章节失败，已回退到上一章。'),
        action: SnackBarAction(
          label: '重试',
          onPressed: () => unawaited(_jumpTo(targetIndex)),
        ),
      ),
    );
  }

  Future<bool> _loadCurrentChapter({double? initialScrollRatio}) async {
    if (!mounted) {
      return false;
    }

    final sourceId = _sourceId;
    final chapterUrl = _chapterUrl;

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
    setState(() {
      _isLoadingContent = true;
      _errorText = null;
    });

    try {
      final resolvedIndex =
          _currentIndex ??
          _chapters.indexWhere((chapter) => chapter.chapterUrl == chapterUrl);

      final contentResult = await _contentService.load(
        sourceId: sourceId,
        chapterUrl: chapterUrl,
        bookId: widget.bookId,
        chapterIndex: resolvedIndex >= 0 ? resolvedIndex : null,
        chapterTitle: _chapterTitle,
      );

      var isCached = contentResult.fromCache;
      final cacheKey = '$sourceId|$chapterUrl';
      try {
        final persisted = await AppDatabase.instance.getChapterCache(cacheKey);
        isCached = persisted != null;
      } catch (_) {
        // ignore
      }

      if (!mounted) {
        return false;
      }

      final targetRatio = initialScrollRatio?.clamp(0.0, 1.0) ?? 0.0;

      setState(() {
        _isCurrentChapterCached = isCached;
        _setContent(
          contentResult.content,
          imageUrls: contentResult.imageUrls,
          imageHeaders: contentResult.imageHeaders,
        );
        _pendingPageRestoreRatio = targetRatio;
      });

      _restoreScrollPosition(targetRatio);

      await _saveProgress();
      final preloadTaskToken = ++_preloadTaskToken;
      unawaited(_preloadNeighbors(taskToken: preloadTaskToken));
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
      if (mounted) {
        setState(() {
          _isLoadingContent = false;
        });
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
            bookId: widget.bookId,
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

    final route =
        Uri(
          path: '/book/${widget.bookId}',
          queryParameters: {
            'sourceId': sourceId,
            'detailUrl': detailUrl,
            'title':
                _bookTitle.isNotEmpty
                    ? _bookTitle
                    : (widget.chapterTitle ?? '书籍详情'),
          },
        ).toString();

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
        await _contentService.load(
          sourceId: normalizedSourceId,
          chapterUrl: chapterUrl,
          bookId: widget.bookId,
          chapterIndex: index,
          chapterTitle: chapter.title,
          nextChapterUrl: nextChapterUrl.isEmpty ? null : nextChapterUrl,
        );
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

    await _preferencesService.saveProgress(
      ReadingProgress(
        bookId: widget.bookId,
        sourceId: sourceId,
        detailUrl: detailUrl,
        chapterId: _chapterId,
        chapterUrl: chapterUrl,
        chapterTitle: chapterTitle,
        chapterIndex: currentIndex,
        updatedAt: DateTime.now(),
        chapterPositionRatio: _currentScrollRatio(),
      ),
    );
  }

  Future<void> _goToPreviousPage(double viewportHeight) async {
    if (!_isPagedTextReaderEnabled()) {
      return;
    }

    final animationStyle = _effectivePageAnimationStyle();
    if (animationStyle == ReaderPageAnimationStyle.curl) {
      await _autoTurnCurlPage(-1);
      return;
    }

    if (_isPaginatingPages) {
      return;
    }

    final pages = _pagedPages;
    if (pages.isEmpty) {
      return;
    }

    if (_currentPageIndex <= 0) {
      final index = _currentIndex;
      if (index == null || index <= 0) {
        _showMessage('已经是第一章。');
        return;
      }
      await _jumpTo(index - 1, initialScrollRatio: 1);
      return;
    }

    setState(() {
      _pageSwitchDirection = -1;
      _currentPageIndex -= 1;
    });
    _scheduleProgressSave();
  }

  Future<void> _goToNextPage(double viewportHeight) async {
    if (!_isPagedTextReaderEnabled()) {
      return;
    }

    final animationStyle = _effectivePageAnimationStyle();
    if (animationStyle == ReaderPageAnimationStyle.curl) {
      await _autoTurnCurlPage(1);
      return;
    }

    if (_isPaginatingPages) {
      return;
    }

    final pages = _pagedPages;
    if (pages.isEmpty) {
      return;
    }

    if (_currentPageIndex >= pages.length - 1) {
      final index = _currentIndex;
      if (index == null || index >= _chapters.length - 1) {
        _showMessage('已经是最后一章。');
        return;
      }
      await _jumpTo(index + 1, initialScrollRatio: 0);
      return;
    }

    setState(() {
      _pageSwitchDirection = 1;
      _currentPageIndex += 1;
    });
    _scheduleProgressSave();
  }

  Future<void> _jumpTo(int index, {double? initialScrollRatio}) async {
    _stopAutoRead();
    final chapter = _chapters[index];

    final previousChapterId = _chapterId;
    final previousChapterUrl = _chapterUrl;
    final previousChapterTitle = _chapterTitle;
    final previousIndex = _currentIndex;
    final previousContent = _content;
    final previousImageUrls = _chapterImageUrls;
    final previousImageHeaders = _chapterImageHeaders;

    setState(() {
      _currentIndex = index;
      _chapterId = chapter.id;
      _chapterUrl = chapter.chapterUrl;
      _chapterTitle = chapter.title;
      _errorText = null;
    });

    final success = await _loadCurrentChapter(
      initialScrollRatio: initialScrollRatio ?? 0,
    );
    if (success || !mounted) {
      return;
    }

    setState(() {
      _chapterId = previousChapterId;
      _chapterUrl = previousChapterUrl;
      _chapterTitle = previousChapterTitle;
      _currentIndex = previousIndex;
      _setContent(
        previousContent,
        imageUrls: previousImageUrls,
        imageHeaders: previousImageHeaders,
      );
      _errorText = null;
    });

    _showChapterSwitchFailedSnackbar(index);
  }

  void _onReaderTap(Offset localPosition, Size size, EdgeInsets gestureInsets) {
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

    if (!_isTapPaginationEnabled()) {
      return;
    }

    if (localPosition.dx <= leftGuard ||
        localPosition.dx >= size.width - rightGuard) {
      return;
    }

    if (localPosition.dx < centerLeft) {
      unawaited(_goToPreviousPage(size.height));
      return;
    }

    if (localPosition.dx > centerRight) {
      unawaited(_goToNextPage(size.height));
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

    const itemExtent = 64.0;
    final currentIndex = _currentIndex;
    final anchorIndex =
        currentIndex == null
            ? 0
            : (currentIndex - 2).clamp(0, _chapters.length - 1);
    final scrollController = ScrollController(
      initialScrollOffset: anchorIndex * itemExtent,
    );
    final searchController = TextEditingController();
    double? selectedScrollRatio;
    final readerModalTheme = _readerModalTheme();

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
              final keyword = searchController.text.trim();
              final isSearching = keyword.isNotEmpty;
              final searchEntries =
                  isSearching
                      ? _buildFullTextSearchEntries(keyword)
                      : const <_CatalogSearchEntry>[];

              final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
              final safeBottom = _bottomSafeInset(context);
              final sheetHeightFactor = _adaptiveReaderSheetHeightFactor(
                context,
                compact: 0.9,
                regular: 0.86,
                large: 0.82,
              );
              final sheetHorizontal = AppSpacing.pageHorizontal(context);

              return AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(bottom: keyboardInset + safeBottom),
                child: FractionallySizedBox(
                  heightFactor: sheetHeightFactor,
                  child: Column(
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
                            final title = Text(
                              '目录（${_chapters.length} 章）',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            );
                            final locationButton =
                                currentIndex == null
                                    ? null
                                    : FilledButton.tonalIcon(
                                      onPressed: () {
                                        final target =
                                            ((currentIndex - 2).clamp(
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
                                        size: 18,
                                      ),
                                      label: Text('定位 ${currentIndex + 1}'),
                                    );

                            if (locationButton == null) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: title,
                              );
                            }

                            if (constraints.maxWidth <
                                AppLayout.phoneSmallWidth) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  title,
                                  const SizedBox(height: 8),
                                  locationButton,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: title),
                                locationButton,
                              ],
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
                        child: TextField(
                          controller: searchController,
                          onChanged: (_) => setModalState(() {}),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: '搜索全文中的句子、章节、角色名',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
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
                      if (isSearching && searchEntries.isEmpty)
                        Expanded(
                          child: Center(
                            child: Text(
                              '未找到匹配内容',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      else if (isSearching)
                        Expanded(
                          child: ListView.separated(
                            itemCount: searchEntries.length,
                            separatorBuilder:
                                (_, __) => Divider(
                                  height: 1,
                                  color: colorScheme.outlineVariant.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                            itemBuilder: (context, index) {
                              final entry = searchEntries[index];

                              return ListTile(
                                leading: Icon(
                                  entry.isContent
                                      ? Icons.article_outlined
                                      : Icons.list_alt_outlined,
                                  color: colorScheme.primary,
                                ),
                                title: Text(
                                  entry.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  entry.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                trailing: Text(
                                  entry.isContent ? '正文' : '目录',
                                  style: textTheme.labelMedium?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                onTap: () {
                                  selectedScrollRatio = entry.scrollRatio;
                                  Navigator.of(context).pop(entry.chapterIndex);
                                },
                              );
                            },
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            itemExtent: itemExtent,
                            itemCount: _chapters.length,
                            itemBuilder: (context, index) {
                              final chapter = _chapters[index];
                              final selected = index == currentIndex;
                              final showDivider = index < _chapters.length - 1;

                              return Material(
                                color:
                                    selected
                                        ? colorScheme.secondaryContainer
                                            .withValues(alpha: 0.5)
                                        : Colors.transparent,
                                child: InkWell(
                                  onTap: () => Navigator.of(context).pop(index),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      border:
                                          showDivider
                                              ? Border(
                                                bottom: BorderSide(
                                                  color: colorScheme
                                                      .outlineVariant
                                                      .withValues(alpha: 0.35),
                                                ),
                                              )
                                              : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                chapter.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: textTheme.bodyLarge
                                                    ?.copyWith(
                                                      fontWeight:
                                                          selected
                                                              ? FontWeight.w700
                                                              : FontWeight.w500,
                                                      color:
                                                          selected
                                                              ? colorScheme
                                                                  .primary
                                                              : colorScheme
                                                                  .onSurface,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (selected)
                                          Icon(
                                            Icons.play_circle_fill_rounded,
                                            size: 20,
                                            color: colorScheme.primary,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
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

    scrollController.dispose();
    searchController.dispose();

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

  bool get _isMissingCriticalParams {
    return _sourceId == null ||
        _sourceId!.isEmpty ||
        _detailUrl == null ||
        _detailUrl!.isEmpty ||
        _chapterUrl == null ||
        _chapterUrl!.isEmpty;
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _recordReaderFailure({required String message, ErrorCode? errorCode}) {
    _readerErrorCenterService.addFailure(
      bookId: widget.bookId,
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

    await _ensureBackgroundPresetsReady();
    if (!mounted) {
      return;
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
              final customBackgroundPreview =
                  hasBackgroundImage && !isPresetBackground
                      ? _tryDecodeBase64(activeBackgroundBase64)
                      : null;
              void previewDraftSettings() {
                if (!mounted || identical(_settings, draft)) {
                  return;
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || identical(_settings, draft)) {
                    return;
                  }
                  setState(() {
                    _settings = draft;
                  });
                });
              }

              Future<void> applyCustomBackgroundImage() async {
                final encoded = await _pickBackgroundImageBase64();
                if (encoded == null || !context.mounted) {
                  return;
                }

                setModalState(() {
                  draft = draft.copyWith(backgroundImageBase64: encoded);
                });
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

              Future<void> openParagraphIndentTabSheet() async {
                if (!context.mounted) {
                  return;
                }

                const options = <int>[0, 1, 2, 3, 4];
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
                            '缩进',
                            textAlign: TextAlign.center,
                            style: Theme.of(sheetContext).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: options
                                .map(
                                  (value) => ChoiceChip(
                                    label: Text(
                                      _paragraphIndentVisualLabel(value),
                                    ),
                                    selected:
                                        draft.paragraphIndent.round() == value,
                                    onSelected: (_) {
                                      setModalState(() {
                                        draft = draft.copyWith(
                                          paragraphIndent: value.toDouble(),
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
                          updatePaddingSettings(
                            next.copyWith(
                              horizontalPadding:
                                  ((next.bodyMarginLeft +
                                              next.bodyMarginRight) /
                                          2)
                                      .toDouble(),
                            ),
                          );
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
                                  width: 28,
                                  child: Text(
                                    safeValue.round().toString(),
                                    textAlign: TextAlign.right,
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
                                    selected: dividerEnabled,
                                    onSelected: onDividerChanged,
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
                                const SizedBox(height: 8),
                                FilledButton.tonal(
                                  onPressed: () {
                                    if (sheetContext.mounted) {
                                      Navigator.of(sheetContext).pop();
                                    }
                                  },
                                  child: const Text('完成'),
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

                        void updateInfoSettings(ReaderSettings next) {
                          setModalState(() {
                            draft = next;
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
                                const SizedBox(height: 8),
                                FilledButton.tonal(
                                  onPressed: () {
                                    if (sheetContext.mounted) {
                                      Navigator.of(sheetContext).pop();
                                    }
                                  },
                                  child: const Text('完成'),
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
              final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
              final safeBottom = _bottomSafeInset(context);
              final sheetHeightFactor = _adaptiveReaderSheetHeightFactor(
                context,
                compact:
                    showInterfaceSection
                        ? 0.58
                        : (isMangaChapter ? 0.64 : 0.68),
                regular:
                    showInterfaceSection
                        ? 0.54
                        : (isMangaChapter ? 0.60 : 0.63),
                large:
                    showInterfaceSection
                        ? 0.50
                        : (isMangaChapter ? 0.56 : 0.58),
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
                      SizedBox(
                        width: 70,
                        child: Text(valueLabel, textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                );
              }

              previewDraftSettings();

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
                                                  onPressed: openFontPickerSheet,
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
                                                      clearBackgroundImage:
                                                          true,
                                                    );
                                                  });
                                                },
                                              ),
                                              const SizedBox(width: 8),
                                              ...presetBackgroundTiles,
                                              _buildBackgroundTile(
                                                label: '自定义',
                                                selected:
                                                    hasBackgroundImage &&
                                                    !isPresetBackground,
                                                previewBytes:
                                                    customBackgroundPreview,
                                                showLabel:
                                                    customBackgroundPreview ==
                                                    null,
                                                onTap:
                                                    applyCustomBackgroundImage,
                                              ),
                                              if (hasBackgroundImage) ...[
                                                const SizedBox(width: 8),
                                                OutlinedButton(
                                                  onPressed: () {
                                                    setModalState(() {
                                                      draft = draft.copyWith(
                                                        clearBackgroundImage:
                                                            true,
                                                      );
                                                    });
                                                  },
                                                  child: const Text('移除'),
                                                ),
                                              ],
                                            ],
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
                                                  label: '缩进',
                                                  value:
                                                      _paragraphIndentValueLabel(
                                                        draft,
                                                      ),
                                                  onTap:
                                                      () => unawaited(
                                                        openParagraphIndentTabSheet(),
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
                                              buildTypographySliderRow(
                                                label: '字号',
                                                min: 5,
                                                max: 50,
                                                divisions: 45,
                                                value: draft.fontSize,
                                                step: 1,
                                                valueLabel:
                                                    _fontSizeValueLabel(draft),
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
                                                value: _letterSpacingSliderValue(
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
                                                    _lineHeightValueLabel(draft),
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
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.labelSmall
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
                                                      children:
                                                          ReaderMangaReadMode
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
                                                                      draft.mangaReadMode ==
                                                                      mode,
                                                                  onSelected:
                                                                      (_) {
                                                                        setModalState(() {
                                                                          draft =
                                                                              draft.copyWith(
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
                                                            (value) =>
                                                                ChoiceChip(
                                                                  label: Text(
                                                                    '${value.toInt()}',
                                                                  ),
                                                                  selected:
                                                                      (draft.mangaImagePadding -
                                                                              value)
                                                                          .abs() <
                                                                      0.2,
                                                                  onSelected:
                                                                      (_) {
                                                                        setModalState(() {
                                                                          draft =
                                                                              draft.copyWith(
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
                                                            (value) =>
                                                                ChoiceChip(
                                                                  label: Text(
                                                                    '${value.toInt()}',
                                                                  ),
                                                                  selected:
                                                                      (draft.mangaImageSpacing -
                                                                              value)
                                                                          .abs() <
                                                                      0.2,
                                                                  onSelected:
                                                                      (_) {
                                                                        setModalState(() {
                                                                          draft =
                                                                              draft.copyWith(
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
                                                              draft = draft
                                                                  .copyWith(
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
                                                              draft = draft
                                                                  .copyWith(
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
                                                              draft = draft
                                                                  .copyWith(
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
                                                              draft = draft
                                                                  .copyWith(
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
                                                      children:
                                                          ReaderMangaLoadStrategy
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
                                                                      draft.mangaLoadStrategy ==
                                                                      strategy,
                                                                  onSelected:
                                                                      (_) {
                                                                        setModalState(() {
                                                                          draft =
                                                                              draft.copyWith(
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
                                                                ).textTheme
                                                                    .bodyMedium,
                                                          ),
                                                        ),
                                                        Switch.adaptive(
                                                          value:
                                                              startAutoReadAfterApply,
                                                          onChanged: (
                                                            enabled,
                                                          ) {
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
                                                          draft = draft.copyWith(
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
                              const SizedBox(height: 6),
                              OverflowBar(
                                alignment: MainAxisAlignment.spaceBetween,
                                overflowAlignment: OverflowBarAlignment.end,
                                spacing: 8,
                                overflowSpacing: 8,
                                children: [
                                  OutlinedButton(
                                    onPressed: () {
                                      setModalState(() {
                                        draft = const ReaderSettings();
                                        startAutoReadAfterApply = false;
                                      });
                                    },
                                    child: const Text('恢复默认'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('完成'),
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
        );
      },
    );

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
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
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
                                      onPressed:
                                          () => Navigator.of(context).pop(),
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
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
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
      const typeGroup = XTypeGroup(
        label: 'image',
        extensions: ['jpg', 'jpeg', 'png', 'webp'],
        mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
        uniformTypeIdentifiers: [
          'public.image',
          'public.jpeg',
          'public.png',
          'org.webmproject.webp',
        ],
      );

      final file = await openFile(
        acceptedTypeGroups: [typeGroup],
        confirmButtonText: '选择背景',
      );

      if (file == null) {
        return null;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _showMessage('背景图片读取失败。');
        return null;
      }

      if (bytes.length > maxBytes) {
        _showMessage('图片过大，请选择 900KB 以内图片。');
        return null;
      }

      return base64Encode(bytes);
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
    return ((((sliderValue.clamp(0, 100).toDouble()) - 50) / 100)
            .clamp(
              ReaderSettings.minLetterSpacing,
              ReaderSettings.maxLetterSpacing,
            ))
        .toDouble();
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
    return (((settings.lineHeight - 1) * safeFontSize).clamp(0, 20))
        .toDouble();
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
    final spaces = '　' * safeCount;
    return '$spaces(${safeCount}格)';
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
    final scheme = _colorSchemeForReaderMode(_effectiveReaderThemeMode());
    final theme = AppTheme.build(scheme);
    return theme.copyWith(
      bottomSheetTheme: theme.bottomSheetTheme.copyWith(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        dragHandleColor: scheme.outlineVariant,
      ),
      dialogTheme: theme.dialogTheme.copyWith(backgroundColor: scheme.surface),
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

class _ReaderSourceSwitchCandidate {
  const _ReaderSourceSwitchCandidate({
    required this.book,
    required this.sourceName,
    required this.baseScore,
    required this.score,
    required this.hitCount,
    required this.sourceScore,
    required this.bookScore,
    required this.latestChapterLabel,
    required this.latestChapterNumber,
    required this.isPotentiallyOutdated,
  });

  final Book book;
  final String sourceName;
  final int baseScore;
  final int score;
  final int hitCount;
  final int sourceScore;
  final int bookScore;
  final String latestChapterLabel;
  final int? latestChapterNumber;
  final bool isPotentiallyOutdated;

  _ReaderSourceSwitchCandidate copyWith({
    int? score,
    int? sourceScore,
    int? bookScore,
  }) {
    return _ReaderSourceSwitchCandidate(
      book: book,
      sourceName: sourceName,
      baseScore: baseScore,
      score: score ?? this.score,
      hitCount: hitCount,
      sourceScore: sourceScore ?? this.sourceScore,
      bookScore: bookScore ?? this.bookScore,
      latestChapterLabel: latestChapterLabel,
      latestChapterNumber: latestChapterNumber,
      isPotentiallyOutdated: isPotentiallyOutdated,
    );
  }
}

class _ReaderSwitchSourceLookupState {
  const _ReaderSwitchSourceLookupState({
    required this.isLoading,
    required this.sourceCount,
    required this.processedSourceCount,
    required this.candidates,
    required this.errorText,
    required this.scoreRankingEnabled,
  });

  const _ReaderSwitchSourceLookupState.loading({
    required int sourceCount,
    required bool scoreRankingEnabled,
  }) : this(
         isLoading: true,
         sourceCount: sourceCount,
         processedSourceCount: 0,
         candidates: const <_ReaderSourceSwitchCandidate>[],
         errorText: null,
         scoreRankingEnabled: scoreRankingEnabled,
       );

  final bool isLoading;
  final int sourceCount;
  final int processedSourceCount;
  final List<_ReaderSourceSwitchCandidate> candidates;
  final String? errorText;
  final bool scoreRankingEnabled;

  _ReaderSwitchSourceLookupState copyWith({
    bool? isLoading,
    int? sourceCount,
    int? processedSourceCount,
    List<_ReaderSourceSwitchCandidate>? candidates,
    String? errorText,
    bool clearErrorText = false,
    bool? scoreRankingEnabled,
  }) {
    return _ReaderSwitchSourceLookupState(
      isLoading: isLoading ?? this.isLoading,
      sourceCount: sourceCount ?? this.sourceCount,
      processedSourceCount: processedSourceCount ?? this.processedSourceCount,
      candidates: candidates ?? this.candidates,
      errorText: clearErrorText ? null : (errorText ?? this.errorText),
      scoreRankingEnabled: scoreRankingEnabled ?? this.scoreRankingEnabled,
    );
  }
}

enum _ReaderSwitchSourceScoreAction { upvote, downvote, reset }

class _ReaderSourceSnapshot {
  const _ReaderSourceSnapshot({
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
