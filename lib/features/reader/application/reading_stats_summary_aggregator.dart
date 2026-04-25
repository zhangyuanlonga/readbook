import '../../../domain/entities/reading_book_status.dart';
import '../../../domain/entities/reading_record.dart';
import '../../../domain/entities/reading_record_day.dart';
import '../../../domain/entities/reading_record_session.dart';
import 'reading_stats_models.dart';
import 'reading_stats_work_identity_service.dart';

class ReadingStatsSummaryAggregator {
  const ReadingStatsSummaryAggregator({
    ReadingStatsWorkIdentityService workIdentityService =
        const ReadingStatsWorkIdentityService(),
  }) : _workIdentityService = workIdentityService;

  final ReadingStatsWorkIdentityService _workIdentityService;

  ReadingRecordsSummary buildSummary({
    required List<ReadingRecord> latestRecords,
    required List<ReadingRecordDay> dailyRecords,
    required List<ReadingRecord> filteredLatestRecords,
    required List<ReadingRecordDay> filteredDailyRecords,
    required List<ReadingRecordSession> filteredSessions,
    required ReadingRecordsPeriodRange periodRange,
    required Map<String, ReadingBookResolvedStatus> resolvedStatusesByBookId,
  }) {
    final recordsForSummary =
        periodRange.isAll
            ? latestRecords
            : _resolveCoverRecords(
              latestRecords: latestRecords,
              filteredDailyRecords: filteredDailyRecords,
              filteredSessions: filteredSessions,
              fallbackRecords: filteredLatestRecords,
            );
    final workGroups = _workIdentityService.groupItems(
      items: recordsForSummary,
      titleOf: (item) => item.bookTitle,
      authorOf: (item) => item.bookAuthor,
      fallbackIdOf: (item) => item.bookId,
    );
    final totalBooks = workGroups.length;
    final totalDays =
        periodRange.isAll
            ? dailyRecords.map((item) => item.dateKey).toSet().length
            : filteredDailyRecords.map((item) => item.dateKey).toSet().length;
    final completedBookCount =
        workGroups.values
            .where(
              (records) => records.any(
                (record) =>
                    resolvedStatusesByBookId[record.bookId]?.isCompleted ??
                    false,
              ),
            )
            .length;
    final readingBookCount =
        totalBooks == 0 ? 0 : totalBooks - completedBookCount;
    final totalReadMillis =
        periodRange.isAll
            ? recordsForSummary.fold<int>(
              0,
              (sum, item) => sum + item.totalReadMillis,
            )
            : filteredDailyRecords.fold<int>(
              0,
              (sum, item) => sum + item.readMillis,
            );
    final totalReadChars =
        periodRange.isAll
            ? recordsForSummary.fold<int>(
              0,
              (sum, item) => sum + item.totalReadChars,
            )
            : filteredDailyRecords.fold<int>(
              0,
              (sum, item) => sum + item.readChars,
            );
    final readMinutes = totalReadMillis / Duration.millisecondsPerMinute;
    final readCharsPerMinute =
        readMinutes <= 0 ? 0.0 : totalReadChars / readMinutes;
    final chapterCount =
        filteredSessions
            .map(_chapterDimensionKey)
            .whereType<String>()
            .toSet()
            .length;

    return ReadingRecordsSummary(
      title: '阅读总览',
      subtitle: '统计周期：${periodRange.label}',
      totalBooks: totalBooks,
      totalDays: totalDays,
      readingBookCount: readingBookCount,
      completedBookCount: completedBookCount,
      totalReadMillis: totalReadMillis,
      totalReadChars: totalReadChars,
      readCharsPerMinute: readCharsPerMinute,
      chapterCount: chapterCount,
      coverRecords: _resolveRepresentativeRecords(workGroups),
    );
  }

  String? _chapterDimensionKey(ReadingRecordSession session) {
    final chapterIndex = session.chapterIndex;
    if (chapterIndex != null && chapterIndex >= 0) {
      return '${session.bookId}#$chapterIndex';
    }
    final chapterTitle = session.chapterTitle?.trim();
    if (chapterTitle != null && chapterTitle.isNotEmpty) {
      return '${session.bookId}@$chapterTitle';
    }
    return null;
  }

  List<ReadingRecord> _resolveCoverRecords({
    required List<ReadingRecord> latestRecords,
    required List<ReadingRecordDay> filteredDailyRecords,
    required List<ReadingRecordSession> filteredSessions,
    required List<ReadingRecord> fallbackRecords,
  }) {
    final activeBookIds = <String>{
      for (final item in filteredDailyRecords) item.bookId,
      for (final item in filteredSessions) item.bookId,
    };
    if (activeBookIds.isEmpty) {
      return fallbackRecords;
    }
    return latestRecords
        .where((item) => activeBookIds.contains(item.bookId))
        .toList(growable: false);
  }

  List<ReadingRecord> _resolveRepresentativeRecords(
    Map<String, List<ReadingRecord>> workGroups,
  ) {
    final records = workGroups.values
        .map(_resolveRepresentativeRecord)
        .toList(growable: false);
    final sorted = [...records]
      ..sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
    return List<ReadingRecord>.unmodifiable(sorted);
  }

  ReadingRecord _resolveRepresentativeRecord(List<ReadingRecord> records) {
    var best = records.first;
    for (final item in records.skip(1)) {
      if (item.lastReadAt.isAfter(best.lastReadAt)) {
        best = item;
        continue;
      }
      final bestCover = best.coverUrl?.trim() ?? '';
      final itemCover = item.coverUrl?.trim() ?? '';
      if (bestCover.isEmpty && itemCover.isNotEmpty) {
        best = item;
      }
    }
    return best;
  }
}
