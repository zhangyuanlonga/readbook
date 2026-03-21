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
}
