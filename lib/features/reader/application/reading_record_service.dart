import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/reading_record.dart';
import '../../../domain/entities/reading_record_day.dart';
import '../../../domain/entities/reading_record_session.dart';

class ReadingRecordCommitInput {
  const ReadingRecordCommitInput({
    required this.bookId,
    required this.sourceId,
    required this.detailUrl,
    required this.bookTitle,
    this.bookAuthor,
    this.coverUrl,
    this.chapterId,
    this.chapterTitle,
    this.chapterIndex,
    this.chapterUrl,
    required this.startAt,
    required this.endAt,
    this.readChars = 0,
    this.startPositionRatio = 0,
    this.endPositionRatio = 0,
  });

  final String bookId;
  final String sourceId;
  final String detailUrl;
  final String bookTitle;
  final String? bookAuthor;
  final String? coverUrl;
  final String? chapterId;
  final String? chapterTitle;
  final int? chapterIndex;
  final String? chapterUrl;
  final DateTime startAt;
  final DateTime endAt;
  final int readChars;
  final double startPositionRatio;
  final double endPositionRatio;
}

class ReadingRecordService {
  ReadingRecordService({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  static const Duration minimumSessionDuration = Duration(seconds: 10);

  Stream<List<ReadingRecord>> watchLatestRecords({String query = ''}) {
    return _database.watchLatestReadingRecords(query: query);
  }

  Stream<List<ReadingRecordDay>> watchDailyRecords({String query = ''}) {
    return _database.watchReadingRecordDays(query: query);
  }

  Stream<List<ReadingRecordSession>> watchSessions({String query = ''}) {
    return _database.watchReadingRecordSessions(query: query);
  }

  Stream<int> watchTotalReadMillis() => _database.watchTotalReadingMillis();

  Future<List<ReadingRecord>> getMergeCandidates(ReadingRecord target) async {
    final normalizedTitle = _normalizeMergeText(target.bookTitle);
    if (normalizedTitle.isEmpty) {
      return const <ReadingRecord>[];
    }

    final records = await _database.listLatestReadingRecords();
    return records
        .where((item) => item.bookId != target.bookId)
        .where((item) => _normalizeMergeText(item.bookTitle) == normalizedTitle)
        .toList(growable: false);
  }

  Future<void> mergeRecords({
    required ReadingRecord target,
    required List<ReadingRecord> sources,
  }) async {
    final uniqueSources = <String, ReadingRecord>{
      for (final source in sources)
        if (source.bookId != target.bookId) source.bookId: source,
    }.values.toList(growable: false);
    if (uniqueSources.isEmpty) {
      return;
    }

    await _database.transaction(() async {
      for (final source in uniqueSources) {
        final sourceSessions = await _database
            .listReadingRecordSessionsByBookId(source.bookId);
        for (final session in sourceSessions) {
          await _database.updateReadingRecordSession(
            ReadingRecordSession(
              id: session.id,
              bookId: target.bookId,
              sourceId: target.sourceId,
              detailUrl: target.detailUrl,
              bookTitle: target.bookTitle,
              bookAuthor: target.bookAuthor,
              coverUrl: target.coverUrl,
              chapterId: null,
              chapterTitle: session.chapterTitle,
              chapterIndex: session.chapterIndex,
              chapterUrl: null,
              startAt: session.startAt,
              endAt: session.endAt,
              durationMillis: session.durationMillis,
              readChars: session.readChars,
              startPositionRatio: session.startPositionRatio,
              endPositionRatio: session.endPositionRatio,
            ),
          );
        }
        await _database.deleteReadingRecordByBookId(source.bookId);
        await _database.deleteReadingRecordDaysByBookId(source.bookId);
      }

      await _rebuildAggregatesForBook(target.bookId);
    });
  }

  Future<void> deleteRecord(ReadingRecord record) async {
    await _database.deleteReadingRecordsByBookId(record.bookId);
  }

  Future<void> deleteDayRecord(ReadingRecordDay day) async {
    final normalizedBookId = day.bookId.trim();
    final normalizedDateKey = day.dateKey.trim();
    if (normalizedBookId.isEmpty || normalizedDateKey.isEmpty) {
      return;
    }

    await _database.transaction(() async {
      await _database.deleteReadingRecordSessionsByBookIdAndDate(
        bookId: normalizedBookId,
        dateKey: normalizedDateKey,
      );
      await _rebuildAggregatesForBook(normalizedBookId);
    });
  }

  Future<void> deleteSession(ReadingRecordSession session) async {
    final normalizedBookId = session.bookId.trim();
    if (normalizedBookId.isEmpty || session.id <= 0) {
      return;
    }

    await _database.transaction(() async {
      await _database.deleteReadingRecordSessionById(session.id);
      await _rebuildAggregatesForBook(normalizedBookId);
    });
  }

  Future<void> commitSession(ReadingRecordCommitInput input) async {
    final normalizedBookId = input.bookId.trim();
    final normalizedSourceId = input.sourceId.trim();
    final normalizedDetailUrl = input.detailUrl.trim();
    final normalizedTitle = input.bookTitle.trim();
    final durationMillis = input.endAt.difference(input.startAt).inMilliseconds;
    final safeReadChars = input.readChars < 0 ? 0 : input.readChars;

    if (normalizedBookId.isEmpty ||
        normalizedSourceId.isEmpty ||
        normalizedDetailUrl.isEmpty ||
        normalizedTitle.isEmpty ||
        durationMillis < minimumSessionDuration.inMilliseconds) {
      return;
    }

    final clampedStartRatio =
        input.startPositionRatio.clamp(0.0, 1.0).toDouble();
    final clampedEndRatio = input.endPositionRatio.clamp(0.0, 1.0).toDouble();
    final dateKey = _dateKeyFor(input.endAt);

    await _database.transaction(() async {
      await _database.insertReadingRecordSession(
        ReadingRecordSession(
          id: 0,
          bookId: normalizedBookId,
          sourceId: normalizedSourceId,
          detailUrl: normalizedDetailUrl,
          bookTitle: normalizedTitle,
          bookAuthor: input.bookAuthor?.trim(),
          coverUrl: input.coverUrl?.trim(),
          chapterId: input.chapterId?.trim(),
          chapterTitle: input.chapterTitle?.trim(),
          chapterIndex: input.chapterIndex,
          chapterUrl: input.chapterUrl?.trim(),
          startAt: input.startAt,
          endAt: input.endAt,
          durationMillis: durationMillis,
          readChars: safeReadChars,
          startPositionRatio: clampedStartRatio,
          endPositionRatio: clampedEndRatio,
        ),
      );

      final existingRecord = await _database.getReadingRecordByBookId(
        normalizedBookId,
      );
      await _database.upsertReadingRecord(
        ReadingRecord(
          bookId: normalizedBookId,
          sourceId: normalizedSourceId,
          detailUrl: normalizedDetailUrl,
          bookTitle: normalizedTitle,
          bookAuthor: input.bookAuthor?.trim(),
          coverUrl: input.coverUrl?.trim(),
          lastChapterId: input.chapterId?.trim(),
          lastChapterTitle: input.chapterTitle?.trim(),
          lastChapterIndex: input.chapterIndex,
          lastChapterUrl: input.chapterUrl?.trim(),
          lastPositionRatio: clampedEndRatio,
          totalReadMillis:
              (existingRecord?.totalReadMillis ?? 0) + durationMillis,
          totalReadChars: (existingRecord?.totalReadChars ?? 0) + safeReadChars,
          lastReadAt: input.endAt,
        ),
      );

      final existingDay = await _database.getReadingRecordDay(
        bookId: normalizedBookId,
        dateKey: dateKey,
      );
      await _database.upsertReadingRecordDay(
        ReadingRecordDay(
          bookId: normalizedBookId,
          dateKey: dateKey,
          bookTitle: normalizedTitle,
          bookAuthor: input.bookAuthor?.trim(),
          coverUrl: input.coverUrl?.trim(),
          readMillis: (existingDay?.readMillis ?? 0) + durationMillis,
          readChars: (existingDay?.readChars ?? 0) + safeReadChars,
          firstReadAt:
              existingDay == null
                  ? input.startAt
                  : _earlier(existingDay.firstReadAt, input.startAt),
          lastReadAt:
              existingDay == null
                  ? input.endAt
                  : _later(existingDay.lastReadAt, input.endAt),
        ),
      );
    });
  }

  DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  String _normalizeMergeText(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  Future<void> _rebuildAggregatesForBook(String bookId) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return;
    }

    final sessions = await _database.listReadingRecordSessionsByBookId(
      normalizedBookId,
    );

    await _database.deleteReadingRecordByBookId(normalizedBookId);
    await _database.deleteReadingRecordDaysByBookId(normalizedBookId);

    if (sessions.isEmpty) {
      return;
    }

    final latestSession = sessions.reduce(
      (current, next) => current.endAt.isAfter(next.endAt) ? current : next,
    );
    final totalReadMillis = sessions.fold<int>(
      0,
      (sum, item) => sum + (item.durationMillis < 0 ? 0 : item.durationMillis),
    );
    final totalReadChars = sessions.fold<int>(
      0,
      (sum, item) => sum + (item.readChars < 0 ? 0 : item.readChars),
    );

    await _database.upsertReadingRecord(
      ReadingRecord(
        bookId: normalizedBookId,
        sourceId: latestSession.sourceId.trim(),
        detailUrl: latestSession.detailUrl.trim(),
        bookTitle: latestSession.bookTitle.trim(),
        bookAuthor: latestSession.bookAuthor?.trim(),
        coverUrl: latestSession.coverUrl?.trim(),
        lastChapterId: latestSession.chapterId?.trim(),
        lastChapterTitle: latestSession.chapterTitle?.trim(),
        lastChapterIndex: latestSession.chapterIndex,
        lastChapterUrl: latestSession.chapterUrl?.trim(),
        lastPositionRatio:
            latestSession.endPositionRatio.clamp(0.0, 1.0).toDouble(),
        totalReadMillis: totalReadMillis,
        totalReadChars: totalReadChars,
        lastReadAt: latestSession.endAt,
      ),
    );

    final sessionsByDate = <String, List<ReadingRecordSession>>{};
    for (final session in sessions) {
      final dateKey = _dateKeyFor(session.endAt);
      sessionsByDate
          .putIfAbsent(dateKey, () => <ReadingRecordSession>[])
          .add(session);
    }

    for (final entry in sessionsByDate.entries) {
      final groupedSessions = entry.value;
      final latestDaySession = groupedSessions.reduce(
        (current, next) => current.endAt.isAfter(next.endAt) ? current : next,
      );
      final readMillis = groupedSessions.fold<int>(
        0,
        (sum, item) =>
            sum + (item.durationMillis < 0 ? 0 : item.durationMillis),
      );
      final readChars = groupedSessions.fold<int>(
        0,
        (sum, item) => sum + (item.readChars < 0 ? 0 : item.readChars),
      );
      final firstReadAt = groupedSessions
          .map((item) => item.startAt)
          .reduce(_earlier);
      final lastReadAt = groupedSessions
          .map((item) => item.endAt)
          .reduce(_later);

      await _database.upsertReadingRecordDay(
        ReadingRecordDay(
          bookId: normalizedBookId,
          dateKey: entry.key,
          bookTitle: latestDaySession.bookTitle.trim(),
          bookAuthor: latestDaySession.bookAuthor?.trim(),
          coverUrl: latestDaySession.coverUrl?.trim(),
          readMillis: readMillis,
          readChars: readChars,
          firstReadAt: firstReadAt,
          lastReadAt: lastReadAt,
        ),
      );
    }
  }

  String _dateKeyFor(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
