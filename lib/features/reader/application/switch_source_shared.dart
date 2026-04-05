import 'dart:math';

import '../../../domain/entities/book.dart';
import '../../../domain/entities/source_health.dart';
import 'source_switch_score_service.dart';

typedef BuildBookScoreKey =
    String Function({
      required String sourceId,
      required String title,
      String? author,
    });

class SwitchSourceCandidate {
  const SwitchSourceCandidate({
    required this.book,
    required this.sourceName,
    required this.healthLevel,
    required this.baseScore,
    required this.hitCount,
    required this.sourceScore,
    required this.bookScore,
    required this.latestChapterLabel,
    required this.latestChapterNumber,
    required this.isPotentiallyOutdated,
    required this.score,
  });

  final Book book;
  final String sourceName;
  final SourceHealthLevel? healthLevel;
  final int baseScore;
  final int hitCount;
  final int sourceScore;
  final int bookScore;
  final String latestChapterLabel;
  final int? latestChapterNumber;
  final bool isPotentiallyOutdated;
  final int score;

  SwitchSourceCandidate copyWith({
    int? score,
    int? sourceScore,
    int? bookScore,
    SourceHealthLevel? healthLevel,
    bool keepHealthLevel = true,
  }) {
    return SwitchSourceCandidate(
      book: book,
      sourceName: sourceName,
      healthLevel:
          keepHealthLevel ? (healthLevel ?? this.healthLevel) : healthLevel,
      baseScore: baseScore,
      hitCount: hitCount,
      sourceScore: sourceScore ?? this.sourceScore,
      bookScore: bookScore ?? this.bookScore,
      latestChapterLabel: latestChapterLabel,
      latestChapterNumber: latestChapterNumber,
      isPotentiallyOutdated: isPotentiallyOutdated,
      score: score ?? this.score,
    );
  }
}

class SwitchSourceLookupState {
  const SwitchSourceLookupState({
    required this.isLoading,
    required this.sourceCount,
    required this.processedSourceCount,
    required this.candidates,
    required this.errorText,
    required this.scoreRankingEnabled,
  });

  const SwitchSourceLookupState.loading({
    required int sourceCount,
    required bool scoreRankingEnabled,
  }) : this(
         isLoading: true,
         sourceCount: sourceCount,
         processedSourceCount: 0,
         candidates: const <SwitchSourceCandidate>[],
         errorText: null,
         scoreRankingEnabled: scoreRankingEnabled,
       );

  final bool isLoading;
  final int sourceCount;
  final int processedSourceCount;
  final List<SwitchSourceCandidate> candidates;
  final String? errorText;
  final bool scoreRankingEnabled;

  SwitchSourceLookupState copyWith({
    bool? isLoading,
    int? sourceCount,
    int? processedSourceCount,
    List<SwitchSourceCandidate>? candidates,
    String? errorText,
    bool clearErrorText = false,
    bool? scoreRankingEnabled,
  }) {
    return SwitchSourceLookupState(
      isLoading: isLoading ?? this.isLoading,
      sourceCount: sourceCount ?? this.sourceCount,
      processedSourceCount: processedSourceCount ?? this.processedSourceCount,
      candidates: candidates ?? this.candidates,
      errorText: clearErrorText ? null : (errorText ?? this.errorText),
      scoreRankingEnabled: scoreRankingEnabled ?? this.scoreRankingEnabled,
    );
  }
}

enum SwitchSourceScoreAction { upvote, downvote, reset }

String normalizeSwitchSourceText(String text) {
  final spacePattern = RegExp(r'[\u3000\s]+');
  final symbolPattern = RegExp(r'''[·•\-_:：|/\\\(\)\[\]【】<>《》"'‘’,.，。!?！？]''');
  return text
      .trim()
      .toLowerCase()
      .replaceAll(spacePattern, '')
      .replaceAll(symbolPattern, '');
}

String formatSwitchSourceLatestChapter(String? latestChapter) {
  final spacePattern = RegExp(r'[\u3000\s]+');
  final normalized = latestChapter?.replaceAll(spacePattern, ' ');
  final text = normalized?.trim() ?? '';
  if (text.isEmpty) {
    return '未知';
  }
  return text;
}

int? extractSwitchSourceChapterNumber(String text) {
  final chapterPattern = RegExp(r'第?\s*(\d{1,5})\s*章');
  final numberPattern = RegExp(r'(\d{1,5})');
  final chapterMatch = chapterPattern.firstMatch(text);
  if (chapterMatch != null) {
    return int.tryParse(chapterMatch.group(1)!);
  }
  final numberMatch = numberPattern.firstMatch(text);
  if (numberMatch != null) {
    return int.tryParse(numberMatch.group(1)!);
  }
  return null;
}

