// ignore_for_file: unused_element

part of 'reader_page.dart';

extension _ReaderPageContentLoadingExtension on _ReaderPageState {
  void _setContentFlow(
    String content, {
    List<String> imageUrls = const [],
    Map<String, String> imageHeaders = const {},
    String? contentType,
    String? sourceFilePath,
    int? totalPageCount,
    String? audioUrl,
    String? audioManifestUrl,
    Map<String, String> audioHeaders = const {},
    String? executionContext,
    ReaderDocument? document,
    List<String>? precomputedParagraphs,
    List<List<ReaderPagedSlice>>? precomputedPagedPages,
    int? precomputedCurrentPageIndex,
    String? precomputedPaginationSignature,
  }) {
    final resolvedContentState = _contentLoadingController.buildResolvedContent(
      content: content,
      imageUrls: imageUrls,
      imageHeaders: imageHeaders,
      document: document,
      precomputedParagraphs: precomputedParagraphs,
      precomputedPagedPages: precomputedPagedPages,
      precomputedCurrentPageIndex: precomputedCurrentPageIndex,
      precomputedPaginationSignature: precomputedPaginationSignature,
    );

    _stopAutoRead();
    _resetScrollEdgeAdvanceState();
    _disposeMangaTransformControllers();
    _document = resolvedContentState.document;
    _content = resolvedContentState.content;
    _resolvedContentType =
        contentType?.trim().isEmpty ?? true ? null : contentType!.trim();
    _chapterImageUrls = resolvedContentState.chapterImageUrls;
    _chapterImageHeaders = resolvedContentState.imageHeaders;
    _chapterAudioUrl =
        audioUrl?.trim().isEmpty ?? true ? null : audioUrl!.trim();
    _chapterAudioManifestUrl =
        audioManifestUrl?.trim().isEmpty ?? true
            ? null
            : audioManifestUrl!.trim();
    _chapterAudioHeaders = Map<String, String>.unmodifiable(audioHeaders);
    _chapterExecutionContext =
        executionContext?.trim().isEmpty ?? true
            ? null
            : executionContext!.trim();
    _audioPlaybackPosition = Duration.zero;
    _audioPlaybackDuration = Duration.zero;
    _audioPlaybackSpeed = 1.0;
    unawaited(_readerAudioController.reset());
    _chapterSourceFilePath =
        sourceFilePath?.trim().isEmpty ?? true ? null : sourceFilePath!.trim();
    _chapterTotalPageCount = totalPageCount;
    _documentPageCount = totalPageCount;
    _documentPageIndex = 0;
    _documentZoomScale = null;
    _documentPanDx = null;
    _documentPanDy = null;
    _pdfViewerController = null;
    _mangaImageRetryNonce.clear();
    _precachedInlineImageUrls.clear();
    _lastInlineImagePrecacheAt = null;
    _imagePageIndex = 0;
    _isTextSelectionActive = false;
    _selectionRange = null;
    _selectionStatus = SelectionStatus.none;
    _selectionStartOffset = 0;
    _selectionEndOffset = 0;
    _selectedSnippet = '';
    _hideBookmarkToolbar();
    _chapterBookmarks = const <Bookmark>[];
    _bookmarkRangesByParagraph = const <int, List<ReaderBookmarkRange>>{};
    if (_mangaPageController.hasClients) {
      _mangaPageController.jumpToPage(0);
    }
    _paragraphs = resolvedContentState.paragraphs;
    _renderItems = resolvedContentState.renderItems;
    _renderTextItemsByParagraph =
        resolvedContentState.renderTextItemsByParagraph;
    _pagedPages = resolvedContentState.pagedPages;
    _pagedBlockPages = const <List<ReaderPagedBlock>>[];
    _textPaginationFallbackDiagnostic = null;
    _resetLayoutReleaseRuntime();
    _pageTurnRuntimeController.currentPageIndex =
        resolvedContentState.currentPageIndex;
    _pageTurnRuntimeController.pagedPaginationState =
        resolvedContentState.paginationState;
    _resetCatalogSearchCache();
    _resetPagedTransitionState();
    _resetCurlAnimationState();
    _scheduleInlineImagePrecache();
    unawaited(_refreshChapterBookmarks());
  }

  bool _shouldBuildContinuousTextFlowForFlow(ChapterContentResult result) {
    return _shouldUseContinuousTextFlow &&
        !result.isImageContent &&
        result.document.paragraphs.isNotEmpty;
  }

  ReaderPageContinuousTextChapter _buildContinuousTextChapterFlow({
    required Chapter chapter,
    required int chapterIndex,
    required ReaderPageChapterLoadSnapshot snapshot,
  }) {
    return _fromContinuousTextChapterSupportFlow(
      _contentLoadingController.buildContinuousTextChapterFromResult(
        chapter: chapter,
        chapterIndex: chapterIndex,
        result: snapshot.result,
        isCached: snapshot.isCached,
      ),
    );
  }

