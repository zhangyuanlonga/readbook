import '../../domain/entities/source_definition.dart';
import '../../domain/repositories/source_repository.dart';
import '../datasources/local/app_database.dart';

class SourceRepositoryImpl implements SourceRepository {
  SourceRepositoryImpl(this._database);

  final AppDatabase _database;

  @override
  Future<void> clear() => _database.clearSources();

  @override
  Future<void> deleteById(String sourceId) => _database.deleteSource(sourceId);

  @override
  Future<void> deleteByIds(List<String> sourceIds) =>
      _database.deleteSourcesByIds(sourceIds);

  @override
  Future<List<SourceDefinition>> getAll() => _database.getAllSources();

  @override
  Future<void> setEnabled({required String sourceId, required bool enabled}) {
    return _database.setSourceEnabled(sourceId, enabled);
  }

  @override
  Future<void> upsertAll(List<SourceDefinition> sources) {
    return _database.upsertSources(sources);
  }

  @override
  Stream<List<SourceDefinition>> watchAll() => _database.watchAllSources();
}
