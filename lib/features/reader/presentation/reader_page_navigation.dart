// ignore_for_file: invalid_use_of_protected_member

part of 'reader_page.dart';

extension _ReaderPageNavigationExtension on _ReaderPageState {
  Future<bool> _ensureCatalogLoadedForOverlay() async {
    if (_chapters.isNotEmpty && _catalogComplete) {
      return true;
    }
    await _hydrateCatalogAfterVisible();
    return _chapters.isNotEmpty;
  }

  Future<bool> _dispatchReaderNavigationCommand(
    ReaderNavigationCommand command,
  ) async {
    final snapshot = _readerNavigationCommandSnapshot(command);
    final decision = _navigationCommandDispatcher.resolve(
      command: command,
      snapshot: snapshot,
    );
    _logReaderNavigationCommand(
      command: command,
      snapshot: snapshot,
      decision: decision,
    );

    if (!decision.shouldExecute) {
      _handleRejectedReaderNavigationCommand(command, decision);
      return false;
    }

    switch (command.type) {
      case ReaderNavigationCommandType.previousPage:
        await _turnReaderByDirection(
          forward: false,
          source: _pageTurnRequestSourceForNavigation(command.source),
        );
        return true;
      case ReaderNavigationCommandType.nextPage:
        await _turnReaderByDirection(
          forward: true,
          source: _pageTurnRequestSourceForNavigation(command.source),
        );
        return true;
      case ReaderNavigationCommandType.previousChapter:
        return _jumpToAdjacentReadableChapter(forward: false);
      case ReaderNavigationCommandType.nextChapter:
        return _jumpToAdjacentReadableChapter(forward: true);
      case ReaderNavigationCommandType.reloadChapter:
        await _reloadCurrentChapterFromPullToRefresh();
        return true;
      case ReaderNavigationCommandType.jumpChapter:
        final target = command.targetChapterIndex;
        if (target == null) {
          return false;
        }
        await _jumpTo(target, initialScrollRatio: 0);
        return true;
    }
  }

  ReaderNavigationCommandSnapshot _readerNavigationCommandSnapshot(
    ReaderNavigationCommand command,
  ) {
    final sessionState = _currentTextSessionState();
    final fallbackCurrentIndex =
        _currentIndex == null ? _resolveCurrentIndex(_chapters) : null;
    final turnGateDecision = _readerPageTurnGateDecisionForCommand(command);
    return ReaderNavigationCommandSnapshot(
      mounted: mounted,
      bootstrapping: _isBootstrapping,
      loadingContent: _isLoadingContent,
      pageTurnBusy: turnGateDecision.isBlocked,
      pageTurnBusyReason: turnGateDecision.blockReason,
      pageTurnBusyMessage: turnGateDecision.message,
      chapterCount: _chapters.length,
      currentChapterIndex:
          sessionState?.currentChapterIndex ??
          _currentIndex ??
          fallbackCurrentIndex,
      overlayVisible: _overlayController.showOverlayControls,
      isLocalContent: _isLocalContent,
      usesContinuousTextFlow: _shouldUseContinuousTextFlow,
      viewportKind: _currentViewportKind.name,
      contentMode: _currentContentMode.name,
      hasError: _errorText != null,
      selectionActive: _isTextSelectionActive,
    );
  }

  ReaderPageTurnGateDecision _readerPageTurnGateDecisionForCommand(
    ReaderNavigationCommand command,
  ) {
    return _pageTurnGate.resolve(
      requestKind: _readerPageTurnRequestKindForCommand(command),
      snapshot: _readerPageTurnGateSnapshot(),
    );
  }

  ReaderPageTurnRequestKind _readerPageTurnRequestKindForCommand(
    ReaderNavigationCommand command,
  ) {
    return switch (command.type) {
      ReaderNavigationCommandType.previousPage ||
      ReaderNavigationCommandType.nextPage => ReaderPageTurnRequestKind.page,
      ReaderNavigationCommandType.previousChapter ||
      ReaderNavigationCommandType
          .nextChapter => ReaderPageTurnRequestKind.chapter,
      ReaderNavigationCommandType.jumpChapter => ReaderPageTurnRequestKind.jump,
      ReaderNavigationCommandType.reloadChapter =>
        ReaderPageTurnRequestKind.reload,
    };
  }

