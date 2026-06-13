import 'cache_entry.dart';
import 'cache_key.dart';
import 'cache_scope.dart';

enum AppCacheReadStatus {
  hit,
  miss,
  stale,
  decodeFailed,
  versionMismatch,
  backendError,
}

enum AppCacheInvalidReason {
  ttlExpired,
  versionChanged,
  layoutChanged,
  fontChanged,
  themeChanged,
  viewportChanged,
  userChanged,
  payloadCorrupted,
  backendUnavailable,
  unknown,
}

enum AppCacheWriteStatus { written, skipped, backendError }

enum AppCacheDeleteStatus { deleted, skipped, backendError }

class AppCacheReadResult {
  const AppCacheReadResult({
    required this.key,
    required this.status,
    required this.backend,
    this.entry,
    this.invalidReason,
    this.error,
    this.stackTrace,
    this.cost,
  });

  factory AppCacheReadResult.hit({
    required AppCacheKey key,
    required String backend,
    required AppCacheEntry entry,
    Duration? cost,
  }) {
    return AppCacheReadResult(
      key: key,
      status: AppCacheReadStatus.hit,
      backend: backend,
      entry: entry,
      cost: cost,
    );
  }

  factory AppCacheReadResult.miss({
    required AppCacheKey key,
    required String backend,
    Duration? cost,
  }) {
    return AppCacheReadResult(
      key: key,
      status: AppCacheReadStatus.miss,
      backend: backend,
      cost: cost,
    );
  }

  factory AppCacheReadResult.stale({
    required AppCacheKey key,
    required String backend,
    required AppCacheEntry entry,
    required AppCacheInvalidReason invalidReason,
    Duration? cost,
  }) {
    return AppCacheReadResult(
      key: key,
      status: AppCacheReadStatus.stale,
      backend: backend,
      entry: entry,
      invalidReason: invalidReason,
      cost: cost,
    );
  }

  factory AppCacheReadResult.decodeFailed({
    required AppCacheKey key,
    required String backend,
    Object? error,
    StackTrace? stackTrace,
    Duration? cost,
  }) {
    return AppCacheReadResult(
      key: key,
      status: AppCacheReadStatus.decodeFailed,
      backend: backend,
      invalidReason: AppCacheInvalidReason.payloadCorrupted,
      error: error,
      stackTrace: stackTrace,
      cost: cost,
    );
  }

  factory AppCacheReadResult.versionMismatch({
    required AppCacheKey key,
    required String backend,
    required AppCacheEntry entry,
    Duration? cost,
  }) {
    return AppCacheReadResult(
      key: key,
      status: AppCacheReadStatus.versionMismatch,
      backend: backend,
      entry: entry,
      invalidReason: AppCacheInvalidReason.versionChanged,
      cost: cost,
    );
  }

  factory AppCacheReadResult.backendError({
    required AppCacheKey key,
    required String backend,
    Object? error,
    StackTrace? stackTrace,
    Duration? cost,
  }) {
    return AppCacheReadResult(
      key: key,
      status: AppCacheReadStatus.backendError,
      backend: backend,
      invalidReason: AppCacheInvalidReason.backendUnavailable,
      error: error,
      stackTrace: stackTrace,
      cost: cost,
    );
  }

  final AppCacheKey key;
  final AppCacheReadStatus status;
  final String backend;
  final AppCacheEntry? entry;
  final AppCacheInvalidReason? invalidReason;
  final Object? error;
  final StackTrace? stackTrace;
  final Duration? cost;

  bool get hasValue => status == AppCacheReadStatus.hit && entry != null;
}

class AppCacheWriteResult {
  const AppCacheWriteResult({
    required this.key,
    required this.status,
    required this.backend,
    this.sizeBytes,
    this.error,
    this.stackTrace,
    this.cost,
  });

  factory AppCacheWriteResult.written({
    required AppCacheKey key,
    required String backend,
    int? sizeBytes,
    Duration? cost,
  }) {
    return AppCacheWriteResult(
      key: key,
      status: AppCacheWriteStatus.written,
      backend: backend,
      sizeBytes: sizeBytes,
      cost: cost,
    );
  }

  factory AppCacheWriteResult.skipped({
    required AppCacheKey key,
    required String backend,
    Duration? cost,
  }) {
    return AppCacheWriteResult(
      key: key,
      status: AppCacheWriteStatus.skipped,
      backend: backend,
      cost: cost,
    );
  }

  factory AppCacheWriteResult.backendError({
    required AppCacheKey key,
    required String backend,
    Object? error,
    StackTrace? stackTrace,
    Duration? cost,
  }) {
    return AppCacheWriteResult(
      key: key,
      status: AppCacheWriteStatus.backendError,
      backend: backend,
      error: error,
      stackTrace: stackTrace,
      cost: cost,
    );
  }

  final AppCacheKey key;
  final AppCacheWriteStatus status;
  final String backend;
  final int? sizeBytes;
  final Object? error;
  final StackTrace? stackTrace;
  final Duration? cost;
}

class AppCacheDeleteResult {
  const AppCacheDeleteResult({
    required this.scope,
    required this.status,
    required this.backend,
    this.key,
    this.deletedEntries = 0,
    this.deletedBytes = 0,
    this.error,
    this.stackTrace,
    this.cost,
  });

  factory AppCacheDeleteResult.deleted({
    required AppCacheScope scope,
    required String backend,
    AppCacheKey? key,
    int deletedEntries = 0,
    int deletedBytes = 0,
    Duration? cost,
  }) {
    return AppCacheDeleteResult(
      scope: scope,
      status: AppCacheDeleteStatus.deleted,
      backend: backend,
      key: key,
      deletedEntries: deletedEntries,
      deletedBytes: deletedBytes,
      cost: cost,
    );
  }

  factory AppCacheDeleteResult.skipped({
    required AppCacheScope scope,
    required String backend,
    AppCacheKey? key,
    Duration? cost,
  }) {
    return AppCacheDeleteResult(
      scope: scope,
      status: AppCacheDeleteStatus.skipped,
      backend: backend,
      key: key,
      cost: cost,
    );
  }

  factory AppCacheDeleteResult.backendError({
    required AppCacheScope scope,
    required String backend,
    AppCacheKey? key,
    Object? error,
    StackTrace? stackTrace,
    Duration? cost,
  }) {
    return AppCacheDeleteResult(
      scope: scope,
      status: AppCacheDeleteStatus.backendError,
      backend: backend,
      key: key,
      error: error,
      stackTrace: stackTrace,
      cost: cost,
    );
  }

  final AppCacheScope scope;
  final AppCacheDeleteStatus status;
  final String backend;
  final AppCacheKey? key;
  final int deletedEntries;
  final int deletedBytes;
  final Object? error;
  final StackTrace? stackTrace;
  final Duration? cost;
}

class AppCachePruneResult {
  const AppCachePruneResult({
    required this.scope,
    required this.backend,
    this.deletedEntries = 0,
    this.deletedBytes = 0,
    this.cost,
  });

  final AppCacheScope scope;
  final String backend;
  final int deletedEntries;
  final int deletedBytes;
  final Duration? cost;
}

class AppCacheStats {
  const AppCacheStats({
    required this.scope,
    required this.backend,
    required this.entries,
    required this.bytes,
  });

  final AppCacheScope scope;
  final String backend;
  final int entries;
  final int bytes;
}
