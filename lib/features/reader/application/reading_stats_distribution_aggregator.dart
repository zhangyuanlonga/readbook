import '../../../domain/entities/reading_record_day.dart';
import 'reading_stats_models.dart';
import 'reading_stats_scope_service.dart';

class ReadingStatsDistributionAggregator {
  const ReadingStatsDistributionAggregator({
    ReadingStatsScopeService scopeService = const ReadingStatsScopeService(),
  }) : _scopeService = scopeService;

  final ReadingStatsScopeService _scopeService;

  ReadingDurationDistribution buildDistribution({
    required DateTime anchor,
    required List<ReadingRecordDay> filteredDailyRecords,
  }) {
    final monthAnchor = _scopeService.stripDate(anchor);
    final monthStart = DateTime(monthAnchor.year, monthAnchor.month);
    final monthEnd = DateTime(monthAnchor.year, monthAnchor.month + 1);
    final gridStart = _scopeService.startOfWeek(monthStart);
    final gridEnd = _scopeService
        .startOfWeek(monthEnd.subtract(const Duration(days: 1)))
        .add(const Duration(days: 6));
    final readMillisByDate = <String, int>{};

    for (final item in filteredDailyRecords) {
      final parsed = DateTime.parse(item.dateKey);
      if (parsed.isBefore(monthStart) || !parsed.isBefore(monthEnd)) {
        continue;
      }
      readMillisByDate[item.dateKey] =
          (readMillisByDate[item.dateKey] ?? 0) + item.readMillis;
    }

    final weeks = <ReadingCalendarDistributionWeek>[];
    var cursor = gridStart;
    while (!cursor.isAfter(gridEnd)) {
      weeks.add(
        ReadingCalendarDistributionWeek(
          days: List<ReadingCalendarDistributionDay>.generate(7, (index) {
            final day = cursor.add(Duration(days: index));
            final dateKey = _scopeService.formatDateKey(day);
            return ReadingCalendarDistributionDay(
              day: day,
              isInCurrentMonth: day.month == monthStart.month,
              readMillis: readMillisByDate[dateKey] ?? 0,
            );
          }, growable: false),
        ),
      );
      cursor = cursor.add(const Duration(days: 7));
    }

    return ReadingDurationDistribution(
      title: '阅读时间分布',
      monthLabel:
          '${monthStart.year}年${monthStart.month.toString().padLeft(2, '0')}月',
      weeks: List<ReadingCalendarDistributionWeek>.unmodifiable(weeks),
    );
  }
}