  ReaderPageContinuousTextChapter _fromContinuousTextChapterSupportFlow(
    ReaderContinuousTextChapter chapter,
  ) {
    return ReaderPageContinuousTextChapter(
      chapterId: chapter.chapterId,
      chapterUrl: chapter.chapterUrl,
      chapterTitle: chapter.chapterTitle,
      displayTitle: chapter.displayTitle,
      chapterIndex: chapter.chapterIndex,
      content: chapter.content,
      document: chapter.document,
      paragraphs: chapter.paragraphs,
      isCached: chapter.isCached,
    );
  }

  List<ReaderPageContinuousTextChapter> _retainContinuousTextWindowFlow(
    Iterable<ReaderPageContinuousTextChapter> chapters, {
    int? currentChapterIndex,
  }) {
    return _chapterWindowController
        .retainWindow<ReaderPageContinuousTextChapter>(
          items: chapters,
          chapterIndexOf: (chapter) => chapter.chapterIndex,
          chapters: _chapters,
          currentChapterIndex: currentChapterIndex ?? _currentIndex,
        );
  }

  List<ReaderPageContinuousTextChapter>
  _insertContinuousTextChapterInWindowFlow(
    ReaderPageContinuousTextChapter chapter, {
    int? currentChapterIndex,
  }) {
    return _chapterWindowController
        .insertAndRetainWindow<ReaderPageContinuousTextChapter>(
          items: _continuousTextChapters,
          item: chapter,
          chapterIndexOf: (item) => item.chapterIndex,
          chapters: _chapters,
          currentChapterIndex: currentChapterIndex ?? _currentIndex,
        );
  }

  ReaderContinuousTextChapter _toContinuousTextChapterSupportFlow(
    ReaderPageContinuousTextChapter chapter,
  ) {
    return ReaderContinuousTextChapter(
      chapterId: chapter.chapterId,
      chapterUrl: chapter.chapterUrl,
      chapterTitle: chapter.chapterTitle,
      displayTitle: chapter.displayTitle,
      chapterIndex: chapter.chapterIndex,
      content: chapter.content,
      document: chapter.document,
      paragraphs: chapter.paragraphs,
      isCached: chapter.isCached,
    );
  }

  ReaderContinuousTextChapterLayout _toContinuousTextChapterLayoutSupportFlow(
    ReaderPageContinuousTextChapterLayout layout,
  ) {
    return ReaderContinuousTextChapterLayout(
      startOffset: layout.startOffset,
      endOffset: layout.endOffset,
    );
  }

  void _replaceContinuousTextFlowWithCurrentChapterFlow({
    required Chapter chapter,
    required int chapterIndex,
    required ReaderPageChapterLoadSnapshot snapshot,
  }) {
    if (!_shouldBuildContinuousTextFlowForFlow(snapshot.result)) {
      _continuousTextChapters = const <ReaderPageContinuousTextChapter>[];
      return;
    }

    _continuousTextChapters = _insertContinuousTextChapterInWindowFlow(
      _buildContinuousTextChapterFlow(
        chapter: chapter,
        chapterIndex: chapterIndex,
        snapshot: snapshot,
      ),
      currentChapterIndex: chapterIndex,
    );
  }

  Future<ReaderPageContinuousTextChapter?> _loadContinuousTextChapterFlow(
    int chapterIndex,
  ) async {
    if (chapterIndex < 0 || chapterIndex >= _chapters.length) {
      return null;
    }

    final chapter = _chapters[chapterIndex];
    if (!_chapterNavigation.isReadableChapter(chapter)) {
      return null;
    }
    if (chapterIndex == _currentIndex &&
        _chapterImageUrls.isEmpty &&
        _content.trim().isNotEmpty) {
      final currentParagraphs =
          _paragraphs.isEmpty ? <String>[_content] : _paragraphs;
      return ReaderPageContinuousTextChapter(
        chapterId: _chapterId,
        chapterUrl: (_chapterUrl ?? '').trim(),
        chapterTitle: chapter.title.trim(),
        displayTitle: (_chapterTitle ?? chapter.title).trim(),
        chapterIndex: chapterIndex,
        content: _content,
        document: _document,
        paragraphs: List<String>.unmodifiable(currentParagraphs),
        isCached: _isCurrentChapterCached,
      );
    }

    final chapterUrl = chapter.chapterUrl.trim();
    if (chapterUrl.isEmpty) {
      return null;
    }

    final snapshot = await _fetchChapterContentSnapshotFlow(
      sourceId: (_sourceId ?? '').trim(),
      chapterId: chapter.id,
      chapterUrl: chapterUrl,
      chapterTitle: chapter.title,
      chapterIndex: chapterIndex,
    );
    if (!_shouldBuildContinuousTextFlowForFlow(snapshot.result)) {
      return null;
    }
    return _buildContinuousTextChapterFlow(
      chapter: chapter,
      chapterIndex: chapterIndex,
      snapshot: snapshot,
    );
  }

