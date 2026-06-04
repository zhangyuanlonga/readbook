import 'dart:convert';

import 'package:charset/charset.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_charset_detector/flutter_charset_detector.dart';

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

/// 本地文本编码检测统一入口。
///
/// 这里保留项目内评分策略，是为了把 BOM、平台 converter、移动端探测器和
/// 中文常见编码候选收口到一个地方。后续不要在 storage、preview、parser
/// 中复制新的 charset 评分逻辑；如有成熟跨端检测库能覆盖这些平台差异，
/// 应先替换本类实现，再回归 TXT / HTML / EPUB 相关测试。
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
      'ansi' => 'gb18030',
      'x-ansi' => 'gb18030',
      'utf8' => 'utf-8',
      'utf-8' => 'utf-8',
      'utf16' => 'utf-16',
      'utf-16' => 'utf-16',
      'utf16be' => 'utf-16be',
      'utf-16be' => 'utf-16be',
      'utf16le' => 'utf-16le',
      'utf-16le' => 'utf-16le',
      'gb2312' => 'gbk',
      'gb_2312-80' => 'gbk',
      'cp936' => 'gbk',
      'windows936' => 'gbk',
      'windows-936' => 'gbk',
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
    final strictUtf8 = _tryDecodeUtf8Sample(bytes, bom: bom);
    if (strictUtf8 != null && strictUtf8.trim().isNotEmpty) {
      return LocalTextDecodeResult(
        text: strictUtf8,
        charsetName: 'utf-8',
        bomLength: bom.length,
      );
    }
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
      final decoded = tryDecodeByCharset(contentBytes, candidate);
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

  Future<LocalTextDecodeResult> decodeBestEffortAsync(
    List<int> bytes, {
    String? preferredCharset,
    String? hintedCharset,
    Iterable<String>? candidateCharsets,
    bool htmlAware = false,
  }) async {
    if (bytes.isEmpty) {
      return const LocalTextDecodeResult(
        text: '',
        charsetName: 'utf-8',
        bomLength: 0,
        fallbackUsed: true,
      );
    }

    final bom = _detectBom(bytes);
    final strictUtf8 = _tryDecodeUtf8Sample(bytes, bom: bom);
    if (strictUtf8 != null && strictUtf8.trim().isNotEmpty) {
      return LocalTextDecodeResult(
        text: strictUtf8,
        charsetName: 'utf-8',
        bomLength: bom.length,
      );
    }
    final contentBytes =
        bom.length > 0 ? bytes.sublist(bom.length) : List<int>.from(bytes);

    final normalizedPreferred = normalizeCharsetName(preferredCharset);
    final normalizedHinted =
        normalizeCharsetName(hintedCharset) ??
        bom.charsetName ??
        _detectUtf16ZeroPattern(contentBytes);

    final candidates = <_AsyncDecodeCandidate>[];

    final mobileDecoded = await _tryAutoDecodeOnMobile(contentBytes);
    if (mobileDecoded != null && mobileDecoded.string.trim().isNotEmpty) {
      candidates.add(
        _AsyncDecodeCandidate(
          result: LocalTextDecodeResult(
            text: mobileDecoded.string,
            charsetName: mobileDecoded.charset,
            bomLength: bom.length,
          ),
          source: _AsyncDecodeSource.plugin,
        ),
      );
    }

    if (normalizedPreferred != null) {
      final preferredDecoded = await _tryDecodeWithPlatformConverter(
        charsetName: normalizedPreferred,
        bytes: contentBytes,
      );
      if (preferredDecoded != null && preferredDecoded.trim().isNotEmpty) {
        candidates.add(
          _AsyncDecodeCandidate(
            result: LocalTextDecodeResult(
              text: preferredDecoded,
              charsetName: normalizedPreferred,
              bomLength: bom.length,
            ),
            source: _AsyncDecodeSource.preferred,
          ),
        );
      }
    }

    final fallback = decodeBestEffort(
      bytes,
      preferredCharset: preferredCharset,
      hintedCharset: hintedCharset,
      candidateCharsets: candidateCharsets,
      htmlAware: htmlAware,
    );
    candidates.add(
      _AsyncDecodeCandidate(
        result: fallback,
        source: _AsyncDecodeSource.fallback,
      ),
    );

    final bestCandidate = _pickBestAsyncCandidate(
      candidates,
      hintedCharset: normalizedHinted,
      htmlAware: htmlAware,
    );
    if (bestCandidate != null) {
      return bestCandidate.result;
    }

    return LocalTextDecodeResult(
      text: utf8.decode(contentBytes, allowMalformed: true),
      charsetName: 'utf-8',
      bomLength: bom.length,
      fallbackUsed: true,
    );
  }

  LocalTextDecodeResult? decodeDirectBytes(
    List<int> bytes, {
    String? preferredCharset,
    String? hintedCharset,
    Iterable<String>? candidateCharsets,
    bool htmlAware = false,
  }) {
    if (bytes.isEmpty) {
      return null;
    }
    final decoded = decodeBestEffort(
      bytes,
      preferredCharset: preferredCharset,
      hintedCharset: hintedCharset,
      candidateCharsets: candidateCharsets,
      htmlAware: htmlAware,
    );
    if (decoded.text.trim().isEmpty) {
      return null;
    }
    return decoded;
  }

  LocalTextDecodeResult? decodeWithFrozenCharset(
    List<int> bytes, {
    required String charsetName,
  }) {
    if (bytes.isEmpty) {
      return null;
    }
    final normalizedCharset = normalizeCharsetName(charsetName);
    if (normalizedCharset == null || normalizedCharset.isEmpty) {
      return null;
    }

    final bom = _detectBom(bytes);
    final contentBytes = _stripCompatibleBom(
      bytes,
      bom: bom,
      charsetName: normalizedCharset,
    );
    final decoded = tryDecodeByCharset(contentBytes, normalizedCharset);
    if (decoded == null || decoded.trim().isEmpty) {
      return null;
    }
    return LocalTextDecodeResult(
      text: decoded.replaceFirst('\uFEFF', ''),
      charsetName: normalizedCharset,
      bomLength: bom.length,
    );
  }

  Future<LocalTextDecodeResult?> decodeDirectBytesAsync(
    List<int> bytes, {
    String? preferredCharset,
    String? hintedCharset,
    Iterable<String>? candidateCharsets,
    bool htmlAware = false,
  }) async {
    if (bytes.isEmpty) {
      return null;
    }
    final decoded = await decodeBestEffortAsync(
      bytes,
      preferredCharset: preferredCharset,
      hintedCharset: hintedCharset,
      candidateCharsets: candidateCharsets,
      htmlAware: htmlAware,
    );
    if (decoded.text.trim().isEmpty) {
      return null;
    }
    return decoded;
  }

  LocalTextDecodeResult? decodeSampleBestEffort(
    List<int> bytes, {
    String? preferredCharset,
    String? hintedCharset,
    Iterable<String>? candidateCharsets,
    bool htmlAware = false,
  }) {
    if (bytes.isEmpty) {
      return null;
    }

    final bom = _detectBom(bytes);
    final strictUtf8 = _tryDecodeUtf8Sample(bytes, bom: bom);
    if (strictUtf8 != null && strictUtf8.trim().isNotEmpty) {
      return LocalTextDecodeResult(
        text: strictUtf8,
        charsetName: 'utf-8',
        bomLength: bom.length,
      );
    }

    final decoded = decodeBestEffort(
      bytes,
      preferredCharset: preferredCharset,
      hintedCharset: hintedCharset,
      candidateCharsets: candidateCharsets,
      htmlAware: htmlAware,
    );
    if (decoded.text.trim().isEmpty) {
      return null;
    }
    return decoded;
  }

  Future<LocalTextDecodeResult?> decodeSampleBestEffortAsync(
    List<int> bytes, {
    String? preferredCharset,
    String? hintedCharset,
    Iterable<String>? candidateCharsets,
    bool htmlAware = false,
  }) async {
    if (bytes.isEmpty) {
      return null;
    }

    final bom = _detectBom(bytes);
    final strictUtf8 = _tryDecodeUtf8Sample(bytes, bom: bom);
    if (strictUtf8 != null && strictUtf8.trim().isNotEmpty) {
      return LocalTextDecodeResult(
        text: strictUtf8,
        charsetName: 'utf-8',
        bomLength: bom.length,
      );
    }

    final contentBytes =
        bom.length > 0 ? bytes.sublist(bom.length) : List<int>.from(bytes);
    final normalizedPreferred = normalizeCharsetName(preferredCharset);
    final normalizedHinted =
        normalizeCharsetName(hintedCharset) ??
        bom.charsetName ??
        _detectUtf16ZeroPattern(contentBytes);

    final candidates = <_AsyncDecodeCandidate>[];

    final mobileDecoded = await _tryAutoDecodeOnMobile(contentBytes);
    if (mobileDecoded != null && mobileDecoded.string.trim().isNotEmpty) {
      candidates.add(
        _AsyncDecodeCandidate(
          result: LocalTextDecodeResult(
            text: mobileDecoded.string,
            charsetName: mobileDecoded.charset,
            bomLength: bom.length,
          ),
          source: _AsyncDecodeSource.plugin,
        ),
      );
    }

    if (normalizedPreferred != null) {
      final preferredDecoded = await _tryDecodeWithPlatformConverter(
        charsetName: normalizedPreferred,
        bytes: contentBytes,
      );
      if (preferredDecoded != null && preferredDecoded.trim().isNotEmpty) {
        candidates.add(
          _AsyncDecodeCandidate(
            result: LocalTextDecodeResult(
              text: preferredDecoded,
              charsetName: normalizedPreferred,
              bomLength: bom.length,
            ),
            source: _AsyncDecodeSource.preferred,
          ),
        );
      }
    }

    final fallback = decodeSampleBestEffort(
      bytes,
      preferredCharset: preferredCharset,
      hintedCharset: hintedCharset,
      candidateCharsets: candidateCharsets,
      htmlAware: htmlAware,
    );
    if (fallback != null) {
      candidates.add(
        _AsyncDecodeCandidate(
          result: fallback,
          source: _AsyncDecodeSource.fallback,
        ),
      );
    }
    return _pickBestAsyncCandidate(
      candidates,
      hintedCharset: normalizedHinted,
      htmlAware: htmlAware,
    )?.result;
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

  String? _tryDecodeUtf8Sample(List<int> bytes, {required _BomInfo bom}) {
    if (bom.charsetName != null && bom.charsetName != 'utf-8') {
      return null;
    }

    final contentBytes =
        bom.length > 0 ? bytes.sublist(bom.length) : List<int>.from(bytes);
    for (
      var truncatedTailBytes = 0;
      truncatedTailBytes <= 3 && truncatedTailBytes < contentBytes.length;
      truncatedTailBytes += 1
    ) {
      final candidateLength = contentBytes.length - truncatedTailBytes;
      if (candidateLength <= 0) {
        break;
      }
      try {
        final decoded = utf8.decode(
          contentBytes.sublist(0, candidateLength),
          allowMalformed: false,
        );
        if (decoded.trim().isNotEmpty) {
          return decoded;
        }
      } on FormatException {
        continue;
      }
    }
    return null;
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

  static String? tryDecodeByCharset(List<int> bytes, String charsetName) {
    try {
      switch (charsetName) {
        case 'utf-8':
          return utf8.decode(bytes, allowMalformed: false);
        case 'utf-16':
          return _decodeUtf16(bytes);
        case 'utf-16le':
          return _decodeUtf16ByEndian(bytes, littleEndian: true);
        case 'utf-16be':
          return _decodeUtf16ByEndian(bytes, littleEndian: false);
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

  static String _decodeUtf16(List<int> bytes) {
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _decodeUtf16ByEndian(bytes.sublist(2), littleEndian: false);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _decodeUtf16ByEndian(bytes.sublist(2), littleEndian: true);
    }
    return _decodeUtf16ByEndian(bytes, littleEndian: true);
  }

  static String _decodeUtf16ByEndian(
    List<int> bytes, {
    required bool littleEndian,
  }) {
    if (bytes.isEmpty) {
      return '';
    }

    final codeUnits = <int>[];
    final evenLength = bytes.length - (bytes.length % 2);
    for (var index = 0; index < evenLength; index += 2) {
      final first = bytes[index];
      final second = bytes[index + 1];
      codeUnits.add(
        littleEndian ? (first | (second << 8)) : ((first << 8) | second),
      );
    }
    if (bytes.length.isOdd) {
      final last = bytes.last;
      codeUnits.add(littleEndian ? last : (last << 8));
    }
    return String.fromCharCodes(codeUnits);
  }

  List<int> _stripCompatibleBom(
    List<int> bytes, {
    required _BomInfo bom,
    required String charsetName,
  }) {
    if (bom.length <= 0 || bytes.length <= bom.length) {
      return List<int>.from(bytes);
    }
    if (bom.charsetName == null) {
      return List<int>.from(bytes);
    }
    if (charsetName == bom.charsetName ||
        (charsetName == 'utf-16' &&
            (bom.charsetName == 'utf-16le' || bom.charsetName == 'utf-16be'))) {
      return bytes.sublist(bom.length);
    }
    return List<int>.from(bytes);
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
    if ((charsetName == 'gb18030' || charsetName == 'gbk') &&
        (hanCount > 0 || cjkPunctuationCount > 0)) {
      score += 48;
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

  bool get _shouldUsePluginDetector {
    if (kIsWeb) {
      return true;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  bool get _shouldUsePlatformConverter {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  Future<_MobileAutoDecodeResult?> _tryAutoDecodeOnMobile(
    List<int> bytes,
  ) async {
    if (!_shouldUsePluginDetector || bytes.isEmpty) {
      return null;
    }
    try {
      final result = await CharsetDetector.autoDecode(
        Uint8List.fromList(bytes),
      );
      final charset = normalizeCharsetName(result.charset);
      final text = result.string.trim();
      if (charset == null || text.isEmpty) {
        return null;
      }
      return _MobileAutoDecodeResult(charset: charset, string: result.string);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _tryDecodeWithPlatformConverter({
    required String charsetName,
    required List<int> bytes,
  }) async {
    final directDecoded = tryDecodeByCharset(bytes, charsetName);
    if (directDecoded != null) {
      return directDecoded;
    }

    if (!_shouldUsePlatformConverter || bytes.isEmpty) {
      return null;
    }
    try {
      if (!await CharsetConverter.checkAvailability(charsetName)) {
        return null;
      }
      return CharsetConverter.decode(charsetName, Uint8List.fromList(bytes));
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }

  _AsyncDecodeCandidate? _pickBestAsyncCandidate(
    List<_AsyncDecodeCandidate> candidates, {
    required String? hintedCharset,
    required bool htmlAware,
  }) {
    if (candidates.isEmpty) {
      return null;
    }
    _AsyncDecodeCandidate? best;
    var bestScore = -0x7fffffff;
    for (final candidate in candidates) {
      final text = candidate.result.text.trim();
      if (text.isEmpty) {
        continue;
      }
      var score = _scoreDecodedText(
        candidate.result.text,
        charsetName: candidate.result.charsetName,
        hintedCharset: hintedCharset,
        htmlAware: htmlAware,
      );
      score += switch (candidate.source) {
        _AsyncDecodeSource.plugin => 0,
        _AsyncDecodeSource.preferred => 80,
        _AsyncDecodeSource.fallback => 40,
      };
      if (best == null || score > bestScore) {
        best = candidate;
        bestScore = score;
      }
    }
    return best;
  }
}

class _BomInfo {
  const _BomInfo({required this.length, required this.charsetName});

  final int length;
  final String? charsetName;
}

class _MobileAutoDecodeResult {
  const _MobileAutoDecodeResult({required this.charset, required this.string});

  final String charset;
  final String string;
}

enum _AsyncDecodeSource { plugin, preferred, fallback }

class _AsyncDecodeCandidate {
  const _AsyncDecodeCandidate({required this.result, required this.source});

  final LocalTextDecodeResult result;
  final _AsyncDecodeSource source;
}
