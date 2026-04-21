import 'dart:async';
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
import 'txt_chapter_rule_service.dart';
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
  static const int _backgroundYieldByteBudget = 512 * 1024;
  static const int _backgroundYieldStepBudget = 8;
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

    final enabledRules = await TxtChapterRuleService().loadEnabledPatterns();
    final fileLength = await file.length();
    final yieldGate = _CooperativeYieldGate(
      byteBudget: _backgroundYieldByteBudget,
      stepBudget: _backgroundYieldStepBudget,
    );
    if (_canUseStreamingIndex(book, fileLength)) {
      final parsed = await _parseWithStreamingIndex(
        file,
        book,
        fileLength,
        enabledRules: enabledRules,
        yieldGate: yieldGate,
      );
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

    final decoded = await _decodeBookText(
      book,
      bytes,
      enabledRules: enabledRules,
    );
    final text = decoded.text;
    if (text.trim().isEmpty) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: '文本内容为空，无法建立章节索引。',
      );
    }

    final selectedPattern = _detectChapterPattern(
      text,
      enabledRules: enabledRules,
    );
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
    return fileLength >= _streamingIndexThresholdBytes;
  }

  Future<LocalParsedBook?> _parseWithStreamingIndex(
    File file,
    LocalBook book,
    int fileLength, {
    required List<TxtAutoChapterPattern> enabledRules,
    required _CooperativeYieldGate yieldGate,
  }) async {
    final sampleLength =
        fileLength < _chapterPatternDetectionSampleLength
            ? fileLength
            : _chapterPatternDetectionSampleLength;
    final sampleChunks = await _readStreamingSampleChunks(
      file,
      fileLength: fileLength,
      sampleLength: sampleLength,
      yieldGate: yieldGate,
    );
    if (sampleChunks.isEmpty) {
      return null;
    }

    final sampleDecoded = await _decodeStreamingSampleChunks(
      book: book,
      chunks: sampleChunks,
      fileLength: fileLength,
      enabledRules: enabledRules,
      yieldGate: yieldGate,
    );
    if (sampleDecoded == null || sampleDecoded.text.trim().isEmpty) {
      return null;
    }

    final charsetName = sampleDecoded.charsetName;
    final bomInfo = _detectBom(sampleChunks.first.bytes);
    final selectedPattern = _detectChapterPattern(
      sampleDecoded.text,
      enabledRules: enabledRules,
    );
    final chapters =
        selectedPattern == null
            ? await _splitByFixedLengthStreaming(
              file,
              fileLength: fileLength,
              bomLength: bomInfo.length,
              charsetName: charsetName,
              yieldGate: yieldGate,
            )
            : await _splitByPatternStreaming(
              file,
              fileLength: fileLength,
              bomLength: bomInfo.length,
              charsetName: charsetName,
              pattern: selectedPattern.compiled,
              splitLongChapter: book.splitLongChapter,
              yieldGate: yieldGate,
            );
    if (chapters.isEmpty) {
      return null;
    }
    final hydratedChapters = await _hydrateChapterContentsFromOffsets(
      file,
      chapters,
      charsetName: charsetName,
      yieldGate: yieldGate,
    );
    return LocalParsedBook(chapters: hydratedChapters, charset: charsetName);
  }

  Future<List<_StreamingSampleChunk>> _readStreamingSampleChunks(
    File file, {
    required int fileLength,
    required int sampleLength,
    required _CooperativeYieldGate yieldGate,
  }) async {
    if (fileLength <= 0 || sampleLength <= 0) {
      return const <_StreamingSampleChunk>[];
    }
    final ranges = <(int, int)>[(0, sampleLength)];
    if (fileLength > sampleLength * 2) {
      final middleStart = ((fileLength - sampleLength) ~/ 2).clamp(
        0,
        fileLength - sampleLength,
      );
      ranges.add((middleStart, sampleLength));
    }
    if (fileLength > sampleLength * 3) {
      final tailStart = (fileLength - sampleLength).clamp(
        0,
        fileLength - sampleLength,
      );
      ranges.add((tailStart, sampleLength));
    }

    final uniqueRanges = <String, (int, int)>{};
    for (final range in ranges) {
      uniqueRanges['${range.$1}:${range.$2}'] = range;
    }

    final chunks = <_StreamingSampleChunk>[];
    for (final range in uniqueRanges.values) {
      final builder = BytesBuilder(copy: false);
      await file.openRead(range.$1, range.$1 + range.$2).forEach(builder.add);
      final bytes = builder.takeBytes();
      if (bytes.isEmpty) {
        continue;
      }
      chunks.add(_StreamingSampleChunk(start: range.$1, bytes: bytes));
      await yieldGate.maybeYield(processedBytes: bytes.length);
    }
    return chunks;
  }

  Future<_DecodedBookText?> _decodeStreamingSampleChunks({
    required LocalBook book,
    required List<_StreamingSampleChunk> chunks,
    required int fileLength,
    required List<TxtAutoChapterPattern> enabledRules,
    required _CooperativeYieldGate yieldGate,
  }) async {
    final results = <_ScoredDecodedChunk>[];
    final preferredCharset = _normalizeCharsetName(book.charset);
    for (final chunk in chunks) {
      final decoded =
          preferredCharset == 'utf-8'
              ? const LocalTextEncodingDetector().decodeSampleBestEffort(
                chunk.bytes,
                preferredCharset: preferredCharset,
                hintedCharset: preferredCharset,
              )
              : await const LocalTextEncodingDetector()
                  .decodeSampleBestEffortAsync(
                    chunk.bytes,
                    preferredCharset: book.charset,
                    hintedCharset: book.charset,
                  );
      if (decoded == null || decoded.text.trim().isEmpty) {
        continue;
      }
      results.add(
        _ScoredDecodedChunk(
          decoded: _DecodedBookText(
            text: decoded.text,
            charsetName: decoded.charsetName,
            bomLength: decoded.bomLength,
          ),
          score: _scoreStreamingSampleChunk(
            chunk: chunk,
            fileLength: fileLength,
            book: book,
            decoded: decoded,
            enabledRules: enabledRules,
          ),
        ),
      );
      await yieldGate.maybeYield(processedBytes: chunk.bytes.length);
    }
    if (results.isEmpty) {
      return null;
    }

    final aggregated = <String, int>{};
    final bestByCharset = <String, _ScoredDecodedChunk>{};
    for (final result in results) {
      final charset = result.decoded.charsetName;
      aggregated[charset] = (aggregated[charset] ?? 0) + result.score;
      final current = bestByCharset[charset];
      if (current == null || result.score > current.score) {
        bestByCharset[charset] = result;
      }
    }

    String? bestCharset;
    var bestScore = -0x7fffffff;
    for (final entry in aggregated.entries) {
      if (entry.value > bestScore) {
        bestCharset = entry.key;
        bestScore = entry.value;
      }
    }
    if (bestCharset == null) {
      return null;
    }
    return bestByCharset[bestCharset]?.decoded;
  }

  int _scoreStreamingSampleChunk({
    required _StreamingSampleChunk chunk,
    required int fileLength,
    required LocalBook book,
    required LocalTextDecodeResult decoded,
    required List<TxtAutoChapterPattern> enabledRules,
  }) {
    var score = _scoreDecodedText(
      decoded.text,
      enabledRules: enabledRules,
      charsetName: decoded.charsetName,
      hintedCharset: _normalizeCharsetName(book.charset),
    );
    final midpoint = chunk.start + (chunk.bytes.length ~/ 2);
    final normalizedPosition =
        fileLength <= 0 ? 0.0 : midpoint / fileLength.toDouble();
    if (normalizedPosition >= 0.25 && normalizedPosition <= 0.75) {
      score += 80;
    } else if (normalizedPosition > 0.75) {
      score += 50;
    } else {
      score += 10;
    }
    if ((decoded.charsetName == 'utf-16' ||
            decoded.charsetName == 'utf-16le' ||
            decoded.charsetName == 'utf-16be') &&
        _zeroByteRatio(chunk.bytes) < 0.12) {
      score -= 240;
    }
    if (decoded.fallbackUsed) {
      score -= 120;
    }
    return score;
  }

  double _zeroByteRatio(List<int> bytes) {
    if (bytes.isEmpty) {
      return 0;
    }
    final zeroCount = bytes.where((byte) => byte == 0).length;
    return zeroCount / bytes.length;
  }

  Future<List<LocalParsedChapter>> _splitByFixedLengthStreaming(
    File file, {
    required int fileLength,
    required int bomLength,
    required String charsetName,
    required _CooperativeYieldGate yieldGate,
  }) async {
    if (fileLength <= bomLength) {
      return const <LocalParsedChapter>[];
    }

    final chapters = <LocalParsedChapter>[];
    var start = _alignStreamOffsetForCharset(
      bomLength,
      charsetName: charsetName,
    );
    var index = 0;
    while (start < fileLength) {
      final end = await _findChunkEndByMaxBytesInFile(
        file,
        start,
        min(start + _chunkLengthWithoutPattern, fileLength),
        charsetName: charsetName,
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
      final processedBytes = safeEnd - start;
      start = await _skipLeadingWhitespaceBytes(
        file,
        safeEnd,
        fileLength,
        charsetName: charsetName,
      );
      start = _alignStreamOffsetForCharset(start, charsetName: charsetName);
      await yieldGate.maybeYield(processedBytes: processedBytes);
    }
    return chapters;
  }

  Future<List<LocalParsedChapter>> _splitByPatternStreaming(
    File file, {
    required int fileLength,
    required int bomLength,
    required String charsetName,
    required RegExp pattern,
    required bool splitLongChapter,
    required _CooperativeYieldGate yieldGate,
  }) async {
    final chapters = <LocalParsedChapter>[];
    final handle = await file.open(mode: FileMode.read);
    try {
      final normalizedStart = _alignStreamOffsetForCharset(
        bomLength,
        charsetName: charsetName,
      );
      await handle.setPosition(normalizedStart);
      var bufferStartOffset = normalizedStart;
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
        final parsedLines = _extractStreamingLines(
          buffer,
          bufferStartOffset: bufferStartOffset,
          charsetName: charsetName,
        );
        for (final line in parsedLines.lines) {
          processLine(line.text, line.startOffset, line.endOffset);
        }
        carry = parsedLines.carryBytes;
        bufferStartOffset = parsedLines.nextBufferOffset;
        await yieldGate.maybeYield(processedBytes: chunk.length);
      }

      if (carry.isNotEmpty) {
        final lineEnd = bufferStartOffset + carry.length;
        processLine(
          _decodeStreamingLine(carry, charsetName: charsetName),
          bufferStartOffset,
          lineEnd,
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
    return _splitLongChaptersByOffsets(
      file,
      chapters,
      charsetName: charsetName,
      yieldGate: yieldGate,
    );
  }

  bool _matchesChapterTitleLine(RegExp pattern, String lineText) {
    if (lineText.trim().isEmpty) {
      return false;
    }
    return pattern.hasMatch(lineText) || pattern.hasMatch('\n$lineText');
  }

  Future<List<LocalParsedChapter>> _splitLongChaptersByOffsets(
    File file,
    List<LocalParsedChapter> chapters, {
    required String charsetName,
    required _CooperativeYieldGate yieldGate,
  }) async {
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
          charsetName: charsetName,
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
        final processedBytes = safePieceEnd - pieceStart;
        pieceStart = await _skipLeadingWhitespaceBytes(
          file,
          safePieceEnd,
          end,
          charsetName: charsetName,
        );
        pieceStart = _alignStreamOffsetForCharset(
          pieceStart,
          charsetName: charsetName,
        );
        await yieldGate.maybeYield(processedBytes: processedBytes);
      }
    }
    return output;
  }

  Future<List<LocalParsedChapter>> _hydrateChapterContentsFromOffsets(
    File file,
    List<LocalParsedChapter> chapters, {
    required String charsetName,
    required _CooperativeYieldGate yieldGate,
  }) async {
    if (chapters.isEmpty) {
      return const <LocalParsedChapter>[];
    }

    final normalizedCharset = _normalizeCharsetName(charsetName) ?? charsetName;
    final hydrated = <LocalParsedChapter>[];
    final handle = await file.open(mode: FileMode.read);
    try {
      for (final chapter in chapters) {
        final startOffset = chapter.startOffset;
        final endOffset = chapter.endOffset;
        if (startOffset == null ||
            endOffset == null ||
            endOffset <= startOffset) {
          hydrated.add(chapter);
          continue;
        }

        await handle.setPosition(startOffset);
        final bytes = await handle.read(endOffset - startOffset);
        final content =
            _decodeStoredBytes(bytes, charsetName: normalizedCharset).trim();
        hydrated.add(
          LocalParsedChapter(
            title: chapter.title,
            content: content,
            startOffset: chapter.startOffset,
            endOffset: chapter.endOffset,
          ),
        );
        await yieldGate.maybeYield(processedBytes: bytes.length);
      }
    } finally {
      await handle.close();
    }
    return hydrated;
  }

  Future<int> _findChunkEndByMaxBytesInFile(
    File file,
    int start,
    int proposedEnd, {
    required String charsetName,
  }) async {
    if (proposedEnd <= start) {
      return start;
    }
    final normalizedStart = _alignStreamOffsetForCharset(
      start,
      charsetName: charsetName,
    );
    final normalizedEnd = _alignStreamOffsetForCharset(
      proposedEnd,
      charsetName: charsetName,
    );
    if (normalizedEnd <= normalizedStart) {
      return normalizedStart;
    }
    final bytes = await file
        .openRead(normalizedStart, normalizedEnd)
        .fold<BytesBuilder>(
          BytesBuilder(copy: false),
          (builder, chunk) => builder..add(chunk),
        );
    final buffer = bytes.takeBytes();
    if (buffer.isEmpty) {
      return normalizedEnd;
    }
    final parsedLines = _extractStreamingLines(
      buffer,
      bufferStartOffset: normalizedStart,
      charsetName: charsetName,
    );
    for (var index = parsedLines.lines.length - 1; index >= 0; index -= 1) {
      final line = parsedLines.lines[index];
      if (line.endOffset - normalizedStart >= _splitBreakMinDistance) {
        return line.endOffset;
      }
    }
    return normalizedEnd;
  }

  Future<int> _skipLeadingWhitespaceBytes(
    File file,
    int start,
    int end, {
    required String charsetName,
  }) async {
    if (start >= end) {
      return end;
    }
    final normalizedStart = _alignStreamOffsetForCharset(
      start,
      charsetName: charsetName,
    );
    final normalizedEnd = _alignStreamOffsetForCharset(
      end,
      charsetName: charsetName,
    );
    final bytes = await file
        .openRead(normalizedStart, normalizedEnd)
        .fold<BytesBuilder>(
          BytesBuilder(copy: false),
          (builder, chunk) => builder..add(chunk),
        );
    final buffer = bytes.takeBytes();
    if (buffer.isEmpty) {
      return normalizedEnd;
    }

    if (_isUtf16Charset(charsetName)) {
      var offset = 0;
      while (offset + 1 < buffer.length) {
        final unit = _readUtf16CodeUnit(
          buffer,
          offset,
          littleEndian: charsetName == 'utf-16le' || charsetName == 'utf-16',
        );
        final char = String.fromCharCode(unit);
        if (char.trim().isEmpty) {
          offset += 2;
          continue;
        }
        break;
      }
      return normalizedStart + offset;
    }

    var offset = 0;
    while (offset < buffer.length) {
      final byte = buffer[offset];
      if (byte == 0x0A || byte == 0x0D || byte == 0x09 || byte == 0x20) {
        offset += 1;
        continue;
      }
      break;
    }
    return normalizedStart + offset;
  }

  int _alignStreamOffsetForCharset(int offset, {required String charsetName}) {
    if (_isUtf16Charset(charsetName) && offset.isOdd) {
      return offset - 1;
    }
    return offset;
  }

  bool _isUtf16Charset(String charsetName) {
    return charsetName == 'utf-16' ||
        charsetName == 'utf-16le' ||
        charsetName == 'utf-16be';
  }

  _StreamingLineExtraction _extractStreamingLines(
    List<int> buffer, {
    required int bufferStartOffset,
    required String charsetName,
  }) {
    if (_isUtf16Charset(charsetName)) {
      return _extractUtf16StreamingLines(
        buffer,
        bufferStartOffset: bufferStartOffset,
        littleEndian: charsetName == 'utf-16le' || charsetName == 'utf-16',
      );
    }
    return _extractByteStreamingLines(
      buffer,
      bufferStartOffset: bufferStartOffset,
      charsetName: charsetName,
    );
  }

  _StreamingLineExtraction _extractByteStreamingLines(
    List<int> buffer, {
    required int bufferStartOffset,
    required String charsetName,
  }) {
    final lines = <_StreamingLine>[];
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
      lines.add(
        _StreamingLine(
          text: _decodeStreamingLine(lineBytes, charsetName: charsetName),
          startOffset: bufferStartOffset + lineStartIndex,
          endOffset: bufferStartOffset + index + separatorLength,
        ),
      );
      lineStartIndex = index + separatorLength;
      if (separatorLength == 2) {
        index += 1;
      }
    }
    final carryBytes = buffer.sublist(lineStartIndex);
    return _StreamingLineExtraction(
      lines: lines,
      carryBytes: carryBytes,
      nextBufferOffset: bufferStartOffset + buffer.length - carryBytes.length,
    );
  }

  _StreamingLineExtraction _extractUtf16StreamingLines(
    List<int> buffer, {
    required int bufferStartOffset,
    required bool littleEndian,
  }) {
    final lines = <_StreamingLine>[];
    var lineStartIndex = 0;
    var index = 0;
    while (index + 1 < buffer.length) {
      final unit = _readUtf16CodeUnit(
        buffer,
        index,
        littleEndian: littleEndian,
      );
      if (unit != 0x0A && unit != 0x0D) {
        index += 2;
        continue;
      }
      if (unit == 0x0D && index + 3 >= buffer.length) {
        break;
      }
      var separatorLength = 2;
      if (unit == 0x0D && index + 3 < buffer.length) {
        final nextUnit = _readUtf16CodeUnit(
          buffer,
          index + 2,
          littleEndian: littleEndian,
        );
        if (nextUnit == 0x0A) {
          separatorLength = 4;
        }
      }
      final lineBytes = buffer.sublist(lineStartIndex, index);
      lines.add(
        _StreamingLine(
          text: _decodeStreamingLine(
            lineBytes,
            charsetName: littleEndian ? 'utf-16le' : 'utf-16be',
          ),
          startOffset: bufferStartOffset + lineStartIndex,
          endOffset: bufferStartOffset + index + separatorLength,
        ),
      );
      lineStartIndex = index + separatorLength;
      index = lineStartIndex;
    }
    final carryBytes = buffer.sublist(lineStartIndex);
    return _StreamingLineExtraction(
      lines: lines,
      carryBytes: carryBytes,
      nextBufferOffset: bufferStartOffset + buffer.length - carryBytes.length,
    );
  }

  int _readUtf16CodeUnit(
    List<int> bytes,
    int offset, {
    required bool littleEndian,
  }) {
    if (littleEndian) {
      return bytes[offset] | (bytes[offset + 1] << 8);
    }
    return (bytes[offset] << 8) | bytes[offset + 1];
  }

  String _decodeStreamingLine(List<int> bytes, {required String charsetName}) {
    if (bytes.isEmpty) {
      return '';
    }
    return _tryDecodeByCharset(bytes, charsetName) ??
        utf8.decode(bytes, allowMalformed: true);
  }

  _ResolvedTxtChapterPattern? _detectChapterPattern(
    String text, {
    required List<TxtAutoChapterPattern> enabledRules,
  }) {
    final sample =
        text.length > _chapterPatternDetectionSampleLength
            ? text.substring(0, _chapterPatternDetectionSampleLength)
            : text;
    _ResolvedTxtChapterPattern? selectedPattern;
    var maxHits = 0;
    var maxRawMatches = 0;
    int? earliestStart;

    for (final chapterPattern in enabledRules.reversed) {
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

  Future<_DecodedBookText> _decodeBookText(
    LocalBook book,
    List<int> bytes, {
    required List<TxtAutoChapterPattern> enabledRules,
  }) async {
    final normalizedPreferred = _normalizeCharsetName(book.charset);
    if (normalizedPreferred == 'utf-8') {
      final decoded = const LocalTextEncodingDetector().decodeBestEffort(
        bytes,
        preferredCharset: normalizedPreferred,
        hintedCharset: normalizedPreferred,
      );
      return _DecodedBookText(
        text: decoded.text,
        charsetName: decoded.charsetName,
        bomLength: decoded.bomLength,
      );
    }

    final bomInfo = _detectBom(bytes);
    final bomLength = bomInfo.length;
    final contentBytes =
        bomLength > 0 ? bytes.sublist(bomLength) : List<int>.from(bytes);

    final preferredCharset = normalizedPreferred;
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
        enabledRules: enabledRules,
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
      final mobileDecoded = await const LocalTextEncodingDetector()
          .decodeBestEffortAsync(
            bytes,
            preferredCharset: book.charset,
            hintedCharset: hintedCharset,
            candidateCharsets: candidateCharsets,
          );
      final mobileScore = _scoreDecodedText(
        mobileDecoded.text,
        enabledRules: enabledRules,
        charsetName: mobileDecoded.charsetName,
        hintedCharset: hintedCharset,
      );
      if (mobileDecoded.text.trim().isNotEmpty && mobileScore >= bestScore) {
        return _DecodedBookText(
          text: mobileDecoded.text,
          charsetName: mobileDecoded.charsetName,
          bomLength: mobileDecoded.bomLength,
        );
      }
      return best;
    }

    final decoded = await const LocalTextEncodingDetector()
        .decodeBestEffortAsync(
          bytes,
          preferredCharset: book.charset,
          hintedCharset: hintedCharset,
          candidateCharsets: candidateCharsets,
        );
    return _DecodedBookText(
      text: decoded.text,
      charsetName: decoded.charsetName,
      bomLength: decoded.bomLength,
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

  String _decodeStoredBytes(List<int> bytes, {required String charsetName}) {
    if (bytes.isEmpty) {
      return '';
    }
    return _tryDecodeByCharset(bytes, charsetName) ??
        utf8.decode(bytes, allowMalformed: true);
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

class _StreamingLine {
  const _StreamingLine({
    required this.text,
    required this.startOffset,
    required this.endOffset,
  });

  final String text;
  final int startOffset;
  final int endOffset;
}

class _StreamingLineExtraction {
  const _StreamingLineExtraction({
    required this.lines,
    required this.carryBytes,
    required this.nextBufferOffset,
  });

  final List<_StreamingLine> lines;
  final List<int> carryBytes;
  final int nextBufferOffset;
}

class _StreamingSampleChunk {
  const _StreamingSampleChunk({required this.start, required this.bytes});

  final int start;
  final List<int> bytes;
}

class _ScoredDecodedChunk {
  const _ScoredDecodedChunk({required this.decoded, required this.score});

  final _DecodedBookText decoded;
  final int score;
}

class _ResolvedTxtChapterPattern {
  const _ResolvedTxtChapterPattern({required this.compiled});

  final RegExp compiled;
}

class _CooperativeYieldGate {
  _CooperativeYieldGate({required this.byteBudget, required this.stepBudget});

  final int byteBudget;
  final int stepBudget;

  int _pendingBytes = 0;
  int _pendingSteps = 0;

  Future<void> maybeYield({
    int processedBytes = 0,
    int processedSteps = 1,
  }) async {
    if (processedBytes > 0) {
      _pendingBytes += processedBytes;
    }
    if (processedSteps > 0) {
      _pendingSteps += processedSteps;
    }
    if (_pendingBytes < byteBudget && _pendingSteps < stepBudget) {
      return;
    }
    _pendingBytes = 0;
    _pendingSteps = 0;
    await Future<void>.delayed(Duration.zero);
  }
}
