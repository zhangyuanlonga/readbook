import 'dart:convert';

import '../../../core/cache/cache_entry.dart';
import '../../../core/cache/cache_key.dart';
import '../../../core/cache/cache_policy.dart';
import '../../../core/cache/cache_result.dart';
import '../../../core/cache/cache_scope.dart';
import '../../../core/cache/cache_store.dart';
import '../../../data/datasources/local/app_database.dart';
import 'reader_gateway_content_cache_codec.dart';

class ReaderChapterContentCacheKeyBuilder {
  const ReaderChapterContentCacheKeyBuilder();

  AppCacheKey build({
    String? bookId,
    required String sourceId,
    required String chapterUrl,
    int? chapterIndex,
  }) {
    return AppCacheKey(
      scope: AppCacheScope.chapterContent,
      owner: _ownerFor(bookId),
      parts: <String, Object?>{
        'sourceId': sourceId,
        'chapterUrl': chapterUrl,
        if (chapterIndex != null) 'chapterIndex': chapterIndex,
      },
    );
  }

  String legacyStorageKey({
    required String sourceId,
    required String chapterUrl,
  }) {
    return '${sourceId.trim()}|${chapterUrl.trim()}';
  }

  String _ownerFor(String? bookId) {
    final normalized = bookId?.trim() ?? '';
    return normalized.isEmpty ? 'reader' : normalized;
  }
}

class ReaderChapterContentCacheStore implements AppCacheStore {
  ReaderChapterContentCacheStore({
    AppDatabase? database,
    ReaderChapterContentCacheKeyBuilder? keyBuilder,
  }) : _database = database ?? AppDatabase.instance,
       _keyBuilder = keyBuilder ?? const ReaderChapterContentCacheKeyBuilder();

  final AppDatabase _database;
  final ReaderChapterContentCacheKeyBuilder _keyBuilder;
  static const int _schemaVersion = 1;

  @override
  AppCacheScope get scope => AppCacheScope.chapterContent;

  @override
  String get backendName => 'drift.chapter_caches';

