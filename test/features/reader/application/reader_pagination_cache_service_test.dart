import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/core/cache/cache_entry.dart';
import 'package:shuxiang_reading_next/core/cache/cache_policy.dart';
import 'package:shuxiang_reading_next/core/cache/cache_result.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_cache_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_models.dart';

void main() {
  test('lazy page snapshot models loading ready and failed states', () {
    const loading = ReaderLazyPageSnapshot<List<ReaderPagedSlice>>.loading(
      pageIndex: 0,
    );
    const ready = ReaderLazyPageSnapshot<List<ReaderPagedSlice>>.ready(
      pageIndex: 1,
      page: <ReaderPagedSlice>[
        ReaderPagedSlice(paragraphIndex: 0, start: 0, end: 1, height: 12),
      ],
    );
    const failed = ReaderLazyPageSnapshot<List<ReaderPagedSlice>>.failed(
      pageIndex: 2,
      errorMessage: 'timeout',
    );

    expect(loading.status, ReaderLazyPageSnapshotStatus.loading);
    expect(ready.isReady, isTrue);
    expect(failed.errorMessage, 'timeout');
  });

  group('ReaderPaginationCacheService', () {
    late Directory tempDir;
    late ReaderPaginationCacheService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'reader-pagination-cache',
      );
      service = ReaderPaginationCacheService(
        directoryProvider: () async => tempDir,
        maxMemoryEntries: 2,
      );
    });

    tearDown(() async {
      // storePrecomputedChapterLayout persists in the background by design.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('stores and reloads precomputed layout', () async {
      const layout = ReaderPrecomputedChapterLayout(
        paragraphs: <String>['正文一', '正文二'],
        pagedPages: <List<ReaderPagedSlice>>[
          <ReaderPagedSlice>[
            ReaderPagedSlice(paragraphIndex: 0, start: 0, end: 2, height: 24),
          ],
        ],
        paginationSignature: 'chapter-a|sig',
      );

      service.storePrecomputedChapterLayout(
        sourceId: 'local',
        chapterUrl: 'chapter://a',
        layout: layout,
      );

      final loaded = await service.loadPrecomputedChapterLayout(
        sourceId: 'local',
        chapterUrl: 'chapter://a',
        signature: 'chapter-a|sig',
      );

      expect(loaded, isNotNull);
      expect(loaded!.paginationSignature, 'chapter-a|sig');
      expect(loaded.pagedPages.first.first.end, 2);
    });

    test('stores and reloads precomputed block layout', () async {
      const layout = ReaderPrecomputedChapterLayout(
        paragraphs: <String>['图文正文'],
        pagedPages: <List<ReaderPagedSlice>>[],
        pagedBlockPages: <List<ReaderPagedBlock>>[
          <ReaderPagedBlock>[
            ReaderPagedBlock.text(
              paragraphIndex: 0,
              start: 0,
              end: 4,
              height: 24,
            ),
            ReaderPagedBlock.image(imageUrl: 'file:///tmp/p1.png', height: 120),
          ],
        ],
        paginationSignature: 'chapter-block|sig',
      );

      service.storePrecomputedChapterLayout(
        sourceId: 'local',
        chapterUrl: 'chapter://block',
        layout: layout,
      );

      final loaded = await service.loadPrecomputedChapterLayout(
        sourceId: 'local',
        chapterUrl: 'chapter://block',
        signature: 'chapter-block|sig',
      );

      expect(loaded, isNotNull);
      expect(loaded!.pagedBlockPages, hasLength(1));
      expect(
        loaded.pagedBlockPages.first.last.kind,
        ReaderPagedBlockKind.image,
      );
      expect(loaded.pagedBlockPages.first.last.imageUrl, 'file:///tmp/p1.png');
    });

    test('prunes persisted layouts by byte budget', () async {
      for (var index = 0; index < 3; index++) {
        await File(
          '${tempDir.path}/layout_$index.json',
        ).writeAsString('{"payload":"${'x' * 256}"}');
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }

      final deleted = await service.prunePersistedChapterLayoutsByBudget(
        maxEntries: 10,
        maxBytes: 300,
      );
      final remaining =
          await tempDir
              .list(followLinks: false)
              .where((entity) => entity is File)
              .length;

      expect(deleted, 2);
      expect(remaining, 1);
    });

    test('reports memory and persisted cache stats', () async {
      const layout = ReaderPrecomputedChapterLayout(
        paragraphs: <String>['正文'],
        pagedPages: <List<ReaderPagedSlice>>[
          <ReaderPagedSlice>[
            ReaderPagedSlice(paragraphIndex: 0, start: 0, end: 2, height: 24),
          ],
        ],
        paginationSignature: 'chapter-stats|sig',
      );

      await service.persistPrecomputedChapterLayout(
        sourceId: 'local',
        chapterUrl: 'chapter://stats',
        layout: layout,
      );
      service.storePrecomputedChapterLayout(
        sourceId: 'local',
        chapterUrl: 'chapter://stats',
        layout: layout,
      );

      final stats = await service.loadStats();

      expect(stats.memoryEntries, 1);
      expect(stats.persistedEntries, 1);
      expect(stats.persistedBytes, greaterThan(0));
    });

    test('reads and writes through AppCacheStore contract', () async {
      const layout = ReaderPrecomputedChapterLayout(
        paragraphs: <String>['正文'],
        pagedPages: <List<ReaderPagedSlice>>[
          <ReaderPagedSlice>[
            ReaderPagedSlice(paragraphIndex: 0, start: 0, end: 2, height: 24),
          ],
        ],
        paginationSignature: 'chapter-store|sig',
      );
      final key = service.buildAppCacheKey(
        sourceId: 'source_store',
        chapterUrl: 'chapter://store',
        signature: 'chapter-store|sig',
      );
      final now = DateTime(2026, 6, 13);

      final writeResult = await service.write(
        AppCacheEntry(
          key: key,
          payload: layout,
          createdAt: now,
          updatedAt: now,
          lastAccessedAt: now,
        ),
      );
      final readResult = await service.read(key);

      expect(writeResult.status, AppCacheWriteStatus.written);
      expect(readResult.status, AppCacheReadStatus.hit);
      expect(readResult.entry?.payload, isA<ReaderPrecomputedChapterLayout>());
      expect(readResult.entry?.metadata['schemaVersion'], 1);
      expect(readResult.entry?.metadata['pageCount'], 1);
    });

    test('reports invalid persisted json as decodeFailed', () async {
      const layout = ReaderPrecomputedChapterLayout(
        paragraphs: <String>['正文'],
        pagedPages: <List<ReaderPagedSlice>>[
          <ReaderPagedSlice>[
            ReaderPagedSlice(paragraphIndex: 0, start: 0, end: 2, height: 24),
          ],
        ],
        paginationSignature: 'chapter-bad-json|sig',
      );
      await service.persistPrecomputedChapterLayout(
        sourceId: 'source_bad_json',
        chapterUrl: 'chapter://bad-json',
        layout: layout,
      );
      final file = await _singleCacheFile(tempDir);
      await file.writeAsString('{bad json');
      final key = service.buildAppCacheKey(
        sourceId: 'source_bad_json',
        chapterUrl: 'chapter://bad-json',
        signature: 'chapter-bad-json|sig',
      );

      final result = await service.read(key);

      expect(result.status, AppCacheReadStatus.decodeFailed);
      expect(result.invalidReason, AppCacheInvalidReason.payloadCorrupted);
    });

    test('reports persisted schema mismatch as versionMismatch', () async {
      const layout = ReaderPrecomputedChapterLayout(
        paragraphs: <String>['正文'],
        pagedPages: <List<ReaderPagedSlice>>[
          <ReaderPagedSlice>[
            ReaderPagedSlice(paragraphIndex: 0, start: 0, end: 2, height: 24),
          ],
        ],
        paginationSignature: 'chapter-version|sig',
      );
      await service.persistPrecomputedChapterLayout(
        sourceId: 'source_version',
        chapterUrl: 'chapter://version',
        layout: layout,
      );
      final file = await _singleCacheFile(tempDir);
      final payload =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      payload['schemaVersion'] = 2;
      await file.writeAsString(jsonEncode(payload));
      final key = service.buildAppCacheKey(
        sourceId: 'source_version',
        chapterUrl: 'chapter://version',
        signature: 'chapter-version|sig',
      );

      final result = await service.read(key);

      expect(result.status, AppCacheReadStatus.versionMismatch);
      expect(result.invalidReason, AppCacheInvalidReason.versionChanged);
    });

    test('reports signature mismatch as stale layoutChanged', () async {
      const layout = ReaderPrecomputedChapterLayout(
        paragraphs: <String>['正文'],
        pagedPages: <List<ReaderPagedSlice>>[
          <ReaderPagedSlice>[
            ReaderPagedSlice(paragraphIndex: 0, start: 0, end: 2, height: 24),
          ],
        ],
        paginationSignature: 'chapter-layout|sig',
      );
      await service.persistPrecomputedChapterLayout(
        sourceId: 'source_layout',
        chapterUrl: 'chapter://layout',
        layout: layout,
      );
      final file = await _singleCacheFile(tempDir);
      final payload =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      payload['layoutSignature'] = 'old-layout-signature';
      payload['paginationSignature'] = 'old-layout-signature';
      await file.writeAsString(jsonEncode(payload));
      final key = service.buildAppCacheKey(
        sourceId: 'source_layout',
        chapterUrl: 'chapter://layout',
        signature: 'chapter-layout|sig',
      );

      final result = await service.read(key);

      expect(result.status, AppCacheReadStatus.stale);
      expect(result.invalidReason, AppCacheInvalidReason.layoutChanged);
    });

    test('reports ttl-expired persisted layout as stale', () async {
      const layout = ReaderPrecomputedChapterLayout(
        paragraphs: <String>['正文'],
        pagedPages: <List<ReaderPagedSlice>>[
          <ReaderPagedSlice>[
            ReaderPagedSlice(paragraphIndex: 0, start: 0, end: 2, height: 24),
          ],
        ],
        paginationSignature: 'chapter-ttl|sig',
      );
      await service.persistPrecomputedChapterLayout(
        sourceId: 'source_ttl',
        chapterUrl: 'chapter://ttl',
        layout: layout,
      );
      final file = await _singleCacheFile(tempDir);
      await file.setLastModified(
        DateTime.now().subtract(const Duration(days: 2)),
      );
      final key = service.buildAppCacheKey(
        sourceId: 'source_ttl',
        chapterUrl: 'chapter://ttl',
        signature: 'chapter-ttl|sig',
      );

      final result = await service.read(
        key,
        policy: const AppCachePolicy(ttl: Duration(days: 1)),
      );

      expect(result.status, AppCacheReadStatus.stale);
      expect(result.invalidReason, AppCacheInvalidReason.ttlExpired);
    });
  });
}

Future<File> _singleCacheFile(Directory directory) async {
  final files =
      await directory
          .list(followLinks: false)
          .where((entity) => entity is File)
          .cast<File>()
          .toList();
  expect(files, hasLength(1));
  return files.single;
}
