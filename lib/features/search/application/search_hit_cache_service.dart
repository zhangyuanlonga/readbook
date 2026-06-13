import '../../../core/cache/cache_entry.dart';
import '../../../core/cache/cache_key.dart';
import '../../../core/cache/cache_policy.dart';
import '../../../core/cache/cache_result.dart';
import '../../../core/cache/cache_scope.dart';
import '../../../core/cache/cache_store.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/book.dart';

class SearchHitCacheKeyBuilder {
  const SearchHitCacheKeyBuilder();

  AppCacheKey build({
    String? userId,
    required String titleNorm,
    required String authorNorm,
    String? sourceId,
  }) {
    return AppCacheKey(
      scope: AppCacheScope.searchHit,
      owner: (userId?.trim().isNotEmpty ?? false) ? userId!.trim() : 'search',
      parts: <String, Object?>{
        'titleNorm': titleNorm,
        'authorNorm': authorNorm,
        if (sourceId != null && sourceId.trim().isNotEmpty)
          'sourceId': sourceId,
      },
    );
  }
}

class SearchHitCacheService implements AppCacheStore {
  SearchHitCacheService({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;
  static const int _schemaVersion = 1;
  static const SearchHitCacheKeyBuilder keyBuilder = SearchHitCacheKeyBuilder();

  static final RegExp _spacePattern = RegExp(r'[\u3000\s]+');
  static final RegExp _symbolPattern = RegExp(
    r'''[·•\-_:：|/\\\(\)\[\]【】<>《》"'‘’,.，。!?！？]''',
  );
  static final RegExp _chapterPattern = RegExp(r'第?\s*(\d{1,6})\s*章');
  static final RegExp _numberPattern = RegExp(r'(\d{1,6})');

  Future<void> recordBooks(
    Iterable<Book> books, {
    Map<String, String> sourceNames = const <String, String>{},
  }) async {
    final aggregated = <String, _SearchSourceHitAccumulator>{};

    for (final book in books) {
      final sourceId = book.sourceId.trim();
      final titleNorm = normalizeText(book.title);
      if (sourceId.isEmpty || titleNorm.isEmpty) {
        continue;
      }

      final authorNorm = normalizeText(book.author ?? '');
      final key = '$titleNorm|$authorNorm|$sourceId';
      final incomingLatestNo = _extractLatestChapterNumber(book.latestChapter);

      final existing = aggregated[key];
      if (existing == null) {
        aggregated[key] = _SearchSourceHitAccumulator(
          titleNorm: titleNorm,
          authorNorm: authorNorm,
          sourceId: sourceId,
          sourceName: (sourceNames[sourceId] ?? '').trim(),
          title: book.title.trim(),
          author: book.author?.trim(),
          latestChapter: book.latestChapter?.trim(),
          latestChapterNo: incomingLatestNo,
          hitIncrement: 1,
        );
        continue;
      }

      aggregated[key] = existing.mergeWith(
        sourceName: (sourceNames[sourceId] ?? '').trim(),
        title: book.title.trim(),
        author: book.author?.trim(),
        latestChapter: book.latestChapter?.trim(),
        latestChapterNo: incomingLatestNo,
      );
    }

    if (aggregated.isEmpty) {
      return;
    }

    final upserts = aggregated.values
        .map(
          (item) => SearchSourceHitUpsert(
            titleNorm: item.titleNorm,
            authorNorm: item.authorNorm,
            sourceId: item.sourceId,
            sourceName: item.sourceName,
            title: item.title,
            author: item.author,
            latestChapter: item.latestChapter,
            latestChapterNo: item.latestChapterNo,
            hitIncrement: item.hitIncrement,
          ),
        )
        .toList(growable: false);

    await _database.upsertSearchSourceHits(upserts);
  }

  Future<Map<String, int>> loadSourceHitCounts({
    required String title,
    String? author,
  }) {
    return _database.getSearchSourceHitCounts(
      titleNorm: normalizeText(title),
      authorNorm: normalizeText(author ?? ''),
    );
  }

  @override
  AppCacheScope get scope => AppCacheScope.searchHit;

  @override
  String get backendName => 'drift.search_source_hits';

  @override
  Future<AppCacheReadResult> read(
    AppCacheKey key, {
    AppCachePolicy? policy,
  }) async {
    final stopwatch = Stopwatch()..start();
    final titleNorm = key.parts['titleNorm'] ?? '';
    final authorNorm = key.parts['authorNorm'] ?? '';
    final sourceId = key.parts['sourceId'];
    if (titleNorm.isEmpty) {
      return AppCacheReadResult.miss(
        key: key,
        backend: backendName,
        cost: stopwatch.elapsed,
      );
    }
    try {
      final rows = await _database.listSearchSourceHits(
        titleNorm: titleNorm,
        authorNorm: authorNorm,
        sourceId: sourceId,
      );
      if (rows.isEmpty) {
        return AppCacheReadResult.miss(
          key: key,
          backend: backendName,
          cost: stopwatch.elapsed,
        );
      }
      final entry = _entryForRows(key: key, rows: rows, policy: policy);
      final expectedVersion = policy?.version ?? _schemaVersion;
      if (!entry.hasVersion(expectedVersion)) {
        return AppCacheReadResult.versionMismatch(
          key: key,
          backend: backendName,
          entry: entry,
          cost: stopwatch.elapsed,
        );
      }
      if (entry.isExpired(DateTime.now())) {
        return AppCacheReadResult.stale(
          key: key,
          backend: backendName,
          entry: entry,
          invalidReason: AppCacheInvalidReason.ttlExpired,
          cost: stopwatch.elapsed,
        );
      }
      return AppCacheReadResult.hit(
        key: key,
        backend: backendName,
        entry: entry,
        cost: stopwatch.elapsed,
      );
    } catch (error, stackTrace) {
      return AppCacheReadResult.backendError(
        key: key,
        backend: backendName,
        error: error,
        stackTrace: stackTrace,
        cost: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<AppCacheWriteResult> write(
    AppCacheEntry entry, {
    AppCachePolicy? policy,
  }) async {
    final stopwatch = Stopwatch()..start();
    final payload = entry.payload;
    try {
      if (payload is SearchSourceHitUpsert) {
        await _database.upsertSearchSourceHits(<SearchSourceHitUpsert>[
          payload,
        ]);
      } else if (payload is Iterable<SearchSourceHitUpsert>) {
        await _database.upsertSearchSourceHits(payload.toList(growable: false));
      } else {
        return AppCacheWriteResult.skipped(
          key: entry.key,
          backend: backendName,
          cost: stopwatch.elapsed,
        );
      }
      return AppCacheWriteResult.written(
        key: entry.key,
        backend: backendName,
        sizeBytes: entry.sizeBytes,
        cost: stopwatch.elapsed,
      );
    } catch (error, stackTrace) {
      return AppCacheWriteResult.backendError(
        key: entry.key,
        backend: backendName,
        error: error,
        stackTrace: stackTrace,
        cost: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<AppCacheDeleteResult> delete(AppCacheKey key) async {
    final stopwatch = Stopwatch()..start();
    try {
      final deleted = await _database.deleteSearchSourceHits(
        titleNorm: key.parts['titleNorm'],
        authorNorm: key.parts['authorNorm'],
        sourceId: key.parts['sourceId'],
      );
      return AppCacheDeleteResult.deleted(
        scope: scope,
        backend: backendName,
        key: key,
        deletedEntries: deleted,
        cost: stopwatch.elapsed,
      );
    } catch (error, stackTrace) {
      return AppCacheDeleteResult.backendError(
        scope: scope,
        backend: backendName,
        key: key,
        error: error,
        stackTrace: stackTrace,
        cost: stopwatch.elapsed,
      );
    }
  }

  @override
  Future<AppCacheDeleteResult> clearScope({String? owner}) async {
    final stopwatch = Stopwatch()..start();
    final deleted = await _database.clearSearchSourceHits();
    return AppCacheDeleteResult.deleted(
      scope: scope,
      backend: backendName,
      deletedEntries: deleted,
      cost: stopwatch.elapsed,
    );
  }

  @override
  Future<AppCacheStats> stats({String? owner}) async {
    return AppCacheStats(
      scope: scope,
      backend: backendName,
      entries: await _database.countSearchSourceHits(),
      bytes: await _database.estimateSearchSourceHitsBytes(),
    );
  }

  @override
  Future<AppCachePruneResult> prune(AppCachePolicy policy) async {
    final stopwatch = Stopwatch()..start();
    final deleted = await _database.pruneSearchSourceHitsByBudget(
      maxEntries: policy.maxEntries ?? 0,
      maxBytes: policy.maxBytes ?? 0,
      stalePeriod: policy.ttl,
    );
    return AppCachePruneResult(
      scope: scope,
      backend: backendName,
      deletedEntries: deleted,
      cost: stopwatch.elapsed,
    );
  }

  String normalizeText(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll(_spacePattern, '')
        .replaceAll(_symbolPattern, '');
  }

  int? _extractLatestChapterNumber(String? rawText) {
    final text = rawText?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }

    final chapterMatch = _chapterPattern.firstMatch(text);
    if (chapterMatch != null) {
      return int.tryParse(chapterMatch.group(1) ?? '');
    }

    final fallback = _numberPattern.firstMatch(text);
    if (fallback != null) {
      return int.tryParse(fallback.group(1) ?? '');
    }
    return null;
  }

  AppCacheEntry _entryForRows({
    required AppCacheKey key,
    required List<SearchSourceHit> rows,
    AppCachePolicy? policy,
  }) {
    var createdAt = rows.first.createdAt;
    var updatedAt = rows.first.updatedAt;
    for (final row in rows.skip(1)) {
      if (row.createdAt.isBefore(createdAt)) {
        createdAt = row.createdAt;
      }
      if (row.updatedAt.isAfter(updatedAt)) {
        updatedAt = row.updatedAt;
      }
    }
    final payload =
        key.parts['sourceId'] == null
            ? <String, int>{for (final row in rows) row.sourceId: row.hitCount}
            : rows.first.hitCount;
    return AppCacheEntry(
      key: key,
      payload: payload,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastAccessedAt: DateTime.now(),
      expiresAt: (policy ?? AppCachePolicies.searchHit).expiresAtFor(updatedAt),
      version: _schemaVersion,
      sizeBytes: rows.fold<int>(
        0,
        (sum, row) =>
            sum +
            row.titleNorm.length +
            row.authorNorm.length +
            row.sourceId.length +
            row.sourceName.length +
            row.title.length +
            (row.author?.length ?? 0) +
            (row.latestChapter?.length ?? 0),
      ),
      metadata: <String, Object?>{
        'titleNorm': rows.first.titleNorm,
        'authorNorm': rows.first.authorNorm,
        'sourceIds': rows.map((row) => row.sourceId).join(','),
      },
    );
  }
}

class _SearchSourceHitAccumulator {
  const _SearchSourceHitAccumulator({
    required this.titleNorm,
    required this.authorNorm,
    required this.sourceId,
    required this.sourceName,
    required this.title,
    required this.author,
    required this.latestChapter,
    required this.latestChapterNo,
    required this.hitIncrement,
  });

  final String titleNorm;
  final String authorNorm;
  final String sourceId;
  final String sourceName;
  final String title;
  final String? author;
  final String? latestChapter;
  final int? latestChapterNo;
  final int hitIncrement;

  _SearchSourceHitAccumulator mergeWith({
    required String sourceName,
    required String title,
    required String? author,
    required String? latestChapter,
    required int? latestChapterNo,
  }) {
    final pickLatestByNumber =
        latestChapterNo != null &&
        (this.latestChapterNo == null ||
            latestChapterNo > this.latestChapterNo!);
    return _SearchSourceHitAccumulator(
      titleNorm: titleNorm,
      authorNorm: authorNorm,
      sourceId: sourceId,
      sourceName: sourceName.isEmpty ? this.sourceName : sourceName,
      title: title.isEmpty ? this.title : title,
      author: (author == null || author.isEmpty) ? this.author : author,
      latestChapter:
          pickLatestByNumber
              ? latestChapter
              : ((this.latestChapter == null || this.latestChapter!.isEmpty)
                  ? latestChapter
                  : this.latestChapter),
      latestChapterNo:
          pickLatestByNumber
              ? latestChapterNo
              : (this.latestChapterNo ?? latestChapterNo),
      hitIncrement: hitIncrement + 1,
    );
  }
}
