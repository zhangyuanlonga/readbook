import 'dart:convert';

import '../domain/entities/reader_layout_models.dart';
import 'reader_layout_engine.dart';
import 'reader_layout_request.dart';

class ReaderLayoutCacheEntry {
  const ReaderLayoutCacheEntry({
    required this.chapterId,
    required this.layoutSignature,
    required this.documentFingerprint,
    required this.cacheVersion,
    required this.pages,
    required this.byteSize,
    required this.updatedAt,
  });

  final String chapterId;
  final String layoutSignature;
  final String documentFingerprint;
  final String cacheVersion;
  final List<ReaderLayoutPage> pages;
  final int byteSize;
  final DateTime updatedAt;

  bool matches(ReaderLayoutRequest request, String expectedCacheVersion) {
    return chapterId == request.chapterId &&
        layoutSignature == request.layoutSignature &&
        documentFingerprint == request.documentFingerprint &&
        cacheVersion == expectedCacheVersion;
  }
}

class ReaderLayoutCacheRecord {
  const ReaderLayoutCacheRecord({
    required this.key,
    required this.byteSize,
    required this.updatedAt,
  });

  final String key;
  final int byteSize;
  final DateTime updatedAt;
}

abstract class ReaderLayoutCacheStore {
  Future<String?> read(String key);
  Future<void> write(String key, String payload, int byteSize);
  Future<void> delete(String key);
  Future<List<ReaderLayoutCacheRecord>> records();
}

class ReaderLayoutMemoryCacheStore implements ReaderLayoutCacheStore {
  final _payloads = <String, String>{};
  final _records = <String, ReaderLayoutCacheRecord>{};

  @override
  Future<String?> read(String key) async {
    final payload = _payloads[key];
    final record = _records[key];
    if (payload != null && record != null) {
      _records[key] = ReaderLayoutCacheRecord(
        key: key,
        byteSize: record.byteSize,
        updatedAt: DateTime.now().toUtc(),
      );
    }
    return payload;
  }

