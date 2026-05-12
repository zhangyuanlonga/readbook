import 'package:shuxiang_reading_next/domain/entities/book.dart';
import 'package:shuxiang_reading_next/domain/entities/source_health.dart';
import 'package:shuxiang_reading_next/features/reader/application/source_switch_score_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/switch_source_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('health snapshot lowers risky switch source candidate score', () {
    final books = <Book>[
      const Book(
        id: 'book_a',
        sourceId: 'healthy_source',
        title: '凡人修仙传',
        detailUrl: 'https://example.com/a',
        author: '忘语',
        latestChapter: '第100章',
      ),
      const Book(
        id: 'book_b',
        sourceId: 'risky_source',
        title: '凡人修仙传',
        detailUrl: 'https://example.com/b',
        author: '忘语',
        latestChapter: '第100章',
      ),
    ];

    final candidates = buildSwitchSourceCandidates(
      books: books,
      sourceNames: const <String, String>{
        'healthy_source': '健康源',
        'risky_source': '高风险源',
      },
      currentSourceId: 'current_source',
      currentChapterCount: 100,
      targetTitle: '凡人修仙传',
      targetAuthor: '忘语',
      hitCountBySource: const <String, int>{},
      scoreStore: SourceSwitchScoreStore(
        sourceScores: const <String, int>{},
        bookScores: const <String, int>{},
      ),
      sourceHealthBySourceId: <String, SourceHealthSnapshot>{
        'healthy_source': const SourceHealthSnapshot(
          sourceId: 'healthy_source',
          level: SourceHealthLevel.healthy,
          enabled: true,
        ),
        'risky_source': const SourceHealthSnapshot(
          sourceId: 'risky_source',
          level: SourceHealthLevel.risky,
          enabled: true,
        ),
      },
      scoreRankingEnabled: true,
      buildBookScoreKey:
          ({required String sourceId, required String title, String? author}) =>
              '$sourceId:$title:${author ?? ''}',
      lagTolerance: 20,
      hitCountCap: 12,
      hitCountWeight: 3,
      candidateLimit: 24,
    );

    expect(candidates.first.sourceName, '健康源');
    expect(candidates.last.sourceName, '高风险源');
    expect(candidates.first.healthLevel, SourceHealthLevel.healthy);
    expect(candidates.last.healthLevel, SourceHealthLevel.risky);
  });
}
