import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/composition/app_providers.dart' as app_providers;
import '../../../domain/entities/book_metadata_override.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/reading_record.dart';
import '../../../domain/repositories/book_metadata_override_repository.dart';
import '../../../domain/repositories/local_book_repository.dart';
import '../../book/application/book_display_state.dart';
import '../../book/application/book_metadata_presentation_resolver.dart';
import '../../book/presentation/book_detail_route.dart';
import 'local/local_reader_identity.dart';
import 'reading_book_status_service.dart';
import 'reader_entry_route_resolver.dart';
import 'reader_preferences_service.dart';
import 'reading_record_service.dart';
import 'reading_records_query_service.dart';
import 'reading_records_page_state_service.dart';
import 'reading_records_stats_presenter.dart';
import 'reading_stats_work_identity_service.dart';
import 'reader_system_settings_service.dart';

class ReadingRecordsPageDependencies {
  const ReadingRecordsPageDependencies({
    required this.readingRecordService,
    required this.readingRecordsQueryService,
    required this.readerSystemSettingsService,
    required this.readingBookStatusService,
    required this.recordOpenRouteService,
    required this.presentationService,
    required this.workIdentityService,
    required this.pageStateService,
    required this.statsPresenter,
  });

  final ReadingRecordService readingRecordService;
  final ReadingRecordsQueryService readingRecordsQueryService;
  final ReaderSystemSettingsService readerSystemSettingsService;
  final ReadingBookStatusService readingBookStatusService;
  final ReadingRecordOpenRouteService recordOpenRouteService;
  final ReadingRecordsPresentationService presentationService;
  final ReadingStatsWorkIdentityService workIdentityService;
  final ReadingRecordsPageStateService pageStateService;
  final ReadingRecordsStatsPresenter statsPresenter;
}

final readingRecordsReadingRecordServiceProvider =
    Provider<ReadingRecordService>((ref) {
      return ReadingRecordService(
        database: ref.watch(app_providers.appDatabaseProvider),
      );
    });

final readingRecordsReaderPreferencesServiceProvider =
    Provider<ReaderPreferencesService>((ref) {
      return ReaderPreferencesService();
    });

final readingRecordsReaderSystemSettingsServiceProvider =
    Provider<ReaderSystemSettingsService>((ref) {
      return ReaderSystemSettingsService();
    });

final readingRecordsReadingBookStatusServiceProvider =
    Provider<ReadingBookStatusService>((ref) {
      return ReadingBookStatusService(
        database: ref.watch(app_providers.appDatabaseProvider),
      );
    });

final readingRecordsQueryServiceProvider = Provider<ReadingRecordsQueryService>(
  (ref) {
    return const ReadingRecordsQueryService();
  },
);

final readingRecordsRecordOpenRouteServiceProvider =
    Provider<ReadingRecordOpenRouteService>((ref) {
      return ReadingRecordOpenRouteService(
        preferencesService: ref.watch(
          readingRecordsReaderPreferencesServiceProvider,
        ),
        readerEntryRouteResolver: const ReaderEntryRouteResolver(),
      );
    });

final readingRecordsPresentationServiceProvider =
    Provider<ReadingRecordsPresentationService>((ref) {
      return ReadingRecordsPresentationService(
        localBookRepository: ref.watch(
          app_providers.localBookRepositoryProvider,
        ),
        bookMetadataOverrideRepository: ref.watch(
          app_providers.bookMetadataOverrideRepositoryProvider,
        ),
      );
    });

final readingRecordsPageDependenciesProvider = Provider<
  ReadingRecordsPageDependencies
>((ref) {
  return ReadingRecordsPageDependencies(
    readingRecordService: ref.watch(readingRecordsReadingRecordServiceProvider),
    readingRecordsQueryService: ref.watch(readingRecordsQueryServiceProvider),
    readerSystemSettingsService: ref.watch(
      readingRecordsReaderSystemSettingsServiceProvider,
    ),
    readingBookStatusService: ref.watch(
      readingRecordsReadingBookStatusServiceProvider,
    ),
    recordOpenRouteService: ref.watch(
      readingRecordsRecordOpenRouteServiceProvider,
    ),
    presentationService: ref.watch(readingRecordsPresentationServiceProvider),
    workIdentityService: const ReadingStatsWorkIdentityService(),
    pageStateService: ref.watch(readingRecordsPageStateServiceProvider),
    statsPresenter: ref.watch(readingRecordsStatsPresenterProvider),
  );
});

final readingRecordsStatsPresenterProvider =
    Provider<ReadingRecordsStatsPresenter>((ref) {
      return const ReadingRecordsStatsPresenter();
    });

final readingRecordsPageStateServiceProvider =
    Provider<ReadingRecordsPageStateService>((ref) {
      return ReadingRecordsPageStateService(
        queryService: ref.watch(readingRecordsQueryServiceProvider),
        readingBookStatusService: ref.watch(
          readingRecordsReadingBookStatusServiceProvider,
        ),
        statsPresenter: ref.watch(readingRecordsStatsPresenterProvider),
      );
    });

