import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_charset_detector_platform_interface/decoding_result.dart';
import 'package:flutter_charset_detector_platform_interface/flutter_charset_detector_platform_interface.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

class CharsetDetectorWeb extends CharsetDetectorPlatform {
  static void registerWith(Registrar registrar) {
    CharsetDetectorPlatform.instance = CharsetDetectorWeb();
  }

  @override
  Future<DecodingResult> autoDecode(Uint8List bytes) async {
    return DecodingResult.fromJson({
      'charset': 'utf-8',
      'string': utf8.decode(bytes, allowMalformed: true),
    });
  }

  @override
  Future<String> detect(Uint8List bytes) async => 'utf-8';
}
