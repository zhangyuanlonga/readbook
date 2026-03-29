import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:charset/charset.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_codes.dart';
import '../../../../core/errors/error_stage.dart';
import '../../../../domain/entities/local_book.dart';
import 'local_book_parser.dart';
import 'txt_auto_chapter_patterns.dart';
import 'local_text_encoding_detector.dart';

class TxtLocalBookParser implements LocalBookParser {
  const TxtLocalBookParser();

  static const int _streamingIndexThresholdBytes = 1024 * 1024;
  static const int _streamReadChunkBytes = 64 * 1024;
  static const int _chunkLengthWithoutPattern = 10 * 1024;
  static const int _chapterPatternDetectionSampleLength = 200000;
  static const int _chapterPatternDetectionGapThreshold = 1000;
  static const int _maxLengthWithPattern = 102400;
  static const int _splitBreakMinDistance = 800;
  static final List<TxtAutoChapterPattern> _builtInChapterPatterns =
      defaultEnabledTxtAutoChapterPatterns;

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

    final fileLength = await file.length();
    if (_canUseStreamingIndex(book, fileLength)) {
      final parsed = await _parseWithStreamingIndex(file, book, fileLength);
      if (parsed != null) {
        return parsed;
      }
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: '文本文件为空，无法建立章节索引。',
      );
    }

    final decoded = _decodeBookText(book, bytes);
    final text = decoded.text;
    if (text.trim().isEmpty) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: '文本内容为空，无法建立章节索引。',
      );
    }

    final selectedPattern = _detectChapterPattern(text);
    final chapters = _withByteOffsets(
      _splitChapters(
        text: text,
        charsetName: decoded.charsetName,
        selectedPattern: selectedPattern,
        splitLongChapter: book.splitLongChapter,
      ),
      text: text,
      charsetName: decoded.charsetName,
      bomLength: decoded.bomLength,
    );
    if (chapters.isEmpty) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: '未解析出有效章节，请检查文本编码或内容格式。',
      );
    }

    return LocalParsedBook(chapters: chapters, charset: decoded.charsetName);
  }

  bool _canUseStreamingIndex(LocalBook book, int fileLength) {
    return fileLength >= _streamingIndexThresholdBytes &&
        _normalizeCharsetName(book.charset) == 'utf-8';
  }

  Future<LocalParsedBook?> _parseWithStreamingIndex(
    File file,
    LocalBook book,
    int fileLength,
  ) async {
    final sampleLength =
        fileLength < _chapterPatternDetectionSampleLength
            ? fileLength
            : _chapterPatternDetectionSampleLength;
    final sampleBytes = await file
        .openRead(0, sampleLength)
        .fold<BytesBuilder>(
          BytesBuilder(copy: false),
          (builder, chunk) => builder..add(chunk),
        );
    final rawSample = sampleBytes.takeBytes();
    if (rawSample.isEmpty) {
      return null;
    }

    final bomInfo = _detectBom(rawSample);
    if (bomInfo.charsetName != null && bomInfo.charsetName != 'utf-8') {
      return null;
    }
    final sampleText = utf8.decode(
      rawSample.sublist(bomInfo.length),
      allowMalformed: true,
    );
    if (sampleText.trim().isEmpty) {
      return null;
    }

    final selectedPattern = _detectChapterPattern(sampleText);
    final chapters =
        selectedPattern == null
            ? await _splitByFixedLengthStreaming(
              file,
              fileLength: fileLength,
              bomLength: bomInfo.length,
            )
            : await _splitByPatternStreaming(
              file,
              fileLength: fileLength,
              bomLength: bomInfo.length,
              pattern: selectedPattern.compiled,
              splitLongChapter: book.splitLongChapter,
            );
    if (chapters.isEmpty) {
      return null;
    }
    return LocalParsedBook(chapters: chapters, charset: 'utf-8');
  }

  Future<List<LocalParsedChapter>> _splitByFixedLengthStreaming(
    File file, {
    required int fileLength,
    required int bomLength,
  }) async {
    if (fileLength <= bomLength) {
      return const <LocalParsedChapter>[];
    }

    final chapters = <LocalParsedChapter>[];
    var start = bomLength;
    var index = 0;
    while (start < fileLength) {
      final end = await _findChunkEndByMaxBytesInFile(
        file,
        start,
        min(start + _chunkLengthWithoutPattern, fileLength),
      );
      final safeEnd = end <= start ? fileLength : end;
      if (safeEnd <= start) {
        break;
      }
      index += 1;
      chapters.add(
        LocalParsedChapter(
          title: '第 $index 段',
          content: '',
          startOffset: start,
          endOffset: safeEnd,
        ),
      );
      start = await _skipLeadingWhitespaceBytes(file, safeEnd, fileLength);
    }
    return chapters;
  }

  Future<List<LocalParsedChapter>> _splitByPatternStreaming(
    File file, {
    required int fileLength,
    required int bomLength,
    required RegExp pattern,
    required bool splitLongChapter,
  }) async {
    final chapters = <LocalParsedChapter>[];
    final handle = await file.open(mode: FileMode.read);
    try {
      await handle.setPosition(bomLength);
      var bufferStartOffset = bomLength;
      var carry = <int>[];
      String? currentTitle;
      int? currentContentStart;
      var currentHasContent = false;
      int? prefaceStart;
      var prefaceHasContent = false;

      void pushChapter(String title, int startOffset, int endOffset) {
        if (endOffset <= startOffset) {
          return;
        }
        chapters.add(
          LocalParsedChapter(
            title: title,
            content: '',
            startOffset: startOffset,
            endOffset: endOffset,
          ),
        );
      }

      void finalizeCurrent(int endOffset) {
        if (currentTitle == null ||
            !currentHasContent ||
            currentContentStart == null) {
          currentTitle = null;
          currentContentStart = null;
          currentHasContent = false;
          return;
        }
        pushChapter(currentTitle!, currentContentStart!, endOffset);
        currentTitle = null;
        currentContentStart = null;
        currentHasContent = false;
      }

      void processLine(String lineText, int lineStart, int lineEnd) {
        final trimmed = lineText.trim();
        if (_matchesChapterTitleLine(pattern, lineText)) {
          if (currentTitle == null) {
            if (prefaceHasContent && prefaceStart != null) {
              pushChapter('前言', prefaceStart!, lineStart);
            }
          } else {
            finalizeCurrent(lineStart);
          }
          currentTitle = trimmed;
          currentContentStart = null;
          currentHasContent = false;
          prefaceStart = null;
          prefaceHasContent = false;
          return;
        }
        if (trimmed.isEmpty) {
          return;
        }
        if (currentTitle == null) {
          prefaceStart ??= lineStart;
          prefaceHasContent = true;
          return;
        }
        currentContentStart ??= lineStart;
        currentHasContent = true;
      }

      while (true) {
        final chunk = await handle.read(_streamReadChunkBytes);
        if (chunk.isEmpty) {
          break;
        }
        final buffer = <int>[...carry, ...chunk];
        var lineStartIndex = 0;
        for (var index = 0; index < buffer.length; index += 1) {
          final byte = buffer[index];
          if (byte != 0x0A && byte != 0x0D) {
            continue;
          }
          if (byte == 0x0D && index + 1 == buffer.length) {
            break;
          }
          var separatorLength = 1;
          if (byte == 0x0D &&
              index + 1 < buffer.length &&
              buffer[index + 1] == 0x0A) {
            separatorLength = 2;
          }
          final lineBytes = buffer.sublist(lineStartIndex, index);
          final lineStart = bufferStartOffset + lineStartIndex;
          final lineEnd = bufferStartOffset + index + separatorLength;
          processLine(
            utf8.decode(lineBytes, allowMalformed: true),
            lineStart,
            lineEnd,
          );
          lineStartIndex = index + separatorLength;
          if (separatorLength == 2) {
            index += 1;
          }
        }
        carry = buffer.sublist(lineStartIndex);
        bufferStartOffset += buffer.length - carry.length;
      }

      if (carry.isNotEmpty) {
        processLine(
          utf8.decode(carry, allowMalformed: true),
          bufferStartOffset,
          fileLength,
        );
      }

      if (currentTitle == null) {
        if (prefaceHasContent && prefaceStart != null) {
          pushChapter('前言', prefaceStart!, fileLength);
        }
      } else {
        finalizeCurrent(fileLength);
      }
    } finally {
      await handle.close();
    }

    if (chapters.isEmpty || !splitLongChapter) {
      return chapters;
    }
    return _splitLongChaptersByOffsets(file, chapters);
  }

  bool _matchesChapterTitleLine(RegExp pattern, String lineText) {
    if (lineText.trim().isEmpty) {
      return false;
    }
    return pattern.hasMatch(lineText) || pattern.hasMatch('\n$lineText');
  }

  Future<List<LocalParsedChapter>> _splitLongChaptersByOffsets(
    File file,
    List<LocalParsedChapter> chapters,
  ) async {
    final output = <LocalParsedChapter>[];
    for (final chapter in chapters) {
      final start = chapter.startOffset;
      final end = chapter.endOffset;
      if (start == null || end == null || end <= start) {
        continue;
      }
      final length = end - start;
      if (length <= _maxLengthWithPattern) {
        output.add(chapter);
        continue;
      }

      var pieceStart = start;
      var splitIndex = 0;
      while (pieceStart < end) {
        final pieceEnd = await _findChunkEndByMaxBytesInFile(
          file,
          pieceStart,
          min(pieceStart + _maxLengthWithPattern, end),
        );
        final safePieceEnd = pieceEnd <= pieceStart ? end : pieceEnd;
        if (safePieceEnd <= pieceStart) {
          break;
        }
        splitIndex += 1;
        output.add(
          LocalParsedChapter(
            title: '${chapter.title}($splitIndex)',
            content: '',
            startOffset: pieceStart,
            endOffset: safePieceEnd,
          ),
        );
        pieceStart = await _skipLeadingWhitespaceBytes(file, safePieceEnd, end);
      }
    }
    return output;
  }

  Future<int> _findChunkEndByMaxBytesInFile(
    File file,
    int start,
    int proposedEnd,
  ) async {
    if (proposedEnd <= start) {
      return start;
    }
    final bytes = await file
        .openRead(start, proposedEnd)
        .fold<BytesBuilder>(
          BytesBuilder(copy: false),
          (builder, chunk) => builder..add(chunk),
        );
    final buffer = bytes.takeBytes();
    if (buffer.isEmpty) {
      return proposedEnd;
    }
    for (
      var index = buffer.length - 1;
      index >= _splitBreakMinDistance;
      index -= 1
    ) {
      final byte = buffer[index];
      if (byte == 0x0A || byte == 0x0D) {
        return start + index;
      }
    }
    return proposedEnd;
  }

  Future<int> _skipLeadingWhitespaceBytes(File file, int start, int end) async {
    if (start >= end) {
      return end;
    }
    final bytes = await file
        .openRead(start, end)
        .fold<BytesBuilder>(
          BytesBuilder(copy: false),
          (builder, chunk) => builder..add(chunk),
        );
    final buffer = bytes.takeBytes();
    var index = 0;
    while (index < buffer.length) {
      final byte = buffer[index];
      if (byte == 0x0A || byte == 0x0D || byte == 0x09 || byte == 0x20) {
        index += 1;
        continue;
      }
      break;
    }
    return start + index;
  }

  _ResolvedTxtChapterPattern? _detectChapterPattern(String text) {
    final sample =
        text.length > _chapterPatternDetectionSampleLength
            ? text.substring(0, _chapterPatternDetectionSampleLength)
            : text;
    _ResolvedTxtChapterPattern? selectedPattern;
    var maxHits = 0;
    var maxRawMatches = 0;
    int? earliestStart;

    for (final chapterPattern in _builtInChapterPatterns.reversed) {
      final pattern = chapterPattern.compiled;
      final matches = pattern.allMatches(sample).toList(growable: false);
      if (matches.isEmpty) {
        continue;
      }

      var hits = 0;
      int? lastAcceptedEnd;
      for (final match in matches) {
        if (lastAcceptedEnd == null ||
            match.start - lastAcceptedEnd >
                _chapterPatternDetectionGapThreshold) {
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
      if (!shouldSelect || hits <= 0) {
        continue;
      }

      maxHits = hits;
      maxRawMatches = matches.length;
      earliestStart = firstMatchStart;
      selectedPattern = _ResolvedTxtChapterPattern(compiled: pattern);
    }

    return selectedPattern;
  }

  List<LocalParsedChapter> _splitChapters({
    required String text,
    required String charsetName,
    required _ResolvedTxtChapterPattern? selectedPattern,
    required bool splitLongChapter,
  }) {
    final chapters =
        selectedPattern == null
            ? _splitByFixedLength(text, charsetName: charsetName)
            : _splitByPattern(text, selectedPattern.compiled);

    if (chapters.isEmpty) {
      return _splitByFixedLength(text, charsetName: charsetName);
    }
    if (!splitLongChapter || selectedPattern == null) {
      return chapters;
    }
    return _splitLongChapters(chapters, charsetName: charsetName);
  }

  List<LocalParsedChapter> _splitByPattern(String text, RegExp pattern) {
    final matches = pattern.allMatches(text).toList(growable: false);
    if (matches.isEmpty) {
      return const <LocalParsedChapter>[];
    }

    final chapters = <LocalParsedChapter>[];
    final prefaceEnd = matches.first.start;
    final prefaceStart = _firstContentIndex(text, 0, prefaceEnd);
    if (prefaceStart >= 0 && prefaceStart < prefaceEnd) {
      final preface = text.substring(prefaceStart, prefaceEnd).trim();
      if (preface.isNotEmpty) {
        chapters.add(
          LocalParsedChapter(
            title: '前言',
            content: preface,
            startOffset: prefaceStart,
            endOffset: prefaceEnd,
          ),
        );
      }
    }

    for (var index = 0; index < matches.length; index += 1) {
      final match = matches[index];
      final chapterEnd =
          index + 1 < matches.length ? matches[index + 1].start : text.length;
      final title = match.group(0)?.trim() ?? '';
      if (title.isEmpty) {
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

  List<LocalParsedChapter> _splitByFixedLength(
    String text, {
    required String charsetName,
  }) {
    if (text.trim().isEmpty) {
      return const <LocalParsedChapter>[];
    }

    final chapters = <LocalParsedChapter>[];
    var start = _skipLeadingLineBreaks(text, 0);
    var index = 0;
    while (start < text.length) {
      var end = _findChunkEndByMaxBytes(
        text,
        start,
        _chunkLengthWithoutPattern,
        charsetName,
      );
      if (end <= start) {
        end = text.length;
      }

      final content = text.substring(start, end).trim();
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

      start = _skipLeadingLineBreaks(text, end);
    }

    return chapters;
  }

  List<LocalParsedChapter> _splitLongChapters(
    List<LocalParsedChapter> chapters, {
    required String charsetName,
  }) {
    final output = <LocalParsedChapter>[];

    for (final chapter in chapters) {
      final content = chapter.content.trim();
      if (content.isEmpty) {
        continue;
      }
      final contentBytes = _encodedLength(content, charsetName);
      if (contentBytes <= _maxLengthWithPattern) {
        output.add(chapter);
        continue;
      }

      var relativeStart = 0;
      var splitIndex = 0;
      while (relativeStart < content.length) {
        var relativeEnd = _findChunkEndByMaxBytes(
          content,
          relativeStart,
          _maxLengthWithPattern,
          charsetName,
        );
        if (relativeEnd <= relativeStart) {
          relativeEnd = content.length;
        }

        final piece = content.substring(relativeStart, relativeEnd).trim();
        if (piece.isNotEmpty) {
          splitIndex += 1;
          final baseStart = chapter.startOffset ?? 0;
          output.add(
            LocalParsedChapter(
              title: '${chapter.title}($splitIndex)',
              content: piece,
              startOffset: baseStart + relativeStart,
              endOffset: baseStart + relativeEnd,
            ),
          );
        }

        relativeStart = _skipLeadingLineBreaks(content, relativeEnd);
      }
    }

    return output;
  }

  List<LocalParsedChapter> _withByteOffsets(
    List<LocalParsedChapter> chapters, {
    required String text,
    required String charsetName,
    required int bomLength,
  }) {
    if (chapters.isEmpty) {
      return const <LocalParsedChapter>[];
    }

    final checkpoints = chapters
      .expand((chapter) => <int?>[chapter.startOffset, chapter.endOffset])
      .whereType<int>()
      .where((index) => index >= 0 && index <= text.length)
      .toSet()
      .toList(growable: false)..sort();

    final byteOffsets = <int, int>{0: bomLength};
    var previousIndex = 0;
    var accumulatedBytes = bomLength;
    for (final index in checkpoints) {
      if (index > previousIndex) {
        accumulatedBytes += _encodedLength(
          text.substring(previousIndex, index),
          charsetName,
        );
        previousIndex = index;
      }
      byteOffsets[index] = accumulatedBytes;
    }

    return chapters
        .map(
          (chapter) => LocalParsedChapter(
            title: chapter.title,
            content: chapter.content,
            startOffset:
                chapter.startOffset == null
                    ? null
                    : byteOffsets[chapter.startOffset] ?? bomLength,
            endOffset:
                chapter.endOffset == null
                    ? null
                    : byteOffsets[chapter.endOffset] ?? accumulatedBytes,
          ),
        )
        .toList(growable: false);
  }

  _DecodedBookText _decodeBookText(LocalBook book, List<int> bytes) {
    final bomInfo = _detectBom(bytes);
    final bomLength = bomInfo.length;
    final contentBytes =
        bomLength > 0 ? bytes.sublist(bomLength) : List<int>.from(bytes);

    final preferredCharset = _normalizeCharsetName(book.charset);
    final hintedCharset =
        preferredCharset ??
        bomInfo.charsetName ??
        _detectUtf16ZeroPattern(bytes);

    final candidateCharsets = <String>[
      if (hintedCharset != null) hintedCharset,
      'utf-8',
      'utf-16be',
      'utf-16le',
      'gbk',
      'gb18030',
      'big5',
      'shift_jis',
      'euc-jp',
      'euc-kr',
      'windows-1252',
      'latin1',
    ];

    _DecodedBookText? best;
    var bestScore = -0x7fffffff;
    final seen = <String>{};
    for (final rawCandidate in candidateCharsets) {
      final candidate = _normalizeCharsetName(rawCandidate);
      if (candidate == null || !seen.add(candidate)) {
        continue;
      }
      final text = _tryDecodeByCharset(contentBytes, candidate);
      if (text == null) {
        continue;
      }

      final score = _scoreDecodedText(
        text,
        enabledRules: _builtInChapterPatterns,
        charsetName: candidate,
        hintedCharset: hintedCharset,
      );
      if (best == null || score > bestScore) {
        best = _DecodedBookText(
          text: text,
          charsetName: candidate,
          bomLength: bomLength,
        );
        bestScore = score;
      }
    }

    if (best != null) {
      return best;
    }

    return _DecodedBookText(
      text: utf8.decode(contentBytes, allowMalformed: true),
      charsetName: 'utf-8',
      bomLength: bomLength,
    );
  }

  _BomInfo _detectBom(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return const _BomInfo(length: 3, charsetName: 'utf-8');
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return const _BomInfo(length: 2, charsetName: 'utf-16be');
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return const _BomInfo(length: 2, charsetName: 'utf-16le');
    }
    return const _BomInfo(length: 0, charsetName: null);
  }

  String? _detectUtf16ZeroPattern(List<int> bytes) {
    final sampleLength = bytes.length < 2048 ? bytes.length : 2048;
    if (sampleLength < 8) {
      return null;
    }

    var evenZeroCount = 0;
    var oddZeroCount = 0;
    var pairCount = 0;
    for (var index = 0; index + 1 < sampleLength; index += 2) {
      pairCount += 1;
      if (bytes[index] == 0) {
        evenZeroCount += 1;
      }
      if (bytes[index + 1] == 0) {
        oddZeroCount += 1;
      }
    }
    if (pairCount == 0) {
      return null;
    }

    final evenZeroRatio = evenZeroCount / pairCount;
    final oddZeroRatio = oddZeroCount / pairCount;
    if (evenZeroRatio >= 0.2 && oddZeroRatio <= 0.05) {
      return 'utf-16be';
    }
    if (oddZeroRatio >= 0.2 && evenZeroRatio <= 0.05) {
      return 'utf-16le';
    }
    return null;
  }

  int _scoreDecodedText(
    String text, {
    required List<TxtAutoChapterPattern> enabledRules,
    required String charsetName,
    required String? hintedCharset,
  }) {
    final sample =
        text.length > _chapterPatternDetectionSampleLength
            ? text.substring(0, _chapterPatternDetectionSampleLength)
            : text;
    if (sample.trim().isEmpty) {
      return -0x3fffffff;
    }

    var replacementCount = 0;
    var nulCount = 0;
    var controlCount = 0;
    var hanCount = 0;
    var asciiCount = 0;
    var suspiciousMojibakeCount = 0;
    for (final rune in sample.runes) {
      if (rune == 0xFFFD) {
        replacementCount += 1;
      }
      if (rune == 0) {
        nulCount += 1;
      }
      if (rune < 0x20 && rune != 0x09 && rune != 0x0A && rune != 0x0D) {
        controlCount += 1;
      }
      if (rune >= 0x4E00 && rune <= 0x9FFF) {
        hanCount += 1;
      }
      if (rune >= 0x20 && rune <= 0x7E) {
        asciiCount += 1;
      }
      if (rune == 0x00C3 ||
          rune == 0x00C2 ||
          rune == 0x00E2 ||
          rune == 0x00D0 ||
          rune == 0x00D1 ||
          rune == 0x00FE ||
          rune == 0x00FF) {
        suspiciousMojibakeCount += 1;
      }
    }

    var bestPatternHits = 0;
    var bestRawMatches = 0;
    for (final chapterPattern in enabledRules) {
      final matches = chapterPattern.compiled
          .allMatches(sample)
          .toList(growable: false);
      if (matches.isEmpty) {
        continue;
      }

      var hits = 0;
      int? lastAcceptedEnd;
      for (final match in matches) {
        if (lastAcceptedEnd == null ||
            match.start - lastAcceptedEnd >
                _chapterPatternDetectionGapThreshold) {
          hits += 1;
          lastAcceptedEnd = match.end;
        }
      }
      if (hits > bestPatternHits ||
          (hits == bestPatternHits && matches.length > bestRawMatches)) {
        bestPatternHits = hits;
        bestRawMatches = matches.length;
      }
    }

    var score = 0;
    score += bestPatternHits * 200;
    score += bestRawMatches * 12;
    score += hanCount * 2;
    if (hanCount > asciiCount) {
      score += 80;
    }
    score -= replacementCount * 120;
    score -= nulCount * 240;
    score -= controlCount * 80;
    score -= suspiciousMojibakeCount * 55;
    score -= _countSuspiciousMojibakeTokens(sample) * 180;
    if (hintedCharset != null && hintedCharset == charsetName) {
      score += 160;
    }
    return score;
  }

  int _countSuspiciousMojibakeTokens(String text) {
    var count = 0;
    for (final pattern in const <String>['锟斤拷', '鈥', 'Ã', 'Â', 'â€', 'ï¿½']) {
      count += RegExp(RegExp.escape(pattern)).allMatches(text).length;
    }
    return count;
  }

  int _findChunkEndByMaxBytes(
    String text,
    int start,
    int maxBytes,
    String charsetName,
  ) {
    if (start >= text.length) {
      return text.length;
    }

    var low = start + 1;
    var high = text.length;
    var best = text.length;
    while (low <= high) {
      final mid = low + ((high - low) >> 1);
      final byteLength = _encodedLength(
        text.substring(start, mid),
        charsetName,
      );
      if (byteLength <= maxBytes) {
        best = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    if (best >= text.length) {
      return text.length;
    }

    final nextBreak = text.lastIndexOf('\n', best);
    if (nextBreak > start + _splitBreakMinDistance) {
      return nextBreak;
    }
    return best;
  }

  int _skipLeadingLineBreaks(String text, int index) {
    var next = index;
    while (next < text.length) {
      final char = text[next];
      if (char == '\n' || char == '\r') {
        next += 1;
        continue;
      }
      if (char.trim().isEmpty) {
        next += 1;
        continue;
      }
      break;
    }
    return next;
  }

  int _firstContentIndex(String text, int start, int end) {
    for (var index = start; index < end; index += 1) {
      if (text[index].trim().isNotEmpty) {
        return index;
      }
    }
    return -1;
  }

  String? _normalizeCharsetName(String? value) {
    return LocalTextEncodingDetector.normalizeCharsetName(value);
  }

  String? _tryDecodeByCharset(List<int> bytes, String charsetName) {
    return LocalTextEncodingDetector.tryDecodeByCharset(bytes, charsetName);
  }

  int _encodedLength(String text, String charsetName) {
    switch (charsetName) {
      case 'utf-8':
        return utf8.encode(text).length;
      case 'utf-16':
      case 'utf-16be':
      case 'utf-16le':
        return text.codeUnits.length * 2;
      case 'latin1':
        return latin1.encode(text).length;
      default:
        final encoding = Charset.getByName(charsetName);
        if (encoding == null) {
          return utf8.encode(text).length;
        }
        return encoding.encode(text).length;
    }
  }
}

class _DecodedBookText {
  const _DecodedBookText({
    required this.text,
    required this.charsetName,
    required this.bomLength,
  });

  final String text;
  final String charsetName;
  final int bomLength;
}

class _BomInfo {
  const _BomInfo({required this.length, required this.charsetName});

  final int length;
  final String? charsetName;
}

class _ResolvedTxtChapterPattern {
  const _ResolvedTxtChapterPattern({required this.compiled});

  final RegExp compiled;
}
