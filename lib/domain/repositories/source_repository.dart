import '../entities/source_definition.dart';

abstract class SourceRepository {
  Future<List<SourceDefinition>> getAll();

  Stream<List<SourceDefinition>> watchAll();

  Future<void> upsertAll(List<SourceDefinition> sources);

  Future<void> setEnabled({required String sourceId, required bool enabled});

  Future<void> deleteById(String sourceId);

  Future<void> deleteByIds(List<String> sourceIds);

  Future<void> clear();
}
