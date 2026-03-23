import 'dart:convert';

import 'package:charset/charset.dart';

class LocalTextDecodeResult {
  const LocalTextDecodeResult({
    required this.text,
    required this.charsetName,
    required this.bomLength,
    this.fallbackUsed = false,
  });

  final String text;
  final String charsetName;
  final int bomLength;
  final bool fallbackUsed;
}

class LocalTextEncodingDetector {
  const LocalTextEncodingDetector();

  static const int _sampleLimit = 24000;
  static const List<String> _defaultCandidates = <String>[
    'utf-8',
    'utf-16be',
    'utf-16le',
    'gb18030',
    'gbk',
    'big5',
    'shift_jis',
    'euc-jp',
    'euc-kr',
    'windows-1252',
    'latin1',
  ];

  static String? normalizeCharsetName(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    return switch (normalized) {
      'utf8' => 'utf-8',
      'utf-8' => 'utf-8',
      'utf16' => 'utf-16',
      'utf-16' => 'utf-16',
      'utf16be' => 'utf-16be',
      'utf-16be' => 'utf-16be',
      'utf16le' => 'utf-16le',
      'utf-16le' => 'utf-16le',
      'gb2312' => 'gbk',
      'cp936' => 'gbk',
      'gbk' => 'gbk',
      'gb18030' => 'gb18030',
      'big5-hkscs' => 'big5',
      'big5' => 'big5',
      'sjis' => 'shift_jis',
      'shift-jis' => 'shift_jis',
      'shift_jis' => 'shift_jis',
      'eucjp' => 'euc-jp',
      'euc-jp' => 'euc-jp',
      'euckr' => 'euc-kr',
      'euc-kr' => 'euc-kr',
      'windows1252' => 'windows-1252',
      'windows-1252' => 'windows-1252',
      'latin1' => 'latin1',
      'iso-8859-1' => 'latin1',
      _ => normalized,
    };
  }

  static String? extractDeclaredCharsetFromHtml(List<int> bytes) {
    if (bytes.isEmpty) {
      return null;
    }
    final sampleBytes =
        bytes.length > 4096 ? bytes.sublist(0, 4096) : List<int>.from(bytes);
    final sample = latin1.decode(sampleBytes, allowInvalid: true);
    final normalizedSample = sample.toLowerCase();

    final metaCharset = RegExp(
      "<meta[^>]*charset\\s*=\\s*[\"']?\\s*([a-z0-9_-]+)",
      caseSensitive: false,
    ).firstMatch(normalizedSample);
    if (metaCharset != null) {
      return normalizeCharsetName(metaCharset.group(1));
    }

    final contentTypeCharset = RegExp(
      "<meta[^>]*content\\s*=\\s*[\"'][^\"']*charset\\s*=\\s*([a-z0-9_-]+)",
      caseSensitive: false,
    ).firstMatch(normalizedSample);
    if (contentTypeCharset != null) {
      return normalizeCharsetName(contentTypeCharset.group(1));
    }

    final xmlEncoding = RegExp(
      "<\\?xml[^>]*encoding\\s*=\\s*[\"']\\s*([a-z0-9_-]+)\\s*[\"']",
      caseSensitive: false,
    ).firstMatch(normalizedSample);
    if (xmlEncoding != null) {
      return normalizeCharsetName(xmlEncoding.group(1));
    }

    return null;
  }

