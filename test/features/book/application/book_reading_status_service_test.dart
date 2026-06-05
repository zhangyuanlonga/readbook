import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/domain/entities/chapter.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_progress.dart';
import 'package:shuxiang_reading_next/features/book/application/book_reading_status_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  late BookReadingStatusService service;

  setUp(() {
    service = BookReadingStatusService(
      readerPreferencesService: ReaderPreferencesService(),
    );
  });

  test('resolves reading status from stored progress', () {
    expect(service.resolveStatus(progress: null), BookReadingStatus.unread);

    expect(
      service.resolveStatus(
        progress: ReadingProgress(
          bookId: 'book_1',
          sourceId: 'source_1',
          detailUrl: 'https://example.com/book',
          chapterId: 'chapter_1',
          chapterUrl: 'https://example.com/chapter/1',
          chapterTitle: '第一章',
          chapterIndex: 0,
          updatedAt: DateTime(2026),
          chapterPositionRatio: 0.2,
        ),
      ),
      BookReadingStatus.reading,
    );

    expect(
      service.resolveStatus(
        progress: ReadingProgress(
          bookId: 'book_1',
          sourceId: 'source_1',
          detailUrl: 'https://example.com/book',
          chapterId: 'chapter_2',
          chapterUrl: 'https://example.com/chapter/2',
          chapterTitle: '第二章',
          chapterIndex: 1,
          updatedAt: DateTime(2026),
          chapterPositionRatio: 1,
        ),
      ),
      BookReadingStatus.finished,
    );
  });

  test('builds reading and finished progress from readable chapters', () async {
    final chapters = <Chapter>[
      const Chapter(
        id: 'volume_1',
        bookId: 'book_1',
        title: '第一卷',
        chapterUrl: '',
        index: 0,
        isVolume: true,
      ),
      const Chapter(
        id: 'chapter_1',
        bookId: 'book_1',
        title: '第一章',
        chapterUrl: 'https://example.com/chapter/1',
        index: 1,
      ),
      const Chapter(
        id: 'chapter_2',
        bookId: 'book_1',
        title: '第二章',
        chapterUrl: 'https://example.com/chapter/2',
        index: 2,
      ),
    ];

    final reading = await service.buildMarkedProgress(
      bookId: 'book_1',
      sourceId: 'source_1',
      detailUrl: 'https://example.com/book',
      status: BookReadingStatus.reading,
      chapters: chapters,
    );

    expect(reading?.progress.chapterId, 'chapter_1');
    expect(reading?.progress.chapterPositionRatio, 0.001);

    final finished = await service.buildMarkedProgress(
      bookId: 'book_1',
      sourceId: 'source_1',
      detailUrl: 'https://example.com/book',
      status: BookReadingStatus.finished,
      chapters: chapters,
    );

    expect(finished?.progress.chapterId, 'chapter_2');
    expect(finished?.progress.chapterPositionRatio, 1);
  });
}
