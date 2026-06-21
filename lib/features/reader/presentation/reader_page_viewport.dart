part of 'reader_page.dart';

extension _ReaderPageViewportExtension on _ReaderPageState {
  Widget _buildReaderPageScaffold(BuildContext context) {
    final colors = _resolveThemeColors(_effectiveReaderThemeMode(), _settings);
    final canPopRoute = context.canPop();
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
                  ? ColoredBox(
                    color: Colors.black.withValues(
                      alpha: _readerBrightnessOverlayAlpha(),
                    ),
                  )
                  : null,
          foregroundOverlay: ReaderOverlayLayerRenderer(
            model: _buildForegroundOverlayModel(colors),
          ),
        ),
      ),
    );

    return ReaderPageScaffoldShell(
      colors: colors,
      canPopRoute: canPopRoute,
      onFallbackPop: () {
        if (mounted) {
          context.go('/bookshelf');
        }
      },
      focusNode: _readerFocusNode,
      onKeyEvent: _handleReaderKeyEvent,
      shellModel: shellModel,
      child: _buildReaderContent(colors),
    );
  }

  Widget _composeReaderContent(ReaderThemeColors colors) {
    return Column(
      children: [
        if (_showsPinnedChapterHeader) _buildPinnedChapterHeader(colors),
        Expanded(child: _buildBody(colors)),
        if (_showsReaderFooterInfoBar)
          _buildReaderInfoBar(colors, isHeader: false),
      ],
    );
  }

  ReaderOverlayLayerModel _buildForegroundOverlayModel(
    ReaderThemeColors colors,
  ) {
    return ReaderOverlayLayerModel(
      layers: readerForegroundOverlayOrder
          .asMap()
          .entries
          .map(
            (entry) => ReaderOverlayLayer(
              slot: entry.value,
              zOrder: entry.key,
              child: _buildForegroundOverlaySlot(entry.value, colors),
              hitTestPolicy: _foregroundOverlayHitTestPolicy(entry.value),
              semanticRole: _foregroundOverlaySemanticRole(entry.value),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildForegroundOverlaySlot(
    ReaderForegroundOverlaySlot slot,
    ReaderThemeColors colors,
  ) {
    return switch (slot) {
      ReaderForegroundOverlaySlot.chapterLoading =>
        _buildChapterLoadingIndicator(colors),
      ReaderForegroundOverlaySlot.autoReadStatus => _buildAutoReadStatusOverlay(
        colors,
      ),
      ReaderForegroundOverlaySlot.overlayScrim => _buildOverlayScrim(),
      ReaderForegroundOverlaySlot.topChrome => _buildTopOverlay(colors),
      ReaderForegroundOverlaySlot.bottomChrome => _buildBottomOverlay(colors),
    };
  }

  ReaderOverlayHitTestPolicy _foregroundOverlayHitTestPolicy(
    ReaderForegroundOverlaySlot slot,
  ) {
    return switch (slot) {
      ReaderForegroundOverlaySlot.chapterLoading =>
        ReaderOverlayHitTestPolicy.deferToChild,
      ReaderForegroundOverlaySlot.autoReadStatus ||
      ReaderForegroundOverlaySlot.overlayScrim ||
      ReaderForegroundOverlaySlot.topChrome ||
      ReaderForegroundOverlaySlot
          .bottomChrome => ReaderOverlayHitTestPolicy.deferToChild,
    };
  }

  ReaderOverlaySemanticRole _foregroundOverlaySemanticRole(
    ReaderForegroundOverlaySlot slot,
  ) {
    return switch (slot) {
      ReaderForegroundOverlaySlot.chapterLoading =>
        ReaderOverlaySemanticRole.loading,
      ReaderForegroundOverlaySlot.autoReadStatus =>
        ReaderOverlaySemanticRole.status,
      ReaderForegroundOverlaySlot.overlayScrim =>
        ReaderOverlaySemanticRole.scrim,
      ReaderForegroundOverlaySlot.topChrome ||
      ReaderForegroundOverlaySlot
          .bottomChrome => ReaderOverlaySemanticRole.chrome,
    };
  }

  Widget _composeReaderBody(ReaderThemeColors colors) {
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
            _overlayController.showHiddenLoadingPlaceholder &&
            (_isBootstrapping || _isLoadingContent) &&
            !_hasVisibleReaderContent,
        showTransientLoadingGap:
            (_isBootstrapping || _isLoadingContent) &&
            !_overlayController.showHiddenLoadingPlaceholder &&
            !_hasVisibleReaderContent,
        hasRenderableContent:
            _content.trim().isNotEmpty ||
            _chapterImageUrls.isNotEmpty ||
            (_chapterAudioUrl?.trim().isNotEmpty ?? false) ||
            (_chapterAudioManifestUrl?.trim().isNotEmpty ?? false),
        errorText: _errorText,
        primaryActionLabel: _readerGatewayRecoveryActionLabel,
        hasPrimaryErrorAction: _hasReaderGatewayRecoveryAction,
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
      onPrimaryErrorAction: () => unawaited(_openReaderGatewayRecovery()),
      onPullToRefresh:
          _supportsChapterPullToRefresh
              ? () => _reloadCurrentChapterFromPullToRefresh()
              : null,
      onCopyDiagnostics: _copyReaderDiagnostics,
      onSwitchSource: () => unawaited(_showSwitchSourceSheet()),
      isLocalContent: _isLocalContent,
    );
  }

  Widget _buildReaderViewportContent(ReaderThemeColors colors) {
    final surfaceModel = _currentContentModeSurfaceModel;
    if (surfaceModel.mode == ReaderContentMode.audio) {
      return _buildAudioReader(colors);
    }
    if (_shouldUseContinuousTextFlow && _continuousTextChapters.isNotEmpty) {
      return _buildContinuousTextReader(colors);
    }
    return _buildStandardReaderList(colors);
  }

  Widget _buildAudioReader(ReaderThemeColors colors) {
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
                ? () => _dispatchReaderNavigationCommand(
                  const ReaderNavigationCommand.previousChapter(
                    source: ReaderNavigationCommandSource.audio,
                  ),
                )
                : null,
        onNextChapter:
            canGoNextChapter
                ? () => _dispatchReaderNavigationCommand(
                  const ReaderNavigationCommand.nextChapter(
                    source: ReaderNavigationCommandSource.audio,
                  ),
                )
                : null,
      ),
    );
  }

  Widget _buildHybridReader(ReaderThemeColors colors) {
    final session = _resolvedContentSession();
    final sourceFilePath = session.sourceFilePath?.trim();
    if (session.hybridSubMode == ReaderHybridSubMode.pdf &&
        sourceFilePath != null &&
        sourceFilePath.isNotEmpty) {
      final restorePlan = _surfacePositionRuntime.restoreFromProgress(
        _bootstrapProgressForCurrentChapter(),
      );
      final documentPosition =
          restorePlan?.kind == ReaderSurfaceKind.document
              ? restorePlan!.position
              : null;
      return ReaderPdfView(
        filePath: sourceFilePath,
        initialPage: max(1, (documentPosition?.documentPageIndex ?? 0) + 1),
        initialZoomScale: documentPosition?.zoomScale,
        initialPanDx: documentPosition?.panDx,
        initialPanDy: documentPosition?.panDy,
        onViewerReady: (controller, pageCount) {
          _pdfViewerController = controller;
          _documentPageCount = pageCount;
        },
        onPageChanged: (pageNumber) {
          if (!mounted) {
            return;
          }
          _updateReaderState(() {
            _documentPageIndex = max(0, pageNumber - 1);
            _chapterTotalPageCount ??= session.totalPageCount;
            _documentPageCount ??= session.totalPageCount;
          });
          _syncActiveReadingRecordSessionProgress();
          _scheduleProgressSave();
        },
        onViewportChanged: (snapshot) {
          if (!mounted) {
            return;
          }
          _updateReaderState(() {
            _documentPageIndex = snapshot.pageIndex ?? _documentPageIndex;
            _documentPageCount = snapshot.pageCount;
            _documentZoomScale = snapshot.zoomScale;
            _documentPanDx = snapshot.panDx;
            _documentPanDy = snapshot.panDy;
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

  Widget _buildMangaViewport(ReaderThemeColors colors) {
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
      currentIndex: _imagePageIndex,
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
          _imagePageIndex = index;
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
        final overlayIndex = _imagePageIndex.clamp(
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

  Widget _buildPagedTextViewport(ReaderThemeColors colors) {
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
          currentPageIndex: _pageTurnRuntimeController.currentPageIndex,
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

        Widget buildLoadingViewport({required int total}) {
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
                total: max(1, total),
                layoutMetrics: layoutMetrics,
              ),
            ],
          );
        }

        final pageSize = constraints.biggest;

        void scheduleLegacyPagination() {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _ensurePagination(spec: paginationSpec);
          });
        }

        Widget buildLegacyViewport([ReaderLayoutRendererState? _]) {
          scheduleLegacyPagination();
          final hasPagedContent =
              _pagedPages.isNotEmpty || _pagedBlockPages.isNotEmpty;
          if (_pageTurnRuntimeController.pagedPaginationState.isPaginating &&
              !hasPagedContent) {
            return buildLoadingViewport(total: _currentPagedPageCount);
          }

          final pageCount = _currentPagedPageCount;
          if (pageCount <= 0) {
            return buildLoadingViewport(total: 1);
          }

          final animationStyle = _currentPagedAnimationStyle();
          final motion = _pagedTextRenderer.motionSpecForStyle(animationStyle);
          final curlState = ReaderPagedViewportCurlState(
            isAnimating: _isCurlAutoTurning,
            isPreview: _isCurlPreviewActive,
            direction: _curlAutoDirection,
            fromIndex: _curlAnimationFromIndex,
            toIndex: _curlAnimationToIndex,
            previewProgress: _curlPreviewProgress,
            commitOnAnimationEnd: _curlCommitOnAnimationEnd,
            isCrossChapter: _isCurlCrossChapterTurn,
          );
          final transitionPlan = _pagedViewportTransitionResolver.resolve(
            requestedAnimationStyle: animationStyle,
            pageCount: pageCount,
            currentPageIndex: _pageTurnRuntimeController.currentPageIndex,
            pagedTransition: _pageTurnRuntimeController.pagedTransition,
            curlState: curlState,
          );
          final viewportInput = ReaderPagedViewportInput(
            chapterId: _chapterId,
            pageIndex: _pageTurnRuntimeController.currentPageIndex,
            pageCount: pageCount,
            pageSize: pageSize,
            animationStyle: animationStyle,
            viewportMetricsHash:
                _paginationSpecResolver
                    .buildSignature(chapterId: _chapterId, spec: paginationSpec)
                    .hashCode,
          );
          return ReaderPagedAnimationSurface(
            model: pagedViewModel,
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
            staticPageController: _resolveStaticPagedTextPageController(
              pageCount,
            ),
            onStaticPageChanged: (pageIndex) {
              if (!mounted) {
                return;
              }
              _updateReaderState(() {
                _pageTurnRuntimeController.currentPageIndex = pageIndex;
              });
              _syncActiveReadingRecordSessionProgress();
              _scheduleProgressSave();
            },
            onStaticScrollInteractionChanged:
                _handlePagedScrollInteractionChanged,
            paperCurlKey: _paperCurlViewKey,
            paperCurlSurface: ReaderPaperCurlPagedSurface(
              surfaceToken: viewportInput,
              pageCount: pageCount,
              currentPageIndex: _pageTurnRuntimeController.currentPageIndex,
              pageBuilder:
                  (context, pageIndex) => _buildPagedPageContainer(
                    colors: colors,
                    pageIndex: pageIndex,
                    total: pageCount,
                    pageSize: pageSize,
                    pagedViewModel: pagedViewModel,
                    includeBackgroundDecoration: true,
                  ),
            ),
            onPaperCurlTurnStarted: (_) {
              _markReaderInteractionBusy(
                ReaderInteractionRuntimeState.animating,
              );
              _recordFirstPageTurnCompleted(mode: 'paper_curl');
            },
            onPaperCurlTurnRejected: (_) {
              _scheduleReaderInteractionSettle();
            },
            onPaperCurlTurnResult: _handlePaperCurlTurnResult,
            onPaperCurlPageCommitted: _commitPaperCurlPage,
            curlState: curlState,
            curlColors: CurlRendererColors(
              backgroundColor: colors.background,
              dividerColor: colors.divider,
              overlayColor: colors.overlay,
            ),
            selectionWrapper: (child) => _wrapSelectionArea(child: child),
            disabledSelectionWrapper:
                (child) => SelectionContainer.disabled(child: child),
          );
        }

        Widget buildReleaseFrame({
          required int pageIndex,
          required int pageCount,
          required Widget child,
          bool includeBackgroundDecoration = false,
        }) {
          final safePageIndex = pageIndex.clamp(0, pageCount - 1).toInt();
          return ReaderPagedPageFrame(
            pageSize: pageSize,
            includeBackgroundDecoration: includeBackgroundDecoration,
            backgroundDecoration: _buildReaderBackgroundDecoration(colors),
            pinnedHeader:
                _showsPagedPinnedChapterHeaderFor(_currentViewportKind)
                    ? SelectionContainer.disabled(
                      child: _buildPinnedChapterHeader(colors),
                    )
                    : null,
            header:
                layoutMetrics.pagedHeaderReserve > 0
                    ? SelectionContainer.disabled(
                      child: _buildPagedHeaderSection(colors, layoutMetrics),
                    )
                    : null,
            body: Padding(
              padding: layoutMetrics.effectivePagePadding,
              child: ReaderBodyRegion(
                model: const ReaderBodyRegionModel.content(),
                palette: ReaderBodyRegionPalette(
                  textColor: colors.text,
                  metaColor: colors.meta,
                  overlayColor: colors.overlay,
                  dividerColor: colors.divider,
                ),
                child: child,
              ),
            ),
            footer: SelectionContainer.disabled(
              child: _buildPagedFooterSection(
                colors: colors,
                index: safePageIndex,
                total: pageCount,
                layoutMetrics: layoutMetrics,
              ),
            ),
          );
        }

        Widget buildReleasePageContent(
          ReaderLayoutRendererState state,
          int pageIndex,
        ) {
          if (state.pages.isEmpty) {
            return const ReaderViewportLoadingPlaceholder();
          }
          final safePageIndex =
              pageIndex.clamp(0, state.pages.length - 1).toInt();
          return ReaderLayoutPageSurface(
            pages: state.pages,
            page: state.pages[safePageIndex],
            textStyle: _paragraphTextStyle(colors),
            titleStyle: _paragraphTextStyle(
              colors,
            ).copyWith(fontWeight: FontWeight.w700),
            annotationRanges: _buildLayoutReleaseAnnotationRanges(),
            highlightColor: colors.text.withValues(alpha: 0.16),
            onSelectionChanged: _handleLayoutReleaseSelectionChanged,
          );
        }

        Widget buildReleaseAnimatedViewport(
          ReaderLayoutRendererState state,
          Widget staticChild,
        ) {
          final pageCount = max(1, state.pages.length);
          final animationStyle = _currentPagedAnimationStyle();
          final motion = _pagedTextRenderer.motionSpecForStyle(animationStyle);
          final curlState = ReaderPagedViewportCurlState(
            isAnimating: _isCurlAutoTurning,
            isPreview: _isCurlPreviewActive,
            direction: _curlAutoDirection,
            fromIndex: _curlAnimationFromIndex,
            toIndex: _curlAnimationToIndex,
            previewProgress: _curlPreviewProgress,
            commitOnAnimationEnd: _curlCommitOnAnimationEnd,
            isCrossChapter: _isCurlCrossChapterTurn,
          );
          final transitionPlan = _pagedViewportTransitionResolver.resolve(
            requestedAnimationStyle: animationStyle,
            pageCount: pageCount,
            currentPageIndex: _pageTurnRuntimeController.currentPageIndex,
            pagedTransition: _pageTurnRuntimeController.pagedTransition,
            curlState: curlState,
          );
          if (transitionPlan.renderMode ==
              ReaderPagedViewportRenderMode.staticPage) {
            final pageIndex =
                _pageTurnRuntimeController.currentPageIndex
                    .clamp(0, pageCount - 1)
                    .toInt();
            return buildReleaseFrame(
              pageIndex: pageIndex,
              pageCount: pageCount,
              child: staticChild,
            );
          }

          final viewportInput = ReaderPagedViewportInput(
            chapterId: _chapterId,
            pageIndex: _pageTurnRuntimeController.currentPageIndex,
            pageCount: pageCount,
            pageSize: pageSize,
            animationStyle: animationStyle,
            viewportMetricsHash: Object.hash(
              _layoutReleaseRequestSignature,
              state.pages.isEmpty ? null : state.pages.first.layoutSignature,
              paginationSpec.contentWidth,
              paginationSpec.contentHeight,
            ),
          );
          return ReaderPagedAnimationSurface(
            model: pagedViewModel,
            plan: transitionPlan,
            pageBuilder:
                ({
                  required int pageIndex,
                  required bool includeBackgroundDecoration,
                }) => buildReleaseFrame(
                  pageIndex: pageIndex,
                  pageCount: pageCount,
                  includeBackgroundDecoration: includeBackgroundDecoration,
                  child: buildReleasePageContent(state, pageIndex),
                ),
            pagedTransitionAnimation: _pagedTransitionController,
            curlAnimation: _curlAutoTurnController,
            switchInCurve: motion.switchInCurve,
            paperCurlKey: _paperCurlViewKey,
            paperCurlSurface: ReaderPaperCurlPagedSurface(
              surfaceToken: viewportInput,
              pageCount: pageCount,
              currentPageIndex: _pageTurnRuntimeController.currentPageIndex,
              pageBuilder:
                  (context, pageIndex) => buildReleaseFrame(
                    pageIndex: pageIndex,
                    pageCount: pageCount,
                    includeBackgroundDecoration: true,
                    child: buildReleasePageContent(state, pageIndex),
                  ),
            ),
            onPaperCurlTurnStarted: (_) {
              _markReaderInteractionBusy(
                ReaderInteractionRuntimeState.animating,
              );
              _recordFirstPageTurnCompleted(mode: 'paper_curl');
            },
            onPaperCurlTurnRejected: (_) {
              _scheduleReaderInteractionSettle();
            },
            onPaperCurlTurnResult: _handlePaperCurlTurnResult,
            onPaperCurlPageCommitted: _commitPaperCurlPage,
            curlState: curlState,
            curlColors: CurlRendererColors(
              backgroundColor: colors.background,
              dividerColor: colors.divider,
              overlayColor: colors.overlay,
            ),
            selectionWrapper: (child) => _wrapSelectionArea(child: child),
            disabledSelectionWrapper:
                (child) => SelectionContainer.disabled(child: child),
          );
        }

        final releaseDecision = _resolveLayoutReleaseDecision();
        if (!releaseDecision.useReleaseRenderer) {
          final diagnostic = _formatLayoutReleaseDiagnostic(
            releaseDecision.toDiagnosticsContext(),
          );
          _deactivateLayoutReleaseForFallback(diagnostic);
          if (releaseDecision.strictReleaseValidation) {
            return ReaderLayoutStrictReleaseFailure(
              reason: releaseDecision.reason,
              diagnostic: diagnostic,
            );
          }
          return buildLegacyViewport();
        }

        final releaseRequest = _buildLayoutReleaseRequest(paginationSpec);
        if (releaseRequest == null) {
          const diagnostic = 'readerLayoutReleaseReason=no_request';
          _deactivateLayoutReleaseForFallback(diagnostic);
          if (releaseDecision.strictReleaseValidation) {
            return const ReaderLayoutStrictReleaseFailure(
              reason: 'no_request',
              diagnostic: diagnostic,
            );
          }
          return buildLegacyViewport();
        }

        _syncLayoutReleaseRequest(
          releaseRequest,
          targetRatio: _currentLogicalPositionRatio(),
          initialPageIndex: _pageTurnRuntimeController.currentPageIndex,
        );
        return ReaderLayoutReleaseSurface(
          request: releaseRequest,
          options: releaseDecision.options,
          controller: _layoutReleaseRendererController,
          targetRatio: _layoutReleaseTargetRatio,
          initialPageIndex: _layoutReleaseInitialPageIndex,
          pageIndex: _pageTurnRuntimeController.currentPageIndex,
          nearbyPageRadius: 1,
          legacyBuilder: (context, state) => buildLegacyViewport(state),
          loadingBuilder:
              (context, state) =>
                  buildLoadingViewport(total: _currentPagedPageCount),
          readyBuilder:
              (context, state, child) =>
                  buildReleaseAnimatedViewport(state, child),
          showDiagnosticsOverlay: releaseDecision.showDiagnosticsOverlay,
          onDiagnostics:
              (state) =>
                  _handleLayoutReleaseDiagnostics(state, releaseDecision),
          onPageChanged: _handleLayoutReleasePageChanged,
          onSelectionChanged: _handleLayoutReleaseSelectionChanged,
          textStyle: _paragraphTextStyle(colors),
          titleStyle: _paragraphTextStyle(
            colors,
          ).copyWith(fontWeight: FontWeight.w700),
          annotationRanges: _buildLayoutReleaseAnnotationRanges(),
          highlightColor: colors.text.withValues(alpha: 0.16),
          physics: const PageScrollPhysics(),
        );
      },
    );
  }

  ReaderLayoutReleaseDecision _resolveLayoutReleaseDecision() {
    return _layoutReleasePolicy.resolve(
      contentMode: _currentContentMode,
      viewportKind: _currentViewportKind,
      hasRenderableText:
          _document.hasTextBlocks ||
          _paragraphs.any((paragraph) => paragraph.trim().isNotEmpty) ||
          _content.trim().isNotEmpty,
      contentLength: _chapterTextLength(),
      pageAnimationStyle:
          _currentReaderMode.pageAnimationStyle ??
          ReaderPageAnimationStyle.none,
    );
  }

  void _deactivateLayoutReleaseForFallback(String diagnostic) {
    _layoutReleaseRendererController.cancelActive();
    _layoutReleaseRendererActive = false;
    _layoutReleasePages = const <ReaderLayoutPage>[];
    _layoutReleasePageCount = null;
    _layoutReleaseCompleted = false;
    _layoutReleaseLayoutSignature = null;
    _layoutReleaseRequestSignature = null;
    _layoutReleaseTargetRatio = 0;
    _layoutReleaseInitialPageIndex = 0;
    _layoutReleaseDiagnostic = diagnostic;
  }

  ReaderLayoutRequest? _buildLayoutReleaseRequest(
    ReaderPaginationSpec paginationSpec,
  ) {
    final effectiveParagraphs =
        _paragraphs.isEmpty
            ? (_content.trim().isEmpty
                ? const <String>[]
                : <String>[_content.trim()])
            : _paragraphs;
    final hasText =
        _document.hasTextBlocks ||
        effectiveParagraphs.any((paragraph) => paragraph.trim().isNotEmpty);
    if (!hasText) {
      return null;
    }

    final layoutSpec = ReaderLayoutSpec.fromPaginationSpec(
      paginationSpec,
      useZhLayout: true,
    );
    final documentFingerprint = _layoutReleasePolicy.buildDocumentFingerprint(
      chapterId: _chapterId,
      document: _document,
      paragraphs: effectiveParagraphs,
      fallbackContent: _content,
    );
    final chapterIndex = max(0, _currentIndex ?? widget.chapterIndex ?? 0);
    if (!_document.isEmpty && !_document.isPureImageDocument) {
      return ReaderLayoutRequest.fromDocument(
        chapterId: _chapterId,
        chapterIndex: chapterIndex,
        document: _document,
        spec: layoutSpec,
        documentFingerprint: documentFingerprint,
      );
    }
    return ReaderLayoutRequest.fromParagraphs(
      chapterId: _chapterId,
      chapterIndex: chapterIndex,
      paragraphs: effectiveParagraphs,
      spec: layoutSpec,
      documentFingerprint: documentFingerprint,
    );
  }

  void _handleLayoutReleaseDiagnostics(
    ReaderLayoutRendererState state,
    ReaderLayoutReleaseDecision decision,
  ) {
    final isActive =
        decision.useReleaseRenderer && !state.shouldUseLegacyRenderer;
    final pageCount = state.pages.length;
    final layoutSignature =
        state.pages.isEmpty ? null : state.pages.first.layoutSignature;
    final anchorSnapshot = ReaderLayoutAnchorReadinessSnapshot(
      contentMode: _currentContentMode,
      viewportKind: _currentViewportKind,
      releaseActive: isActive,
      layoutPageCount: pageCount,
      layoutSignature: layoutSignature,
    );
    final searchAnchorReadiness = _layoutAnchorReadinessPolicy.resolve(
      consumer: ReaderLayoutAnchorConsumer.search,
      snapshot: anchorSnapshot,
    );
    final readAloudAnchorReadiness = _layoutAnchorReadinessPolicy.resolve(
      consumer: ReaderLayoutAnchorConsumer.readAloud,
      snapshot: anchorSnapshot,
    );
    final autoReadAnchorReadiness = _layoutAnchorReadinessPolicy.resolve(
      consumer: ReaderLayoutAnchorConsumer.autoRead,
      snapshot: anchorSnapshot,
    );
    final rendererAuthority = _rendererAuthorityResolver.resolve(
      releaseActive: isActive,
      releasePageCount: pageCount,
      legacyTextPageCount: _pagedPages.length,
      legacyBlockPageCount: _pagedBlockPages.length,
      currentPageIndex: _pageTurnRuntimeController.currentPageIndex,
      fallbackReason:
          state.shouldUseLegacyRenderer
              ? state.diagnostics.fallbackReason
              : null,
    );
    final context = <String, Object?>{
      ...decision.toDiagnosticsContext(),
      ...state.diagnosticsContext,
      'readerLayoutReleaseState': state.kind.name,
      'readerLayoutReleaseCompleted': state.completed,
      'readerLayoutReleaseFromCache': state.fromCache,
      'readerRendererAuthority': rendererAuthority.authority.name,
      'readerRendererAuthorityPageCount': rendererAuthority.pageCount,
      'readerRendererAuthorityReason': rendererAuthority.reason,
      'readerLayoutSearchAnchor': searchAnchorReadiness.type.name,
      'readerLayoutSearchAnchorReason': searchAnchorReadiness.reason,
      'readerLayoutReadAloudAnchor': readAloudAnchorReadiness.type.name,
      'readerLayoutReadAloudAnchorReason': readAloudAnchorReadiness.reason,
      'readerLayoutAutoReadAnchor': autoReadAnchorReadiness.type.name,
      'readerLayoutAutoReadAnchorReason': autoReadAnchorReadiness.reason,
    };
    final diagnostic = _formatLayoutReleaseDiagnostic(context);
    final layoutPages =
        isActive && state.canRenderLayout
            ? state.pages
            : const <ReaderLayoutPage>[];
    final layoutPagesChanged =
        !identical(_layoutReleasePages, layoutPages) ||
        _layoutReleaseCompleted != (isActive && state.completed) ||
        _layoutReleaseLayoutSignature != layoutSignature;
    if (_layoutReleaseRendererActive == isActive &&
        _layoutReleasePageCount == pageCount &&
        _layoutReleaseDiagnostic == diagnostic &&
        !layoutPagesChanged) {
      return;
    }
    _updateReaderState(() {
      _layoutReleaseRendererActive = isActive;
      _layoutReleasePages = layoutPages;
      _layoutReleasePageCount = pageCount;
      _layoutReleaseCompleted = isActive && state.completed;
      _layoutReleaseLayoutSignature = layoutSignature;
      _layoutReleaseDiagnostic = diagnostic;
    });
  }

  String _formatLayoutReleaseDiagnostic(Map<String, Object?> context) {
    final keys = context.keys.toList(growable: false)..sort();
    return keys
        .where((key) => context[key] != null)
        .map((key) => '$key=${context[key]}')
        .join('; ');
  }

  void _handleLayoutReleasePageChanged(int pageIndex) {
    if (!mounted) {
      return;
    }
    final pageCount = max(1, _layoutReleasePageCount ?? _currentPagedPageCount);
    final safeIndex = pageIndex.clamp(0, pageCount - 1).toInt();
    if (_pageTurnRuntimeController.currentPageIndex != safeIndex) {
      _updateReaderState(() {
        _pageTurnRuntimeController.currentPageIndex = safeIndex;
      });
    }
    _syncActiveReadingRecordSessionProgress();
    _scheduleProgressSave();
  }

  void _handleLayoutReleaseSelectionChanged(
    ReaderLayoutSelectionSnapshot selection,
  ) {
    final totalLength = _chapterTextLength();
    if (totalLength <= 0) {
      return;
    }
    var safeStart =
        min(
          selection.startOffset,
          selection.endOffset,
        ).clamp(0, totalLength).toInt();
    var safeEnd =
        max(
          selection.startOffset,
          selection.endOffset,
        ).clamp(0, totalLength).toInt();
    if (safeStart == safeEnd) {
      safeEnd = min(safeStart + 1, totalLength);
    }
    final snippet = selection.selectedText.trim();
    if (safeEnd <= safeStart || snippet.isEmpty) {
      return;
    }
    final overlapStyle = _resolveSelectionStyleByOverlap(
      startOffset: safeStart,
      endOffset: safeEnd,
    );
    if (_isAutoReadSessionEnabled) {
      _pauseAutoReadSession();
    }
    _hideOverlayControls(resumeAutoRead: false);
    _activateSelectionFromBookmarkRange(
      startOffset: safeStart,
      endOffset: safeEnd,
      snippet: snippet,
      hasHighlight: overlapStyle.highlight,
      isBold: overlapStyle.bold,
      isUnderline: overlapStyle.underline,
      isWavy: overlapStyle.wavy,
    );
  }

  List<ReaderLayoutTextAnnotationRange> _buildLayoutReleaseAnnotationRanges() {
    final ranges = <ReaderLayoutTextAnnotationRange>[];
    final totalLength = _chapterTextLength();
    for (final bookmark in _chapterBookmarks) {
      if (!_isBookmarkInCurrentChapter(bookmark)) {
        continue;
      }
      final start =
          min(
            bookmark.startOffset,
            bookmark.endOffset,
          ).clamp(0, totalLength).toInt();
      final end =
          max(
            bookmark.startOffset,
            bookmark.endOffset,
          ).clamp(0, totalLength).toInt();
      if (end <= start) {
        continue;
      }
      ranges.add(
        ReaderLayoutTextAnnotationRange(
          startOffset: start,
          endOffset: end,
          hasHighlight: _bookmarkHasHighlight(bookmark),
          hasBold: bookmark.isBold,
          hasUnderline: bookmark.isUnderline,
          hasWavyUnderline: bookmark.isWavy,
          color: _layoutReleaseBookmarkColor(bookmark),
        ),
      );
    }
    final readAloudRange = _buildLayoutReleaseReadAloudRange(totalLength);
    if (readAloudRange != null) {
      ranges.add(readAloudRange);
    }
    if (_isTextSelectionActive && _selectionEndOffset > _selectionStartOffset) {
      ranges.add(
        ReaderLayoutTextAnnotationRange(
          startOffset: _selectionStartOffset,
          endOffset: _selectionEndOffset,
        ),
      );
    }
    return List<ReaderLayoutTextAnnotationRange>.unmodifiable(ranges);
  }

  ReaderLayoutTextAnnotationRange? _buildLayoutReleaseReadAloudRange(
    int totalLength,
  ) {
    if (!_layoutReleaseRendererActive ||
        !_layoutReleaseCompleted ||
        _layoutReleasePages.isEmpty ||
        _autoReadSessionState != ReaderAutoReadSessionState.running ||
        totalLength <= 0) {
      return null;
    }
    final page = _layoutReleasePageForIndex(
      _pageTurnRuntimeController.currentPageIndex,
    );
    if (page == null || page.lines.isEmpty) {
      return null;
    }
    final step = _layoutReadAloudAnchorMapper.resolveStep(
      layoutPages: _layoutReleasePages,
      chapterOffset: page.lines.first.chapterOffset,
      unit:
          _settings.autoReadPauseMode == ReaderAutoReadPauseMode.paragraphEnd
              ? ReaderReadAloudAdvanceUnit.block
              : ReaderReadAloudAdvanceUnit.line,
    );
    final anchor = step?.current;
    if (anchor == null || anchor.isCollapsed) {
      return null;
    }
    final start =
        min(anchor.startOffset, anchor.endOffset).clamp(0, totalLength).toInt();
    final end =
        max(anchor.startOffset, anchor.endOffset).clamp(0, totalLength).toInt();
    if (end <= start) {
      return null;
    }
    return ReaderLayoutTextAnnotationRange(startOffset: start, endOffset: end);
  }

  ReaderLayoutPage? _layoutReleasePageForIndex(int pageIndex) {
    for (final page in _layoutReleasePages) {
      if (page.pageIndex == pageIndex) {
        return page;
      }
    }
    if (pageIndex >= 0 && pageIndex < _layoutReleasePages.length) {
      return _layoutReleasePages[pageIndex];
    }
    return null;
  }

  Color? _layoutReleaseBookmarkColor(Bookmark bookmark) {
    final raw = bookmark.color?.trim();
    if (raw == null ||
        raw.isEmpty ||
        raw == _ReaderPageState._kBookmarkNoHighlightToken ||
        raw == readerBookmarkDefaultHighlightToken) {
      return null;
    }
    final parsed = _parseReaderHexColor(raw);
    return parsed == null ? null : Color(parsed);
  }
}
