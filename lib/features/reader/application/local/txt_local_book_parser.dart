import 'dart:convert';
import 'dart:io';

import 'package:charset/charset.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_codes.dart';
import '../../../../core/errors/error_stage.dart';
import '../../../../domain/entities/local_book.dart';
import 'local_book_parser.dart';
import 'txt_toc_rule_settings_service.dart';

class TxtLocalBookParser implements LocalBookParser {
  TxtLocalBookParser({TxtTocRuleSettingsService? ruleSettingsService})
    : _ruleSettingsService = ruleSettingsService ?? TxtTocRuleSettingsService();

  static const int _chunkLengthWithoutToc = 4000;
  static const int _tocDetectionSampleLength = 200000;
  static const int _tocDetectionGapThreshold = 1000;
  static const int _maxLengthWithToc = 102400;

  final TxtTocRuleSettingsService _ruleSettingsService;

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

    final normalizedBytes = utf8.encode(normalized);
    final chapters = _withUtf8ByteOffsets(
      await _splitChapters(book, normalized),
      normalized,
    );
    if (chapters.isEmpty) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: '未解析出有效章节，请检查文本编码或内容格式。',
      );
    }

    if (!_listEquals(bytes, normalizedBytes)) {
      await file.writeAsBytes(normalizedBytes, flush: true);
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
        .trimRight();
  }

  Future<List<LocalParsedChapter>> _splitChapters(
    LocalBook book,
    String text,
  ) async {
    final pattern =
        _resolveConfiguredPattern(book.txtTocRulePattern) ??
        await _detectTocPattern(text);
    if (pattern == null) {
      return _splitByFixedLength(text);
    }
    final chapters = _splitByPattern(text, pattern);
    if (chapters.isEmpty) {
      return _splitByFixedLength(text);
    }
    if (book.splitLongChapter) {
      return _splitLongChapters(chapters);
    }
    return chapters;
  }

  RegExp? _resolveConfiguredPattern(String? configuredPattern) {
    final pattern = configuredPattern?.trim() ?? '';
    if (pattern.isEmpty) {
      return null;
    }
    try {
      return RegExp(pattern, multiLine: true, caseSensitive: false);
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  Future<RegExp?> _detectTocPattern(String text) async {
    final sample =
        text.length > _tocDetectionSampleLength
            ? text.substring(0, _tocDetectionSampleLength)
            : text;
    RegExp? selectedPattern;
    var maxHits = 0;
    var maxRawMatches = 0;
    int? earliestStart;

    final enabledRules = await _ruleSettingsService.loadEnabledRules();
    for (final rule in enabledRules.reversed) {
      final pattern = rule.compiled;
      final matches = pattern.allMatches(sample).toList(growable: false);
      if (matches.isEmpty) {
        continue;
      }
      var hits = 0;
      int? lastAcceptedEnd;
      for (final match in matches) {
        if (lastAcceptedEnd == null ||
            match.start - lastAcceptedEnd > _tocDetectionGapThreshold) {
          hits += 1;
          lastAcceptedEnd = match.end;
        }
      }
      final firstMatchStart = matches.first.start;
      final shouldSelect =
          hits > maxHits ||
          (hits == maxHits && matches.length > maxRawMatches) ||
          (hits == maxHits &&
              matches.length == maxRawMatches &&
              (earliestStart == null || firstMatchStart < earliestStart));
      if (shouldSelect && hits > 0) {
        maxHits = hits;
        maxRawMatches = matches.length;
        earliestStart = firstMatchStart;
        selectedPattern = pattern;
      }
    }

    return selectedPattern;
  }

  List<LocalParsedChapter> _splitByPattern(String text, RegExp pattern) {
    final matches = pattern.allMatches(text).toList(growable: false);
    if (matches.isEmpty) {
      return const <LocalParsedChapter>[];
    }

    final chapters = <LocalParsedChapter>[];
    final preface = text.substring(0, matches.first.start).trim();
    if (preface.isNotEmpty) {
      chapters.add(
        LocalParsedChapter(
          title: '前言',
          content: preface,
          startOffset: 0,
          endOffset: matches.first.start,
        ),
      );
    }

    for (var i = 0; i < matches.length; i += 1) {
      final match = matches[i];
      final chapterEnd =
          i + 1 < matches.length ? matches[i + 1].start : text.length;
      final title = match.group(0)?.trim();
      if (title == null || title.isEmpty) {
        continue;
      }

      final content = text.substring(match.end, chapterEnd).trim();
      if (content.isEmpty) {
        continue;
      }

      chapters.add(
        LocalParsedChapter(
          title: title,
          content: content,
          startOffset: match.end,
          endOffset: chapterEnd,
        ),
      );
    }

    return chapters;
  }

  List<LocalParsedChapter> _splitByFixedLength(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return const <LocalParsedChapter>[];
    }

    final chapters = <LocalParsedChapter>[];
    var start = 0;
    var index = 0;
    while (start < normalized.length) {
      var end = start + _chunkLengthWithoutToc;
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

  List<LocalParsedChapter> _splitLongChapters(
    List<LocalParsedChapter> chapters,
  ) {
    final output = <LocalParsedChapter>[];

    for (final chapter in chapters) {
      final content = chapter.content.trim();
      if (content.isEmpty || content.length <= _maxLengthWithToc) {
        output.add(chapter);
        continue;
      }

      var start = 0;
      var splitIndex = 0;
      while (start < content.length) {
        var end = start + _maxLengthWithToc;
        if (end >= content.length) {
          end = content.length;
        } else {
          final nextBreak = content.lastIndexOf('\n', end);
          if (nextBreak > start + 800) {
            end = nextBreak;
          }
        }

        final piece = content.substring(start, end).trim();
        if (piece.isNotEmpty) {
          splitIndex += 1;
          final baseStart = chapter.startOffset ?? 0;
          output.add(
            LocalParsedChapter(
              title: '${chapter.title}($splitIndex)',
              content: piece,
              startOffset: baseStart + start,
              endOffset: baseStart + end,
            ),
          );
        }

        start = end;
        while (start < content.length && content[start] == '\n') {
          start += 1;
        }
      }
    }

    return output;
  }

  List<LocalParsedChapter> _withUtf8ByteOffsets(
    List<LocalParsedChapter> chapters,
    String normalizedText,
  ) {
    if (chapters.isEmpty) {
      return const <LocalParsedChapter>[];
    }

    final checkpoints = chapters
      .expand((chapter) => <int?>[chapter.startOffset, chapter.endOffset])
      .whereType<int>()
      .where((index) => index >= 0 && index <= normalizedText.length)
      .toSet()
      .toList(growable: false)..sort();

    final byteOffsets = <int, int>{0: 0};
    var previousIndex = 0;
    var accumulatedBytes = 0;
    for (final index in checkpoints) {
      if (index > previousIndex) {
        accumulatedBytes +=
            utf8.encode(normalizedText.substring(previousIndex, index)).length;
        previousIndex = index;
      }
      byteOffsets[index] = accumulatedBytes;
    }

    return chapters
        .map((chapter) {
          final startOffset = chapter.startOffset;
          final endOffset = chapter.endOffset;
          return LocalParsedChapter(
            title: chapter.title,
            content: chapter.content,
            startOffset:
                startOffset == null ? null : byteOffsets[startOffset] ?? 0,
            endOffset:
                endOffset == null
                    ? null
                    : byteOffsets[endOffset] ?? accumulatedBytes,
          );
        })
        .toList(growable: false);
  }

  bool _listEquals(List<int> left, List<int> right) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }
}
