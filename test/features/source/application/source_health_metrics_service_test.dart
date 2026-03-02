import 'package:flutter_appread/core/errors/error_stage.dart';
import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_appread/domain/repositories/source_repository.dart';
import 'package:flutter_appread/features/source/application/source_health_metrics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourceHealthMetricsService', () {
    test(
      'persists latest response duration and failure counts by stage',
      () async {
        final repository = _FakeSourceRepository([
          SourceDefinition(
            id: 's1',
            name: '源1',
            baseUrl: 'https://example.com',
          ),
        ]);
        final service = SourceHealthMetricsService(
          sourceRepository: repository,
        );

        final source = (await repository.getAll()).first;
        await service.recordRequestSuccess(
          source: source,
          stage: ErrorStage.search,
          durationMs: 123,
        );
        await service.recordRequestFailure(
          source: source,
          stage: ErrorStage.search,
          durationMs: 456,
        );
        await service.recordRequestFailure(
          source: source,
          stage: ErrorStage.content,
          durationMs: 789,
        );

        final updated = (await repository.getAll()).first;
        expect(updated.lastResponseDurationMs, 789);
        expect(updated.lastResponseStage, ErrorStage.content.name);
        expect(updated.stageFailureCounts[ErrorStage.search.name], 1);
        expect(updated.stageFailureCounts[ErrorStage.content.name], 1);
      },
    );
  });
}

class _FakeSourceRepository implements SourceRepository {
  _FakeSourceRepository(List<SourceDefinition> seed)
    : _sources = List<SourceDefinition>.from(seed);

  final List<SourceDefinition> _sources;

  @override
  Future<void> clear() async {
    _sources.clear();
  }

  @override
  Future<void> deleteById(String sourceId) async {
    _sources.removeWhere((source) => source.id == sourceId);
  }

  @override
  Future<void> deleteByIds(List<String> sourceIds) async {
    final idSet = sourceIds.toSet();
    _sources.removeWhere((source) => idSet.contains(source.id));
  }

  @override
  Future<List<SourceDefinition>> getAll() async {
    return List<SourceDefinition>.unmodifiable(_sources);
  }

  @override
  Future<void> setEnabled({
    required String sourceId,
    required bool enabled,
  }) async {
    final index = _sources.indexWhere((source) => source.id == sourceId);
    if (index < 0) {
      return;
    }
    _sources[index] = _sources[index].copyWith(enabled: enabled);
  }

  @override
  Future<void> upsertAll(List<SourceDefinition> items) async {
    for (final item in items) {
      final index = _sources.indexWhere((source) => source.id == item.id);
      if (index >= 0) {
        _sources[index] = item;
      } else {
        _sources.add(item);
      }
    }
  }

  @override
  Stream<List<SourceDefinition>> watchAll() {
    return Stream<List<SourceDefinition>>.value(
      List<SourceDefinition>.unmodifiable(_sources),
    );
  }
}
