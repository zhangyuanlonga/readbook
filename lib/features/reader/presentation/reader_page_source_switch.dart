// ignore_for_file: invalid_use_of_protected_member

part of 'reader_page.dart';

extension _ReaderPageSourceSwitchExtension on _ReaderPageState {
  Future<void> _showSwitchSourceSheet() async {
    _suspendOverlayAutoHide();
    try {
      if (!await _ensureSwitchSourceMembership()) {
        return;
      }
      final validation = _sourceSwitchCoordinator.validateManualSwitchRequest(
        isSwitchSourceLoading: _isSwitchSourceLoading,
        canSwitchSource: _canSwitchSource,
        sourceId: _sourceId,
        detailUrl: _detailUrl,
      );
      if (!validation.canProceed) {
        final message = (validation.message ?? '').trim();
        if (message.isNotEmpty) {
          _showMessage(message);
        }
        return;
      }
      final currentSourceId = validation.currentSourceId!;
      final currentDetailUrl = validation.currentDetailUrl!;

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

      ReaderSwitchSourceScopePlan scope;
      try {
        scope = await _buildSwitchSourceScope(currentSourceId: currentSourceId);
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

      if (mounted) {
        setState(() {
          _isSwitchSourceLoading = true;
        });
      }

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
        if (identical(
          _activeSwitchSourceCancellationToken,
          cancellationToken,
        )) {
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
    } finally {
      _resumeOverlayAutoHide();
    }
  }

  Future<bool> _ensureSwitchSourceMembership() async {
    try {
      final session = await _membershipAccessService.getCurrentSession();
      if (session == null) {
        _showMessage(
          MembershipAccessPresentation.unavailableMessage(
            MembershipFeatureGate.switchSource,
            isLoggedIn: false,
          ),
        );
        if (mounted) {
          unawaited(context.push('/membership'));
        }
        return false;
      }

      final hasAccess = await _membershipAccessService.fetchOnlineServiceAccess(
        session: session,
      );
      if (!hasAccess) {
        _showMessage(
          MembershipAccessPresentation.unavailableMessage(
            MembershipFeatureGate.switchSource,
            isLoggedIn: true,
          ),
        );
        if (mounted) {
          unawaited(context.push('/membership'));
        }
        return false;
      }
      return true;
    } catch (error) {
      _showMessage(
        error is AppException
            ? error.briefMessage
            : MembershipAccessPresentation.checkFailedMessage,
      );
      return false;
    }
  }

  Future<ReaderSwitchSourceScopePlan> _buildSwitchSourceScope({
    required String currentSourceId,
  }) {
    return _sourceSwitchController.buildSwitchSourceScope(
      currentSourceId: currentSourceId,
      isMangaChapter: _isMangaChapter,
    );
  }

  Future<void> _loadSwitchSourceCandidatesProgressively({
    required String keyword,
    required ReaderSwitchSourceScopePlan scope,
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
        contentMode:
            scope.isMangaType
                ? SearchContentMode.manga
                : SearchContentMode.novel,
        scenario: SearchPlanScenario.switchSource,
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
    final sourceHealthBySourceId = _sourceHealthService.snapshotsFor(
      books.map((book) => book.sourceId),
    );
    return buildSwitchSourceCandidates(
      books: books,
      sourceNames: sourceNames,
      currentSourceId: currentSourceId,
      currentChapterCount: currentChapterCount,
      targetTitle: targetTitle,
      targetAuthor: targetAuthor,
      hitCountBySource: hitCountBySource,
      scoreStore: scoreStore,
      sourceHealthBySourceId: sourceHealthBySourceId,
      scoreRankingEnabled: scoreRankingEnabled,
      buildBookScoreKey: _switchSourceScoreService.buildBookScoreKey,
      lagTolerance: _ReaderPageState._kSwitchSourceLagTolerance,
      hitCountCap: _ReaderPageState._kSwitchSourceHitCountCap,
      hitCountWeight: _ReaderPageState._kSwitchSourceHitCountWeight,
      candidateLimit: _ReaderPageState._kSwitchSourceCandidateLimit,
    );
  }

  Future<String?> _resolveSwitchSourceSearchKeyword({
    required String currentSourceId,
    required String currentDetailUrl,
  }) async {
    final currentTitle = _bookTitle.trim();
    final keyword = _sourceSwitchCoordinator.resolveKeywordFromKnownTitles(
      currentTitle: currentTitle,
      fallbackTitles: <String?>[widget.chapterTitle, _chapterTitle],
    );
    if (keyword != null) {
      if (mounted && keyword != _bookTitle) {
        setState(() {
          _bookTitle = keyword;
        });
      } else {
        _bookTitle = keyword;
      }
      return keyword;
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
      if (_sourceSwitchCoordinator.isBookTitleUsable(refreshedTitle)) {
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
              delta: _ReaderPageState._kSwitchSourceScoreStep,
            ),
        SwitchSourceScoreAction.downvote => _switchSourceScoreService
            .adjustBookScore(
              sourceId: candidate.book.sourceId,
              title: candidate.book.title,
              author: candidate.book.author,
              delta: -_ReaderPageState._kSwitchSourceScoreStep,
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
    Map<String, SourceHealthSnapshot> sourceHealthBySourceId =
        const <String, SourceHealthSnapshot>{},
    required bool scoreRankingEnabled,
  }) {
    return rebuildSwitchSourceCandidateScore(
      candidate,
      scoreStore: scoreStore,
      sourceHealthBySourceId: sourceHealthBySourceId,
      scoreRankingEnabled: scoreRankingEnabled,
      buildBookScoreKey: _switchSourceScoreService.buildBookScoreKey,
      hitCountCap: _ReaderPageState._kSwitchSourceHitCountCap,
      hitCountWeight: _ReaderPageState._kSwitchSourceHitCountWeight,
    );
  }

  String _formatSignedScore(int score) {
    return _sourceSwitchController.formatSignedScore(score);
  }

  void _cancelActiveSwitchSourceSearch() {
    _activeSwitchSourceCancellationToken?.cancel();
    _activeSwitchSourceCancellationToken = null;
  }

  bool _canAutoSwitchSourceOnFailure() {
    return _sourceSwitchController.canAutoSwitchSourceOnFailure(
      canSwitchSource: _canSwitchSource,
      autoSwitchSourceOnFailureEnabled: _autoSwitchSourceOnFailureEnabled,
      isAutoSwitchingSource: _isAutoSwitchingSource,
      isSwitchSourceLoading: _isSwitchSourceLoading,
      sourceId: _sourceId,
      detailUrl: _detailUrl,
    );
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

      final scoreStore = await _loadSwitchSourceScoreStoreSafely();
      final hitCountBySource = await _loadSwitchSourceHitCountsSafely(
        title: keyword,
        author: _bookAuthor,
      );
      final report = await _switchSourceSearchService.search(
        keyword: keyword,
        pageSize: 16,
        contentMode:
            scope.isMangaType
                ? SearchContentMode.manga
                : SearchContentMode.novel,
        scenario: SearchPlanScenario.autoSwitchSource,
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

      final autoTryCandidates = _sourceSwitchCoordinator
          .prioritizeAutoSwitchCandidates(
            candidates,
            tryLimit: _ReaderPageState._kAutoSwitchSourceTryLimit,
          );

      for (final candidate in autoTryCandidates) {
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
      contentSession: _currentContentSession(),
      errorText: _errorText,
      isInBookshelf: _isInBookshelf,
      isCurrentChapterCached: _isCurrentChapterCached,
      content: _content,
      chapterImageUrls: _chapterImageUrls,
      chapterImageHeaders: _chapterImageHeaders,
      scrollRatio: _currentScrollRatio(),
      catalogComplete: _catalogComplete,
    );

    setState(() {
      _isSwitchSourceLoading = true;
    });

    try {
      _commitReadingRecordSession();
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
      if (!detailResult.catalogComplete) {
        if (showResultMessage) {
          _showMessage('目标书源目录未完整加载，暂时无法安全换源。');
        }
        return false;
      }
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
      if (_chapterNavigation.readableChapters(chapters).isEmpty) {
        if (showResultMessage) {
          _showMessage('目标书源暂无可读章节，无法切换。');
        }
        return false;
      }
      final switchTarget = _sourceSwitchTargetResolver.resolve(
        currentChapters: snapshot.chapters,
        targetChapters: chapters,
        previousChapterTitle: snapshot.chapterTitle,
        previousChapterIndex: snapshot.currentIndex,
        previousLogicalPosition:
            snapshot.contentSession?.sessionState?.logicalPosition,
        lagTolerance: _ReaderPageState._kSwitchSourceLagTolerance,
      );
      final positionDecision = switchTarget.positionDecision;

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

      final targetIndex = switchTarget.targetChapterIndex;
      final targetChapter = chapters[targetIndex];

      setState(() {
        _activeBookId = candidate.book.id.trim();
        _sourceId = candidate.book.sourceId;
        _detailUrl = candidate.book.detailUrl;
        _bookTitle = detailResult.detail.title;
        _bookAuthor = detailResult.detail.author;
        _bookCoverUrl = detailResult.detail.coverUrl;
        _bookCustomCoverPath = null;
        _chapters = chapters;
        _catalogComplete = detailResult.catalogComplete;
        _currentIndex = targetIndex;
        _chapterId = targetChapter.id;
        _chapterUrl = targetChapter.chapterUrl;
        _chapterTitle = targetChapter.title;
        _errorText = null;
      });
      await _applyPresentedBookMetadata(
        fallbackTitle: detailResult.detail.title,
        fallbackAuthor: detailResult.detail.author,
        realCoverUrl: detailResult.detail.coverUrl,
        sourceId: candidate.book.sourceId,
        detailUrl: candidate.book.detailUrl,
      );
      _cancelBackgroundRefreshConflictForCurrentBook();

      final loaded = await _loadCurrentChapter(
        initialScrollRatio: switchTarget.logicalPosition.chapterPositionRatio,
      );
      if (!loaded) {
        throw StateError('切换后正文加载失败。');
      }

      await _syncBookshelfAfterSourceSwitch(
        snapshot: snapshot,
        candidate: candidate,
        showResultMessage: showResultMessage,
      );
      await _syncReadingStateAfterSourceSwitch(
        snapshot: snapshot,
        candidate: candidate,
      );

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

  Future<void> _syncBookshelfAfterSourceSwitch({
    required _ReaderSourceSnapshot snapshot,
    required SwitchSourceCandidate candidate,
    required bool showResultMessage,
  }) async {
    final migrationPlan = _sourceSwitchCoordinator.planBookshelfMigrationCheck(
      previousSourceId: snapshot.sourceId,
      previousDetailUrl: snapshot.detailUrl,
      wasInBookshelf: snapshot.isInBookshelf,
    );
    var containsResult = false;
    if (migrationPlan.requiresContainsCheck) {
      try {
        containsResult = await _bookshelfService.contains(
          sourceId: migrationPlan.previousSourceId,
          detailUrl: migrationPlan.previousDetailUrl,
        );
      } catch (_) {
        containsResult = false;
      }
    }
    final shouldMigrateBookshelf = _sourceSwitchCoordinator
        .resolveBookshelfMigration(
          plan: migrationPlan,
          containsResult: containsResult,
        );

    if (!shouldMigrateBookshelf) {
      await _refreshBookshelfState();
      return;
    }

    try {
      final replacementBook = _sourceSwitchCoordinator
          .buildReplacementBookshelfBook(
            currentLogicalBookId: _currentBookId,
            nextSourceId: candidate.book.sourceId,
            nextDetailUrl: candidate.book.detailUrl,
            nextBookTitle: _bookTitle,
            fallbackBookTitle: candidate.book.title,
            nextBookAuthor: _bookAuthor,
            nextBookCoverUrl: _bookCoverUrl,
            latestReadableChapterTitle: _latestReadableChapterTitle(_chapters),
            fallbackLatestChapterTitle: candidate.book.latestChapter,
            addedAt: DateTime.now(),
          );
      await _bookshelfService.replace(
        previousSourceId: migrationPlan.previousSourceId,
        previousDetailUrl: migrationPlan.previousDetailUrl,
        preserveTags: true,
        nextBook: replacementBook,
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
  }

  Future<void> _syncReadingStateAfterSourceSwitch({
    required _ReaderSourceSnapshot snapshot,
    required SwitchSourceCandidate candidate,
  }) async {
    if (snapshot.bookId.trim().isEmpty ||
        snapshot.bookId.trim() == _activeBookId.trim()) {
      return;
    }

    final sourceId = (_sourceId ?? '').trim();
    final detailUrl = (_detailUrl ?? '').trim();
    final chapterUrl = (_chapterUrl ?? '').trim();
    final chapterTitle = (_chapterTitle ?? '').trim();
    final currentIndex = _currentIndex;
    if (sourceId.isEmpty ||
        detailUrl.isEmpty ||
        chapterUrl.isEmpty ||
        chapterTitle.isEmpty ||
        currentIndex == null) {
      return;
    }

    try {
      final logicalPosition = _currentLogicalPosition();
      await _preferencesService.migrateProgress(
        previousBookId: snapshot.bookId,
        nextProgress: ReadingProgress(
          bookId: _activeBookId,
          sourceId: sourceId,
          detailUrl: _normalizeLocalDetailUrlForProgress(detailUrl),
          chapterId: _chapterId,
          chapterUrl: _normalizeLocalChapterUrlForProgress(chapterUrl),
          chapterTitle: chapterTitle,
          chapterIndex: currentIndex,
          updatedAt: DateTime.now(),
          chapterPositionRatio: _currentScrollRatio(),
          logicalPosition: logicalPosition,
        ),
      );
    } catch (_) {
      // Keep source switch success even if progress migration fails.
    }

    try {
      await _readingRecordService.reassignBookIdentity(
        previousBookId: snapshot.bookId,
        nextBookId: _activeBookId,
        nextSourceId: sourceId,
        nextDetailUrl: detailUrl,
        nextBookTitle: _bookTitle,
        nextBookAuthor: _bookAuthor,
        nextCoverUrl: _bookCoverUrl,
      );
    } catch (_) {
      // Keep source switch success even if reading record migration fails.
    }

    _bootstrapProgress = null;
    _maybeStartReadingRecordSession(initialRatio: _currentScrollRatio());
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
        targetChapterCount + _ReaderPageState._kSwitchSourceLagTolerance <
            currentChapterCount;
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

    final confirmed = await showAdaptiveActionSurface<bool>(
      context: context,
      maxWidth: 500,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '切换到 $sourceName ?',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              '$reasonText\n\n$detailText\n继续切换可能回退到较早章节。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('继续切换'),
                ),
              ],
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  void _restoreSourceSnapshot(_ReaderSourceSnapshot snapshot) {
    var restoreRatio = snapshot.scrollRatio;
    setState(() {
      _activeBookId = snapshot.bookId;
      _sourceId = snapshot.sourceId;
      _detailUrl = snapshot.detailUrl;
      _bookTitle = snapshot.bookTitle;
      _bookAuthor = snapshot.bookAuthor;
      _bookCoverUrl = snapshot.bookCoverUrl;
      _chapters = snapshot.chapters;
      _catalogComplete = snapshot.catalogComplete;
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
      restoreRatio = _resolveDocumentRestoreRatio(
        logicalPosition: snapshot.contentSession?.sessionState?.logicalPosition,
        fallback: snapshot.scrollRatio,
      );
      _pagedPaginationState = _pagedPaginationState.copyWith(
        pendingRestoreRatio: restoreRatio,
      );
    });

    _restoreScrollPosition(restoreRatio);
    _scheduleReadingRecordSessionStart(initialRatio: restoreRatio);
    _scheduleAutoReadResume();
  }
}