bool isStrictSwitchSourceMatch(
  Book book, {
  required String normalizedTargetTitle,
  required String normalizedTargetAuthor,
}) {
  final normalizedTitle = normalizeSwitchSourceText(book.title);
  if (normalizedTargetTitle.isEmpty ||
      normalizedTitle != normalizedTargetTitle) {
    return false;
  }

  if (normalizedTargetAuthor.isEmpty) {
    return true;
  }

  final normalizedAuthor = normalizeSwitchSourceText(book.author ?? '');
  if (normalizedAuthor.isEmpty) {
    return false;
  }

  return normalizedAuthor == normalizedTargetAuthor;
}

int scoreSwitchSourceCandidate(
  Book book, {
  required String normalizedTargetTitle,
  required String normalizedTargetAuthor,
}) {
  final normalizedTitle = normalizeSwitchSourceText(book.title);
  var score = 0;

  if (normalizedTargetTitle.isEmpty) {
    score += 40;
  } else if (normalizedTitle == normalizedTargetTitle) {
    score += 140;
  } else if (normalizedTitle.startsWith(normalizedTargetTitle) ||
      normalizedTargetTitle.startsWith(normalizedTitle)) {
    score += 110;
  } else if (normalizedTitle.contains(normalizedTargetTitle) ||
      normalizedTargetTitle.contains(normalizedTitle)) {
    score += 85;
  } else {
    score += 50;
  }

  final normalizedAuthor = normalizeSwitchSourceText(book.author ?? '');
  if (normalizedTargetAuthor.isNotEmpty && normalizedAuthor.isNotEmpty) {
    if (normalizedAuthor == normalizedTargetAuthor) {
      score += 24;
    } else if (normalizedAuthor.contains(normalizedTargetAuthor) ||
        normalizedTargetAuthor.contains(normalizedAuthor)) {
      score += 12;
    }
  }

  if (book.latestChapter?.trim().isNotEmpty == true) {
    score += 2;
  }

  return score;
}

int resolveSwitchSourceHitBonus(
  int hitCount, {
  required int hitCountCap,
  required int hitCountWeight,
}) {
  final normalizedCount = max(0, hitCount);
  final capped = min(hitCountCap, normalizedCount);
  return capped * hitCountWeight;
}

int composeSwitchSourceCandidateScore({
  required int baseScore,
  required int hitCount,
  required int sourceScore,
  required int bookScore,
  required int healthScore,
  required bool scoreRankingEnabled,
  required int hitCountCap,
  required int hitCountWeight,
}) {
  final hitBonus = resolveSwitchSourceHitBonus(
    hitCount,
    hitCountCap: hitCountCap,
    hitCountWeight: hitCountWeight,
  );
  if (!scoreRankingEnabled) {
    return baseScore + hitBonus + healthScore;
  }
  return baseScore + hitBonus + sourceScore + bookScore + healthScore;
}

List<SwitchSourceCandidate> sortSwitchSourceCandidates(
  List<SwitchSourceCandidate> candidates,
) {
  candidates.sort((a, b) {
    final scoreDiff = b.score.compareTo(a.score);
    if (scoreDiff != 0) {
      return scoreDiff;
    }
    final latestDiff = (b.latestChapterNumber ?? -1).compareTo(
      a.latestChapterNumber ?? -1,
    );
    if (latestDiff != 0) {
      return latestDiff;
    }
    return a.sourceName.compareTo(b.sourceName);
  });
  return candidates;
}

