import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_runtime_facade.dart';

void main() {
  group('ReaderRuntimeFacade', () {
    const facade = ReaderRuntimeFacade();

    test('resolves immediate progress save when no previous save exists', () {
      final decision = facade.resolveProgressSaveDecision(
        lastSavedAt: null,
        now: DateTime(2026, 6, 6, 9),
      );

      expect(decision.flushImmediately, isTrue);
      expect(decision.debounce, Duration.zero);
    });

    test('debounces progress save inside wake policy cadence', () {
      final now = DateTime(2026, 6, 6, 9, 0, 10);
      final decision = facade.resolveProgressSaveDecision(
        lastSavedAt: DateTime(2026, 6, 6, 9),
        now: now,
      );

      expect(decision.flushImmediately, isFalse);
      expect(decision.debounce > Duration.zero, isTrue);
    });

    test('starts and syncs reading record session', () {
      final result = facade.startOrUpdateReadingRecordSession(
        readingRecordEnabled: true,
        isBootstrapping: false,
        isLoadingContent: false,
        hasError: false,
        hasVisibleReaderContent: true,
        sourceId: 'source-a',
        detailUrl: 'detail://a',
        bookTitle: '示例书',
        currentBookId: 'book-a',
        chapterId: 'chapter-1',
        chapterUrl: 'chapter://1',
        chapterTitle: '第一章',
        chapterIndex: 0,
        bookAuthor: '作者',
        coverUrl: 'cover://a',
        initialRatio: 0.25,
        now: DateTime(2026, 6, 6, 9),
        existingSession: null,
      );

      expect(result.session, isNotNull);
      expect(result.scheduleAutoCommitTimer, isTrue);

      final synced = facade.syncReadingRecordSessionProgress(
        session: result.session,
        ratio: 0.6,
      );
      expect(synced?.furthestPositionRatio, 0.6);
      expect(
        facade.autoCommitInterval(session: synced) > Duration.zero,
        isTrue,
      );
    });

    test('skips progress sync and auto commit when session is absent', () {
      expect(
        facade.syncReadingRecordSessionProgress(session: null, ratio: 0.7),
        isNull,
      );
      expect(facade.autoCommitInterval(session: null), Duration.zero);
    });
  });
}
