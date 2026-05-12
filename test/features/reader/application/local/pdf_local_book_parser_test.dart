import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/errors/app_exception.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/pdf_local_book_parser.dart';

void main() {
  group('PdfLocalBookParser', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pdf_local_parser_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('extracts text pdf into page chapters', () async {
      final file = File('${tempDir.path}/sample.pdf');
      await file.writeAsBytes(const <int>[1, 2, 3], flush: true);
      final parser = PdfLocalBookParser(
        extractor: _FakePdfTextExtractor(
          document: LocalPdfDocument(
            pageCount: 2,
            title: 'PDF 标题',
            author: 'PDF 作者',
            subject: 'PDF 简介',
          ),
          pageTexts: <int, String>{1: '第1章 开始\n第一页内容。', 2: '第二页内容。'},
        ),
        isRuntimeSupported: () => true,
      );

      final now = DateTime.parse('2026-04-16T12:00:00.000Z');
      final result = await parser.parse(
        LocalBook(
          id: 'local_pdf_1',
          title: 'fallback',
          format: LocalBookFormat.pdf,
          storagePath: file.path,
          fileSize: await file.length(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(result.title, 'PDF 标题');
      expect(result.author, 'PDF 作者');
      expect(result.description, 'PDF 简介');
      expect(result.chapters, hasLength(2));
      expect(result.chapters.first.title, '第1章 开始');
      expect(result.chapters.last.title, '第 2 页');
      expect(result.chapters.last.content, contains('第二页内容'));
      expect(result.chapters.first.document, isNotNull);
      expect(
        result.chapters.first.document!.blocks.first,
        isA<ReaderTitleBlock>(),
      );
    });

    test('throws clear error when pdf has no text layer', () async {
      final file = File('${tempDir.path}/no_text.pdf');
      await file.writeAsBytes(const <int>[1, 2, 3], flush: true);
      final parser = PdfLocalBookParser(
        extractor: _FakePdfTextExtractor(
          document: const LocalPdfDocument(pageCount: 2),
          pageTexts: const <int, String>{1: '   ', 2: '\n\n'},
        ),
        isRuntimeSupported: () => true,
      );

      final now = DateTime.parse('2026-04-16T12:00:00.000Z');
      await expectLater(
        () async => parser.parse(
          LocalBook(
            id: 'local_pdf_2',
            title: 'fallback',
            format: LocalBookFormat.pdf,
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
            contains('无文本层'),
          ),
        ),
      );
    });

    test('throws clear error when pdf may be encrypted', () async {
      final file = File('${tempDir.path}/encrypted.pdf');
      await file.writeAsBytes(const <int>[1, 2, 3], flush: true);
      final parser = PdfLocalBookParser(
        extractor: const _ThrowingPdfTextExtractor('password required'),
        isRuntimeSupported: () => true,
      );

      final now = DateTime.parse('2026-04-16T12:00:00.000Z');
      await expectLater(
        () async => parser.parse(
          LocalBook(
            id: 'local_pdf_3',
            title: 'fallback',
            format: LocalBookFormat.pdf,
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
            contains('加密'),
          ),
        ),
      );
    });

    test('throws clear error on unsupported runtime', () async {
      final file = File('${tempDir.path}/unsupported.pdf');
      await file.writeAsBytes(const <int>[1, 2, 3], flush: true);
      final parser = PdfLocalBookParser(
        extractor: _FakePdfTextExtractor(
          document: const LocalPdfDocument(pageCount: 1),
          pageTexts: const <int, String>{1: 'content'},
        ),
        isRuntimeSupported: () => false,
      );

      final now = DateTime.parse('2026-04-16T12:00:00.000Z');
      await expectLater(
        () async => parser.parse(
          LocalBook(
            id: 'local_pdf_4',
            title: 'fallback',
            format: LocalBookFormat.pdf,
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
            contains('Android 或 iOS'),
          ),
        ),
      );
    });
  });
}

class _FakePdfTextExtractor implements LocalPdfTextExtractor {
  const _FakePdfTextExtractor({
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

class _ThrowingPdfTextExtractor implements LocalPdfTextExtractor {
  const _ThrowingPdfTextExtractor(this.message);

  final String message;

  @override
  Future<String> extractPageText({
    required LocalPdfDocument document,
    required int pageNumber,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<LocalPdfDocument> open(String path) async {
    throw Exception(message);
  }
}
