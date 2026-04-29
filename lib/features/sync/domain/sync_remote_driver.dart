class SyncRemoteFileStat {
  const SyncRemoteFileStat({
    required this.path,
    this.revision,
    this.contentLength,
    this.updatedAt,
  });

  final String path;
  final String? revision;
  final int? contentLength;
  final DateTime? updatedAt;
}

abstract class SyncRemoteDriver {
  Future<void> ensureReady();

  Future<SyncRemoteFileStat?> stat(String path);

  Future<String?> readText(String path);

  Future<void> writeText(
    String path,
    String content, {
    String? ifMatchRevision,
  });

  Future<void> ensureDirectory(String path);
}
