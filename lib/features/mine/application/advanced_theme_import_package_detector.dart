import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

enum AdvancedThemeImportPackageKind { official, red, rgshare }

class AdvancedThemeImportPackageDetector {
  const AdvancedThemeImportPackageDetector();

  Future<AdvancedThemeImportPackageKind> detect({
    required String path,
    String? mimeType,
    List<int>? bytes,
  }) async {
    final normalizedMime = mimeType?.trim().toLowerCase() ?? '';
    final normalizedExtension = p.extension(path).trim().toLowerCase();
    if (normalizedExtension == '.rgshare') {
      return AdvancedThemeImportPackageKind.rgshare;
    }
    if (normalizedMime.contains('octet-stream') &&
        normalizedExtension == '.red') {
      return AdvancedThemeImportPackageKind.red;
    }
    if (normalizedExtension == '.red') {
      return AdvancedThemeImportPackageKind.red;
    }
    final resolvedBytes = bytes ?? await File(path).readAsBytes();
    final sniffedKind = detectFromBytes(resolvedBytes);
    return sniffedKind ?? AdvancedThemeImportPackageKind.official;
  }

  AdvancedThemeImportPackageKind? detectFromBytes(List<int> bytes) {
    if (hasRedHeader(bytes)) {
      return AdvancedThemeImportPackageKind.red;
    }
    if (!looksLikeZip(bytes)) {
      return null;
    }

    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      if (archive.findFile('manifest.json') != null) {
        return AdvancedThemeImportPackageKind.official;
      }
      final themeFile = archive.findFile('theme.json');
      if (themeFile == null) {
        return AdvancedThemeImportPackageKind.official;
      }
      final decoded = jsonDecode(
        utf8.decode(archiveFileBytes(themeFile), allowMalformed: true),
      );
      if (decoded is! Map) {
        return AdvancedThemeImportPackageKind.official;
      }
      final payload = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      if (_looksLikeRgShareTheme(payload)) {
        return AdvancedThemeImportPackageKind.rgshare;
      }
      if (_looksLikeRedTheme(payload)) {
        return AdvancedThemeImportPackageKind.red;
      }
    } catch (_) {
      return null;
    }
    return AdvancedThemeImportPackageKind.official;
  }

  bool isZipThemeFile({
    required String path,
    String? mimeType,
    List<int>? bytes,
  }) {
    final normalizedMime = mimeType?.trim().toLowerCase() ?? '';
    if (normalizedMime.contains('zip')) {
      return true;
    }
    if (p.extension(path).trim().toLowerCase() == '.zip') {
      return true;
    }
    return bytes != null && looksLikeZip(bytes);
  }

  bool hasRedHeader(List<int> bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x45 &&
        bytes[2] == 0x44;
  }

  bool looksLikeZip(List<int> bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
  }

  static List<int> archiveFileBytes(ArchiveFile file) {
    return List<int>.from(file.content);
  }

  bool _looksLikeRgShareTheme(Map<String, dynamic> payload) {
    return payload.containsKey('1') &&
        payload.containsKey('2') &&
        payload.containsKey('4');
  }

  bool _looksLikeRedTheme(Map<String, dynamic> payload) {
    return payload['light'] is Map && payload['dark'] is Map;
  }
}