  LocalTextDecodeResult decodeBestEffort(
    List<int> bytes, {
    String? preferredCharset,
    String? hintedCharset,
    Iterable<String>? candidateCharsets,
    bool htmlAware = false,
  }) {
    if (bytes.isEmpty) {
      return const LocalTextDecodeResult(
        text: '',
        charsetName: 'utf-8',
        bomLength: 0,
        fallbackUsed: true,
      );
    }

    final bom = _detectBom(bytes);
    final contentBytes =
        bom.length > 0 ? bytes.sublist(bom.length) : List<int>.from(bytes);

    final normalizedPreferred = normalizeCharsetName(preferredCharset);
    final normalizedHinted =
        normalizeCharsetName(hintedCharset) ??
        bom.charsetName ??
        _detectUtf16ZeroPattern(contentBytes);

    final resolvedCandidates = <String>[
      if (normalizedPreferred != null) normalizedPreferred,
      if (normalizedHinted != null) normalizedHinted,
      ...?candidateCharsets?.map(normalizeCharsetName).whereType<String>(),
      ..._defaultCandidates,
    ];

    LocalTextDecodeResult? best;
    var bestScore = -0x7fffffff;
    final seen = <String>{};
    for (final rawCandidate in resolvedCandidates) {
      final candidate = normalizeCharsetName(rawCandidate);
      if (candidate == null || !seen.add(candidate)) {
        continue;
      }
      final decoded = _tryDecodeByCharset(contentBytes, candidate);
      if (decoded == null) {
        continue;
      }
      final score = _scoreDecodedText(
        decoded,
        charsetName: candidate,
        hintedCharset: normalizedHinted,
        htmlAware: htmlAware,
      );
      if (best == null || score > bestScore) {
        best = LocalTextDecodeResult(
          text: decoded,
          charsetName: candidate,
          bomLength: bom.length,
        );
        bestScore = score;
      }
    }

    if (best != null) {
      return best;
    }

    return LocalTextDecodeResult(
      text: utf8.decode(contentBytes, allowMalformed: true),
      charsetName: 'utf-8',
      bomLength: bom.length,
      fallbackUsed: true,
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
    final sampleLength = bytes.length < 4096 ? bytes.length : 4096;
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

  String? _tryDecodeByCharset(List<int> bytes, String charsetName) {
    try {
      switch (charsetName) {
        case 'utf-8':
          return utf8.decode(bytes, allowMalformed: false);
        case 'latin1':
        case 'windows-1252':
          final encoding = Charset.getByName(charsetName);
          if (encoding != null) {
            return encoding.decode(bytes);
          }
          return latin1.decode(bytes, allowInvalid: true);
        default:
          final encoding = Charset.getByName(charsetName);
          if (encoding == null) {
            return null;
          }
          return encoding.decode(bytes);
      }
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  int _scoreDecodedText(
    String text, {
    required String charsetName,
    required String? hintedCharset,
    required bool htmlAware,
  }) {
    final sample =
        text.length > _sampleLimit ? text.substring(0, _sampleLimit) : text;
    if (sample.trim().isEmpty) {
      return -0x3fffffff;
    }

    var replacementCount = 0;
    var nulCount = 0;
    var controlCount = 0;
    var hanCount = 0;
    var cjkPunctuationCount = 0;
    var suspiciousMojibakeCount = 0;
    var asciiCount = 0;

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
      if ('，。！？；：“”‘’《》、（）【】'.runes.contains(rune)) {
        cjkPunctuationCount += 1;
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

    var score = 0;
    score += hanCount * 2;
    score += cjkPunctuationCount * 10;
    score += htmlAware ? _scoreHtmlSignals(sample) : _scorePlainSignals(sample);
    score -= replacementCount * 180;
    score -= nulCount * 260;
    score -= controlCount * 90;
    score -= suspiciousMojibakeCount * 55;

    if (!htmlAware && hanCount > asciiCount) {
      score += 60;
    }

    if (hintedCharset != null && hintedCharset == charsetName) {
      score += 140;
    }
    if (charsetName == 'utf-8') {
      score += 24;
    }

    return score;
  }

  int _scorePlainSignals(String sample) {
    var score = 0;
    if (RegExp(r'第.{0,12}[章节回卷部集]\s*', multiLine: true).hasMatch(sample)) {
      score += 120;
    }
    if (RegExp(r'[。！？；]\s*').hasMatch(sample)) {
      score += 80;
    }
    return score;
  }

  int _scoreHtmlSignals(String sample) {
    final lower = sample.toLowerCase();
    var score = 0;
    if (lower.contains('<html') ||
        lower.contains('<body') ||
        lower.contains('<?xml')) {
      score += 140;
    }
    final tagMatches =
        RegExp(
          r'<(html|head|body|div|p|span|h[1-6]|img|meta|title)\b',
          caseSensitive: false,
        ).allMatches(lower).length;
    final closeMatches =
        RegExp(
          r'</[a-z][a-z0-9]*>',
          caseSensitive: false,
        ).allMatches(lower).length;
    score += tagMatches * 14;
    score += closeMatches * 6;
    if (tagMatches == 0 && closeMatches == 0) {
      score -= 120;
    }
    return score;
  }
}

class _BomInfo {
  const _BomInfo({required this.length, required this.charsetName});

  final int length;
  final String? charsetName;
}
