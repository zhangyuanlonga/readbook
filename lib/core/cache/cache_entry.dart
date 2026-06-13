import 'cache_key.dart';

class AppCacheEntry {
  const AppCacheEntry({
    required this.key,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
    required this.lastAccessedAt,
    this.expiresAt,
    this.version = 1,
    this.sizeBytes,
    this.metadata = const <String, Object?>{},
  });

  final AppCacheKey key;
  final Object? payload;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastAccessedAt;
  final DateTime? expiresAt;
  final int version;
  final int? sizeBytes;
  final Map<String, Object?> metadata;

  bool isExpired(DateTime now) {
    final expiresAt = this.expiresAt;
    return expiresAt != null && !expiresAt.isAfter(now);
  }

  bool hasVersion(int expectedVersion) => version == expectedVersion;

  AppCacheEntry copyWith({
    AppCacheKey? key,
    Object? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastAccessedAt,
    DateTime? expiresAt,
    int? version,
    int? sizeBytes,
    Map<String, Object?>? metadata,
  }) {
    return AppCacheEntry(
      key: key ?? this.key,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      version: version ?? this.version,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      metadata: metadata ?? this.metadata,
    );
  }
}
