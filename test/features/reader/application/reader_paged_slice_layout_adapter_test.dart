import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_paged_slice_layout_adapter.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_models.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_spec.dart';

void main() {
  group('ReaderPagedSliceLayoutAdapter', () {
    const adapter = ReaderPagedSliceLayoutAdapter();

    test('converts a single paged slice into a layout page', () {
      final pages = adapter.buildPages(
        chapterId: 'chapter-1',
        chapterIndex: 0,
        paragraphs: const <String>['abcdef'],
        pagedPages: const <List<ReaderPagedSlice>>[
          <ReaderPagedSlice>[
            ReaderPagedSlice(paragraphIndex: 0, start: 1, end: 4, height: 24),
          ],
        ],
        spec: _spec,
        layoutSignature: 'sig',
      );

      expect(pages, hasLength(1));
      expect(pages.first.startOffset, 1);
      expect(pages.first.endOffset, 4);
      expect(pages.first.lines.single.text, 'bcd');
      expect(pages.first.lines.single.columns.single.rect.right, 320);
    });

    test('keeps paragraph separator offsets explicit', () {
      final pages = adapter.buildPages(
        chapterId: 'chapter-1',
        chapterIndex: 0,
        paragraphs: const <String>['abc', 'defg'],
        pagedPages: const <List<ReaderPagedSlice>>[
          <ReaderPagedSlice>[
            ReaderPagedSlice(paragraphIndex: 0, start: 0, end: 3, height: 20),
            ReaderPagedSlice(paragraphIndex: 1, start: 1, end: 3, height: 20),
          ],
        ],
        spec: _spec,
        layoutSignature: 'sig',
        paragraphSeparatorLength: 2,
      );

      final lines = pages.single.lines;
      expect(lines.first.chapterOffset, 0);
      expect(lines.first.endChapterOffset, 3);
      expect(lines.last.chapterOffset, 6);
      expect(lines.last.endChapterOffset, 8);
      expect(lines.last.pageOffset, 6);
    });

    test('supports split slices from one paragraph across pages', () {
      final pages = adapter.buildPages(
        chapterId: 'chapter-1',
        chapterIndex: 0,
        paragraphs: const <String>['abcdef'],
        pagedPages: const <List<ReaderPagedSlice>>[
          <ReaderPagedSlice>[
            ReaderPagedSlice(paragraphIndex: 0, start: 0, end: 2, height: 20),
          ],
          <ReaderPagedSlice>[
            ReaderPagedSlice(paragraphIndex: 0, start: 2, end: 6, height: 20),
          ],
        ],
        spec: _spec,
        layoutSignature: 'sig',
      );

      expect(pages, hasLength(2));
      expect(pages.first.startOffset, 0);
      expect(pages.first.endOffset, 2);
      expect(pages.last.startOffset, 2);
      expect(pages.last.endOffset, 6);
    });

    test('ignores out-of-range paragraph indexes safely', () {
      final pages = adapter.buildPages(
        chapterId: 'chapter-1',
        chapterIndex: 0,
        paragraphs: const <String>['abc'],
        pagedPages: const <List<ReaderPagedSlice>>[
          <ReaderPagedSlice>[
            ReaderPagedSlice(paragraphIndex: 99, start: 0, end: 2, height: 20),
          ],
        ],
        spec: _spec,
        layoutSignature: 'sig',
      );

      expect(pages, hasLength(1));
      expect(pages.single.isEmpty, isTrue);
      expect(pages.single.startOffset, 0);
      expect(pages.single.endOffset, 0);
    });

    test('returns an empty list for empty paged pages', () {
      final pages = adapter.buildPages(
        chapterId: 'chapter-1',
        chapterIndex: 0,
        paragraphs: const <String>['abc'],
        pagedPages: const <List<ReaderPagedSlice>>[],
        spec: _spec,
        layoutSignature: 'sig',
      );

      expect(pages, isEmpty);
    });
  });
}

const _spec = ReaderPaginationSpec(
  contentWidth: 320,
  contentHeight: 480,
  contentRectLeft: 18,
  contentRectTop: 18,
  pagePaddingTop: 18,
  pagePaddingRight: 18,
  pagePaddingBottom: 18,
  pagePaddingLeft: 18,
  pinnedHeaderHeight: 40,
  paragraphSpacing: 12,
  paragraphIndent: 2,
  lineHeight: 1.72,
  fontSize: 18,
  letterSpacing: 0.02,
  textFullJustifyEnabled: false,
  bodyTextItalicEnabled: false,
  fontWeightLevel: ReaderFontWeightLevel.regular,
  fontWeightValue: null,
  fontSource: ReaderFontSource.system,
  systemFontPreset: ReaderSystemFontPreset.defaultSans,
  fontFamilyKey: null,
);
