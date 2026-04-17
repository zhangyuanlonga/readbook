import 'package:shuxiang_reading_next/domain/entities/local_chapter.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_chapter_content_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_book_preview_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_reader_identity.dart';
import 'package:shuxiang_reading_next/features/reader/application/local_content_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLocalChapterContentService extends LocalChapterContentService {
  _FakeLocalChapterContentService(this.chapter);

  final LocalChapter chapter;

  String? bookId;
  String? chapterId;
  int? chapterIndex;

  @override
  Future<LocalChapter> load({
    required String bookId,
    String? chapterId,
    int? chapterIndex,
  }) async {
    this.bookId = bookId;
    this.chapterId = chapterId;
    this.chapterIndex = chapterIndex;
    return chapter;
  }
}

class _FakeLocalBookPreviewService extends LocalBookPreviewService {
  _FakeLocalBookPreviewService(this.chapter);

  final LocalChapter chapter;
  String? bookId;

  @override
  Future<LocalChapter> loadTxtBootstrapPreview({required String bookId}) async {
    this.bookId = bookId;
    return chapter;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.parse('2026-04-02T12:00:00.000Z');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('keeps mixed inline images in text reader document', () async {
    final fakeService = _FakeLocalChapterContentService(
      LocalChapter(
        id: 'chapter_1',
        bookId: 'book_1',
        chapterIndex: 0,
        title: '第一章',
        content: '第一段文字。\n\n[[appread-image:file:///tmp/p1.jpg]]\n\n第二段文字。',
        imageUrls: const <String>['file:///tmp/p1.jpg'],
        createdAt: now,
        updatedAt: now,
      ),
    );
    final provider = LocalContentProvider(chapterContentService: fakeService);

    final result = await provider.loadChapterContent(
      sourceId: LocalReaderIdentity.localSourceId,
      bookId: 'book_1',
      chapterUrl: LocalReaderIdentity.buildChapterUrl('chapter_1'),
      chapterId: 'chapter_1',
      chapterIndex: 0,
    );

    expect(result.isImageContent, isFalse);
    expect(result.imageUrls, isEmpty);
    expect(result.document.blocks, hasLength(3));
    expect(result.document.blocks[1], isA<ReaderImageBlock>());
    expect(fakeService.bookId, 'book_1');
    expect(fakeService.chapterId, 'chapter_1');
    expect(fakeService.chapterIndex, 0);
  });

  test('maps pure image local chapters to manga-style payload', () async {
    final fakeService = _FakeLocalChapterContentService(
      LocalChapter(
        id: 'chapter_2',
        bookId: 'book_1',
        chapterIndex: 1,
        title: '第二章',
        content:
            '[[appread-image:file:///tmp/p1.jpg]]\n\n[[appread-image:file:///tmp/p2.jpg]]',
        imageUrls: const <String>['file:///tmp/p1.jpg', 'file:///tmp/p2.jpg'],
        createdAt: now,
        updatedAt: now,
      ),
    );
    final provider = LocalContentProvider(chapterContentService: fakeService);

    final result = await provider.loadChapterContent(
      sourceId: LocalReaderIdentity.localSourceId,
      bookId: 'book_1',
      chapterUrl: LocalReaderIdentity.buildChapterUrl('chapter_2'),
      chapterId: 'chapter_2',
      chapterIndex: 1,
    );

    expect(result.isImageContent, isTrue);
    expect(result.content, isEmpty);
    expect(result.imageUrls, hasLength(2));
    expect(result.document.isPureImageDocument, isTrue);
  });

  test('prefers structured local chapter document when available', () async {
    final fakeService = _FakeLocalChapterContentService(
      LocalChapter(
        id: 'chapter_3',
        bookId: 'book_1',
        chapterIndex: 2,
        title: '第三章',
        content: '兼容文本',
        imageUrls: const <String>['file:///tmp/p3.jpg'],
        createdAt: now,
        updatedAt: now,
        document: ReaderDocument(
          blocks: const <ReaderBlock>[
            ReaderTitleBlock(text: '第三章', level: 1),
            ReaderTextBlock(text: '结构化正文'),
            ReaderImageBlock(imageUrl: 'file:///tmp/p3.jpg'),
          ],
        ),
      ),
    );
    final provider = LocalContentProvider(chapterContentService: fakeService);

    final result = await provider.loadChapterContent(
      sourceId: LocalReaderIdentity.localSourceId,
      bookId: 'book_1',
      chapterUrl: LocalReaderIdentity.buildChapterUrl('chapter_3'),
      chapterId: 'chapter_3',
      chapterIndex: 2,
    );

    expect(result.document.blocks.first, isA<ReaderTitleBlock>());
    expect(result.document.blocks[1], isA<ReaderTextBlock>());
    expect(result.document.blocks.last, isA<ReaderImageBlock>());
    expect(result.content, contains('第三章'));
    expect(result.content, contains('结构化正文'));
  });

  test(
    'routes bootstrap chapter to preview service instead of chapter service',
    () async {
      final fakeContentService = _FakeLocalChapterContentService(
        LocalChapter(
          id: 'chapter_unused',
          bookId: 'book_1',
          chapterIndex: 9,
          title: 'unused',
          content: 'unused',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final fakePreviewService = _FakeLocalBookPreviewService(
        LocalChapter(
          id: 'book_1_bootstrap',
          bookId: 'book_1',
          chapterIndex: 0,
          title: '开始阅读',
          content: '预览正文',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final provider = LocalContentProvider(
        chapterContentService: fakeContentService,
        previewService: fakePreviewService,
      );

      final result = await provider.loadChapterContent(
        sourceId: LocalReaderIdentity.localSourceId,
        bookId: 'book_1',
        chapterUrl: '',
        chapterId: 'bootstrap',
      );

      expect(result.content, contains('预览正文'));
      expect(fakePreviewService.bookId, 'book_1');
      expect(fakeContentService.bookId, isNull);
    },
  );
}
