import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/book.dart';
import '../../reader/application/source_switch_score_service.dart';
import '../../reader/application/switch_source_shared.dart';
import '../../search/application/search_hit_cache_service.dart';
import '../../search/application/search_service.dart';
import '../../source/application/source_runtime_facade.dart';
import '../../../runtime/sources/source_registry.dart';

class BookDetailSwitchSourceScope {
  const BookDetailSwitchSourceScope({
    required this.sourceIds,
    required this.contentMode,
    this.allowUnscopedSearch = false,
  });

  final List<String> sourceIds;
  final SearchContentMode contentMode;
  final bool allowUnscopedSearch;
}

class BookDetailSwitchSourceHelper {
  BookDetailSwitchSourceHelper({
    required SearchService switchSourceSearchService,
    required SearchHitCacheService searchHitCacheService,
    required SourceSwitchScoreService switchSourceScoreService,
    SourceRuntimeFacade? sourceRuntimeFacade,
  }) : _switchSourceSearchService = switchSourceSearchService,
       _searchHitCacheService = searchHitCacheService,
       _switchSourceScoreService = switchSourceScoreService,
       _sourceRuntimeFacade =
           sourceRuntimeFacade ?? SourceRuntimeFacade.instance;

  final SearchService _switchSourceSearchService;
  final SearchHitCacheService _searchHitCacheService;
  final SourceSwitchScoreService _switchSourceScoreService;
  final SourceRuntimeFacade _sourceRuntimeFacade;

  static const int _candidateLimit = 24;
  static const int _lagTolerance = 20;
  static const int _scoreStep = 6;
  static const int _hitCountCap = 12;
  static const int _hitCountWeight = 3;
  static const Duration _scopeLoadTimeout = Duration(milliseconds: 1600);
  static const Duration _hitCountLoadTimeout = Duration(milliseconds: 1200);
  static final RegExp _chapterPattern = RegExp(r'第?\s*(\d{1,5})\s*章');
  static final RegExp _chapterEnglishPattern = RegExp(
    r'^(chapter|chap)\s*\d{1,5}\b',
  );

  Future<BookDetailSwitchSourceScope> buildScope({
    required String currentSourceId,
  }) async {
    List<RegisteredSource> sources;
    try {
      sources = _sourceRuntimeFacade.registeredScriptSources(enabledOnly: true);
      if (sources.isEmpty) {
        final report = await _sourceRuntimeFacade.reloadScriptSources().timeout(
          _scopeLoadTimeout,
        );
        sources = report.loaded;
      }
    } catch (_) {
      return const BookDetailSwitchSourceScope(
        sourceIds: <String>[],
        contentMode: SearchContentMode.novel,
        allowUnscopedSearch: true,
      );
    }
    if (sources.isEmpty) {
      return const BookDetailSwitchSourceScope(
        sourceIds: <String>[],
        contentMode: SearchContentMode.novel,
        allowUnscopedSearch: true,
      );
    }

    RegisteredSource? currentSource;
    for (final source in sources) {
      if (source.runtime.id == currentSourceId) {
        currentSource = source;
        break;
      }
    }

    if (currentSource == null) {
      final fallbackSourceIds = sources
          .where((source) => source.runtime.id != currentSourceId)
          .map((source) => source.runtime.id)
          .toList(growable: false);
      if (fallbackSourceIds.isEmpty) {
        return const BookDetailSwitchSourceScope(
          sourceIds: <String>[],
          contentMode: SearchContentMode.novel,
          allowUnscopedSearch: true,
        );
      }
      return BookDetailSwitchSourceScope(
        sourceIds: fallbackSourceIds,
        contentMode: SearchContentMode.novel,
      );
    }

    final isMangaType = _isMangaSource(currentSource);
    final sourceIds = sources
        .where(
          (source) =>
              source.runtime.id != currentSourceId &&
              _isMangaSource(source) == isMangaType,
        )
        .map((source) => source.runtime.id)
        .toList(growable: false);
    if (sourceIds.isEmpty) {
      return BookDetailSwitchSourceScope(
        sourceIds: const <String>[],
        contentMode:
            isMangaType ? SearchContentMode.manga : SearchContentMode.novel,
        allowUnscopedSearch: true,
      );
    }
    return BookDetailSwitchSourceScope(
      sourceIds: sourceIds,
      contentMode:
          isMangaType ? SearchContentMode.manga : SearchContentMode.novel,
    );
  }

