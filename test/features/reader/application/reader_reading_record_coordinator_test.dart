import 'package:flutter_appread/features/reader/application/reader_reading_record_coordinator.dart';
import 'package:flutter_appread/features/reader/application/reading_record_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReaderReadingRecordCoordinator', () {
    const coordinator = ReaderReadingRecordCoordinator();

    test('canTrackSession requires enabled and valid reader context', () {
      final valid = coordinator.canTrackSession(
        readingRecordEnabled: true,
        isBootstrapping: false,
        isLoadingContent: false,
        hasError: false,
        hasVisibleReaderContent: true,
        sourceId: 'source_a',
        detailUrl: 'https://example.com/detail',
        bookTitle: '书名',
      );
      final invalidByError = coordinator.canTrackSession(
        readingRecordEnabled: true,
        isBootstrapping: false,
        isLoadingContent: false,
        hasError: true,
        hasVisibleReaderContent: true,
        sourceId: 'source_a',
        detailUrl: 'https://example.com/detail',
        bookTitle: '书名',
      );
      final invalidByIdentity = coordinator.canTrackSession(
        readingRecordEnabled: true,
        isBootstrapping: false,
        isLoadingContent: false,
        hasError: false,
        hasVisibleReaderContent: true,
        sourceId: ' ',
        detailUrl: '',
        bookTitle: ' ',
      );

      expect(valid, isTrue);
      expect(invalidByError, isFalse);
      expect(invalidByIdentity, isFalse);
    });

    test(
      'startOrUpdateSession cancels timer when session cannot be tracked',
      () {
        final result = coordinator.startOrUpdateSession(
          readingRecordEnabled: false,
          isBootstrapping: false,
          isLoadingContent: false,
          hasError: false,
          hasVisibleReaderContent: true,
          sourceId: 'source_a',
          detailUrl: 'https://example.com/detail',
          bookTitle: '书名',
          currentBookId: 'book_1',
          chapterId: 'chapter_1',
          chapterUrl: 'https://example.com/chapter/1',
          chapterTitle: '第一章',
          chapterIndex: 0,
          bookAuthor: '作者',
          coverUrl: null,
          initialRatio: 0.2,
          now: DateTime(2026, 4, 2, 10),
        );

        expect(result.session, isNull);
        expect(result.cancelAutoCommitTimer, isTrue);
        expect(result.scheduleAutoCommitTimer, isFalse);
      },
    );

    test('startOrUpdateSession creates new session and clamps ratio', () {
      final now = DateTime(2026, 4, 2, 10);
      final result = coordinator.startOrUpdateSession(
        readingRecordEnabled: true,
        isBootstrapping: false,
        isLoadingContent: false,
        hasError: false,
        hasVisibleReaderContent: true,
        sourceId: ' source_a ',
        detailUrl: ' https://example.com/detail ',
        bookTitle: ' 书名 ',
        currentBookId: 'book_1',
        chapterId: ' chapter_1 ',
        chapterUrl: ' https://example.com/chapter/1 ',
        chapterTitle: ' 第一章 ',
        chapterIndex: 0,
        bookAuthor: ' 作者 ',
        coverUrl: ' https://example.com/cover.png ',
        initialRatio: 1.4,
        now: now,
      );

      final session = result.session;
      expect(session, isNotNull);
      expect(session!.sourceId, 'source_a');
      expect(session.detailUrl, 'https://example.com/detail');
      expect(session.bookTitle, '书名');
      expect(session.chapterId, 'chapter_1');
      expect(session.chapterUrl, 'https://example.com/chapter/1');
      expect(session.startAt, now);
      expect(session.startPositionRatio, 1.0);
      expect(session.furthestPositionRatio, 1.0);
      expect(result.scheduleAutoCommitTimer, isTrue);
    });

    test('startOrUpdateSession reuses existing session in same chapter', () {
      final existing = ReaderReadingRecordSession(
        bookId: 'book_1',
        sourceId: 'source_a',
        detailUrl: 'https://example.com/detail',
        bookTitle: '书名',
        chapterId: 'chapter_1',
        chapterUrl: 'https://example.com/chapter/1',
        startAt: DateTime(2026, 4, 2, 10),
        startPositionRatio: 0.2,
        furthestPositionRatio: 0.3,
      );
      final result = coordinator.startOrUpdateSession(
        readingRecordEnabled: true,
        isBootstrapping: false,
        isLoadingContent: false,
        hasError: false,
        hasVisibleReaderContent: true,
        sourceId: 'source_a',
        detailUrl: 'https://example.com/detail',
        bookTitle: '书名',
        currentBookId: 'book_1',
        chapterId: 'chapter_1',
        chapterUrl: 'https://example.com/chapter/1',
        chapterTitle: '第一章',
        chapterIndex: 0,
        bookAuthor: null,
        coverUrl: null,
        initialRatio: 0.6,
        now: DateTime(2026, 4, 2, 11),
        existingSession: existing,
      );

      expect(result.session, isNotNull);
      expect(result.session!.startAt, existing.startAt);
      expect(result.session!.furthestPositionRatio, 0.6);
      expect(result.scheduleAutoCommitTimer, isTrue);
    });

    test('buildCommitInput maps session and metrics correctly', () {
      final session = ReaderReadingRecordSession(
        bookId: 'book_1',
        sourceId: 'source_a',
        detailUrl: 'https://example.com/detail',
        bookTitle: '书名',
        chapterId: 'chapter_1',
        chapterTitle: '第一章',
        chapterIndex: 0,
        chapterUrl: 'https://example.com/chapter/1',
        startAt: DateTime(2026, 4, 2, 10),
        startPositionRatio: 0.2,
        furthestPositionRatio: 0.8,
      );
      final input = coordinator.buildCommitInput(
        readingRecordEnabled: true,
        session: session,
        endAt: DateTime(2026, 4, 2, 10, 30),
        endRatio: 0.6,
        chapterLength: 1000,
        isMangaChapter: false,
      );

      expect(input, isNotNull);
      expect(input!.bookId, session.bookId);
      expect(input.chapterUrl, session.chapterUrl);
      expect(input.startPositionRatio, 0.2);
      expect(input.endPositionRatio, 0.6);
      expect(
        input.readChars,
        estimateSessionReadChars(
          chapterLength: 1000,
          startRatio: 0.2,
          endRatio: 0.6,
          furthestRatio: 0.8,
          countAsText: true,
        ),
      );
    });
  });
}
