import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../app/images/file_image_cache.dart';
import '../../../core/media/image_selection_service.dart';
import '../../../core/storage/managed_asset_store.dart';
import '../../../domain/entities/managed_asset.dart';

class CustomCoverStorageService {
  CustomCoverStorageService({ManagedAssetStore? assetStore})
    : _assetStore = assetStore ?? ManagedAssetStore();

  final ManagedAssetStore _assetStore;

  Future<String?> persistForBook({
    required String sourceId,
    required String detailUrl,
    required PickedImageData picked,
  }) async {
    final bytes = picked.bytes;
    if (bytes.isEmpty) {
      return null;
    }

    final normalizedSourceId = sourceId.trim();
    final normalizedDetailUrl = detailUrl.trim();
    if (normalizedSourceId.isEmpty || normalizedDetailUrl.isEmpty) {
      return null;
    }

    final coverDir = await _assetStore.resolveDirectory(
      ManagedAssetType.customBookCover,
    );
    if (!await coverDir.exists()) {
      await coverDir.create(recursive: true);
    }

    final bookKey = '$normalizedSourceId::$normalizedDetailUrl'.replaceAll(
      RegExp(r'[^a-zA-Z0-9]+'),
      '_',
    );
    final sourceExtension = p.extension(picked.name).toLowerCase();
    final extension =
        const [
              '.jpg',
              '.jpeg',
              '.png',
              '.webp',
              '.gif',
            ].contains(sourceExtension)
            ? sourceExtension
            : '.jpg';

    await for (final entity in coverDir.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final name = p.basename(entity.path);
      if (!name.startsWith('${bookKey}_')) {
        continue;
      }
      try {
        await entity.delete();
      } catch (_) {
        // Ignore stale cleanup failure.
      }
    }

    final asset = await _assetStore.persistBytes(
      type: ManagedAssetType.customBookCover,
      scope: ManagedAssetScope.bookshelfBook,
      bytes: bytes,
      fileName: '$bookKey$extension',
      assetId: bookKey,
      targetNamePrefix: bookKey,
    );
    await evictFileImagePath(asset.resolvedPath);
    return asset.relativePath;
  }
}
