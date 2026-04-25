import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_models.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_text_offset_mapper.dart';

void main() {
  group('reader_text_offset_mapper', () {
    test('maps scroll display offset back to chapter offset', () {
      final offset = resolveChapterOffsetFromDisplayOffset(
        paragraphs: const <String>['第一段', '第二段'],
        pagedPages: const <List<ReaderPagedSlice>>[],
        currentPageIndex: 0,
        paragraphIndentLength: 2,
        displayOffset: 7,
      );

      expect(offset, 5);
    });

    test('maps paged display offset using current page slices', () {
      final offset = resolveChapterOffsetFromDisplayOffset(
        paragraphs: const <String>['第一段正文', '第二段正文'],
        pagedPages: const <List<ReaderPagedSlice>>[
          <ReaderPagedSlice>[
            ReaderPagedSlice(paragraphIndex: 0, start: 0, end: 2),
            ReaderPagedSlice(paragraphIndex: 1, start: 0, end: 2),
          ],
        ],
        currentPageIndex: 0,
        paragraphIndentLength: 2,
        displayOffset: 5,
      );

      expect(offset, 7);
    });

    test('maps paragraph-local offset back to chapter offset', () {
      final offset = resolveChapterOffsetFromParagraph(
        paragraphs: const <String>['第一段', '第二段'],
        paragraphIndex: 1,
        paragraphOffset: 2,
      );

      expect(offset, 3 + 2 + 2);
    });
  });
}
