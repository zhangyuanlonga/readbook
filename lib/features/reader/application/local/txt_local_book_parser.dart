import 'dart:convert';
import 'dart:io';

import 'package:charset/charset.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_codes.dart';
import '../../../../core/errors/error_stage.dart';
import '../../../../domain/entities/local_book.dart';
import 'local_book_parser.dart';

class TxtLocalBookParser implements LocalBookParser {
  const TxtLocalBookParser();

  static final RegExp _chapterTitlePattern = RegExp(
    r'^\s*(第[0-9零一二三四五六七八九十百千万两〇]+[章节卷部篇回](?:\s|[:：\-_.、\)\]）】》>]|$).*)$',
    caseSensitive: false,
  );

  @override
  bool supports(LocalBookFormat format) {
    return format == LocalBookFormat.txt;
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
        briefMessage: '文本文件为空，无法建立章节索引。',
      );
    }

    final decoded = _decodeText(bytes);
    final normalized = _normalizeText(decoded);
    if (normalized.isEmpty) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: '文本内容为空，无法建立章节索引。',
      );
    }

    final chapters = _splitChapters(normalized);
    if (chapters.isEmpty) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: '未解析出有效章节，请检查文本编码或内容格式。',
      );
    }

    return LocalParsedBook(chapters: chapters);
  }

  String _decodeText(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      final gbk = Charset.getByName('gbk');
      if (gbk != null) {
        try {
          return gbk.decode(bytes);
        } on FormatException {
          return utf8.decode(bytes, allowMalformed: true);
        }
      }
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  String _normalizeText(String raw) {
    return raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\u0000', '')
        .trim();
  }

  List<LocalParsedChapter> _splitChapters(String text) {
    final lines = text.split('\n');
    final chapterTitles = <String>[];
    final chapterBuffers = <StringBuffer>[];

    String currentTitle = '开始阅读';
    var currentBuffer = StringBuffer();

    void flushChapter() {
      final content = currentBuffer.toString().trim();
      if (content.isEmpty) {
        return;
      }
      chapterTitles.add(currentTitle);
      chapterBuffers.add(StringBuffer(content));
      currentBuffer = StringBuffer();
    }

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      final normalizedLine = line.trim();
      final isTitle = _chapterTitlePattern.hasMatch(normalizedLine);

      if (isTitle) {
        flushChapter();
        currentTitle = normalizedLine;
        continue;
      }

      if (currentBuffer.isNotEmpty) {
        currentBuffer.writeln();
      }
      currentBuffer.write(line);
    }

    flushChapter();

    if (chapterTitles.length <= 1) {
      return _splitByFixedLength(text);
    }

    return _buildChapters(chapterTitles, chapterBuffers);
  }

  List<LocalParsedChapter> _splitByFixedLength(String text) {
    const chunkLength = 4000;
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return const <LocalParsedChapter>[];
    }

    final chapters = <LocalParsedChapter>[];
    var start = 0;
    var index = 0;
    while (start < normalized.length) {
      var end = start + chunkLength;
      if (end >= normalized.length) {
        end = normalized.length;
      } else {
        final nextBreak = normalized.lastIndexOf('\n', end);
        if (nextBreak > start + 800) {
          end = nextBreak;
        }
      }

      final content = normalized.substring(start, end).trim();
      if (content.isNotEmpty) {
        index += 1;
        chapters.add(
          LocalParsedChapter(
            title: '第 $index 段',
            content: content,
            startOffset: start,
            endOffset: end,
          ),
        );
      }

      start = end;
      while (start < normalized.length && normalized[start] == '\n') {
        start += 1;
      }
    }

    return chapters;
  }

  List<LocalParsedChapter> _buildChapters(
    List<String> titles,
    List<StringBuffer> buffers,
  ) {
    final chapters = <LocalParsedChapter>[];
    var offset = 0;
    for (var i = 0; i < titles.length; i += 1) {
      final content = buffers[i].toString().trim();
      if (content.isEmpty) {
        continue;
      }
      final start = offset;
      offset += content.length;
      chapters.add(
        LocalParsedChapter(
          title: titles[i],
          content: content,
          startOffset: start,
          endOffset: offset,
        ),
      );
      offset += 1;
    }

    return chapters;
  }
}
