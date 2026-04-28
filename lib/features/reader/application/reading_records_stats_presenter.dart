import '../../../domain/entities/reading_record_day.dart';
import '../../../domain/entities/reading_record_session.dart';
import 'reading_stats_models.dart';
import 'reading_stats_work_identity_service.dart';

class ReadingRecordsSectionVisibility {
  const ReadingRecordsSectionVisibility({
    required this.showRanking,
    required this.showWeekActivity,
    required this.showCalendar,
    required this.showHeatmap,
  });

  final bool showRanking;
  final bool showWeekActivity;
  final bool showCalendar;
  final bool showHeatmap;
}

class ReadingCalendarBookDetail {
  const ReadingCalendarBookDetail({
    required this.bookId,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.readMillis,
    required this.readChars,
    required this.chapterTitle,
  });

  final String bookId;
  final String title;
  final String? author;
  final String? coverUrl;
  final int readMillis;
  final int readChars;
  final String? chapterTitle;
}

class ReadingCalendarDayDetail {
  const ReadingCalendarDayDetail({
    required this.dateKey,
    required this.readMillis,
    required this.readChars,
    required this.sessionCount,
    required this.workCount,
    required this.books,
  });

  final String dateKey;
  final int readMillis;
  final int readChars;
  final int sessionCount;
  final int workCount;
  final List<ReadingCalendarBookDetail> books;
}

class ReadingRecordsStatsPresenter {
  const ReadingRecordsStatsPresenter({
    ReadingStatsWorkIdentityService workIdentityService =
        const ReadingStatsWorkIdentityService(),
  }) : _workIdentityService = workIdentityService;

  final ReadingStatsWorkIdentityService _workIdentityService;

  ReadingRecordsSectionVisibility resolveVisibleSections(
    ReadingRecordsPeriod period,
  ) {
    final showRanking =
        period == ReadingRecordsPeriod.day ||
        period == ReadingRecordsPeriod.week ||
        period == ReadingRecordsPeriod.month ||
        period == ReadingRecordsPeriod.year ||
        period == ReadingRecordsPeriod.all;
    return ReadingRecordsSectionVisibility(
      showRanking: showRanking,
      showWeekActivity: period == ReadingRecordsPeriod.week,
      showCalendar: period == ReadingRecordsPeriod.month,
      showHeatmap:
          period == ReadingRecordsPeriod.year ||
          period == ReadingRecordsPeriod.all,
    );
  }

  Map<String, ReadingCalendarDayDetail> buildCalendarDetailsByDate({
    required Set<String> allowedDateKeys,
    required List<ReadingRecordDay> dailyRecords,
    required List<ReadingRecordSession> sessions,
  }) {
    final totalReadMillisByDate = <String, int>{};
    final totalReadCharsByDate = <String, int>{};
    final daysByDate = <String, List<ReadingRecordDay>>{};
    final sessionsByDate = <String, List<ReadingRecordSession>>{};

    for (final day in dailyRecords) {
      if (!allowedDateKeys.contains(day.dateKey)) {
        continue;
      }
      daysByDate.putIfAbsent(day.dateKey, () => <ReadingRecordDay>[]).add(day);
      totalReadMillisByDate[day.dateKey] =
          (totalReadMillisByDate[day.dateKey] ?? 0) + day.readMillis;
      totalReadCharsByDate[day.dateKey] =
          (totalReadCharsByDate[day.dateKey] ?? 0) + day.readChars;
    }

    final sessionCountByDate = <String, int>{};
    for (final session in sessions) {
      final dateKey = _dateKeyFor(session.startAt);
      if (!allowedDateKeys.contains(dateKey)) {
        continue;
      }
      sessionsByDate
          .putIfAbsent(dateKey, () => <ReadingRecordSession>[])
          .add(session);
      sessionCountByDate[dateKey] = (sessionCountByDate[dateKey] ?? 0) + 1;
    }

    final details = <String, ReadingCalendarDayDetail>{};
    for (final dateKey in allowedDateKeys) {
      final books = _buildBooksForDate(
        sessionsByDate[dateKey] ?? const <ReadingRecordSession>[],
      );
      details[dateKey] = ReadingCalendarDayDetail(
        dateKey: dateKey,
        readMillis: totalReadMillisByDate[dateKey] ?? 0,
        readChars: totalReadCharsByDate[dateKey] ?? 0,
        sessionCount: sessionCountByDate[dateKey] ?? 0,
        workCount: books.isEmpty
            ? _workIdentityService.countDistinctWorks(
                items: daysByDate[dateKey] ?? const <ReadingRecordDay>[],
                titleOf: (item) => item.bookTitle,
                authorOf: (item) => item.bookAuthor,
                fallbackIdOf: (item) => item.bookId,
              )
            : books.length,
        books: books,
      );
    }
    return details;
  }

  DateTime resolveSelectedCalendarDate({
    required List<DateTime> candidateDays,
    required Map<String, ReadingCalendarDayDetail> detailsByDate,
    required DateTime? selectedDate,
  }) {
    if (selectedDate != null) {
      for (final day in candidateDays) {
        if (_dateKeyFor(day) == _dateKeyFor(selectedDate)) {
          return day;
        }
      }
    }

    final sortedDays = List<DateTime>.from(candidateDays)
      ..sort((a, b) => b.compareTo(a));
    for (final day in sortedDays) {
      final detail = detailsByDate[_dateKeyFor(day)];
      if (detail != null && detail.readMillis > 0) {
        return day;
      }
    }

    final today = _stripDate(DateTime.now());
    for (final day in candidateDays) {
      if (_dateKeyFor(day) == _dateKeyFor(today)) {
        return day;
      }
    }
    return candidateDays.first;
  }

  List<ReadingCalendarBookDetail> _buildBooksForDate(
    List<ReadingRecordSession> sessions,
  ) {
    final groups = _workIdentityService.groupItems(
      items: sessions,
      titleOf: (item) => item.bookTitle,
      authorOf: (item) => item.bookAuthor,
      fallbackIdOf: (item) => item.bookId,
    );
    final books = groups.values
        .map((items) {
          final latest = _latestSession(items);
          final preferredChapter = items
              .map((item) => item.chapterTitle?.trim() ?? '')
              .firstWhere((item) => item.isNotEmpty, orElse: () => '');
          return ReadingCalendarBookDetail(
            bookId: latest.bookId,
            title: latest.bookTitle,
            author: latest.bookAuthor,
            coverUrl: latest.coverUrl,
            readMillis: items.fold<int>(
              0,
              (sum, item) => sum + item.durationMillis,
            ),
            readChars: items.fold<int>(0, (sum, item) => sum + item.readChars),
            chapterTitle: preferredChapter.isEmpty ? null : preferredChapter,
          );
        })
        .toList(growable: true);
    books.sort((a, b) => b.readMillis.compareTo(a.readMillis));
    return books;
  }

  ReadingRecordSession _latestSession(List<ReadingRecordSession> sessions) {
    var latest = sessions.first;
    for (final session in sessions.skip(1)) {
      if (session.endAt.isAfter(latest.endAt)) {
        latest = session;
      }
    }
    return latest;
  }

  DateTime _stripDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  String _dateKeyFor(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
