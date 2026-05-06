import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shuxiang_reading_next/domain/entities/reading_record.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_record_day.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/bookshelf_page.dart';
import 'package:shuxiang_reading_next/features/home/application/home_engagement_service.dart';
import 'package:shuxiang_reading_next/features/home/presentation/home_page.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/mine_page.dart';
import 'package:shuxiang_reading_next/features/reader/application/reading_record_service.dart';
import 'package:shuxiang_reading_next/features/search/presentation/search_page.dart';
import '../../test_utils/adaptive_test_harness.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('BookshelfPage renders on phone and large screens', (
    tester,
  ) async {
    await runAdaptivePageSmokeMatrix(
      tester,
      pageBuilder: () => const BookshelfPage(prefetchAnnouncementOnInit: false),
      useProviderScope: true,
      pageName: 'BookshelfPage',
    );
  });

  testWidgets('MinePage renders on phone and large screens', (tester) async {
    await runAdaptivePageSmokeMatrix(
      tester,
      pageBuilder: () => const MinePage(),
      useProviderScope: true,
      pageName: 'MinePage',
    );
  });

  testWidgets('HomePage renders on phone and large screens', (tester) async {
    await runAdaptivePageSmokeMatrix(
      tester,
      pageBuilder:
          () => HomePage(
            readingRecordService: _FakeReadingRecordService(),
            engagementService: _FakeHomeEngagementService(),
          ),
      useProviderScope: true,
      pageName: 'HomePage',
    );
  });

  testWidgets('SearchPage renders on phone and large screens', (tester) async {
    await runAdaptivePageSmokeMatrix(
      tester,
      pageBuilder: () => const SearchPage(),
      useProviderScope: true,
      pageName: 'SearchPage',
    );
  });
}

class _FakeReadingRecordService extends ReadingRecordService {
  static final DateTime _now = DateTime.parse('2026-05-06T08:00:00.000Z');

  @override
  Stream<List<ReadingRecord>> watchLatestRecords({String query = ''}) {
    return Stream<List<ReadingRecord>>.value(<ReadingRecord>[
      ReadingRecord(
        bookId: 'book_1',
        sourceId: 'source_1',
        detailUrl: 'https://example.com/books/1',
        bookTitle: '测试书籍',
        bookAuthor: '测试作者',
        coverUrl: 'https://example.com/cover.jpg',
        totalReadMillis: 20 * 60 * 1000,
        lastReadAt: _now,
      ),
    ]);
  }

  @override
  Stream<List<ReadingRecordDay>> watchDailyRecords({String query = ''}) {
    return Stream<List<ReadingRecordDay>>.value(<ReadingRecordDay>[
      ReadingRecordDay(
        bookId: 'book_1',
        dateKey: '2026-05-06',
        bookTitle: '测试书籍',
        bookAuthor: '测试作者',
        coverUrl: 'https://example.com/cover.jpg',
        readMillis: 20 * 60 * 1000,
        firstReadAt: _now.subtract(const Duration(minutes: 20)),
        lastReadAt: _now,
      ),
    ]);
  }
}

class _FakeHomeEngagementService extends HomeEngagementService {
  @override
  Future<HomeEngagementState> loadState() async {
    return const HomeEngagementState(
      dailyGoalMinutes: 15,
      checkInDateKeys: <String>['2026-05-05'],
    );
  }

  @override
  Future<HomeEngagementState> checkInToday({DateTime? now}) async {
    return const HomeEngagementState(
      dailyGoalMinutes: 15,
      checkInDateKeys: <String>['2026-05-05', '2026-05-06'],
    );
  }
}
