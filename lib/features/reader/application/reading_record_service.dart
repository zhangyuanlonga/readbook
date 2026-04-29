import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/reading_record.dart';
import '../../../domain/entities/reading_record_day.dart';
import '../../../domain/entities/reading_record_session.dart';

enum ReadingRecordMergeRisk { safe, review, blocked }

class ReadingRecordMergeCandidate {
  const ReadingRecordMergeCandidate({
    required this.record,
    required this.risk,
    required this.hint,
    required this.sortScore,
  });

  final ReadingRecord record;
  final ReadingRecordMergeRisk risk;
  final String hint;
  final int sortScore;

  bool get requiresExtraConfirmation => risk == ReadingRecordMergeRisk.review;
}

class ReadingRecordMergeCandidatesResult {
  const ReadingRecordMergeCandidatesResult({
    this.candidates = const <ReadingRecordMergeCandidate>[],
    this.blockedCount = 0,
  });

  final List<ReadingRecordMergeCandidate> candidates;
  final int blockedCount;
}

class DeletedReadingRecordSnapshot {
  const DeletedReadingRecordSnapshot({
    required this.record,
    required this.days,
    required this.sessions,
  });

  final ReadingRecord record;
  final List<ReadingRecordDay> days;
  final List<ReadingRecordSession> sessions;
}

class DeletedReadingRecordDaySnapshot {
  const DeletedReadingRecordDaySnapshot({
    required this.day,
    required this.sessions,
  });

  final ReadingRecordDay day;
  final List<ReadingRecordSession> sessions;
}

class DeletedReadingRecordSessionSnapshot {
  const DeletedReadingRecordSessionSnapshot({required this.session});

