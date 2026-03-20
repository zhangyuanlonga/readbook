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

  Future<void> commitSession(ReadingRecordCommitInput input) async {
    final normalizedBookId = input.bookId.trim();
    final normalizedSourceId = input.sourceId.trim();
    final normalizedDetailUrl = input.detailUrl.trim();
    final normalizedTitle = input.bookTitle.trim();
    final durationMillis = input.endAt.difference(input.startAt).inMilliseconds;

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

  String _dateKeyFor(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
