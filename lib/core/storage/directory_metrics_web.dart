class DirectoryMetrics {
  const DirectoryMetrics({required this.fileCount, required this.totalBytes});

  final int fileCount;
  final int totalBytes;
}

Future<DirectoryMetrics> inspectDirectoryPath(String? path) async {
  return const DirectoryMetrics(fileCount: 0, totalBytes: 0);
}

Future<void> deleteDirectoryContents(String? path) async {}
