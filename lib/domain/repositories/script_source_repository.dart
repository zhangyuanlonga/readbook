import '../entities/script_source.dart';

abstract class ScriptSourceRepository {
  Future<List<ScriptSource>> getAll();

  Stream<List<ScriptSource>> watchAll();

  Future<ScriptSource?> getById(String id);

  Future<void> upsert(ScriptSource source);

  Future<void> setEnabled({required String id, required bool enabled});

  Future<void> deleteById(String id);

  Future<void> clear();
}
