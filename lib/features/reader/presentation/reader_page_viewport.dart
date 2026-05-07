part of 'reader_page.dart';

extension _ReaderPageViewportExtension on _ReaderPageState {
  Widget _buildReaderPageScaffold(BuildContext context) {
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
          final shellModel = _presentationResolver.buildShellModel(
            contentSession: _resolvedContentSession(),
            settings: _settings,
            surfaceMetrics: _resolveReaderSurfaceMetrics(context),
            viewportKind: _presentationViewportKind,
            palette: _presentationPalette(context),
            parts: ReaderShellParts(
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

  Widget _composeReaderContent(_ReaderThemeColors colors) {
    return Column(
      children: [
        if (_showsPinnedChapterHeader) _buildPinnedChapterHeader(colors),
        Expanded(child: _buildBody(colors)),
        if (_showsReaderFooterInfoBar)
          _buildReaderInfoBar(colors, isHeader: false),
      ],
    );
  }

  Widget _composeReaderBody(_ReaderThemeColors colors) {
    final palette = ReaderBodyRegionPalette(
      textColor: colors.text,
      metaColor: colors.meta,
      overlayColor: colors.overlay,
      dividerColor: colors.divider,
    );
    return _viewportBuilder.buildBody(
      state: ReaderViewportBodyState(
        showBlockingLoading: _shouldShowBlockingReaderLoading,
        showHiddenLoading:
            _showHiddenLoadingPlaceholder &&
            (_isBootstrapping || _isLoadingContent) &&
            !_hasVisibleReaderContent,
        showTransientLoadingGap:
            (_isBootstrapping || _isLoadingContent) &&
            !_showHiddenLoadingPlaceholder &&
            !_hasVisibleReaderContent,
        hasRenderableContent:
            _content.trim().isNotEmpty || _chapterImageUrls.isNotEmpty,
        errorText: _errorText,
        canSwitchSource: _canSwitchSource,
        isSwitchSourceLoading: _isSwitchSourceLoading,
      ),
      palette: palette,
      tapAwareBuilder: ({required child}) => _buildTapAwareBody(child: child),
      contentBuilder:
          () => switch (_currentViewportKind) {
            ReaderModeViewportKind.imagePaged ||
            ReaderModeViewportKind.imageScroll => _buildMangaReader(colors),
            ReaderModeViewportKind.textPaged => _buildPagedReader(colors),
            ReaderModeViewportKind.textScroll => _buildReaderList(colors),
          },
      onRetry: () => unawaited(_loadCurrentChapter(initialScrollRatio: null)),
      onPullToRefresh:
          _supportsChapterPullToRefresh
              ? () => _reloadCurrentChapterFromPullToRefresh()
              : null,
      onCopyDiagnostics: _copyLocalReaderDiagnostics,
      onSwitchSource: () => unawaited(_showSwitchSourceSheet()),
      isLocalContent: _isLocalContent,
    );
  }

  Widget _buildReaderViewportContent(_ReaderThemeColors colors) {
    if (_shouldUseContinuousTextFlow && _continuousTextChapters.isNotEmpty) {
      return _buildContinuousTextReader(colors);
    }
    return _buildStandardReaderList(colors);
  }

  Widget _buildMangaViewport(_ReaderThemeColors colors) {
    final contentSession = _resolvedContentSession();
    final surfaceMetrics = _resolveReaderSurfaceMetrics(context);
    final bottomInset = _effectiveBottomSafeInset(context);
    final mangaModel = _presentationResolver.buildMangaModel(
      contentSession: contentSession,
      settings: _settings,
      surfaceMetrics: surfaceMetrics,
      palette: _presentationPalette(context),
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
    );
    return _viewportBuilder.buildMangaViewport(
      model: mangaModel,
      scrollController: _scrollController,
      pageController: _mangaPageController,
      onPageChanged: (index) {
        if (!mounted) {
          return;
        }
        _updateReaderState(() {
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

  Widget _buildPagedTextViewport(_ReaderThemeColors colors) {
    return _viewportBuilder.buildPagedViewport(
      builder: (context, constraints, palette) {
        final layoutMetrics = _resolvePagedLayoutMetrics(context, constraints);
        final paginationSpec = _resolvePaginationSpec(
          surfaceMetrics: layoutMetrics,
        );
        _lastPaginationSpec = paginationSpec;
        final pagedViewModel = _presentationResolver.buildTextPagedModel(
          contentSession: _resolvedContentSession(),
          settings: _settings,
          surfaceMetrics: layoutMetrics,
          paginationSpec: paginationSpec,
          palette: palette,
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
                    model: const ReaderBodyRegionModel.content(),
                    palette: ReaderBodyRegionPalette(
                      textColor: colors.text,
                      metaColor: colors.meta,
                      overlayColor: colors.overlay,
                      dividerColor: colors.divider,
                    ),
                    child: const ReaderViewportLoadingPlaceholder(),
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
        final motion = _pagedTextRenderer.motionSpecForStyle(
          _currentPagedAnimationStyle(),
        );
        final transitionPlan = _pagedViewportTransitionResolver.resolve(
          requestedAnimationStyle: _currentPagedAnimationStyle(),
          pageCount: pageCount,
          currentPageIndex: _currentPageIndex,
          pagedTransition: _pagedTransition,
          curlState: ReaderPagedViewportCurlState(
            isAnimating: _isCurlAutoTurning,
            isPreview: _isCurlPreviewActive,
            direction: _curlAutoDirection,
            fromIndex: _curlAnimationFromIndex,
            toIndex: _curlAnimationToIndex,
            previewProgress: _curlPreviewProgress,
            touchXFactor: _curlTouchXFactor,
            useTopCorner: _curlUseTopCorner,
            commitOnAnimationEnd: _curlCommitOnAnimationEnd,
          ),
        );
        final pageSize = constraints.biggest;
        final pageStack = ReaderPagedViewportTransitionStack(
          plan: transitionPlan,
          pageBuilder:
              ({
                required int pageIndex,
                required bool includeBackgroundDecoration,
              }) => _buildPagedPageContainer(
                colors: colors,
                pageIndex: pageIndex,
                total: pageCount,
                pageSize: pageSize,
                pagedViewModel: pagedViewModel,
                includeBackgroundDecoration: includeBackgroundDecoration,
              ),
          pagedTransitionAnimation: _pagedTransitionController,
          curlAnimation: _curlAutoTurnController,
          switchInCurve: motion.switchInCurve,
          curlColors: CurlRendererColors(
            backgroundColor: colors.background,
            dividerColor: colors.divider,
            overlayColor: colors.overlay,
          ),
          selectionWrapper: (child) => _wrapSelectionArea(child: child),
          disabledSelectionWrapper:
              (child) => SelectionContainer.disabled(child: child),
        );
        return ReaderTextPagedView(model: pagedViewModel, content: pageStack);
      },
    );
  }
}
