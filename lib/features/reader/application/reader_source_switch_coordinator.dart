import '../../../domain/entities/bookshelf_book.dart';
import '../../../runtime/sources/source_registry.dart';
import 'switch_source_shared.dart';

class ReaderSwitchSourceRequestValidationResult {
  const ReaderSwitchSourceRequestValidationResult._({
    required this.canProceed,
    this.message,
    this.currentSourceId,
    this.currentDetailUrl,
  });

  const ReaderSwitchSourceRequestValidationResult.blocked({
    required String message,
  }) : this._(canProceed: false, message: message);

  const ReaderSwitchSourceRequestValidationResult.ready({
    required String currentSourceId,
    required String currentDetailUrl,
  }) : this._(
         canProceed: true,
         currentSourceId: currentSourceId,
         currentDetailUrl: currentDetailUrl,
       );

  final bool canProceed;
  final String? message;
  final String? currentSourceId;
  final String? currentDetailUrl;
}

class ReaderBookshelfMigrationCheckPlan {
  const ReaderBookshelfMigrationCheckPlan({
    required this.previousSourceId,
    required this.previousDetailUrl,
    required this.shouldMigrateImmediately,
    required this.requiresContainsCheck,
  });

  final String previousSourceId;
  final String previousDetailUrl;
  final bool shouldMigrateImmediately;
  final bool requiresContainsCheck;

  bool get hasPreviousIdentity =>
      previousSourceId.isNotEmpty && previousDetailUrl.isNotEmpty;
}

class ReaderSwitchSourceScopePlan {
  const ReaderSwitchSourceScopePlan({
    required this.sourceIds,
    required this.isMangaType,
  });

  final List<String> sourceIds;
  final bool isMangaType;
}

class ReaderSourceSwitchCoordinator {
  const ReaderSourceSwitchCoordinator();

  static final RegExp _chapterPattern = RegExp(r'第?\s*(\d{1,5})\s*章');
  static final RegExp _chapterEnglishPattern = RegExp(
    r'^(chapter|chap)\s*\d{1,5}\b',
  );

  bool isBookTitleUsable(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    return !_looksLikeChapterTitle(trimmed);
  }

  String? resolveKeywordFromKnownTitles({
    required String currentTitle,
    required List<String?> fallbackTitles,
  }) {
    final normalizedCurrent = currentTitle.trim();
    if (isBookTitleUsable(normalizedCurrent)) {
      return normalizedCurrent;
    }

    for (final candidate in fallbackTitles) {
      final normalized = (candidate ?? '').trim();
      if (!isBookTitleUsable(normalized)) {
        continue;
      }
      return normalized;
    }
    return null;
  }

  ReaderSwitchSourceRequestValidationResult validateManualSwitchRequest({
    required bool isSwitchSourceLoading,
    required bool canSwitchSource,
    required String? sourceId,
    required String? detailUrl,
  }) {
    if (isSwitchSourceLoading) {
      return const ReaderSwitchSourceRequestValidationResult.blocked(
        message: '',
      );
    }
    if (!canSwitchSource) {
      return const ReaderSwitchSourceRequestValidationResult.blocked(
        message: '当前书籍暂不支持换源。',
      );
    }

    final normalizedSourceId = (sourceId ?? '').trim();
    final normalizedDetailUrl = (detailUrl ?? '').trim();
    if (normalizedSourceId.isEmpty || normalizedDetailUrl.isEmpty) {
      return const ReaderSwitchSourceRequestValidationResult.blocked(
        message: '缺少当前书享源信息，暂时无法换源。',
      );
    }
    return ReaderSwitchSourceRequestValidationResult.ready(
      currentSourceId: normalizedSourceId,
      currentDetailUrl: normalizedDetailUrl,
    );
  }

