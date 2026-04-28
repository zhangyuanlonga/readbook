import 'dart:async';

import '../../../domain/entities/book_metadata_override.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/reading_book_status.dart';
import '../../../domain/entities/reading_record.dart';
import '../../../domain/entities/reading_record_day.dart';
import '../../../domain/entities/reading_record_session.dart';
import 'reading_book_status_service.dart';
import 'reading_records_query_service.dart';
import 'reading_records_stats_presenter.dart';

class ReadingRecordsPageState {
  const ReadingRecordsPageState({
    required this.latestRecords,
    required this.dailyRecords,
    required this.sessions,
    required this.localBooks,
    required this.metadataOverrides,
    required this.manualStatuses,
    required this.localBooksById,
    required this.metadataOverridesByTargetKey,
    required this.resolvedStatusesByBookId,
    required this.queryView,
    required this.visibleSections,
  });

  final List<ReadingRecord> latestRecords;
  final List<ReadingRecordDay> dailyRecords;
  final List<ReadingRecordSession> sessions;
  final List<LocalBook> localBooks;
  final List<BookMetadataOverride> metadataOverrides;
  final List<ReadingBookStatusEntry> manualStatuses;
  final Map<String, LocalBook> localBooksById;
  final Map<String, BookMetadataOverride> metadataOverridesByTargetKey;
  final Map<String, ReadingBookResolvedStatus> resolvedStatusesByBookId;
  final ReadingRecordsQueryView queryView;
  final ReadingRecordsSectionVisibility visibleSections;
}

class ReadingRecordsPageStateService {
  const ReadingRecordsPageStateService({
    required ReadingRecordsQueryService queryService,
    required ReadingBookStatusService readingBookStatusService,
    ReadingRecordsStatsPresenter statsPresenter =
        const ReadingRecordsStatsPresenter(),
  }) : _queryService = queryService,
       _readingBookStatusService = readingBookStatusService,
       _statsPresenter = statsPresenter;

  final ReadingRecordsQueryService _queryService;
  final ReadingBookStatusService _readingBookStatusService;
  final ReadingRecordsStatsPresenter _statsPresenter;

  Stream<ReadingRecordsPageState> watchPageState({
    required Stream<List<ReadingRecord>> latestRecordsStream,
    required Stream<List<ReadingRecordDay>> dailyRecordsStream,
    required Stream<List<ReadingRecordSession>> sessionsStream,
    required Stream<List<LocalBook>> localBooksStream,
    required Stream<List<BookMetadataOverride>> metadataOverridesStream,
    required Stream<List<ReadingBookStatusEntry>> manualStatusesStream,
    required ReadingRecordsPeriod period,
    required DateTime anchor,
  }) {
    return Stream<ReadingRecordsPageState>.multi((controller) {
      var hasLatest = false;
      var hasDaily = false;
      var hasSessions = false;
      var hasLocalBooks = false;
      var hasOverrides = false;
      var hasStatuses = false;

      var latestRecords = const <ReadingRecord>[];
      var dailyRecords = const <ReadingRecordDay>[];
      var sessions = const <ReadingRecordSession>[];
      var localBooks = const <LocalBook>[];
      var metadataOverrides = const <BookMetadataOverride>[];
      var manualStatuses = const <ReadingBookStatusEntry>[];

      void emitIfReady() {
        if (!hasLatest ||
            !hasDaily ||
            !hasSessions ||
            !hasLocalBooks ||
            !hasOverrides ||
            !hasStatuses) {
          return;
        }

        final localBooksById = <String, LocalBook>{
          for (final book in localBooks) book.id.trim(): book,
        };
        final metadataOverridesByTargetKey = <String, BookMetadataOverride>{
          for (final item in metadataOverrides) item.targetKey: item,
        };
        final resolvedStatusesByBookId = _readingBookStatusService
            .resolveStatuses(
              latestRecords: latestRecords,
              localBooks: localBooks,
              manualStatuses: manualStatuses,
            );
        final queryView = _queryService.buildQueryView(
          latestRecords: latestRecords,
          dailyRecords: dailyRecords,
          sessions: sessions,
          period: period,
          anchor: anchor,
          resolvedStatusesByBookId: resolvedStatusesByBookId,
        );

        controller.add(
          ReadingRecordsPageState(
            latestRecords: latestRecords,
            dailyRecords: dailyRecords,
            sessions: sessions,
            localBooks: localBooks,
            metadataOverrides: metadataOverrides,
            manualStatuses: manualStatuses,
            localBooksById: localBooksById,
            metadataOverridesByTargetKey: metadataOverridesByTargetKey,
            resolvedStatusesByBookId: resolvedStatusesByBookId,
            queryView: queryView,
            visibleSections: _statsPresenter.resolveVisibleSections(period),
          ),
        );
      }

      final subscriptions = <StreamSubscription<dynamic>>[
        latestRecordsStream.listen((value) {
          latestRecords = List<ReadingRecord>.unmodifiable(value);
          hasLatest = true;
          emitIfReady();
        }, onError: controller.addError),
        dailyRecordsStream.listen((value) {
          dailyRecords = List<ReadingRecordDay>.unmodifiable(value);
          hasDaily = true;
          emitIfReady();
        }, onError: controller.addError),
        sessionsStream.listen((value) {
          sessions = List<ReadingRecordSession>.unmodifiable(value);
          hasSessions = true;
          emitIfReady();
        }, onError: controller.addError),
        localBooksStream.listen((value) {
          localBooks = List<LocalBook>.unmodifiable(value);
          hasLocalBooks = true;
          emitIfReady();
        }, onError: controller.addError),
        metadataOverridesStream.listen((value) {
          metadataOverrides = List<BookMetadataOverride>.unmodifiable(value);
          hasOverrides = true;
          emitIfReady();
        }, onError: controller.addError),
        manualStatusesStream.listen((value) {
          manualStatuses = List<ReadingBookStatusEntry>.unmodifiable(value);
          hasStatuses = true;
          emitIfReady();
        }, onError: controller.addError),
      ];

      controller.onCancel = () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      };
    });
  }
}
