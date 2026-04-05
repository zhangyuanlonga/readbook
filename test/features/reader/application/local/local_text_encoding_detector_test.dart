import 'dart:convert';

import 'package:flutter_appread/features/reader/application/local/local_text_encoding_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalTextEncodingDetector', () {
    const detector = LocalTextEncodingDetector();

    test('decodeSampleBestEffort treats truncated utf8 sample as utf8', () {
      const sampleText = '第一章 开始\n正文内容。';
      final raw = utf8.encode(sampleText);
      final truncated = raw.sublist(0, raw.length - 1);

      final decoded = detector.decodeSampleBestEffort(truncated);

      expect(decoded, isNotNull);
      expect(decoded!.charsetName, 'utf-8');
      expect(decoded.text, contains('第一章'));
    });

    test('decodeSampleBestEffort keeps utf16 bom charset from sample', () {
      final bytes = _encodeUtf16(
        '第1章 开始\n正文内容。',
        littleEndian: true,
        withBom: true,
      );

      final decoded = detector.decodeSampleBestEffort(bytes);

      expect(decoded, isNotNull);
      expect(decoded!.charsetName, 'utf-16le');
      expect(decoded.text, contains('正文内容'));
    });

    test(
      'decodeSampleBestEffortAsync falls back without plugin in tests',
      () async {
        const sampleText = '第1章 开始\n正文内容。';
        final raw = utf8.encode(sampleText);

        final decoded = await detector.decodeSampleBestEffortAsync(raw);

        expect(decoded, isNotNull);
        expect(decoded!.text, contains('正文内容'));
      },
    );

    test(
      'decodeBestEffortAsync respects preferred charset fallback path',
      () async {
        final bytes = _encodeUtf16(
          '第1章 开始\n正文内容。',
          littleEndian: true,
          withBom: true,
        );

        final decoded = await detector.decodeBestEffortAsync(
          bytes,
          preferredCharset: 'utf-16le',
        );

        expect(decoded.charsetName, 'utf-16le');
        expect(decoded.text, contains('正文内容'));
      },
    );
  });
}

List<int> _encodeUtf16(
  String value, {
  required bool littleEndian,
  bool withBom = false,
}) {
  final bytes = <int>[];
  if (withBom) {
    if (littleEndian) {
      bytes.addAll(const <int>[0xFF, 0xFE]);
    } else {
      bytes.addAll(const <int>[0xFE, 0xFF]);
    }
  }
  for (final unit in value.codeUnits) {
    if (littleEndian) {
      bytes.add(unit & 0xFF);
      bytes.add((unit >> 8) & 0xFF);
    } else {
      bytes.add((unit >> 8) & 0xFF);
      bytes.add(unit & 0xFF);
    }
  }
  return bytes;
}
