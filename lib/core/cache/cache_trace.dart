import '../logging/app_logger.dart';
import 'cache_key.dart';
import 'cache_result.dart';
import 'cache_scope.dart';

typedef AppCacheTraceLog =
    void Function(String message, {Map<String, Object?> context});

class AppCacheTraceEvent {
  const AppCacheTraceEvent({
    required this.scope,
    required this.key,
    required this.status,
    required this.backend,
    required this.owner,
    this.sizeBytes,
    this.cost,
    this.invalidReason,
    this.errorType,
    this.errorMessage,
  });

  final AppCacheScope scope;
  final AppCacheKey? key;
  final String status;
  final String backend;
  final String owner;
  final int? sizeBytes;
  final Duration? cost;
  final AppCacheInvalidReason? invalidReason;
  final String? errorType;
  final String? errorMessage;

  Map<String, Object?> toContext() {
    return <String, Object?>{
      'scope': scope.name,
      'owner': owner,
      'backend': backend,
      'status': status,
      'key': key?.toStorageKey(),
      'sizeBytes': sizeBytes,
      'costMs': cost?.inMilliseconds,
      'invalidReason': invalidReason?.name,
      'errorType': errorType,
      'errorMessage': errorMessage,
    };
  }
}

class AppCacheTracer {
  AppCacheTracer({AppCacheTraceLog? log, this.enabled = true})
    : _log = log ?? AppLogger.instance.debug;

  final bool enabled;
  final AppCacheTraceLog _log;

  void traceRead(AppCacheReadResult result) {
    _trace(
      AppCacheTraceEvent(
        scope: result.key.scope,
        key: result.key,
        status: result.status.name,
        backend: result.backend,
        owner: result.key.owner,
        sizeBytes: result.entry?.sizeBytes,
        cost: result.cost,
        invalidReason: result.invalidReason,
        errorType: result.error?.runtimeType.toString(),
        errorMessage: result.error?.toString(),
      ),
    );
  }

  void traceWrite(AppCacheWriteResult result) {
    _trace(
      AppCacheTraceEvent(
        scope: result.key.scope,
        key: result.key,
        status: result.status.name,
        backend: result.backend,
        owner: result.key.owner,
        sizeBytes: result.sizeBytes,
        cost: result.cost,
        errorType: result.error?.runtimeType.toString(),
        errorMessage: result.error?.toString(),
      ),
    );
  }

  void traceDelete(AppCacheDeleteResult result) {
    _trace(
      AppCacheTraceEvent(
        scope: result.scope,
        key: result.key,
        status: result.status.name,
        backend: result.backend,
        owner: result.key?.owner ?? 'scope',
        sizeBytes: result.deletedBytes,
        cost: result.cost,
        errorType: result.error?.runtimeType.toString(),
        errorMessage: result.error?.toString(),
      ),
    );
  }

  void tracePrune(AppCachePruneResult result) {
    _trace(
      AppCacheTraceEvent(
        scope: result.scope,
        key: null,
        status: 'pruned',
        backend: result.backend,
        owner: 'scope',
        sizeBytes: result.deletedBytes,
        cost: result.cost,
      ),
    );
  }

  void traceDecodeFailed({
    required AppCacheKey key,
    required String backend,
    Object? error,
    StackTrace? stackTrace,
  }) {
    traceRead(
      AppCacheReadResult.decodeFailed(
        key: key,
        backend: backend,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  void traceVersionMismatch({
    required AppCacheKey key,
    required String backend,
    required int expectedVersion,
    required int actualVersion,
  }) {
    _trace(
      AppCacheTraceEvent(
        scope: key.scope,
        key: key,
        status: AppCacheReadStatus.versionMismatch.name,
        backend: backend,
        owner: key.owner,
        invalidReason: AppCacheInvalidReason.versionChanged,
        errorType: 'versionMismatch',
        errorMessage: 'expected=$expectedVersion, actual=$actualVersion',
      ),
    );
  }

  void _trace(AppCacheTraceEvent event) {
    if (!enabled) {
      return;
    }
    _log('Cache ${event.status}', context: event.toContext());
  }
}
