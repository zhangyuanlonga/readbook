import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/storage/managed_asset_store.dart';
import 'package:shuxiang_reading_next/domain/entities/cover_gallery.dart';
import 'package:shuxiang_reading_next/domain/entities/managed_asset.dart';
import 'package:shuxiang_reading_next/features/mine/application/cover_gallery_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  group('CoverGalleryService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    setUp(() async {
      final documentsDir = await Directory.systemTemp.createTemp(
        'cover_gallery_docs_',
      );
      final supportDir = await Directory.systemTemp.createTemp(
        'cover_gallery_support_',
      );
      _latestPathProviderDocumentsDir = documentsDir;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, (call) async {
            if (call.method == 'getApplicationDocumentsDirectory') {
              return documentsDir.path;
            }
            if (call.method == 'getApplicationSupportDirectory') {
              return supportDir.path;
            }
            return null;
          });
      addTearDown(() async {
        _latestPathProviderDocumentsDir = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(pathProviderChannel, null);
        if (documentsDir.existsSync()) {
          await documentsDir.delete(recursive: true);
        }
        if (supportDir.existsSync()) {
          await supportDir.delete(recursive: true);
        }
      });
    });

    test(
      'persists galleries into index file instead of SharedPreferences',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final service = CoverGalleryService(
          preferences: prefs,
          assetStore: await _createAssetStore(),
        );
        final gallery = CoverGallery(
          id: 'cover_gallery_a',
          name: '封面图集A',
          createdAt: DateTime.parse('2026-05-21T00:00:00.000Z'),
          updatedAt: DateTime.parse('2026-05-21T00:00:00.000Z'),
          imagePaths: const <String>[],
        );

        await service.saveGalleries(<CoverGallery>[gallery]);

        expect(prefs.containsKey('coverGallery.galleries'), isFalse);
        final documentsDir = await _pathProviderDocumentsDir();
        final indexFile = File(
          '${documentsDir.path}/cover_galleries/index.json',
        );
        expect(await indexFile.exists(), isTrue);
        expect(await indexFile.readAsString(), contains('cover_gallery_a'));
      },
    );

    test('migrates legacy SharedPreferences payload into index file', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'coverGallery.galleries',
        jsonEncode(<Map<String, dynamic>>[
          CoverGallery(
            id: 'cover_gallery_legacy',
            name: '旧封面图集',
            createdAt: DateTime.parse('2026-05-21T00:00:00.000Z'),
            updatedAt: DateTime.parse('2026-05-21T00:00:00.000Z'),
            imagePaths: const <String>[],
          ).toJson(),
        ]),
      );
      final service = CoverGalleryService(
        preferences: prefs,
        assetStore: await _createAssetStore(),
      );

      final galleries = await service.loadGalleries();

      expect(galleries, hasLength(1));
      expect(galleries.first.id, 'cover_gallery_legacy');
      expect(prefs.containsKey('coverGallery.galleries'), isFalse);
      final documentsDir = await _pathProviderDocumentsDir();
      final indexFile = File('${documentsDir.path}/cover_galleries/index.json');
      expect(await indexFile.exists(), isTrue);
    });

    test(
      'loadGalleryIndex resolves persisted preview path for gallery cards',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final assetStore = await _createAssetStore();
        final service = CoverGalleryService(
          preferences: prefs,
          assetStore: assetStore,
        );
        final managedFile = await assetStore.persistBytes(
          type: ManagedAssetType.coverGalleryImage,
          scope: ManagedAssetScope.themeBinding,
          bytes: const <int>[1, 2, 3],
          fileName: 'preview.png',
          collectionId: 'cover_gallery_index_preview',
          targetNamePrefix: 'preview',
        );

        await service.saveGalleries(<CoverGallery>[
          CoverGallery(
            id: 'cover_gallery_index_preview',
            name: '封面预览图集',
            createdAt: DateTime.parse('2026-05-21T00:00:00.000Z'),
            updatedAt: DateTime.parse('2026-05-21T00:00:00.000Z'),
            imagePaths: <String>[managedFile.resolvedPath!],
          ),
        ]);

        final indexItems = await service.loadGalleryIndex();

        expect(indexItems, hasLength(1));
        expect(indexItems.first.previewPath, managedFile.resolvedPath);
      },
    );
  });
}

Directory? _latestPathProviderDocumentsDir;

Future<Directory> _pathProviderDocumentsDir() async {
  final directory = _latestPathProviderDocumentsDir;
  if (directory == null) {
    throw StateError('Missing path provider documents test directory.');
  }
  return directory;
}

Future<ManagedAssetStore> _createAssetStore() async {
  final documentsDir = await Directory.systemTemp.createTemp('cover_docs_');
  final supportDir = await Directory.systemTemp.createTemp('cover_support_');
  addTearDown(() async {
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
    if (supportDir.existsSync()) {
      await supportDir.delete(recursive: true);
    }
  });
  return ManagedAssetStore(
    documentsDirectoryProvider: () async => documentsDir,
    supportDirectoryProvider: () async => supportDir,
  );
}
