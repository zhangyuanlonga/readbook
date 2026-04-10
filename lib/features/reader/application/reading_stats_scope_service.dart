import 'reading_stats_models.dart';

class ReadingStatsScopeService {
  const ReadingStatsScopeService();

  ReadingRecordsPeriodRange resolvePeriodRange({
    required ReadingRecordsPeriod period,
    required DateTime anchor,
  }) {
    final localAnchor = stripDate(anchor);
    switch (period) {
      case ReadingRecordsPeriod.day:
        final start = localAnchor;
        return ReadingRecordsPeriodRange(
          period: period,
          label: formatDateKey(start),
          start: start,
          endExclusive: start.add(const Duration(days: 1)),
        );
      case ReadingRecordsPeriod.week:
        final start = startOfWeek(localAnchor);
        final end = start.add(const Duration(days: 7));
        return ReadingRecordsPeriodRange(
          period: period,
          label:
              '${formatDateKey(start)} - ${formatDateKey(end.subtract(const Duration(days: 1)))}',
          start: start,
          endExclusive: end,
        );
      case ReadingRecordsPeriod.month:
        final start = DateTime(localAnchor.year, localAnchor.month);
        return ReadingRecordsPeriodRange(
          period: period,
          label: '${start.year}年${start.month.toString().padLeft(2, '0')}月',
          start: start,
          endExclusive: DateTime(start.year, start.month + 1),
        );
      case ReadingRecordsPeriod.year:
        final start = DateTime(localAnchor.year);
        return ReadingRecordsPeriodRange(
          period: period,
          label: '${start.year}年',
          start: start,
          endExclusive: DateTime(start.year + 1),
        );
      case ReadingRecordsPeriod.all:
        return const ReadingRecordsPeriodRange(
          period: ReadingRecordsPeriod.all,
          label: '全部时间',
        );
    }
  }

  DateTime stripDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  DateTime startOfWeek(DateTime date) {
    final normalized = stripDate(date);
    final offset = normalized.weekday - DateTime.monday;
    return normalized.subtract(Duration(days: offset));
  }

  String formatDateKey(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
