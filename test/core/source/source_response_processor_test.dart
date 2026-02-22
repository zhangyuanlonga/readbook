import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_appread/core/source/source_response_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';

void main() {
  group('SourceResponseProcessor', () {
    const processor = SourceResponseProcessor();

    test('decodes legacy lz-base64 payload into structured json', () {
      final payload =
          File(
            'test/fixtures/aaawz_search_payload_lz_base64.txt',
          ).readAsStringSync().trim();

      final processed = processor.process(body: payload);

      expect(processed.decodeApplied, isTrue);
      expect(processed.body.trimLeft().startsWith('{'), isTrue);
      final decoded = jsonDecode(processed.body) as Map<String, dynamic>;
      expect(decoded['data'], isA<Map>());
    });

    test('decrypts aes-cbc payload then keeps plain html content', () {
      const decryptRule =
          r'{"type":"aes_cbc_pkcs7_iv16_base64_lzbase64","key":"123#2^0@0vm@08.b5%$1[A]1&4115s((","urlContains":"-chapter-"}';
      const plainText = '<div class="content">第一段\n\n第二段</div>';

      final encryptedPayload = _encryptLegacyAesChapterPayload(
        plainText: plainText,
        key: r'123#2^0@0vm@08.b5%$1[A]1&4115s((',
      );

      final processed = processor.process(
        body: encryptedPayload,
        requestUrl: 'https://example.com/api-chapter-1',
        decryptRule: decryptRule,
      );

      expect(processed.decryptApplied, isTrue);
      expect(processed.body, plainText);
    });

    test('skips decrypt when url condition does not match', () {
      const decryptRule = r'{"type":"lz_base64","urlContains":"-chapter-"}';
      final payload =
          File(
            'test/fixtures/aaawz_detail_payload_lz_base64.txt',
          ).readAsStringSync().trim();

      final processed = processor.process(
        body: payload,
        requestUrl: 'https://example.com/api-info-1',
        decryptRule: decryptRule,
      );

      expect(processed.decryptApplied, isFalse);
      expect(processed.decodeApplied, isTrue);
      expect(processed.body.trimLeft().startsWith('{'), isTrue);
    });
  });
}

String _encryptLegacyAesChapterPayload({
  required String plainText,
  required String key,
}) {
  final iv = Uint8List.fromList(List<int>.generate(16, (index) => index + 1));
  final keyBytes = Uint8List.fromList(utf8.encode(key));

  final cipher = PaddedBlockCipherImpl(
    PKCS7Padding(),
    CBCBlockCipher(AESEngine()),
  );
  cipher.init(
    true,
    PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
      ParametersWithIV<KeyParameter>(KeyParameter(keyBytes), iv),
      null,
    ),
  );

  final encrypted = cipher.process(Uint8List.fromList(utf8.encode(plainText)));
  final payload = Uint8List.fromList(<int>[...iv, ...encrypted]);
  return base64.encode(payload);
}
