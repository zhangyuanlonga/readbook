import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart';

class SourceCryptoContext {
  SourceCryptoContext({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  String md5(
    String? value, {
    String inputEncoding = 'utf8',
    String outputEncoding = 'hex',
  }) {
    return _hash(
      _decodeBytes(value ?? '', inputEncoding),
      crypto.md5.convert,
      outputEncoding,
    );
  }

  String sha1(
    String? value, {
    String inputEncoding = 'utf8',
    String outputEncoding = 'hex',
  }) {
    return _hash(
      _decodeBytes(value ?? '', inputEncoding),
      crypto.sha1.convert,
      outputEncoding,
    );
  }

  String sha256(
    String? value, {
    String inputEncoding = 'utf8',
    String outputEncoding = 'hex',
  }) {
    return _hash(
      _decodeBytes(value ?? '', inputEncoding),
      crypto.sha256.convert,
      outputEncoding,
    );
  }

  String sha512(
    String? value, {
    String inputEncoding = 'utf8',
    String outputEncoding = 'hex',
  }) {
    return _hash(
      _decodeBytes(value ?? '', inputEncoding),
      crypto.sha512.convert,
      outputEncoding,
    );
  }

  String sm3(
    String? value, {
    String inputEncoding = 'utf8',
    String outputEncoding = 'hex',
  }) {
    final bytes = _decodeBytes(value ?? '', inputEncoding);
    final digest = SM3Digest().process(bytes);
    return _encodeBytes(digest, outputEncoding);
  }

  String hmacSha1(
    String? value,
    String? key, {
    String inputEncoding = 'utf8',
    String keyEncoding = 'utf8',
    String outputEncoding = 'hex',
  }) {
    return _hmac(
      value: value,
      key: key,
      digest: crypto.sha1,
      inputEncoding: inputEncoding,
      keyEncoding: keyEncoding,
      outputEncoding: outputEncoding,
    );
  }

  String hmacSha256(
    String? value,
    String? key, {
    String inputEncoding = 'utf8',
    String keyEncoding = 'utf8',
    String outputEncoding = 'hex',
  }) {
    return _hmac(
      value: value,
      key: key,
      digest: crypto.sha256,
      inputEncoding: inputEncoding,
      keyEncoding: keyEncoding,
      outputEncoding: outputEncoding,
    );
  }

  String hmacSha512(
    String? value,
    String? key, {
    String inputEncoding = 'utf8',
    String keyEncoding = 'utf8',
    String outputEncoding = 'hex',
  }) {
    return _hmac(
      value: value,
      key: key,
      digest: crypto.sha512,
      inputEncoding: inputEncoding,
      keyEncoding: keyEncoding,
      outputEncoding: outputEncoding,
    );
  }

  String aesEncrypt({
    required String data,
    required String key,
    String? iv,
    String mode = 'cbc',
    String inputEncoding = 'utf8',
    String keyEncoding = 'utf8',
    String ivEncoding = 'utf8',
    String outputEncoding = 'base64',
  }) {
    return symmetricEncrypt(
      algorithm: 'AES-${mode.toUpperCase()}-PKCS5Padding',
      data: data,
      key: key,
      iv: iv,
      inputEncoding: inputEncoding,
      dataEncoding: inputEncoding,
      keyEncoding: keyEncoding,
      ivEncoding: ivEncoding,
      outputEncoding: outputEncoding,
    );
  }

  String aesDecrypt({
    required String data,
    required String key,
    String? iv,
    String mode = 'cbc',
    String inputEncoding = 'base64',
    String keyEncoding = 'utf8',
    String ivEncoding = 'utf8',
    String outputEncoding = 'utf8',
  }) {
    return symmetricDecrypt(
      algorithm: 'AES-${mode.toUpperCase()}-PKCS5Padding',
      data: data,
      key: key,
      iv: iv,
      dataEncoding: inputEncoding,
      keyEncoding: keyEncoding,
      ivEncoding: ivEncoding,
      outputEncoding: outputEncoding,
    );
  }

  String desEncrypt({
    required String data,
    required String key,
    String? iv,
    String mode = 'cbc',
    String inputEncoding = 'utf8',
    String keyEncoding = 'utf8',
    String ivEncoding = 'utf8',
    String outputEncoding = 'base64',
  }) {
    return symmetricEncrypt(
      algorithm: 'DES-${mode.toUpperCase()}-PKCS5Padding',
      data: data,
      key: key,
      iv: iv,
      inputEncoding: inputEncoding,
      dataEncoding: inputEncoding,
      keyEncoding: keyEncoding,
      ivEncoding: ivEncoding,
      outputEncoding: outputEncoding,
    );
  }

  String desDecrypt({
    required String data,
    required String key,
    String? iv,
    String mode = 'cbc',
    String inputEncoding = 'base64',
    String keyEncoding = 'utf8',
    String ivEncoding = 'utf8',
    String outputEncoding = 'utf8',
  }) {
    return symmetricDecrypt(
      algorithm: 'DES-${mode.toUpperCase()}-PKCS5Padding',
      data: data,
      key: key,
      iv: iv,
      dataEncoding: inputEncoding,
      keyEncoding: keyEncoding,
      ivEncoding: ivEncoding,
      outputEncoding: outputEncoding,
    );
  }

  String tripleDesEncrypt({
    required String data,
    required String key,
    String? iv,
    String mode = 'cbc',
    String inputEncoding = 'utf8',
    String keyEncoding = 'utf8',
    String ivEncoding = 'utf8',
    String outputEncoding = 'base64',
  }) {
    return symmetricEncrypt(
      algorithm: 'DESede-${mode.toUpperCase()}-PKCS5Padding',
      data: data,
      key: key,
      iv: iv,
      inputEncoding: inputEncoding,
      dataEncoding: inputEncoding,
      keyEncoding: keyEncoding,
      ivEncoding: ivEncoding,
      outputEncoding: outputEncoding,
    );
  }

  String tripleDesDecrypt({
    required String data,
    required String key,
    String? iv,
    String mode = 'cbc',
    String inputEncoding = 'base64',
    String keyEncoding = 'utf8',
    String ivEncoding = 'utf8',
    String outputEncoding = 'utf8',
  }) {
    return symmetricDecrypt(
      algorithm: 'DESede-${mode.toUpperCase()}-PKCS5Padding',
      data: data,
      key: key,
      iv: iv,
      dataEncoding: inputEncoding,
      keyEncoding: keyEncoding,
      ivEncoding: ivEncoding,
      outputEncoding: outputEncoding,
    );
  }

  String rc4Encrypt({
    required String data,
    required String key,
    String inputEncoding = 'utf8',
    String keyEncoding = 'utf8',
    String outputEncoding = 'base64',
  }) {
    return symmetricEncrypt(
      algorithm: 'RC4',
      data: data,
      key: key,
      inputEncoding: inputEncoding,
      dataEncoding: inputEncoding,
      keyEncoding: keyEncoding,
      outputEncoding: outputEncoding,
    );
  }

  String rc4Decrypt({
    required String data,
    required String key,
    String inputEncoding = 'base64',
    String keyEncoding = 'utf8',
    String outputEncoding = 'utf8',
  }) {
    return symmetricDecrypt(
      algorithm: 'RC4',
      data: data,
      key: key,
      dataEncoding: inputEncoding,
      keyEncoding: keyEncoding,
      outputEncoding: outputEncoding,
    );
  }

  String symmetricEncrypt({
    required String algorithm,
    required String data,
    required String key,
    String? iv,
    String inputEncoding = 'utf8',
    String dataEncoding = 'utf8',
    String keyEncoding = 'utf8',
    String ivEncoding = 'utf8',
    String outputEncoding = 'base64',
  }) {
    final spec = _SymmetricSpec.parse(algorithm);
    return _processSymmetric(
      spec: spec,
      encrypt: true,
      data: data,
      key: key,
      iv: iv,
      inputEncoding: inputEncoding,
      dataEncoding: dataEncoding,
      keyEncoding: keyEncoding,
      ivEncoding: ivEncoding,
      outputEncoding: outputEncoding,
    );
  }

  String symmetricDecrypt({
    required String algorithm,
    required String data,
    required String key,
    String? iv,
    String dataEncoding = 'base64',
    String keyEncoding = 'utf8',
    String ivEncoding = 'utf8',
    String outputEncoding = 'utf8',
  }) {
    final spec = _SymmetricSpec.parse(algorithm);
    return _processSymmetric(
      spec: spec,
      encrypt: false,
      data: data,
      key: key,
      iv: iv,
      inputEncoding: outputEncoding,
      dataEncoding: dataEncoding,
      keyEncoding: keyEncoding,
      ivEncoding: ivEncoding,
      outputEncoding: outputEncoding,
    );
  }

  String rsaEncrypt({
    required String data,
    required String publicKey,
    String inputEncoding = 'utf8',
    String outputEncoding = 'base64',
    String padding = 'pkcs1',
  }) {
    return asymmetricEncrypt(
      algorithm: 'RSA/ECB/${_normalizeRsaPaddingName(padding)}',
      data: data,
      publicKey: publicKey,
      inputEncoding: inputEncoding,
      outputEncoding: outputEncoding,
    );
  }

  String rsaDecrypt({
    required String data,
    required String privateKey,
    String inputEncoding = 'base64',
    String outputEncoding = 'utf8',
    String padding = 'pkcs1',
  }) {
    return asymmetricDecrypt(
      algorithm: 'RSA/ECB/${_normalizeRsaPaddingName(padding)}',
      data: data,
      privateKey: privateKey,
      inputEncoding: inputEncoding,
      outputEncoding: outputEncoding,
    );
  }

  String asymmetricEncrypt({
    required String algorithm,
    required String data,
    required String publicKey,
    String inputEncoding = 'utf8',
    String outputEncoding = 'base64',
  }) {
    final spec = _AsymmetricSpec.parse(algorithm);
    final input = _decodeBytes(data, inputEncoding);
    final key = _parsePublicKey(publicKey);
    final cipher = _buildRsaCipher(spec.padding)
      ..init(true, PublicKeyParameter<RSAPublicKey>(key));
    final output = _processAsymmetric(cipher, input);
    return _encodeBytes(output, outputEncoding);
  }

  String asymmetricDecrypt({
    required String algorithm,
    required String data,
    required String privateKey,
    String inputEncoding = 'base64',
    String outputEncoding = 'utf8',
  }) {
    final spec = _AsymmetricSpec.parse(algorithm);
    final input = _decodeBytes(data, inputEncoding);
    final key = _parsePrivateKey(privateKey);
    final cipher = _buildRsaCipher(spec.padding)
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(key));
    final output = _processAsymmetric(cipher, input);
    return _encodeBytes(output, outputEncoding);
  }

  String rsaSign({
    required String data,
    required String privateKey,
    String algorithm = 'SHA-256/RSA',
    String inputEncoding = 'utf8',
    String outputEncoding = 'base64',
  }) {
    final normalizedAlgorithm = _normalizeRsaSignAlgorithm(algorithm);
    final key = _parsePrivateKey(privateKey);
    final input = _decodeBytes(data, inputEncoding);
    final signature = CryptoUtils.rsaSign(
      key,
      input,
      algorithmName: normalizedAlgorithm,
    );
    return _encodeBytes(signature, outputEncoding);
  }

  bool rsaVerify({
    required String data,
    required String publicKey,
    required String signature,
    String algorithm = 'SHA-256/RSA',
    String inputEncoding = 'utf8',
    String signatureEncoding = 'base64',
  }) {
    final normalizedAlgorithm = _normalizeRsaSignAlgorithm(algorithm);
    final key = _parsePublicKey(publicKey);
    final input = _decodeBytes(data, inputEncoding);
    final signatureBytes = _decodeBytes(signature, signatureEncoding);
    return CryptoUtils.rsaVerify(
      key,
      input,
      signatureBytes,
      algorithm: normalizedAlgorithm,
    );
  }

  String randomBytes(int length, {String outputEncoding = 'hex'}) {
    if (length < 0) {
      throw ArgumentError.value(length, 'length', 'length 不能小于 0。');
    }
    final bytes = Uint8List.fromList(
      List<int>.generate(length, (_) => _random.nextInt(256)),
    );
    return _encodeBytes(bytes, outputEncoding);
  }

  String randomString(
    int length, {
    String alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789',
  }) {
    if (length < 0) {
      throw ArgumentError.value(length, 'length', 'length 不能小于 0。');
    }
    if (alphabet.isEmpty) {
      throw ArgumentError.value(alphabet, 'alphabet', 'alphabet 不能为空。');
    }
    final buffer = StringBuffer();
    for (var index = 0; index < length; index += 1) {
      buffer.write(alphabet[_random.nextInt(alphabet.length)]);
    }
    return buffer.toString();
  }

  int timestamp({String unit = 'ms'}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    switch (unit.trim().toLowerCase()) {
      case 'ms':
      case 'millisecond':
      case 'milliseconds':
        return now;
      case 's':
      case 'sec':
      case 'second':
      case 'seconds':
        return now ~/ 1000;
      default:
        throw ArgumentError.value(unit, 'unit', '仅支持 ms 或 s。');
    }
  }

  String _hash(
    Uint8List bytes,
    crypto.Digest Function(List<int> input) convert,
    String outputEncoding,
  ) {
    final digest = Uint8List.fromList(convert(bytes).bytes);
    return _encodeBytes(digest, outputEncoding);
  }

  String _hmac({
    required String? value,
    required String? key,
    required crypto.Hash digest,
    required String inputEncoding,
    required String keyEncoding,
    required String outputEncoding,
  }) {
    final hmac = crypto.Hmac(digest, _decodeBytes(key ?? '', keyEncoding));
    final result = hmac.convert(_decodeBytes(value ?? '', inputEncoding));
    return _encodeBytes(Uint8List.fromList(result.bytes), outputEncoding);
  }

  String _processSymmetric({
    required _SymmetricSpec spec,
    required bool encrypt,
    required String data,
    required String key,
    required String? iv,
    required String inputEncoding,
    required String dataEncoding,
    required String keyEncoding,
    required String ivEncoding,
    required String outputEncoding,
  }) {
    if (spec.algorithm == _CipherAlgorithm.rc4) {
      final keyBytes = _decodeBytes(key, keyEncoding);
      if (keyBytes.isEmpty) {
        throw ArgumentError('RC4 key 不能为空。');
      }
      final inputBytes = _decodeBytes(data, dataEncoding);
      final cipher = RC4Engine()..init(encrypt, KeyParameter(keyBytes));
      final output = cipher.process(inputBytes);
      return _encodeBytes(Uint8List.fromList(output), outputEncoding);
    }

    final keyBytes = _normalizeKey(
      algorithm: spec.algorithm,
      keyBytes: _decodeBytes(key, keyEncoding),
    );
    final dataBytes = _decodeBytes(data, dataEncoding);
    final cipher = _buildPaddedCipher(
      algorithm: spec.algorithm,
      mode: spec.mode ?? 'cbc',
      keyBytes: keyBytes,
      ivBytes: iv == null ? null : _decodeBytes(iv, ivEncoding),
      encrypt: encrypt,
    );
    final output = cipher.process(dataBytes);
    return _encodeBytes(Uint8List.fromList(output), outputEncoding);
  }

  PaddedBlockCipher _buildPaddedCipher({
    required _CipherAlgorithm algorithm,
    required String mode,
    required Uint8List keyBytes,
    required Uint8List? ivBytes,
    required bool encrypt,
  }) {
    final blockCipher = switch (algorithm) {
      _CipherAlgorithm.aes => AESEngine(),
      _CipherAlgorithm.des || _CipherAlgorithm.tripleDes => DESedeEngine(),
      _CipherAlgorithm.rc4 => throw StateError('RC4 不使用 block cipher。'),
    };

    final normalizedMode = mode.trim().toLowerCase();
    late final BlockCipher underlying;
    late final CipherParameters parameters;
    switch (normalizedMode) {
      case 'ecb':
        underlying = ECBBlockCipher(blockCipher);
        parameters = KeyParameter(keyBytes);
        break;
      case 'cbc':
        final blockSize = blockCipher.blockSize;
        final effectiveIv = ivBytes ?? Uint8List(blockSize);
        if (effectiveIv.length != blockSize) {
          throw ArgumentError('IV 长度必须等于 block size: $blockSize bytes。');
        }
        underlying = CBCBlockCipher(blockCipher);
        parameters = ParametersWithIV<KeyParameter>(
          KeyParameter(keyBytes),
          effectiveIv,
        );
        break;
      default:
        throw ArgumentError.value(mode, 'mode', '仅支持 cbc 或 ecb。');
    }

    final cipher = PaddedBlockCipherImpl(PKCS7Padding(), underlying);
    cipher.init(
      encrypt,
      PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
        parameters,
        null,
      ),
    );
    return cipher;
  }

