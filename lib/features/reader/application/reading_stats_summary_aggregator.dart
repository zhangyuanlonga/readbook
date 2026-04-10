import '../../../domain/entities/reading_book_status.dart';
import '../../../domain/entities/reading_record.dart';
import '../../../domain/entities/reading_record_day.dart';
import '../../../domain/entities/reading_record_session.dart';
import 'reading_stats_models.dart';

class ReadingStatsSummaryAggregator {
  const ReadingStatsSummaryAggregator();

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
    final activeBookIds =
        periodRange.isAll
            ? latestRecords.map((item) => item.bookId).toSet()
            : <String>{
              for (final item in filteredDailyRecords) item.bookId,
              for (final item in filteredSessions) item.bookId,
            };
    final totalBooks =
        periodRange.isAll ? latestRecords.length : activeBookIds.length;
    final totalDays =
        periodRange.isAll
            ? dailyRecords.map((item) => item.dateKey).toSet().length
            : filteredDailyRecords.map((item) => item.dateKey).toSet().length;
    final completedBookCount =
        activeBookIds
            .where(
              (bookId) =>
                  resolvedStatusesByBookId[bookId]?.isCompleted ?? false,
            )
            .length;
    final readingBookCount =
        activeBookIds.isEmpty ? 0 : activeBookIds.length - completedBookCount;
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
      coverRecords: recordsForSummary,
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
}