  bool canAutoSwitchOnFailure({
    required bool canSwitchSource,
    required bool autoSwitchSourceOnFailureEnabled,
    required bool isAutoSwitchingSource,
    required bool isSwitchSourceLoading,
    required String? sourceId,
    required String? detailUrl,
  }) {
    if (!canSwitchSource || !autoSwitchSourceOnFailureEnabled) {
      return false;
    }
    if (isAutoSwitchingSource || isSwitchSourceLoading) {
      return false;
    }
    final normalizedSourceId = (sourceId ?? '').trim();
    final normalizedDetailUrl = (detailUrl ?? '').trim();
    return normalizedSourceId.isNotEmpty && normalizedDetailUrl.isNotEmpty;
  }

  List<SwitchSourceCandidate> prioritizeAutoSwitchCandidates(
    List<SwitchSourceCandidate> candidates, {
    required int tryLimit,
  }) {
    final upToDateCandidates = candidates
        .where((candidate) => !candidate.isPotentiallyOutdated)
        .toList(growable: false);
    final orderedCandidates =
        upToDateCandidates.isNotEmpty ? upToDateCandidates : candidates;
    return orderedCandidates.take(tryLimit).toList(growable: false);
  }

  ReaderSwitchSourceScopePlan buildSwitchSourceScope({
    required List<RegisteredSource> sources,
    required String currentSourceId,
    required bool fallbackIsMangaType,
  }) {
    RegisteredSource? currentSource;
    for (final source in sources) {
      if (source.runtime.id == currentSourceId) {
        currentSource = source;
        break;
      }
    }

    final isMangaType =
        inferRuntimeMangaSource(currentSource) ?? fallbackIsMangaType;
    final sourceIds = sources
        .where(
          (source) =>
              source.runtime.id != currentSourceId &&
              (inferRuntimeMangaSource(source) ?? false) == isMangaType,
        )
        .map((source) => source.runtime.id)
        .toList(growable: false);

    return ReaderSwitchSourceScopePlan(
      sourceIds: sourceIds,
      isMangaType: isMangaType,
    );
  }

  bool? inferRuntimeMangaSource(RegisteredSource? source) {
    if (source == null) {
      return null;
    }
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

  ReaderBookshelfMigrationCheckPlan planBookshelfMigrationCheck({
    required String? previousSourceId,
    required String? previousDetailUrl,
    required bool wasInBookshelf,
  }) {
    final normalizedSourceId = (previousSourceId ?? '').trim();
    final normalizedDetailUrl = (previousDetailUrl ?? '').trim();
    final hasIdentity =
        normalizedSourceId.isNotEmpty && normalizedDetailUrl.isNotEmpty;
    if (!hasIdentity) {
      return const ReaderBookshelfMigrationCheckPlan(
        previousSourceId: '',
        previousDetailUrl: '',
        shouldMigrateImmediately: false,
        requiresContainsCheck: false,
      );
    }

    return ReaderBookshelfMigrationCheckPlan(
      previousSourceId: normalizedSourceId,
      previousDetailUrl: normalizedDetailUrl,
      shouldMigrateImmediately: wasInBookshelf,
      requiresContainsCheck: !wasInBookshelf,
    );
  }

  bool resolveBookshelfMigration({
    required ReaderBookshelfMigrationCheckPlan plan,
    required bool containsResult,
  }) {
    if (!plan.hasPreviousIdentity) {
      return false;
    }
    if (plan.shouldMigrateImmediately) {
      return true;
    }
    if (plan.requiresContainsCheck) {
      return containsResult;
    }
    return false;
  }

  BookshelfBook buildReplacementBookshelfBook({
    required String currentBookId,
    required String nextSourceId,
    required String nextDetailUrl,
    required String nextBookTitle,
    required String fallbackBookTitle,
    required String? nextBookAuthor,
    required String? nextBookCoverUrl,
    required String? latestReadableChapterTitle,
    required String? fallbackLatestChapterTitle,
    required DateTime addedAt,
  }) {
    return BookshelfBook(
      bookId: currentBookId,
      sourceId: nextSourceId,
      title: nextBookTitle.trim().isEmpty ? fallbackBookTitle : nextBookTitle,
      detailUrl: nextDetailUrl,
      author: nextBookAuthor,
      coverUrl: nextBookCoverUrl,
      latestChapter: latestReadableChapterTitle ?? fallbackLatestChapterTitle,
      addedAt: addedAt,
    );
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
