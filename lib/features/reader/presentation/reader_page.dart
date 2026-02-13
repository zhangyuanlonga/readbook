import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reader_settings.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../book/application/book_detail_service.dart';
import '../../bookshelf/application/bookshelf_service.dart';
import '../application/chapter_content_service.dart';
import '../application/reader_preferences_service.dart';

class ReaderPage extends StatefulWidget {
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
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage>
    with SingleTickerProviderStateMixin {
  final BookDetailService _detailService = BookDetailService();
  final ChapterContentService _contentService = ChapterContentService();
  final ReaderPreferencesService _preferencesService =
      ReaderPreferencesService();
  final BookshelfService _bookshelfService = BookshelfService();
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _pageTurnFxController;

  int _pageTurnDirection = 0;

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
  bool _isShelfActionLoading = false;
  String? _errorText;
  String _content = '';
  List<String> _paragraphs = const [];
  ReadingProgress? _bootstrapProgress;
  Timer? _progressDebounceTimer;

  @override
  void initState() {
    super.initState();
    _chapterId = widget.chapterId;
    _chapterUrl = widget.chapterUrl?.trim();
    _chapterTitle = widget.chapterTitle?.trim();
    _sourceId = widget.sourceId?.trim();
    _detailUrl = widget.detailUrl?.trim();
    _currentIndex = widget.chapterIndex;
    _pageTurnFxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scrollController.addListener(_onScrollChanged);

    _bootstrap();
  }

  @override
  void dispose() {
    _progressDebounceTimer?.cancel();
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    _pageTurnFxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _resolveThemeColors(_settings.themeMode);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Stack(
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
            _buildPageTurnEffect(colors),
            _buildTopOverlay(colors),
            _buildBottomOverlay(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundLayer(_ReaderThemeColors colors) {
    final decoration = switch (_settings.backgroundStyle) {
      ReaderBackgroundStyle.plain => BoxDecoration(color: colors.background),
      ReaderBackgroundStyle.paper => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _shiftLightness(colors.background, 0.03),
            _shiftLightness(colors.background, -0.02),
          ],
        ),
      ),
      ReaderBackgroundStyle.warm => const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF9F1DE), Color(0xFFF3E2C5)],
        ),
      ),
    };

    return DecoratedBox(decoration: decoration);
  }

  Widget _buildReaderContent(_ReaderThemeColors colors) {
    return Column(
      children: [
        const SizedBox(height: 4),
        if (_showOverlayControls &&
            (_currentIndex != null || _chapters.isNotEmpty))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                if (_currentIndex != null)
                  Text(
                    '第 ${_currentIndex! + 1} / ${_chapters.length} 章',
                    style: TextStyle(color: colors.meta, fontSize: 12),
                  ),
                const Spacer(),
                if (_isLoadingContent)
                  Text(
                    '加载中...',
                    style: TextStyle(color: colors.meta, fontSize: 12),
                  ),
              ],
            ),
          ),
        Expanded(child: _buildBody(colors)),
      ],
    );
  }

  Widget _buildBody(_ReaderThemeColors colors) {
    if (_isBootstrapping || _isLoadingContent) {
      return _buildTapAwareBody(
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_errorText != null) {
      return _buildTapAwareBody(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _errorText!,
                  style: TextStyle(color: colors.meta),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed:
                      () => _loadCurrentChapter(initialScrollRatio: null),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_content.trim().isEmpty) {
      return _buildTapAwareBody(
        child: Center(
          child: Text('正文为空', style: TextStyle(color: colors.meta)),
        ),
      );
    }

    return _buildTapAwareBody(child: _buildReaderList(colors));
  }

  Widget _buildReaderList(_ReaderThemeColors colors) {
    final paragraphs = _paragraphs;

    return ListView.builder(
      key: ValueKey(_chapterId),
      controller: _scrollController,
      cacheExtent: 1200,
      padding: EdgeInsets.fromLTRB(
        _settings.horizontalPadding,
        16,
        _settings.horizontalPadding,
        88,
      ),
      itemCount: paragraphs.isEmpty ? 3 : paragraphs.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Text(
            _chapterTitle?.isNotEmpty == true ? _chapterTitle! : '未命名章节',
            style: TextStyle(
              color: colors.text,
              fontWeight: FontWeight.w600,
              fontSize: _settings.fontSize + 2,
              height: _settings.lineHeight,
            ),
          );
        }

        if (index == 1) {
          return const SizedBox(height: 16);
        }

        if (paragraphs.isEmpty) {
          return Text(_content, style: _paragraphTextStyle(colors));
        }

        final paragraph = paragraphs[index - 2];
        final isLast = index == paragraphs.length + 1;

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

  Widget _buildTapAwareBody({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp:
              (details) =>
                  _onReaderTap(details.localPosition, constraints.biggest),
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
    );
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

  Widget _buildPageTurnEffect(_ReaderThemeColors colors) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _pageTurnFxController,
          builder: (context, child) {
            if (_pageTurnDirection == 0) {
              return const SizedBox.shrink();
            }

            final progress = Curves.easeOut.transform(
              _pageTurnFxController.value,
            );
            final widthFactor = (progress * 0.34).clamp(0.0, 0.34);
            final gradient =
                _pageTurnDirection > 0
                    ? const LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [Color(0x1A000000), Color(0x00000000)],
                    )
                    : const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0x1A000000), Color(0x00000000)],
                    );

            final align =
                _pageTurnDirection > 0
                    ? Alignment.centerRight
                    : Alignment.centerLeft;

            return Align(
              alignment: align,
              child: FractionallySizedBox(
                widthFactor: widthFactor,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: gradient,
                    border: Border(
                      left:
                          _pageTurnDirection > 0
                              ? BorderSide(
                                color: colors.divider.withValues(alpha: 0.35),
                              )
                              : BorderSide.none,
                      right:
                          _pageTurnDirection < 0
                              ? BorderSide(
                                color: colors.divider.withValues(alpha: 0.35),
                              )
                              : BorderSide.none,
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

  Future<void> _playPageTurnEffect(int direction) async {
    _pageTurnDirection = direction;
    await _pageTurnFxController.forward(from: 0);
    if (!mounted) {
      return;
    }
    setState(() {
      _pageTurnDirection = 0;
    });
  }

  Widget _buildTopOverlay(_ReaderThemeColors colors) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_showOverlayControls,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          offset: _showOverlayControls ? Offset.zero : const Offset(0, -1),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _showOverlayControls ? 1 : 0,
            child: Container(
              decoration: BoxDecoration(
                color: colors.overlay,
                border: Border(bottom: BorderSide(color: colors.divider)),
              ),
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: '返回',
                    icon: const Icon(Icons.arrow_back_ios_new),
                  ),
                  Expanded(
                    child: Text(
                      _chapterTitle?.isNotEmpty == true ? _chapterTitle! : '阅读',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.text),
                    ),
                  ),
                  IconButton(
                    onPressed: _isShelfActionLoading ? null : _toggleBookshelf,
                    tooltip: _isInBookshelf ? '移出书架' : '加入书架',
                    icon:
                        _isShelfActionLoading
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : Icon(
                              _isInBookshelf
                                  ? Icons.bookmark_added
                                  : Icons.bookmark_add_outlined,
                            ),
                  ),
                  IconButton(
                    onPressed: _openDetailPage,
                    tooltip: '查看详情',
                    icon: const Icon(Icons.info_outline),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomOverlay(_ReaderThemeColors colors) {
    final dayNightLabel =
        _settings.themeMode == ReaderThemeMode.dark ? '日间' : '夜间';
    final dayNightIcon =
        _settings.themeMode == ReaderThemeMode.dark
            ? Icons.light_mode_outlined
            : Icons.dark_mode_outlined;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !_showOverlayControls,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          offset: _showOverlayControls ? Offset.zero : const Offset(0, 1),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _showOverlayControls ? 1 : 0,
            child: Container(
              decoration: BoxDecoration(
                color: colors.overlay,
                border: Border(top: BorderSide(color: colors.divider)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              child: Row(
                children: [
                  Expanded(
                    child: _buildToolbarAction(
                      icon: Icons.list_alt_outlined,
                      label: '目录',
                      onTap: _showCatalogSheet,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildToolbarAction(
                      icon: dayNightIcon,
                      label: dayNightLabel,
                      onTap: _toggleDayNight,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildToolbarAction(
                      icon: Icons.tune,
                      label: '设置',
                      onTap: _showSettingsSheet,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarAction({
    required IconData icon,
    required String label,
    required Future<void> Function() onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => unawaited(onTap()),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(icon), const SizedBox(height: 4), Text(label)],
        ),
      ),
    );
  }

  Future<void> _bootstrap() async {
    try {
      _settings = await _preferencesService.loadSettings();

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
      setState(() {
        _errorText = _toUserReadableError(error);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '阅读器初始化失败。';
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
    return switch (error.code) {
      ErrorCode.network => '网络请求失败，请检查网络或更换书源。',
      ErrorCode.validation => '书源规则配置不完整，无法继续阅读。',
      ErrorCode.ruleParse => '书源规则语法错误，正文解析失败。',
      ErrorCode.ruleMatchEmpty => '当前章节没有可读取内容，请切换章节或书源。',
      ErrorCode.decode => '正文解析失败，可能是编码或格式不兼容。',
      ErrorCode.unknownSource => '书源不存在或已被删除。',
      ErrorCode.unknown => '加载失败，请稍后重试。',
    };
  }

  void _setContent(String content) {
    _content = content;
    _paragraphs = _splitParagraphs(content);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final normalized = ratio.clamp(0.0, 1.0);
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent <= 0) {
        _scrollController.jumpTo(0);
        return;
      }

      _scrollController.jumpTo(maxExtent * normalized);
    });
  }

  void _onScrollChanged() {
    if (_isBootstrapping || _isLoadingContent || _errorText != null) {
      return;
    }
    if (_content.trim().isEmpty || _currentIndex == null) {
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
      final contentResult = await _contentService.load(
        sourceId: sourceId,
        chapterUrl: chapterUrl,
      );

      if (!mounted) {
        return false;
      }

      setState(() {
        _setContent(contentResult.content);
      });

      final targetRatio = initialScrollRatio?.clamp(0.0, 1.0) ?? 0.0;
      _restoreScrollPosition(targetRatio);

      await _saveProgress();
      await _preloadNeighbors();
      return true;
    } on AppException catch (error) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _errorText = _toUserReadableError(error);
      });
      return false;
    } catch (_) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _errorText = '加载正文失败。';
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
    if (!_scrollController.hasClients || viewportHeight <= 0) {
      _goToPreviousChapter();
      return;
    }

    final position = _scrollController.position;
    if (position.pixels <= 24) {
      _goToPreviousChapter();
      return;
    }

    await _playPageTurnEffect(-1);
    final target =
        (position.pixels - viewportHeight * _settings.pageTurnStepRatio)
            .clamp(0, position.maxScrollExtent)
            .toDouble();

    await _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  Future<void> _goToNextPage(double viewportHeight) async {
    if (!_scrollController.hasClients || viewportHeight <= 0) {
      _goToNextChapter();
      return;
    }

    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels <= 24) {
      _goToNextChapter();
      return;
    }

    await _playPageTurnEffect(1);
    final target =
        (position.pixels + viewportHeight * _settings.pageTurnStepRatio)
            .clamp(0, position.maxScrollExtent)
            .toDouble();

    await _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  void _goToPreviousChapter() {
    final index = _currentIndex;
    if (index == null || index <= 0) {
      _showMessage('已经是第一章。');
      return;
    }
    unawaited(_jumpTo(index - 1));
  }

  void _goToNextChapter() {
    final index = _currentIndex;
    if (index == null || index >= _chapters.length - 1) {
      _showMessage('已经是最后一章。');
      return;
    }
    unawaited(_jumpTo(index + 1));
  }

  Future<void> _jumpTo(int index) async {
    final chapter = _chapters[index];

    final previousChapterId = _chapterId;
    final previousChapterUrl = _chapterUrl;
    final previousChapterTitle = _chapterTitle;
    final previousIndex = _currentIndex;
    final previousContent = _content;

    setState(() {
      _currentIndex = index;
      _chapterId = chapter.id;
      _chapterUrl = chapter.chapterUrl;
      _chapterTitle = chapter.title;
      _errorText = null;
    });

    final success = await _loadCurrentChapter(initialScrollRatio: 0);
    if (success || !mounted) {
      return;
    }

    setState(() {
      _chapterId = previousChapterId;
      _chapterUrl = previousChapterUrl;
      _chapterTitle = previousChapterTitle;
      _currentIndex = previousIndex;
      _setContent(previousContent);
      _errorText = null;
    });

    _showChapterSwitchFailedSnackbar(index);
  }

  void _onReaderTap(Offset localPosition, Size size) {
    final centerLeft = size.width * 0.28;
    final centerRight = size.width * 0.72;
    final centerTop = size.height * 0.2;
    final centerBottom = size.height * 0.8;

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

    if (_settings.pageTurnMode != ReaderPageTurnMode.tap) {
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

  Future<void> _showCatalogSheet() async {
    if (_chapters.isEmpty) {
      _showMessage('当前书籍暂无目录。');
      return;
    }

    const itemHeight = 72.0;
    final currentIndex = _currentIndex;
    final initialOffset =
        currentIndex == null
            ? 0.0
            : ((currentIndex - 3).clamp(0, _chapters.length) * itemHeight)
                .toDouble();
    final scrollController = ScrollController(
      initialScrollOffset: initialOffset,
    );

    var didLocateCurrent = false;
    final selectedIndex = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        if (!didLocateCurrent && currentIndex != null) {
          didLocateCurrent = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!scrollController.hasClients) {
              return;
            }
            final targetOffset =
                ((currentIndex - 2).clamp(0, _chapters.length) * itemHeight)
                    .toDouble();
            scrollController.animateTo(
              targetOffset,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
            );
          });
        }

        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.86,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '目录（${_chapters.length} 章）',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (currentIndex != null)
                        TextButton.icon(
                          onPressed: () {
                            final target =
                                ((currentIndex - 2).clamp(0, _chapters.length) *
                                        itemHeight)
                                    .toDouble();
                            scrollController.animateTo(
                              target,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                            );
                          },
                          icon: const Icon(
                            Icons.my_location_outlined,
                            size: 16,
                          ),
                          label: Text('定位 ${currentIndex + 1}'),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: _chapters.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final chapter = _chapters[index];
                      final selected = index == currentIndex;

                      return ListTile(
                        selected: selected,
                        title: Text(
                          chapter.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('第 ${index + 1} 章'),
                        trailing:
                            selected
                                ? const Icon(Icons.play_arrow_rounded)
                                : null,
                        onTap: () => Navigator.of(context).pop(index),
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

    scrollController.dispose();

    if (!mounted ||
        selectedIndex == null ||
        selectedIndex == _currentIndex ||
        selectedIndex < 0 ||
        selectedIndex >= _chapters.length) {
      return;
    }

    await _jumpTo(selectedIndex);
  }

  Future<void> _toggleDayNight() async {
    final nextMode =
        _settings.themeMode == ReaderThemeMode.dark
            ? ReaderThemeMode.light
            : ReaderThemeMode.dark;
    final updated = _settings.copyWith(themeMode: nextMode);

    setState(() {
      _settings = updated;
    });
    await _preferencesService.saveSettings(updated);

    _showMessage(nextMode == ReaderThemeMode.dark ? '已切换夜间模式。' : '已切换日间模式。');
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

  Future<void> _showSettingsSheet() async {
    final shouldRestoreOverlay = _showOverlayControls;
    if (shouldRestoreOverlay) {
      _hideOverlayControls();
    }

    var draft = _settings;

    final result = await showModalBottomSheet<ReaderSettings>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  20 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '阅读设置',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _buildSettingsSection(
                        context: context,
                        title: '排版',
                        children: [
                          _buildSliderSettingItem(
                            context: context,
                            label: '字号',
                            valueText: draft.fontSize.toStringAsFixed(0),
                            min: 14,
                            max: 30,
                            divisions: 16,
                            value: draft.fontSize,
                            onChanged: (value) {
                              setModalState(() {
                                draft = draft.copyWith(fontSize: value);
                              });
                            },
                          ),
                          _buildSliderSettingItem(
                            context: context,
                            label: '行距',
                            valueText: draft.lineHeight.toStringAsFixed(1),
                            min: 1.2,
                            max: 2.2,
                            divisions: 10,
                            value: draft.lineHeight,
                            onChanged: (value) {
                              setModalState(() {
                                draft = draft.copyWith(lineHeight: value);
                              });
                            },
                          ),
                          _buildSliderSettingItem(
                            context: context,
                            label: '边距',
                            valueText: draft.horizontalPadding.toStringAsFixed(
                              0,
                            ),
                            min: 12,
                            max: 36,
                            divisions: 12,
                            value: draft.horizontalPadding,
                            onChanged: (value) {
                              setModalState(() {
                                draft = draft.copyWith(
                                  horizontalPadding: value,
                                );
                              });
                            },
                          ),
                          _buildSliderSettingItem(
                            context: context,
                            label: '段落间距',
                            valueText: draft.paragraphSpacing.toStringAsFixed(
                              0,
                            ),
                            min: 0,
                            max: 28,
                            divisions: 14,
                            value: draft.paragraphSpacing,
                            onChanged: (value) {
                              setModalState(() {
                                draft = draft.copyWith(paragraphSpacing: value);
                              });
                            },
                          ),
                          _buildSliderSettingItem(
                            context: context,
                            label: '首行缩进',
                            valueText: draft.paragraphIndent.toStringAsFixed(0),
                            min: 0,
                            max: 8,
                            divisions: 8,
                            value: draft.paragraphIndent,
                            onChanged: (value) {
                              setModalState(() {
                                draft = draft.copyWith(paragraphIndent: value);
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildSettingsSection(
                        context: context,
                        title: '主题与背景',
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '背景样式',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 6),
                              SegmentedButton<ReaderBackgroundStyle>(
                                segments: const [
                                  ButtonSegment(
                                    value: ReaderBackgroundStyle.plain,
                                    label: Text('纯色'),
                                  ),
                                  ButtonSegment(
                                    value: ReaderBackgroundStyle.paper,
                                    label: Text('纸感'),
                                  ),
                                  ButtonSegment(
                                    value: ReaderBackgroundStyle.warm,
                                    label: Text('暖色'),
                                  ),
                                ],
                                selected: {draft.backgroundStyle},
                                onSelectionChanged: (selection) {
                                  setModalState(() {
                                    draft = draft.copyWith(
                                      backgroundStyle: selection.first,
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                          _buildSliderSettingItem(
                            context: context,
                            label: '亮度',
                            valueText:
                                '${(draft.brightness * 100).toStringAsFixed(0)}%',
                            min: 0.2,
                            max: 1,
                            divisions: 16,
                            value: draft.brightness,
                            onChanged: (value) {
                              setModalState(() {
                                draft = draft.copyWith(brightness: value);
                              });
                            },
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '主题模式',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 6),
                              SegmentedButton<ReaderThemeMode>(
                                segments: const [
                                  ButtonSegment(
                                    value: ReaderThemeMode.light,
                                    label: Text('浅色'),
                                  ),
                                  ButtonSegment(
                                    value: ReaderThemeMode.sepia,
                                    label: Text('护眼'),
                                  ),
                                  ButtonSegment(
                                    value: ReaderThemeMode.dark,
                                    label: Text('深色'),
                                  ),
                                ],
                                selected: {draft.themeMode},
                                onSelectionChanged: (selection) {
                                  setModalState(() {
                                    draft = draft.copyWith(
                                      themeMode: selection.first,
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildSettingsSection(
                        context: context,
                        title: '翻页',
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '翻页模式',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 6),
                              SegmentedButton<ReaderPageTurnMode>(
                                segments: const [
                                  ButtonSegment(
                                    value: ReaderPageTurnMode.tap,
                                    label: Text('点击翻页'),
                                  ),
                                  ButtonSegment(
                                    value: ReaderPageTurnMode.scroll,
                                    label: Text('滚动阅读'),
                                  ),
                                ],
                                selected: {draft.pageTurnMode},
                                onSelectionChanged: (selection) {
                                  setModalState(() {
                                    draft = draft.copyWith(
                                      pageTurnMode: selection.first,
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                          if (draft.pageTurnMode == ReaderPageTurnMode.tap)
                            _buildSliderSettingItem(
                              context: context,
                              label: '翻页步进',
                              valueText:
                                  '${(draft.pageTurnStepRatio * 100).toStringAsFixed(0)}%',
                              min: 0.6,
                              max: 1,
                              divisions: 8,
                              value: draft.pageTurnStepRatio,
                              onChanged: (value) {
                                setModalState(() {
                                  draft = draft.copyWith(
                                    pageTurnStepRatio: value,
                                  );
                                });
                              },
                            )
                          else
                            Text(
                              '滚动阅读模式下，点击左右区域不触发翻页。',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
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

    setState(() {
      _settings = result;
    });
    await _preferencesService.saveSettings(result);
  }

  Widget _buildSettingsSection({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    final sectionChildren = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        sectionChildren.add(const SizedBox(height: 10));
      }
      sectionChildren.add(children[index]);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...sectionChildren,
        ],
      ),
    );
  }

  Widget _buildSliderSettingItem({
    required BuildContext context,
    required String label,
    required String valueText,
    required double min,
    required double max,
    int? divisions,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                valueText,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        Slider(
          min: min,
          max: max,
          divisions: divisions,
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  _ReaderThemeColors _resolveThemeColors(ReaderThemeMode mode) {
    return switch (mode) {
      ReaderThemeMode.light => const _ReaderThemeColors(
        background: Color(0xFFFDFDFD),
        text: Color(0xFF111827),
        meta: Color(0xFF6B7280),
        divider: Color(0xFFE5E7EB),
        overlay: Color(0xFFF7F7F7),
      ),
      ReaderThemeMode.sepia => const _ReaderThemeColors(
        background: Color(0xFFF7EEDC),
        text: Color(0xFF3F2E1F),
        meta: Color(0xFF6E563D),
        divider: Color(0xFFE2D2B4),
        overlay: Color(0xFFF0E3C7),
      ),
      ReaderThemeMode.dark => const _ReaderThemeColors(
        background: Color(0xFF1E1F24),
        text: Color(0xFFE5E7EB),
        meta: Color(0xFF9CA3AF),
        divider: Color(0xFF3F4450),
        overlay: Color(0xFF2A2C33),
      ),
    };
  }

  Color _shiftLightness(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final shifted = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(shifted).toColor();
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
