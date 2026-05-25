import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/chapter.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_progress.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_session.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_session_resolver.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_logical_position.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_reading_record_coordinator.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_session_state.dart';

void main() {
  group('ReaderContentSessionResolver', () {
    const resolver = ReaderContentSessionResolver();
    const chapter = Chapter(
      id: 'chapter_1',
      bookId: 'book_1',
      title: '第一章',
      chapterUrl: 'https://example.com/chapter/1',
      index: 0,
    );
    const sessionState = ReaderSessionState(
      currentChapterIndex: 0,
      currentChapterId: 'chapter_1',
      currentChapterUrl: 'https://example.com/chapter/1',
      currentChapterTitle: '第一章',
      logicalPosition: ReaderLogicalPosition(
        chapterIndex: 0,
        blockIndex: 0,
        offsetInBlock: 6,
        chapterPositionRatio: 0.24,
      ),
      visiblePosition: ReaderVisiblePosition(
        scrollOffset: 120,
        maxScrollExtent: 800,
      ),
      viewportSession: ReaderViewportSession(
        viewportMode: 'textScroll',
        scrollOffset: 120,
        maxScrollExtent: 800,
      ),
      rendererKind: TextReaderRendererKind.scroll,
      isAutoReading: true,
      isChapterTransitioning: false,
    );
    final bootstrapProgress = ReadingProgress(
      bookId: 'book_1',
      sourceId: 'source_1',
      detailUrl: 'https://example.com/detail/1',
      chapterId: 'chapter_1',
      chapterUrl: 'https://example.com/chapter/1',
      chapterTitle: '第一章',
      chapterIndex: 0,
      updatedAt: DateTime(2026, 4, 7),
      positionSnapshot: const ReaderPositionSnapshot(
        viewportMode: 'textScroll',
      ),
    );
    final readingRecordSession = ReaderReadingRecordSession(
      bookId: 'book_1',
      sourceId: 'source_1',
      detailUrl: 'https://example.com/detail/1',
      bookTitle: '测试书籍',
      chapterId: 'chapter_1',
      chapterUrl: 'https://example.com/chapter/1',
      startAt: DateTime(2026, 4, 7),
      startPositionRatio: 0.1,
      furthestPositionRatio: 0.3,
    );

    test('returns null when required identity is incomplete', () {
      final missingBook = resolver.resolve(
        contentMode: ReaderContentMode.text,
        bookId: ' ',
        sourceId: 'source_1',
        detailUrl: 'https://example.com/detail/1',
        bookTitle: '测试书籍',
        bookAuthor: null,
        bookCoverUrl: null,
        chapterId: 'chapter_1',
        chapterUrl: 'https://example.com/chapter/1',
        chapterTitle: '第一章',
        chapterIndex: 0,
        resolvedContentType: null,
        hybridSubMode: null,
        sourceFilePath: null,
        totalPageCount: null,
        audioUrl: null,
        audioManifestUrl: null,
        audioHeaders: const <String, String>{},
        chapters: const <Chapter>[chapter],
        sessionState: sessionState,
        bootstrapProgress: bootstrapProgress,
        readingRecordSession: readingRecordSession,
      );

      final missingSource = resolver.resolve(
        contentMode: ReaderContentMode.text,
        bookId: 'book_1',
        sourceId: null,
        detailUrl: 'https://example.com/detail/1',
        bookTitle: '测试书籍',
        bookAuthor: null,
        bookCoverUrl: null,
        chapterId: 'chapter_1',
        chapterUrl: 'https://example.com/chapter/1',
        chapterTitle: '第一章',
        chapterIndex: 0,
        resolvedContentType: null,
        hybridSubMode: null,
        sourceFilePath: null,
        totalPageCount: null,
        audioUrl: null,
        audioManifestUrl: null,
        audioHeaders: const <String, String>{},
        chapters: const <Chapter>[chapter],
        sessionState: sessionState,
        bootstrapProgress: bootstrapProgress,
        readingRecordSession: readingRecordSession,
      );

      expect(missingBook, isNull);
      expect(missingSource, isNull);
    });

    test('builds normalized content session snapshot', () {
      final session = resolver.resolve(
        contentMode: ReaderContentMode.text,
        bookId: ' book_1 ',
        sourceId: ' source_1 ',
        detailUrl: ' https://example.com/detail/1 ',
        bookTitle: ' 测试书籍 ',
        bookAuthor: ' 作者 ',
        bookCoverUrl: ' https://example.com/cover.jpg ',
        chapterId: ' chapter_1 ',
        chapterUrl: ' https://example.com/chapter/1 ',
        chapterTitle: ' 第一章 ',
        chapterIndex: 0,
        resolvedContentType: ' audio ',
        hybridSubMode: ReaderHybridSubMode.pdf,
        sourceFilePath: ' /tmp/book.pdf ',
        totalPageCount: 12,
        audioUrl: ' https://cdn.example/chapter-1.mp3 ',
        audioManifestUrl: ' https://cdn.example/chapter-1.m3u8 ',
        audioHeaders: const <String, String>{'Referer': 'https://example.com'},
        chapters: const <Chapter>[chapter],
        sessionState: sessionState,
        bootstrapProgress: bootstrapProgress,
        readingRecordSession: readingRecordSession,
      );

      expect(session, isNotNull);
      expect(session!.contentMode, ReaderContentMode.text);
      expect(session.bookId, 'book_1');
      expect(session.sourceId, 'source_1');
      expect(session.detailUrl, 'https://example.com/detail/1');
      expect(session.bookTitle, '测试书籍');
      expect(session.bookAuthor, '作者');
      expect(session.chapterId, 'chapter_1');
      expect(session.chapterUrl, 'https://example.com/chapter/1');
      expect(session.chapterTitle, '第一章');
      expect(session.resolvedContentType, 'audio');
      expect(session.hybridSubMode, ReaderHybridSubMode.pdf);
      expect(session.sourceFilePath, '/tmp/book.pdf');
      expect(session.totalPageCount, 12);
      expect(session.audioUrl, 'https://cdn.example/chapter-1.mp3');
      expect(session.audioManifestUrl, 'https://cdn.example/chapter-1.m3u8');
      expect(session.audioHeaders, const <String, String>{
        'Referer': 'https://example.com',
      });
      expect(session.chapters, hasLength(1));
      expect(session.bootstrapProgress, same(bootstrapProgress));
      expect(session.readingRecordSession, same(readingRecordSession));
      expect(session.sessionState, same(sessionState));
    });
  });
}