  Uint8List _normalizeKey({
    required _CipherAlgorithm algorithm,
    required Uint8List keyBytes,
  }) {
    switch (algorithm) {
      case _CipherAlgorithm.aes:
        if (keyBytes.length == 16 ||
            keyBytes.length == 24 ||
            keyBytes.length == 32) {
          return keyBytes;
        }
        throw ArgumentError('AES key 长度必须为 16 / 24 / 32 bytes。');
      case _CipherAlgorithm.des:
        if (keyBytes.length != 8) {
          throw ArgumentError('DES key 长度必须为 8 bytes。');
        }
        return Uint8List.fromList(<int>[...keyBytes, ...keyBytes, ...keyBytes]);
      case _CipherAlgorithm.tripleDes:
        if (keyBytes.length == 16 || keyBytes.length == 24) {
          return keyBytes;
        }
        throw ArgumentError('3DES key 长度必须为 16 或 24 bytes。');
      case _CipherAlgorithm.rc4:
        return keyBytes;
    }
  }

  AsymmetricBlockCipher _buildRsaCipher(String padding) {
    switch (_normalizeRsaPaddingName(padding).toLowerCase()) {
      case 'pkcs1':
        return PKCS1Encoding(RSAEngine());
      case 'oaepsha1':
        return OAEPEncoding.withSHA1(RSAEngine());
      case 'oaepsha256':
        return OAEPEncoding.withSHA256(RSAEngine());
      case 'oaepsha512':
        return OAEPEncoding.withCustomDigest(() => SHA512Digest(), RSAEngine());
      default:
        throw ArgumentError.value(
          padding,
          'padding',
          '仅支持 PKCS1Padding / OAEP-SHA1 / OAEP-SHA256 / OAEP-SHA512。',
        );
    }
  }

