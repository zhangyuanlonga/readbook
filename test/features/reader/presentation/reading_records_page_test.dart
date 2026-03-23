import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_appread/data/datasources/local/app_database.dart';
import 'package:flutter_appread/domain/entities/reading_record.dart';
import 'package:flutter_appread/domain/entities/reading_record_day.dart';
import 'package:flutter_appread/domain/entities/reading_record_session.dart';
import 'package:flutter_appread/features/reader/application/reader_preferences_service.dart';
import 'package:flutter_appread/features/reader/application/reader_system_settings_service.dart';
import 'package:flutter_appread/features/reader/application/reading_record_service.dart';
import 'package:flutter_appread/features/reader/presentation/reading_records_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ReadingRecordsPage heatmap sheet', () {
    late ReadingRecordService readingRecordService;
    late ReaderPreferencesService preferencesService;
    late ReaderSystemSettingsService systemSettingsService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      readingRecordService = _FakeReadingRecordService();
      preferencesService = ReaderPreferencesService();
      systemSettingsService = ReaderSystemSettingsService();
    });

    testWidgets('keeps empty heatmap sheet wide on compact screens', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: ReadingRecordsPage(
            readingRecordService: readingRecordService,
            preferencesService: preferencesService,
            readerSystemSettingsService: systemSettingsService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('热力图'));
      await tester.pumpAndSettle();

      final emptyText = find.text('还没有可以展示的阅读热力图。');
      expect(emptyText, findsOneWidget);

      final card = find.ancestor(of: emptyText, matching: find.byType(Card));
      expect(card, findsOneWidget);
      expect(tester.getSize(card).width, greaterThan(300));
    });

    testWidgets('renders without layout exceptions on phone and tablet sizes', (
      tester,
    ) async {
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
          MaterialApp(
            home: ReadingRecordsPage(
              readingRecordService: readingRecordService,
              preferencesService: preferencesService,
              readerSystemSettingsService: systemSettingsService,
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
  _FakeReadingRecordService()
    : super(database: AppDatabase(executor: NativeDatabase.memory()));

  @override
  Stream<List<ReadingRecord>> watchLatestRecords({String query = ''}) {
    return Stream<List<ReadingRecord>>.value(const <ReadingRecord>[]);
  }

  @override
  Stream<List<ReadingRecordDay>> watchDailyRecords({String query = ''}) {
    return Stream<List<ReadingRecordDay>>.value(const <ReadingRecordDay>[]);
  }

  @override
  Stream<List<ReadingRecordSession>> watchSessions({String query = ''}) {
    return Stream<List<ReadingRecordSession>>.value(
      const <ReadingRecordSession>[],
    );
  }
}
