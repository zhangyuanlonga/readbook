import '../../../domain/entities/reading_book_status.dart';
import '../../../domain/entities/reading_record.dart';
import '../../../domain/entities/reading_record_day.dart';
import '../../../domain/entities/reading_record_session.dart';

enum ReadingRecordsPeriod { day, week, month, year, all }

class ReadingRecordsPeriodRange {
  const ReadingRecordsPeriodRange({
    required this.period,
    required this.label,
    this.start,
    this.endExclusive,
  });

  final ReadingRecordsPeriod period;
  final String label;
  final DateTime? start;
  final DateTime? endExclusive;

  bool get isAll => period == ReadingRecordsPeriod.all;

  bool contains(DateTime value) {
    if (isAll) {
      return true;
    }
    final local = value.toLocal();
    return !local.isBefore(start!) && local.isBefore(endExclusive!);
  }
}

class ReadingRecordsSummary {
  const ReadingRecordsSummary({
    required this.title,
    required this.subtitle,
    required this.totalBooks,
    required this.totalDays,
    required this.readingBookCount,
    required this.completedBookCount,
    required this.totalReadMillis,
    required this.totalReadChars,
    required this.readCharsPerMinute,
    required this.chapterCount,
    required this.coverRecords,
  });

  final String title;
  final String subtitle;
  final int totalBooks;
  final int totalDays;
  final int readingBookCount;
  final int completedBookCount;
  final int totalReadMillis;
  final int totalReadChars;
  final double readCharsPerMinute;
  final int chapterCount;
  final List<ReadingRecord> coverRecords;
}

class ReadingRecordsQueryView {
  const ReadingRecordsQueryView({
    required this.periodRange,
    required this.filteredLatestRecords,
    required this.summary,
    required this.distribution,
    required this.rankings,
  });

  final ReadingRecordsPeriodRange periodRange;
  final List<ReadingRecord> filteredLatestRecords;
  final ReadingRecordsSummary summary;
  final ReadingDurationDistribution distribution;
  final List<ReadingDurationRankingItem> rankings;
}

class DailyHeatmapStat {
  const DailyHeatmapStat({
    required this.workCount,
    required this.sessionCount,
    required this.readMillis,
  });

  final int workCount;
  final int sessionCount;
  final int readMillis;
}

class ReadingCalendarDistributionDay {
  const ReadingCalendarDistributionDay({
    required this.day,
    required this.isInCurrentMonth,
    required this.readMillis,
  });

  final DateTime day;
  final bool isInCurrentMonth;
  final int readMillis;

  bool get hasReading => readMillis > 0;

  String get dateKey {
    final local = day.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final date = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$date';
  }
}

class ReadingCalendarDistributionWeek {
  const ReadingCalendarDistributionWeek({required this.days});

  final List<ReadingCalendarDistributionDay> days;
}

class ReadingDurationDistribution {
  const ReadingDurationDistribution({
    required this.title,
    required this.monthLabel,
    required this.weeks,
  });

  final String title;
  final String monthLabel;
  final List<ReadingCalendarDistributionWeek> weeks;
}

class ReadingDurationRankingItem {
  const ReadingDurationRankingItem({
    required this.record,
    required this.readMillis,
    required this.readChars,
    required this.readDays,
  });

  final ReadingRecord record;
  final int readMillis;
  final int readChars;
  final int readDays;
}

class ReadingRecordsQueryService {
  const ReadingRecordsQueryService();

  ReadingRecordsQueryView buildQueryView({
    required List<ReadingRecord> latestRecords,
    required List<ReadingRecordDay> dailyRecords,
    required List<ReadingRecordSession> sessions,
    required ReadingRecordsPeriod period,
    required DateTime anchor,
    required Map<String, ReadingBookResolvedStatus> resolvedStatusesByBookId,
  }) {
    final periodRange = resolvePeriodRange(period: period, anchor: anchor);
    final filteredLatestRecords = filterLatestRecords(
      latestRecords,
      periodRange: periodRange,
    );
    final filteredDailyRecords = filterDailyRecords(
      dailyRecords,
      periodRange: periodRange,
    );
    final filteredSessions = filterSessions(sessions, periodRange: periodRange);

    return ReadingRecordsQueryView(
      periodRange: periodRange,
      filteredLatestRecords: filteredLatestRecords,
      summary: buildSummary(
        latestRecords: latestRecords,
        dailyRecords: dailyRecords,
        filteredLatestRecords: filteredLatestRecords,
        filteredDailyRecords: filteredDailyRecords,
        filteredSessions: filteredSessions,
        periodRange: periodRange,
        resolvedStatusesByBookId: resolvedStatusesByBookId,
      ),
      distribution: buildDurationDistribution(
        periodRange: periodRange,
        anchor: anchor,
        filteredDailyRecords: filteredDailyRecords,
      ),
      rankings: buildDurationRankings(
        latestRecords: latestRecords,
        filteredDailyRecords: filteredDailyRecords,
        periodRange: periodRange,
      ),
    );
  }

