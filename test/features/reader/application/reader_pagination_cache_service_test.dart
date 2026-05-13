import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_cache_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_models.dart';

void main() {
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
  });
}
