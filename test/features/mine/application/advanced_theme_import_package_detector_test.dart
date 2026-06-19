import 'dart:convert';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_import_package_detector.dart';

void main() {
  const detector = AdvancedThemeImportPackageDetector();

  group('AdvancedThemeImportPackageDetector', () {
    test('uses file extensions before reading package bytes', () async {
      await expectLater(
        detector.detect(path: '/tmp/theme.red', bytes: const <int>[]),
        completion(AdvancedThemeImportPackageKind.red),
      );
      await expectLater(
        detector.detect(path: '/tmp/theme.rgshare', bytes: const <int>[]),
        completion(AdvancedThemeImportPackageKind.rgshare),
      );
    });

    test('detects red package from RED header', () {
      expect(
        detector.detectFromBytes(const <int>[0x52, 0x45, 0x44, 0x04]),
        AdvancedThemeImportPackageKind.red,
      );
    });

    test('detects official package when manifest exists', () {
      expect(
        detector.detectFromBytes(
          _buildZipPackageBytes(<String, List<int>>{
            'manifest.json': utf8.encode('{"type":"advanced_theme_bundle"}'),
          }),
        ),
        AdvancedThemeImportPackageKind.official,
      );
    });

    test('detects rgshare package from theme payload shape', () {
      expect(
        detector.detectFromBytes(
          _buildZipPackageBytes(<String, List<int>>{
            'theme.json': utf8.encode('{"1":"主题","2":{},"4":{}}'),
          }),
        ),
        AdvancedThemeImportPackageKind.rgshare,
      );
    });

    test('detects red package from theme payload shape', () {
      expect(
        detector.detectFromBytes(
          _buildZipPackageBytes(<String, List<int>>{
            'theme.json': utf8.encode('{"light":{},"dark":{}}'),
          }),
        ),
        AdvancedThemeImportPackageKind.red,
      );
    });

    test('recognizes zip theme by mime, extension, or bytes', () {
      final bytes = _buildZipPackageBytes(<String, List<int>>{
        'manifest.json': utf8.encode('{}'),
      });

      expect(
        detector.isZipThemeFile(
          path: '/tmp/theme.bin',
          mimeType: 'application/zip',
        ),
        isTrue,
      );
      expect(detector.isZipThemeFile(path: '/tmp/theme.zip'), isTrue);
      expect(
        detector.isZipThemeFile(path: '/tmp/theme.bin', bytes: bytes),
        isTrue,
      );
      expect(
        detector.isZipThemeFile(path: '/tmp/theme.bin', bytes: const <int>[]),
        isFalse,
      );
    });
  });
}

List<int> _buildZipPackageBytes(Map<String, List<int>> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return ZipEncoder().encode(archive);
}