  bool _isMangaSource(RegisteredSource source) {
    final capabilities =
        source.definition.manifest.capabilities
            .map((item) => item.trim().toLowerCase())
            .where((item) => item.isNotEmpty)
            .toSet();
    return capabilities.contains('manga') ||
        capabilities.contains('comic') ||
        capabilities.contains('manhua') ||
        capabilities.contains('manhwa');
  }

  Future<String?> resolveSearchKeyword({
    required String currentTitle,
    required Future<String?> Function(String currentTitle) reloadTitle,
    required void Function(String title) onResolvedTitle,
  }) async {
    if (isBookTitleUsable(currentTitle)) {
      return currentTitle.trim();
    }

    try {
      final refreshedTitle = (await reloadTitle(currentTitle))?.trim() ?? '';
      if (isBookTitleUsable(refreshedTitle)) {
        onResolvedTitle(refreshedTitle);
        return refreshedTitle;
      }
    } catch (_) {
      // Fall through to null and let caller show user-facing message.
    }

    return null;
  }

  bool isBookTitleUsable(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    return !_looksLikeChapterTitle(trimmed);
  }

  Future<SourceSwitchScoreStore> loadScoreStoreSafely() async {
    try {
      return await _switchSourceScoreService.loadStore();
    } catch (_) {
      return SourceSwitchScoreStore(
        sourceScores: <String, int>{},
        bookScores: <String, int>{},
      );
    }
  }

  Future<Map<String, int>> loadHitCountsSafely({
    required String title,
    required String? author,
  }) async {
    try {
      return await _searchHitCacheService
          .loadSourceHitCounts(title: title, author: author)
          .timeout(_hitCountLoadTimeout);
    } catch (_) {
      return <String, int>{};
    }
  }

