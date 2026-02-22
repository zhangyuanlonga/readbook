import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

class SourceResponseProcessResult {
  const SourceResponseProcessResult({
    required this.body,
    this.decryptApplied = false,
    this.decodeApplied = false,
  });

  final String body;
  final bool decryptApplied;
  final bool decodeApplied;
}

class SourceResponseProcessor {
  const SourceResponseProcessor();

  SourceResponseProcessResult process({
    required String body,
    String? requestUrl,
    String? fallbackUrl,
    String? decryptRule,
  }) {
    var normalized = body;
    var decryptApplied = false;
    var decodeApplied = false;

    final decrypted = _tryDecryptBody(
      body: normalized,
      requestUrl: requestUrl,
      fallbackUrl: fallbackUrl,
      decryptRule: decryptRule,
    );
    if (decrypted != null && decrypted != normalized) {
      normalized = decrypted;
      decryptApplied = true;
    }

    final decoded = _decodeLegacyPayloadIfNeeded(normalized);
    if (decoded != null && decoded != normalized) {
      normalized = decoded;
      decodeApplied = true;
    }

    return SourceResponseProcessResult(
      body: normalized,
      decryptApplied: decryptApplied,
      decodeApplied: decodeApplied,
    );
  }

  String? _tryDecryptBody({
    required String body,
    required String? requestUrl,
    required String? fallbackUrl,
    required String? decryptRule,
  }) {
    final spec = _LegacyResponseDecryptSpec.fromRaw(decryptRule);
    if (spec == null ||
        !spec.matches(requestUrl: requestUrl, fallbackUrl: fallbackUrl)) {
      return null;
    }

    return switch (spec.type) {
      _LegacyResponseDecryptSpec.aesCbcPkcs7Iv16Base64LzBase64 =>
        _decryptAesCbcPkcs7Body(body: body, key: spec.key ?? ''),
      _LegacyResponseDecryptSpec.lzBase64 =>
        _LzStringDecoder.decompressFromBase64(
          body.replaceAll(RegExp(r'\s+'), ''),
        ),
      _LegacyResponseDecryptSpec.base64Utf8 => _decodeBase64Utf8(body),
      _ => null,
    };
  }

  String? _decryptAesCbcPkcs7Body({required String body, required String key}) {
    final compact = body.replaceAll(RegExp(r'\s+'), '');
    if (compact.length < 24 || !_looksLikeBase64Text(compact)) {
      return null;
    }

    final keyBytes = Uint8List.fromList(utf8.encode(key));
    if (keyBytes.length != 16 &&
        keyBytes.length != 24 &&
        keyBytes.length != 32) {
      return null;
    }

    Uint8List encryptedBytes;
    try {
      encryptedBytes = Uint8List.fromList(base64.decode(compact));
    } on FormatException {
      return null;
    }

    if (encryptedBytes.lengthInBytes <= 16) {
      return null;
    }

    final iv = Uint8List.fromList(encryptedBytes.sublist(0, 16));
    final cipherText = Uint8List.fromList(encryptedBytes.sublist(16));

    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    );
    cipher.init(
      false,
      PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
        ParametersWithIV<KeyParameter>(KeyParameter(keyBytes), iv),
        null,
      ),
    );

    final decryptedBytes = cipher.process(cipherText);
    final decryptedText =
        utf8.decode(decryptedBytes, allowMalformed: true).trim();
    if (decryptedText.isEmpty) {
      return null;
    }

    final lzCandidate = decryptedText.replaceAll(RegExp(r'\s+'), '');
    final decompressed = _LzStringDecoder.decompressFromBase64(lzCandidate);
    if (decompressed != null && decompressed.trim().isNotEmpty) {
      return decompressed;
    }

    return decryptedText;
  }

  String? _decodeLegacyPayloadIfNeeded(String body) {
    final text = body.trim();
    if (text.isEmpty || _looksLikeStructuredPayload(text)) {
      return null;
    }

    final compact = text.replaceAll(RegExp(r'\s+'), '');
    if (compact.length < 16 || !_looksLikeBase64Text(compact)) {
      return null;
    }

    final decompressed = _LzStringDecoder.decompressFromBase64(compact);
    if (decompressed != null && _looksLikeStructuredPayload(decompressed)) {
      return decompressed;
    }

    final plain = _decodeBase64Utf8(compact)?.trim();
    if (plain != null && _looksLikeStructuredPayload(plain)) {
      return plain;
    }

    return null;
  }

  String? _decodeBase64Utf8(String body) {
    final compact = body.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty || !_looksLikeBase64Text(compact)) {
      return null;
    }

    try {
      final decodedBytes = base64.decode(compact);
      final plain = utf8.decode(decodedBytes, allowMalformed: true);
      final normalized = plain.trim();
      return normalized.isEmpty ? null : normalized;
    } on FormatException {
      return null;
    }
  }

  bool _looksLikeStructuredPayload(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    return trimmed.startsWith('{') ||
        trimmed.startsWith('[') ||
        trimmed.startsWith('<');
  }

  bool _looksLikeBase64Text(String text) {
    return RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(text);
  }
}

