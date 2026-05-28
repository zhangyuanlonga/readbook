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
                    _buildAutoReadStatusOverlay(colors),
                    _buildOverlayScrim(),
                    _buildTopOverlay(colors),
                    _buildBottomOverlay(colors),
                  ],
                ),
              ),
            ),
          );

          return Focus(
            focusNode: _readerFocusNode,
            autofocus: true,
            onKeyEvent: _handleReaderKeyEvent,
            child: Scaffold(
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
            _content.trim().isNotEmpty ||
            _chapterImageUrls.isNotEmpty ||
            (_chapterAudioUrl?.trim().isNotEmpty ?? false) ||
            (_chapterAudioManifestUrl?.trim().isNotEmpty ?? false),
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
            ReaderModeViewportKind.hybridPaged => _buildHybridReader(colors),
            ReaderModeViewportKind.textPaged => _buildPagedReader(colors),
            ReaderModeViewportKind.textScroll => _buildReaderList(colors),
            ReaderModeViewportKind.audio => _buildAudioReader(colors),
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
    if (_currentContentMode == ReaderContentMode.audio) {
      return _buildAudioReader(colors);
    }
    if (_shouldUseContinuousTextFlow && _continuousTextChapters.isNotEmpty) {
      return _buildContinuousTextReader(colors);
    }
    return _buildStandardReaderList(colors);
  }

  Widget _buildAudioReader(_ReaderThemeColors colors) {
    final snapshot = _bootstrapProgress?.positionSnapshot;
    final canGoPreviousChapter = (_currentIndex ?? 0) > 0;
    final canGoNextChapter =
        _currentIndex != null &&
        _currentIndex! >= 0 &&
        _currentIndex! < _chapters.length - 1;
    return ReaderAudioView(
      model: ReaderAudioViewModel(
        controller: _readerAudioController,
        contentSession: _resolvedContentSession(),
        initialPosition:
            snapshot?.audioPositionMs == null
                ? null
                : Duration(milliseconds: snapshot!.audioPositionMs!),
        initialSpeed:
            _settings.audioRememberSpeed && (snapshot?.audioSpeed ?? 0) > 0
                ? snapshot!.audioSpeed!
                : _settings.audioDefaultSpeed,
        autoPlay: _settings.audioAutoPlay,
        seekStepSeconds: _settings.audioSeekStepSeconds,
        canGoPreviousChapter: canGoPreviousChapter,
        canGoNextChapter: canGoNextChapter,
        onPreviousChapter:
            canGoPreviousChapter
                ? () => _jumpToAdjacentReadableChapter(forward: false)
                : null,
        onNextChapter:
            canGoNextChapter
                ? () => _jumpToAdjacentReadableChapter(forward: true)
                : null,
      ),
    );
  }

  Widget _buildHybridReader(_ReaderThemeColors colors) {
    final session = _resolvedContentSession();
    final sourceFilePath = session.sourceFilePath?.trim();
    if (session.hybridSubMode == ReaderHybridSubMode.pdf &&
        sourceFilePath != null &&
        sourceFilePath.isNotEmpty) {
      return ReaderPdfView(
        filePath: sourceFilePath,
        initialPage: max(
          1,
          (_bootstrapProgress?.positionSnapshot?.pageIndex ?? 0) + 1,
        ),
        onPageChanged: (pageNumber) {
          if (!mounted) {
            return;
          }
          _updateReaderState(() {
            _mangaPageIndex = max(0, pageNumber - 1);
            _chapterTotalPageCount ??= session.totalPageCount;
          });
          _syncActiveReadingRecordSessionProgress();
          _scheduleProgressSave();
        },
      );
    }
    if (session.hybridSubMode == ReaderHybridSubMode.pictureBook) {
      return _buildMangaReader(colors);
    }
    return _buildMangaReader(colors);
  }

  Widget _buildMangaViewport(_ReaderThemeColors colors) {
    final contentSession = _resolvedContentSession();
    final surfaceMetrics = _resolveReaderSurfaceMetrics(context);
    final mediaSize = MediaQuery.sizeOf(context);
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
      imageDecodeBudget: _readerImageDecodeBudget(
        role: ReaderImageDecodeRole.manga,
        logicalWidth: mediaSize.width,
      ),
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
          pageCount: _currentPagedPageCount,
          currentPageIndex: _currentPageIndex,
          document: _document,
          paragraphs: _paragraphs,
          pagedPages: _pagedPages,
          pagedBlockPages: _pagedBlockPages,
          textItemsByParagraph: _renderTextItemsByParagraph,
          imageDecodeBudget: _readerImageDecodeBudget(
            role: ReaderImageDecodeRole.epubInline,
            logicalWidth: paginationSpec.contentWidth,
            logicalHeight: paginationSpec.contentHeight,
          ),
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _ensurePagination(spec: paginationSpec);
        });

        final hasPagedContent =
            _pagedPages.isNotEmpty || _pagedBlockPages.isNotEmpty;
        if (_pagedPaginationState.isPaginating && !hasPagedContent) {
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
                total: max(1, _currentPagedPageCount),
                layoutMetrics: layoutMetrics,
              ),
            ],
          );
        }

        final pageCount = _currentPagedPageCount;
        if (pageCount <= 0) {
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
                total: 1,
                layoutMetrics: layoutMetrics,
              ),
            ],
          );
        }

        if (_usesPaperCurlAnimation) {
          return ReaderPaperCurlPagedView(
            key: _paperCurlViewKey,
            chapterId: _chapterId,
            pageCount: pageCount,
            currentPageIndex: _currentPageIndex,
            onTurnStarted: (_) {
              _markReaderInteractionBusy(_ReaderInteractionState.animating);
              _recordFirstPageTurnCompleted(mode: 'paper_curl');
            },
            onTurnRejected: (_) {
              _scheduleReaderInteractionSettle();
            },
            onPageCommitted: _commitPaperCurlPage,
            pageBuilder: (context, pageIndex) {
              return _buildPagedPageContainer(
                colors: colors,
                pageIndex: pageIndex,
                total: pageCount,
                pageSize: constraints.biggest,
                pagedViewModel: pagedViewModel,
                includeBackgroundDecoration: true,
              );
            },
          );
        }

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
            commitOnAnimationEnd: _curlCommitOnAnimationEnd,
            isCrossChapter: _isCurlCrossChapterTurn,
          ),
        );
        final pageSize = constraints.biggest;
        Widget buildPage({required int pageIndex}) {
          return _buildPagedPageContainer(
            colors: colors,
            pageIndex: pageIndex,
            total: pageCount,
            pageSize: pageSize,
            pagedViewModel: pagedViewModel,
            includeBackgroundDecoration:
                transitionPlan.includeBackgroundDecorationOnPrimaryPage,
          );
        }

        if (transitionPlan.renderMode ==
            ReaderPagedViewportRenderMode.staticPage) {
          return _wrapSelectionArea(
            child: ReaderTextPagedView(
              model: pagedViewModel,
              pageController: _resolveStaticPagedTextPageController(pageCount),
              pageBuilder: (context, pageIndex) {
                return buildPage(pageIndex: pageIndex);
              },
              onPageChanged: (pageIndex) {
                if (!mounted) {
                  return;
                }
                _updateReaderState(() {
                  _currentPageIndex = pageIndex;
                });
                _syncActiveReadingRecordSessionProgress();
                _scheduleProgressSave();
              },
              onScrollInteractionChanged: _handlePagedScrollInteractionChanged,
            ),
          );
        }

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
