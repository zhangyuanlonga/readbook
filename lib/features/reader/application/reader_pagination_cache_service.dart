import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/cache/cache_entry.dart';
import '../../../core/cache/app_cache_governance_service.dart';
import '../../../core/cache/cache_key.dart';
import '../../../core/cache/cache_policy.dart';
import '../../../core/cache/cache_result.dart';
import '../../../core/cache/cache_scope.dart';
import '../../../core/cache/cache_store.dart';
import 'reader_pagination_models.dart';

typedef ReaderPaginationCacheDirectoryProvider = Future<Directory> Function();

class ReaderPaginationLayoutCacheKeyBuilder {
  const ReaderPaginationLayoutCacheKeyBuilder();

  AppCacheKey build({
    required String sourceId,
    required String chapterUrl,
    required String signature,
    double? viewportWidth,
    double? viewportHeight,
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    double? letterSpacing,
    double? paragraphSpacing,
    String? themeId,
  }) {
    return AppCacheKey(
      scope: AppCacheScope.paginationLayout,
      owner: sourceId.trim().isEmpty ? 'reader' : sourceId,
      parts: <String, Object?>{
        'sourceId': sourceId,
        'chapterUrl': chapterUrl,
        'signature': signature,
        if (viewportWidth != null) 'viewportWidth': viewportWidth,
        if (viewportHeight != null) 'viewportHeight': viewportHeight,
        if (fontFamily != null) 'fontFamily': fontFamily,
        if (fontSize != null) 'fontSize': fontSize,
        if (lineHeight != null) 'lineHeight': lineHeight,
        if (letterSpacing != null) 'letterSpacing': letterSpacing,
        if (paragraphSpacing != null) 'paragraphSpacing': paragraphSpacing,
        if (themeId != null) 'themeId': themeId,
      },
    );
  }
}

class ReaderPaginationCacheStats {
  const ReaderPaginationCacheStats({
    required this.memoryEntries,
    required this.persistedEntries,
    required this.persistedBytes,
  });

  final int memoryEntries;
  final int persistedEntries;
  final int persistedBytes;
}

