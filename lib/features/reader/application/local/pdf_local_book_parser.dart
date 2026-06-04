import 'dart:io';

import 'package:pdf_text_extract/pdf_text_extract.dart' as pdf_text;

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_codes.dart';
import '../../../../core/errors/error_stage.dart';
import '../../../../domain/entities/local_book.dart';
import '../../../../domain/entities/local_chapter.dart';
import '../../../../domain/entities/reader_document.dart';
import 'local_book_parser.dart';

/// PDF 文本抽取保留在独立 adapter 后面，避免把移动端插件能力扩散到业务层。
///
/// 退出条件：如果 `pdfrx` / PDFium 能稳定提供多端页元数据和文本抽取，
/// 则替换 `PackagePdfTextExtractor`，同时保留 PDF 阅读的轻索引、按页懒加载语义。
class PdfLocalBookParser implements LocalBookParser {
  const PdfLocalBookParser({
    LocalPdfTextExtractor extractor = const PackagePdfTextExtractor(),
    bool Function()? isRuntimeSupported,
  }) : _extractor = extractor,
       _isRuntimeSupported = isRuntimeSupported ?? _defaultRuntimeSupported;

  final LocalPdfTextExtractor _extractor;
  final bool Function() _isRuntimeSupported;

  @override
  bool supports(LocalBookFormat format) => format == LocalBookFormat.pdf;

  @override
  Future<LocalParsedBook> parse(LocalBook book) async {
    final file = File(book.storagePath);
    if (!await file.exists()) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '本地文件不存在：${book.storagePath}',
      );
    }

    if (!_isRuntimeSupported()) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: 'PDF 导入当前仅支持 Android 或 iOS 平台。',
      );
    }

    final document = await _openDocument(book.storagePath);
    if (document.pageCount <= 0) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: 'PDF 页数为空，无法建立章节索引。',
      );
    }

    final chapters = List<LocalParsedChapter>.generate(
      document.pageCount,
      (index) => LocalParsedChapter(
        title: '第 ${index + 1} 页',
        content: '',
        sourceRef: 'pdf:page:${index + 1}',
      ),
      growable: false,
    );

    return LocalParsedBook(
      chapters: chapters,
      title: _normalizeOptional(document.title, fallback: book.title),
      author: _normalizeNullable(document.author, fallback: book.author),
      description: _normalizeNullable(
        document.subject,
        fallback: book.description,
      ),
    );
  }

  Future<LocalParsedChapter> parsePage({
    required LocalBook book,
    required LocalChapter chapter,
  }) async {
    final sourceRef = chapter.sourceRef?.trim() ?? '';
    final pageNumber = _parsePageNumber(sourceRef);
    if (pageNumber == null || pageNumber <= 0) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: 'PDF 页面定位信息缺失，请重新索引后重试。',
      );
    }
    if (!_isRuntimeSupported()) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: 'PDF 导入当前仅支持 Android 或 iOS 平台。',
      );
    }
    final document = await _openDocument(book.storagePath);
    if (pageNumber > document.pageCount) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: 'PDF 页面不存在，请重新索引后重试。',
      );
    }
    final rawText = await _extractor.extractPageText(
      document: document,
      pageNumber: pageNumber,
    );
    final text = _normalizePdfText(rawText);
    if (text.isEmpty) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: 'PDF 当前页未提取到文本，可能是扫描版、图片版或无文本层页面。',
      );
    }
    final title = _resolvePageTitle(
      pageNumber,
      text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false),
    );
    return LocalParsedChapter(
      title: title,
      content: text,
      sourceRef: sourceRef,
      document: ReaderDocument.fromContent(
        content: text,
        title: title,
        includeTitleBlock: true,
      ),
    );
  }

  Future<LocalPdfDocument> _openDocument(String path) async {
    try {
      return await _extractor.open(path);
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('password') ||
          message.contains('encrypted') ||
          message.contains('decrypt')) {
        throw AppException(
          code: ErrorCode.decode,
          stage: ErrorStage.content,
          briefMessage: 'PDF 可能已加密或受密码保护，当前无法导入。',
        );
      }
      throw AppException(
        code: ErrorCode.decode,
        stage: ErrorStage.content,
        briefMessage: 'PDF 文本抽取失败：$error',
      );
    }
  }

  String _resolvePageTitle(int pageNumber, List<String> lines) {
    if (lines.isNotEmpty) {
      final first = lines.first;
      if (_looksLikeChapterTitle(first)) {
        return first;
      }
    }
    return '第 $pageNumber 页';
  }

  int? _parsePageNumber(String sourceRef) {
    const prefix = 'pdf:page:';
    if (!sourceRef.startsWith(prefix)) {
      return null;
    }
    return int.tryParse(sourceRef.substring(prefix.length).trim());
  }

  bool _looksLikeChapterTitle(String line) {
    final normalized = line.trim();
    if (normalized.isEmpty) {
      return false;
    }
    if (RegExp(r'^第.{1,12}[章节回部卷集篇]').hasMatch(normalized)) {
      return true;
    }
    if (RegExp(
      r'^(chapter|part)\s+\d+',
      caseSensitive: false,
    ).hasMatch(normalized)) {
      return true;
    }
    return false;
  }

  String _normalizePdfText(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t\u00A0]+'), ' ')
        .trim();
  }

  String _normalizeOptional(String? value, {required String fallback}) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
    return fallback;
  }

  String? _normalizeNullable(String? value, {required String? fallback}) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
    final fallbackNormalized = fallback?.trim();
    if (fallbackNormalized == null || fallbackNormalized.isEmpty) {
      return null;
    }
    return fallbackNormalized;
  }

  static bool _defaultRuntimeSupported() =>
      Platform.isAndroid || Platform.isIOS;
}

abstract class LocalPdfTextExtractor {
  const LocalPdfTextExtractor();

  Future<LocalPdfDocument> open(String path);

  Future<String> extractPageText({
    required LocalPdfDocument document,
    required int pageNumber,
  });
}

class LocalPdfDocument {
  const LocalPdfDocument({
    required this.pageCount,
    this.title,
    this.author,
    this.subject,
    this.delegate,
  });

  final int pageCount;
  final String? title;
  final String? author;
  final String? subject;
  final Object? delegate;
}

class PackagePdfTextExtractor implements LocalPdfTextExtractor {
  const PackagePdfTextExtractor();

  @override
  Future<LocalPdfDocument> open(String path) async {
    final document = await pdf_text.PDFDoc.fromPath(path);
    return LocalPdfDocument(
      pageCount: document.length,
      title: document.info.title,
      author: document.info.author,
      subject: document.info.subject,
      delegate: document,
    );
  }

  @override
  Future<String> extractPageText({
    required LocalPdfDocument document,
    required int pageNumber,
  }) async {
    final delegate = document.delegate;
    if (delegate is! pdf_text.PDFDoc) {
      throw StateError('Invalid PDF document delegate');
    }
    final page = delegate.pageAt(pageNumber);
    return page.text;
  }
}