  ReaderPageTurnRequestSource _pageTurnRequestSourceForNavigation(
    ReaderNavigationCommandSource source,
  ) {
    return switch (source) {
      ReaderNavigationCommandSource.chrome =>
        ReaderPageTurnRequestSource.chrome,
      ReaderNavigationCommandSource.audio => ReaderPageTurnRequestSource.audio,
      ReaderNavigationCommandSource.tapZone =>
        ReaderPageTurnRequestSource.tapZone,
      ReaderNavigationCommandSource.keyboard =>
        ReaderPageTurnRequestSource.keyboard,
      ReaderNavigationCommandSource.swipe => ReaderPageTurnRequestSource.swipe,
      ReaderNavigationCommandSource.volumeKey =>
        ReaderPageTurnRequestSource.volumeKey,
      ReaderNavigationCommandSource.scrollEdge =>
        ReaderPageTurnRequestSource.scrollEdge,
      ReaderNavigationCommandSource.autoRead =>
        ReaderPageTurnRequestSource.autoRead,
      ReaderNavigationCommandSource.catalog =>
        ReaderPageTurnRequestSource.catalog,
      ReaderNavigationCommandSource.unknown =>
        ReaderPageTurnRequestSource.navigationCommand,
    };
  }

  ReaderPageTurnGateSnapshot _readerPageTurnGateSnapshot() {
    return ReaderPageTurnGateSnapshot(
      pagedTransitionAnimating: _isPagedTransitionAnimating,
      curlAutoTurning: _isCurlAutoTurning,
      curlPreviewActive: _isCurlPreviewActive,
      crossChapterSnapshotActive:
          _pageTurnRuntimeController.crossChapterSnapshotTransition.isActive,
      paperCurlAnimating: _paperCurlViewKey.currentState?.isAnimating ?? false,
      readerInteractionAnimating:
          _readerInteractionState == ReaderInteractionRuntimeState.animating,
    );
  }

  void _handleRejectedReaderNavigationCommand(
    ReaderNavigationCommand command,
    ReaderNavigationCommandDecision decision,
  ) {
    if (decision.rejectReason == ReaderNavigationCommandRejectReason.boundary) {
      if (command.type == ReaderNavigationCommandType.previousChapter) {
        _showChapterBoundaryHint(isFirst: true);
      } else if (command.type == ReaderNavigationCommandType.nextChapter) {
        _showChapterBoundaryHint(isFirst: false);
      }
      return;
    }

    final message = decision.message;
    if (decision.rejectReason ==
            ReaderNavigationCommandRejectReason.pageTurnBusy &&
        _shouldSuppressReaderBusyMessage(command)) {
      return;
    }
    if (message != null && message.isNotEmpty) {
      _showMessage(message);
    }
  }

  bool _shouldSuppressReaderBusyMessage(ReaderNavigationCommand command) {
    final turnGateDecision = _readerPageTurnGateDecisionForCommand(command);
    return turnGateDecision.blockReason ==
        ReaderPageTurnBlockReason.crossChapterSnapshotActive;
  }

  void _logReaderNavigationCommand({
    required ReaderNavigationCommand command,
    required ReaderNavigationCommandSnapshot snapshot,
    required ReaderNavigationCommandDecision decision,
  }) {
    final context = <String, Object?>{
      'chain': 'reader_navigation_command',
      'command': command.type.name,
      'source': command.source.name,
      'decision': decision.type.name,
      'rejectReason': decision.rejectReason?.name,
      'targetChapterIndex': command.targetChapterIndex,
      'currentIndex': snapshot.currentChapterIndex,
      'chapterCount': snapshot.chapterCount,
      'pageTurnBusy': snapshot.pageTurnBusy,
      'pageTurnBusyReason': snapshot.pageTurnBusyReason?.name,
      'bootstrapping': snapshot.bootstrapping,
      'loadingContent': snapshot.loadingContent,
      'hasError': snapshot.hasError,
      'overlayVisible': snapshot.overlayVisible,
      'isLocalContent': snapshot.isLocalContent,
      'usesContinuousTextFlow': snapshot.usesContinuousTextFlow,
      'viewportKind': snapshot.viewportKind,
      'contentMode': snapshot.contentMode,
      'selectionActive': snapshot.selectionActive,
      'chapterId': _chapterId,
    };
    developer.Timeline.instantSync(
      'reader.navigation_command',
      arguments: context,
    );
    if (decision.shouldExecute) {
      _logger.info('Reader navigation command execute', context: context);
    } else {
      _logger.warn('Reader navigation command rejected', context: context);
    }
  }

