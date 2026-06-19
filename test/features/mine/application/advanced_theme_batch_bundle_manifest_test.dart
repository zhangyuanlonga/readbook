import 'dart:convert';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_batch_bundle_manifest.dart';

void main() {
  group('AdvancedThemeBatchBundleManifest', () {
    test('encodes and parses batch bundle entries', () {
      final manifestBytes = AdvancedThemeBatchBundleManifest.encode(
        generatedAt: DateTime.parse('2026-06-19T10:30:00.000Z'),
        themes: const <AdvancedThemeBatchBundleEntry>[
          AdvancedThemeBatchBundleEntry(
            id: 'theme_1',
            name: '清晨主题',
            file: 'themes/001.zip',
          ),
        ],
      );
      final archive = _buildArchive(<String, List<int>>{
        AdvancedThemeBatchBundleManifest.manifestFileName: manifestBytes,
      });

      expect(
        AdvancedThemeBatchBundleManifest.isBatchBundleArchive(archive),
        isTrue,
      );
      final parsed = AdvancedThemeBatchBundleManifest.parseArchive(archive);

      expect(parsed.themes, hasLength(1));
      expect(parsed.themes.single.id, 'theme_1');
      expect(parsed.themes.single.name, '清晨主题');
      expect(parsed.themes.single.file, 'themes/001.zip');
    });

    test('rejects unsupported version with stable message', () {
      final archive = _buildArchive(<String, List<int>>{
        AdvancedThemeBatchBundleManifest.manifestFileName: utf8.encode(
          '{"type":"advanced_theme_batch_bundle","version":999,"themes":[]}',
        ),
      });

      expect(
        () => AdvancedThemeBatchBundleManifest.parseArchive(archive),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            '不支持的批量主题包版本。',
          ),
        ),
      );
    });

    test('ignores non-batch archives in sniffing path', () {
      final archive = _buildArchive(<String, List<int>>{
        AdvancedThemeBatchBundleManifest.manifestFileName: utf8.encode(
          '{"type":"advanced_theme_bundle","version":1}',
        ),
      });

      expect(
        AdvancedThemeBatchBundleManifest.isBatchBundleArchive(archive),
        isFalse,
      );
    });
  });
}

Archive _buildArchive(Map<String, List<int>> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return archive;
}