List<SwitchSourceCandidate> buildSwitchSourceCandidates({
  required List<Book> books,
  required Map<String, String> sourceNames,
  required String currentSourceId,
  required int currentChapterCount,
  required String targetTitle,
  required String? targetAuthor,
  required Map<String, int> hitCountBySource,
  required SourceSwitchScoreStore scoreStore,
  Map<String, SourceHealthSnapshot> sourceHealthBySourceId =
      const <String, SourceHealthSnapshot>{},
  required bool scoreRankingEnabled,
  required BuildBookScoreKey buildBookScoreKey,
  required int lagTolerance,
  required int hitCountCap,
  required int hitCountWeight,
  required int candidateLimit,
}) {
  final normalizedTargetTitle = normalizeSwitchSourceText(targetTitle);
  final normalizedTargetAuthor = normalizeSwitchSourceText(targetAuthor ?? '');
  final bestBySource = <String, SwitchSourceCandidate>{};

  for (final book in books) {
    if (book.sourceId == currentSourceId) {
      continue;
    }
    if (!isStrictSwitchSourceMatch(
      book,
      normalizedTargetTitle: normalizedTargetTitle,
      normalizedTargetAuthor: normalizedTargetAuthor,
    )) {
      continue;
    }

    final baseScore = scoreSwitchSourceCandidate(
      book,
      normalizedTargetTitle: normalizedTargetTitle,
      normalizedTargetAuthor: normalizedTargetAuthor,
    );
    final hitCount = hitCountBySource[book.sourceId] ?? 0;
    final sourceScore = scoreStore.sourceScores[book.sourceId] ?? 0;
    final bookScore =
        scoreStore.bookScores[buildBookScoreKey(
          sourceId: book.sourceId,
          title: book.title,
          author: book.author,
        )] ??
        0;
    final healthScore = _switchSourceHealthScore(
      sourceHealthBySourceId[book.sourceId],
    );
    final score = composeSwitchSourceCandidateScore(
      baseScore: baseScore,
      hitCount: hitCount,
      sourceScore: sourceScore,
      bookScore: bookScore,
      healthScore: healthScore,
      scoreRankingEnabled: scoreRankingEnabled,
      hitCountCap: hitCountCap,
      hitCountWeight: hitCountWeight,
    );
    final latestChapterLabel = formatSwitchSourceLatestChapter(
      book.latestChapter,
    );
    final latestChapterNumber = extractSwitchSourceChapterNumber(
      latestChapterLabel,
    );
    final isPotentiallyOutdated =
        currentChapterCount > 0 &&
        latestChapterNumber != null &&
        latestChapterNumber + lagTolerance < currentChapterCount;

    final candidate = SwitchSourceCandidate(
      book: book,
      sourceName: sourceNames[book.sourceId] ?? book.sourceId,
      healthLevel: sourceHealthBySourceId[book.sourceId]?.level,
      baseScore: baseScore,
      hitCount: hitCount,
      sourceScore: sourceScore,
      bookScore: bookScore,
      latestChapterLabel: latestChapterLabel,
      latestChapterNumber: latestChapterNumber,
      isPotentiallyOutdated: isPotentiallyOutdated,
      score: score,
    );

    final existing = bestBySource[book.sourceId];
    if (existing == null || candidate.score > existing.score) {
      bestBySource[book.sourceId] = candidate;
    }
  }

  final candidates = sortSwitchSourceCandidates(
    bestBySource.values.toList(growable: false),
  );
  if (candidates.length <= candidateLimit) {
    return candidates;
  }
  return candidates.take(candidateLimit).toList(growable: false);
}

SwitchSourceCandidate rebuildSwitchSourceCandidateScore(
  SwitchSourceCandidate candidate, {
  required SourceSwitchScoreStore scoreStore,
  Map<String, SourceHealthSnapshot> sourceHealthBySourceId =
      const <String, SourceHealthSnapshot>{},
  required bool scoreRankingEnabled,
  required BuildBookScoreKey buildBookScoreKey,
  required int hitCountCap,
  required int hitCountWeight,
}) {
  final sourceScore = scoreStore.sourceScores[candidate.book.sourceId] ?? 0;
  final bookScore =
      scoreStore.bookScores[buildBookScoreKey(
        sourceId: candidate.book.sourceId,
        title: candidate.book.title,
        author: candidate.book.author,
      )] ??
      0;
  final healthScore = _switchSourceHealthScore(
    sourceHealthBySourceId[candidate.book.sourceId],
  );
  return candidate.copyWith(
    healthLevel: sourceHealthBySourceId[candidate.book.sourceId]?.level,
    sourceScore: sourceScore,
    bookScore: bookScore,
    score: composeSwitchSourceCandidateScore(
      baseScore: candidate.baseScore,
      hitCount: candidate.hitCount,
      sourceScore: sourceScore,
      bookScore: bookScore,
      healthScore: healthScore,
      scoreRankingEnabled: scoreRankingEnabled,
      hitCountCap: hitCountCap,
      hitCountWeight: hitCountWeight,
    ),
  );
}

int _switchSourceHealthScore(SourceHealthSnapshot? snapshot) {
  if (snapshot == null) {
    return 0;
  }
  return switch (snapshot.level) {
    SourceHealthLevel.healthy => 18,
    SourceHealthLevel.warning => 4,
    SourceHealthLevel.risky => -18,
    SourceHealthLevel.unavailable => -60,
  };
}
