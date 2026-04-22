import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../app/images/file_image_cache.dart';

class ReaderBackgroundService {
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

    final extension = _normalizeFileExtension(fileName);
    final targetPath = p.join(
      directory.path,
      'reader_bg_${DateTime.now().millisecondsSinceEpoch}.$extension',
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
    return Directory(p.join(documents.path, 'reader_backgrounds'));
  }

  String _normalizeFileExtension(String fileName) {
    final extension = p.extension(fileName).replaceFirst('.', '').trim();
    if (extension.isEmpty) {
      return 'png';
    }
    return extension.toLowerCase();
  }
}
