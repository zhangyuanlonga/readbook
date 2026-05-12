import '../../../domain/entities/reading_record.dart';
import '../../../domain/entities/reading_record_day.dart';
import '../../../domain/entities/reading_record_session.dart';
import 'reading_stats_models.dart';

class ReadingStatsFilterResult {
  const ReadingStatsFilterResult({
    required this.filteredLatestRecords,
    required this.filteredDailyRecords,
    required this.filteredSessions,
  });

  final List<ReadingRecord> filteredLatestRecords;
  final List<ReadingRecordDay> filteredDailyRecords;
  final List<ReadingRecordSession> filteredSessions;
}

class ReadingStatsRecordsFilterService {
  const ReadingStatsRecordsFilterService();

  ReadingStatsFilterResult filter({
    required List<ReadingRecord> latestRecords,
    required List<ReadingRecordDay> dailyRecords,
    required List<ReadingRecordSession> sessions,
    required ReadingRecordsPeriodRange periodRange,
  }) {
    return ReadingStatsFilterResult(
      filteredLatestRecords: filterLatestRecords(
        latestRecords,
        periodRange: periodRange,
      ),
      filteredDailyRecords: filterDailyRecords(
        dailyRecords,
        periodRange: periodRange,
      ),
      filteredSessions: filterSessions(sessions, periodRange: periodRange),
    );
  }

  List<ReadingRecord> filterLatestRecords(
    List<ReadingRecord> latestRecords, {
    required ReadingRecordsPeriodRange periodRange,
  }) {
    if (periodRange.isAll) {
      return latestRecords;
    }
    return latestRecords
        .where((item) => periodRange.contains(item.lastReadAt))
        .toList(growable: false);
  }

  List<ReadingRecordDay> filterDailyRecords(
    List<ReadingRecordDay> dailyRecords, {
    required ReadingRecordsPeriodRange periodRange,
  }) {
    if (periodRange.isAll) {
      return dailyRecords;
    }
    return dailyRecords
        .where(
          (item) =>
              periodRange.contains(DateTime.parse(item.dateKey).toLocal()),
        )
        .toList(growable: false);
  }

  List<ReadingRecordSession> filterSessions(
    List<ReadingRecordSession> sessions, {
    required ReadingRecordsPeriodRange periodRange,
  }) {
    if (periodRange.isAll) {
      return sessions;
    }
    return sessions
        .where((item) => periodRange.contains(item.endAt))
        .toList(growable: false);
  }
}
