import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/storage/managed_asset_store.dart';
import 'package:shuxiang_reading_next/domain/entities/managed_asset.dart';

void main() {
  late Directory documentsDir;
  late Directory supportDir;
  late ManagedAssetStore store;

  setUp(() async {
    documentsDir = await Directory.systemTemp.createTemp('managed_docs_');
    supportDir = await Directory.systemTemp.createTemp('managed_support_');
    store = ManagedAssetStore(
      documentsDirectoryProvider: () async => documentsDir,
      supportDirectoryProvider: () async => supportDir,
    );
  });

  tearDown(() async {
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
    if (supportDir.existsSync()) {
      await supportDir.delete(recursive: true);
    }
  });

  test('persists managed asset and resolves relative path', () async {
    final ref = await store.persistBytes(
      type: ManagedAssetType.coverGalleryImage,
      scope: ManagedAssetScope.themeBinding,
      bytes: const <int>[1, 2, 3],
      fileName: 'cover.png',
      collectionId: 'gallery_a',
      targetNamePrefix: 'cover',
    );

    expect(ref.relativePath, startsWith('cover_galleries/gallery_a/cover_'));
    expect(ref.resolvedPath, isNotNull);
    expect(await File(ref.resolvedPath!).exists(), isTrue);
    expect(
      _normalizePath(await store.resolvePersistedPath(ref.relativePath)),
      _normalizePath(ref.resolvedPath),
    );
  });

  test('relativizes legacy absolute path inside managed directory', () async {
    final file = File('${documentsDir.path}/launch_image_galleries/demo/a.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(const <int>[7, 8, 9], flush: true);

    final relative = await store.relativizePersistedPath(file.path);

    expect(relative, 'launch_image_galleries/demo/a.png');
    expect(
      _normalizePath(await store.resolvePersistedPath(relative)),
      _normalizePath(file.path),
    );
  });
}

String? _normalizePath(String? value) {
  return value?.replaceAll('\\', '/');
}
