import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_cache_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_models.dart';

void main() {
  group('ReaderPaginationCacheService', () {
    late Directory tempDir;
    late ReaderPaginationCacheService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('reader-pagination-cache');
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
            ReaderPagedSlice(paragraphIndex: 0, start: 0, end: 2),
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
  });
}
