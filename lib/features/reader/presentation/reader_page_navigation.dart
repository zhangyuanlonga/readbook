// ignore_for_file: invalid_use_of_protected_member

part of 'reader_page.dart';

extension _ReaderPageNavigationExtension on _ReaderPageState {
  Future<bool> _ensureCatalogLoadedForOverlay() async {
    if (_chapters.isNotEmpty) {
      return true;
    }
    await _hydrateCatalogAfterVisible();
    return _chapters.isNotEmpty;
  }

  Future<bool> _jumpToAdjacentReadableChapter({
    required bool forward,
    bool showBoundaryHint = true,
    double? initialScrollRatio,
  }) async {
    final sessionState = _currentTextSessionState();
    final decision = _chapterFlow.resolveAdjacentChapter(
      chapters: _chapters,
      currentChapterIndex: sessionState?.currentChapterIndex ?? _currentIndex,
      forward: forward,
      initialScrollRatio: initialScrollRatio,
    );
    if (decision.type == ReaderAdjacentChapterDecisionType.noCurrent) {
      return false;
    }
    if (decision.type == ReaderAdjacentChapterDecisionType.boundary) {
      if (showBoundaryHint) {
        _showChapterBoundaryHint(isFirst: decision.isFirstBoundary);
      }
      return false;
    }
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
    });

    _maybeStartReadingRecordSession(initialRatio: _currentScrollRatio());
    _showChapterSwitchFailedSnackbar(jumpDecision.targetChapterIndex!);
  }

  Future<void> _openCatalogSheetFromOverlay() async {
    await _showCatalogSheet();
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
          currentPageIndex: _currentPageIndex,
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

    await _executeNavigationRequest(
      _navigationEntryResolver.resolveProgressSelection(
        scrollRatio: selectedRatio,
      ),
    );
  }

  Future<void> _showCatalogSheet() async {
    if (!await _ensureCatalogLoadedForOverlay()) {
      _showMessage('当前书籍暂无目录。');
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
      activeTheme: ref.read(activeAdvancedThemeProvider).valueOrNull,
      galleries: ref.read(coverGalleriesProvider).valueOrNull ?? const [],
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
      peekCatalogSearchEntries: _peekCatalogSearchEntries,
      lookupCatalogSearchEntries: _lookupCatalogSearchEntries,
      resolveCatalogSearchEntryTargetIndex:
          _resolveCatalogSearchEntryTargetIndex,
      refreshChapterBookmarks: _refreshChapterBookmarks,
      showMessage: _showMessage,
    );

    if (!mounted) {
      _scheduleAutoReadResume();
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
      currentPageIndex: _currentPageIndex,
    );
    _catalogSearchCacheFingerprint = result.state.fingerprint;
    _catalogSearchEntriesCache = result.state.entriesCache;
    return result.entries;
  }
}
