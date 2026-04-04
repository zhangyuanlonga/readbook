import '../../../domain/entities/reading_record.dart';
import '../../../domain/entities/reading_record_day.dart';
import '../../../domain/entities/reading_record_session.dart';

class ReadingRecordsSummary {
  const ReadingRecordsSummary({
    required this.title,
    required this.subtitle,
    required this.totalBooks,
    required this.totalReadMillis,
    required this.totalReadChars,
    required this.sessionCount,
    required this.chapterCount,
    required this.coverRecords,
  });

  final String title;
  final String subtitle;
  final int totalBooks;
  final int totalReadMillis;
  final int totalReadChars;
  final int sessionCount;
  final int chapterCount;
  final List<ReadingRecord> coverRecords;
}

class ReadingRecordsQueryView {
  const ReadingRecordsQueryView({
    required this.filteredLatestRecords,
    required this.filteredDailyRecords,
    required this.filteredSessions,
    required this.summary,
  });

  final List<ReadingRecord> filteredLatestRecords;
  final List<ReadingRecordDay> filteredDailyRecords;
  final List<ReadingRecordSession> filteredSessions;
  final ReadingRecordsSummary summary;
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

class ReadingRecordsQueryService {
  const ReadingRecordsQueryService();

  ReadingRecordsQueryView buildQueryView({
    required List<ReadingRecord> latestRecords,
    required List<ReadingRecordDay> dailyRecords,
    required List<ReadingRecordSession> sessions,
    required String? selectedDateKey,
    required String searchKeyword,
    required String viewLabel,
  }) {
    final filteredLatestRecords = filterLatestRecords(
      latestRecords,
      selectedDateKey: selectedDateKey,
    );
    final filteredDailyRecords = filterDailyRecords(
      dailyRecords,
      selectedDateKey: selectedDateKey,
    );
    final filteredSessions = filterSessions(
      sessions,
      selectedDateKey: selectedDateKey,
    );

    return ReadingRecordsQueryView(
      filteredLatestRecords: filteredLatestRecords,
      filteredDailyRecords: filteredDailyRecords,
      filteredSessions: filteredSessions,
      summary: buildSummary(
        latestRecords: latestRecords,
        filteredLatestRecords: filteredLatestRecords,
        filteredDailyRecords: filteredDailyRecords,
        filteredSessions: filteredSessions,
        selectedDateKey: selectedDateKey,
        searchKeyword: searchKeyword,
        viewLabel: viewLabel,
      ),
    );
  }

  List<ReadingRecord> filterLatestRecords(
    List<ReadingRecord> latestRecords, {
    required String? selectedDateKey,
  }) {
    if (selectedDateKey == null) {
      return latestRecords;
    }
    return latestRecords
        .where((item) => _dateKeyFor(item.lastReadAt) == selectedDateKey)
        .toList(growable: false);
  }

  List<ReadingRecordDay> filterDailyRecords(
    List<ReadingRecordDay> dailyRecords, {
    required String? selectedDateKey,
  }) {
    if (selectedDateKey == null) {
      return dailyRecords;
    }
    return dailyRecords
        .where((item) => item.dateKey == selectedDateKey)
        .toList(growable: false);
  }

  List<ReadingRecordSession> filterSessions(
    List<ReadingRecordSession> sessions, {
    required String? selectedDateKey,
  }) {
    if (selectedDateKey == null) {
      return sessions;
    }
    return sessions
        .where((item) => _dateKeyFor(item.endAt) == selectedDateKey)
        .toList(growable: false);
  }

  ReadingRecordsSummary buildSummary({
    required List<ReadingRecord> latestRecords,
    required List<ReadingRecord> filteredLatestRecords,
    required List<ReadingRecordDay> filteredDailyRecords,
    required List<ReadingRecordSession> filteredSessions,
    required String? selectedDateKey,
    required String searchKeyword,
    required String viewLabel,
  }) {
    final recordsForSummary =
        selectedDateKey == null ? latestRecords : filteredLatestRecords;
    final totalBooks =
        selectedDateKey == null
            ? recordsForSummary.length
            : filteredDailyRecords.map((item) => item.bookId).toSet().length;
    final totalReadMillis =
        selectedDateKey == null
            ? recordsForSummary.fold<int>(
              0,
              (sum, item) => sum + item.totalReadMillis,
            )
            : filteredDailyRecords.fold<int>(
              0,
              (sum, item) => sum + item.readMillis,
            );
    final totalReadChars =
        selectedDateKey == null
            ? recordsForSummary.fold<int>(
              0,
              (sum, item) => sum + item.totalReadChars,
            )
            : filteredDailyRecords.fold<int>(
              0,
              (sum, item) => sum + item.readChars,
            );
    final sessionCount = filteredSessions.length;
    final chapterCount =
        filteredSessions
            .map(_chapterDimensionKey)
            .whereType<String>()
            .toSet()
            .length;
    final title = selectedDateKey == null ? '累计阅读成就' : '$selectedDateKey 阅读概览';
    final subtitle =
        selectedDateKey == null
            ? (searchKeyword.isEmpty
                ? '当前查看：$viewLabel'
                : '当前查看：$viewLabel · 搜索“$searchKeyword”')
            : '当前查看：$viewLabel · 已按日期过滤';

    return ReadingRecordsSummary(
      title: title,
      subtitle: subtitle,
      totalBooks: totalBooks,
      totalReadMillis: totalReadMillis,
      totalReadChars: totalReadChars,
      sessionCount: sessionCount,
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

  String _dateKeyFor(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
