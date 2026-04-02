import 'package:flutter_appread/domain/entities/chapter.dart';
import 'package:flutter_appread/domain/entities/reader_document.dart';
import 'package:flutter_appread/features/reader/application/reader_catalog_search_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReaderCatalogSearchService', () {
    const service = ReaderCatalogSearchService();
    final chapters = <Chapter>[
      const Chapter(
        id: 'chapter_1',
        bookId: 'book_1',
        title: '第一章 开始',
        chapterUrl: 'https://example.com/1',
        index: 0,
      ),
      const Chapter(
        id: 'chapter_2',
        bookId: 'book_1',
        title: '第二章 继续',
        chapterUrl: 'https://example.com/2',
        index: 1,
      ),
    ];

    test('buildFullTextSearchEntries includes toc and content hits', () {
      final document = ReaderDocument(
        blocks: const [
          ReaderTextBlock(text: '第一段正文命中关键词'),
          ReaderTextBlock(text: '第二段正文'),
        ],
      );

      final entries = service.buildFullTextSearchEntries(
        keyword: '第一',
        chapters: chapters,
        currentChapterIndex: 0,
        chapterContent: '第一段正文命中关键词',
        chapterParagraphs: const ['第一段正文命中关键词', '第二段正文'],
        chapterDocument: document,
        isPagedTextReaderEnabled: true,
        currentPageIndex: 2,
      );

      expect(entries.where((entry) => !entry.isContent).isNotEmpty, isTrue);
      final contentEntry = entries.firstWhere((entry) => entry.isContent);
      expect(contentEntry.chapterIndex, 0);
      expect(contentEntry.logicalPosition, isNotNull);
      expect(contentEntry.logicalPosition!.pageIndex, 2);
    });

    test('lookup uses cache when fingerprint is unchanged', () {
      const keyword = '关键词';
      final document = ReaderDocument(
        blocks: const [ReaderTextBlock(text: '这里有关键词')],
      );

      final first = service.lookup(
        keyword: keyword,
        state: const ReaderCatalogSearchCacheState(),
        chapterId: 'chapter_1',
        chapterUrl: 'https://example.com/1',
        currentChapterIndex: 0,
        chapters: chapters,
        chapterContent: '这里有关键词',
        chapterParagraphs: const ['这里有关键词'],
        chapterDocument: document,
        isPagedTextReaderEnabled: false,
        currentPageIndex: 0,
      );
      final second = service.lookup(
        keyword: keyword,
        state: first.state,
        chapterId: 'chapter_1',
        chapterUrl: 'https://example.com/1',
        currentChapterIndex: 0,
        chapters: chapters,
        chapterContent: '这里有关键词',
        chapterParagraphs: const ['这里有关键词'],
        chapterDocument: document,
        isPagedTextReaderEnabled: false,
        currentPageIndex: 0,
      );

      expect(first.entries, isNotEmpty);
      expect(identical(first.entries, second.entries), isTrue);
      expect(second.state.entriesCache[keyword], isNotNull);
    });

    test('lookup invalidates stale cache when fingerprint changes', () {
      const keyword = '唯一词';
      final first = service.lookup(
        keyword: keyword,
        state: const ReaderCatalogSearchCacheState(),
        chapterId: 'chapter_1',
        chapterUrl: 'https://example.com/1',
        currentChapterIndex: 0,
        chapters: chapters,
        chapterContent: '包含唯一词',
        chapterParagraphs: const ['包含唯一词'],
        chapterDocument: ReaderDocument(
          blocks: const [ReaderTextBlock(text: '包含唯一词')],
        ),
        isPagedTextReaderEnabled: false,
        currentPageIndex: 0,
      );
      final second = service.lookup(
        keyword: keyword,
        state: first.state,
        chapterId: 'chapter_1',
        chapterUrl: 'https://example.com/1',
        currentChapterIndex: 0,
        chapters: chapters,
        chapterContent: '不包含',
        chapterParagraphs: const ['不包含'],
        chapterDocument: ReaderDocument(
          blocks: const [ReaderTextBlock(text: '不包含')],
        ),
        isPagedTextReaderEnabled: false,
        currentPageIndex: 0,
      );

      expect(first.entries.where((entry) => entry.isContent), isNotEmpty);
      expect(second.entries, isEmpty);
    });

    test('volume title hit resolves to first readable chapter', () {
      final entries = service.buildFullTextSearchEntries(
        keyword: '第一卷',
        chapters: const <Chapter>[
          Chapter(
            id: 'volume_1',
            bookId: 'book_1',
            title: '第一卷 初入江湖',
            chapterUrl: '',
            index: 0,
            isVolume: true,
          ),
          Chapter(
            id: 'chapter_1',
            bookId: 'book_1',
            title: '第一章 开始',
            chapterUrl: 'https://example.com/1',
            index: 1,
          ),
        ],
        currentChapterIndex: null,
        chapterContent: '',
        chapterParagraphs: const <String>[],
        chapterDocument: ReaderDocument(blocks: const <ReaderBlock>[]),
        isPagedTextReaderEnabled: false,
        currentPageIndex: 0,
      );

      expect(entries, hasLength(1));
      expect(entries.first.isVolume, isTrue);
      expect(entries.first.targetChapterIndex, 1);
    });

    test(
      'volume title hit stays non-navigable when no readable chapter exists',
      () {
        final entries = service.buildFullTextSearchEntries(
          keyword: '终卷',
          chapters: const <Chapter>[
            Chapter(
              id: 'volume_last',
              bookId: 'book_1',
              title: '终卷 完结',
              chapterUrl: '',
              index: 0,
              isVolume: true,
            ),
          ],
          currentChapterIndex: null,
          chapterContent: '',
          chapterParagraphs: const <String>[],
          chapterDocument: ReaderDocument(blocks: const <ReaderBlock>[]),
          isPagedTextReaderEnabled: false,
          currentPageIndex: 0,
        );

        expect(entries, hasLength(1));
        expect(entries.first.isVolume, isTrue);
        expect(entries.first.targetChapterIndex, isNull);
      },
    );
  });
}
