import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_appread/domain/entities/local_book.dart';
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
      final result = await parser.parse(
        LocalBook(
          id: 'local_epub_1',
          title: 'epub测试',
          format: LocalBookFormat.epub,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(result.chapters, hasLength(2));
      expect(result.chapters.first.title, contains('第一章'));
      expect(result.chapters.last.title, contains('第二章'));
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
      expect(result.chapters.first.imageUrls, isNotEmpty);
      final firstImageUri = Uri.parse(result.chapters.first.imageUrls.first);
      expect(firstImageUri.scheme, 'file');
      expect(File.fromUri(firstImageUri).existsSync(), isTrue);
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
      expect(result.chapters.first.content, contains('第一段文字。'));
      expect(result.chapters.first.content, contains('[[appread-image:'));
      expect(result.chapters.first.content, contains('第二段文字。'));
    });
  });
}
