import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/errors/app_exception.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/kindle_local_book_parser.dart';

void main() {
  group('KindleLocalBookParser', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'kindle_local_parser_test',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('parses mobi html, metadata and resources into chapters', () async {
      final file = File('${tempDir.path}/sample.mobi');
      await file.writeAsBytes(const <int>[1, 2, 3], flush: true);
      final parser = KindleLocalBookParser(
        extractor: _FakeKindleExtractor(
          payload: LocalKindleParsePayload(
            markupHtml: '''
<html>
  <head><title>Kindle 标题</title></head>
  <body>
    <h1>第一章</h1>
    <p>第一章内容。</p>
    <h2>第二章</h2>
    <p>第二章内容。</p>
    <img src="resource00000.jpg" />
  </body>
</html>
''',
            title: 'Kindle 标题',
            author: 'Kindle 作者',
            description: 'Kindle 简介',
            coverFileName: 'resource00000.jpg',
            resources: <LocalKindleResource>[
              LocalKindleResource(
                fileName: 'resource00000.jpg',
                bytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
              ),
            ],
          ),
        ),
      );

      final now = DateTime.parse('2026-04-16T12:00:00.000Z');
      final result = await parser.parse(
        LocalBook(
          id: 'local_mobi_1',
          title: 'fallback',
          format: LocalBookFormat.mobi,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(result.title, 'Kindle 标题');
      expect(result.author, 'Kindle 作者');
      expect(result.description, 'Kindle 简介');
      expect(result.coverPath, isNotNull);
      expect(File(result.coverPath!).existsSync(), isTrue);
      expect(result.chapters, hasLength(2));
      expect(result.chapters.first.title, '第一章');
      expect(result.chapters.last.imageUrls, isNotEmpty);
    });

    test('throws clear error when kindle file is DRM protected', () async {
      final file = File('${tempDir.path}/protected.azw3');
      await file.writeAsBytes(const <int>[1, 2, 3], flush: true);
      final parser = KindleLocalBookParser(
        extractor: _FakeKindleExtractor(
          payload: const LocalKindleParsePayload(
            markupHtml: '',
            encrypted: true,
          ),
        ),
      );

      final now = DateTime.parse('2026-04-16T12:00:00.000Z');
      await expectLater(
        () async => parser.parse(
          LocalBook(
            id: 'local_azw3_1',
            title: 'fallback',
            format: LocalBookFormat.azw3,
            storagePath: file.path,
            fileSize: await file.length(),
            createdAt: now,
            updatedAt: now,
          ),
        ),
        throwsA(
          isA<AppException>().having(
            (error) => error.briefMessage,
            'briefMessage',
            contains('无 DRM'),
          ),
        ),
      );
    });

    test('parses azw3 payload through the same kindle pipeline', () async {
      final file = File('${tempDir.path}/sample.azw3');
      await file.writeAsBytes(const <int>[1, 2, 3], flush: true);
      final parser = KindleLocalBookParser(
        extractor: _FakeKindleExtractor(
          payload: const LocalKindleParsePayload(
            markupHtml:
                '<html><body><h1>AZW3 章节</h1><p>AZW3 正文。</p></body></html>',
            title: 'AZW3 标题',
            author: 'AZW3 作者',
          ),
        ),
      );

      final now = DateTime.parse('2026-04-16T12:00:00.000Z');
      final result = await parser.parse(
        LocalBook(
          id: 'local_azw3_2',
          title: 'fallback',
          format: LocalBookFormat.azw3,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(result.title, 'AZW3 标题');
      expect(result.author, 'AZW3 作者');
      expect(result.chapters, hasLength(1));
      expect(result.chapters.single.title, 'AZW3 章节');
      expect(result.chapters.single.content, contains('AZW3 正文'));
    });

    test('parses azw payload through the same kindle pipeline', () async {
      final file = File('${tempDir.path}/sample.azw');
      await file.writeAsBytes(const <int>[1, 2, 3], flush: true);
      final parser = KindleLocalBookParser(
        extractor: _FakeKindleExtractor(
          payload: const LocalKindleParsePayload(
            markupHtml:
                '<html><body><h1>AZW 章节</h1><p>AZW 正文。</p></body></html>',
            title: 'AZW 标题',
            author: 'AZW 作者',
          ),
        ),
      );

      final now = DateTime.parse('2026-04-16T12:00:00.000Z');
      final result = await parser.parse(
        LocalBook(
          id: 'local_azw_1',
          title: 'fallback',
          format: LocalBookFormat.azw,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(result.title, 'AZW 标题');
      expect(result.author, 'AZW 作者');
      expect(result.chapters, hasLength(1));
      expect(result.chapters.single.title, 'AZW 章节');
      expect(result.chapters.single.content, contains('AZW 正文'));
    });
  });
}

class _FakeKindleExtractor implements LocalKindleContainerExtractor {
  const _FakeKindleExtractor({required this.payload});

  final LocalKindleParsePayload payload;

  @override
  Future<LocalKindleParsePayload> extract(String path) async => payload;
}
