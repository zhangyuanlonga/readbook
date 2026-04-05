import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_appread/domain/entities/local_book.dart';
import 'package:flutter_appread/domain/entities/local_chapter.dart';
import 'package:flutter_appread/domain/entities/reader_document.dart';
import 'package:flutter_appread/features/reader/application/local/epub_local_book_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EpubLocalBookParser', () {
    late Directory tempDir;
    const parser = EpubLocalBookParser();

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('epub_local_parser_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('extracts readable html chapters from epub zip', () async {
      final archive =
          Archive()
            ..addFile(
              ArchiveFile(
                'OPS/chapter1.xhtml',
                0,
                utf8.encode(
                  '<html><body><h1>第一章</h1><p>第一章内容第一章内容第一章内容第一章内容第一章内容第一章内容。</p></body></html>',
                ),
              ),
            )
            ..addFile(
              ArchiveFile(
                'OPS/chapter2.xhtml',
                0,
                utf8.encode(
                  '<html><body><h1>第二章</h1><p>第二章内容第二章内容第二章内容第二章内容第二章内容第二章内容。</p></body></html>',
                ),
              ),
            );

      final encoded = ZipEncoder().encode(archive);
      expect(encoded, isNotNull);

      final file = File('${tempDir.path}/sample.epub');
      await file.writeAsBytes(encoded!);

      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      final book = LocalBook(
        id: 'local_epub_1',
        title: 'epub测试',
        format: LocalBookFormat.epub,
        storagePath: file.path,
        fileSize: await file.length(),
        createdAt: now,
        updatedAt: now,
      );
      final result = await parser.parse(book);

      expect(result.chapters, hasLength(2));
      expect(result.chapters.first.title, contains('第一章'));
      expect(result.chapters.last.title, contains('第二章'));
      final firstChapterContent = await parser.parseChapter(
        book: book,
        chapter: LocalChapter(
          id: '${book.id}_0',
          bookId: book.id,
          chapterIndex: 0,
          title: result.chapters.first.title,
          content: '',
          sourceRef: result.chapters.first.sourceRef,
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(firstChapterContent.document, isNotNull);
      expect(
        firstChapterContent.document!.blocks.first,
        isA<ReaderTitleBlock>(),
      );
    });

    test('uses spine order instead of filename order and skips nav docs', () async {
      final archive =
          Archive()
            ..addFile(
              ArchiveFile(
                'META-INF/container.xml',
                0,
                utf8.encode('''
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
'''),
              ),
            )
            ..addFile(
              ArchiveFile(
                'OPS/content.opf',
                0,
                utf8.encode('''
<?xml version="1.0" encoding="UTF-8"?>
<package version="3.0" xmlns="http://www.idpf.org/2007/opf">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>排序修复测试</dc:title>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="chap10" href="chapter10.xhtml" media-type="application/xhtml+xml"/>
    <item id="chap2" href="chapter2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="nav"/>
    <itemref idref="chap2"/>
    <itemref idref="chap10"/>
  </spine>
</package>
'''),
              ),
            )
            ..addFile(
              ArchiveFile(
                'OPS/nav.xhtml',
                0,
                utf8.encode(
                  '<html><body><nav><ol><li>目录页</li></ol></nav></body></html>',
                ),
              ),
            )
            ..addFile(
              ArchiveFile(
                'OPS/chapter10.xhtml',
                0,
                utf8.encode(
                  '<html><body><h1>第十章</h1><p>第十章内容第十章内容第十章内容第十章内容第十章内容第十章内容。</p></body></html>',
                ),
              ),
            )
            ..addFile(
              ArchiveFile(
                'OPS/chapter2.xhtml',
                0,
                utf8.encode(
                  '<html><body><h1>第二章</h1><p>第二章内容第二章内容第二章内容第二章内容第二章内容第二章内容。</p></body></html>',
                ),
              ),
            );

      final encoded = ZipEncoder().encode(archive);
      expect(encoded, isNotNull);

      final file = File('${tempDir.path}/sample_spine.epub');
      await file.writeAsBytes(encoded!);

      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      final result = await parser.parse(
        LocalBook(
          id: 'local_epub_spine_1',
          title: 'spine排序测试',
          format: LocalBookFormat.epub,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(result.title, '排序修复测试');
      expect(result.chapters, hasLength(2));
      expect(result.chapters.map((chapter) => chapter.title), <String>[
        '第二章',
        '第十章',
      ]);
    });

    test(
      'keeps very short body chapters instead of filtering them out',
      () async {
        final archive =
            Archive()
              ..addFile(
                ArchiveFile(
                  'META-INF/container.xml',
                  0,
                  utf8.encode('''
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
'''),
                ),
              )
              ..addFile(
                ArchiveFile(
                  'OPS/content.opf',
                  0,
                  utf8.encode('''
<?xml version="1.0" encoding="UTF-8"?>
<package version="3.0" xmlns="http://www.idpf.org/2007/opf">
  <manifest>
    <item id="short" href="short.xhtml" media-type="application/xhtml+xml"/>
    <item id="normal" href="normal.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="short"/>
    <itemref idref="normal"/>
  </spine>
</package>
'''),
                ),
              )
              ..addFile(
                ArchiveFile(
                  'OPS/short.xhtml',
                  0,
                  utf8.encode('<html><body><h1>其一</h1><p>风。</p></body></html>'),
                ),
              )
              ..addFile(
                ArchiveFile(
                  'OPS/normal.xhtml',
                  0,
                  utf8.encode(
                    '<html><body><h1>其二</h1><p>云起，月明。</p></body></html>',
                  ),
                ),
              );

        final encoded = ZipEncoder().encode(archive);
        expect(encoded, isNotNull);

        final file = File('${tempDir.path}/short_body.epub');
        await file.writeAsBytes(encoded!);

        final now = DateTime.parse('2026-02-23T12:00:00.000Z');
        final result = await parser.parse(
          LocalBook(
            id: 'local_epub_short_body_1',
            title: '短正文测试',
            format: LocalBookFormat.epub,
            storagePath: file.path,
            fileSize: await file.length(),
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(result.chapters, hasLength(2));
        expect(result.chapters.first.title, '其一');
        expect(result.chapters.first.document, isNotNull);
        expect(
          result.chapters.first.document!.blocks.first,
          isA<ReaderTitleBlock>(),
        );
      },
    );

    test(
      'filters explicit metadata pages while keeping short body chapters',
      () async {
        final archive =
            Archive()
              ..addFile(
                ArchiveFile(
                  'META-INF/container.xml',
                  0,
                  utf8.encode('''
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
'''),
                ),
              )
              ..addFile(
                ArchiveFile(
                  'OPS/content.opf',
                  0,
                  utf8.encode('''
<?xml version="1.0" encoding="UTF-8"?>
<package version="3.0" xmlns="http://www.idpf.org/2007/opf">
  <manifest>
    <item id="copyright" href="copyright.xhtml" media-type="application/xhtml+xml"/>
    <item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="copyright"/>
    <itemref idref="chapter1"/>
  </spine>
</package>
'''),
                ),
              )
              ..addFile(
                ArchiveFile(
                  'OPS/copyright.xhtml',
                  0,
                  utf8.encode(
                    '<html><body><h1>版权页</h1><p>版权所有。</p></body></html>',
                  ),
                ),
              )
              ..addFile(
                ArchiveFile(
                  'OPS/chapter1.xhtml',
                  0,
                  utf8.encode(
                    '<html><body><h1>第一章</h1><p>雨。</p></body></html>',
                  ),
                ),
              );

        final encoded = ZipEncoder().encode(archive);
        expect(encoded, isNotNull);

        final file = File('${tempDir.path}/metadata_filter.epub');
        await file.writeAsBytes(encoded!);

        final now = DateTime.parse('2026-02-23T12:00:00.000Z');
        final result = await parser.parse(
          LocalBook(
            id: 'local_epub_metadata_filter_1',
            title: '元数据过滤测试',
            format: LocalBookFormat.epub,
            storagePath: file.path,
            fileSize: await file.length(),
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(result.chapters, hasLength(1));
        expect(result.chapters.single.title, '第一章');
      },
    );

    test('extracts local image urls for image-heavy epub chapters', () async {
      final archive =
          Archive()
            ..addFile(
              ArchiveFile(
                'OPS/chapter1.xhtml',
                0,
                utf8.encode(
                  '<html><body><h1>第一章</h1><img src="images/p1.jpg" /></body></html>',
                ),
              ),
            )
            ..addFile(ArchiveFile('OPS/images/p1.jpg', 3, [1, 2, 3]));

      final encoded = ZipEncoder().encode(archive);
      expect(encoded, isNotNull);

      final file = File('${tempDir.path}/sample_image.epub');
      await file.writeAsBytes(encoded!);

      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      final result = await parser.parse(
        LocalBook(
          id: 'local_epub_image_1',
          title: 'epub图片测试',
          format: LocalBookFormat.epub,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(result.chapters, hasLength(1));
      expect(result.chapters.first.imageUrls, isEmpty);
      expect(result.chapters.first.sourceRef, 'OPS/chapter1.xhtml');
      final parsedChapter = await parser.parseChapter(
        book: LocalBook(
          id: 'local_epub_image_1',
          title: 'epub图片测试',
          format: LocalBookFormat.epub,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
        chapter: LocalChapter(
          id: 'chapter_1',
          bookId: 'local_epub_image_1',
          chapterIndex: 0,
          title: result.chapters.first.title,
          content: '',
          sourceRef: result.chapters.first.sourceRef,
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(parsedChapter.imageUrls, isNotEmpty);
      final firstImageUri = Uri.parse(parsedChapter.imageUrls.first);
      expect(firstImageUri.scheme, 'file');
      expect(File.fromUri(firstImageUri).existsSync(), isTrue);
    });

    test('materializes svg chapter resources as readable image urls', () async {
      final archive =
          Archive()
            ..addFile(
              ArchiveFile(
                'OPS/chapter1.xhtml',
                0,
                utf8.encode(
                  '<html><body><h1>SVG 章节</h1><img src="images/p1.svg" /></body></html>',
                ),
              ),
            )
            ..addFile(
              ArchiveFile(
                'OPS/images/p1.svg',
                0,
                utf8.encode(
                  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><rect width="24" height="24" fill="#222"/><circle cx="12" cy="12" r="6" fill="#fff"/></svg>',
                ),
              ),
            );

      final encoded = ZipEncoder().encode(archive);
      expect(encoded, isNotNull);

      final file = File('${tempDir.path}/sample_svg.epub');
      await file.writeAsBytes(encoded!);

      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      final result = await parser.parse(
        LocalBook(
          id: 'local_epub_svg_1',
          title: 'epub svg 测试',
          format: LocalBookFormat.epub,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final parsedChapter = await parser.parseChapter(
        book: LocalBook(
          id: 'local_epub_svg_1',
          title: 'epub svg 测试',
          format: LocalBookFormat.epub,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
        chapter: LocalChapter(
          id: 'chapter_svg_1',
          bookId: 'local_epub_svg_1',
          chapterIndex: 0,
          title: result.chapters.first.title,
          content: '',
          sourceRef: result.chapters.first.sourceRef,
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(parsedChapter.imageUrls, hasLength(1));
      final imageUri = Uri.parse(parsedChapter.imageUrls.single);
      expect(imageUri.scheme, 'file');
      expect(imageUri.path.toLowerCase(), endsWith('.svg'));
      expect(File.fromUri(imageUri).existsSync(), isTrue);
    });

    test('keeps inline image marker within mixed epub content', () async {
      final archive =
          Archive()
            ..addFile(
              ArchiveFile(
                'OPS/chapter1.xhtml',
                0,
                utf8.encode(
                  '<html><body><p>第一段文字。</p><img src="images/p1.jpg" /><p>第二段文字。</p></body></html>',
                ),
              ),
            )
            ..addFile(ArchiveFile('OPS/images/p1.jpg', 3, [1, 2, 3]));

      final encoded = ZipEncoder().encode(archive);
      expect(encoded, isNotNull);

      final file = File('${tempDir.path}/sample_mixed.epub');
      await file.writeAsBytes(encoded!);

      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      final result = await parser.parse(
        LocalBook(
          id: 'local_epub_mixed_1',
          title: 'epub图文测试',
          format: LocalBookFormat.epub,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(result.chapters, hasLength(1));
      expect(result.chapters.first.content, isEmpty);
      final parsedChapter = await parser.parseChapter(
        book: LocalBook(
          id: 'local_epub_mixed_1',
          title: 'epub图文测试',
          format: LocalBookFormat.epub,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
        chapter: LocalChapter(
          id: 'chapter_1',
          bookId: 'local_epub_mixed_1',
          chapterIndex: 0,
          title: result.chapters.first.title,
          content: '',
          sourceRef: result.chapters.first.sourceRef,
          createdAt: now,
          updatedAt: now,
        ),
      );
      expect(parsedChapter.content, contains('第一段文字。'));
      expect(parsedChapter.content, contains('[[appread-image:'));
      expect(parsedChapter.content, contains('第二段文字。'));
    });

    test(
      'builds structured ReaderDocument blocks for image-heavy chapters',
      () async {
        final archive =
            Archive()
              ..addFile(
                ArchiveFile(
                  'OPS/chapter1.xhtml',
                  0,
                  utf8.encode(
                    '<html><body><h1>结构化</h1><p>段落文本</p><img src="images/p1.jpg" /></body></html>',
                  ),
                ),
              )
              ..addFile(ArchiveFile('OPS/images/p1.jpg', 3, [1, 2, 3]));

        final encoded = ZipEncoder().encode(archive);
        expect(encoded, isNotNull);

        final file = File('${tempDir.path}/structured.epub');
        await file.writeAsBytes(encoded!);
        final now = DateTime.parse('2026-02-23T12:00:00.000Z');
        final book = LocalBook(
          id: 'local_epub_structured_1',
          title: '结构化测试',
          format: LocalBookFormat.epub,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        );
        final result = await parser.parse(book);
        final chapter = await parser.parseChapter(
          book: book,
          chapter: LocalChapter(
            id: '${book.id}_0',
            bookId: book.id,
            chapterIndex: 0,
            title: result.chapters.first.title,
            content: '',
            sourceRef: result.chapters.first.sourceRef,
            createdAt: now,
            updatedAt: now,
          ),
        );
        expect(chapter.document, isNotNull);
        expect(
          chapter.document!.blocks,
          containsAllInOrder(<Matcher>[
            isA<ReaderTitleBlock>(),
            isA<ReaderTextBlock>(),
            isA<ReaderImageBlock>(),
          ]),
        );
      },
    );

    test('builds lightweight preview document during indexing parse', () async {
      final archive =
          Archive()..addFile(
            ArchiveFile(
              'OPS/chapter1.xhtml',
              0,
              utf8.encode(
                '<html><body><h1>预览标题</h1><p>这是一段很短的正文预览。</p></body></html>',
              ),
            ),
          );

      final encoded = ZipEncoder().encode(archive);
      expect(encoded, isNotNull);

      final file = File('${tempDir.path}/preview_document.epub');
      await file.writeAsBytes(encoded!);

      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      final result = await parser.parse(
        LocalBook(
          id: 'local_epub_preview_document_1',
          title: '预览结构测试',
          format: LocalBookFormat.epub,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(result.chapters, hasLength(1));
      expect(result.chapters.first.document, isNotNull);
      expect(
        result.chapters.first.document!.blocks,
        containsAllInOrder(<Matcher>[
          isA<ReaderTitleBlock>(),
          isA<ReaderTextBlock>(),
        ]),
      );
    });

    test(
      'falls back to chapter title block when html has no heading',
      () async {
        final archive =
            Archive()..addFile(
              ArchiveFile(
                'OPS/chapter1.xhtml',
                0,
                utf8.encode('<html><body><p>只有正文。</p></body></html>'),
              ),
            );

        final encoded = ZipEncoder().encode(archive);
        expect(encoded, isNotNull);

        final file = File('${tempDir.path}/fallback_title.epub');
        await file.writeAsBytes(encoded!);
        final now = DateTime.parse('2026-02-23T12:00:00.000Z');
        final chapter = await parser.parseChapter(
          book: LocalBook(
            id: 'local_epub_title_fallback_1',
            title: '标题回填测试',
            format: LocalBookFormat.epub,
            storagePath: file.path,
            fileSize: await file.length(),
            createdAt: now,
            updatedAt: now,
          ),
          chapter: LocalChapter(
            id: 'chapter_1',
            bookId: 'local_epub_title_fallback_1',
            chapterIndex: 0,
            title: '外部章节标题',
            content: '',
            sourceRef: 'OPS/chapter1.xhtml',
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(chapter.document, isNotNull);
        expect(chapter.document!.blocks.first, isA<ReaderTitleBlock>());
        expect(
          (chapter.document!.blocks.first as ReaderTitleBlock).text,
          '外部章节标题',
        );
      },
    );

    test('renders list items as separate readable text blocks', () async {
      final archive =
          Archive()..addFile(
            ArchiveFile(
              'OPS/chapter1.xhtml',
              0,
              utf8.encode(
                '<html><body><ul><li>第一项</li><li>第二项</li></ul></body></html>',
              ),
            ),
          );

      final encoded = ZipEncoder().encode(archive);
      expect(encoded, isNotNull);

      final file = File('${tempDir.path}/list_items.epub');
      await file.writeAsBytes(encoded!);
      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      final chapter = await parser.parseChapter(
        book: LocalBook(
          id: 'local_epub_list_1',
          title: '列表测试',
          format: LocalBookFormat.epub,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
        chapter: LocalChapter(
          id: 'chapter_1',
          bookId: 'local_epub_list_1',
          chapterIndex: 0,
          title: '列表章节',
          content: '',
          sourceRef: 'OPS/chapter1.xhtml',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final textBlocks = chapter.document!.blocks.whereType<ReaderTextBlock>();
      expect(textBlocks, isEmpty);
      final listBlocks =
          chapter.document!.blocks.whereType<ReaderListItemBlock>();
      expect(listBlocks.map((block) => block.text), contains('第一项'));
      expect(listBlocks.map((block) => block.text), contains('第二项'));
    });

    test('parses quote and caption blocks into structured document', () async {
      final archive =
          Archive()
            ..addFile(
              ArchiveFile(
                'OPS/chapter1.xhtml',
                0,
                utf8.encode(
                  '<html><body><blockquote>引用内容</blockquote><figure><img src="images/p1.jpg" /><figcaption>插图说明</figcaption></figure></body></html>',
                ),
              ),
            )
            ..addFile(ArchiveFile('OPS/images/p1.jpg', 3, [1, 2, 3]));

      final encoded = ZipEncoder().encode(archive);
      expect(encoded, isNotNull);

      final file = File('${tempDir.path}/quote_caption.epub');
      await file.writeAsBytes(encoded!);
      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      final chapter = await parser.parseChapter(
        book: LocalBook(
          id: 'local_epub_quote_caption_1',
          title: '引用图注测试',
          format: LocalBookFormat.epub,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
        chapter: LocalChapter(
          id: 'chapter_1',
          bookId: 'local_epub_quote_caption_1',
          chapterIndex: 0,
          title: '引用图注章节',
          content: '',
          sourceRef: 'OPS/chapter1.xhtml',
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(chapter.document, isNotNull);
      expect(
        chapter.document!.blocks.whereType<ReaderQuoteBlock>(),
        isNotEmpty,
      );
      expect(
        chapter.document!.blocks.whereType<ReaderCaptionBlock>(),
        isNotEmpty,
      );
    });

    test('parses footnotes into dedicated structured blocks', () async {
      final archive =
          Archive()..addFile(
            ArchiveFile(
              'OPS/chapter1.xhtml',
              0,
              utf8.encode('''
<html>
  <body>
    <p>正文内容<a href="#fn1" epub:type="noteref">1</a></p>
    <aside id="fn1" epub:type="footnote">
      <p>脚注一：补充说明。</p>
    </aside>
  </body>
</html>
'''),
            ),
          );

      final encoded = ZipEncoder().encode(archive);
      expect(encoded, isNotNull);

      final file = File('${tempDir.path}/footnote.epub');
      await file.writeAsBytes(encoded!);
      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      final chapter = await parser.parseChapter(
        book: LocalBook(
          id: 'local_epub_footnote_1',
          title: '脚注测试',
          format: LocalBookFormat.epub,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
        chapter: LocalChapter(
          id: 'chapter_footnote_1',
          bookId: 'local_epub_footnote_1',
          chapterIndex: 0,
          title: '脚注章节',
          content: '',
          sourceRef: 'OPS/chapter1.xhtml',
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(chapter.document, isNotNull);
      expect(
        chapter.document!.blocks.whereType<ReaderFootnoteBlock>(),
        isNotEmpty,
      );
      expect(chapter.content, contains('注: 脚注一：补充说明。'));
    });

    test('keeps complex mixed-media chapter order stable', () async {
      final archive =
          Archive()
            ..addFile(
              ArchiveFile(
                'OPS/chapter1.xhtml',
                0,
                utf8.encode('''
<html>
  <body>
    <h1>复杂章节</h1>
    <p>第一段。</p>
    <img src="images/p1.jpg" />
    <figure>
      <img src="images/p2.svg" />
      <figcaption>图注说明</figcaption>
    </figure>
    <aside id="fn1" epub:type="footnote">
      <p>脚注内容。</p>
    </aside>
    <p>第二段。</p>
  </body>
</html>
'''),
              ),
            )
            ..addFile(ArchiveFile('OPS/images/p1.jpg', 3, [1, 2, 3]))
            ..addFile(
              ArchiveFile(
                'OPS/images/p2.svg',
                0,
                utf8.encode(
                  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20"><rect width="20" height="20" fill="#000"/></svg>',
                ),
              ),
            );

      final encoded = ZipEncoder().encode(archive);
      expect(encoded, isNotNull);

      final file = File('${tempDir.path}/mixed_media.epub');
      await file.writeAsBytes(encoded!);
      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      final chapter = await parser.parseChapter(
        book: LocalBook(
          id: 'local_epub_mixed_media_1',
          title: '复杂章节测试',
          format: LocalBookFormat.epub,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
        chapter: LocalChapter(
          id: 'chapter_mixed_media_1',
          bookId: 'local_epub_mixed_media_1',
          chapterIndex: 0,
          title: '复杂章节',
          content: '',
          sourceRef: 'OPS/chapter1.xhtml',
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(chapter.document, isNotNull);
      expect(
        chapter.document!.blocks,
        containsAllInOrder(<Matcher>[
          isA<ReaderTitleBlock>(),
          isA<ReaderTextBlock>(),
          isA<ReaderImageBlock>(),
          isA<ReaderImageBlock>(),
          isA<ReaderCaptionBlock>(),
          isA<ReaderFootnoteBlock>(),
          isA<ReaderTextBlock>(),
        ]),
      );
      expect(chapter.imageUrls, hasLength(2));
    });
  });
}
