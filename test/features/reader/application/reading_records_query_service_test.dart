import 'package:flutter_appread/domain/entities/reading_record.dart';
import 'package:flutter_appread/domain/entities/reading_record_day.dart';
import 'package:flutter_appread/domain/entities/reading_record_session.dart';
import 'package:flutter_appread/features/reader/application/reading_records_query_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReadingRecordsQueryService', () {
    const service = ReadingRecordsQueryService();

    test('builds filtered query view and summary for selected date', () {
      final latestRecords = <ReadingRecord>[
        ReadingRecord(
          bookId: 'book_1',
          sourceId: 'source_1',
          detailUrl: 'https://example.com/book/1',
          bookTitle: '测试书一',
          totalReadMillis: const Duration(minutes: 30).inMilliseconds,
          totalReadChars: 6000,
          lastReadAt: DateTime.parse('2026-04-04T10:30:00.000Z'),
        ),
        ReadingRecord(
          bookId: 'book_2',
          sourceId: 'source_1',
          detailUrl: 'https://example.com/book/2',
          bookTitle: '测试书二',
          totalReadMillis: const Duration(minutes: 10).inMilliseconds,
          totalReadChars: 1200,
          lastReadAt: DateTime.parse('2026-04-03T10:30:00.000Z'),
        ),
      ];
      final dailyRecords = <ReadingRecordDay>[
        ReadingRecordDay(
          bookId: 'book_1',
          dateKey: '2026-04-04',
          bookTitle: '测试书一',
          readMillis: const Duration(minutes: 30).inMilliseconds,
          readChars: 6000,
          firstReadAt: DateTime.parse('2026-04-04T10:00:00.000Z'),
          lastReadAt: DateTime.parse('2026-04-04T10:30:00.000Z'),
        ),
        ReadingRecordDay(
          bookId: 'book_2',
          dateKey: '2026-04-03',
          bookTitle: '测试书二',
          readMillis: const Duration(minutes: 10).inMilliseconds,
          readChars: 1200,
          firstReadAt: DateTime.parse('2026-04-03T10:20:00.000Z'),
          lastReadAt: DateTime.parse('2026-04-03T10:30:00.000Z'),
        ),
      ];
      final sessions = <ReadingRecordSession>[
        ReadingRecordSession(
          id: 1,
          bookId: 'book_1',
          sourceId: 'source_1',
          detailUrl: 'https://example.com/book/1',
          bookTitle: '测试书一',
          chapterTitle: '第一章',
          chapterIndex: 0,
          startAt: DateTime.parse('2026-04-04T10:00:00.000Z'),
          endAt: DateTime.parse('2026-04-04T10:30:00.000Z'),
          durationMillis: const Duration(minutes: 30).inMilliseconds,
          readChars: 6000,
        ),
      ];

      final view = service.buildQueryView(
        latestRecords: latestRecords,
        dailyRecords: dailyRecords,
        sessions: sessions,
        selectedDateKey: '2026-04-04',
        searchKeyword: '',
        viewLabel: '最近阅读',
      );

      expect(view.filteredLatestRecords, hasLength(1));
      expect(view.filteredLatestRecords.first.bookId, 'book_1');
      expect(view.filteredDailyRecords, hasLength(1));
      expect(view.filteredSessions, hasLength(1));
      expect(view.summary.title, '2026-04-04 阅读概览');
      expect(view.summary.totalBooks, 1);
      expect(
        view.summary.totalReadMillis,
        const Duration(minutes: 30).inMilliseconds,
      );
      expect(view.summary.totalReadChars, 6000);
      expect(view.summary.sessionCount, 1);
      expect(view.summary.chapterCount, 1);
      expect(view.summary.coverRecords, hasLength(1));
    });

    test('builds heatmap stats with work and session dimensions', () {
      final dailyRecords = <ReadingRecordDay>[
        ReadingRecordDay(
          bookId: 'book_1',
          dateKey: '2026-04-04',
          bookTitle: '测试书一',
          readMillis: const Duration(minutes: 30).inMilliseconds,
          firstReadAt: DateTime.parse('2026-04-04T10:00:00.000Z'),
          lastReadAt: DateTime.parse('2026-04-04T10:30:00.000Z'),
        ),
        ReadingRecordDay(
          bookId: 'book_2',
          dateKey: '2026-04-04',
          bookTitle: '测试书二',
          readMillis: const Duration(minutes: 15).inMilliseconds,
          firstReadAt: DateTime.parse('2026-04-04T20:00:00.000Z'),
          lastReadAt: DateTime.parse('2026-04-04T20:15:00.000Z'),
        ),
      ];
      final sessions = <ReadingRecordSession>[
        ReadingRecordSession(
          id: 1,
          bookId: 'book_1',
          sourceId: 'source_1',
          detailUrl: 'https://example.com/book/1',
          bookTitle: '测试书一',
          startAt: DateTime.parse('2026-04-04T10:00:00.000Z'),
          endAt: DateTime.parse('2026-04-04T10:10:00.000Z'),
          durationMillis: const Duration(minutes: 10).inMilliseconds,
        ),
        ReadingRecordSession(
          id: 2,
          bookId: 'book_1',
          sourceId: 'source_1',
          detailUrl: 'https://example.com/book/1',
          bookTitle: '测试书一',
          startAt: DateTime.parse('2026-04-04T10:15:00.000Z'),
          endAt: DateTime.parse('2026-04-04T10:25:00.000Z'),
          durationMillis: const Duration(minutes: 10).inMilliseconds,
        ),
      ];

      final stats = service.buildHeatmapStats(dailyRecords, sessions: sessions);
      final day = stats['2026-04-04'];

      expect(day, isNotNull);
      expect(day!.workCount, 2);
      expect(day.sessionCount, 2);
      expect(day.readMillis, const Duration(minutes: 45).inMilliseconds);
    });
  });
}
