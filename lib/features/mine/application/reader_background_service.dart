import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import '../../../app/images/file_image_cache.dart';
import '../../../core/storage/managed_asset_store.dart';
import '../../../domain/entities/managed_asset.dart';

class ReaderBackgroundService {
  ReaderBackgroundService({ManagedAssetStore? assetStore})
    : _assetStore = assetStore ?? ManagedAssetStore();

  final ManagedAssetStore _assetStore;

  Future<List<String>> loadBackgroundPaths() async {
    final directory = await _assetStore.resolveDirectory(
      ManagedAssetType.readerBackground,
    );
    if (!await directory.exists()) {
      return const <String>[];
    }

    final paths = directory
        .listSync()
        .whereType<File>()
        .where(
          (file) => switch (p.extension(file.path).toLowerCase()) {
            '.jpg' || '.jpeg' || '.png' || '.webp' || '.gif' => true,
            _ => false,
          },
        )
        .map((file) => file.path)
        .toList(growable: false);
    final sorted = [...paths]..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  Future<String> importBackground({
    required List<int> bytes,
    required String fileName,
  }) async {
    final existingPath = await _findExistingDuplicate(bytes);
    if (existingPath != null) {
      return existingPath;
    }
    final extension = _normalizeImageFileExtension(bytes, fileName);
    final asset = await _assetStore.persistBytes(
      type: ManagedAssetType.readerBackground,
      scope: ManagedAssetScope.readerAppearance,
      bytes: bytes,
      fileName: 'reader_bg.$extension',
      targetNamePrefix: 'reader_bg',
    );
    final targetPath = asset.resolvedPath!;
    await evictFileImagePath(targetPath);
    return targetPath;
  }

  Future<String?> _findExistingDuplicate(List<int> bytes) async {
    final targetHash = crypto.sha256.convert(bytes).toString();
    final candidatePaths = await _assetStore.listResolvedFilePaths(
      ManagedAssetType.readerBackground,
    );
    for (final path in candidatePaths) {
      final file = File(path);
      if (!await file.exists()) {
        continue;
      }
      if (await file.length() != bytes.length) {
        continue;
      }
      final existingHash = crypto.sha256.convert(await file.readAsBytes());
      if (existingHash.toString() == targetHash) {
        return file.path;
      }
    }
    return null;
  }

  Future<void> deleteBackground(String path) async {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      return;
    }
    await evictFileImagePath(normalized);
    await _assetStore.deletePath(normalized);
  }

  String _normalizeFileExtension(String fileName) {
    final extension = p.extension(fileName).replaceFirst('.', '').trim();
    if (extension.isEmpty) {
      return 'png';
    }
    return extension.toLowerCase();
  }

  String _normalizeImageFileExtension(List<int> bytes, String fileName) {
    final detected = _detectImageExtension(bytes);
    if (detected != null) {
      return detected;
    }
    final normalized = _normalizeFileExtension(fileName);
    return switch (normalized) {
      'img' => 'png',
      _ => normalized,
    };
  }

  String? _detectImageExtension(List<int> bytes) {
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'jpg';
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38 &&
        (bytes[4] == 0x37 || bytes[4] == 0x39) &&
        bytes[5] == 0x61) {
      return 'gif';
    }
    return null;
  }
}
