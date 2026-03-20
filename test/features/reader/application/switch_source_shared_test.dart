import 'package:flutter_appread/domain/entities/book.dart';
import 'package:flutter_appread/features/reader/application/source_switch_score_service.dart';
import 'package:flutter_appread/features/reader/application/switch_source_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildSwitchSourceCandidates', () {
    const buildBookScoreKey = _fakeBuildBookScoreKey;

    test(
      'keeps only exact title and exact author matches when author exists',
      () {
        final candidates = buildSwitchSourceCandidates(
          books: const [
            Book(
              id: 'b1',
              sourceId: 's1',
              title: '诛仙',
              detailUrl: 'https://a.example/book',
              author: '萧鼎',
              latestChapter: '第120章',
            ),
            Book(
              id: 'b2',
              sourceId: 's2',
              title: '诛仙',
              detailUrl: 'https://b.example/book',
              author: '其他作者',
              latestChapter: '第118章',
            ),
            Book(
              id: 'b3',
              sourceId: 's3',
              title: '诛仙2',
              detailUrl: 'https://c.example/book',
              author: '萧鼎',
              latestChapter: '第90章',
            ),
            Book(
              id: 'b4',
              sourceId: 's4',
              title: '诛仙',
              detailUrl: 'https://d.example/book',
              latestChapter: '第119章',
            ),
          ],
          sourceNames: const {'s1': '源一', 's2': '源二', 's3': '源三', 's4': '源四'},
          currentSourceId: 'current',
          currentChapterCount: 100,
          targetTitle: '诛仙',
          targetAuthor: '萧鼎',
          hitCountBySource: const <String, int>{},
          scoreStore: SourceSwitchScoreStore(
            sourceScores: <String, int>{},
            bookScores: <String, int>{},
          ),
          scoreRankingEnabled: true,
          buildBookScoreKey: buildBookScoreKey,
          lagTolerance: 20,
          hitCountCap: 12,
          hitCountWeight: 3,
          candidateLimit: 24,
        );

        expect(candidates, hasLength(1));
        expect(candidates.single.book.sourceId, 's1');
      },
    );

    test('allows exact title match when target author is missing', () {
      final candidates = buildSwitchSourceCandidates(
        books: const [
          Book(
            id: 'b1',
            sourceId: 's1',
            title: '庆余年',
            detailUrl: 'https://a.example/book',
            author: '猫腻',
          ),
          Book(
            id: 'b2',
            sourceId: 's2',
            title: '庆余年外传',
            detailUrl: 'https://b.example/book',
            author: '猫腻',
          ),
        ],
        sourceNames: const {'s1': '源一', 's2': '源二'},
        currentSourceId: 'current',
        currentChapterCount: 0,
        targetTitle: '庆余年',
        targetAuthor: null,
        hitCountBySource: const <String, int>{},
        scoreStore: SourceSwitchScoreStore(
          sourceScores: <String, int>{},
          bookScores: <String, int>{},
        ),
        scoreRankingEnabled: true,
        buildBookScoreKey: buildBookScoreKey,
        lagTolerance: 20,
        hitCountCap: 12,
        hitCountWeight: 3,
        candidateLimit: 24,
      );

      expect(candidates, hasLength(1));
      expect(candidates.single.book.sourceId, 's1');
    });
  });
}

String _fakeBuildBookScoreKey({
  required String sourceId,
  required String title,
  String? author,
}) {
  return '$sourceId|$title|${author ?? ''}';
}
