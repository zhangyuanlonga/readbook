import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_cache_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_engine.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_request.dart';
import 'package:shuxiang_reading_next/features/reader/domain/entities/reader_layout_models.dart';

void main() {
  group('ReaderLayoutCacheService', () {
    test('stores and reads layout pages from memory', () async {
      final service = ReaderLayoutCacheService(maxMemoryEntries: 2);
      final request = _request('chapter-1', fingerprint: 'doc-a');
      final result = _result(request);

      await service.write(result);
      final restored = await service.read(request);

      expect(restored, isNotNull);
      expect(restored!.pages.single.lines.single.text, 'x');
      expect(service.memoryEntryCount, 1);
    });

    test('restores from backing store after memory miss', () async {
      final store = ReaderLayoutMemoryCacheStore();
      final request = _request('chapter-1', fingerprint: 'doc-a');
      await ReaderLayoutCacheService(store: store).write(_result(request));

      final restored = await ReaderLayoutCacheService(
        store: store,
      ).read(request);

      expect(restored, isNotNull);
      expect(restored!.documentFingerprint, 'doc-a');
    });

    test('invalidates cache when document fingerprint changes', () async {
      final store = ReaderLayoutMemoryCacheStore();
      final oldRequest = _request('chapter-1', fingerprint: 'doc-a');
      final newRequest = _request('chapter-1', fingerprint: 'doc-b');
      await ReaderLayoutCacheService(store: store).write(_result(oldRequest));

      final restored = await ReaderLayoutCacheService(
        store: store,
      ).read(newRequest);

      expect(restored, isNull);
    });

    test('trims memory entries by LRU order', () async {
      final service = ReaderLayoutCacheService(maxMemoryEntries: 1);
      final first = _request('chapter-1', fingerprint: 'doc-a');
      final second = _request('chapter-2', fingerprint: 'doc-b');

      await service.write(_result(first));
      await service.write(_result(second));

      expect(await service.read(first), isNull);
      expect(await service.read(second), isNotNull);
      expect(service.memoryEntryCount, 1);
    });

    test('ignores entries with mismatched cache version', () async {
      final store = ReaderLayoutMemoryCacheStore();
      final request = _request('chapter-1', fingerprint: 'doc-a');
      await ReaderLayoutCacheService(
        store: store,
        cacheVersion: 'old',
      ).write(_result(request));

      final restored = await ReaderLayoutCacheService(
        store: store,
        cacheVersion: 'new',
      ).read(request);

      expect(restored, isNull);
    });
  });
}

ReaderLayoutRequest _request(String chapterId, {required String fingerprint}) {
  return ReaderLayoutRequest.fromParagraphs(
    chapterId: chapterId,
    chapterIndex: 0,
    paragraphs: const <String>['x'],
    spec: _spec,
    documentFingerprint: fingerprint,
  );
}

ReaderLayoutResult _result(ReaderLayoutRequest request) {
  return ReaderLayoutResult(
    request: request,
    elapsedMicros: 1,
    pages: <ReaderLayoutPage>[
      ReaderLayoutPage(
        chapterId: request.chapterId,
        chapterIndex: request.chapterIndex,
        pageIndex: 0,
        startOffset: 0,
        endOffset: 1,
        contentWidth: request.spec.contentWidth,
        contentHeight: request.spec.contentHeight,
        layoutSignature: request.layoutSignature,
        lines: const <ReaderLayoutLine>[
          ReaderLayoutLine(
            lineIndex: 0,
            paragraphIndex: 0,
            text: 'x',
            chapterOffset: 0,
            pageOffset: 0,
            lineTop: 0,
            lineBase: 10,
            lineBottom: 12,
            columns: <ReaderLayoutColumn>[
              ReaderLayoutColumn(
                columnIndex: 0,
                kind: ReaderLayoutColumnKind.text,
                startOffset: 0,
                endOffset: 1,
                rect: ReaderLayoutRect(left: 0, top: 0, right: 10, bottom: 12),
                text: 'x',
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

const _spec = ReaderLayoutSpec(
  contentWidth: 80,
  contentHeight: 42,
  contentRectLeft: 0,
  contentRectTop: 0,
  pagePaddingTop: 0,
  pagePaddingRight: 0,
  pagePaddingBottom: 0,
  pagePaddingLeft: 0,
  pinnedHeaderHeight: 0,
  fontSize: 14,
  lineHeight: 1,
  paragraphSpacing: 2,
  paragraphIndent: 0,
  letterSpacing: 0,
  textFullJustifyEnabled: false,
  bodyTextItalicEnabled: false,
  fontWeightLevel: ReaderFontWeightLevel.regular,
  fontWeightValue: null,
  fontSource: ReaderFontSource.system,
  systemFontPreset: ReaderSystemFontPreset.defaultSans,
  fontFamilyKey: null,
);
