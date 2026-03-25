import 'package:drift/native.dart';
import 'package:flutter_appread/data/datasources/local/app_database.dart';
import 'package:flutter_appread/data/repositories/script_source_repository_impl.dart';
import 'package:flutter_appread/domain/entities/script_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScriptSourceRepositoryImpl', () {
    late AppDatabase database;
    late ScriptSourceRepositoryImpl repository;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = ScriptSourceRepositoryImpl(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('upsert and query script sources', () async {
      final now = DateTime.parse('2026-03-25T12:00:00.000Z');
      final source = ScriptSource(
        id: 'script_1',
        name: '脚本源A',
        group: '测试组',
        author: 'tester',
        description: '说明',
        sourceCode: 'export default { meta: { name: "脚本源A" } }',
        enabled: true,
        createdAt: now,
        updatedAt: now,
      );

      await repository.upsert(source);
      final items = await repository.getAll();

      expect(items, hasLength(1));
      expect(items.first.id, 'script_1');
      expect(items.first.name, '脚本源A');
      expect(items.first.group, '测试组');
      expect(items.first.author, 'tester');
    });

    test('set enabled, delete and clear', () async {
      final now = DateTime.parse('2026-03-25T12:00:00.000Z');
      final sourceA = ScriptSource(
        id: 'script_a',
        name: '脚本源A',
        sourceCode: 'code-a',
        enabled: true,
        createdAt: now,
        updatedAt: now,
      );
      final sourceB = ScriptSource(
        id: 'script_b',
        name: '脚本源B',
        sourceCode: 'code-b',
        enabled: true,
        createdAt: now,
        updatedAt: now,
      );

      await repository.upsert(sourceA);
      await repository.upsert(sourceB);
      await repository.setEnabled(id: 'script_a', enabled: false);

      var items = await repository.getAll();
      expect(
        items.firstWhere((item) => item.id == 'script_a').enabled,
        isFalse,
      );

      await repository.deleteById('script_b');
      items = await repository.getAll();
      expect(items.map((item) => item.id), <String>['script_a']);

      await repository.clear();
      expect(await repository.getAll(), isEmpty);
    });
  });
}