  Future<ReaderPageContinuousTextChapter?>
  _loadAdjacentContinuousTextChapterFlow({required bool forward}) async {
    if (_isScrollEdgeAdvancingChapter ||
        !_shouldUseContinuousTextFlow ||
        _continuousTextChapters.isEmpty) {
      return null;
    }

    final anchorChapter = _findCurrentContinuousTextChapter();
    final beforeAnchorStart =
        anchorChapter == null
            ? null
            : _measureContinuousTextChapterLayoutFlow(
              anchorChapter,
            )?.startOffset;
    final beforeScrollOffset =
        _scrollController.hasClients ? _scrollController.position.pixels : null;
    final visibleChapter =
        _resolveActiveContinuousTextChapterFlow() ??
        _findCurrentContinuousTextChapter();
    final visibleChapterIndex = visibleChapter?.chapterIndex ?? _currentIndex;
    _continuousTextChapters = _retainContinuousTextWindowFlow(
      _continuousTextChapters,
      currentChapterIndex: visibleChapterIndex,
    );
    final plan = _chapterWindowController.buildWindowPlan(
      chapters: _chapters,
      currentChapterIndex: visibleChapterIndex,
    );
    final adjacentIndex =
        forward ? plan?.nextChapterIndex : plan?.previousChapterIndex;
    if (adjacentIndex == null) {
      return null;
    }
    for (final chapter in _continuousTextChapters) {
      if (chapter.chapterIndex == adjacentIndex) {
        return chapter;
      }
    }

    final targetIndex = _chapterWindowController.resolveAdjacentLoadIndex(
      chapters: _chapters,
      loadedChapterIndices: _continuousTextChapters.map(
        (item) => item.chapterIndex,
      ),
      currentChapterIndex: visibleChapterIndex,
      forward: forward,
    );
    if (targetIndex == null || targetIndex != adjacentIndex) {
      return null;
    }

    _isScrollEdgeAdvancingChapter = true;
    try {
      final chapter = await _loadContinuousTextChapterFlow(targetIndex);
      if (!mounted || chapter == null) {
        return null;
      }
      if (_continuousTextChapters.any(
        (item) => item.chapterIndex == chapter.chapterIndex,
      )) {
        return chapter;
      }
      _updateReaderState(() {
        _continuousTextChapters = _insertContinuousTextChapterInWindowFlow(
          chapter,
          currentChapterIndex: visibleChapterIndex,
        );
      });
      _restoreContinuousWindowAnchorAfterLayout(
        anchorChapter: anchorChapter,
        beforeAnchorStart: beforeAnchorStart,
        beforeScrollOffset: beforeScrollOffset,
      );
      return chapter;
    } finally {
      _isScrollEdgeAdvancingChapter = false;
    }
  }

  void _restoreContinuousWindowAnchorAfterLayout({
    required ReaderPageContinuousTextChapter? anchorChapter,
    required double? beforeAnchorStart,
    required double? beforeScrollOffset,
  }) {
    if (anchorChapter == null || beforeAnchorStart == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final afterAnchorStart =
          _measureContinuousTextChapterLayoutFlow(anchorChapter)?.startOffset;
      if (afterAnchorStart == null) {
        return;
      }
      final delta = afterAnchorStart - beforeAnchorStart;
      if (delta.abs() <= 0.5) {
        return;
      }
      final position = _scrollController.position;
      final target = ((beforeScrollOffset ?? position.pixels) + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((position.pixels - target).abs() > 0.5) {
        _logger.info(
          'Reader continuous window anchor restored',
          context: <String, Object?>{
            'chain': 'reader_scroll_step',
            'step': 'continuous_window_anchor_restored',
            'chapterId': anchorChapter.chapterId,
            'activeChapterId': _chapterId,
            'beforeAnchorStart': beforeAnchorStart.toStringAsFixed(1),
            'afterAnchorStart': afterAnchorStart.toStringAsFixed(1),
            'delta': delta.toStringAsFixed(1),
            'beforeScrollOffset': beforeScrollOffset?.toStringAsFixed(1),
            'targetOffset': target.toStringAsFixed(1),
          },
        );
        _scrollController.jumpTo(target);
      }
    });
  }

  bool _isContinuousTextChapterActiveFlow(
    ReaderPageContinuousTextChapter chapter,
  ) {
    return _contentLoadingController.isContinuousTextChapterActive(
      chapter: _toContinuousTextChapterSupportFlow(chapter),
      currentChapterIndex: _currentIndex,
      currentChapterId: _chapterId,
      currentChapterUrl: _chapterUrl,
    );
  }

