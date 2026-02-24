import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:page_curl_effect/page_curl_effect.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_spacing.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reader_settings.dart';
import '../../../app/theme/app_theme_provider.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../book/application/book_detail_service.dart';
import '../../bookshelf/application/bookshelf_service.dart';
import '../application/chapter_content_service.dart';
import '../application/reader_preferences_service.dart';
import '../application/reader_error_center_service.dart';
import 'chapter_cache_sheets.dart';

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
  final ReaderErrorCenterService _readerErrorCenterService =
      ReaderErrorCenterService.instance;
  final BookshelfService _bookshelfService = BookshelfService();
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
  String? _errorText;
  String _content = '';
  List<String> _paragraphs = const [];
  List<String> _chapterImageUrls = const [];
  Map<String, String> _chapterImageHeaders = const {};
  final Map<String, int> _mangaImageRetryNonce = <String, int>{};
  final Map<int, TransformationController> _mangaTransformControllers =
      <int, TransformationController>{};
  final Map<int, TapDownDetails> _mangaDoubleTapDetails =
      <int, TapDownDetails>{};
  final Set<int> _mangaZoomedPageIndexes = <int>{};
  int _mangaPageIndex = 0;
  ReadingProgress? _bootstrapProgress;
  Timer? _progressDebounceTimer;
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
  late final AnimationController _curlAutoTurnController;
  double _curlAutoStartX = 0;
  double _curlAutoEndX = 0;
  double _curlAutoY = 0;
  int _curlAutoDirection = 1;

  static const double _kPinnedHeaderTopPadding = 6;
  static const double _kPinnedHeaderHeight = 40;

  bool _isTapPaginationEnabled() {
    return _settings.pageTurnMode == ReaderPageTurnMode.tap &&
        _chapterImageUrls.isEmpty;
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
      duration: const Duration(milliseconds: 320),
    );
    _curlAutoTurnController.addListener(_onCurlAutoTurnTick);
    _curlAutoTurnController.addStatusListener(_onCurlAutoTurnStatus);
    _scrollController.addListener(_onScrollChanged);

    _bootstrap();
  }

  @override
  void dispose() {
    _progressDebounceTimer?.cancel();
    _scrollController.removeListener(_onScrollChanged);
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
    final backgroundImage = _resolveBackgroundDecorationImage();
    final decoration = switch (_settings.backgroundStyle) {
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

    return DecoratedBox(decoration: decoration);
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
    final isPaged = _isTapPaginationEnabled();

    return Column(
      children: [
        if (!isPaged) _buildPinnedChapterHeader(colors),
        Expanded(child: _buildBody(colors)),
      ],
    );
  }

  Widget _buildPinnedChapterHeader(_ReaderThemeColors colors) {
    final chapterTitle =
        _chapterTitle?.isNotEmpty == true ? _chapterTitle! : '未命名章节';

    return ColoredBox(
      color: colors.background,
      child: Padding(
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
      ),
    );
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
          action: FilledButton.tonal(
            onPressed: () => _loadCurrentChapter(initialScrollRatio: null),
            child: const Text('重试'),
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
              : _isTapPaginationEnabled()
              ? _buildPagedReader(colors)
              : _buildReaderList(colors),
    );
  }

  Widget _buildReaderList(_ReaderThemeColors colors) {
    final paragraphs = _paragraphs;

    final bottomInset = _bottomSafeInset(context);

    return ListView.builder(
      key: ValueKey(_chapterId),
      controller: _scrollController,
      cacheExtent: 1200,
      padding: EdgeInsets.fromLTRB(
        _settings.horizontalPadding,
        18,
        _settings.horizontalPadding,
        96 + bottomInset,
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
    );
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

    final bottomInset = _bottomSafeInset(context);

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

    final bottomInset = _bottomSafeInset(context);

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
        Positioned(
          right: 12,
          bottom: 12 + bottomInset,
          child: _buildPageIndexBadge(
            colors: colors,
            index: currentIndex,
            total: pageCount,
          ),
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
    final appBrightness = Theme.of(context).brightness;
    if (appBrightness == Brightness.dark) {
      return ReaderThemeMode.dark;
    }

    return _settings.themeMode == ReaderThemeMode.sepia
        ? ReaderThemeMode.sepia
        : ReaderThemeMode.light;
  }

  ReaderPageAnimationStyle _effectivePageAnimationStyle() {
    final style = _settings.pageAnimationStyle;
    return style == ReaderPageAnimationStyle.simulation
        ? ReaderPageAnimationStyle.curl
        : style;
  }

  Widget _buildPagedReader(_ReaderThemeColors colors) {
    final paragraphs =
        _paragraphs.isEmpty ? <String>[_content.trim()] : _paragraphs;

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentPadding = EdgeInsets.fromLTRB(
          _settings.horizontalPadding,
          18,
          _settings.horizontalPadding,
          18,
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
                Positioned(
                  right: 12,
                  bottom: 12 + _bottomSafeInset(context),
                  child: _buildPageIndexBadge(
                    colors: colors,
                    index: safeIndex,
                    total: pageCount,
                  ),
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
              Positioned(
                right: 12,
                bottom: 12 + _bottomSafeInset(context),
                child: _buildPageIndexBadge(
                  colors: colors,
                  index: safeIndex,
                  total: pageCount,
                ),
              ),
            ],
          );
        }

        Widget transitionBuilder(Widget child, Animation<double> animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final direction = _pageSwitchDirection.toDouble().clamp(-1.0, 1.0);

          switch (animationStyle) {
            case ReaderPageAnimationStyle.cover:
              if (animation.status == AnimationStatus.reverse) {
                return child;
              }
              return SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(direction, 0),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
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
            case ReaderPageAnimationStyle.simulation:
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
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
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
              Positioned(
                right: 12,
                bottom: 12,
                child: _buildPageIndexBadge(
                  colors: colors,
                  index: safeIndex,
                  total: pageCount,
                ),
              ),
          ],
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
      child: ColoredBox(
        color: colors.background,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.overlay.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.divider.withValues(alpha: 0.7)),
      ),
      child: Text(
        '${index + 1}/$total',
        style: TextStyle(color: colors.meta, fontSize: 12),
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
      child: ColoredBox(
        color: colors.background,
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
    final t = Curves.easeOutCubic.transform(_curlAutoTurnController.value);
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

    if (!_isTapPaginationEnabled()) {
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
      _settings.horizontalPadding.toStringAsFixed(1),
      _settings.paragraphSpacing.toStringAsFixed(1),
      _settings.paragraphIndent.toStringAsFixed(1),
      _settings.fontWeightLevel.name,
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

      final prefix = start == 0 ? ' ' * _settings.paragraphIndent.round() : '';
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

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp:
              (details) => _onReaderTap(
                details.localPosition,
                constraints.biggest,
                gestureInsets,
              ),
          onLongPress:
              _isMangaChapter
                  ? () => unawaited(_openMangaPositionSheet())
                  : null,
          child: child,
        );
      },
    );
  }

  TextStyle _paragraphTextStyle(_ReaderThemeColors colors) {
    return TextStyle(
      color: colors.text,
      fontSize: _settings.fontSize,
      height: _settings.lineHeight,
      fontWeight: _resolveBodyFontWeight(),
    );
  }

  FontWeight _resolveBodyFontWeight() {
    return switch (_settings.fontWeightLevel) {
      ReaderFontWeightLevel.light => FontWeight.w400,
      ReaderFontWeightLevel.regular => FontWeight.w500,
      ReaderFontWeightLevel.medium => FontWeight.w600,
    };
  }

  String _applyParagraphIndent(String paragraph) {
    final indentCount = _settings.paragraphIndent.round();
    if (indentCount <= 0) {
      return paragraph;
    }

    return '${' ' * indentCount}$paragraph';
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
                          icon:
                              _isInBookshelf
                                  ? Icons.bookmark_added
                                  : Icons.bookmark_add_outlined,
                          tooltip: _isInBookshelf ? '移出书架' : '加入书架',
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
    final isNight = Theme.of(context).brightness == Brightness.dark;
    final dayNightLabel = isNight ? '日间' : '夜间';
    final dayNightIcon =
        isNight ? Icons.light_mode_outlined : Icons.dark_mode_outlined;
    final middleLabel = _isMangaChapter ? '定位' : dayNightLabel;
    final middleIcon = _isMangaChapter ? Icons.gps_fixed_rounded : dayNightIcon;

    final bottomInset = _bottomSafeInset(context);

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
                                      : _toggleDayNight,
                              colors: colors,
                              active:
                                  !_isMangaChapter &&
                                  _settings.themeMode == ReaderThemeMode.dark,
                            ),
                          ),
                          Expanded(
                            child: _buildToolbarAction(
                              icon: Icons.tune,
                              label: '设置',
                              onTap: _showSettingsSheet,
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
      _settings = await _preferencesService.loadSettings();
      _settings = _settings.copyWith(pageTurnMode: ReaderPageTurnMode.tap);

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

      if (_isTapPaginationEnabled()) {
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

  void _onScrollChanged() {
    if (_isTapPaginationEnabled()) {
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

  double _currentScrollRatio() {
    if (_isTapPaginationEnabled()) {
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
      setState(() {
        _errorText = '当前章节信息不完整。';
      });
      return false;
    }

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
      await _preloadNeighbors();
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
      return false;
    } catch (_) {
      if (!mounted) {
        return false;
      }
      const fallbackError = '加载正文失败。';
      _recordReaderFailure(message: fallbackError);
      setState(() {
        _errorText = fallbackError;
      });
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingContent = false;
        });
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

  Future<void> _preloadNeighbors() async {
    final sourceId = _sourceId;
    final currentIndex = _currentIndex;
    if (sourceId == null || currentIndex == null || _chapters.isEmpty) {
      return;
    }

    final urls = <String>[];
    if (currentIndex > 0) {
      urls.add(_chapters[currentIndex - 1].chapterUrl);
    }
    if (currentIndex < _chapters.length - 1) {
      urls.add(_chapters[currentIndex + 1].chapterUrl);
    }

    await _contentService.preload(sourceId: sourceId, chapterUrls: urls);
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
    if (!_isTapPaginationEnabled()) {
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
    if (!_isTapPaginationEnabled()) {
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

    if (isCenterTap) {
      setState(() {
        _showOverlayControls = !_showOverlayControls;
      });
      return;
    }

    if (_showOverlayControls) {
      _hideOverlayControls();
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

  void _hideOverlayControls() {
    if (!_showOverlayControls || !mounted) {
      return;
    }

    setState(() {
      _showOverlayControls = false;
    });
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

    final selectedRatio = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
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
                        onPressed: () => Navigator.of(context).pop(draftRatio),
                        child: const Text('跳转'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
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

    final selectedIndex = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final keyword = searchController.text.trim();
            final isSearching = keyword.isNotEmpty;
            final searchEntries =
                isSearching
                    ? _buildFullTextSearchEntries(keyword)
                    : const <_CatalogSearchEntry>[];

            final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
            final safeBottom = _bottomSafeInset(context);

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(bottom: keyboardInset + safeBottom),
              child: FractionallySizedBox(
                heightFactor: 0.86,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '目录（${_chapters.length} 章）',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (currentIndex != null)
                            FilledButton.tonalIcon(
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
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                );
                              },
                              icon: const Icon(
                                Icons.my_location_outlined,
                                size: 18,
                              ),
                              label: Text('定位 ${currentIndex + 1}'),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
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
                      color: colorScheme.outlineVariant.withValues(alpha: 0.7),
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
        );
      },
    );

    scrollController.dispose();
    searchController.dispose();

    if (!mounted ||
        selectedIndex == null ||
        selectedIndex < 0 ||
        selectedIndex >= _chapters.length) {
      return;
    }

    if (selectedIndex == _currentIndex) {
      if (selectedScrollRatio != null) {
        _restoreScrollPosition(selectedScrollRatio!);
      }
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

  Future<void> _toggleDayNight() async {
    final isNight = Theme.of(context).brightness == Brightness.dark;
    final nextThemeMode = isNight ? ThemeMode.light : ThemeMode.dark;

    await ref.read(appThemeModeProvider.notifier).setThemeMode(nextThemeMode);

    _showMessage(isNight ? '已切换日间模式。' : '已切换夜间模式。');
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

  Future<void> _showSettingsSheet() async {
    final shouldRestoreOverlay = _showOverlayControls;
    if (shouldRestoreOverlay) {
      _hideOverlayControls();
    }

    var draft = _settings;
    if (draft.pageAnimationStyle == ReaderPageAnimationStyle.simulation) {
      draft = draft.copyWith(pageAnimationStyle: ReaderPageAnimationStyle.curl);
    }

    final result = await showModalBottomSheet<ReaderSettings>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final customBackgroundPreview = _tryDecodeBase64(
              draft.backgroundImageBase64,
            );
            final isMangaChapter = _chapterImageUrls.isNotEmpty;
            final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
            final safeBottom = _bottomSafeInset(context);

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(bottom: keyboardInset + safeBottom),
              child: SafeArea(
                child: FractionallySizedBox(
                  heightFactor: 0.6,
                  child: Padding(
                    padding: AppSpacing.modalSheetPadding(context),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '阅读设置',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView(
                            children: [
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
                                                    ? ReaderThemeMode.sepia
                                                    : ReaderThemeMode.light,
                                            backgroundStyle:
                                                selected
                                                    ? ReaderBackgroundStyle.warm
                                                    : draft.backgroundStyle,
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
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          final next =
                                              (draft.fontSize - 1)
                                                  .clamp(14, 30)
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
                                            draft.fontSize.toStringAsFixed(0),
                                          ),
                                        ),
                                      ),
                                      IconButton.filledTonal(
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          final next =
                                              (draft.fontSize + 1)
                                                  .clamp(14, 30)
                                                  .toDouble();
                                          setModalState(() {
                                            draft = draft.copyWith(
                                              fontSize: next,
                                            );
                                          });
                                        },
                                        icon: const Icon(Icons.add),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            setModalState(() {
                                              draft = draft.copyWith(
                                                fontWeightLevel: switch (draft
                                                    .fontWeightLevel) {
                                                  ReaderFontWeightLevel.light =>
                                                    ReaderFontWeightLevel
                                                        .regular,
                                                  ReaderFontWeightLevel
                                                      .regular =>
                                                    ReaderFontWeightLevel
                                                        .medium,
                                                  ReaderFontWeightLevel
                                                      .medium =>
                                                    ReaderFontWeightLevel.light,
                                                },
                                              );
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.font_download_outlined,
                                            size: 16,
                                          ),
                                          label: Text(
                                            _fontWeightLabel(
                                              draft.fontWeightLevel,
                                            ),
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
                                label: '颜色',
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildThemeColorDot(
                                        draft: draft,
                                        color: const Color(0xFFFDFDFD),
                                        mode: ReaderThemeMode.light,
                                        backgroundStyle:
                                            ReaderBackgroundStyle.plain,
                                        onChanged: (next) {
                                          setModalState(() {
                                            draft = next;
                                          });
                                        },
                                      ),
                                      _buildThemeColorDot(
                                        draft: draft,
                                        color: const Color(0xFFF7EEDC),
                                        mode: ReaderThemeMode.sepia,
                                        backgroundStyle:
                                            ReaderBackgroundStyle.warm,
                                        onChanged: (next) {
                                          setModalState(() {
                                            draft = next;
                                          });
                                        },
                                      ),
                                      _buildThemeColorDot(
                                        draft: draft,
                                        color: const Color(0xFFF2F4F7),
                                        mode: ReaderThemeMode.light,
                                        backgroundStyle:
                                            ReaderBackgroundStyle.paper,
                                        onChanged: (next) {
                                          setModalState(() {
                                            draft = next;
                                          });
                                        },
                                      ),
                                      _buildThemeColorDot(
                                        draft: draft,
                                        color: const Color(0xFF1E1F24),
                                        mode: ReaderThemeMode.dark,
                                        backgroundStyle:
                                            ReaderBackgroundStyle.plain,
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
                                label: '背景层级',
                                labelWidth: 92,
                                helpText:
                                    '背景层级用于在当前主题色板中切换阅读背景的明暗层级（surface / surfaceContainer*）。它不会改变文字颜色，只是让背景更亮/更灰/更厚重，暗色主题同样生效。',
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildBackgroundToneDot(
                                        draft: draft,
                                        tone: ReaderBackgroundTone.surface,
                                        onChanged: (next) {
                                          setModalState(() {
                                            draft = next;
                                          });
                                        },
                                      ),
                                      _buildBackgroundToneDot(
                                        draft: draft,
                                        tone: ReaderBackgroundTone.containerLow,
                                        onChanged: (next) {
                                          setModalState(() {
                                            draft = next;
                                          });
                                        },
                                      ),
                                      _buildBackgroundToneDot(
                                        draft: draft,
                                        tone: ReaderBackgroundTone.container,
                                        onChanged: (next) {
                                          setModalState(() {
                                            draft = next;
                                          });
                                        },
                                      ),
                                      _buildBackgroundToneDot(
                                        draft: draft,
                                        tone:
                                            ReaderBackgroundTone.containerHigh,
                                        onChanged: (next) {
                                          setModalState(() {
                                            draft = next;
                                          });
                                        },
                                      ),
                                      _buildBackgroundToneDot(
                                        draft: draft,
                                        tone:
                                            ReaderBackgroundTone
                                                .containerHighest,
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
                                        label: '示例1',
                                        selected: false,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildBackgroundTile(
                                        label: '示例2',
                                        selected: false,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildBackgroundTile(
                                        label: '示例3',
                                        selected: false,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildBackgroundTile(
                                        label: '自定义',
                                        selected:
                                            customBackgroundPreview != null,
                                        previewBytes: customBackgroundPreview,
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          final encoded =
                                              await _pickBackgroundImageBase64();
                                          if (encoded == null) {
                                            return;
                                          }
                                          setModalState(() {
                                            draft = draft.copyWith(
                                              backgroundImageBase64: encoded,
                                            );
                                          });
                                        },
                                        icon: const Icon(
                                          Icons.add_photo_alternate_outlined,
                                          size: 16,
                                        ),
                                        label: const Text('上传'),
                                      ),
                                      if (customBackgroundPreview != null) ...[
                                        const SizedBox(width: 8),
                                        OutlinedButton(
                                          onPressed: () {
                                            setModalState(() {
                                              draft = draft.copyWith(
                                                clearBackgroundImage: true,
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
                              const Divider(height: 1),
                              _buildSettingLine(
                                context: context,
                                label: '翻页',
                                child: SingleChildScrollView(
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
                                            padding: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            child: ChoiceChip(
                                              label: Text(
                                                _pageAnimationLabel(style),
                                              ),
                                              selected:
                                                  draft.pageAnimationStyle ==
                                                  style,
                                              onSelected: (_) {
                                                setModalState(() {
                                                  draft = draft.copyWith(
                                                    pageAnimationStyle: style,
                                                  );
                                                });
                                              },
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                                ),
                              ),
                              const Divider(height: 1),
                              _buildSettingLine(
                                context: context,
                                label: '其他',
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
                                                    (mode) => ChoiceChip(
                                                      label: Text(
                                                        _mangaReadModeLabel(
                                                          mode,
                                                        ),
                                                      ),
                                                      selected:
                                                          draft.mangaReadMode ==
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
                                                  .toList(growable: false),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              '留白',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelMedium?.copyWith(
                                                color:
                                                    Theme.of(context)
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
                                                    (value) => ChoiceChip(
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
                                                          draft = draft.copyWith(
                                                            mangaImagePadding:
                                                                value,
                                                          );
                                                        });
                                                      },
                                                    ),
                                                  )
                                                  .toList(growable: false),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              '图间距',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelMedium?.copyWith(
                                                color:
                                                    Theme.of(context)
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
                                                    (value) => ChoiceChip(
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
                                                          draft = draft.copyWith(
                                                            mangaImageSpacing:
                                                                value,
                                                          );
                                                        });
                                                      },
                                                    ),
                                                  )
                                                  .toList(growable: false),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              '背景',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelMedium?.copyWith(
                                                color:
                                                    Theme.of(context)
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
                                                  label: const Text('日间'),
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
                                                      );
                                                    });
                                                  },
                                                ),
                                                ChoiceChip(
                                                  label: const Text('护眼'),
                                                  selected:
                                                      draft.themeMode ==
                                                      ReaderThemeMode.sepia,
                                                  onSelected: (_) {
                                                    setModalState(() {
                                                      draft = draft.copyWith(
                                                        themeMode:
                                                            ReaderThemeMode
                                                                .sepia,
                                                        backgroundStyle:
                                                            ReaderBackgroundStyle
                                                                .warm,
                                                      );
                                                    });
                                                  },
                                                ),
                                                ChoiceChip(
                                                  label: const Text('夜间'),
                                                  selected:
                                                      draft.themeMode ==
                                                      ReaderThemeMode.dark,
                                                  onSelected: (_) {
                                                    setModalState(() {
                                                      draft = draft.copyWith(
                                                        themeMode:
                                                            ReaderThemeMode
                                                                .dark,
                                                        backgroundStyle:
                                                            ReaderBackgroundStyle
                                                                .plain,
                                                      );
                                                    });
                                                  },
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              '加载策略',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelMedium?.copyWith(
                                                color:
                                                    Theme.of(context)
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
                                                    (strategy) => ChoiceChip(
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
                                                          draft = draft.copyWith(
                                                            mangaLoadStrategy:
                                                                strategy,
                                                          );
                                                        });
                                                      },
                                                    ),
                                                  )
                                                  .toList(growable: false),
                                            ),
                                          ],
                                        )
                                        : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                OutlinedButton(
                                                  onPressed: () async {
                                                    final result = await _showSpacingSheet(
                                                      initialLineHeight:
                                                          draft.lineHeight,
                                                      initialHorizontalPadding:
                                                          draft
                                                              .horizontalPadding,
                                                      initialParagraphSpacing:
                                                          draft
                                                              .paragraphSpacing,
                                                      initialParagraphIndent:
                                                          draft.paragraphIndent,
                                                    );
                                                    if (result == null) {
                                                      return;
                                                    }
                                                    setModalState(() {
                                                      draft = draft.copyWith(
                                                        horizontalPadding:
                                                            result
                                                                .horizontalPadding,
                                                        lineHeight:
                                                            result.lineHeight,
                                                        paragraphSpacing:
                                                            result
                                                                .paragraphSpacing,
                                                        paragraphIndent:
                                                            result
                                                                .paragraphIndent,
                                                      );
                                                    });
                                                  },
                                                  child: const Text('间距设置'),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                setModalState(() {
                                  draft = const ReaderSettings();
                                });
                              },
                              child: const Text('恢复默认'),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(draft),
                              child: const Text('应用'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted) {
      return;
    }

    if (shouldRestoreOverlay) {
      setState(() {
        _showOverlayControls = true;
      });
    }

    if (result == null) {
      return;
    }

    final normalizedResult =
        result.pageAnimationStyle == ReaderPageAnimationStyle.simulation
            ? result.copyWith(pageAnimationStyle: ReaderPageAnimationStyle.curl)
            : result;

    final appliedResult = normalizedResult.copyWith(
      pageTurnMode: ReaderPageTurnMode.tap,
    );

    setState(() {
      _settings = appliedResult;
    });
    await _preferencesService.saveSettings(appliedResult);
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
    required ReaderThemeMode mode,
    required ReaderBackgroundStyle backgroundStyle,
    required ValueChanged<ReaderSettings> onChanged,
  }) {
    final selected =
        draft.themeMode == mode && draft.backgroundStyle == backgroundStyle;

    return GestureDetector(
      onTap: () {
        onChanged(
          draft.copyWith(
            themeMode: mode,
            backgroundStyle: backgroundStyle,
            clearBackgroundImage: true,
          ),
        );
      },
      child: Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color:
                selected ? Theme.of(context).colorScheme.primary : Colors.grey,
            width: selected ? 2 : 1,
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundToneDot({
    required ReaderSettings draft,
    required ReaderBackgroundTone tone,
    required ValueChanged<ReaderSettings> onChanged,
  }) {
    final effectiveMode =
        Theme.of(context).brightness == Brightness.dark
            ? ReaderThemeMode.dark
            : (draft.themeMode == ReaderThemeMode.sepia
                ? ReaderThemeMode.sepia
                : ReaderThemeMode.light);

    final preview = draft.copyWith(backgroundTone: tone);
    final previewColors = _resolveThemeColors(effectiveMode, preview);
    final selected = draft.backgroundTone == tone;

    return GestureDetector(
      onTap: () => onChanged(preview),
      child: Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: previewColors.background,
          shape: BoxShape.circle,
          border: Border.all(
            color:
                selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundTile({
    required String label,
    required bool selected,
    Uint8List? previewBytes,
  }) {
    final image =
        previewBytes == null
            ? null
            : DecorationImage(
              image: MemoryImage(previewBytes),
              fit: BoxFit.cover,
            );

    return Container(
      width: 58,
      height: _kPinnedHeaderHeight,
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
              ? Text(label, style: Theme.of(context).textTheme.labelSmall)
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
              ),
    );
  }

  Future<String?> _pickBackgroundImageBase64() async {
    try {
      const maxBytes = 900 * 1024;
      const typeGroup = XTypeGroup(
        label: 'image',
        extensions: ['jpg', 'jpeg', 'png', 'webp'],
        mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
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
    } catch (error) {
      _showMessage('选择背景失败：$error');
      return null;
    }
  }

  String _fontWeightLabel(ReaderFontWeightLevel level) {
    return switch (level) {
      ReaderFontWeightLevel.light => '字体: 细',
      ReaderFontWeightLevel.regular => '字体: 常规',
      ReaderFontWeightLevel.medium => '字体: 粗',
    };
  }

  Future<_ReaderSpacingSheetResult?> _showSpacingSheet({
    required double initialLineHeight,
    required double initialHorizontalPadding,
    required double initialParagraphSpacing,
    required double initialParagraphIndent,
  }) async {
    const lineOptions = <_ReaderSpacingOption>[
      _ReaderSpacingOption('小', 1.3),
      _ReaderSpacingOption('较小', 1.5),
      _ReaderSpacingOption('适中', 1.7),
      _ReaderSpacingOption('大', 2.0),
    ];

    const paddingOptions = <_ReaderSpacingOption>[
      _ReaderSpacingOption('小', 12),
      _ReaderSpacingOption('适中', 18),
      _ReaderSpacingOption('较大', 24),
      _ReaderSpacingOption('大', 30),
    ];

    const paragraphOptions = <_ReaderSpacingOption>[
      _ReaderSpacingOption('小', 8),
      _ReaderSpacingOption('较小', 10),
      _ReaderSpacingOption('适中', 14),
      _ReaderSpacingOption('大', 20),
    ];

    const indentOptions = <_ReaderSpacingOption>[
      _ReaderSpacingOption('无', 0),
      _ReaderSpacingOption('小', 2),
      _ReaderSpacingOption('适中', 4),
      _ReaderSpacingOption('大', 6),
    ];

    double lineHeight = initialLineHeight;
    double horizontalPadding = initialHorizontalPadding;
    double paragraphSpacing = initialParagraphSpacing;
    double paragraphIndent = initialParagraphIndent;

    String resolveLabel(List<_ReaderSpacingOption> options, double value) {
      const epsilon = 0.06;
      for (final option in options) {
        if ((option.value - value).abs() < epsilon) {
          return option.label;
        }
      }
      return '自定义';
    }

    return showModalBottomSheet<_ReaderSpacingSheetResult>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentLineLabel = resolveLabel(lineOptions, lineHeight);
            final currentPaddingLabel = resolveLabel(
              paddingOptions,
              horizontalPadding,
            );

            final currentParagraphLabel = resolveLabel(
              paragraphOptions,
              paragraphSpacing,
            );
            final currentIndentLabel = resolveLabel(
              indentOptions,
              paragraphIndent,
            );

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.72,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '间距设置',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '当前：行间距 $currentLineLabel / 页面边距 $currentPaddingLabel / 段落 $currentParagraphLabel / 缩进 $currentIndentLabel',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          children: [
                            const SizedBox(height: 16),
                            Text(
                              '行间距',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final option in lineOptions)
                                  ChoiceChip(
                                    label: Text(option.label),
                                    selected:
                                        (option.value - lineHeight).abs() <
                                        0.06,
                                    onSelected: (_) {
                                      setModalState(() {
                                        lineHeight = option.value;
                                      });
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '页面边距',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final option in paddingOptions)
                                  ChoiceChip(
                                    label: Text(option.label),
                                    selected:
                                        (option.value - horizontalPadding)
                                            .abs() <
                                        0.6,
                                    onSelected: (_) {
                                      setModalState(() {
                                        horizontalPadding = option.value;
                                      });
                                    },
                                  ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            Text(
                              '段落间距',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final option in paragraphOptions)
                                  ChoiceChip(
                                    label: Text(option.label),
                                    selected:
                                        (option.value - paragraphSpacing)
                                            .abs() <
                                        0.6,
                                    onSelected: (_) {
                                      setModalState(() {
                                        paragraphSpacing = option.value;
                                      });
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '首行缩进',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final option in indentOptions)
                                  ChoiceChip(
                                    label: Text(option.label),
                                    selected:
                                        (option.value - paragraphIndent).abs() <
                                        0.6,
                                    onSelected: (_) {
                                      setModalState(() {
                                        paragraphIndent = option.value;
                                      });
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('取消'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () {
                              Navigator.of(context).pop(
                                _ReaderSpacingSheetResult(
                                  lineHeight: lineHeight,
                                  horizontalPadding: horizontalPadding,
                                  paragraphSpacing: paragraphSpacing,
                                  paragraphIndent: paragraphIndent,
                                ),
                              );
                            },
                            child: const Text('应用'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
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
      ReaderPageAnimationStyle.simulation => '仿真',
      ReaderPageAnimationStyle.cover => '覆盖',
      ReaderPageAnimationStyle.translate => '平移',
      ReaderPageAnimationStyle.vertical => '上下',
      ReaderPageAnimationStyle.none => '无动画',
    };
  }

  _ReaderThemeColors _resolveThemeColors(
    ReaderThemeMode mode,
    ReaderSettings settings,
  ) {
    final scheme = Theme.of(context).colorScheme;

    final baseBackground = _backgroundForTone(scheme, settings.backgroundTone);
    final baseOverlay = _overlayForTone(scheme, settings.backgroundTone);

    var background = baseBackground;
    var overlay = baseOverlay;
    var textColor = scheme.onSurface;
    var metaColor = scheme.onSurfaceVariant;
    final dividerColor = scheme.outlineVariant.withValues(alpha: 0.6);

    if (mode == ReaderThemeMode.sepia &&
        Theme.of(context).brightness != Brightness.dark) {
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

  Color _backgroundForTone(ColorScheme scheme, ReaderBackgroundTone tone) {
    return switch (tone) {
      ReaderBackgroundTone.surface => scheme.surface,
      ReaderBackgroundTone.containerLow => scheme.surfaceContainerLow,
      ReaderBackgroundTone.container => scheme.surfaceContainer,
      ReaderBackgroundTone.containerHigh => scheme.surfaceContainerHigh,
      ReaderBackgroundTone.containerHighest => scheme.surfaceContainerHighest,
    };
  }

  Color _overlayForTone(ColorScheme scheme, ReaderBackgroundTone tone) {
    return switch (tone) {
      ReaderBackgroundTone.surface => scheme.surfaceContainerLow,
      ReaderBackgroundTone.containerLow => scheme.surfaceContainer,
      ReaderBackgroundTone.container => scheme.surfaceContainerHigh,
      ReaderBackgroundTone.containerHigh => scheme.surfaceContainerHighest,
      ReaderBackgroundTone.containerHighest => scheme.surfaceContainerHighest,
    };
  }

  Color _shiftLightness(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final shifted = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(shifted).toColor();
  }
}

class _ReaderSpacingSheetResult {
  const _ReaderSpacingSheetResult({
    required this.lineHeight,
    required this.horizontalPadding,
    required this.paragraphSpacing,
    required this.paragraphIndent,
  });

  final double lineHeight;
  final double horizontalPadding;
  final double paragraphSpacing;
  final double paragraphIndent;
}

class _ReaderSpacingOption {
  const _ReaderSpacingOption(this.label, this.value);

  final String label;
  final double value;
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
