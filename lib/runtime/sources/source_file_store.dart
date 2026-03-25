import 'dart:io';

import 'package:path_provider/path_provider.dart';

class StoredSourceFile {
  const StoredSourceFile({
    required this.fileName,
    required this.filePath,
    required this.lastModified,
  });

  final String fileName;
  final String filePath;
  final DateTime lastModified;

  String get displayName => fileName.replaceAll('.js', '');
}

class SourceFileStore {
  SourceFileStore({Directory? baseDirectory})
    : _customBaseDirectory = baseDirectory;

  final Directory? _customBaseDirectory;

  Future<Directory> resolveSourcesDirectory() async {
    final customBaseDirectory = _customBaseDirectory;
    if (customBaseDirectory != null) {
      return _ensureDirectory(customBaseDirectory);
    }

    final appSupport = await getApplicationSupportDirectory();
    final directory = Directory('${appSupport.path}/novel_sources');
    return _ensureDirectory(directory);
  }

  Future<List<StoredSourceFile>> listSourceFiles() async {
    final directory = await resolveSourcesDirectory();
    final files = directory
        .listSync()
        .whereType<File>()
        .where((File file) => file.path.toLowerCase().endsWith('.js'))
        .toList(growable: false)
      ..sort((File a, File b) => a.path.compareTo(b.path));

    return Future.wait(
      files.map((File file) async {
        final stat = await file.stat();
        return StoredSourceFile(
          fileName: file.uri.pathSegments.last,
          filePath: file.path,
          lastModified: stat.modified,
        );
      }),
    );
  }

  Future<String> readSource(String filePath) {
    return File(filePath).readAsString();
  }

  Future<StoredSourceFile> saveSource({
    required String suggestedName,
    required String contents,
  }) async {
    final directory = await resolveSourcesDirectory();
    final slug = _slugify(suggestedName);
    final file = await _nextAvailableFile(directory, slug);
    await file.writeAsString(contents);
    final stat = await file.stat();

    return StoredSourceFile(
      fileName: file.uri.pathSegments.last,
      filePath: file.path,
      lastModified: stat.modified,
    );
  }

  Future<void> overwriteSource({
    required StoredSourceFile sourceFile,
    required String contents,
  }) {
    return File(sourceFile.filePath).writeAsString(contents);
  }

  Future<void> deleteSource(String filePath) {
    return File(filePath).delete();
  }

  Future<Directory> _ensureDirectory(Directory directory) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File> _nextAvailableFile(Directory directory, String slug) async {
    var candidate = File('${directory.path}/$slug.js');
    if (!await candidate.exists()) {
      return candidate;
    }

    var index = 2;
    while (true) {
      candidate = File('${directory.path}/$slug-$index.js');
      if (!await candidate.exists()) {
        return candidate;
      }
      index += 1;
    }
  }

  String _slugify(String input) {
    final normalized = input.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '-',
    );
    final trimmed = normalized.replaceAll(RegExp(r'^-+|-+$'), '');
    return trimmed.isEmpty ? 'source' : trimmed;
  }
}
