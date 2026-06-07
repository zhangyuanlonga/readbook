import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/features/mine/application/gallery_index_file_store.dart';

void main() {
  group('GalleryIndexFileStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('loads existing index file before legacy preferences', () async {
      final documentsDir = await Directory.systemTemp.createTemp(
        'gallery_index_store_docs_',
      );
      addTearDown(() async {
        if (documentsDir.existsSync()) {
          await documentsDir.delete(recursive: true);
        }
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('legacy.key', 'legacy');
      final store = GalleryIndexFileStore(
        directoryName: 'gallery_index',
        legacyPreferencesKey: 'legacy.key',
        documentsDirectoryProvider: () async => documentsDir,
      );

      await store.writeRaw('file');

      expect(await store.loadRaw(preferences: prefs), 'file');
      expect(prefs.getString('legacy.key'), 'legacy');
    });

    test('migrates legacy preferences payload into index file', () async {
      final documentsDir = await Directory.systemTemp.createTemp(
        'gallery_index_store_legacy_',
      );
      addTearDown(() async {
        if (documentsDir.existsSync()) {
          await documentsDir.delete(recursive: true);
        }
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('legacy.key', 'legacy payload');
      final store = GalleryIndexFileStore(
        directoryName: 'gallery_index',
        legacyPreferencesKey: 'legacy.key',
        documentsDirectoryProvider: () async => documentsDir,
      );

      expect(await store.loadRaw(preferences: prefs), 'legacy payload');

      final indexFile = File('${documentsDir.path}/gallery_index/index.json');
      expect(await indexFile.readAsString(), 'legacy payload');
      expect(prefs.containsKey('legacy.key'), isFalse);
    });

    test('delete removes index file', () async {
      final documentsDir = await Directory.systemTemp.createTemp(
        'gallery_index_store_delete_',
      );
      addTearDown(() async {
        if (documentsDir.existsSync()) {
          await documentsDir.delete(recursive: true);
        }
      });
      final store = GalleryIndexFileStore(
        directoryName: 'gallery_index',
        legacyPreferencesKey: 'legacy.key',
        documentsDirectoryProvider: () async => documentsDir,
      );

      await store.writeRaw('payload');
      await store.delete();

      final indexFile = File('${documentsDir.path}/gallery_index/index.json');
      expect(await indexFile.exists(), isFalse);
    });
  });
}