  @override
  Future<void> write(String key, String payload, int byteSize) async {
    _payloads[key] = payload;
    _records[key] = ReaderLayoutCacheRecord(
      key: key,
      byteSize: byteSize,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> delete(String key) async {
    _payloads.remove(key);
    _records.remove(key);
  }

  @override
  Future<List<ReaderLayoutCacheRecord>> records() async {
    return _records.values.toList(growable: false);
  }
}

class ReaderLayoutCacheService {
  ReaderLayoutCacheService({
    this.store,
    this.cacheVersion = 'reader_layout_cache_v1',
    this.maxMemoryEntries = 3,
    this.maxMemoryBytes = 1024 * 1024,
    this.maxStoreBytes = 8 * 1024 * 1024,
    DateTime Function()? now,
  }) : _now = now ?? (() => DateTime.now().toUtc());

  final ReaderLayoutCacheStore? store;
  final String cacheVersion;
  final int maxMemoryEntries;
  final int maxMemoryBytes;
  final int maxStoreBytes;
  final DateTime Function() _now;
  final _memory = <String, ReaderLayoutCacheEntry>{};

  int get memoryEntryCount => _memory.length;
  int get memoryByteSize {
    return _memory.values.fold<int>(
      0,
      (total, entry) => total + entry.byteSize,
    );
  }

  Future<ReaderLayoutCacheEntry?> read(ReaderLayoutRequest request) async {
    final key = _keyFor(request.chapterId, request.layoutSignature);
    final memoryEntry = _memory.remove(key);
    if (memoryEntry != null) {
      if (memoryEntry.matches(request, cacheVersion)) {
        _memory[key] = memoryEntry;
        return memoryEntry;
      }
      await store?.delete(key);
      return null;
    }

    final payload = await store?.read(key);
    if (payload == null) {
      return null;
    }

    final entry = _decodeEntry(payload);
    if (entry == null || !entry.matches(request, cacheVersion)) {
      await store?.delete(key);
      return null;
    }

    _remember(key, entry);
    return entry;
  }

  Future<void> write(ReaderLayoutResult result) async {
    final request = result.request;
    final entry = ReaderLayoutCacheEntry(
      chapterId: request.chapterId,
      layoutSignature: request.layoutSignature,
      documentFingerprint: request.documentFingerprint,
      cacheVersion: cacheVersion,
      pages: result.pages,
      byteSize: 0,
      updatedAt: _now(),
    );
    final payload = _encodeEntry(entry);
    final byteSize = utf8.encode(payload).length;
    final sizedEntry = ReaderLayoutCacheEntry(
      chapterId: entry.chapterId,
      layoutSignature: entry.layoutSignature,
      documentFingerprint: entry.documentFingerprint,
      cacheVersion: entry.cacheVersion,
      pages: entry.pages,
      byteSize: byteSize,
      updatedAt: entry.updatedAt,
    );
    final key = _keyFor(request.chapterId, request.layoutSignature);
    _remember(key, sizedEntry);
    if (store != null && byteSize <= maxStoreBytes) {
      await store!.write(key, _encodeEntry(sizedEntry), byteSize);
      await _trimStore();
    }
  }

  Future<void> invalidate(ReaderLayoutRequest request) async {
    final key = _keyFor(request.chapterId, request.layoutSignature);
    _memory.remove(key);
    await store?.delete(key);
  }

  Future<void> _trimStore() async {
    final targetStore = store;
    if (targetStore == null) {
      return;
    }
    final records = await targetStore.records();
    var totalBytes = records.fold<int>(
      0,
      (total, record) => total + record.byteSize,
    );
    if (totalBytes <= maxStoreBytes) {
      return;
    }

    final sorted =
        records.toList()..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    for (final record in sorted) {
      if (totalBytes <= maxStoreBytes) {
        break;
      }
      await targetStore.delete(record.key);
      totalBytes -= record.byteSize;
    }
  }

  void _remember(String key, ReaderLayoutCacheEntry entry) {
    _memory.remove(key);
    _memory[key] = entry;
    _trimMemory();
  }

  void _trimMemory() {
    while (_memory.length > maxMemoryEntries ||
        memoryByteSize > maxMemoryBytes) {
      if (_memory.isEmpty) {
        return;
      }
      _memory.remove(_memory.keys.first);
    }
  }

  String _keyFor(String chapterId, String layoutSignature) {
    return '$chapterId::$layoutSignature';
  }

  String _encodeEntry(ReaderLayoutCacheEntry entry) {
    return jsonEncode(<String, Object?>{
      'chapterId': entry.chapterId,
      'layoutSignature': entry.layoutSignature,
      'documentFingerprint': entry.documentFingerprint,
      'cacheVersion': entry.cacheVersion,
      'byteSize': entry.byteSize,
      'updatedAt': entry.updatedAt.toIso8601String(),
      'pages': entry.pages.map(_encodePage).toList(growable: false),
    });
  }

  ReaderLayoutCacheEntry? _decodeEntry(String payload) {
    final decoded = jsonDecode(payload);
    if (decoded is! Map) {
      return null;
    }
    final pages = decoded['pages'];
    if (pages is! List) {
      return null;
    }
    final updatedAt = DateTime.tryParse(decoded['updatedAt']?.toString() ?? '');
    return ReaderLayoutCacheEntry(
      chapterId: decoded['chapterId']?.toString() ?? '',
      layoutSignature: decoded['layoutSignature']?.toString() ?? '',
      documentFingerprint: decoded['documentFingerprint']?.toString() ?? '',
      cacheVersion: decoded['cacheVersion']?.toString() ?? '',
      byteSize: _asInt(decoded['byteSize']) ?? utf8.encode(payload).length,
      updatedAt: updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0).toUtc(),
      pages: pages
          .whereType<Map>()
          .map(_decodePage)
          .whereType<ReaderLayoutPage>()
          .toList(growable: false),
    );
  }

  Map<String, Object?> _encodePage(ReaderLayoutPage page) {
    return <String, Object?>{
      'chapterId': page.chapterId,
      'chapterIndex': page.chapterIndex,
      'pageIndex': page.pageIndex,
      'startOffset': page.startOffset,
      'endOffset': page.endOffset,
      'contentWidth': page.contentWidth,
      'contentHeight': page.contentHeight,
      'layoutSignature': page.layoutSignature,
      'isCompleted': page.isCompleted,
      'blockRefs': page.blockRefs,
      'lines': page.lines.map(_encodeLine).toList(growable: false),
    };
  }

  ReaderLayoutPage? _decodePage(Map page) {
    final lines = page['lines'];
    return ReaderLayoutPage(
      chapterId: page['chapterId']?.toString() ?? '',
      chapterIndex: _asInt(page['chapterIndex']) ?? 0,
      pageIndex: _asInt(page['pageIndex']) ?? 0,
      startOffset: _asInt(page['startOffset']) ?? 0,
      endOffset: _asInt(page['endOffset']) ?? 0,
      contentWidth: _asDouble(page['contentWidth']) ?? 0,
      contentHeight: _asDouble(page['contentHeight']) ?? 0,
      layoutSignature: page['layoutSignature']?.toString() ?? '',
      isCompleted: page['isCompleted'] == true,
      blockRefs:
          page['blockRefs'] is List
              ? (page['blockRefs'] as List)
                  .map((value) => value.toString())
                  .toList(growable: false)
              : const <String>[],
      lines:
          lines is List
              ? lines
                  .whereType<Map>()
                  .map(_decodeLine)
                  .whereType<ReaderLayoutLine>()
                  .toList(growable: false)
              : const <ReaderLayoutLine>[],
    );
  }

  Map<String, Object?> _encodeLine(ReaderLayoutLine line) {
    return <String, Object?>{
      'lineIndex': line.lineIndex,
      'paragraphIndex': line.paragraphIndex,
      'text': line.text,
      'chapterOffset': line.chapterOffset,
      'pageOffset': line.pageOffset,
      'lineTop': line.lineTop,
      'lineBase': line.lineBase,
      'lineBottom': line.lineBottom,
      'isTitle': line.isTitle,
      'isImage': line.isImage,
      'isHtml': line.isHtml,
      'isParagraphEnd': line.isParagraphEnd,
      'columns': line.columns.map(_encodeColumn).toList(growable: false),
    };
  }

  ReaderLayoutLine? _decodeLine(Map line) {
    final columns = line['columns'];
    return ReaderLayoutLine(
      lineIndex: _asInt(line['lineIndex']) ?? 0,
      paragraphIndex: _asInt(line['paragraphIndex']) ?? 0,
      text: line['text']?.toString() ?? '',
      chapterOffset: _asInt(line['chapterOffset']) ?? 0,
      pageOffset: _asInt(line['pageOffset']) ?? 0,
      lineTop: _asDouble(line['lineTop']) ?? 0,
      lineBase: _asDouble(line['lineBase']) ?? 0,
      lineBottom: _asDouble(line['lineBottom']) ?? 0,
      isTitle: line['isTitle'] == true,
      isImage: line['isImage'] == true,
      isHtml: line['isHtml'] == true,
      isParagraphEnd: line['isParagraphEnd'] == true,
      columns:
          columns is List
              ? columns
                  .whereType<Map>()
                  .map(_decodeColumn)
                  .whereType<ReaderLayoutColumn>()
                  .toList(growable: false)
              : const <ReaderLayoutColumn>[],
    );
  }

  Map<String, Object?> _encodeColumn(ReaderLayoutColumn column) {
    return <String, Object?>{
      'columnIndex': column.columnIndex,
      'kind': column.kind.name,
      'startOffset': column.startOffset,
      'endOffset': column.endOffset,
      'rect': <String, Object?>{
        'left': column.rect.left,
        'top': column.rect.top,
        'right': column.rect.right,
        'bottom': column.rect.bottom,
      },
      'text': column.text,
      'styleKey': column.styleKey,
      'payload': column.payload,
    };
  }

  ReaderLayoutColumn? _decodeColumn(Map column) {
    final rect = column['rect'];
    return ReaderLayoutColumn(
      columnIndex: _asInt(column['columnIndex']) ?? 0,
      kind: _parseColumnKind(column['kind']),
      startOffset: _asInt(column['startOffset']) ?? 0,
      endOffset: _asInt(column['endOffset']) ?? 0,
      rect:
          rect is Map
              ? ReaderLayoutRect(
                left: _asDouble(rect['left']) ?? 0,
                top: _asDouble(rect['top']) ?? 0,
                right: _asDouble(rect['right']) ?? 0,
                bottom: _asDouble(rect['bottom']) ?? 0,
              )
              : const ReaderLayoutRect(left: 0, top: 0, right: 0, bottom: 0),
      text: column['text']?.toString() ?? '',
      styleKey: column['styleKey']?.toString(),
      payload:
          column['payload'] is Map
              ? (column['payload'] as Map).map(
                (key, value) => MapEntry(key.toString(), value),
              )
              : const <String, Object?>{},
    );
  }

  ReaderLayoutColumnKind _parseColumnKind(Object? value) {
    final name = value?.toString();
    for (final kind in ReaderLayoutColumnKind.values) {
      if (kind.name == name) {
        return kind;
      }
    }
    return ReaderLayoutColumnKind.text;
  }

  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  double? _asDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }
}
