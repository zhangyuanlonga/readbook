import '../../../core/errors/error_stage.dart';
import '../../../core/logging/app_logger.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/repositories/source_repository_impl.dart';
import '../../../domain/entities/source_definition.dart';
import '../../../domain/repositories/source_repository.dart';

class SourceHealthMetricsService {
  SourceHealthMetricsService({
    SourceRepository? sourceRepository,
    AppLogger? logger,
  }) : _sourceRepository =
           sourceRepository ?? SourceRepositoryImpl(AppDatabase.instance),
       _logger = logger ?? AppLogger.instance;

  final SourceRepository _sourceRepository;
  final AppLogger _logger;

  final Map<String, Future<void>> _pendingBySourceId = <String, Future<void>>{};

  Future<void> recordRequestSuccess({
    required SourceDefinition source,
    required ErrorStage stage,
    required int durationMs,
  }) {
    return _enqueueSourceUpdate(
      sourceId: source.id,
      task:
          () => _persistMetrics(
            source: source,
            stage: stage,
            durationMs: durationMs,
            incrementFailure: false,
          ),
    );
  }

  Future<void> recordRequestFailure({
    required SourceDefinition source,
    required ErrorStage stage,
    required int durationMs,
  }) {
    return _enqueueSourceUpdate(
      sourceId: source.id,
      task:
          () => _persistMetrics(
            source: source,
            stage: stage,
            durationMs: durationMs,
            incrementFailure: true,
          ),
    );
  }

  Future<void> _enqueueSourceUpdate({
    required String sourceId,
    required Future<void> Function() task,
  }) {
    final normalizedSourceId = sourceId.trim();
    if (normalizedSourceId.isEmpty) {
      return Future<void>.value();
    }

    final previous =
        _pendingBySourceId[normalizedSourceId] ?? Future<void>.value();
    final next = previous.catchError((_) {}).then((_) => task());
    _pendingBySourceId[normalizedSourceId] = next.whenComplete(() {
      if (identical(_pendingBySourceId[normalizedSourceId], next)) {
        _pendingBySourceId.remove(normalizedSourceId);
      }
    });
    return next;
  }

  Future<void> _persistMetrics({
    required SourceDefinition source,
    required ErrorStage stage,
    required int durationMs,
    required bool incrementFailure,
  }) async {
    final latest = await _resolveLatestSource(source);
    final nextFailureCounts = <String, int>{...latest.stageFailureCounts};
    if (incrementFailure) {
      final stageKey = stage.name;
      final current = nextFailureCounts[stageKey] ?? 0;
      nextFailureCounts[stageKey] = current + 1;
    }

    final nextSource = latest.copyWith(
      lastResponseDurationMs: durationMs < 0 ? 0 : durationMs,
      lastResponseStage: stage.name,
      stageFailureCounts: nextFailureCounts,
    );

    try {
      await _sourceRepository.upsertAll([nextSource]);
    } catch (error) {
      _logger.warn(
        'Persist source health metrics failed',
        context: <String, Object?>{
          'sourceId': source.id,
          'stage': stage.name,
          'durationMs': durationMs,
          'incrementFailure': incrementFailure,
          'error': error.toString(),
        },
      );
    }
  }

  Future<SourceDefinition> _resolveLatestSource(
    SourceDefinition fallback,
  ) async {
    try {
      final sources = await _sourceRepository.getAll();
      for (final source in sources) {
        if (source.id == fallback.id) {
          return source;
        }
      }
    } catch (_) {
      // Keep fallback when repository lookup fails.
    }
    return fallback;
  }
}