  List<SwitchSourceCandidate> buildCandidates({
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
    return buildSwitchSourceCandidates(
      books: books,
      sourceNames: sourceNames,
      currentSourceId: currentSourceId,
      currentChapterCount: currentChapterCount,
      targetTitle: targetTitle,
      targetAuthor: targetAuthor,
      hitCountBySource: hitCountBySource,
      scoreStore: scoreStore,
      scoreRankingEnabled: scoreRankingEnabled,
      buildBookScoreKey: _switchSourceScoreService.buildBookScoreKey,
      lagTolerance: _lagTolerance,
      hitCountCap: _hitCountCap,
      hitCountWeight: _hitCountWeight,
      candidateLimit: _candidateLimit,
    );
  }

  Future<void> loadCandidatesProgressively({
    required String keyword,
    required String? author,
    required BookDetailSwitchSourceScope scope,
    required String currentSourceId,
    required int currentChapterCount,
    required ValueNotifier<SwitchSourceLookupState> lookupStateNotifier,
    required SearchCancellationToken cancellationToken,
    required SourceSwitchScoreStore scoreStore,
    required bool scoreRankingEnabled,
  }) async {
    final requestScopedSourceIds =
        scope.allowUnscopedSearch && scope.sourceIds.isEmpty
            ? null
            : scope.sourceIds;
    try {
      final hitCountBySource = await loadHitCountsSafely(
        title: keyword,
        author: author,
      );
      final report = await _switchSourceSearchService.search(
        keyword: keyword,
        pageSize: 16,
        contentMode: scope.contentMode,
        sourceIds: requestScopedSourceIds,
        cancellationToken: cancellationToken,
        onProgress: (progress) {
          if (cancellationToken.isCancelled) {
            return;
          }

          final candidates = buildCandidates(
            books: progress.books,
            sourceNames: progress.sourceNames,
            currentSourceId: currentSourceId,
            currentChapterCount: currentChapterCount,
            targetTitle: keyword,
            targetAuthor: author,
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

      final candidates = buildCandidates(
        books: report.books,
        sourceNames: report.sourceNames,
        currentSourceId: currentSourceId,
        currentChapterCount: currentChapterCount,
        targetTitle: keyword,
        targetAuthor: author,
        hitCountBySource: hitCountBySource,
        scoreStore: scoreStore,
        scoreRankingEnabled: scoreRankingEnabled,
      );
      lookupStateNotifier.value = SwitchSourceLookupState(
        isLoading: false,
        sourceCount: report.sourceCount,
        processedSourceCount: report.processedSourceCount,
        candidates: candidates,
        errorText: candidates.isEmpty ? '没有检索到可切换书享源，请稍后重试。' : null,
        scoreRankingEnabled: scoreRankingEnabled,
      );
    } on AppException catch (error) {
      if (cancellationToken.isCancelled) {
        return;
      }
      lookupStateNotifier.value = SwitchSourceLookupState(
        isLoading: false,
        sourceCount:
            requestScopedSourceIds == null ? 0 : requestScopedSourceIds.length,
        processedSourceCount: 0,
        candidates: const <SwitchSourceCandidate>[],
        errorText: '查找可切换书享源失败：${error.briefMessage}',
        scoreRankingEnabled: scoreRankingEnabled,
      );
    } catch (_) {
      if (cancellationToken.isCancelled) {
        return;
      }
      lookupStateNotifier.value = SwitchSourceLookupState(
        isLoading: false,
        sourceCount:
            requestScopedSourceIds == null ? 0 : requestScopedSourceIds.length,
        processedSourceCount: 0,
        candidates: const <SwitchSourceCandidate>[],
        errorText: '查找可切换书享源失败，请稍后重试。',
        scoreRankingEnabled: scoreRankingEnabled,
      );
    }
  }

  Future<void> applyScoreAction({
    required SwitchSourceCandidate candidate,
    required SwitchSourceScoreAction action,
    required ValueNotifier<SwitchSourceLookupState> lookupStateNotifier,
    required SourceSwitchScoreStore scoreStore,
    required bool scoreRankingEnabled,
    required void Function(String message) onMessage,
  }) async {
    try {
      final update = switch (action) {
        SwitchSourceScoreAction.upvote => _switchSourceScoreService
            .adjustBookScore(
              sourceId: candidate.book.sourceId,
              title: candidate.book.title,
              author: candidate.book.author,
              delta: _scoreStep,
            ),
        SwitchSourceScoreAction.downvote => _switchSourceScoreService
            .adjustBookScore(
              sourceId: candidate.book.sourceId,
              title: candidate.book.title,
              author: candidate.book.author,
              delta: -_scoreStep,
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
            (item) => rebuildCandidateScore(
              item,
              scoreStore: scoreStore,
              scoreRankingEnabled: scoreRankingEnabled,
            ),
          )
          .toList(growable: false);
      lookupStateNotifier.value = current.copyWith(
        candidates: sortSwitchSourceCandidates(nextCandidates),
      );

      final actionLabel = switch (action) {
        SwitchSourceScoreAction.upvote => '已推荐',
        SwitchSourceScoreAction.downvote => '已降权',
        SwitchSourceScoreAction.reset => '已重置',
      };
      onMessage(
        '$actionLabel ${candidate.sourceName}（源评 ${formatSignedScore(resolved.sourceScore)}，书评 ${formatSignedScore(resolved.bookScore)}）',
      );
    } catch (_) {
      onMessage('更新评分失败，请稍后重试。');
    }
  }

  SwitchSourceCandidate rebuildCandidateScore(
    SwitchSourceCandidate candidate, {
    required SourceSwitchScoreStore scoreStore,
    required bool scoreRankingEnabled,
  }) {
    return rebuildSwitchSourceCandidateScore(
      candidate,
      scoreStore: scoreStore,
      scoreRankingEnabled: scoreRankingEnabled,
      buildBookScoreKey: _switchSourceScoreService.buildBookScoreKey,
      hitCountCap: _hitCountCap,
      hitCountWeight: _hitCountWeight,
    );
  }

  String formatSignedScore(int score) {
    if (score > 0) {
      return '+$score';
    }
    return '$score';
  }

  bool _looksLikeChapterTitle(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (_chapterPattern.hasMatch(trimmed)) {
      return true;
    }
    final lower = trimmed.toLowerCase();
    return _chapterEnglishPattern.hasMatch(lower);
  }
}