  final ReadingRecordSession session;
}

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
  static const int minimumMeaningfulReadChars = 200;
  static const double minimumMeaningfulProgressDelta = 0.08;

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

  Future<List<ReadingRecord>> listLatestRecords({String query = ''}) {
    return _database.listLatestReadingRecords(query: query);
  }

  Future<List<ReadingRecordDay>> listAllDays() {
    return _database.listAllReadingRecordDays();
  }

  Future<List<ReadingRecordSession>> listAllSessions() {
    return _database.listAllReadingRecordSessions();
  }

  Future<ReadingRecordMergeCandidatesResult> getMergeCandidates(
    ReadingRecord target,
  ) async {
    final normalizedTitle = _normalizeMergeText(target.bookTitle);
    if (normalizedTitle.isEmpty) {
      return const ReadingRecordMergeCandidatesResult();
    }

    final records = await _database.listLatestReadingRecords();
    final candidates = <ReadingRecordMergeCandidate>[];
    var blockedCount = 0;

    for (final item in records) {
      if (item.bookId == target.bookId) {
        continue;
      }
      if (_normalizeMergeText(item.bookTitle) != normalizedTitle) {
        continue;
      }

      final candidate = _buildMergeCandidate(target: target, candidate: item);
      if (candidate == null) {
        blockedCount += 1;
        continue;
      }
      candidates.add(candidate);
    }

    candidates.sort((a, b) {
      final scoreCompare = b.sortScore.compareTo(a.sortScore);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      final lastReadCompare = b.record.lastReadAt.compareTo(
        a.record.lastReadAt,
      );
      if (lastReadCompare != 0) {
        return lastReadCompare;
      }
      final durationCompare = b.record.totalReadMillis.compareTo(
        a.record.totalReadMillis,
      );
      if (durationCompare != 0) {
        return durationCompare;
      }
      return a.record.bookId.compareTo(b.record.bookId);
    });

    return ReadingRecordMergeCandidatesResult(
      candidates: List<ReadingRecordMergeCandidate>.unmodifiable(candidates),
      blockedCount: blockedCount,
    );
  }

  Future<void> mergeRecords({
    required ReadingRecord target,
    required List<ReadingRecord> sources,
  }) async {
    final targetRecord =
        await _database.getReadingRecordByBookId(target.bookId) ?? target;
    final uniqueSources = <String, ReadingRecord>{
          for (final source in sources)
            if (source.bookId != target.bookId) source.bookId: source,
        }.values
        .where((source) {
          return _buildMergeCandidate(target: target, candidate: source) !=
              null;
        })
        .toList(growable: false);
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

      await _rebuildAggregatesForBook(
        target.bookId,
        identityRecord: target,
        fallbackLocationRecord: targetRecord,
      );
    });
  }

  Future<void> deleteRecord(ReadingRecord record) async {
    await _database.deleteReadingRecordsByBookId(record.bookId);
  }

  Future<DeletedReadingRecordSnapshot?> deleteRecordWithSnapshot(
    ReadingRecord record,
  ) async {
    final currentRecord = await _database.getReadingRecordByBookId(
      record.bookId,
    );
    if (currentRecord == null) {
      return null;
    }
    final days = await _database.listReadingRecordDaysByBookId(record.bookId);
    final sessions = await _database.listReadingRecordSessionsByBookId(
      record.bookId,
    );
    await _database.deleteReadingRecordsByBookId(record.bookId);
    return DeletedReadingRecordSnapshot(
      record: currentRecord,
      days: days,
      sessions: sessions,
    );
  }

  Future<void> restoreDeletedRecord(
    DeletedReadingRecordSnapshot snapshot,
  ) async {
    await _database.transaction(() async {
      await _database.upsertReadingRecord(snapshot.record);
      for (final day in snapshot.days) {
        await _database.upsertReadingRecordDay(day);
      }
      for (final session in snapshot.sessions) {
        await _database.updateReadingRecordSession(session);
      }
    });
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

  Future<DeletedReadingRecordDaySnapshot?> deleteDayRecordWithSnapshot(
    ReadingRecordDay day,
  ) async {
    final normalizedBookId = day.bookId.trim();
    final normalizedDateKey = day.dateKey.trim();
    if (normalizedBookId.isEmpty || normalizedDateKey.isEmpty) {
      return null;
    }

    final currentDay = await _database.getReadingRecordDay(
      bookId: normalizedBookId,
      dateKey: normalizedDateKey,
    );
    if (currentDay == null) {
      return null;
    }
    final sessions = await _database.listReadingRecordSessionsByBookIdAndDate(
      bookId: normalizedBookId,
      dateKey: normalizedDateKey,
    );

    await deleteDayRecord(day);
    return DeletedReadingRecordDaySnapshot(day: currentDay, sessions: sessions);
  }

  Future<void> restoreDeletedDayRecord(
    DeletedReadingRecordDaySnapshot snapshot,
  ) async {
    await _database.transaction(() async {
      await _database.upsertReadingRecordDay(snapshot.day);
      for (final session in snapshot.sessions) {
        await _database.updateReadingRecordSession(session);
      }
      await _rebuildAggregatesForBook(snapshot.day.bookId);
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

  Future<DeletedReadingRecordSessionSnapshot?> deleteSessionWithSnapshot(
    ReadingRecordSession session,
  ) async {
    final normalizedBookId = session.bookId.trim();
    if (normalizedBookId.isEmpty || session.id <= 0) {
      return null;
    }

    await deleteSession(session);
    return DeletedReadingRecordSessionSnapshot(session: session);
  }

  Future<void> reassignBookIdentity({
    required String previousBookId,
    required String nextBookId,
    required String nextSourceId,
    required String nextDetailUrl,
    required String nextBookTitle,
    String? nextBookAuthor,
    String? nextCoverUrl,
  }) async {
    final normalizedPreviousBookId = previousBookId.trim();
    final normalizedNextBookId = nextBookId.trim();
    final normalizedNextSourceId = nextSourceId.trim();
    final normalizedNextDetailUrl = nextDetailUrl.trim();
    final normalizedNextTitle = nextBookTitle.trim();
    if (normalizedPreviousBookId.isEmpty ||
        normalizedNextBookId.isEmpty ||
        normalizedNextSourceId.isEmpty ||
        normalizedNextDetailUrl.isEmpty ||
        normalizedNextTitle.isEmpty ||
        normalizedPreviousBookId == normalizedNextBookId) {
      return;
    }

    final sourceSessions = await _database.listReadingRecordSessionsByBookId(
      normalizedPreviousBookId,
    );
    final sourceRecord = await _database.getReadingRecordByBookId(
      normalizedPreviousBookId,
    );
    final sourceDays = await _database.listReadingRecordDaysByBookId(
      normalizedPreviousBookId,
    );
    if (sourceSessions.isEmpty && sourceRecord == null && sourceDays.isEmpty) {
      return;
    }

    final normalizedNextAuthor = _normalizeOptionalText(nextBookAuthor);
    final normalizedNextCoverUrl = _normalizeOptionalText(nextCoverUrl);
    final firstSession = sourceSessions.isEmpty ? null : sourceSessions.first;
    final lastSession = sourceSessions.isEmpty ? null : sourceSessions.last;

    await _database.transaction(() async {
      for (final session in sourceSessions) {
        await _database.updateReadingRecordSession(
          ReadingRecordSession(
            id: session.id,
            bookId: normalizedNextBookId,
            sourceId: normalizedNextSourceId,
            detailUrl: normalizedNextDetailUrl,
            bookTitle: normalizedNextTitle,
            bookAuthor: normalizedNextAuthor ?? session.bookAuthor,
            coverUrl: normalizedNextCoverUrl ?? session.coverUrl,
            chapterId: session.chapterId,
            chapterTitle: session.chapterTitle,
            chapterIndex: session.chapterIndex,
            chapterUrl: session.chapterUrl,
            startAt: session.startAt,
            endAt: session.endAt,
            durationMillis: session.durationMillis,
            readChars: session.readChars,
            startPositionRatio: session.startPositionRatio,
            endPositionRatio: session.endPositionRatio,
          ),
        );
      }

      await _database.deleteReadingRecordByBookId(normalizedPreviousBookId);
      await _database.deleteReadingRecordDaysByBookId(normalizedPreviousBookId);

      final targetIdentity = ReadingRecord(
        bookId: normalizedNextBookId,
        sourceId: normalizedNextSourceId,
        detailUrl: normalizedNextDetailUrl,
        bookTitle: normalizedNextTitle,
        bookAuthor:
            normalizedNextAuthor ??
            sourceRecord?.bookAuthor ??
            firstSession?.bookAuthor,
        coverUrl:
            normalizedNextCoverUrl ??
            sourceRecord?.coverUrl ??
            firstSession?.coverUrl,
        lastReadAt:
            sourceRecord?.lastReadAt ?? lastSession?.endAt ?? DateTime.now(),
      );

      await _rebuildAggregatesForBook(
        normalizedNextBookId,
        identityRecord: targetIdentity,
        fallbackLocationRecord: sourceRecord,
      );
    });
  }

  Future<void> restoreDeletedSession(
    DeletedReadingRecordSessionSnapshot snapshot,
  ) async {
    await _database.transaction(() async {
      await _database.updateReadingRecordSession(snapshot.session);
      await _rebuildAggregatesForBook(snapshot.session.bookId);
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
        normalizedTitle.isEmpty) {
      return;
    }

    final shortButMeaningful =
        safeReadChars >= minimumMeaningfulReadChars ||
        _readingProgressDelta(input) >= minimumMeaningfulProgressDelta;
    if (durationMillis < minimumSessionDuration.inMilliseconds &&
        !shortButMeaningful) {
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

  Future<void> syncBookPresentation({
    required String bookId,
    required String bookTitle,
    String? bookAuthor,
    String? coverUrl,
  }) async {
    final normalizedBookId = bookId.trim();
    final normalizedTitle = bookTitle.trim();
    final normalizedAuthor = _normalizeOptionalText(bookAuthor);
    final normalizedCoverUrl = _normalizeOptionalText(coverUrl);
    if (normalizedBookId.isEmpty || normalizedTitle.isEmpty) {
      return;
    }

    final existingRecord = await _database.getReadingRecordByBookId(
      normalizedBookId,
    );
    final existingDays = await _database.listReadingRecordDaysByBookId(
      normalizedBookId,
    );
    final existingSessions = await _database.listReadingRecordSessionsByBookId(
      normalizedBookId,
    );
    if (existingRecord == null &&
        existingDays.isEmpty &&
        existingSessions.isEmpty) {
      return;
    }

    await _database.transaction(() async {
      if (existingRecord != null) {
        await _database.upsertReadingRecord(
          ReadingRecord(
            bookId: existingRecord.bookId,
            sourceId: existingRecord.sourceId,
            detailUrl: existingRecord.detailUrl,
            bookTitle: normalizedTitle,
            bookAuthor: normalizedAuthor,
            coverUrl: normalizedCoverUrl,
            lastChapterId: existingRecord.lastChapterId,
            lastChapterTitle: existingRecord.lastChapterTitle,
            lastChapterIndex: existingRecord.lastChapterIndex,
            lastChapterUrl: existingRecord.lastChapterUrl,
            lastPositionRatio: existingRecord.lastPositionRatio,
            totalReadMillis: existingRecord.totalReadMillis,
            totalReadChars: existingRecord.totalReadChars,
            lastReadAt: existingRecord.lastReadAt,
          ),
        );
      }

      for (final day in existingDays) {
        await _database.upsertReadingRecordDay(
          ReadingRecordDay(
            bookId: day.bookId,
            dateKey: day.dateKey,
            bookTitle: normalizedTitle,
            bookAuthor: normalizedAuthor,
            coverUrl: normalizedCoverUrl,
            readMillis: day.readMillis,
            readChars: day.readChars,
            firstReadAt: day.firstReadAt,
            lastReadAt: day.lastReadAt,
          ),
        );
      }

      for (final session in existingSessions) {
        await _database.updateReadingRecordSession(
          ReadingRecordSession(
            id: session.id,
            bookId: session.bookId,
            sourceId: session.sourceId,
            detailUrl: session.detailUrl,
            bookTitle: normalizedTitle,
            bookAuthor: normalizedAuthor,
            coverUrl: normalizedCoverUrl,
            chapterId: session.chapterId,
            chapterTitle: session.chapterTitle,
            chapterIndex: session.chapterIndex,
            chapterUrl: session.chapterUrl,
            startAt: session.startAt,
            endAt: session.endAt,
            durationMillis: session.durationMillis,
            readChars: session.readChars,
            startPositionRatio: session.startPositionRatio,
            endPositionRatio: session.endPositionRatio,
          ),
        );
      }
    });
  }

  Future<void> replaceRemoteScopedHistoryFromSync(
    List<ReadingRecordSession> syncedSessions,
  ) async {
    final existingSessions = await _database.listAllReadingRecordSessions();
    final existingRemoteBookIds =
        existingSessions
            .where((item) => item.sourceId.trim() != '__local_book__')
            .map((item) => item.bookId.trim())
            .where((item) => item.isNotEmpty)
            .toSet();
    final nextRemoteBookIds =
        syncedSessions
            .where((item) => item.sourceId.trim() != '__local_book__')
            .map((item) => item.bookId.trim())
            .where((item) => item.isNotEmpty)
            .toSet();
    final affectedBookIds = <String>{
      ...existingRemoteBookIds,
      ...nextRemoteBookIds,
    };
    if (affectedBookIds.isEmpty) {
      return;
    }

    final sessionsByBookId = <String, List<ReadingRecordSession>>{};
    for (final session in syncedSessions) {
      final normalizedBookId = session.bookId.trim();
      if (normalizedBookId.isEmpty ||
          session.sourceId.trim() == '__local_book__') {
        continue;
      }
      sessionsByBookId
          .putIfAbsent(normalizedBookId, () => <ReadingRecordSession>[])
          .add(session);
    }

    await _database.transaction(() async {
      for (final bookId in affectedBookIds) {
        await _database.deleteReadingRecordsByBookId(bookId);
      }
      for (final entry in sessionsByBookId.entries) {
        for (final session in entry.value) {
          await _database.insertReadingRecordSession(
            ReadingRecordSession(
              id: 0,
              bookId: session.bookId,
              sourceId: session.sourceId,
              detailUrl: session.detailUrl,
              bookTitle: session.bookTitle,
              bookAuthor: session.bookAuthor,
              coverUrl: session.coverUrl,
              chapterId: session.chapterId,
              chapterTitle: session.chapterTitle,
              chapterIndex: session.chapterIndex,
              chapterUrl: session.chapterUrl,
              startAt: session.startAt,
              endAt: session.endAt,
              durationMillis: session.durationMillis,
              readChars: session.readChars,
              startPositionRatio: session.startPositionRatio,
              endPositionRatio: session.endPositionRatio,
            ),
          );
        }
        await _rebuildAggregatesForBook(entry.key);
      }
    });
  }

  double _readingProgressDelta(ReadingRecordCommitInput input) {
    final start = input.startPositionRatio.clamp(0.0, 1.0).toDouble();
    final end = input.endPositionRatio.clamp(0.0, 1.0).toDouble();
    return (end - start).abs();
  }

  DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  ReadingRecordSession? _latestSessionWithCover(
    List<ReadingRecordSession> sessions,
  ) {
    ReadingRecordSession? latest;
    for (final session in sessions) {
      final coverUrl = session.coverUrl?.trim() ?? '';
      if (coverUrl.isEmpty) {
        continue;
      }
      if (latest == null || session.endAt.isAfter(latest.endAt)) {
        latest = session;
      }
    }
    return latest;
  }

  ReadingRecordSession? _latestSessionWithAuthor(
    List<ReadingRecordSession> sessions,
  ) {
    ReadingRecordSession? latest;
    for (final session in sessions) {
      final author = session.bookAuthor?.trim() ?? '';
      if (author.isEmpty) {
        continue;
      }
      if (latest == null || session.endAt.isAfter(latest.endAt)) {
        latest = session;
      }
    }
    return latest;
  }

  String _normalizeMergeText(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  ReadingRecordMergeCandidate? _buildMergeCandidate({
    required ReadingRecord target,
    required ReadingRecord candidate,
  }) {
    final normalizedTargetAuthor = _normalizeMergeAuthor(target.bookAuthor);
    final normalizedCandidateAuthor = _normalizeMergeAuthor(
      candidate.bookAuthor,
    );

    if (normalizedTargetAuthor.isNotEmpty &&
        normalizedCandidateAuthor.isNotEmpty) {
      if (normalizedTargetAuthor == normalizedCandidateAuthor) {
        return ReadingRecordMergeCandidate(
          record: candidate,
          risk: ReadingRecordMergeRisk.safe,
          hint: '书名与作者一致，合并风险较低。',
          sortScore: 300,
        );
      }
      if (_looksLikeAuthorAlias(
        normalizedTargetAuthor,
        normalizedCandidateAuthor,
      )) {
        return ReadingRecordMergeCandidate(
          record: candidate,
          risk: ReadingRecordMergeRisk.review,
          hint: '作者写法接近，请先确认不是同名不同书。',
          sortScore: 220,
        );
      }
      return null;
    }

    if (normalizedTargetAuthor.isEmpty && normalizedCandidateAuthor.isEmpty) {
      return ReadingRecordMergeCandidate(
        record: candidate,
        risk: ReadingRecordMergeRisk.review,
        hint: '双方都缺少作者信息，请结合封面和最近阅读时间确认。',
        sortScore: 120,
      );
    }

    return ReadingRecordMergeCandidate(
      record: candidate,
      risk: ReadingRecordMergeRisk.review,
      hint: '其中一条缺少作者信息，请确认不是同名不同书。',
      sortScore: 180,
    );
  }

  String _normalizeMergeAuthor(String? value) {
    final normalized = (value ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'''[\s\-_:：·•,，.。/\\'"“”‘’（）()\[\]【】《》]+'''), '')
        .replaceAll(RegExp(r'(作者|著)$'), '');
    return normalized;
  }

  bool _looksLikeAuthorAlias(String a, String b) {
    if (a.isEmpty || b.isEmpty) {
      return false;
    }
    if (a == b) {
      return true;
    }
    final minLength = a.length < b.length ? a.length : b.length;
    if (minLength < 2) {
      return false;
    }
    return a.contains(b) || b.contains(a);
  }

  Future<void> _rebuildAggregatesForBook(
    String bookId, {
    ReadingRecord? identityRecord,
    ReadingRecord? fallbackLocationRecord,
  }) async {
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
    final latestSessionWithCover = _latestSessionWithCover(sessions);
    final latestSessionWithAuthor = _latestSessionWithAuthor(sessions);
    final totalReadMillis = sessions.fold<int>(
      0,
      (sum, item) => sum + (item.durationMillis < 0 ? 0 : item.durationMillis),
    );
    final totalReadChars = sessions.fold<int>(
      0,
      (sum, item) => sum + (item.readChars < 0 ? 0 : item.readChars),
    );

    final rebuiltRecord = ReadingRecord(
      bookId: normalizedBookId,
      sourceId: latestSession.sourceId.trim(),
      detailUrl: latestSession.detailUrl.trim(),
      bookTitle: latestSession.bookTitle.trim(),
      bookAuthor:
          latestSessionWithAuthor?.bookAuthor?.trim() ??
          latestSession.bookAuthor?.trim(),
      coverUrl:
          latestSessionWithCover?.coverUrl?.trim() ??
          latestSession.coverUrl?.trim(),
      lastChapterId: latestSession.chapterId?.trim(),
      lastChapterTitle: latestSession.chapterTitle?.trim(),
      lastChapterIndex: latestSession.chapterIndex,
      lastChapterUrl: latestSession.chapterUrl?.trim(),
      lastPositionRatio:
          latestSession.endPositionRatio.clamp(0.0, 1.0).toDouble(),
      totalReadMillis: totalReadMillis,
      totalReadChars: totalReadChars,
      lastReadAt: latestSession.endAt,
    );
    final locationRecord = _selectBetterLocationRecord(
      primary: rebuiltRecord,
      fallback: fallbackLocationRecord,
    );
    final identity = identityRecord ?? rebuiltRecord;

    await _database.upsertReadingRecord(
      ReadingRecord(
        bookId: normalizedBookId,
        sourceId: identity.sourceId.trim(),
        detailUrl: identity.detailUrl.trim(),
        bookTitle: identity.bookTitle.trim(),
        bookAuthor: identity.bookAuthor?.trim(),
        coverUrl: identity.coverUrl?.trim(),
        lastChapterId: locationRecord.lastChapterId?.trim(),
        lastChapterTitle: locationRecord.lastChapterTitle?.trim(),
        lastChapterIndex: locationRecord.lastChapterIndex,
        lastChapterUrl: locationRecord.lastChapterUrl?.trim(),
        lastPositionRatio:
            locationRecord.lastPositionRatio.clamp(0.0, 1.0).toDouble(),
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

  ReadingRecord _selectBetterLocationRecord({
    required ReadingRecord primary,
    ReadingRecord? fallback,
  }) {
    if (fallback == null) {
      return primary;
    }
    return _locationScore(fallback) > _locationScore(primary)
        ? fallback
        : primary;
  }

  int _locationScore(ReadingRecord record) {
    var score = 0;
    final hasChapterId = record.lastChapterId?.trim().isNotEmpty == true;
    final hasChapterUrl = record.lastChapterUrl?.trim().isNotEmpty == true;
    final hasChapterTitle = record.lastChapterTitle?.trim().isNotEmpty == true;
    final hasChapterIndex = record.lastChapterIndex != null;

    if (hasChapterId) {
      score += 4;
    }
    if (hasChapterUrl) {
      score += 4;
    }
    if (hasChapterTitle) {
      score += 2;
    }
    if (hasChapterIndex) {
      score += 1;
    }
    return score;
  }

  String? _normalizeOptionalText(String? value) {
    final normalized = (value ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }
}