class _LegacyResponseDecryptSpec {
  const _LegacyResponseDecryptSpec({
    required this.type,
    this.key,
    this.urlContains,
  });

  static const String aesCbcPkcs7Iv16Base64LzBase64 =
      'aes_cbc_pkcs7_iv16_base64_lzbase64';
  static const String lzBase64 = 'lz_base64';
  static const String base64Utf8 = 'base64_utf8';

  final String type;
  final String? key;
  final String? urlContains;

  bool matches({required String? requestUrl, required String? fallbackUrl}) {
    final pattern = urlContains?.trim();
    if (pattern == null || pattern.isEmpty) {
      return true;
    }

    final request = requestUrl ?? '';
    final fallback = fallbackUrl ?? '';
    return request.contains(pattern) || fallback.contains(pattern);
  }

  static _LegacyResponseDecryptSpec? fromRaw(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return null;
    }

    if (decoded is! Map) {
      return null;
    }

    final type = decoded['type']?.toString().trim() ?? '';
    if (type.isEmpty) {
      return null;
    }

    final key = decoded['key']?.toString();
    final urlContains = decoded['urlContains']?.toString().trim();

    if (type == aesCbcPkcs7Iv16Base64LzBase64) {
      if (key == null || key.isEmpty) {
        return null;
      }
      return _LegacyResponseDecryptSpec(
        type: type,
        key: key,
        urlContains: urlContains,
      );
    }

    if (type == lzBase64 || type == base64Utf8) {
      return _LegacyResponseDecryptSpec(
        type: type,
        key: key,
        urlContains: urlContains,
      );
    }

    return null;
  }
}

class _LzStringDecoder {
  const _LzStringDecoder._();

  static const String _base64Alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';

  static String? decompressFromBase64(String input) {
    final normalized = input.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final compact = normalized.replaceAll(RegExp(r'\s+'), '');
    final decompressed = _decompress(compact.length, 32, (index) {
      if (index < 0 || index >= compact.length) {
        return -1;
      }
      return _base64Alphabet.indexOf(compact[index]);
    });

    final result = decompressed?.trim();
    if (result == null || result.isEmpty) {
      return null;
    }

    return result;
  }

  static String? _decompress(
    int length,
    int resetValue,
    int Function(int) getNextValue,
  ) {
    if (length == 0) {
      return null;
    }

    final dictionary = <String>['', '', ''];
    var enlargeIn = 4;
    var dictSize = 4;
    var numBits = 3;

    var dataVal = getNextValue(0);
    if (dataVal < 0) {
      return null;
    }
    var dataPosition = resetValue;
    var dataIndex = 1;

    int? readBits(int count) {
      var bits = 0;
      var maxPower = 1 << count;
      var power = 1;

      while (power != maxPower) {
        final resb = dataVal & dataPosition;
        dataPosition >>= 1;
        if (dataPosition == 0) {
          dataPosition = resetValue;
          if (dataIndex >= length) {
            return null;
          }
          dataVal = getNextValue(dataIndex);
          dataIndex += 1;
          if (dataVal < 0) {
            return null;
          }
        }
        bits |= (resb > 0 ? 1 : 0) * power;
        power <<= 1;
      }

      return bits;
    }

    final next = readBits(2);
    if (next == null) {
      return null;
    }

    String? nextValue;
    switch (next) {
      case 0:
        final charCode = readBits(8);
        if (charCode == null) {
          return null;
        }
        nextValue = String.fromCharCode(charCode);
        break;
      case 1:
        final charCode = readBits(16);
        if (charCode == null) {
          return null;
        }
        nextValue = String.fromCharCode(charCode);
        break;
      case 2:
        return '';
    }

    if (nextValue == null || nextValue.isEmpty) {
      return null;
    }

    dictionary.add(nextValue);
    var w = nextValue;
    final result = StringBuffer()..write(w);

    while (true) {
      if (dataIndex > length) {
        return null;
      }

      final c = readBits(numBits);
      if (c == null) {
        return null;
      }

      var current = c;

      if (current == 0) {
        final charCode = readBits(8);
        if (charCode == null) {
          return null;
        }
        dictionary.add(String.fromCharCode(charCode));
        current = dictSize;
        dictSize += 1;
        enlargeIn -= 1;
      } else if (current == 1) {
        final charCode = readBits(16);
        if (charCode == null) {
          return null;
        }
        dictionary.add(String.fromCharCode(charCode));
        current = dictSize;
        dictSize += 1;
        enlargeIn -= 1;
      } else if (current == 2) {
        return result.toString();
      }

      if (enlargeIn == 0) {
        enlargeIn = 1 << numBits;
        numBits += 1;
      }

      String entry;
      if (current < dictionary.length && dictionary[current].isNotEmpty) {
        entry = dictionary[current];
      } else if (current == dictSize) {
        entry = '$w${w[0]}';
      } else {
        return null;
      }

      result.write(entry);
      dictionary.add('$w${entry[0]}');
      dictSize += 1;
      enlargeIn -= 1;
      w = entry;

      if (enlargeIn == 0) {
        enlargeIn = 1 << numBits;
        numBits += 1;
      }
    }
  }
}
