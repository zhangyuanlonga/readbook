import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/composition/app_providers.dart' as app_providers;
import '../../../domain/entities/book_identity.dart';
import '../../../domain/entities/book_metadata_override.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/entities/reading_record.dart';
import '../../../domain/repositories/book_metadata_override_repository.dart';
import '../../../domain/repositories/local_book_repository.dart';
import '../../book/application/book_metadata_presentation_resolver.dart';
import 'reading_book_status_service.dart';
import 'reader_entry_route_resolver.dart';
import 'reader_preferences_service.dart';
import 'reading_record_service.dart';
import 'reading_records_query_service.dart';
import 'reading_records_page_state_service.dart';
import 'reading_records_stats_presenter.dart';
import 'reading_stats_work_identity_service.dart';
import 'local/local_reader_entry_guard_service.dart';
import 'local/local_reader_identity.dart';
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
        localReaderEntryGuardService: LocalReaderEntryGuardService(
          localBookRepository: ref.watch(
            app_providers.localBookRepositoryProvider,
          ),
        ),
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
    LocalReaderEntryGuardService? localReaderEntryGuardService,
  }) : _preferencesService = preferencesService,
       _readerEntryRouteResolver = readerEntryRouteResolver,
       _localReaderEntryGuardService = localReaderEntryGuardService;

  final ReaderPreferencesService _preferencesService;
  final ReaderEntryRouteResolver _readerEntryRouteResolver;
  final LocalReaderEntryGuardService? _localReaderEntryGuardService;

  Future<ReadingRecordOpenRouteResolution> resolveRoute(
    ReadingRecord record,
  ) async {
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

    final localGuard = await _guardLocalEntry(record, progress);
    if (localGuard != null) {
      return localGuard;
    }

    if (chapterId.isNotEmpty && chapterUrl.isNotEmpty) {
      return ReadingRecordOpenRouteResolution.open(
        _readerEntryRouteResolver.buildChapterRoute(
          bookId: record.bookId,
          chapterId: chapterId,
          chapterUrl: chapterUrl,
          chapterTitle: chapterTitle,
          sourceId: record.sourceId,
          detailUrl: record.detailUrl,
          chapterIndex: chapterIndex,
        ),
      );
    }

    return ReadingRecordOpenRouteResolution.open(
      _readerEntryRouteResolver.buildChapterRoute(
        bookId: record.bookId,
        chapterId: chapterId.isNotEmpty ? chapterId : 'bootstrap',
        chapterUrl: chapterUrl.isNotEmpty ? chapterUrl : null,
        chapterTitle: chapterTitle,
        sourceId: record.sourceId,
        detailUrl: record.detailUrl,
        chapterIndex: chapterIndex,
        openRouteKind: 'reading_record_fallback',
      ),
    );
  }

  Future<ReadingRecordOpenRouteResolution?> _guardLocalEntry(
    ReadingRecord record,
    ReadingProgress? progress,
  ) async {
    final guardService = _localReaderEntryGuardService;
    if (guardService == null ||
        !LocalReaderIdentity.isLocalSourceId(record.sourceId)) {
      return null;
    }
    final guardResult =
        progress != null &&
                progress.sourceId.trim() == record.sourceId.trim() &&
                progress.detailUrl.trim() == record.detailUrl.trim()
            ? await guardService.guardProgress(progress)
            : await guardService.guardRecord(record);
    return _toResolution(guardResult);
  }

  ReadingRecordOpenRouteResolution _toResolution(
    LocalReaderEntryGuardResult result,
  ) {
    return switch (result.action) {
      LocalReaderEntryGuardAction.openReader ||
      LocalReaderEntryGuardAction
          .openDetail => ReadingRecordOpenRouteResolution.open(
        result.route!,
        message: result.message,
      ),
      LocalReaderEntryGuardAction.unavailable =>
        ReadingRecordOpenRouteResolution.unavailable(
          result.message ?? '本地图书暂不可用。',
        ),
    };
  }
}

class ReadingRecordOpenRouteResolution {
  const ReadingRecordOpenRouteResolution._({
    required this.route,
    required this.unavailable,
    this.message,
  });

  const ReadingRecordOpenRouteResolution.open(String route, {String? message})
    : this._(route: route, unavailable: false, message: message);

  const ReadingRecordOpenRouteResolution.unavailable(String message)
    : this._(route: null, unavailable: true, message: message);

  final String? route;
  final bool unavailable;
  final String? message;
}

class ReadingRecordsPresentationService {
  ReadingRecordsPresentationService({
    required LocalBookRepository localBookRepository,
    required BookMetadataOverrideRepository bookMetadataOverrideRepository,
    BookDisplayStateResolver resolver = const BookDisplayStateResolver(),
  }) : _localBookRepository = localBookRepository,
       _bookMetadataOverrideRepository = bookMetadataOverrideRepository,
       _resolver = resolver;

  final LocalBookRepository _localBookRepository;
  final BookMetadataOverrideRepository _bookMetadataOverrideRepository;
  final BookDisplayStateResolver _resolver;

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
        isLocalBookSourceId(normalizedSourceId)
            ? localBooksById[normalizedBookId]
            : null;
    final overrideKey =
        isLocalBookSourceId(normalizedSourceId)
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
        isLocalBookSourceId(normalizedSourceId)
            ? localBooksById[normalizedBookId]
            : null;
    final overrideKey =
        isLocalBookSourceId(normalizedSourceId)
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
