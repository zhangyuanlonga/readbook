import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/storage/managed_asset_store.dart';
import 'package:shuxiang_reading_next/domain/entities/launch_image_gallery.dart';
import 'package:shuxiang_reading_next/domain/entities/managed_asset.dart';
import 'package:shuxiang_reading_next/features/mine/application/launch_image_gallery_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  group('LaunchImageGalleryService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    setUp(() async {
      final documentsDir = await Directory.systemTemp.createTemp(
        'launch_gallery_docs_',
      );
      final supportDir = await Directory.systemTemp.createTemp(
        'launch_gallery_support_',
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

    test('persists galleries and active gallery id', () async {
      final service = LaunchImageGalleryService(
        assetStore: await _createAssetStore(),
      );
      final gallery = LaunchImageGallery(
        id: 'launch_gallery_a',
        name: '品牌启动图',
        createdAt: DateTime.parse('2026-04-22T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-04-22T00:00:00.000Z'),
        imagePaths: const <String>[],
      );

      await service.saveGalleries(<LaunchImageGallery>[gallery]);
      await service.saveActiveGalleryId(gallery.id);

      final galleries = await service.loadGalleries();
      expect(
        galleries.map((item) => item.id),
        contains(defaultLaunchImageGalleryId),
      );
      final savedGallery = galleries.singleWhere(
        (item) => item.id == gallery.id,
      );
      expect(savedGallery.name, '品牌启动图');
      expect(await service.loadActiveGalleryId(), gallery.id);
      expect((await service.loadActiveGallery())?.id, gallery.id);
    });

    test(
      'persists custom galleries into index file instead of SharedPreferences',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final service = LaunchImageGalleryService(
          preferences: prefs,
          assetStore: await _createAssetStore(),
        );
        final gallery = LaunchImageGallery(
          id: 'launch_gallery_index',
          name: '索引启动图集',
          createdAt: DateTime.parse('2026-05-21T00:00:00.000Z'),
          updatedAt: DateTime.parse('2026-05-21T00:00:00.000Z'),
          imagePaths: const <String>[],
        );

        await service.saveGalleries(<LaunchImageGallery>[gallery]);

        expect(prefs.containsKey('launchImageGallery.galleries'), isFalse);
        final documentsDir = await _pathProviderDocumentsDir();
        final indexFile = File(
          '${documentsDir.path}/launch_image_galleries/index.json',
        );
        expect(await indexFile.exists(), isTrue);
        expect(
          await indexFile.readAsString(),
          contains('launch_gallery_index'),
        );
      },
    );

    test('migrates legacy SharedPreferences payload into index file', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'launchImageGallery.galleries',
        jsonEncode(<Map<String, dynamic>>[
          LaunchImageGallery(
            id: 'launch_gallery_legacy',
            name: '旧启动图集',
            createdAt: DateTime.parse('2026-05-21T00:00:00.000Z'),
            updatedAt: DateTime.parse('2026-05-21T00:00:00.000Z'),
            imagePaths: const <String>[],
          ).toJson(),
        ]),
      );
      final service = LaunchImageGalleryService(
        preferences: prefs,
        assetStore: await _createAssetStore(),
      );

      final galleries = await service.loadGalleries();

      expect(
        galleries.any((item) => item.id == 'launch_gallery_legacy'),
        isTrue,
      );
      expect(prefs.containsKey('launchImageGallery.galleries'), isFalse);
      final documentsDir = await _pathProviderDocumentsDir();
      final indexFile = File(
        '${documentsDir.path}/launch_image_galleries/index.json',
      );
      expect(await indexFile.exists(), isTrue);
    });

    test(
      'loadGalleryIndex resolves persisted preview path for gallery cards',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final assetStore = await _createAssetStore();
        final service = LaunchImageGalleryService(
          preferences: prefs,
          assetStore: assetStore,
        );
        final managedFile = await assetStore.persistBytes(
          type: ManagedAssetType.launchImageGalleryImage,
          scope: ManagedAssetScope.readerAppearance,
          bytes: const <int>[1, 2, 3],
          fileName: 'launch_preview.png',
          collectionId: 'launch_gallery_index_preview',
          targetNamePrefix: 'launch_preview',
        );

        await service.saveGalleries(<LaunchImageGallery>[
          LaunchImageGallery(
            id: 'launch_gallery_index_preview',
            name: '启动图预览图集',
            createdAt: DateTime.parse('2026-05-21T00:00:00.000Z'),
            updatedAt: DateTime.parse('2026-05-21T00:00:00.000Z'),
            imagePaths: <String>[managedFile.resolvedPath!],
          ),
        ]);

        final indexItems = await service.loadGalleryIndex();
        final customItem = indexItems.singleWhere(
          (item) => item.id == 'launch_gallery_index_preview',
        );

        expect(customItem.previewPath, managedFile.resolvedPath);
      },
    );

    test('loads built-in launch gallery by default', () async {
      final service = LaunchImageGalleryService(
        assetStore: await _createAssetStore(),
      );

      expect(await service.loadActiveGalleryId(), defaultLaunchImageGalleryId);
      expect(
        await service.loadActiveLaunchImagePath(),
        'assets/branding/selune_launch_scene.png',
      );
    });

    test('resolves first existing image path from active gallery', () async {
      final service = LaunchImageGalleryService(
        assetStore: await _createAssetStore(),
      );
      final tempDir = await Directory.systemTemp.createTemp(
        'launch_image_gallery_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final existingFile = File('${tempDir.path}/launch.png');
      await existingFile.writeAsBytes(const <int>[1, 2, 3], flush: true);

      final gallery = LaunchImageGallery(
        id: 'launch_gallery_b',
        name: '节日启动图',
        createdAt: DateTime.parse('2026-04-22T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-04-22T00:00:00.000Z'),
        imagePaths: <String>['${tempDir.path}/missing.png', existingFile.path],
      );

      await service.saveGalleries(<LaunchImageGallery>[gallery]);
      await service.saveActiveGalleryId(gallery.id);

      expect(await service.loadActiveLaunchImagePath(), existingFile.path);
    });

    test(
      'resolves first existing image path for a specific gallery id',
      () async {
        final service = LaunchImageGalleryService(
          assetStore: await _createAssetStore(),
        );
        final tempDir = await Directory.systemTemp.createTemp(
          'launch_image_gallery_theme_test_',
        );
        addTearDown(() => tempDir.delete(recursive: true));

        final existingFile = File('${tempDir.path}/launch_theme.png');
        await existingFile.writeAsBytes(const <int>[7, 8, 9], flush: true);

        final gallery = LaunchImageGallery(
          id: 'launch_gallery_theme',
          name: '主题启动图',
          createdAt: DateTime.parse('2026-04-22T00:00:00.000Z'),
          updatedAt: DateTime.parse('2026-04-22T00:00:00.000Z'),
          imagePaths: <String>[
            '${tempDir.path}/missing.png',
            existingFile.path,
          ],
        );

        await service.saveGalleries(<LaunchImageGallery>[gallery]);

        expect(
          await service.loadLaunchImagePathForGallery(gallery.id),
          existingFile.path,
        );
      },
    );

    test('updates startup snapshot when active gallery changes', () async {
      final service = LaunchImageGalleryService(
        assetStore: await _createAssetStore(),
      );
      final tempDir = await Directory.systemTemp.createTemp(
        'launch_image_snapshot_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final existingFile = File('${tempDir.path}/launch_snapshot.png');
      await existingFile.writeAsBytes(const <int>[5, 6, 7], flush: true);

      final gallery = LaunchImageGallery(
        id: 'launch_gallery_snapshot',
        name: '快照图集',
        createdAt: DateTime.parse('2026-05-12T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-05-12T00:00:00.000Z'),
        imagePaths: <String>[existingFile.path],
      );

      await service.saveGalleries(<LaunchImageGallery>[gallery]);
      await service.saveActiveGalleryId(gallery.id);

      final snapshot = await service.loadStartupSnapshot();
      expect(snapshot.galleryId, gallery.id);
      expect(snapshot.resolvedImagePath, existingFile.path);
    });

    test('clears startup snapshot when startup artwork is disabled', () async {
      final service = LaunchImageGalleryService(
        assetStore: await _createAssetStore(),
      );
      final tempDir = await Directory.systemTemp.createTemp(
        'launch_image_snapshot_disable_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final existingFile = File('${tempDir.path}/launch_disable.png');
      await existingFile.writeAsBytes(const <int>[9, 8, 7], flush: true);

      final gallery = LaunchImageGallery(
        id: 'launch_gallery_disable',
        name: '禁用图集',
        createdAt: DateTime.parse('2026-05-12T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-05-12T00:00:00.000Z'),
        imagePaths: <String>[existingFile.path],
      );

      await service.saveGalleries(<LaunchImageGallery>[gallery]);
      await service.saveActiveGalleryId(gallery.id);
      await service.saveStartupEnabled(false);

      final snapshot = await service.loadStartupSnapshot();
      expect(snapshot.galleryId, isNull);
      expect(snapshot.resolvedImagePath, isNull);
    });
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
  final documentsDir = await Directory.systemTemp.createTemp('launch_docs_');
  final supportDir = await Directory.systemTemp.createTemp('launch_support_');
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
