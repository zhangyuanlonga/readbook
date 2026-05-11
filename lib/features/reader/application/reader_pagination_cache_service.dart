import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'reader_pagination_models.dart';

typedef ReaderPaginationCacheDirectoryProvider = Future<Directory> Function();

class ReaderPaginationCacheService {
  ReaderPaginationCacheService({
    ReaderPaginationCacheDirectoryProvider? directoryProvider,
    int maxMemoryEntries = 24,
  }) : _directoryProvider = directoryProvider ?? _defaultDirectoryProvider,
       _maxMemoryEntries = maxMemoryEntries.clamp(1, 512);

  final ReaderPaginationCacheDirectoryProvider _directoryProvider;
  final int _maxMemoryEntries;
  final LinkedHashMap<String, ReaderPrecomputedChapterLayout> _memoryCache =
      LinkedHashMap<String, ReaderPrecomputedChapterLayout>();

  String buildChapterLayoutCacheKey({
    required String sourceId,
    required String chapterUrl,
    required String signature,
  }) {
    return '${sourceId.trim()}|${chapterUrl.trim()}|$signature';
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
      return Future<ReaderPrecomputedChapterLayout?>.value(memoryCached);
    }
    if (!shouldPersistChapterLayout(
      sourceId: sourceId,
      chapterUrl: chapterUrl,
    )) {
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
      await file.writeAsString(jsonEncode(layout.toJson()), flush: false);
    } catch (_) {
      // Persistence failures should not block active pagination.
    }
  }

  int get memoryEntryCount => _memoryCache.length;

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
      if (!await file.exists()) {
        return null;
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final layout = ReaderPrecomputedChapterLayout.fromJson(decoded);
      if (layout.paginationSignature != signature) {
        return null;
      }
      _memoryCache[cacheKey] = layout;
      _trimMemoryCache();
      return layout;
    } catch (_) {
      return null;
    }
  }

  void _trimMemoryCache() {
    while (_memoryCache.length > _maxMemoryEntries) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
  }

  static Future<Directory> _defaultDirectoryProvider() async {
    final supportDirectory = await getApplicationSupportDirectory();
    return Directory(p.join(supportDirectory.path, 'reader_pagination_cache'));
  }

  String _stablePaginationCacheHash(String input) {
    const mask = 0x3fffffff;
    var hash = 0x001dc5;
    for (final unit in input.codeUnits) {
      hash = ((hash * 16777619) ^ unit) & mask;
    }
    return '${input.length.toRadixString(16)}_${hash.toRadixString(16)}';
  }
}
