import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../app/images/file_image_cache.dart';

class AppBackgroundService {
  Future<List<String>> loadBackgroundPaths() async {
    final directory = await _backgroundDirectory();
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
    final directory = await _backgroundDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final extension = _normalizeImageFileExtension(bytes, fileName);
    final targetPath = p.join(
      directory.path,
      'app_bg_${DateTime.now().millisecondsSinceEpoch}.$extension',
    );
    await File(targetPath).writeAsBytes(bytes, flush: true);
    await evictFileImagePath(targetPath);
    return targetPath;
  }

  Future<void> deleteBackground(String path) async {
    final normalized = path.trim();
    if (normalized.isEmpty) {
      return;
    }
    await evictFileImagePath(normalized);
    final file = File(normalized);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> _backgroundDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, 'backgrounds'));
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
