import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_catalog_search_presentation.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_catalog_search_service.dart';

void main() {
  group('ReaderCatalogSearchPresenter', () {
    const presenter = ReaderCatalogSearchPresenter();

    test('splits toc and content hits while keeping ascending order', () {
      final presentation = presenter.resolve(
        descending: false,
        entries: const [
          ReaderCatalogSearchEntry(
            title: '正文',
            subtitle: '',
            chapterIndex: 2,
            isContent: true,
          ),
          ReaderCatalogSearchEntry(title: '目录', subtitle: '', chapterIndex: 1),
        ],
      );

      expect(presentation.tocEntries.single.title, '目录');
      expect(presentation.contentEntries.single.title, '正文');
    });

    test('sorts each search section independently when descending', () {
      final presentation = presenter.resolve(
        descending: true,
        entries: const [
          ReaderCatalogSearchEntry(
            title: '目录 1',
            subtitle: '',
            chapterIndex: 1,
          ),
          ReaderCatalogSearchEntry(
            title: '目录 3',
            subtitle: '',
            chapterIndex: 3,
          ),
          ReaderCatalogSearchEntry(
            title: '正文 2',
            subtitle: '',
            chapterIndex: 2,
            isContent: true,
          ),
          ReaderCatalogSearchEntry(
            title: '正文 4',
            subtitle: '',
            chapterIndex: 4,
            isContent: true,
          ),
        ],
      );

      expect(presentation.tocEntries.map((entry) => entry.chapterIndex), [
        3,
        1,
      ]);
      expect(presentation.contentEntries.map((entry) => entry.chapterIndex), [
        4,
        2,
      ]);
    });
  });
}
