import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shuxiang_reading_next/core/auth/auth_session.dart';
import 'package:shuxiang_reading_next/core/auth/auth_session_store.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_record.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_record_day.dart';
import 'package:shuxiang_reading_next/features/mine/application/mine_page_session_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/bookshelf_page.dart';
import 'package:shuxiang_reading_next/features/home/application/home_engagement_service.dart';
import 'package:shuxiang_reading_next/features/home/presentation/home_page.dart';
import 'package:shuxiang_reading_next/features/mine/presentation/mine_page.dart';
import 'package:shuxiang_reading_next/features/mine/providers.dart';
import 'package:shuxiang_reading_next/features/reader/application/reading_record_service.dart';
import 'package:shuxiang_reading_next/features/search/presentation/search_page.dart';

import '../../test_utils/adaptive_test_harness.dart';
import '../../test_utils/fake_auth_session_secret_store.dart';

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

  testWidgets('MinePage uses desktop profile card on desktop platform', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.macOS),
          home: const MinePage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey<String>('mine_desktop_profile_card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('mine_mobile_profile_card')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'MinePage renders with secure auth session after startup priming',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth.user_id': 'user_smoke',
        'auth.username': 'reader_smoke',
        'auth.display_name': 'Reader Smoke',
      });
      final prefs = await SharedPreferences.getInstance();
      MinePageSessionPriming.prime(prefs);
      final sessionStore = AuthSessionStore(
        preferences: prefs,
        secretStore: FakeAuthSessionSecretStore(),
      );
      await sessionStore.saveSession(
        const AuthSession(
          accessToken: 'secure_token',
          refreshToken: 'secure_refresh',
          userId: 'user_smoke',
          username: 'reader_smoke',
          displayName: 'Reader Smoke',
        ),
      );

      await runAdaptivePageSmokeMatrix(
        tester,
        pageBuilder: () => const MinePage(),
        pageName: 'MinePageSecureSession',
        overrides: <Override>[
          mineAuthSessionStoreProvider.overrideWithValue(sessionStore),
        ],
        cases: const <AdaptiveViewportCase>[
          AdaptiveViewportCase(name: 'phone_390', size: Size(390, 844), dpr: 3),
          AdaptiveViewportCase(
            name: 'desktop_1280',
            size: Size(1280, 800),
            dpr: 1,
          ),
        ],
      );
    },
  );

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
