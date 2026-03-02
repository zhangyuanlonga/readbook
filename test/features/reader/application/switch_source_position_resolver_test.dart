import 'package:flutter_appread/domain/entities/chapter.dart';
import 'package:flutter_appread/features/reader/application/switch_source_position_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SwitchSourcePositionResolver', () {
    const resolver = SwitchSourcePositionResolver();

    Chapter chapter(int index, String title) {
      return Chapter(
        id: 'c$index',
        bookId: 'book_1',
        title: title,
        chapterUrl: 'https://example.com/$index',
        index: index,
      );
    }

    List<Chapter> buildChapters(int count, {String prefix = '第'}) {
      return List<Chapter>.generate(
        count,
        (index) => chapter(index, '$prefix${index + 1}章'),
        growable: false,
      );
    }

    test('keeps mapped chapter position when title matches', () {
      final currentChapters = buildChapters(120);
      final targetChapters = <Chapter>[
        ...buildChapters(54),
        chapter(54, '第55章 天外来客'),
        ...buildChapters(30, prefix: '后续'),
      ];

      final decision = resolver.resolve(
        currentChapters: currentChapters,
        targetChapters: targetChapters,
        previousChapterTitle: '第55章 天外来客',
        previousChapterIndex: 54,
        lagTolerance: 20,
      );

      expect(decision.targetIndex, 54);
      expect(decision.currentReadingChapterNo, 55);
      expect(decision.targetChapterCount, targetChapters.length);
      expect(decision.isBehindCurrentReading, isFalse);
    });

    test('falls back by index and flags behind when target is shorter', () {
      final decision = resolver.resolve(
        currentChapters: buildChapters(120),
        targetChapters: buildChapters(50),
        previousChapterTitle: '第88章 不存在',
        previousChapterIndex: 80,
        lagTolerance: 20,
      );

      expect(decision.targetIndex, 49);
      expect(decision.currentReadingChapterNo, 81);
      expect(decision.targetChapterCount, 50);
      expect(decision.isBehindCurrentReading, isTrue);
      expect(decision.isSignificantlyBehind, isTrue);
    });

    test(
      'flags significant lag when target count falls behind current source',
      () {
        final decision = resolver.resolve(
          currentChapters: buildChapters(200),
          targetChapters: buildChapters(150),
          previousChapterTitle: '第20章',
          previousChapterIndex: 19,
          lagTolerance: 20,
        );

        expect(decision.isBehindCurrentReading, isFalse);
        expect(decision.isSignificantlyBehind, isTrue);
      },
    );
  });
}