  ReadingRecordsPeriodRange resolvePeriodRange({
    required ReadingRecordsPeriod period,
    required DateTime anchor,
  }) {
    final localAnchor = _stripDate(anchor);
    switch (period) {
      case ReadingRecordsPeriod.day:
        final start = localAnchor;
        return ReadingRecordsPeriodRange(
          period: period,
          label: _formatDateKey(start),
          start: start,
          endExclusive: start.add(const Duration(days: 1)),
        );
      case ReadingRecordsPeriod.week:
        final start = _startOfWeek(localAnchor);
        final end = start.add(const Duration(days: 7));
        return ReadingRecordsPeriodRange(
          period: period,
          label:
              '${_formatDateKey(start)} - ${_formatDateKey(end.subtract(const Duration(days: 1)))}',
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
        .where((item) => periodRange.contains(DateTime.parse(item.dateKey)))
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
    const title = '阅读总览';
    final subtitle = '统计周期：${periodRange.label}';

    return ReadingRecordsSummary(
      title: title,
      subtitle: subtitle,
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
      final dateKey = _dateKeyFor(session.endAt);
      final current = result[dateKey];
      result[dateKey] = DailyHeatmapStat(
        workCount: current?.workCount ?? 0,
        sessionCount: (current?.sessionCount ?? 0) + 1,
        readMillis: current?.readMillis ?? 0,
      );
    }
    return result;
  }

  ReadingDurationDistribution buildDurationDistribution({
    required ReadingRecordsPeriodRange periodRange,
    required DateTime anchor,
    required List<ReadingRecordDay> filteredDailyRecords,
  }) {
    final monthAnchor = _stripDate(anchor);
    final monthStart = DateTime(monthAnchor.year, monthAnchor.month);
    final monthEnd = DateTime(monthAnchor.year, monthAnchor.month + 1);
    final gridStart = _startOfWeek(monthStart);
    final gridEnd = _startOfWeek(
      monthEnd.subtract(const Duration(days: 1)),
    ).add(const Duration(days: 6));
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
            final dateKey = _formatDateKey(day);
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

  List<ReadingDurationRankingItem> buildDurationRankings({
    required List<ReadingRecord> latestRecords,
    required List<ReadingRecordDay> filteredDailyRecords,
    required ReadingRecordsPeriodRange periodRange,
  }) {
    if (periodRange.isAll) {
      final items = latestRecords
          .map(
            (record) => ReadingDurationRankingItem(
              record: record,
              readMillis: record.totalReadMillis,
              readChars: record.totalReadChars,
              readDays: 0,
            ),
          )
          .where((item) => item.readMillis > 0)
          .toList(growable: false);
      return _sortRankings(items);
    }

    final recordByBookId = <String, ReadingRecord>{
      for (final record in latestRecords) record.bookId: record,
    };
    final millisByBookId = <String, int>{};
    final charsByBookId = <String, int>{};
    final daysByBookId = <String, Set<String>>{};

    for (final item in filteredDailyRecords) {
      millisByBookId[item.bookId] =
          (millisByBookId[item.bookId] ?? 0) + item.readMillis;
      charsByBookId[item.bookId] =
          (charsByBookId[item.bookId] ?? 0) + item.readChars;
      daysByBookId.putIfAbsent(item.bookId, () => <String>{}).add(item.dateKey);
    }

    final items = <ReadingDurationRankingItem>[];
    for (final entry in millisByBookId.entries) {
      final record = recordByBookId[entry.key];
      if (record == null || entry.value <= 0) {
        continue;
      }
      items.add(
        ReadingDurationRankingItem(
          record: record,
          readMillis: entry.value,
          readChars: charsByBookId[entry.key] ?? 0,
          readDays: daysByBookId[entry.key]?.length ?? 0,
        ),
      );
    }
    return _sortRankings(items);
  }

  List<ReadingDurationRankingItem> _sortRankings(
    List<ReadingDurationRankingItem> items,
  ) {
    final mutable = List<ReadingDurationRankingItem>.from(items);
    mutable.sort((a, b) {
      final millisCompare = b.readMillis.compareTo(a.readMillis);
      if (millisCompare != 0) {
        return millisCompare;
      }
      final daysCompare = b.readDays.compareTo(a.readDays);
      if (daysCompare != 0) {
        return daysCompare;
      }
      return b.record.lastReadAt.compareTo(a.record.lastReadAt);
    });
    return List<ReadingDurationRankingItem>.unmodifiable(mutable);
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

  DateTime _stripDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = _stripDate(date);
    final offset = normalized.weekday - DateTime.monday;
    return normalized.subtract(Duration(days: offset));
  }

  String _dateKeyFor(DateTime time) {
    final local = time.toLocal();
    return _formatDateKey(local);
  }

  String _formatDateKey(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
