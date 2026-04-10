import '../../../domain/entities/reading_record_day.dart';
import '../../../domain/entities/reading_record_session.dart';
import 'reading_stats_models.dart';
import 'reading_stats_scope_service.dart';

class ReadingStatsHeatmapAggregator {
  const ReadingStatsHeatmapAggregator({
    ReadingStatsScopeService scopeService = const ReadingStatsScopeService(),
  }) : _scopeService = scopeService;

  final ReadingStatsScopeService _scopeService;

  Map<String, DailyHeatmapStat> buildHeatmapStats(
    List<ReadingRecordDay> allDays, {
    required List<ReadingRecordSession> sessions,
  }) {
    final result = <String, DailyHeatmapStat>{};
    for (final item in allDays) {
      final current = result[item.dateKey];
      result[item.dateKey] = DailyHeatmapStat(
        workCount: (current?.workCount ?? 0) + 1,
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
    return result;
  }
}
