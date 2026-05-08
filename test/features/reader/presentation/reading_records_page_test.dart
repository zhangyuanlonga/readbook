import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/app/widgets/app_empty_state_card.dart';
import 'package:shuxiang_reading_next/domain/entities/book_metadata_override.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/domain/entities/local_chapter.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_book_status.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_record.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_record_day.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_record_session.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:shuxiang_reading_next/domain/repositories/book_metadata_override_repository.dart';
import 'package:shuxiang_reading_next/domain/repositories/local_book_repository.dart';
import 'package:shuxiang_reading_next/features/reader/application/reading_book_status_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_entry_route_resolver.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_preferences_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reading_stats_models.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_system_settings_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reading_record_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reading_records_page_dependencies_provider.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reading_records_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ReadingRecordsPage heatmap sheet', () {
    late ReadingRecordService readingRecordService;
    late ReaderPreferencesService preferencesService;
    late ReaderSystemSettingsService systemSettingsService;
    late ReadingBookStatusService readingBookStatusService;
    late ReadingRecordsPresentationService presentationService;
    late ReadingRecordOpenRouteService recordOpenRouteService;

    setUpAll(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    tearDownAll(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      readingRecordService = _FakeReadingRecordService();
      preferencesService = ReaderPreferencesService();
      systemSettingsService = ReaderSystemSettingsService();
      readingBookStatusService = _FakeReadingBookStatusService();
      presentationService = ReadingRecordsPresentationService(
        localBookRepository: _FakeLocalBookRepository(),
        bookMetadataOverrideRepository: _FakeBookMetadataOverrideRepository(),
      );
      recordOpenRouteService = ReadingRecordOpenRouteService(
        preferencesService: preferencesService,
        readerEntryRouteResolver: const ReaderEntryRouteResolver(),
      );
    });

    testWidgets('在小屏设备上保持空热力图面板足够宽', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ReadingRecordsPage(
              readingRecordService: readingRecordService,
              preferencesService: preferencesService,
              readerSystemSettingsService: systemSettingsService,
              readingBookStatusService: readingBookStatusService,
              recordOpenRouteService: recordOpenRouteService,
              presentationService: presentationService,
              initialPeriod: ReadingRecordsPeriod.all,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final emptyText = find.text('还没有可以展示的阅读热力图。');
      expect(emptyText, findsOneWidget);

      final emptyCard = find.byType(AppEmptyStateCard);
      expect(emptyCard, findsWidgets);
      expect(tester.getSize(emptyCard.first).width, greaterThan(300));
    });

    testWidgets('在手机和平板尺寸下渲染时不出现布局异常', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final item in const <_ViewportCase>[
        _ViewportCase(name: 'phone_360', size: Size(360, 800), dpr: 3.0),
        _ViewportCase(name: 'phone_412', size: Size(412, 915), dpr: 3.5),
        _ViewportCase(name: 'phone_480', size: Size(480, 1066), dpr: 3.0),
        _ViewportCase(name: 'phone_landscape', size: Size(640, 360), dpr: 3.0),
        _ViewportCase(name: 'tablet_840', size: Size(840, 1180), dpr: 2.0),
        _ViewportCase(name: 'large_1366', size: Size(1366, 1024), dpr: 2.0),
      ]) {
        tester.view.devicePixelRatio = item.dpr;
        await tester.binding.setSurfaceSize(item.size);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: ReadingRecordsPage(
                readingRecordService: readingRecordService,
                preferencesService: preferencesService,
                readerSystemSettingsService: systemSettingsService,
                readingBookStatusService: readingBookStatusService,
                recordOpenRouteService: recordOpenRouteService,
                presentationService: presentationService,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason:
              'unexpected exception at ${item.name} (${item.size.width}x${item.size.height}@${item.dpr})',
        );
      }
    });

    testWidgets('总览周期可作为初始周期稳定启动', (tester) async {
      final today = DateTime.now();
      final todayKey =
          '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      readingRecordService = _FakeReadingRecordService(
        dailyRecords: <ReadingRecordDay>[
          ReadingRecordDay(
            bookId: 'book_1',
            dateKey: todayKey,
            bookTitle: '测试书',
            readMillis: const Duration(minutes: 30).inMilliseconds,
            firstReadAt: today,
            lastReadAt: today.add(const Duration(minutes: 30)),
          ),
        ],
        sessions: <ReadingRecordSession>[
          ReadingRecordSession(
            id: 1,
            bookId: 'book_1',
            sourceId: 'source_1',
            detailUrl: 'https://example.com/book/1',
            bookTitle: '测试书',
            chapterTitle: '第一章',
            startAt: today,
            endAt: today.add(const Duration(minutes: 30)),
            durationMillis: const Duration(minutes: 30).inMilliseconds,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ReadingRecordsPage(
              readingRecordService: readingRecordService,
              preferencesService: preferencesService,
              readerSystemSettingsService: systemSettingsService,
              readingBookStatusService: readingBookStatusService,
              recordOpenRouteService: recordOpenRouteService,
              presentationService: presentationService,
              initialPeriod: ReadingRecordsPeriod.all,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('统计'), findsOneWidget);
      expect(find.text('当前周期内的阅读时长变化'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('月周期可作为初始周期稳定启动', (tester) async {
      final today = DateTime.now();
      final todayKey =
          '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      readingRecordService = _FakeReadingRecordService(
        dailyRecords: <ReadingRecordDay>[
          ReadingRecordDay(
            bookId: 'book_1',
            dateKey: todayKey,
            bookTitle: '测试书',
            readMillis: const Duration(minutes: 20).inMilliseconds,
            readChars: 1200,
            firstReadAt: today,
            lastReadAt: today.add(const Duration(minutes: 25)),
          ),
        ],
        sessions: <ReadingRecordSession>[
          ReadingRecordSession(
            id: 1,
            bookId: 'book_1',
            sourceId: 'source_1',
            detailUrl: 'https://example.com/book/1',
            bookTitle: '测试书',
            chapterTitle: '第一章',
            startAt: today,
            endAt: today.add(const Duration(minutes: 10)),
            durationMillis: const Duration(minutes: 10).inMilliseconds,
          ),
          ReadingRecordSession(
            id: 2,
            bookId: 'book_1',
            sourceId: 'source_1',
            detailUrl: 'https://example.com/book/1',
            bookTitle: '测试书',
            chapterTitle: '第二章',
            startAt: today.add(const Duration(minutes: 15)),
            endAt: today.add(const Duration(minutes: 25)),
            durationMillis: const Duration(minutes: 10).inMilliseconds,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ReadingRecordsPage(
              readingRecordService: readingRecordService,
              preferencesService: preferencesService,
              readerSystemSettingsService: systemSettingsService,
              readingBookStatusService: readingBookStatusService,
              recordOpenRouteService: recordOpenRouteService,
              presentationService: presentationService,
              initialPeriod: ReadingRecordsPeriod.month,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('统计'), findsOneWidget);
      expect(find.text('当前周期内的阅读时长变化'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _ViewportCase {
  const _ViewportCase({
    required this.name,
    required this.size,
    required this.dpr,
  });

  final String name;
  final Size size;
  final double dpr;
}

class _FakeReadingRecordService extends ReadingRecordService {
  _FakeReadingRecordService({
    this.dailyRecords = const <ReadingRecordDay>[],
    this.sessions = const <ReadingRecordSession>[],
  }) : super(database: AppDatabase(executor: NativeDatabase.memory()));

  final List<ReadingRecordDay> dailyRecords;
  final List<ReadingRecordSession> sessions;

  @override
  Stream<List<ReadingRecord>> watchLatestRecords({String query = ''}) {
    return Stream<List<ReadingRecord>>.value(const <ReadingRecord>[]);
  }

  @override
  Stream<List<ReadingRecordDay>> watchDailyRecords({String query = ''}) {
    return Stream<List<ReadingRecordDay>>.value(dailyRecords);
  }

  @override
  Stream<List<ReadingRecordSession>> watchSessions({String query = ''}) {
    return Stream<List<ReadingRecordSession>>.value(sessions);
  }
}

class _FakeReadingBookStatusService extends ReadingBookStatusService {
  _FakeReadingBookStatusService();

  @override
  Stream<List<ReadingBookStatusEntry>> watchManualStatuses() {
    return Stream<List<ReadingBookStatusEntry>>.value(
      const <ReadingBookStatusEntry>[],
    );
  }

  @override
  Stream<List<LocalBook>> watchLocalBooks() {
    return Stream<List<LocalBook>>.value(const <LocalBook>[]);
  }
}

class _FakeLocalBookRepository implements LocalBookRepository {
  @override
  Future<void> deleteBook(String bookId) => throw UnimplementedError();

  @override
  Future<List<LocalBook>> getAllBooks() async => const <LocalBook>[];

  @override
  Future<LocalBook?> getBookById(String bookId) async => null;

  @override
  Future<LocalBook?> getBookBySourcePath(String sourcePath) async => null;

  @override
  Future<LocalChapter?> getChapterById(String chapterId) =>
      throw UnimplementedError();

  @override
  Future<LocalChapter?> getChapterContentById(String chapterId) =>
      throw UnimplementedError();

  @override
  Future<LocalChapter?> getChapterByIndex(String bookId, int chapterIndex) =>
      throw UnimplementedError();

  @override
  Future<LocalChapter?> getChapterContentByIndex(
    String bookId,
    int chapterIndex,
  ) => throw UnimplementedError();

  @override
  Future<LocalChapter?> getChapterMetaByIndex(
    String bookId,
    int chapterIndex,
  ) => throw UnimplementedError();

  @override
  Future<List<LocalChapter>> getChapterMetas(String bookId) =>
      throw UnimplementedError();

  @override
  Future<List<LocalChapter>> getChapters(String bookId) =>
      throw UnimplementedError();

  @override
  Future<void> replaceChapters({
    required String bookId,
    required List<LocalChapter> chapters,
  }) => throw UnimplementedError();

  @override
  Future<void> updateBookIndexState({
    required String bookId,
    required LocalBookIndexStatus status,
    int? chapterCount,
    String? lastError,
    bool clearLastError = false,
  }) => throw UnimplementedError();

  @override
  Future<void> updateChapterContent({
    required String chapterId,
    required String content,
    List<String> imageUrls = const <String>[],
    ReaderDocument? document,
  }) => throw UnimplementedError();

  @override
  Future<void> upsertBook(LocalBook book) => throw UnimplementedError();

  @override
  Stream<List<LocalBook>> watchAllBooks() {
    return Stream<List<LocalBook>>.value(const <LocalBook>[]);
  }
}

class _FakeBookMetadataOverrideRepository
    implements BookMetadataOverrideRepository {
  @override
  Future<void> deleteByLocalBookId(String bookId) => throw UnimplementedError();

  @override
  Future<void> deleteByRemoteBook({
    required String sourceId,
    required String detailUrl,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteByTargetKey(String targetKey) =>
      throw UnimplementedError();

  @override
  Future<List<BookMetadataOverride>> getAll() async =>
      const <BookMetadataOverride>[];

  @override
  Future<BookMetadataOverride?> getByLocalBookId(String bookId) async => null;

  @override
  Future<BookMetadataOverride?> getByRemoteBook({
    required String sourceId,
    required String detailUrl,
  }) async => null;

  @override
  Future<BookMetadataOverride?> getByTargetKey(String targetKey) async => null;

  @override
  Future<void> upsert(BookMetadataOverride metadataOverride) =>
      throw UnimplementedError();

  @override
  Stream<List<BookMetadataOverride>> watchAll() {
    return Stream<List<BookMetadataOverride>>.value(
      const <BookMetadataOverride>[],
    );
  }
}