  String _normalizeRsaPaddingName(String padding) {
    final normalized =
        padding.trim().replaceAll('-', '').replaceAll('/', '').toLowerCase();
    switch (normalized) {
      case 'pkcs1':
      case 'pkcs1padding':
        return 'pkcs1';
      case 'oaep':
      case 'oaepsha1':
      case 'oaepsha1padding':
        return 'oaepSha1';
      case 'oaepsha256':
      case 'oaepsha256padding':
        return 'oaepSha256';
      case 'oaepsha512':
      case 'oaepsha512padding':
        return 'oaepSha512';
      default:
        return padding;
    }
  }

  String _normalizeRsaSignAlgorithm(String algorithm) {
    final normalized = algorithm
        .trim()
        .replaceAll('_', '/')
        .replaceAll('-', '')
        .replaceAll('with', '/')
        .replaceAll('WITH', '/')
        .replaceAll('rsa', 'RSA')
        .replaceAll('pss', 'PSS');
    final upper = normalized.toUpperCase();
    switch (upper) {
      case 'MD5':
      case 'MD5/RSA':
      case 'MD5RSA':
        return 'MD5/RSA';
      case 'SHA1':
      case 'SHA-1':
      case 'SHA1/RSA':
      case 'SHA-1/RSA':
      case 'SHA1RSA':
        return 'SHA-1/RSA';
      case 'SHA256':
      case 'SHA-256':
      case 'SHA256/RSA':
      case 'SHA-256/RSA':
      case 'SHA256RSA':
        return 'SHA-256/RSA';
      case 'SHA512':
      case 'SHA-512':
      case 'SHA512/RSA':
      case 'SHA-512/RSA':
      case 'SHA512RSA':
        return 'SHA-512/RSA';
      case 'SHA1/PSS':
      case 'SHA-1/PSS':
      case 'SHA1PSS':
        return 'SHA-1/PSS';
      case 'SHA256/PSS':
      case 'SHA-256/PSS':
      case 'SHA256PSS':
        return 'SHA-256/PSS';
      case 'SHA512/PSS':
      case 'SHA-512/PSS':
      case 'SHA512PSS':
        return 'SHA-512/PSS';
      default:
        return algorithm;
    }
  }

