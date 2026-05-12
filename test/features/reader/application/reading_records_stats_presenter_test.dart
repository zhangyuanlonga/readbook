import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_record_day.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_record_session.dart';
import 'package:shuxiang_reading_next/features/reader/application/reading_records_stats_presenter.dart';

void main() {
  group('ReadingRecordsStatsPresenter', () {
    const presenter = ReadingRecordsStatsPresenter();

    test('groups session details by end date for cross-day sessions', () {
      final startAt = DateTime(2026, 4, 4, 23, 50);
      final endAt = DateTime(2026, 4, 5, 0, 20);
      final details = presenter.buildCalendarDetailsByDate(
        allowedDateKeys: const {'2026-04-04', '2026-04-05'},
        dailyRecords: <ReadingRecordDay>[
          ReadingRecordDay(
            bookId: 'book_1',
            dateKey: '2026-04-05',
            bookTitle: '测试书一',
            readMillis: const Duration(minutes: 30).inMilliseconds,
            readChars: 3200,
            firstReadAt: startAt,
            lastReadAt: endAt,
          ),
        ],
        sessions: <ReadingRecordSession>[
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
        ],
      );

      expect(details['2026-04-04']?.sessionCount, 0);
      expect(details['2026-04-04']?.books, isEmpty);
      expect(details['2026-04-05']?.sessionCount, 1);
      expect(details['2026-04-05']?.workCount, 1);
      expect(details['2026-04-05']?.books.single.title, '测试书一');
    });
  });
}