  Future<bool> _jumpToAdjacentReadableChapter({
    required bool forward,
    bool showBoundaryHint = true,
    double? initialScrollRatio,
  }) async {
    final sessionState = _currentTextSessionState();
    final fallbackCurrentIndex =
        _currentIndex == null ? _resolveCurrentIndex(_chapters) : null;
    final currentChapterIndex =
        sessionState?.currentChapterIndex ??
        _currentIndex ??
        fallbackCurrentIndex;
    if (_currentIndex == null && currentChapterIndex != null) {
      _currentIndex = currentChapterIndex;
    }
    _logger.info(
      'Reader adjacent chapter navigation',
      context: <String, Object?>{
        'chain': 'reader_chapter_navigation',
        'step': 'adjacent_request',
        'direction': forward ? 'next' : 'previous',
        'chapterId': _chapterId,
        'chapterUrl': _chapterUrl,
        'currentIndex': _currentIndex,
        'sessionIndex': sessionState?.currentChapterIndex,
        'fallbackIndex': fallbackCurrentIndex,
        'resolvedCurrentIndex': currentChapterIndex,
        'chapterCount': _chapters.length,
      },
    );
    final decision = _chapterFlow.resolveAdjacentChapter(
      chapters: _chapters,
      currentChapterIndex: currentChapterIndex,
      forward: forward,
      initialScrollRatio: initialScrollRatio,
    );
    if (decision.type == ReaderAdjacentChapterDecisionType.noCurrent) {
      if (showBoundaryHint) {
        _showMessage('当前章节定位失败，请从目录重新进入。');
      }
      _logger.warn(
        'Reader adjacent chapter navigation rejected',
        context: <String, Object?>{
          'chain': 'reader_chapter_navigation',
          'step': 'no_current',
          'direction': forward ? 'next' : 'previous',
          'chapterId': _chapterId,
          'chapterCount': _chapters.length,
        },
      );
      return false;
    }
    if (decision.type == ReaderAdjacentChapterDecisionType.boundary) {
      if (showBoundaryHint) {
        _showChapterBoundaryHint(isFirst: decision.isFirstBoundary);
      }
      _logger.info(
        'Reader adjacent chapter navigation boundary',
        context: <String, Object?>{
          'chain': 'reader_chapter_navigation',
          'step': 'boundary',
          'direction': forward ? 'next' : 'previous',
          'currentIndex': currentChapterIndex,
          'chapterCount': _chapters.length,
          'isFirstBoundary': decision.isFirstBoundary,
        },
      );
      return false;
    }
    _logger.info(
      'Reader adjacent chapter navigation jump',
      context: <String, Object?>{
        'chain': 'reader_chapter_navigation',
        'step': 'jump',
        'direction': forward ? 'next' : 'previous',
        'fromIndex': currentChapterIndex,
        'targetIndex': decision.targetChapterIndex,
        'initialScrollRatio': decision.initialScrollRatio,
      },
    );
    await _jumpTo(
      decision.targetChapterIndex!,
      initialScrollRatio: decision.initialScrollRatio,
    );
    return true;
  }

  Future<void> _jumpTo(
    int index, {
    double? initialScrollRatio,
    ReaderLogicalPosition? initialLogicalPosition,
  }) async {
    if (_isLoadingContent || index < 0 || index >= _chapters.length) {
      return;
    }

    _stopAutoRead();
    _resetScrollEdgeAdvanceState();
    final jumpDecision = _jumpPlanner.resolve(
      chapters: _chapters,
      requestedChapterIndex: index,
      currentChapterIndex: _currentIndex,
    );
    if (jumpDecision.type == ReaderJumpDecisionType.boundary) {
      _showChapterBoundaryHint(isFirst: jumpDecision.isFirstBoundary);
      return;
    }
    final windowMovePlan = _chapterWindowController.buildMovePlan(
      chapters: _chapters,
      previousCurrentChapterIndex: _currentIndex,
      nextCurrentChapterIndex: jumpDecision.targetChapterIndex,
    );
    _readerSessionController.cancelPreloadTasks();
    _readerSessionController.cancelPaginationTasks();
    _continuousTextChapters = _retainContinuousTextWindowFlow(
      _continuousTextChapters,
      currentChapterIndex: windowMovePlan.to?.currentChapterIndex,
    );
    final chapter = _chapters[jumpDecision.targetChapterIndex!];

    final success = await _loadCurrentChapter(
      initialScrollRatio: initialScrollRatio ?? 0,
      initialLogicalPosition: initialLogicalPosition,
      sourceIdOverride: _sourceId,
      chapterIdOverride: chapter.id,
      chapterUrlOverride: chapter.chapterUrl,
      chapterTitleOverride: chapter.title,
      chapterIndexOverride: jumpDecision.targetChapterIndex,
      commitChapterIdentity: true,
    );
    if (success || !mounted) {
      return;
    }

    setState(() {
      _errorText = null;
      _contentFailureDiagnostics = null;
    });

    _maybeStartReadingRecordSession(initialRatio: _currentScrollRatio());
    _showChapterSwitchFailedSnackbar(jumpDecision.targetChapterIndex!);
  }

