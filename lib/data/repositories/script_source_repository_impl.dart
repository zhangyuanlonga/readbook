import '../../domain/entities/script_source.dart';
import '../../domain/repositories/script_source_repository.dart';
import '../../data/datasources/local/app_database.dart';

class ScriptSourceRepositoryImpl implements ScriptSourceRepository {
  ScriptSourceRepositoryImpl(this._database);

  final AppDatabase _database;

  @override
  Future<void> clear() => _database.clearScriptSources();

  @override
  Future<void> deleteById(String id) => _database.deleteScriptSource(id);

  @override
  Future<List<ScriptSource>> getAll() => _database.getAllScriptSources();

  @override
  Future<ScriptSource?> getById(String id) => _database.getScriptSourceById(id);

  @override
  Future<void> setEnabled({required String id, required bool enabled}) {
    return _database.setScriptSourceEnabled(id: id, enabled: enabled);
  }

  @override
  Future<void> upsert(ScriptSource source) =>
      _database.upsertScriptSource(source);

  @override
  Stream<List<ScriptSource>> watchAll() => _database.watchAllScriptSources();
}
