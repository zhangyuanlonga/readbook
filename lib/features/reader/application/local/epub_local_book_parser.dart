import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_codes.dart';
import '../../../../core/errors/error_stage.dart';
import '../../../../domain/entities/local_book.dart';
import 'local_book_parser.dart';

class EpubLocalBookParser implements LocalBookParser {
  const EpubLocalBookParser();

  static const List<String> _supportedExtensions = <String>[
    '.xhtml',
    '.html',
    '.htm',
  ];

  @override
  bool supports(LocalBookFormat format) {
    return format == LocalBookFormat.epub;
  }

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

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: 'EPUB 文件为空，无法建立章节索引。',
      );
    }

    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (error) {
      throw AppException(
        code: ErrorCode.decode,
        stage: ErrorStage.content,
        briefMessage: 'EPUB 解压失败：$error',
      );
    }

    final chapterCandidates = archive.files
        .where((entry) {
          if (!entry.isFile) {
            return false;
          }
          final lowerName = entry.name.toLowerCase();
          if (lowerName.contains('meta-inf/')) {
            return false;
          }
          return _supportedExtensions.any(lowerName.endsWith);
        })
        .toList(growable: false)
      ..sort((left, right) => left.name.compareTo(right.name));

    final chapters = <LocalParsedChapter>[];
    var offset = 0;
    var index = 0;

    for (final entry in chapterCandidates) {
      final html = _readArchiveEntryAsText(entry);
      if (html.trim().isEmpty) {
        continue;
      }

      final document = html_parser.parse(html);
      final plainText =
          document.body?.text ?? document.documentElement?.text ?? '';
      final normalized = _normalizeText(plainText);
      if (normalized.length < 20) {
        continue;
      }

      final title = _resolveTitle(document.outerHtml, entry.name, index + 1);
      final start = offset;
      offset += normalized.length;

      chapters.add(
        LocalParsedChapter(
          title: title,
          content: normalized,
          startOffset: start,
          endOffset: offset,
        ),
      );
      offset += 1;
      index += 1;
    }

    if (chapters.isEmpty) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: 'EPUB 未解析出正文章节，可能是受保护或结构异常文件。',
      );
    }

    return LocalParsedBook(chapters: chapters);
  }

  String _readArchiveEntryAsText(ArchiveFile entry) {
    final content = entry.content;
    if (content is String) {
      return content;
    }

    List<int>? bytes;
    if (content is List<int>) {
      bytes = content;
    } else {
      try {
        final dynamicContent = entry.content;
        if (dynamicContent is List<int>) {
          bytes = dynamicContent;
        }
      } catch (_) {
        bytes = null;
      }
    }

    if (bytes == null) {
      return '';
    }

    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  String _resolveTitle(String html, String entryName, int index) {
    final document = html_parser.parse(html);
    final titleCandidate =
        document.querySelector('h1')?.text ??
        document.querySelector('h2')?.text ??
        document.querySelector('h3')?.text ??
        document.querySelector('title')?.text;

    final normalized = _normalizeInlineText(titleCandidate ?? '');
    if (normalized.isNotEmpty) {
      return normalized;
    }

    final fileName = entryName.split('/').last;
    final dot = fileName.lastIndexOf('.');
    final fallback = dot > 0 ? fileName.substring(0, dot) : fileName;
    final fallbackNormalized = _normalizeInlineText(fallback);
    if (fallbackNormalized.isNotEmpty) {
      return fallbackNormalized;
    }

    return '第 $index 章';
  }

  String _normalizeText(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t\u00A0]+'), ' ')
        .trim();
  }

  String _normalizeInlineText(String text) {
    return text
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }
}