  Future<void> _openCatalogSheetFromOverlay() async {
    _suspendOverlayAutoHide();
    await _showCatalogSheet();
    if (mounted) {
      _resumeOverlayAutoHide();
    }
  }

  Future<void> _executeNavigationRequest(
    ReaderNavigationRequest request, {
    bool resumeAutoReadOnRestore = false,
  }) async {
    switch (request.type) {
      case ReaderNavigationRequestType.resumeAutoRead:
        if (resumeAutoReadOnRestore) {
          _scheduleAutoReadResume();
        }
        return;
      case ReaderNavigationRequestType.restoreCurrent:
        if (request.initialLogicalPosition != null) {
          final ratio = _resolveDocumentRestoreRatio(
            logicalPosition: request.initialLogicalPosition,
          );
          _restoreScrollPosition(ratio);
        } else if (request.initialScrollRatio != null) {
          _restoreScrollPosition(request.initialScrollRatio!);
        }
        if (resumeAutoReadOnRestore) {
          _scheduleAutoReadResume();
        } else {
          _scheduleProgressSave();
        }
        return;
      case ReaderNavigationRequestType.jumpChapter:
        await _jumpTo(
          request.targetChapterIndex!,
          initialScrollRatio: request.initialScrollRatio,
          initialLogicalPosition: request.initialLogicalPosition,
        );
        return;
      case ReaderNavigationRequestType.jumpBookmark:
        await _jumpTo(request.targetChapterIndex!, initialScrollRatio: 0);
        if (!mounted) {
          return;
        }
        final bookmark = request.bookmark!;
        if (_content.trim().isEmpty) {
          _showMessage('章节内容为空，无法定位灵感。');
          return;
        }
        final restorePlan = _jumpFacade.resolveBookmarkRestorePlan(
          bookmark: bookmark,
          document: _document,
          currentChapterIndex: _currentIndex,
          isPagedTextReaderEnabled: _isPagedTextReaderEnabled(),
          currentPageIndex: _pageTurnRuntimeController.currentPageIndex,
          chapterContent: _content,
        );
        if (restorePlan.logicalPosition != null) {
          await _executeNavigationRequest(
            ReaderNavigationRequest.restoreCurrent(
              logicalPosition: restorePlan.logicalPosition,
            ),
          );
          return;
        }
        if (restorePlan.fallbackRatio != null) {
          await _executeNavigationRequest(
            ReaderNavigationRequest.restoreCurrent(
              scrollRatio: restorePlan.fallbackRatio,
            ),
          );
          return;
        }
        _showMessage('未找到灵感位置，已定位到章节开头。');
        return;
    }
  }