  RSAPublicKey _parsePublicKey(String pem) {
    try {
      return CryptoUtils.rsaPublicKeyFromPem(pem);
    } catch (_) {
      return CryptoUtils.rsaPublicKeyFromPemPkcs1(pem);
    }
  }

  RSAPrivateKey _parsePrivateKey(String pem) {
    try {
      return CryptoUtils.rsaPrivateKeyFromPem(pem);
    } catch (_) {
      return CryptoUtils.rsaPrivateKeyFromPemPkcs1(pem);
    }
  }

  Uint8List _processAsymmetric(AsymmetricBlockCipher cipher, Uint8List input) {
    final output = BytesBuilder(copy: false);
    var offset = 0;
    while (offset < input.length) {
      final end = min(offset + cipher.inputBlockSize, input.length);
      output.add(cipher.process(input.sublist(offset, end)));
      offset = end;
    }
    return output.toBytes();
  }

  Uint8List _decodeBytes(String value, String encoding) {
    switch (encoding.trim().toLowerCase()) {
      case 'utf8':
      case 'utf-8':
      case 'string':
        return Uint8List.fromList(utf8.encode(value));
      case 'base64':
        return Uint8List.fromList(base64.decode(value));
      case 'hex':
        return Uint8List.fromList(_decodeHex(value));
      default:
        throw ArgumentError.value(
          encoding,
          'encoding',
          '仅支持 utf8 / string / base64 / hex。',
        );
    }
  }