  ReaderPageContinuousTextChapter? _findCurrentContinuousTextChapterFlow() {
    for (final chapter in _continuousTextChapters) {
      if (_isContinuousTextChapterActiveFlow(chapter)) {
        return chapter;
      }
    }
    return null;
  }

  ReaderPageContinuousTextChapterLayout?
  _measureContinuousTextChapterLayoutFlow(
    ReaderPageContinuousTextChapter chapter,
  ) {
    if (!_scrollController.hasClients) {
      return null;
    }

    final context = _continuousTextChapterKey(chapter).currentContext;
    if (context == null) {
      return null;
    }

    final RenderObject? renderObject;
    try {
      renderObject = context.findRenderObject();
    } on FlutterError {
      // During auto-read mode switches, chapter keyed subtrees can be inactive
      // for one frame. Treat them as temporarily unmeasurable instead of
      // failing the reader build.
      return null;
    }
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    if (!renderObject.attached) {
      return null;
    }

    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) {
      return null;
    }

    final double startOffset;
    try {
      startOffset = viewport.getOffsetToReveal(renderObject, 0).offset;
    } on FlutterError {
      return null;
    }
    return ReaderPageContinuousTextChapterLayout(
      startOffset: startOffset,
      endOffset: startOffset + renderObject.size.height,
    );
  }

  double _continuousTextChapterScrollRatioForFlow(
    ReaderPageContinuousTextChapter chapter,
  ) {
    if (!_scrollController.hasClients) {
      return 0;
    }

    final layout = _measureContinuousTextChapterLayoutFlow(chapter);
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

  double _continuousTextChapterDocumentRatioForFlow(
    ReaderPageContinuousTextChapter chapter,
  ) {
    if (!_scrollController.hasClients) {
      return 0;
    }

    final layout = _measureContinuousTextChapterLayoutFlow(chapter);
    if (layout == null) {
      return 0;
    }

    final extent = (layout.endOffset - layout.startOffset).clamp(
      0.0,
      double.infinity,
    );
    if (extent <= 0) {
      return 0;
    }

    final local = (_scrollController.position.pixels - layout.startOffset)
        .clamp(0.0, extent);
    return (local / extent).clamp(0.0, 1.0);
  }

  ReaderPageContinuousTextChapter? _resolveActiveContinuousTextChapterFlow() {
    if (!_scrollController.hasClients || _continuousTextChapters.isEmpty) {
      return null;
    }
    final layouts = <int, ReaderContinuousTextChapterLayout>{};
    for (final chapter in _continuousTextChapters) {
      final layout = _measureContinuousTextChapterLayoutFlow(chapter);
      if (layout == null) {
        continue;
      }
      layouts[chapter.chapterIndex] = _toContinuousTextChapterLayoutSupportFlow(
        layout,
      );
    }
    final resolved = _contentLoadingController
        .resolveActiveContinuousTextChapter(
          chapters: _continuousTextChapters
              .map(_toContinuousTextChapterSupportFlow)
              .toList(growable: false),
          layoutsByChapterIndex: layouts,
          viewport: ReaderContinuousTextViewportMetrics(
            pixels: _scrollController.position.pixels,
            viewportDimension: _scrollController.position.viewportDimension,
            maxScrollExtent: _scrollController.position.maxScrollExtent,
          ),
        );
    return resolved == null
        ? null
        : _fromContinuousTextChapterSupportFlow(resolved);
  }

  void _activateContinuousTextChapterFlow(
    ReaderPageContinuousTextChapter chapter,
  ) {
    final layout = _measureContinuousTextChapterLayoutFlow(chapter);
    final activation =
        layout == null
            ? _contentLoadingController.buildContinuousTextActivation(
              chapter: _toContinuousTextChapterSupportFlow(chapter),
              currentChapterIndex: _currentIndex,
              currentChapterId: _chapterId,
              currentChapterUrl: _chapterUrl,
            )
            : _contentLoadingController
                .buildContinuousTextActivationFromViewport(
                  chapter: _toContinuousTextChapterSupportFlow(chapter),
                  currentChapterIndex: _currentIndex,
                  currentChapterId: _chapterId,
                  currentChapterUrl: _chapterUrl,
                  layout: _toContinuousTextChapterLayoutSupportFlow(layout),
                  viewport: ReaderContinuousTextViewportMetrics(
                    pixels:
                        _scrollController.hasClients
                            ? _scrollController.position.pixels
                            : 0,
                    viewportDimension:
                        _scrollController.hasClients
                            ? _scrollController.position.viewportDimension
                            : 0,
                    maxScrollExtent:
                        _scrollController.hasClients
                            ? _scrollController.position.maxScrollExtent
                            : 0,
                  ),
                );
    if (activation == null) {
      return;
    }
    _commitReadingRecordSession();
    if (!mounted) {
      return;
    }
    final preserveOffset =
        _scrollController.hasClients ? _scrollController.position.pixels : null;

    _updateReaderState(() {
      _currentIndex = activation.chapterIndex;
      _chapterId = activation.chapterId;
      _chapterUrl = activation.chapterUrl;
      _chapterTitle = activation.chapterTitle;
      _isCurrentChapterCached = activation.isCached;
      _document = activation.contentState.document;
      _content = activation.contentState.content;
      _chapterImageUrls = activation.contentState.chapterImageUrls;
      _chapterImageHeaders = activation.contentState.imageHeaders;
      _precachedInlineImageUrls.clear();
      _lastInlineImagePrecacheAt = null;
      _paragraphs = activation.contentState.paragraphs;
      _renderItems = activation.contentState.renderItems;
      _renderTextItemsByParagraph =
          activation.contentState.renderTextItemsByParagraph;
      _pagedPages = activation.contentState.pagedPages;
      _pagedBlockPages = const <List<ReaderPagedBlock>>[];
      _pageTurnRuntimeController.currentPageIndex =
          activation.contentState.currentPageIndex;
      _pageTurnRuntimeController.pagedPaginationState =
          activation.contentState.paginationState;
      _isTextSelectionActive = false;
      _selectionRange = null;
      _selectionStatus = SelectionStatus.none;
      _selectionStartOffset = 0;
      _selectionEndOffset = 0;
      _selectedSnippet = '';
      _hideBookmarkToolbar();
      _chapterBookmarks = const <Bookmark>[];
      _bookmarkRangesByParagraph = const <int, List<ReaderBookmarkRange>>{};
      _resetCatalogSearchCache();
      _resetScrollEdgeAdvanceState();
    });
    if (preserveOffset != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) {
          return;
        }
        final position = _scrollController.position;
        final stableOffset = preserveOffset.clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        if ((position.pixels - stableOffset).abs() > 0.5) {
          _scrollController.jumpTo(stableOffset);
        }
      });
    }
    _scheduleInlineImagePrecache();
    unawaited(_refreshChapterBookmarks());

    _scheduleReadingRecordSessionStart(initialRatio: activation.initialRatio);
    _scheduleProgressSave();
    _scheduleNeighborPreload();
  }

  void _syncActiveContinuousTextChapterFromScrollFlow() {
    if (!_shouldUseContinuousTextFlow ||
        _continuousTextChapters.length <= 1 ||
        _isScrollStepAnimating ||
        _isUserScrollInteractionActive) {
      return;
    }

    final resolved = _resolveActiveContinuousTextChapterFlow();
    if (resolved == null || _isContinuousTextChapterActiveFlow(resolved)) {
      return;
    }
    _activateContinuousTextChapterFlow(resolved);
  }

  void _syncContinuousTextFlowAfterSettingsAppliedFlow() {
    final seeded = _contentLoadingController.seedContinuousTextFlow(
      shouldUseContinuousTextFlow: _shouldUseContinuousTextFlow,
      isMangaChapter: _isMangaChapter,
      currentContent: _content,
      currentChapterIndex: _currentIndex,
      chapters: _chapters,
      currentChapterId: _chapterId,
      currentChapterUrl: _chapterUrl,
      currentChapterTitle: _chapterTitle,
      contentState: _contentLoadingController.buildResolvedContent(
        content: _content,
        imageUrls: _chapterImageUrls,
        imageHeaders: _chapterImageHeaders,
        document: _document,
        precomputedParagraphs: _paragraphs,
        precomputedPagedPages: _pagedPages,
        precomputedCurrentPageIndex:
            _pageTurnRuntimeController.currentPageIndex,
        precomputedPaginationSignature:
            _pageTurnRuntimeController.pagedPaginationState.signature,
      ),
      isCurrentChapterCached: _isCurrentChapterCached,
    );
    if (seeded.isEmpty) {
      if (_continuousTextChapters.isEmpty) {
        return;
      }
      _updateReaderState(() {
        _continuousTextChapters = const <ReaderPageContinuousTextChapter>[];
      });
      return;
    }

    if (_continuousTextChapters.isNotEmpty) {
      return;
    }
    _updateReaderState(() {
      _continuousTextChapters = _retainContinuousTextWindowFlow(
        seeded.map(_fromContinuousTextChapterSupportFlow),
      );
    });
    _scheduleContinuousTextNeighborWindowWarmup();
  }

  Future<ReaderPageChapterLoadSnapshot> _fetchChapterContentSnapshotFlow({
    required String sourceId,
    required String chapterId,
    required String chapterUrl,
    required String? chapterTitle,
    required int? chapterIndex,
  }) async {
    final contentProvider = _contentLoadingPresenter.requireContentProvider(
      registry: _contentProviderRegistry,
      sourceId: sourceId,
      stage: ErrorStage.content,
    );
    final snapshot = await _contentLoadingPresenter.fetchChapterContentSnapshot(
      contentProvider: contentProvider,
      sourceId: sourceId,
      chapterUrl: chapterUrl,
      currentBookId: _currentBookId,
      bookTitle: _bookTitle,
      detailUrl: _detailUrl,
      executionContext: _executionContextForChapter(
        chapterId: chapterId,
        chapterUrl: chapterUrl,
        chapterIndex: chapterIndex,
      ),
      chapterId: chapterId,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
    );

    return ReaderPageChapterLoadSnapshot(
      result: snapshot.result,
      isCached: snapshot.isCached,
    );
  }

  String? _executionContextForChapter({
    required String chapterId,
    required String chapterUrl,
    required int? chapterIndex,
  }) {
    Chapter? chapter;
    if (chapterIndex != null &&
        chapterIndex >= 0 &&
        chapterIndex < _chapters.length) {
      chapter = _chapters[chapterIndex];
    } else {
      final normalizedId = chapterId.trim();
      final normalizedUrl = chapterUrl.trim();
      for (final item in _chapters) {
        if ((normalizedId.isNotEmpty && item.id.trim() == normalizedId) ||
            (normalizedUrl.isNotEmpty &&
                item.chapterUrl.trim() == normalizedUrl)) {
          chapter = item;
          break;
        }
      }
    }
    final normalized =
        (chapter?.executionContext ?? _chapterExecutionContext)?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  Future<void> _applyLoadedChapterSnapshotFlow({
    required ReaderPageChapterLoadSnapshot snapshot,
    required String chapterId,
    required String chapterUrl,
    required String? chapterTitle,
    required int? chapterIndex,
    required double targetRatio,
    required int requestToken,
    bool commitChapterIdentity = false,
  }) async {
    if (!_isActiveChapterContentRequestFlow(requestToken)) {
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
      final paginationSpec = _lastPaginationSpec;
      if (paginationSpec != null) {
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
        }
      }
    }

    _updateReaderState(() {
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
      _readerFailurePresentation = null;
      _readerGatewayFailureStage = null;
      _errorText = null;
      _contentFailureDiagnostics = null;
      _setContentFlow(
        snapshot.result.content,
        imageUrls: snapshot.result.imageUrls,
        imageHeaders: snapshot.result.imageHeaders,
        contentType: snapshot.result.contentType,
        sourceFilePath: snapshot.result.sourceFilePath,
        totalPageCount: snapshot.result.totalPageCount,
        audioUrl: snapshot.result.audioUrl,
        audioManifestUrl: snapshot.result.audioManifestUrl,
        audioHeaders: snapshot.result.audioHeaders,
        executionContext: snapshot.result.executionContext,
        document: snapshot.result.document,
        precomputedParagraphs: precomputedParagraphs,
        precomputedPagedPages: precomputedPagedPages,
        precomputedCurrentPageIndex: precomputedPageIndex,
        precomputedPaginationSignature: precomputedPaginationSignature,
      );
      if (resolvedContinuousChapter != null) {
        _replaceContinuousTextFlowWithCurrentChapterFlow(
          chapter: resolvedContinuousChapter,
          chapterIndex: resolvedContinuousIndex,
          snapshot: snapshot,
        );
      } else {
        _continuousTextChapters = const <ReaderPageContinuousTextChapter>[];
      }
      _pageTurnRuntimeController
          .pagedPaginationState = ReaderPaginationSessionState(
        signature: precomputedPaginationSignature,
        pendingRestoreRatio: targetRatio,
      );
    });

    _restoreScrollPosition(targetRatio);

    await _saveProgress();
    if (_canWarmNeighborPaginationCache()) {
      _scheduleNeighborPreload();
    }
  }

  Future<bool> _tryHydrateVisibleContentFromCacheFlow() async {
    final sourceId = (_sourceId ?? '').trim();
    if (sourceId.isEmpty) {
      return false;
    }

    if (LocalReaderIdentity.isLocalSourceId(sourceId)) {
      final chapterId = _chapterId.trim();
      if (chapterId.isEmpty || chapterId.toLowerCase() == 'bootstrap') {
        return false;
      }

      try {
        final chapter = await _localBookRepository.getChapterContentById(
          chapterId,
        );
        if (chapter == null || !chapter.hasReadablePayload) {
          return false;
        }
        final readableChapter = const LocalChapterReadableDocumentNormalizer()
            .normalize(chapter);

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

        _updateReaderState(() {
          _isCurrentChapterCached = true;
          _errorText = null;
          _contentFailureDiagnostics = null;
          _setContentFlow(
            readableChapter.content,
            imageUrls: readableChapter.imageUrls,
            contentType: null,
            sourceFilePath: null,
            totalPageCount: null,
            executionContext: null,
            document: readableChapter.document,
          );
          previewRatio = _resolveDocumentRestoreRatio(
            progress: previewProgress,
          );
          if (resolvedCurrentChapter != null &&
              _shouldUseContinuousTextFlow &&
              !_document.isPureImageDocument &&
              _document.paragraphs.isNotEmpty) {
            _continuousTextChapters = _insertContinuousTextChapterInWindowFlow(
              ReaderPageContinuousTextChapter(
                chapterId: chapter.id,
                chapterUrl: (_chapterUrl ?? '').trim(),
                chapterTitle: resolvedCurrentChapter.title.trim(),
                displayTitle:
                    (_chapterTitle ?? resolvedCurrentChapter.title).trim(),
                chapterIndex: _currentIndex!,
                content: readableChapter.content,
                document: _document,
                paragraphs:
                    _paragraphs.isEmpty
                        ? List<String>.unmodifiable(_document.paragraphs)
                        : List<String>.unmodifiable(_paragraphs),
                isCached: true,
              ),
            );
          } else {
            _continuousTextChapters = const <ReaderPageContinuousTextChapter>[];
          }
          _pageTurnRuntimeController
              .pagedPaginationState = ReaderPaginationSessionState(
            signature:
                _pageTurnRuntimeController.pagedPaginationState.signature,
            pendingRestoreRatio: previewRatio,
          );
        });

        if (previewProgress != null) {
          _bootstrapProgress = null;
        }
        _restoreScrollPosition(previewRatio);
        _scheduleNeighborPreload();
        _scheduleReadingRecordSessionStart(initialRatio: previewRatio);
        return true;
      } catch (_) {
        return false;
      }
    }

    final chapterUrl = (_chapterUrl ?? '').trim();
    if (chapterUrl.isEmpty) {
      return false;
    }

    try {
      final payload = await _cachedChapterStore.getCachedPayload(
        bookId: _activeBookId,
        sourceId: sourceId,
        chapterUrl: chapterUrl,
        chapterIndex: _currentIndex,
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

      _updateReaderState(() {
        _isCurrentChapterCached = true;
        _errorText = null;
        _contentFailureDiagnostics = null;
        _setContentFlow(
          decoded.content,
          imageUrls: decoded.imageUrls,
          imageHeaders: decoded.imageHeaders,
          sourceFilePath: null,
          totalPageCount: null,
          executionContext: null,
        );
        previewRatio = _resolveDocumentRestoreRatio(progress: previewProgress);
        if (resolvedCurrentChapter != null &&
            _shouldUseContinuousTextFlow &&
            !_document.isPureImageDocument &&
            _document.paragraphs.isNotEmpty) {
          _continuousTextChapters = _insertContinuousTextChapterInWindowFlow(
            ReaderPageContinuousTextChapter(
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
                      ? List<String>.unmodifiable(_document.paragraphs)
                      : List<String>.unmodifiable(_paragraphs),
              isCached: true,
            ),
          );
        } else {
          _continuousTextChapters = const <ReaderPageContinuousTextChapter>[];
        }
        _pageTurnRuntimeController
            .pagedPaginationState = ReaderPaginationSessionState(
          signature: _pageTurnRuntimeController.pagedPaginationState.signature,
          pendingRestoreRatio: previewRatio,
        );
      });

      if (previewProgress != null) {
        _bootstrapProgress = null;
      }
      _restoreScrollPosition(previewRatio);
      _scheduleNeighborPreload();
      _scheduleReadingRecordSessionStart(initialRatio: previewRatio);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _loadCurrentChapterFlow({
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
      scene: RemoteContentTaskScene.reader,
      conflictKeys: _currentConflictKeys(),
    );
    if (lease == null) {
      return false;
    }
    final requestToken =
        _readerSessionController
            .beginIntent(const ReaderSessionIntent.load())
            .chapterContentToken!;

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
      _updateReaderState(() {
        const message = '当前章节信息不完整。';
        _contentFailureDiagnostics = _buildReaderDiagnosticsFromMessage(
          scene: 'reader_content',
          userMessage: message,
        );
        _errorText = message;
      });
      return false;
    }

    final suppressLoadingUi = await _shouldSuppressChapterLoadingUiFlow(
      sourceId: request.sourceId,
      chapterUrl: request.chapterUrl,
    );

    _stopAutoRead();
    _resetScrollEdgeAdvanceState();
    _commitReadingRecordSession();
    _updateReaderState(() {
      _isLoadingContent = true;
      _errorText = null;
      _contentFailureDiagnostics = null;
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
      final snapshot = await _fetchChapterContentSnapshotFlow(
        sourceId: request.sourceId,
        chapterId: request.chapterId,
        chapterUrl: request.chapterUrl,
        chapterTitle: request.chapterTitle,
        chapterIndex: resolvedIndex,
      );

      if (!_isActiveChapterContentRequestFlow(requestToken)) {
        return false;
      }

      final targetRatio = _resolveDocumentRestoreRatio(
        document: snapshot.result.document,
        logicalPosition: initialLogicalPosition,
        fallback: initialScrollRatio ?? 0.0,
      );
      await _applyLoadedChapterSnapshotFlow(
        snapshot: snapshot,
        chapterId: request.chapterId,
        chapterUrl: request.chapterUrl,
        chapterTitle: request.chapterTitle,
        chapterIndex: resolvedIndex,
        targetRatio: targetRatio,
        requestToken: requestToken,
        commitChapterIdentity: commitChapterIdentity,
      );
      if (!_isActiveChapterContentRequestFlow(requestToken)) {
        return false;
      }
      readingRecordStartRatio = targetRatio;
      return true;
    } on AppException catch (error) {
      if (!_isActiveChapterContentRequestFlow(requestToken)) {
        return false;
      }
      final presentation = _readerFailurePresentationFor(error);
      final readableError =
          presentation?.message ?? _toUserReadableError(error);
      _recordReaderFailure(message: readableError, errorCode: error.code);
      _updateReaderState(() {
        _readerFailurePresentation = presentation;
        _readerGatewayFailureStage = _readerGatewayFailureStageFor(error);
        _contentFailureDiagnostics = _buildReaderDiagnostics(
          scene: 'reader_content',
          userMessage: readableError,
          error: error,
        );
        _errorText = readableError;
      });
      _maybePromptSwitchSourceForMissingSource(error.code);
      final switched = await _tryAutoSwitchSourceOnFailure();
      return switched;
    } catch (_) {
      if (!_isActiveChapterContentRequestFlow(requestToken)) {
        return false;
      }
      const fallbackError = '加载正文失败。';
      _recordReaderFailure(message: fallbackError);
      _updateReaderState(() {
        _readerFailurePresentation = null;
        _readerGatewayFailureStage = null;
        _contentFailureDiagnostics = _buildReaderDiagnosticsFromMessage(
          scene: 'reader_content',
          userMessage: fallbackError,
        );
        _errorText = fallbackError;
      });
      final switched = await _tryAutoSwitchSourceOnFailure();
      return switched;
    } finally {
      if (_isActiveChapterContentRequestFlow(requestToken)) {
        _clearDelayedLoadingUi();
        _updateReaderState(() {
          _isLoadingContent = false;
        });
        _drainPendingReaderNavigationAfterSettle();
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

  bool _isActiveChapterContentRequestFlow(int requestToken) {
    return mounted && requestToken == _chapterContentRequestToken;
  }

  Future<bool> _shouldSuppressChapterLoadingUiFlow({
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
        bookId: _activeBookId,
        sourceId: normalizedSourceId,
        chapterUrl: normalizedChapterUrl,
        chapterIndex: _currentIndex,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> _preloadNeighborsFlow({required int taskToken}) async {
    if (_isLowPriorityReaderWorkPaused) {
      _interactionRuntimeController.markDeferredNeighborPreload();
      return;
    }
    final sourceId = _sourceId;
    final currentIndex = _currentIndex;
    if (sourceId == null || currentIndex == null || _chapters.isEmpty) {
      return;
    }

    final normalizedSourceId = sourceId.trim();
    if (normalizedSourceId.isEmpty) {
      return;
    }
    final budget = _currentResourceBudget(
      scene: ReaderWorkScene.backgroundPrefetch,
    );
    final orderedIndexes = _neighborPreloadContentIndexes(
      normalizedSourceId: normalizedSourceId,
      currentIndex: currentIndex,
      chapterCount: _chapters.length,
      budget: budget,
    );
    if (orderedIndexes.isEmpty) {
      return;
    }

    for (final index in orderedIndexes) {
      if (!mounted || taskToken != _preloadTaskToken) {
        return;
      }
      if (_isLowPriorityReaderWorkPaused) {
        _interactionRuntimeController.markDeferredNeighborPreload();
        return;
      }

      final chapter = _chapters[index];
      final chapterUrl = chapter.chapterUrl.trim();
      if (chapterUrl.isEmpty) {
        continue;
      }
      final preloadIdentity = ReaderPreloadTask.identityFor(
        type: ReaderPreloadTaskType.content,
        chapterIndex: index,
      );

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
          executionContext:
              chapter.executionContext ?? _chapterExecutionContext,
        );
        _preloadFailureMemory.recordSuccess(preloadIdentity);
        if (_canWarmNeighborPaginationCache() &&
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
                shouldAbort:
                    () =>
                        !mounted ||
                        taskToken != _preloadTaskToken ||
                        _isLowPriorityReaderWorkPaused,
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
        _preloadFailureMemory.recordFailure(preloadIdentity);
        // Preload failures should not interrupt active reading.
      }
    }
  }
}
