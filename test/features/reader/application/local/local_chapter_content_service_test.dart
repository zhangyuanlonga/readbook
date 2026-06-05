import 'dart:io';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:charset/charset.dart';
import 'package:drift/native.dart';
import 'package:shuxiang_reading_next/core/errors/app_exception.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/data/repositories/local_book_repository_impl.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/domain/entities/local_chapter.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reading_record_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_system_settings_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_book_parser.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_book_index_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_chapter_content_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/epub_local_book_parser.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_book_storage_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/pdf_local_book_parser.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/txt_local_book_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalChapterContentService', () {
    late Directory tempDir;
    late AppDatabase database;
    late LocalBookRepositoryImpl repository;
    late LocalBookIndexService indexService;
    late LocalChapterContentService contentService;
    late LocalBookStorageService storageService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp(
        'local_chapter_content_service_test',
      );
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = LocalBookRepositoryImpl(database);
      storageService = LocalBookStorageService(
        supportDirectoryProvider: () async => tempDir,
      );
      indexService = LocalBookIndexService(
        localBookRepository: repository,
        parsers: <LocalBookParser>[const TxtLocalBookParser()],
        readerSystemSettingsService: ReaderSystemSettingsService(),
        storageService: storageService,
        bookshelfService: BookshelfService(),
        readingRecordService: ReadingRecordService(database: database),
      );
      contentService = LocalChapterContentService(
        localBookRepository: repository,
        indexService: indexService,
        storageService: storageService,
      );
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'loads txt chapter content directly from stored indexed content',
      () async {
        final file = File('${tempDir.path}/offset_book.txt');
        await file.writeAsString('''
第1章 开始
第一章内容。

第2章 继续
第二章内容。
''');

        final now = DateTime.parse('2026-03-21T12:00:00.000Z');
        await repository.upsertBook(
          LocalBook(
            id: 'local_offset_1',
            title: '偏移读取测试',
            format: LocalBookFormat.txt,
            storagePath: file.path,
            fileSize: await file.length(),
            createdAt: now,
            updatedAt: now,
          ),
        );

        await indexService.ensureIndexed(bookId: 'local_offset_1');

        final metas = await repository.getChapters('local_offset_1');
        expect(metas, hasLength(2));
        expect(metas.first.content, contains('第一章内容'));
        expect(metas.first.startOffset, isNotNull);
        expect(metas.first.endOffset, isNotNull);

        final chapter = await contentService.load(
          bookId: 'local_offset_1',
          chapterIndex: 0,
        );
        expect(chapter.title, '第1章 开始');
        expect(chapter.content, contains('第一章内容'));
        expect(chapter.content, isNot(contains('第2章 继续')));
      },
    );

    test('loads gbk txt chapter content with detected charset', () async {
      final file = File('${tempDir.path}/offset_book_gbk.txt');
      final gbk = Charset.getByName('gbk');
      expect(gbk, isNotNull);

      const content = '第1章 开始\n第一章内容。\n\n第2章 继续\n第二章内容。';
      await file.writeAsBytes(gbk!.encode(content), flush: true);

      final now = DateTime.parse('2026-03-21T12:00:00.000Z');
      await repository.upsertBook(
        LocalBook(
          id: 'local_offset_gbk_1',
          title: '偏移读取 GBK 测试',
          format: LocalBookFormat.txt,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      await indexService.ensureIndexed(bookId: 'local_offset_gbk_1');

      final indexedBook = await repository.getBookById('local_offset_gbk_1');
      expect(indexedBook, isNotNull);
      expect(indexedBook!.charset, 'gbk');

      final chapter = await contentService.load(
        bookId: 'local_offset_gbk_1',
        chapterIndex: 1,
      );
      expect(chapter.title, '第2章 继续');
      expect(chapter.content, contains('第二章内容'));
    });

    test('loads utf-16be txt chapter content with detected charset', () async {
      final file = File('${tempDir.path}/offset_book_utf16be.txt');
      const content = '第1章 开始\n第一章内容。\n\n第2章 继续\n第二章内容。';
      await file.writeAsBytes(
        _encodeUtf16(content, littleEndian: false),
        flush: true,
      );

      final now = DateTime.parse('2026-03-21T12:00:00.000Z');
      await repository.upsertBook(
        LocalBook(
          id: 'local_offset_utf16be_1',
          title: '偏移读取 UTF16BE 测试',
          format: LocalBookFormat.txt,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      await indexService.ensureIndexed(bookId: 'local_offset_utf16be_1');

      final indexedBook = await repository.getBookById(
        'local_offset_utf16be_1',
      );
      expect(indexedBook, isNotNull);
      expect(indexedBook!.charset, 'utf-16be');

      final chapter = await contentService.load(
        bookId: 'local_offset_utf16be_1',
        chapterIndex: 1,
      );
      expect(chapter.title, '第2章 继续');
      expect(chapter.content, contains('第二章内容'));
    });

    test(
      'loads streamed utf-16be txt chapters without marking the index stale',
      () async {
        final file = File('${tempDir.path}/streamed_utf16be_book.txt');
        final chapter1 = List.filled(180000, '内容一').join();
        final chapter2 = List.filled(180000, '内容二').join();
        await file.writeAsBytes(
          _encodeUtf16(
            '''
第1章 开始
$chapter1

第2章 继续
$chapter2
''',
            littleEndian: false,
            withBom: true,
          ),
          flush: true,
        );

        final now = DateTime.parse('2026-03-21T12:00:00.000Z');
        await repository.upsertBook(
          LocalBook(
            id: 'local_offset_streamed_utf16be_1',
            title: '偏移读取 UTF16BE 大文件测试',
            format: LocalBookFormat.txt,
            storagePath: file.path,
            splitLongChapter: false,
            fileSize: await file.length(),
            createdAt: now,
            updatedAt: now,
          ),
        );

        await indexService.ensureIndexed(
          bookId: 'local_offset_streamed_utf16be_1',
        );

        final indexedBook = await repository.getBookById(
          'local_offset_streamed_utf16be_1',
        );
        expect(indexedBook, isNotNull);
        expect(indexedBook!.charset, 'utf-16be');
        expect(indexedBook.indexStatus, LocalBookIndexStatus.ready);

        final metas = await repository.getChapters(
          'local_offset_streamed_utf16be_1',
        );
        expect(metas.length, greaterThan(1));
        expect(metas.first.content, isEmpty);
        expect(metas.first.startOffset, isNotNull);
        expect(metas.first.endOffset, isNotNull);

        final chapter = await contentService.load(
          bookId: 'local_offset_streamed_utf16be_1',
          chapterIndex: metas.length - 1,
        );
        expect(chapter.content, contains('内容'));

        final refreshedBook = await repository.getBookById(
          'local_offset_streamed_utf16be_1',
        );
        expect(refreshedBook, isNotNull);
        expect(refreshedBook!.indexStatus, LocalBookIndexStatus.ready);
      },
    );

    test('loads offset-only ready txt by byte range', () async {
      final file = File('${tempDir.path}/offset_only_book.txt');
      const content = '第1章 开始\n仅偏移正文';
      await file.writeAsString(content);
      final fileStat = await file.stat();
      final startOffset = utf8.encode('第1章 开始\n').length;
      final endOffset = utf8.encode(content).length;

      final now = DateTime.parse('2026-03-21T12:00:00.000Z');
      await repository.upsertBook(
        LocalBook(
          id: 'local_offset_only_1',
          title: '仅偏移旧数据测试',
          format: LocalBookFormat.txt,
          storagePath: file.path,
          fileSize: fileStat.size,
          storageFileLastModifiedMs: fileStat.modified.millisecondsSinceEpoch,
          indexStatus: LocalBookIndexStatus.ready,
          chapterCount: 1,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.replaceChapters(
        bookId: 'local_offset_only_1',
        chapters: <LocalChapter>[
          LocalChapter(
            id: 'local_offset_only_1_0',
            bookId: 'local_offset_only_1',
            chapterIndex: 0,
            title: '第1章 开始',
            content: '',
            startOffset: startOffset,
            endOffset: endOffset,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      final chapter = await contentService.load(
        bookId: 'local_offset_only_1',
        chapterIndex: 0,
      );
      expect(chapter.content, contains('仅偏移正文'));

      final refreshedBook = await repository.getBookById('local_offset_only_1');
      expect(refreshedBook, isNotNull);
      expect(refreshedBook!.indexStatus, LocalBookIndexStatus.ready);
    });

    test(
      'builds cleaned reader document for stored local text content',
      () async {
        final file = File('${tempDir.path}/stored_single_break_book.txt');
        const firstParagraph =
            '这是第一段正文内容，用来模拟本地图文导入后只有单换行的长段落。它应该被识别为一个完整段落，而不是和下一段黏在一起。';
        const secondParagraph =
            '这是第二段正文内容，同样没有额外空行。智能分段应当在上一段句号后断开，保证阅读器里显示为独立段落。';
        const content = '$firstParagraph\n$secondParagraph';
        await file.writeAsString(content);
        final fileStat = await file.stat();

        final now = DateTime.parse('2026-03-21T12:00:00.000Z');
        await repository.upsertBook(
          LocalBook(
            id: 'local_stored_clean_1',
            title: '本地图文分段测试',
            format: LocalBookFormat.txt,
            storagePath: file.path,
            fileSize: fileStat.size,
            storageFileLastModifiedMs: fileStat.modified.millisecondsSinceEpoch,
            indexStatus: LocalBookIndexStatus.ready,
            chapterCount: 1,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await repository.replaceChapters(
          bookId: 'local_stored_clean_1',
          chapters: <LocalChapter>[
            LocalChapter(
              id: 'local_stored_clean_1_0',
              bookId: 'local_stored_clean_1',
              chapterIndex: 0,
              title: '第1章 开始',
              content: content,
              createdAt: now,
              updatedAt: now,
            ),
          ],
        );

        final chapter = await contentService.load(
          bookId: 'local_stored_clean_1',
          chapterIndex: 0,
        );

        expect(chapter.document, isNotNull);
        expect(chapter.document!.paragraphs, <String>[
          firstParagraph,
          secondParagraph,
        ]);
        expect(chapter.content, '$firstParagraph\n\n$secondParagraph');
      },
    );

    test('returns epub chapter content directly from indexed storage', () async {
      final archive =
          Archive()
            ..addFile(
              ArchiveFile(
                'OPS/ch1.xhtml',
                0,
                utf8.encode(
                  '<html><body><p>第一章正文。</p><img src="images/p1.jpg" /></body></html>',
                ),
              ),
            )
            ..addFile(ArchiveFile('OPS/images/p1.jpg', 3, [1, 2, 3]));
      final encoded = ZipEncoder().encode(archive);
      final file = File('${tempDir.path}/lazy.epub');
      await file.writeAsBytes(encoded, flush: true);

      final now = DateTime.parse('2026-03-21T12:00:00.000Z');
      await repository.upsertBook(
        LocalBook(
          id: 'local_epub_lazy_1',
          title: '懒加载 EPUB',
          format: LocalBookFormat.epub,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      indexService = LocalBookIndexService(
        localBookRepository: repository,
        parsers: const <LocalBookParser>[EpubLocalBookParser()],
        readerSystemSettingsService: ReaderSystemSettingsService(),
        storageService: storageService,
        bookshelfService: BookshelfService(),
        readingRecordService: ReadingRecordService(database: database),
      );
      contentService = LocalChapterContentService(
        localBookRepository: repository,
        indexService: indexService,
        storageService: storageService,
      );

      await indexService.ensureIndexed(bookId: 'local_epub_lazy_1');
      final metas = await repository.getChapters('local_epub_lazy_1');
      expect(metas, hasLength(1));
      expect(metas.first.content, isEmpty);
      expect(metas.first.sourceRef, 'OPS/ch1.xhtml');
      expect(metas.first.imageUrls, isEmpty);
      expect(metas.first.document, isNull);

      final chapter = await contentService.load(
        bookId: 'local_epub_lazy_1',
        chapterIndex: 0,
      );
      expect(chapter.content, contains('第一章正文。'));
      expect(chapter.imageUrls, isNotEmpty);
      final document = chapter.document;
      expect(document, isNotNull);
      expect(document?.blocks.whereType<ReaderImageBlock>(), isNotEmpty);

      final persistedContent = await repository.getChapterContentById(
        metas.first.id,
      );
      expect(persistedContent, isNotNull);
      expect(persistedContent!.content, contains('第一章正文。'));
      expect(persistedContent.imageUrls, isNotEmpty);
      expect(persistedContent.document, isNull);

      final persisted = await repository.getChapterById(metas.first.id);
      expect(persisted, isNotNull);
      expect(persisted!.content, contains('第一章正文。'));
      expect(persisted.imageUrls, isNotEmpty);
      expect(persisted.document, isNotNull);
    });

    test('rejects ready epub chapters with missing stored content', () async {
      final now = DateTime.parse('2026-03-21T12:00:00.000Z');
      final file = File('${tempDir.path}/broken_ready.epub');
      await file.writeAsBytes(const <int>[1, 2, 3], flush: true);
      await repository.upsertBook(
        LocalBook(
          id: 'local_epub_broken_1',
          title: '损坏 EPUB',
          format: LocalBookFormat.epub,
          storagePath: file.path,
          fileSize: await file.length(),
          indexStatus: LocalBookIndexStatus.ready,
          chapterCount: 1,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.replaceChapters(
        bookId: 'local_epub_broken_1',
        chapters: <LocalChapter>[
          LocalChapter(
            id: 'local_epub_broken_1_0',
            bookId: 'local_epub_broken_1',
            chapterIndex: 0,
            title: '第一章',
            content: '',
            sourceRef: 'OPS/ch1.xhtml',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      await expectLater(
        () =>
            contentService.load(bookId: 'local_epub_broken_1', chapterIndex: 0),
        throwsA(
          isA<AppException>().having(
            (error) => error.briefMessage,
            'briefMessage',
            contains('重新索引'),
          ),
        ),
      );
    });

    test('loads pdf page content lazily and persists body cache', () async {
      final file = File('${tempDir.path}/sample.pdf');
      await file.writeAsBytes(const <int>[1, 2, 3], flush: true);
      final fileStat = await file.stat();
      final now = DateTime.parse('2026-03-21T12:00:00.000Z');

      await repository.upsertBook(
        LocalBook(
          id: 'local_pdf_lazy_1',
          title: 'PDF 按需正文测试',
          format: LocalBookFormat.pdf,
          storagePath: file.path,
          fileSize: fileStat.size,
          storageFileLastModifiedMs: fileStat.modified.millisecondsSinceEpoch,
          indexStatus: LocalBookIndexStatus.ready,
          chapterCount: 1,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.replaceChapters(
        bookId: 'local_pdf_lazy_1',
        chapters: <LocalChapter>[
          LocalChapter(
            id: 'local_pdf_lazy_1_0',
            bookId: 'local_pdf_lazy_1',
            chapterIndex: 0,
            title: '第 1 页',
            content: '',
            sourceRef: 'pdf:page:1',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      final contentService = LocalChapterContentService(
        localBookRepository: repository,
        indexService: indexService,
        storageService: storageService,
      );

      final parser = PdfLocalBookParser(
        extractor: _LocalChapterContentFakePdfTextExtractor(
          document: const LocalPdfDocument(pageCount: 1),
          pageTexts: const <int, String>{1: '第1章 开始\n第一页内容。'},
        ),
        isRuntimeSupported: () => true,
      );

      final chapter = await parser.parsePage(
        book: LocalBook(
          id: 'local_pdf_lazy_1',
          title: 'PDF 按需正文测试',
          format: LocalBookFormat.pdf,
          storagePath: file.path,
          fileSize: fileStat.size,
          storageFileLastModifiedMs: fileStat.modified.millisecondsSinceEpoch,
          indexStatus: LocalBookIndexStatus.ready,
          chapterCount: 1,
          createdAt: now,
          updatedAt: now,
        ),
        chapter: LocalChapter(
          id: 'local_pdf_lazy_1_0',
          bookId: 'local_pdf_lazy_1',
          chapterIndex: 0,
          title: '第 1 页',
          content: '',
          sourceRef: 'pdf:page:1',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.updateChapterContent(
        chapterId: 'local_pdf_lazy_1_0',
        content: chapter.content,
        imageUrls: chapter.imageUrls,
        document: chapter.document,
      );

      final loaded = await contentService.load(
        bookId: 'local_pdf_lazy_1',
        chapterIndex: 0,
      );
      expect(loaded.content, contains('第一页内容。'));
      expect(loaded.document, isNotNull);

      final persisted = await repository.getChapterContentById(
        'local_pdf_lazy_1_0',
      );
      expect(persisted, isNotNull);
      expect(persisted!.content, contains('第一页内容。'));
    });

    test('does not auto index while local book is still pending', () async {
      final file = File('${tempDir.path}/pending_book.txt');
      await file.writeAsString('第1章 开始\n第一章内容。');

      final now = DateTime.parse('2026-03-21T12:00:00.000Z');
      final pendingBook = LocalBook(
        id: 'local_pending_1',
        title: '待建立目录测试',
        format: LocalBookFormat.txt,
        storagePath: file.path,
        fileSize: await file.length(),
        indexStatus: LocalBookIndexStatus.pending,
        createdAt: now,
        updatedAt: now,
      );
      await repository.upsertBook(pendingBook);

      final fakeIndexService = _TrackingLocalBookIndexService(
        localBookRepository: repository,
        storageService: storageService,
        refreshedBook: pendingBook,
      );
      contentService = LocalChapterContentService(
        localBookRepository: repository,
        indexService: fakeIndexService,
        storageService: storageService,
      );

      await expectLater(
        () => contentService.load(bookId: 'local_pending_1', chapterIndex: 0),
        throwsA(
          isA<AppException>().having(
            (error) => error.briefMessage,
            'briefMessage',
            contains('目录尚未建立完成'),
          ),
        ),
      );
      expect(fakeIndexService.ensureIndexedCallCount, 0);
    });

    test(
      'rejects bootstrap chapter because preview moved to preview service',
      () async {
        final file = File('${tempDir.path}/pending_bootstrap_book.txt');
        await file.writeAsString('第1章 开始\n第一章正文内容。');

        final now = DateTime.parse('2026-03-21T12:00:00.000Z');
        final pendingBook = LocalBook(
          id: 'local_pending_bootstrap_1',
          title: '待建立正文直读测试',
          format: LocalBookFormat.txt,
          storagePath: file.path,
          fileSize: await file.length(),
          indexStatus: LocalBookIndexStatus.pending,
          createdAt: now,
          updatedAt: now,
        );
        await repository.upsertBook(pendingBook);

        await expectLater(
          () => contentService.load(
            bookId: 'local_pending_bootstrap_1',
            chapterId: 'bootstrap',
          ),
          throwsA(
            isA<AppException>().having(
              (error) => error.briefMessage,
              'briefMessage',
              contains('独立预览服务'),
            ),
          ),
        );
      },
    );

    test('prompts reindex when local book index is stale', () async {
      final file = File('${tempDir.path}/stale_book.txt');
      await file.writeAsString('第1章 开始\n第一章内容。');

      final now = DateTime.parse('2026-03-21T12:00:00.000Z');
      final staleBook = LocalBook(
        id: 'local_stale_1',
        title: '需重建目录测试',
        format: LocalBookFormat.txt,
        storagePath: file.path,
        fileSize: await file.length(),
        indexStatus: LocalBookIndexStatus.stale,
        chapterCount: 2,
        createdAt: now,
        updatedAt: now,
      );
      await repository.upsertBook(staleBook);

      final fakeIndexService = _TrackingLocalBookIndexService(
        localBookRepository: repository,
        storageService: storageService,
        refreshedBook: staleBook,
      );
      contentService = LocalChapterContentService(
        localBookRepository: repository,
        indexService: fakeIndexService,
        storageService: storageService,
      );

      await expectLater(
        () => contentService.load(bookId: 'local_stale_1', chapterIndex: 0),
        throwsA(
          isA<AppException>().having(
            (error) => error.briefMessage,
            'briefMessage',
            contains('目录已过期'),
          ),
        ),
      );
      expect(fakeIndexService.ensureIndexedCallCount, 0);
    });
  });
}

class _LocalChapterContentFakePdfTextExtractor
    implements LocalPdfTextExtractor {
  const _LocalChapterContentFakePdfTextExtractor({
    required this.document,
    required this.pageTexts,
  });

  final LocalPdfDocument document;
  final Map<int, String> pageTexts;

  @override
  Future<String> extractPageText({
    required LocalPdfDocument document,
    required int pageNumber,
  }) async {
    return pageTexts[pageNumber] ?? '';
  }

  @override
  Future<LocalPdfDocument> open(String path) async => document;
}

class _TrackingLocalBookIndexService extends LocalBookIndexService {
  _TrackingLocalBookIndexService({
    required LocalBookRepositoryImpl localBookRepository,
    required super.storageService,
    this.refreshedBook,
  }) : super(
         localBookRepository: localBookRepository,
         readerSystemSettingsService: ReaderSystemSettingsService(),
         bookshelfService: BookshelfService(),
         readingRecordService: ReadingRecordService(
           database: AppDatabase(executor: NativeDatabase.memory()),
         ),
       );

  final LocalBook? refreshedBook;
  int ensureIndexedCallCount = 0;

  @override
  Future<List<LocalChapter>> ensureIndexed({
    required String bookId,
    bool force = false,
  }) async {
    ensureIndexedCallCount += 1;
    return const <LocalChapter>[];
  }

  @override
  Future<LocalBook?> refreshBookState({required String bookId}) async {
    return refreshedBook;
  }
}

List<int> _encodeUtf16(
  String value, {
  required bool littleEndian,
  bool withBom = false,
}) {
  final bytes = <int>[];
  if (withBom) {
    if (littleEndian) {
      bytes.addAll(const <int>[0xFF, 0xFE]);
    } else {
      bytes.addAll(const <int>[0xFE, 0xFF]);
    }
  }
  for (final unit in value.codeUnits) {
    if (littleEndian) {
      bytes.add(unit & 0xFF);
      bytes.add((unit >> 8) & 0xFF);
    } else {
      bytes.add((unit >> 8) & 0xFF);
      bytes.add(unit & 0xFF);
    }
  }
  return bytes;
}
