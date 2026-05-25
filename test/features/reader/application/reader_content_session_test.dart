import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/chapter.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_session.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_logical_position.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_session_state.dart';

void main() {
  group('ReaderContentSession', () {
    const baseSession = ReaderContentSession(
      contentMode: ReaderContentMode.text,
      bookId: 'book_1',
      sourceId: 'source_1',
      detailUrl: 'https://example.com/detail/1',
      bookTitle: '测试书籍',
      bookAuthor: '作者',
      bookCoverUrl: 'https://example.com/cover.jpg',
      chapterId: 'chapter_1',
      chapterUrl: 'https://example.com/chapter/1',
      chapterTitle: '第一章',
      chapterIndex: 0,
      resolvedContentType: 'text',
      hybridSubMode: ReaderHybridSubMode.pdf,
      sourceFilePath: '/tmp/book.pdf',
      totalPageCount: 10,
      audioUrl: 'https://cdn.example/chapter-1.mp3',
      audioManifestUrl: 'https://cdn.example/chapter-1.m3u8',
      chapters: <Chapter>[
        Chapter(
          id: 'chapter_1',
          bookId: 'book_1',
          title: '第一章',
          chapterUrl: 'https://example.com/chapter/1',
          index: 0,
        ),
      ],
      sessionState: ReaderSessionState(
        currentChapterIndex: 0,
        currentChapterId: 'chapter_1',
        currentChapterUrl: 'https://example.com/chapter/1',
        currentChapterTitle: '第一章',
        logicalPosition: ReaderLogicalPosition(
          chapterIndex: 0,
          blockIndex: 1,
          offsetInBlock: 5,
          chapterPositionRatio: 0.3,
        ),
        visiblePosition: ReaderVisiblePosition(pageIndex: 0, pageCount: 3),
        viewportSession: ReaderViewportSession(
          viewportMode: 'textPaged',
          pageIndex: 0,
          pageCount: 3,
        ),
        rendererKind: TextReaderRendererKind.paged,
        isAutoReading: false,
        isChapterTransitioning: false,
      ),
    );

    test('copyWith preserves existing values when omitted', () {
      final updated = baseSession.copyWith(bookTitle: '新的标题');

      expect(updated.bookTitle, '新的标题');
      expect(updated.sourceId, baseSession.sourceId);
      expect(updated.chapterId, baseSession.chapterId);
      expect(updated.audioUrl, baseSession.audioUrl);
      expect(updated.hybridSubMode, baseSession.hybridSubMode);
      expect(updated.sourceFilePath, baseSession.sourceFilePath);
      expect(updated.sessionState, same(baseSession.sessionState));
    });

    test('copyWith supports clearing optional values', () {
      final updated = baseSession.copyWith(
        bookAuthor: null,
        chapterTitle: null,
        audioUrl: null,
        audioManifestUrl: null,
        sessionState: null,
      );

      expect(updated.bookAuthor, isNull);
      expect(updated.chapterTitle, isNull);
      expect(updated.audioUrl, isNull);
      expect(updated.audioManifestUrl, isNull);
      expect(updated.sessionState, isNull);
    });
  });
}
