import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/storage/managed_asset_store.dart';
import 'package:shuxiang_reading_next/features/mine/application/app_background_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/reader_background_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('app background import reuses existing identical image', () async {
    final assetStore = await _createAssetStore();
    final service = AppBackgroundService(assetStore: assetStore);
    const bytes = <int>[0x89, 0x50, 0x4E, 0x47, 0x01];

    final firstPath = await service.importBackground(
      bytes: bytes,
      fileName: 'first.png',
    );
    final secondPath = await service.importBackground(
      bytes: bytes,
      fileName: 'second.png',
    );
    final files = await service.loadBackgroundPaths();

    expect(secondPath, firstPath);
    expect(files, hasLength(1));
  });

  test('reader background import reuses existing identical image', () async {
    final assetStore = await _createAssetStore();
    final service = ReaderBackgroundService(assetStore: assetStore);
    const bytes = <int>[0x89, 0x50, 0x4E, 0x47, 0x02];

    final firstPath = await service.importBackground(
      bytes: bytes,
      fileName: 'first.png',
    );
    final secondPath = await service.importBackground(
      bytes: bytes,
      fileName: 'second.png',
    );
    final files = await service.loadBackgroundPaths();

    expect(secondPath, firstPath);
    expect(files, hasLength(1));
  });
}

Future<ManagedAssetStore> _createAssetStore() async {
  final documentsDir = await Directory.systemTemp.createTemp('bg_docs_');
  final supportDir = await Directory.systemTemp.createTemp('bg_support_');
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