class ReadingRecordOpenRouteService {
  const ReadingRecordOpenRouteService({
    required ReaderPreferencesService preferencesService,
    required ReaderEntryRouteResolver readerEntryRouteResolver,
  }) : _preferencesService = preferencesService,
       _readerEntryRouteResolver = readerEntryRouteResolver;

  final ReaderPreferencesService _preferencesService;
  final ReaderEntryRouteResolver _readerEntryRouteResolver;

  Future<String> resolveRoute(ReadingRecord record) async {
    final progress = await _preferencesService.loadProgress(record.bookId);
    final chapterId =
        progress?.chapterId.trim().isNotEmpty == true
            ? progress!.chapterId
            : (record.lastChapterId?.trim().isNotEmpty == true
                ? record.lastChapterId!
                : '');
    final chapterUrl =
        progress?.chapterUrl.trim().isNotEmpty == true
            ? progress!.chapterUrl
            : (record.lastChapterUrl?.trim().isNotEmpty == true
                ? record.lastChapterUrl!
                : '');
    final chapterTitle =
        progress?.chapterTitle.trim().isNotEmpty == true
            ? progress!.chapterTitle
            : (record.lastChapterTitle?.trim().isNotEmpty == true
                ? record.lastChapterTitle!
                : record.bookTitle);
    final chapterIndex = progress?.chapterIndex ?? record.lastChapterIndex;

    if (chapterId.isNotEmpty && chapterUrl.isNotEmpty) {
      return _readerEntryRouteResolver.buildChapterRoute(
        bookId: record.bookId,
        chapterId: chapterId,
        chapterUrl: chapterUrl,
        chapterTitle: chapterTitle,
        sourceId: record.sourceId,
        detailUrl: record.detailUrl,
        chapterIndex: chapterIndex,
      );
    }

    return buildBookDetailRoute(
      bookId: record.bookId,
      sourceId: record.sourceId,
      detailUrl: record.detailUrl,
      title: record.bookTitle,
      author: record.bookAuthor,
      coverUrl: record.coverUrl,
    );
  }
}

class ReadingRecordsPresentationService {
  ReadingRecordsPresentationService({
    required LocalBookRepository localBookRepository,
    required BookMetadataOverrideRepository bookMetadataOverrideRepository,
    BookMetadataPresentationResolver resolver =
        const BookMetadataPresentationResolver(),
  }) : _localBookRepository = localBookRepository,
       _bookMetadataOverrideRepository = bookMetadataOverrideRepository,
       _resolver = resolver;

  final LocalBookRepository _localBookRepository;
  final BookMetadataOverrideRepository _bookMetadataOverrideRepository;
  final BookMetadataPresentationResolver _resolver;

  Stream<List<LocalBook>> watchLocalBooks() {
    return _localBookRepository.watchAllBooks();
  }

  Stream<List<BookMetadataOverride>> watchMetadataOverrides() {
    return _bookMetadataOverrideRepository.watchAll();
  }

  BookDisplayState resolveRecordDisplayState({
    required ReadingRecord record,
    required Map<String, LocalBook> localBooksById,
    required Map<String, BookMetadataOverride> metadataOverridesByTargetKey,
  }) {
    final normalizedBookId = record.bookId.trim();
    final normalizedSourceId = record.sourceId.trim();
    final normalizedDetailUrl = record.detailUrl.trim();
    final localBook =
        normalizedSourceId == LocalReaderIdentity.localSourceId
            ? localBooksById[normalizedBookId]
            : null;
    final overrideKey =
        normalizedSourceId == LocalReaderIdentity.localSourceId
            ? BookMetadataOverride.localTargetKey(normalizedBookId)
            : BookMetadataOverride.remoteTargetKey(
              sourceId: normalizedSourceId,
              detailUrl: normalizedDetailUrl,
            );
    return _resolver.resolveReadingRecord(
      record: record,
      localBook: localBook,
      metadataOverride: metadataOverridesByTargetKey[overrideKey],
    );
  }

  BookDisplayState resolveSnapshotDisplayState({
    required String bookId,
    required String? sourceId,
    required String? detailUrl,
    required String? title,
    String? author,
    String? intro,
    String? coverUrl,
    required Map<String, LocalBook> localBooksById,
    required Map<String, BookMetadataOverride> metadataOverridesByTargetKey,
  }) {
    final normalizedBookId = bookId.trim();
    final normalizedSourceId = (sourceId ?? '').trim();
    final normalizedDetailUrl = (detailUrl ?? '').trim();
    final localBook =
        normalizedSourceId == LocalReaderIdentity.localSourceId
            ? localBooksById[normalizedBookId]
            : null;
    final overrideKey =
        normalizedSourceId == LocalReaderIdentity.localSourceId
            ? BookMetadataOverride.localTargetKey(normalizedBookId)
            : BookMetadataOverride.remoteTargetKey(
              sourceId: normalizedSourceId,
              detailUrl: normalizedDetailUrl,
            );
    return _resolver.resolve(
      fallbackTitle: title,
      fallbackAuthor: author,
      fallbackIntro: intro,
      realCoverUrl: coverUrl,
      localBook: localBook,
      metadataOverride: metadataOverridesByTargetKey[overrideKey],
    );
  }
}
