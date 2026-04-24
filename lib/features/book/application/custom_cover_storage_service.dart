import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/media/image_selection_service.dart';

class CustomCoverStorageService {
  const CustomCoverStorageService();

  Future<Uri?> persistForBook({
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

    final baseDir = await getApplicationSupportDirectory();
    final coverDir = Directory(
      p.join(baseDir.path, 'shuxiang_reading_next', 'custom_covers'),
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

    final targetFile = File(
      p.join(
        coverDir.path,
        '${bookKey}_${DateTime.now().millisecondsSinceEpoch}$extension',
      ),
    );
    await targetFile.writeAsBytes(bytes, flush: true);
    return targetFile.uri;
  }
}