  String _encodeBytes(Uint8List bytes, String encoding) {
    switch (encoding.trim().toLowerCase()) {
      case 'utf8':
      case 'utf-8':
      case 'string':
        return utf8.decode(bytes, allowMalformed: true);
      case 'base64':
        return base64.encode(bytes);
      case 'hex':
        return _encodeHex(bytes);
      default:
        throw ArgumentError.value(
          encoding,
          'encoding',
          '仅支持 utf8 / string / base64 / hex。',
        );
    }
  }

  String _encodeHex(List<int> bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  List<int> _decodeHex(String value) {
    final raw = value.trim();
    if (raw.isEmpty) {
      return const <int>[];
    }
    if (raw.length.isOdd) {
      throw const FormatException('hex 字符串长度必须为偶数。');
    }
    final bytes = <int>[];
    for (var index = 0; index < raw.length; index += 2) {
      bytes.add(int.parse(raw.substring(index, index + 2), radix: 16));
    }
    return bytes;
  }
}

enum _CipherAlgorithm { aes, des, tripleDes, rc4 }

class _SymmetricSpec {
  const _SymmetricSpec({required this.algorithm, this.mode});

  final _CipherAlgorithm algorithm;
  final String? mode;

  factory _SymmetricSpec.parse(String algorithm) {
    final raw = algorithm.trim();
    final normalized = raw.replaceAll('/', '-').replaceAll('_', '-');
    final parts = normalized
        .split('-')
        .where((String value) => value.trim().isNotEmpty)
        .map((String value) => value.trim())
        .toList(growable: false);
    if (parts.isEmpty) {
      throw ArgumentError.value(algorithm, 'algorithm', '算法描述不能为空。');
    }

    final algoName = parts.first.toLowerCase();
    if (algoName == 'rc4') {
      return const _SymmetricSpec(algorithm: _CipherAlgorithm.rc4);
    }

    final mode = parts.length >= 2 ? parts[1].toLowerCase() : 'cbc';
    final padding = parts.length >= 3 ? parts[2].toLowerCase() : 'pkcs5padding';
    if (padding != 'pkcs5padding' && padding != 'pkcs7padding') {
      throw ArgumentError.value(
        algorithm,
        'algorithm',
        '当前仅支持 PKCS5Padding / PKCS7Padding。',
      );
    }
    if (mode != 'cbc' && mode != 'ecb') {
      throw ArgumentError.value(algorithm, 'algorithm', '当前仅支持 CBC / ECB。');
    }

    switch (algoName) {
      case 'aes':
        return _SymmetricSpec(algorithm: _CipherAlgorithm.aes, mode: mode);
      case 'des':
        return _SymmetricSpec(algorithm: _CipherAlgorithm.des, mode: mode);
      case 'desede':
      case '3des':
      case 'tripledes':
        return _SymmetricSpec(
          algorithm: _CipherAlgorithm.tripleDes,
          mode: mode,
        );
      default:
        throw ArgumentError.value(
          algorithm,
          'algorithm',
          '当前仅支持 AES / DES / DESede / RC4。',
        );
    }
  }
}

class _AsymmetricSpec {
  const _AsymmetricSpec({required this.padding});

  final String padding;

  factory _AsymmetricSpec.parse(String algorithm) {
    final parts = algorithm
        .trim()
        .split('/')
        .where((String value) => value.trim().isNotEmpty)
        .map((String value) => value.trim())
        .toList(growable: false);
    if (parts.isEmpty || parts.first.toUpperCase() != 'RSA') {
      throw ArgumentError.value(algorithm, 'algorithm', '当前仅支持 RSA 非对称算法。');
    }
    final padding = parts.isNotEmpty ? parts.last : 'PKCS1Padding';
    return _AsymmetricSpec(padding: padding);
  }
}