  Future<void> _openMangaPositionSheet() async {
    if (!_isMangaViewport) {
      return;
    }

    final total = _chapterImageUrls.length;
    if (total <= 1 && !_scrollController.hasClients) {
      return;
    }

    final isPagedMode =
        _currentViewportKind == ReaderModeViewportKind.imagePaged;
    double draftRatio = _currentScrollRatio();
    final readerModalTheme = _readerModalTheme();

    final selectedRatio = await showAdaptiveActionSurface<double>(
      context: context,
      maxWidth: 460,
      builder: (context) {
        return Theme(
          data: readerModalTheme,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final progressLabel = '${(draftRatio * 100).round()}%';
              final chapterLabel =
                  isPagedMode
                      ? '第 ${(_imagePageIndex + 1).clamp(1, total)} / $total 张'
                      : '长图进度定位';

              return Padding(
                padding: const EdgeInsets.fromLTRB(2, 0, 2, 2),
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
                        AppButton(
                          variant: AppButtonVariant.text,
                          onPressed: () => Navigator.of(context).pop(),
                          label: '取消',
                        ),
                        const Spacer(),
                        AppButton(
                          onPressed:
                              () => Navigator.of(context).pop(draftRatio),
                          label: '跳转',
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

    await _executeNavigationRequest(
      _navigationEntryResolver.resolveProgressSelection(
        scrollRatio: selectedRatio,
      ),
    );
  }

  Future<void> _showCatalogSheet() async {
    final beforeLoadDecision = _catalogEntryController.resolveOpenDecision(
      capabilities: _readerModeCapabilities,
      hasCatalog: _chapters.isNotEmpty,
      catalogComplete: _catalogComplete,
    );
    if (!beforeLoadDecision.canOpen) {
      _showMessage(beforeLoadDecision.message ?? '当前内容暂不支持目录操作。');
      return;
    }
    if (!await _ensureCatalogLoadedForOverlay()) {
      final afterLoadDecision = _catalogEntryController.resolveOpenDecision(
        capabilities: _readerModeCapabilities,
        hasCatalog: _chapters.isNotEmpty,
        catalogComplete: true,
      );
      _showMessage(afterLoadDecision.message ?? '当前书籍暂无目录。');
      return;
    }
    _stopAutoReadSession();
    final customCoverPath =
        _bookCustomCoverPath ?? await _resolveCurrentBookCustomCoverPath();
    if (!mounted) {
      return;
    }
    final resolvedCover = resolveBookCover(
      realCoverUrl: _bookCoverUrl,
      customCoverPath: customCoverPath,
      activeTheme: _currentActiveAdvancedTheme(),
      galleries: _coverGalleries,
      brightness: Theme.of(context).brightness,
      bookId: _currentBookId,
      sourceId: _sourceId,
      detailUrl: _detailUrl,
    );
    final result = await showReaderCatalogSheet(
      context: context,
      readerModalTheme: _readerModalTheme(),
      chapters: _chapters,
      currentChapterIndex: _currentIndex,
      bookTitle: _bookTitle,
      bookAuthor: _bookAuthor,
      bookCoverUrl: _bookCoverUrl,
      customCoverPath: customCoverPath,
      resolvedCover: resolvedCover,
      supportsContentSearch:
          _readerModeCapabilities.supportsCatalogContentSearch,
      bookmarkRepository: _bookmarkRepository,
      currentBookId: _currentBookId,
      peekCatalogSearchEntries: (keyword) {
        if (!mounted) {
          return null;
        }
        return _peekCatalogSearchEntries(keyword);
      },
      lookupCatalogSearchEntries: (keyword) {
        if (!mounted) {
          return const <ReaderCatalogSearchEntry>[];
        }
        return _lookupCatalogSearchEntries(keyword);
      },
      resolveCatalogSearchEntryTargetIndex: (entry) {
        if (!mounted) {
          return null;
        }
        return _resolveCatalogSearchEntryTargetIndex(entry);
      },
      refreshChapterBookmarks: () async {
        if (!mounted) {
          return;
        }
        await _refreshChapterBookmarks();
      },
      showMessage: (message) {
        if (!mounted) {
          return;
        }
        _showMessage(message);
      },
    );
    if (!mounted) {
      return;
    }

    if (result?.bookmark != null) {
      await _jumpToBookmark(result!.bookmark!);
      return;
    }

    final selection = result?.selection;

    final request = _navigationEntryResolver.resolveCatalogSelection(
      selectedIndex: selection?.chapterIndex,
      chapters: _chapters,
      currentChapterIndex: _currentIndex,
      selectedScrollRatio: selection?.scrollRatio,
      selectedLogicalPosition: selection?.logicalPosition,
    );
    await _executeNavigationRequest(request, resumeAutoReadOnRestore: true);
  }

  List<ReaderCatalogSearchEntry> _lookupCatalogSearchEntries(String keyword) {
    final result = _catalogSearchService.lookup(
      keyword: keyword,
      state: ReaderCatalogSearchCacheState(
        fingerprint: _catalogSearchCacheFingerprint,
        entriesCache: _catalogSearchEntriesCache,
      ),
      supportsContentSearch:
          _readerModeCapabilities.supportsCatalogContentSearch,
      chapterId: _chapterId,
      chapterUrl: _chapterUrl,
      currentChapterIndex: _currentIndex,
      chapters: _chapters,
      chapterContent: _content,
      chapterParagraphs: _paragraphs,
      chapterDocument: _document,
      isPagedTextReaderEnabled: _isPagedTextReaderEnabled(),
      currentPageIndex: _pageTurnRuntimeController.currentPageIndex,
    );
    _catalogSearchCacheFingerprint = result.state.fingerprint;
    _catalogSearchEntriesCache = result.state.entriesCache;
    return result.entries;
  }
}