  @override
  Future<AppCacheReadResult> read(
    AppCacheKey key, {
    AppCachePolicy? policy,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final sourceId = key.parts['sourceId'] ?? '';
      final chapterUrl = key.parts['chapterUrl'] ?? '';
      if (sourceId.isEmpty || chapterUrl.isEmpty) {
        return AppCacheReadResult.miss(
          key: key,
          backend: backendName,
          cost: stopwatch.elapsed,
        );
      }
      final cacheKey = _keyBuilder.legacyStorageKey(
        sourceId: sourceId,
        chapterUrl: chapterUrl,
      );
      final cached = await _database.getChapterCache(cacheKey);
      if (cached == null || cached.content.trim().isEmpty) {
        return AppCacheReadResult.miss(
          key: key,
          backend: backendName,
          cost: stopwatch.elapsed,
        );
      }
      final resolvedPolicy = policy ?? const AppCachePolicy();
      final now = DateTime.now();
      final entry = AppCacheEntry(
        key: key,
        payload: cached.content,
        createdAt: cached.createdAt,
        updatedAt: cached.updatedAt,
        lastAccessedAt: now,
        expiresAt: resolvedPolicy.expiresAtFor(cached.updatedAt),
        version: _schemaVersion,
        sizeBytes: _estimateBytes(cached),
        metadata: <String, Object?>{
          'bookId': cached.bookId,
          'sourceId': cached.sourceId,
          'chapterIndex': cached.chapterIndex,
          'chapterTitle': cached.chapterTitle,
          'chapterUrl': cached.chapterUrl,
          'legacyCacheKey': cached.cacheKey,
        },
      );
      if (!entry.hasVersion(resolvedPolicy.version)) {
        return AppCacheReadResult.versionMismatch(
          key: key,
          backend: backendName,
          entry: entry,
          cost: stopwatch.elapsed,
        );
      }
      final corruptedPayloadError = _tryResolveCorruptedPayload(cached.content);
      if (corruptedPayloadError != null) {
        return AppCacheReadResult.decodeFailed(
          key: key,
          backend: backendName,
          error: corruptedPayloadError,
          cost: stopwatch.elapsed,
        );
      }
      if (entry.isExpired(now)) {
        return AppCacheReadResult.stale(
          key: key,
          backend: backendName,
          entry: entry,
          invalidReason: AppCacheInvalidReason.ttlExpired,
          cost: stopwatch.elapsed,
        );
      }
      await _database.touchChapterCache(cacheKey);
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
    try {
      final sourceId = _metadataText(entry, 'sourceId');
      final chapterUrl = _metadataText(entry, 'chapterUrl');
      final bookId = _metadataText(entry, 'bookId');
      final chapterIndex = entry.metadata['chapterIndex'];
      final content = entry.payload?.toString().trim() ?? '';
      if (sourceId.isEmpty ||
          chapterUrl.isEmpty ||
          bookId.isEmpty ||
          chapterIndex is! int ||
          content.isEmpty) {
        return AppCacheWriteResult.skipped(
          key: entry.key,
          backend: backendName,
          cost: stopwatch.elapsed,
        );
      }
      await _database.upsertChapterCache(
        cacheKey: _keyBuilder.legacyStorageKey(
          sourceId: sourceId,
          chapterUrl: chapterUrl,
        ),
        bookId: bookId,
        sourceId: sourceId,
        chapterIndex: chapterIndex,
        chapterTitle: _metadataText(entry, 'chapterTitle'),
        chapterUrl: chapterUrl,
        content: content,
      );
      return AppCacheWriteResult.written(
        key: entry.key,
        backend: backendName,
        sizeBytes: content.length,
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
      final sourceId = key.parts['sourceId'] ?? '';
      final chapterUrl = key.parts['chapterUrl'] ?? '';
      if (sourceId.isEmpty || chapterUrl.isEmpty) {
        return AppCacheDeleteResult.skipped(
          scope: scope,
          backend: backendName,
          key: key,
          cost: stopwatch.elapsed,
        );
      }
      final deleted = await _database.deleteChapterCache(
        _keyBuilder.legacyStorageKey(
          sourceId: sourceId,
          chapterUrl: chapterUrl,
        ),
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
    if (owner != null && owner.trim().isNotEmpty) {
      await _database.deleteChapterCachesByBookId(owner);
      return AppCacheDeleteResult.deleted(
        scope: scope,
        backend: backendName,
        deletedEntries: 0,
        cost: stopwatch.elapsed,
      );
    }
    final before = await _database.countChapterCaches();
    await _database.clearChapterCaches();
    return AppCacheDeleteResult.deleted(
      scope: scope,
      backend: backendName,
      deletedEntries: before,
      cost: stopwatch.elapsed,
    );
  }

  @override
  Future<AppCacheStats> stats({String? owner}) async {
    final normalizedOwner = owner?.trim() ?? '';
    if (normalizedOwner.isNotEmpty) {
      return AppCacheStats(
        scope: scope,
        backend: backendName,
        entries: await _database.getCachedChapterCount(normalizedOwner),
        bytes: 0,
      );
    }
    return AppCacheStats(
      scope: scope,
      backend: backendName,
      entries: await _database.countChapterCaches(),
      bytes: await _database.estimateChapterCachesBytes(),
    );
  }

  @override
  Future<AppCachePruneResult> prune(AppCachePolicy policy) async {
    final stopwatch = Stopwatch()..start();
    final deleted = await _database.pruneChapterCachesByBudget(
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

  String _metadataText(AppCacheEntry entry, String key) {
    return entry.metadata[key]?.toString().trim() ?? '';
  }

  int _estimateBytes(ChapterCache cached) {
    return cached.cacheKey.length +
        cached.bookId.length +
        cached.sourceId.length +
        (cached.chapterTitle?.length ?? 0) +
        cached.chapterUrl.length +
        cached.content.length;
  }

  FormatException? _tryResolveCorruptedPayload(String payload) {
    final trimmed = payload.trim();
    final gatewayPrefix = ReaderGatewayContentCacheCodec.payloadPrefix;
    final legacyImagePrefix = ReaderGatewayContentCacheCodec.legacyImagePrefix;
    if (trimmed.startsWith(gatewayPrefix)) {
      return _tryDecodeJsonPayload(trimmed.substring(gatewayPrefix.length));
    }
    if (trimmed.startsWith(legacyImagePrefix)) {
      return _tryDecodeJsonPayload(trimmed.substring(legacyImagePrefix.length));
    }
    return null;
  }

  FormatException? _tryDecodeJsonPayload(String raw) {
    try {
      jsonDecode(raw);
      return null;
    } on FormatException catch (error) {
      return error;
    }
  }
}