class ReaderPaginationCacheService
    implements AppPaginationLayoutCacheStore, AppCacheStore {
  ReaderPaginationCacheService({
    ReaderPaginationCacheDirectoryProvider? directoryProvider,
    int maxMemoryEntries = 24,
    ReaderPaginationLayoutCacheKeyBuilder? keyBuilder,
  }) : _directoryProvider = directoryProvider ?? _defaultDirectoryProvider,
       _maxMemoryEntries = maxMemoryEntries.clamp(1, 512),
       _keyBuilder =
           keyBuilder ?? const ReaderPaginationLayoutCacheKeyBuilder();

  final ReaderPaginationCacheDirectoryProvider _directoryProvider;
  final int _maxMemoryEntries;
  final ReaderPaginationLayoutCacheKeyBuilder _keyBuilder;
  final LinkedHashMap<String, ReaderPrecomputedChapterLayout> _memoryCache =
      LinkedHashMap<String, ReaderPrecomputedChapterLayout>();
  static const int _layoutSchemaVersion = 1;

  @override
  AppCacheScope get scope => AppCacheScope.paginationLayout;

  @override
  String get backendName => 'file.reader_pagination_layouts';

  String buildChapterLayoutCacheKey({
    required String sourceId,
    required String chapterUrl,
    required String signature,
  }) {
    return '${sourceId.trim()}|${chapterUrl.trim()}|$signature';
  }

  AppCacheKey buildAppCacheKey({
    required String sourceId,
    required String chapterUrl,
    required String signature,
  }) {
    return _keyBuilder.build(
      sourceId: sourceId,
      chapterUrl: chapterUrl,
      signature: signature,
    );
  }

  bool shouldPersistChapterLayout({
    required String sourceId,
    required String chapterUrl,
  }) {
    return sourceId.trim().isNotEmpty && chapterUrl.trim().isNotEmpty;
  }

  Future<ReaderPrecomputedChapterLayout?> loadPrecomputedChapterLayout({
    required String sourceId,
    required String chapterUrl,
    required String signature,
  }) {
    final cacheKey = buildChapterLayoutCacheKey(
      sourceId: sourceId,
      chapterUrl: chapterUrl,
      signature: signature,
    );
    final memoryCached = _memoryCache[cacheKey];
    if (memoryCached != null) {
      _traceCacheEvent(
        'reader.pagination.cache.hit',
        sourceId: sourceId,
        chapterUrl: chapterUrl,
        signature: signature,
        status: 'memory',
        pageCount: memoryCached.pagedPages.length,
        blockPageCount: memoryCached.pagedBlockPages.length,
      );
      return Future<ReaderPrecomputedChapterLayout?>.value(memoryCached);
    }
    if (!shouldPersistChapterLayout(
      sourceId: sourceId,
      chapterUrl: chapterUrl,
    )) {
      _traceCacheEvent(
        'reader.pagination.cache.skip',
        sourceId: sourceId,
        chapterUrl: chapterUrl,
        signature: signature,
        status: 'unpersistable',
      );
      return Future<ReaderPrecomputedChapterLayout?>.value(null);
    }
    return _readPersistedChapterLayout(
      sourceId: sourceId,
      chapterUrl: chapterUrl,
      signature: signature,
      cacheKey: cacheKey,
    );
  }

  void storePrecomputedChapterLayout({
    required String sourceId,
    required String chapterUrl,
    required ReaderPrecomputedChapterLayout layout,
  }) {
    final cacheKey = buildChapterLayoutCacheKey(
      sourceId: sourceId,
      chapterUrl: chapterUrl,
      signature: layout.paginationSignature,
    );
    _memoryCache[cacheKey] = layout;
    _trimMemoryCache();
    _traceCacheEvent(
      'reader.pagination.cache.write',
      sourceId: sourceId,
      chapterUrl: chapterUrl,
      signature: layout.paginationSignature,
      status: 'memory',
      pageCount: layout.pagedPages.length,
      blockPageCount: layout.pagedBlockPages.length,
    );
    if (shouldPersistChapterLayout(
      sourceId: sourceId,
      chapterUrl: chapterUrl,
    )) {
      unawaited(
        persistPrecomputedChapterLayout(
          sourceId: sourceId,
          chapterUrl: chapterUrl,
          layout: layout,
        ),
      );
    }
  }

  @override
  Future<int> countPersistedChapterLayouts() async {
    final directory = await _directoryProvider();
    if (!await directory.exists()) {
      return 0;
    }

    var count = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File) {
        count++;
      }
    }
    return count;
  }

  @override
  Future<int> estimatePersistedChapterLayoutBytes() async {
    final directory = await _directoryProvider();
    if (!await directory.exists()) {
      return 0;
    }

    var bytes = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      try {
        bytes += await entity.length();
      } catch (_) {
        // Ignore single-file stat failure.
      }
    }
    return bytes;
  }

  Future<ReaderPaginationCacheStats> loadStats() async {
    final directory = await _directoryProvider();
    if (!await directory.exists()) {
      return ReaderPaginationCacheStats(
        memoryEntries: _memoryCache.length,
        persistedEntries: 0,
        persistedBytes: 0,
      );
    }

    var persistedEntries = 0;
    var persistedBytes = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      persistedEntries++;
      try {
        persistedBytes += await entity.length();
      } catch (_) {
        // Ignore single-file stat failure.
      }
    }
    return ReaderPaginationCacheStats(
      memoryEntries: _memoryCache.length,
      persistedEntries: persistedEntries,
      persistedBytes: persistedBytes,
    );
  }

  @override
  Future<int> clearPersistedChapterLayouts() async {
    _memoryCache.clear();
    final directory = await _directoryProvider();
    if (!await directory.exists()) {
      return 0;
    }

    var deletedCount = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      try {
        if (await entity.exists()) {
          await entity.delete();
          deletedCount++;
        }
      } catch (_) {
        // Ignore single-file cleanup failure and continue.
      }
    }
    return deletedCount;
  }

  Future<int> prunePersistedChapterLayouts({required int maxEntries}) async {
    return prunePersistedChapterLayoutsByBudget(
      maxEntries: maxEntries,
      maxBytes: -1,
    );
  }

  @override
  Future<int> prunePersistedChapterLayoutsByBudget({
    required int maxEntries,
    required int maxBytes,
    Duration? stalePeriod,
  }) async {
    final normalizedMaxEntries = maxEntries < 0 ? 0 : maxEntries;
    final normalizedMaxBytes = maxBytes < 0 ? -1 : maxBytes;
    _memoryCache.clear();
    final directory = await _directoryProvider();
    if (!await directory.exists()) {
      return 0;
    }

    final files = <File>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File) {
        files.add(entity);
      }
    }

    var deletedCount = 0;
    var totalBytes = 0;
    final retainedFiles = <File>[];
    final now = DateTime.now();
    for (final file in files) {
      try {
        final stat = await file.stat();
        if (stalePeriod != null &&
            stalePeriod > Duration.zero &&
            now.difference(stat.modified) > stalePeriod) {
          await file.delete();
          deletedCount++;
          continue;
        }
        totalBytes += stat.size;
        retainedFiles.add(file);
      } catch (_) {
        // Ignore single-file stat/delete failure.
      }
    }

    retainedFiles.sort(
      (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
    );
    var overflowCount = retainedFiles.length - normalizedMaxEntries;
    for (final file in retainedFiles) {
      if (overflowCount <= 0 &&
          (normalizedMaxBytes < 0 || totalBytes <= normalizedMaxBytes)) {
        break;
      }
      try {
        if (await file.exists()) {
          final length = await file.length();
          await file.delete();
          deletedCount++;
          overflowCount--;
          totalBytes -= length;
        }
      } catch (_) {
        // Ignore single-file cleanup failure and continue.
      }
    }
    return deletedCount;
  }

  Future<void> persistPrecomputedChapterLayout({
    required String sourceId,
    required String chapterUrl,
    required ReaderPrecomputedChapterLayout layout,
  }) async {
    try {
      final file = await _chapterLayoutCacheFile(
        sourceId: sourceId,
        chapterUrl: chapterUrl,
        signature: layout.paginationSignature,
      );
      await file.writeAsString(
        jsonEncode(_layoutCachePayload(layout)),
        flush: false,
      );
      _traceCacheEvent(
        'reader.pagination.cache.write',
        sourceId: sourceId,
        chapterUrl: chapterUrl,
        signature: layout.paginationSignature,
        status: 'disk',
        pageCount: layout.pagedPages.length,
        blockPageCount: layout.pagedBlockPages.length,
      );
    } catch (_) {
      _traceCacheEvent(
        'reader.pagination.cache.write',
        sourceId: sourceId,
        chapterUrl: chapterUrl,
        signature: layout.paginationSignature,
        status: 'disk_error',
      );
      // Persistence failures should not block active pagination.
    }
  }

  int get memoryEntryCount => _memoryCache.length;

  @override
  Future<AppCacheReadResult> read(
    AppCacheKey key, {
    AppCachePolicy? policy,
  }) async {
    final stopwatch = Stopwatch()..start();
    final sourceId = key.parts['sourceId'] ?? '';
    final chapterUrl = key.parts['chapterUrl'] ?? '';
    final signature = key.parts['signature'] ?? '';
    if (sourceId.isEmpty || chapterUrl.isEmpty || signature.isEmpty) {
      return AppCacheReadResult.miss(
        key: key,
        backend: backendName,
        cost: stopwatch.elapsed,
      );
    }
    try {
      final cacheKey = buildChapterLayoutCacheKey(
        sourceId: sourceId,
        chapterUrl: chapterUrl,
        signature: signature,
      );
      final memoryCached = _memoryCache[cacheKey];
      if (memoryCached != null) {
        final entry = _entryForLayout(
          key: key,
          layout: memoryCached,
          sourceId: sourceId,
          chapterUrl: chapterUrl,
          signature: signature,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final expectedVersion = policy?.version ?? _layoutSchemaVersion;
        if (!entry.hasVersion(expectedVersion)) {
          return AppCacheReadResult.versionMismatch(
            key: key,
            backend: backendName,
            entry: entry,
            cost: stopwatch.elapsed,
          );
        }
        return AppCacheReadResult.hit(
          key: key,
          backend: backendName,
          entry: entry,
          cost: stopwatch.elapsed,
        );
      }
      final persistedResult = await _readPersistedChapterLayoutResult(
        sourceId: sourceId,
        chapterUrl: chapterUrl,
        signature: signature,
        cacheKey: cacheKey,
        policy: policy,
      );
      if (persistedResult.status != AppCacheReadStatus.hit) {
        return persistedResult.toAppCacheReadResult(
          key: key,
          backend: backendName,
          cost: stopwatch.elapsed,
        );
      }
      final layout = persistedResult.layout;
      if (layout == null) {
        return AppCacheReadResult.miss(
          key: key,
          backend: backendName,
          cost: stopwatch.elapsed,
        );
      }
      final entry = _entryForLayout(
        key: key,
        layout: layout,
        sourceId: sourceId,
        chapterUrl: chapterUrl,
        signature: signature,
        createdAt: persistedResult.createdAt ?? DateTime.now(),
        updatedAt: persistedResult.updatedAt ?? DateTime.now(),
      );
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
    final sourceId = entry.key.parts['sourceId'] ?? '';
    final chapterUrl = entry.key.parts['chapterUrl'] ?? '';
    final payload = entry.payload;
    if (sourceId.isEmpty ||
        chapterUrl.isEmpty ||
        payload is! ReaderPrecomputedChapterLayout) {
      return AppCacheWriteResult.skipped(
        key: entry.key,
        backend: backendName,
        cost: stopwatch.elapsed,
      );
    }
    storePrecomputedChapterLayout(
      sourceId: sourceId,
      chapterUrl: chapterUrl,
      layout: payload,
    );
    return AppCacheWriteResult.written(
      key: entry.key,
      backend: backendName,
      sizeBytes: _estimateLayoutBytes(payload),
      cost: stopwatch.elapsed,
    );
  }

  @override
  Future<AppCacheDeleteResult> delete(AppCacheKey key) async {
    final stopwatch = Stopwatch()..start();
    final sourceId = key.parts['sourceId'] ?? '';
    final chapterUrl = key.parts['chapterUrl'] ?? '';
    final signature = key.parts['signature'] ?? '';
    if (sourceId.isEmpty || chapterUrl.isEmpty || signature.isEmpty) {
      return AppCacheDeleteResult.skipped(
        scope: scope,
        backend: backendName,
        key: key,
        cost: stopwatch.elapsed,
      );
    }
    final cacheKey = buildChapterLayoutCacheKey(
      sourceId: sourceId,
      chapterUrl: chapterUrl,
      signature: signature,
    );
    _memoryCache.remove(cacheKey);
    var deleted = 0;
    try {
      final file = await _chapterLayoutCacheFile(
        sourceId: sourceId,
        chapterUrl: chapterUrl,
        signature: signature,
      );
      if (await file.exists()) {
        await file.delete();
        deleted += 1;
      }
      final legacyFile = await _legacyChapterLayoutCacheFile(
        sourceId: sourceId,
        chapterUrl: chapterUrl,
        signature: signature,
      );
      if (await legacyFile.exists()) {
        await legacyFile.delete();
        deleted += 1;
      }
    } catch (_) {
      // Delete failures are reported as partial misses by the caller path.
    }
    return AppCacheDeleteResult.deleted(
      scope: scope,
      backend: backendName,
      key: key,
      deletedEntries: deleted,
      cost: stopwatch.elapsed,
    );
  }

  @override
  Future<AppCacheDeleteResult> clearScope({String? owner}) async {
    final stopwatch = Stopwatch()..start();
    final deleted = await clearPersistedChapterLayouts();
    return AppCacheDeleteResult.deleted(
      scope: scope,
      backend: backendName,
      deletedEntries: deleted,
      cost: stopwatch.elapsed,
    );
  }

  @override
  Future<AppCacheStats> stats({String? owner}) async {
    final stats = await loadStats();
    return AppCacheStats(
      scope: scope,
      backend: backendName,
      entries: stats.persistedEntries + stats.memoryEntries,
      bytes: stats.persistedBytes,
    );
  }

  @override
  Future<AppCachePruneResult> prune(AppCachePolicy policy) async {
    final stopwatch = Stopwatch()..start();
    final deleted = await prunePersistedChapterLayoutsByBudget(
      maxEntries: policy.maxEntries ?? 0,
      maxBytes: policy.maxBytes ?? -1,
      stalePeriod: policy.ttl,
    );
    return AppCachePruneResult(
      scope: scope,
      backend: backendName,
      deletedEntries: deleted,
      cost: stopwatch.elapsed,
    );
  }

  Future<File> _chapterLayoutCacheFile({
    required String sourceId,
    required String chapterUrl,
    required String signature,
  }) async {
    final cacheDirectory = await _directoryProvider();
    if (!await cacheDirectory.exists()) {
      await cacheDirectory.create(recursive: true);
    }
    final cacheKey = buildChapterLayoutCacheKey(
      sourceId: sourceId,
      chapterUrl: chapterUrl,
      signature: signature,
    );
    return File(
      p.join(
        cacheDirectory.path,
        '${_stablePaginationCacheHash(cacheKey)}.json',
      ),
    );
  }

  Future<ReaderPrecomputedChapterLayout?> _readPersistedChapterLayout({
    required String sourceId,
    required String chapterUrl,
    required String signature,
    required String cacheKey,
  }) async {
    try {
      final file = await _chapterLayoutCacheFile(
        sourceId: sourceId,
        chapterUrl: chapterUrl,
        signature: signature,
      );
      var targetFile = file;
      if (!await targetFile.exists()) {
        final legacyFile = await _legacyChapterLayoutCacheFile(
          sourceId: sourceId,
          chapterUrl: chapterUrl,
          signature: signature,
        );
        if (await legacyFile.exists()) {
          targetFile = legacyFile;
        } else {
          _traceCacheEvent(
            'reader.pagination.cache.miss',
            sourceId: sourceId,
            chapterUrl: chapterUrl,
            signature: signature,
            status: 'disk_missing',
          );
          return null;
        }
      }
      final result = await _decodePersistedChapterLayoutFile(
        file: targetFile,
        sourceId: sourceId,
        chapterUrl: chapterUrl,
        signature: signature,
        cacheKey: cacheKey,
      );
      return result.layout;
    } catch (_) {
      _traceCacheEvent(
        'reader.pagination.cache.miss',
        sourceId: sourceId,
        chapterUrl: chapterUrl,
        signature: signature,
        status: 'read_error',
      );
      return null;
    }
  }

  Future<_ReaderPaginationPersistedReadResult>
  _readPersistedChapterLayoutResult({
    required String sourceId,
    required String chapterUrl,
    required String signature,
    required String cacheKey,
    AppCachePolicy? policy,
  }) async {
    try {
      final file = await _chapterLayoutCacheFile(
        sourceId: sourceId,
        chapterUrl: chapterUrl,
        signature: signature,
      );
      var targetFile = file;
      if (!await targetFile.exists()) {
        final legacyFile = await _legacyChapterLayoutCacheFile(
          sourceId: sourceId,
          chapterUrl: chapterUrl,
          signature: signature,
        );
        if (await legacyFile.exists()) {
          targetFile = legacyFile;
        } else {
          return const _ReaderPaginationPersistedReadResult(
            status: AppCacheReadStatus.miss,
          );
        }
      }
      final decoded = await _decodePersistedChapterLayoutFile(
        file: targetFile,
        sourceId: sourceId,
        chapterUrl: chapterUrl,
        signature: signature,
        cacheKey: cacheKey,
        policy: policy,
      );
      return decoded;
    } catch (error, stackTrace) {
      return _ReaderPaginationPersistedReadResult(
        status: AppCacheReadStatus.backendError,
        invalidReason: AppCacheInvalidReason.backendUnavailable,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<_ReaderPaginationPersistedReadResult>
  _decodePersistedChapterLayoutFile({
    required File file,
    required String sourceId,
    required String chapterUrl,
    required String signature,
    required String cacheKey,
    AppCachePolicy? policy,
  }) async {
    final stat = await file.stat();
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      _traceCacheEvent(
        'reader.pagination.cache.miss',
        sourceId: sourceId,
        chapterUrl: chapterUrl,
        signature: signature,
        status: 'disk_empty',
      );
      return const _ReaderPaginationPersistedReadResult(
        status: AppCacheReadStatus.decodeFailed,
        invalidReason: AppCacheInvalidReason.payloadCorrupted,
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error, stackTrace) {
      _traceCacheEvent(
        'reader.pagination.cache.miss',
        sourceId: sourceId,
        chapterUrl: chapterUrl,
        signature: signature,
        status: 'disk_invalid_json',
      );
      return _ReaderPaginationPersistedReadResult(
        status: AppCacheReadStatus.decodeFailed,
        invalidReason: AppCacheInvalidReason.payloadCorrupted,
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (decoded is! Map) {
      _traceCacheEvent(
        'reader.pagination.cache.miss',
        sourceId: sourceId,
        chapterUrl: chapterUrl,
        signature: signature,
        status: 'disk_invalid',
      );
      return const _ReaderPaginationPersistedReadResult(
        status: AppCacheReadStatus.decodeFailed,
        invalidReason: AppCacheInvalidReason.payloadCorrupted,
      );
    }
    final payload = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final schemaVersion = _decodeOptionalInt(payload['schemaVersion']);
    final expectedVersion = policy?.version ?? _layoutSchemaVersion;
    if ((schemaVersion != null && schemaVersion != _layoutSchemaVersion) ||
        expectedVersion != _layoutSchemaVersion) {
      _traceCacheEvent(
        'reader.pagination.cache.miss',
        sourceId: sourceId,
        chapterUrl: chapterUrl,
        signature: signature,
        status: 'schema_mismatch',
      );
      return _ReaderPaginationPersistedReadResult(
        status: AppCacheReadStatus.versionMismatch,
        invalidReason: AppCacheInvalidReason.versionChanged,
        layout: ReaderPrecomputedChapterLayout.fromJson(payload),
        createdAt: stat.changed,
        updatedAt: stat.modified,
      );
    }
    final layoutSignature =
        payload['layoutSignature']?.toString().trim() ??
        payload['paginationSignature']?.toString().trim() ??
        '';
    final layout = ReaderPrecomputedChapterLayout.fromJson(payload);
    if (layoutSignature != signature ||
        layout.paginationSignature != signature) {
      _traceCacheEvent(
        'reader.pagination.cache.miss',
        sourceId: sourceId,
        chapterUrl: chapterUrl,
        signature: signature,
        status: 'signature_mismatch',
      );
      return _ReaderPaginationPersistedReadResult(
        status: AppCacheReadStatus.stale,
        invalidReason: AppCacheInvalidReason.layoutChanged,
        layout: layout,
        createdAt: stat.changed,
        updatedAt: stat.modified,
      );
    }
    final ttl = policy?.ttl;
    if (ttl != null &&
        ttl > Duration.zero &&
        DateTime.now().difference(stat.modified) > ttl) {
      return _ReaderPaginationPersistedReadResult(
        status: AppCacheReadStatus.stale,
        invalidReason: AppCacheInvalidReason.ttlExpired,
        layout: layout,
        createdAt: stat.changed,
        updatedAt: stat.modified,
      );
    }
    _memoryCache[cacheKey] = layout;
    _trimMemoryCache();
    _traceCacheEvent(
      'reader.pagination.cache.hit',
      sourceId: sourceId,
      chapterUrl: chapterUrl,
      signature: signature,
      status: 'disk',
      pageCount: layout.pagedPages.length,
      blockPageCount: layout.pagedBlockPages.length,
    );
    return _ReaderPaginationPersistedReadResult(
      status: AppCacheReadStatus.hit,
      layout: layout,
      createdAt: stat.changed,
      updatedAt: stat.modified,
    );
  }

  void _traceCacheEvent(
    String name, {
    required String sourceId,
    required String chapterUrl,
    required String signature,
    required String status,
    int? pageCount,
    int? blockPageCount,
  }) {
    developer.Timeline.instantSync(
      name,
      arguments: <String, Object?>{
        'status': status,
        'sourceId': sourceId,
        'chapterUrl': chapterUrl,
        'signature': signature,
        if (pageCount != null) 'pageCount': pageCount,
        if (blockPageCount != null) 'blockPageCount': blockPageCount,
      },
    );
  }

  void _trimMemoryCache() {
    while (_memoryCache.length > _maxMemoryEntries) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
  }

  static Future<Directory> _defaultDirectoryProvider() async {
    final cacheDirectory = await getApplicationCacheDirectory();
    return Directory(p.join(cacheDirectory.path, 'reader_pagination_cache'));
  }

  Future<File> _legacyChapterLayoutCacheFile({
    required String sourceId,
    required String chapterUrl,
    required String signature,
  }) async {
    final supportDirectory = await getApplicationSupportDirectory();
    final cacheKey = buildChapterLayoutCacheKey(
      sourceId: sourceId,
      chapterUrl: chapterUrl,
      signature: signature,
    );
    return File(
      p.join(
        supportDirectory.path,
        'reader_pagination_cache',
        '${_stablePaginationCacheHash(cacheKey)}.json',
      ),
    );
  }

  String _stablePaginationCacheHash(String input) {
    const mask = 0x3fffffff;
    var hash = 0x001dc5;
    for (final unit in input.codeUnits) {
      hash = ((hash * 16777619) ^ unit) & mask;
    }
    return '${input.length.toRadixString(16)}_${hash.toRadixString(16)}';
  }

  int _estimateLayoutBytes(ReaderPrecomputedChapterLayout layout) {
    try {
      return jsonEncode(_layoutCachePayload(layout)).length;
    } catch (_) {
      return layout.paragraphs.fold<int>(0, (sum, item) => sum + item.length);
    }
  }

  AppCacheEntry _entryForLayout({
    required AppCacheKey key,
    required ReaderPrecomputedChapterLayout layout,
    required String sourceId,
    required String chapterUrl,
    required String signature,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return AppCacheEntry(
      key: key,
      payload: layout,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastAccessedAt: DateTime.now(),
      version: _layoutSchemaVersion,
      sizeBytes: _estimateLayoutBytes(layout),
      metadata: <String, Object?>{
        'schemaVersion': _layoutSchemaVersion,
        'layoutSignature': signature,
        'sourceId': sourceId,
        'chapterUrl': chapterUrl,
        'signature': signature,
        'pageCount': layout.pagedPages.length,
        'blockPageCount': layout.pagedBlockPages.length,
      },
    );
  }

  Map<String, Object?> _layoutCachePayload(
    ReaderPrecomputedChapterLayout layout,
  ) {
    return <String, Object?>{
      ...layout.toJson(),
      'schemaVersion': _layoutSchemaVersion,
      'layoutSignature': layout.paginationSignature,
      'createdAt': DateTime.now().toIso8601String(),
      'pageCount': layout.pagedPages.length,
      'blockPageCount': layout.pagedBlockPages.length,
    };
  }

  int? _decodeOptionalInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString().trim());
  }
}

class _ReaderPaginationPersistedReadResult {
  const _ReaderPaginationPersistedReadResult({
    required this.status,
    this.invalidReason,
    this.layout,
    this.createdAt,
    this.updatedAt,
    this.error,
    this.stackTrace,
  });

  final AppCacheReadStatus status;
  final AppCacheInvalidReason? invalidReason;
  final ReaderPrecomputedChapterLayout? layout;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Object? error;
  final StackTrace? stackTrace;

  AppCacheReadResult toAppCacheReadResult({
    required AppCacheKey key,
    required String backend,
    Duration? cost,
  }) {
    final entry =
        layout == null
            ? null
            : AppCacheEntry(
              key: key,
              payload: layout,
              createdAt: createdAt ?? DateTime.now(),
              updatedAt: updatedAt ?? DateTime.now(),
              lastAccessedAt: DateTime.now(),
              version: ReaderPaginationCacheService._layoutSchemaVersion,
            );
    return switch (status) {
      AppCacheReadStatus.hit => AppCacheReadResult.hit(
        key: key,
        backend: backend,
        entry: entry!,
        cost: cost,
      ),
      AppCacheReadStatus.stale => AppCacheReadResult.stale(
        key: key,
        backend: backend,
        entry: entry!,
        invalidReason: invalidReason ?? AppCacheInvalidReason.unknown,
        cost: cost,
      ),
      AppCacheReadStatus.decodeFailed => AppCacheReadResult.decodeFailed(
        key: key,
        backend: backend,
        error: error,
        stackTrace: stackTrace,
        cost: cost,
      ),
      AppCacheReadStatus.versionMismatch => AppCacheReadResult.versionMismatch(
        key: key,
        backend: backend,
        entry: entry!,
        cost: cost,
      ),
      AppCacheReadStatus.backendError => AppCacheReadResult.backendError(
        key: key,
        backend: backend,
        error: error,
        stackTrace: stackTrace,
        cost: cost,
      ),
      AppCacheReadStatus.miss => AppCacheReadResult.miss(
        key: key,
        backend: backend,
        cost: cost,
      ),
    };
  }
}
