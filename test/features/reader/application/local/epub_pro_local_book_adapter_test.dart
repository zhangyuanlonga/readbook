import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/epub_pro_local_book_adapter.dart';

void main() {
  group('EpubProLocalBookAdapter', () {
    const adapter = EpubProLocalBookAdapter();

    test(
      'maps metadata and spine ordered chapters to local parser model',
      () async {
        final bytes = _encodeEpub(
          contentOpf: '''
<?xml version="1.0" encoding="UTF-8"?>
<package version="3.0" unique-identifier="book-id" xmlns="http://www.idpf.org/2007/opf">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="book-id">urn:test:spine</dc:identifier>
    <dc:title>排序修复测试</dc:title>
    <dc:creator>测试作者</dc:creator>
    <dc:language>zh-CN</dc:language>
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
''',
          files: <String, String>{
            'OPS/nav.xhtml': '''
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>目录</title></head>
  <body>
    <nav epub:type="toc">
      <ol>
        <li><a href="chapter2.xhtml">第二章</a></li>
        <li><a href="chapter10.xhtml">第十章</a></li>
      </ol>
    </nav>
  </body>
</html>
''',
            'OPS/chapter10.xhtml':
                '<html><body><h1>第十章</h1><p>第十章内容。</p></body></html>',
            'OPS/chapter2.xhtml':
                '<html><body><h1>第二章</h1><p>第二章内容。</p></body></html>',
          },
        );

        final result = await adapter.parseIndex(bytes);

        expect(result.parsedBook.title, '排序修复测试');
        expect(result.parsedBook.author, '测试作者');
        expect(result.spineItemCount, 3);
        expect(result.manifestItemCount, 3);
        expect(
          result.parsedBook.chapters.map((chapter) => chapter.sourceRef),
          <String>['OPS/chapter2.xhtml', 'OPS/chapter10.xhtml'],
        );
      },
    );

    test(
      'keeps nav anchors in source refs for existing lazy chapter parser',
      () async {
        final bytes = _encodeEpub(
          contentOpf: '''
<?xml version="1.0" encoding="UTF-8"?>
<package version="3.0" unique-identifier="book-id" xmlns="http://www.idpf.org/2007/opf">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="book-id">urn:test:fragment</dc:identifier>
    <dc:title>Fragment 测试</dc:title>
    <dc:language>zh-CN</dc:language>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    <item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="nav"/>
    <itemref idref="chapter1"/>
  </spine>
</package>
''',
          files: <String, String>{
            'OPS/nav.xhtml': '''
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>目录</title></head>
  <body>
    <nav epub:type="toc">
      <ol>
        <li><a href="chapter1.xhtml#part1">第一节</a></li>
        <li><a href="chapter1.xhtml#part2">第二节</a></li>
      </ol>
    </nav>
  </body>
</html>
''',
            'OPS/chapter1.xhtml': '''
<html>
  <body>
    <h1 id="part1">第一节</h1>
    <p>第一节内容。</p>
    <h1 id="part2">第二节</h1>
    <p>第二节内容。</p>
  </body>
</html>
''',
          },
        );

        final result = await adapter.parseIndex(bytes);

        expect(
          result.parsedBook.chapters.map((chapter) => chapter.title),
          contains('第一节'),
        );
        expect(
          result.parsedBook.chapters.map((chapter) => chapter.sourceRef),
          contains('epub-ref://chapter?path=OPS%2Fchapter1.xhtml&start=part1'),
        );
        expect(
          result.parsedBook.chapters.map((chapter) => chapter.title),
          isNot(contains('第二节')),
          reason: 'epub_pro 5.6.0 会对同一 HTML 文件去重，fragment 拆章仍需保留现有 parser。',
        );
      },
    );
  });
}

List<int> _encodeEpub({
  required String contentOpf,
  required Map<String, String> files,
}) {
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
        ..addFile(ArchiveFile('OPS/content.opf', 0, utf8.encode(contentOpf)));
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile(entry.key, 0, utf8.encode(entry.value)));
  }
  return ZipEncoder().encode(archive);
}
