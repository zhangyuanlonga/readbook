import 'cache_scope.dart';

class AppCachePolicy {
  const AppCachePolicy({
    this.ttl,
    this.maxEntries,
    this.maxBytes,
    this.userScoped = false,
    this.rebuildable = true,
    this.deletable = true,
    this.version = 1,
  });

  final Duration? ttl;
  final int? maxEntries;
  final int? maxBytes;
  final bool userScoped;
  final bool rebuildable;
  final bool deletable;
  final int version;

  DateTime? expiresAtFor(DateTime createdAt) {
    final ttl = this.ttl;
    if (ttl == null) {
      return null;
    }
    return createdAt.add(ttl);
  }

  bool isExpired(DateTime now, {required DateTime createdAt}) {
    final expiresAt = expiresAtFor(createdAt);
    return expiresAt != null && !expiresAt.isAfter(now);
  }
}

abstract final class AppCachePolicies {
  static const chapterContent = AppCachePolicy(
    ttl: Duration(days: 45),
    maxEntries: 3000,
    maxBytes: 96 * 1024 * 1024,
    userScoped: true,
  );

  static const paginationLayout = AppCachePolicy(
    ttl: Duration(days: 30),
    maxEntries: 1200,
    maxBytes: 24 * 1024 * 1024,
    userScoped: true,
  );

  static const coverImage = AppCachePolicy(
    ttl: Duration(days: 30),
    maxEntries: 300,
    maxBytes: 48 * 1024 * 1024,
  );

  static const readerImage = AppCachePolicy(
    ttl: Duration(days: 30),
    maxEntries: 1200,
    maxBytes: 128 * 1024 * 1024,
  );

  static const apiResponse = AppCachePolicy(
    ttl: Duration(minutes: 5),
    maxEntries: 256,
    maxBytes: 8 * 1024 * 1024,
    userScoped: true,
  );

  static const searchHit = AppCachePolicy(
    ttl: Duration(days: 7),
    maxEntries: 3000,
    maxBytes: 24 * 1024 * 1024,
    userScoped: true,
  );

  static const sourceHealth = AppCachePolicy(
    ttl: Duration(hours: 12),
    maxEntries: 3000,
    maxBytes: 12 * 1024 * 1024,
  );

  static const themePreview = AppCachePolicy(
    ttl: Duration(days: 30),
    maxEntries: 600,
    maxBytes: 96 * 1024 * 1024,
  );

  static const localBookIndex = AppCachePolicy(
    maxEntries: 2000,
    maxBytes: 256 * 1024 * 1024,
  );

  static const readerPreference = AppCachePolicy(
    maxEntries: 200,
    maxBytes: 2 * 1024 * 1024,
    userScoped: true,
    rebuildable: false,
    deletable: false,
  );

  static const Map<AppCacheScope, AppCachePolicy> defaults = {
    AppCacheScope.chapterContent: chapterContent,
    AppCacheScope.paginationLayout: paginationLayout,
    AppCacheScope.coverImage: coverImage,
    AppCacheScope.readerImage: readerImage,
    AppCacheScope.apiResponse: apiResponse,
    AppCacheScope.searchHit: searchHit,
    AppCacheScope.sourceHealth: sourceHealth,
    AppCacheScope.themePreview: themePreview,
    AppCacheScope.localBookIndex: localBookIndex,
    AppCacheScope.readerPreference: readerPreference,
  };
}
