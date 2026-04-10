import '../../../domain/entities/reading_record_day.dart';
import '../../../domain/entities/reading_record_session.dart';
import 'reading_stats_models.dart';
import 'reading_stats_scope_service.dart';

class ReadingStatsDistributionAggregator {
  const ReadingStatsDistributionAggregator({
    ReadingStatsScopeService scopeService = const ReadingStatsScopeService(),
  }) : _scopeService = scopeService;

  final ReadingStatsScopeService _scopeService;

  ReadingDurationDistribution buildDistribution({
    required ReadingRecordsPeriodRange periodRange,
    required DateTime anchor,
    required List<ReadingRecordDay> filteredDailyRecords,
    required List<ReadingRecordSession> filteredSessions,
  }) {
    final buckets = switch (periodRange.period) {
      ReadingRecordsPeriod.day => _buildDayDistributionBuckets(
        filteredSessions: filteredSessions,
      ),
      ReadingRecordsPeriod.week => _buildWeekDistributionBuckets(
        filteredDailyRecords: filteredDailyRecords,
      ),
      ReadingRecordsPeriod.month => _buildMonthDistributionBuckets(
        periodRange: periodRange,
        filteredDailyRecords: filteredDailyRecords,
      ),
      ReadingRecordsPeriod.year => _buildYearDistributionBuckets(
        filteredDailyRecords: filteredDailyRecords,
      ),
      ReadingRecordsPeriod.all => _buildAllDistributionBuckets(
        filteredDailyRecords: filteredDailyRecords,
      ),
    };
    final maxReadMillis = buckets.fold<int>(
      0,
      (current, item) => item.readMillis > current ? item.readMillis : current,
    );

    return ReadingDurationDistribution(
      title: '阅读时间分布',
      buckets: buckets,
      maxReadMillis: maxReadMillis,
    );
  }

  ReadingCalendarDistribution buildCalendarDistribution({
    required DateTime anchor,
    required List<ReadingRecordDay> filteredDailyRecords,
  }) {
    final readMillisByDate = <String, int>{};

    for (final item in filteredDailyRecords) {
      readMillisByDate[item.dateKey] =
          (readMillisByDate[item.dateKey] ?? 0) + item.readMillis;
    }

    final monthAnchor = _scopeService.stripDate(anchor);
    final months = <ReadingCalendarDistributionMonth>[
      _buildCalendarMonth(
        DateTime(monthAnchor.year, monthAnchor.month - 1, 1),
        readMillisByDate,
      ),
      _buildCalendarMonth(
        DateTime(monthAnchor.year, monthAnchor.month, 1),
        readMillisByDate,
      ),
      _buildCalendarMonth(
        DateTime(monthAnchor.year, monthAnchor.month + 1, 1),
        readMillisByDate,
      ),
    ];

    return ReadingCalendarDistribution(
      months: List<ReadingCalendarDistributionMonth>.unmodifiable(months),
    );
  }

  ReadingCalendarDistributionMonth _buildCalendarMonth(
    DateTime monthStart,
    Map<String, int> readMillisByDate,
  ) {
    final normalizedMonthStart = DateTime(monthStart.year, monthStart.month);
    final monthEnd = DateTime(
      normalizedMonthStart.year,
      normalizedMonthStart.month + 1,
    );
    final gridStart = _scopeService.startOfWeek(normalizedMonthStart);
    final gridEnd = _scopeService
        .startOfWeek(monthEnd.subtract(const Duration(days: 1)))
        .add(const Duration(days: 6));

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
              isInCurrentMonth: day.month == normalizedMonthStart.month,
              readMillis: readMillisByDate[dateKey] ?? 0,
            );
          }, growable: false),
        ),
      );
      cursor = cursor.add(const Duration(days: 7));
    }

    return ReadingCalendarDistributionMonth(
      monthLabel:
          '${normalizedMonthStart.year}年${normalizedMonthStart.month.toString().padLeft(2, '0')}月',
      weeks: List<ReadingCalendarDistributionWeek>.unmodifiable(weeks),
    );
  }

  List<ReadingDurationDistributionBucket> _buildDayDistributionBuckets({
    required List<ReadingRecordSession> filteredSessions,
  }) {
    final millisByHour = <int, int>{};
    for (final session in filteredSessions) {
      final local = session.startAt.toLocal();
      millisByHour[local.hour] =
          (millisByHour[local.hour] ?? 0) + session.durationMillis;
    }
    return List<ReadingDurationDistributionBucket>.generate(24, (hour) {
      return ReadingDurationDistributionBucket(
        label: hour.toString(),
        readMillis: millisByHour[hour] ?? 0,
      );
    }, growable: false);
  }

  List<ReadingDurationDistributionBucket> _buildWeekDistributionBuckets({
    required List<ReadingRecordDay> filteredDailyRecords,
  }) {
    final millisByWeekday = <int, int>{};
    for (final item in filteredDailyRecords) {
      final weekday = DateTime.parse(item.dateKey).weekday;
      millisByWeekday[weekday] =
          (millisByWeekday[weekday] ?? 0) + item.readMillis;
    }
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return List<ReadingDurationDistributionBucket>.generate(7, (index) {
      final weekday = index + 1;
      return ReadingDurationDistributionBucket(
        label: labels[index],
        readMillis: millisByWeekday[weekday] ?? 0,
      );
    }, growable: false);
  }

  List<ReadingDurationDistributionBucket> _buildMonthDistributionBuckets({
    required ReadingRecordsPeriodRange periodRange,
    required List<ReadingRecordDay> filteredDailyRecords,
  }) {
    final start = periodRange.start!;
    final end = periodRange.endExclusive!;
    final totalDays = end.difference(start).inDays;
    final millisByDay = <int, int>{};
    for (final item in filteredDailyRecords) {
      final day = DateTime.parse(item.dateKey).day;
      millisByDay[day] = (millisByDay[day] ?? 0) + item.readMillis;
    }
    return List<ReadingDurationDistributionBucket>.generate(totalDays, (index) {
      final day = index + 1;
      return ReadingDurationDistributionBucket(
        label: day.toString(),
        readMillis: millisByDay[day] ?? 0,
      );
    }, growable: false);
  }

  List<ReadingDurationDistributionBucket> _buildYearDistributionBuckets({
    required List<ReadingRecordDay> filteredDailyRecords,
  }) {
    final millisByMonth = <int, int>{};
    for (final item in filteredDailyRecords) {
      final month = DateTime.parse(item.dateKey).month;
      millisByMonth[month] = (millisByMonth[month] ?? 0) + item.readMillis;
    }
    return List<ReadingDurationDistributionBucket>.generate(12, (index) {
      final month = index + 1;
      return ReadingDurationDistributionBucket(
        label: month.toString(),
        readMillis: millisByMonth[month] ?? 0,
      );
    }, growable: false);
  }

  List<ReadingDurationDistributionBucket> _buildAllDistributionBuckets({
    required List<ReadingRecordDay> filteredDailyRecords,
  }) {
    if (filteredDailyRecords.isEmpty) {
      return const <ReadingDurationDistributionBucket>[];
    }
    final millisByYear = <int, int>{};
    final years = <int>{};
    for (final item in filteredDailyRecords) {
      final year = DateTime.parse(item.dateKey).year;
      years.add(year);
      millisByYear[year] = (millisByYear[year] ?? 0) + item.readMillis;
    }
    final orderedYears = years.toList()..sort();
    return orderedYears
        .map(
          (year) => ReadingDurationDistributionBucket(
            label: year.toString(),
            readMillis: millisByYear[year] ?? 0,
          ),
        )
        .toList(growable: false);
  }
}
