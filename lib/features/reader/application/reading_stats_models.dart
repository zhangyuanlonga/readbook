import '../../../domain/entities/reading_record.dart';

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
