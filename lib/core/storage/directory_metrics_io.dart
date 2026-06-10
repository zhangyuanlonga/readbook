import 'dart:io';

class DirectoryMetrics {
  const DirectoryMetrics({required this.fileCount, required this.totalBytes});

  final int fileCount;
  final int totalBytes;
}

Future<DirectoryMetrics> inspectDirectoryPath(String? path) async {
  final normalized = path?.trim() ?? '';
  if (normalized.isEmpty) {
    return const DirectoryMetrics(fileCount: 0, totalBytes: 0);
  }
  final directory = Directory(normalized);
  if (!await directory.exists()) {
    return const DirectoryMetrics(fileCount: 0, totalBytes: 0);
  }

  var fileCount = 0;
  var totalBytes = 0;
  await for (final entity in directory.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) {
      continue;
    }
    fileCount += 1;
    try {
      totalBytes += await entity.length();
    } catch (_) {
      // Ignore a single unreadable file.
    }
  }
  return DirectoryMetrics(fileCount: fileCount, totalBytes: totalBytes);
}

Future<void> deleteDirectoryContents(String? path) async {
  final normalized = path?.trim() ?? '';
  if (normalized.isEmpty) {
    return;
  }
  final directory = Directory(normalized);
  if (!await directory.exists()) {
    return;
  }
  await for (final entity in directory.list(followLinks: false)) {
    try {
      await entity.delete(recursive: true);
    } catch (_) {
      // Best-effort cleanup.
    }
  }
}
