import 'package:drift/native.dart';
import 'package:flutter_appread/data/datasources/local/app_database.dart';
import 'package:flutter_appread/data/repositories/source_repository_impl.dart';
import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourceRepositoryImpl', () {
    late AppDatabase database;
    late SourceRepositoryImpl repository;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = SourceRepositoryImpl(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('upsert and query sources', () async {
      final source = SourceDefinition(
        id: 's1',
        name: '源A',
        baseUrl: 'https://a.com',
        rules: const SourceRuleSet(searchRule: '/search?key={{key}}'),
      );

      await repository.upsertAll([source]);
      final items = await repository.getAll();

      expect(items, hasLength(1));
      expect(items.first.id, 's1');
      expect(items.first.name, '源A');
    });

    test('set enabled, delete and clear', () async {
      final sourceA = SourceDefinition(
        id: 's1',
        name: '源A',
        baseUrl: 'https://a.com',
        rules: const SourceRuleSet(searchRule: '/search?key={{key}}'),
      );
      final sourceB = SourceDefinition(
        id: 's2',
        name: '源B',
        baseUrl: 'https://b.com',
        rules: const SourceRuleSet(searchRule: '/search?key={{key}}'),
      );

      await repository.upsertAll([sourceA, sourceB]);
      await repository.setEnabled(sourceId: 's1', enabled: false);

      var items = await repository.getAll();
      final changed = items.firstWhere((item) => item.id == 's1');
      expect(changed.enabled, isFalse);

      await repository.deleteById('s2');
      items = await repository.getAll();
      expect(items.map((item) => item.id), ['s1']);

      await repository.clear();
      items = await repository.getAll();
      expect(items, isEmpty);
    });

    test('persists discover fields and supportsExplore state', () async {
      final source = SourceDefinition(
        id: 'discover_s1',
        name: '发现源',
        baseUrl: 'https://discover.example.com',
        enabled: true,
        exploreEnabled: true,
        exploreUrl: '推荐::/discover?page={{page}}',
        rules: const SourceRuleSet(
          searchRule: '/search?key={{key}}',
          exploreListRule: '.item@html',
          exploreTitleRule: '.name@text',
          exploreDetailUrlRule: '.name@href',
        ),
      );

      await repository.upsertAll(<SourceDefinition>[source]);
      final items = await repository.getAll();

      expect(items, hasLength(1));
      final restored = items.first;
      expect(restored.exploreEnabled, isTrue);
      expect(restored.exploreUrl, '推荐::/discover?page={{page}}');
      expect(restored.rules.exploreListRule, '.item@html');
      expect(restored.rules.exploreTitleRule, '.name@text');
      expect(restored.rules.exploreDetailUrlRule, '.name@href');
      expect(restored.supportsExplore, isTrue);
    });
  });
}
