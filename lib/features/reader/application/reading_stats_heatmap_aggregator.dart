import '../../../domain/entities/reading_record_day.dart';
import '../../../domain/entities/reading_record_session.dart';
import 'reading_stats_models.dart';
import 'reading_stats_scope_service.dart';
import 'reading_stats_work_identity_service.dart';

class ReadingStatsHeatmapAggregator {
  const ReadingStatsHeatmapAggregator({
    ReadingStatsScopeService scopeService = const ReadingStatsScopeService(),
    ReadingStatsWorkIdentityService workIdentityService =
        const ReadingStatsWorkIdentityService(),
  }) : _scopeService = scopeService,
       _workIdentityService = workIdentityService;

  final ReadingStatsScopeService _scopeService;
  final ReadingStatsWorkIdentityService _workIdentityService;

  Map<String, DailyHeatmapStat> buildHeatmapStats(
    List<ReadingRecordDay> allDays, {
    required List<ReadingRecordSession> sessions,
  }) {
    final daysByDate = <String, List<ReadingRecordDay>>{};
    final result = <String, DailyHeatmapStat>{};
    for (final item in allDays) {
      daysByDate
          .putIfAbsent(item.dateKey, () => <ReadingRecordDay>[])
          .add(item);
      final current = result[item.dateKey];
      result[item.dateKey] = DailyHeatmapStat(
        workCount: current?.workCount ?? 0,
        sessionCount: current?.sessionCount ?? 0,
        readMillis: (current?.readMillis ?? 0) + item.readMillis,
      );
    }
    for (final session in sessions) {
      final dateKey = _scopeService.formatDateKey(session.endAt);
      final current = result[dateKey];
      result[dateKey] = DailyHeatmapStat(
        workCount: current?.workCount ?? 0,
        sessionCount: (current?.sessionCount ?? 0) + 1,
        readMillis: current?.readMillis ?? 0,
      );
    }
    for (final entry in daysByDate.entries) {
      final current = result[entry.key];
      result[entry.key] = DailyHeatmapStat(
        workCount: _workIdentityService.countDistinctWorks(
          items: entry.value,
          titleOf: (item) => item.bookTitle,
          authorOf: (item) => item.bookAuthor,
          fallbackIdOf: (item) => item.bookId,
        ),
        sessionCount: current?.sessionCount ?? 0,
        readMillis: current?.readMillis ?? 0,
      );
    }
    return result;
  }
}
