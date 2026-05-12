import 'package:shuxiang_reading_next/domain/entities/reading_record.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_record_day.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_record_session.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_book_status.dart';
import 'package:shuxiang_reading_next/features/reader/application/reading_records_query_service.dart';
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
        period: ReadingRecordsPeriod.day,
        anchor: DateTime.parse('2026-04-04T00:00:00.000Z'),
        resolvedStatusesByBookId: const <String, ReadingBookResolvedStatus>{},
      );

      expect(view.filteredLatestRecords, hasLength(1));
      expect(view.filteredLatestRecords.first.bookId, 'book_1');
      expect(view.summary.title, '阅读总览');
      expect(view.summary.totalBooks, 1);
      expect(view.summary.readingBookCount, 1);
      expect(view.summary.completedBookCount, 0);
      expect(
        view.summary.totalReadMillis,
        const Duration(minutes: 30).inMilliseconds,
      );
      expect(view.summary.totalReadChars, 6000);
      expect(view.summary.chapterCount, 1);
      expect(view.summary.coverRecords, hasLength(1));
      expect(view.distribution.buckets, hasLength(24));
      expect(view.distributionCalendar.months, hasLength(3));
      expect(view.distributionCalendar.months[1].monthLabel, '2026年04月');
      expect(view.rankings, hasLength(1));
      expect(view.rankings.first.record.bookId, 'book_1');
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

    test('groups cross-day session counts by end date in calendar stats', () {
      final startAt = DateTime(2026, 4, 4, 23, 50);
      final endAt = DateTime(2026, 4, 5, 0, 20);
      final latestRecords = <ReadingRecord>[
        ReadingRecord(
          bookId: 'book_1',
          sourceId: 'source_1',
          detailUrl: 'https://example.com/book/1',
          bookTitle: '测试书一',
          totalReadMillis: const Duration(minutes: 30).inMilliseconds,
          totalReadChars: 3200,
          lastReadAt: endAt,
        ),
      ];
      final dailyRecords = <ReadingRecordDay>[
        ReadingRecordDay(
          bookId: 'book_1',
          dateKey: '2026-04-05',
          bookTitle: '测试书一',
          readMillis: const Duration(minutes: 30).inMilliseconds,
          readChars: 3200,
          firstReadAt: startAt,
          lastReadAt: endAt,
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
          startAt: startAt,
          endAt: endAt,
          durationMillis: const Duration(minutes: 30).inMilliseconds,
          readChars: 3200,
        ),
      ];

      final view = service.buildQueryView(
        latestRecords: latestRecords,
        dailyRecords: dailyRecords,
        sessions: sessions,
        period: ReadingRecordsPeriod.month,
        anchor: DateTime.parse('2026-04-05T00:00:00.000Z'),
        resolvedStatusesByBookId: const <String, ReadingBookResolvedStatus>{},
      );

      final calendarMonth = view.distributionCalendar.months[1];
      final targetDay = calendarMonth.weeks
          .expand((week) => week.days)
          .firstWhere((day) => day.dateKey == '2026-04-05');
      expect(targetDay.readMillis, const Duration(minutes: 30).inMilliseconds);

      final heatmap = service.buildHeatmapStats(
        dailyRecords,
        sessions: sessions,
      );
      expect(heatmap['2026-04-05']?.sessionCount, 1);
    });

    test('splits day distribution across crossed hours', () {
      final startAt = DateTime(2026, 4, 4, 9, 50);
      final endAt = DateTime(2026, 4, 4, 11, 20);
      final latestRecords = <ReadingRecord>[
        ReadingRecord(
          bookId: 'book_1',
          sourceId: 'source_1',
          detailUrl: 'https://example.com/book/1',
          bookTitle: '测试书一',
          totalReadMillis: const Duration(minutes: 80).inMilliseconds,
          totalReadChars: 4000,
          lastReadAt: endAt,
        ),
      ];
      final dailyRecords = <ReadingRecordDay>[
        ReadingRecordDay(
          bookId: 'book_1',
          dateKey: '2026-04-04',
          bookTitle: '测试书一',
          readMillis: const Duration(minutes: 80).inMilliseconds,
          readChars: 4000,
          firstReadAt: startAt,
          lastReadAt: endAt,
        ),
      ];
      final sessions = <ReadingRecordSession>[
        ReadingRecordSession(
          id: 1,
          bookId: 'book_1',
          sourceId: 'source_1',
          detailUrl: 'https://example.com/book/1',
          bookTitle: '测试书一',
          startAt: startAt,
          endAt: endAt,
          durationMillis: const Duration(minutes: 90).inMilliseconds,
          readChars: 4000,
        ),
      ];

      final view = service.buildQueryView(
        latestRecords: latestRecords,
        dailyRecords: dailyRecords,
        sessions: sessions,
        period: ReadingRecordsPeriod.day,
        anchor: DateTime.parse('2026-04-04T00:00:00.000Z'),
        resolvedStatusesByBookId: const <String, ReadingBookResolvedStatus>{},
      );

      expect(
        view.distribution.buckets[9].readMillis,
        const Duration(minutes: 10).inMilliseconds,
      );
      expect(
        view.distribution.buckets[10].readMillis,
        const Duration(hours: 1).inMilliseconds,
      );
      expect(
        view.distribution.buckets[11].readMillis,
        const Duration(minutes: 20).inMilliseconds,
      );
    });

    test('dedupes same work re-imported under different book ids', () {
      final latestRecords = <ReadingRecord>[
        ReadingRecord(
          bookId: 'book_a_1',
          sourceId: 'source_1',
          detailUrl: 'https://example.com/book/a-1',
          bookTitle: '作品 A',
          bookAuthor: '作者甲',
          totalReadMillis: const Duration(minutes: 20).inMilliseconds,
          totalReadChars: 2400,
          lastReadAt: DateTime.parse('2026-04-04T10:30:00.000Z'),
        ),
        ReadingRecord(
          bookId: 'book_a_2',
          sourceId: 'source_1',
          detailUrl: 'https://example.com/book/a-2',
          bookTitle: '作品 A',
          bookAuthor: '作者甲',
          totalReadMillis: const Duration(minutes: 10).inMilliseconds,
          totalReadChars: 800,
          lastReadAt: DateTime.parse('2026-04-05T10:30:00.000Z'),
        ),
      ];
      final dailyRecords = <ReadingRecordDay>[
        ReadingRecordDay(
          bookId: 'book_a_1',
          dateKey: '2026-04-04',
          bookTitle: '作品 A',
          bookAuthor: '作者甲',
          readMillis: const Duration(minutes: 20).inMilliseconds,
          readChars: 2400,
          firstReadAt: DateTime.parse('2026-04-04T10:00:00.000Z'),
          lastReadAt: DateTime.parse('2026-04-04T10:20:00.000Z'),
        ),
        ReadingRecordDay(
          bookId: 'book_a_2',
          dateKey: '2026-04-05',
          bookTitle: '作品 A',
          bookAuthor: '作者甲',
          readMillis: const Duration(minutes: 10).inMilliseconds,
          readChars: 800,
          firstReadAt: DateTime.parse('2026-04-05T10:00:00.000Z'),
          lastReadAt: DateTime.parse('2026-04-05T10:10:00.000Z'),
        ),
      ];

      final view = service.buildQueryView(
        latestRecords: latestRecords,
        dailyRecords: dailyRecords,
        sessions: const <ReadingRecordSession>[],
        period: ReadingRecordsPeriod.all,
        anchor: DateTime.parse('2026-04-05T00:00:00.000Z'),
        resolvedStatusesByBookId: const <String, ReadingBookResolvedStatus>{},
      );
      final heatmap = service.buildHeatmapStats(
        dailyRecords,
        sessions: const <ReadingRecordSession>[],
      );

      expect(view.summary.totalBooks, 1);
      expect(view.summary.coverRecords, hasLength(1));
      expect(view.rankings, hasLength(1));
      expect(
        view.rankings.first.readMillis,
        const Duration(minutes: 30).inMilliseconds,
      );
      expect(heatmap['2026-04-04']!.workCount, 1);
      expect(heatmap['2026-04-05']!.workCount, 1);
    });
  });
}
