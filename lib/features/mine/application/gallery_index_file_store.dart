import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GalleryIndexFileStore {
  const GalleryIndexFileStore({
    required this.directoryName,
    required this.legacyPreferencesKey,
    this.indexFileName = 'index.json',
    Future<Directory> Function()? documentsDirectoryProvider,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final String directoryName;
  final String indexFileName;
  final String legacyPreferencesKey;
  final Future<Directory> Function() _documentsDirectoryProvider;

  Future<String?> loadRaw({required SharedPreferences preferences}) async {
    final indexFile = await _indexFile();
    if (await indexFile.exists()) {
      final raw = await indexFile.readAsString();
      return raw.trim().isEmpty ? null : raw;
    }

    final legacyRaw = preferences.getString(legacyPreferencesKey);
    if (legacyRaw == null || legacyRaw.trim().isEmpty) {
      return null;
    }
    await writeRaw(legacyRaw);
    await preferences.remove(legacyPreferencesKey);
    return legacyRaw;
  }

  Future<void> writeRaw(String raw) async {
    final indexFile = await _indexFile();
    await indexFile.writeAsString(raw, flush: true);
  }

  Future<void> delete() async {
    final indexFile = await _indexFile();
    if (await indexFile.exists()) {
      await indexFile.delete();
    }
  }

  Future<File> _indexFile() async {
    final documents = await _documentsDirectoryProvider();
    final root = Directory(p.join(documents.path, directoryName));
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return File(p.join(root.path, indexFileName));
  }
}
