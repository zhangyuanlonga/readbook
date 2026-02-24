import 'package:drift/native.dart';
import 'package:flutter_appread/data/datasources/local/app_database.dart';
import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Source list query', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('supports count, keyword search and pagination', () async {
      await database.upsertSources([
        SourceDefinition(
          id: 's_a',
          name: '番茄源',
          baseUrl: 'https://a.example.com',
          enabled: true,
          group: '小说',
          comment: '稳定',
          rules: const SourceRuleSet(searchRule: '/search?key={{key}}'),
        ),
        SourceDefinition(
          id: 's_b',
          name: '晴天漫画',
          baseUrl: 'https://comic.example.com',
          enabled: false,
          sourceType: 2,
          group: '漫画',
          comment: '备用',
          rules: const SourceRuleSet(searchRule: '/search?key={{key}}'),
        ),
        SourceDefinition(
          id: 's_c',
          name: '起点源',
          baseUrl: 'https://book.example.com',
          enabled: true,
          group: '小说',
          rules: const SourceRuleSet(searchRule: '/search?key={{key}}'),
        ),
      ]);

      expect(await database.countSourceListItems(), 3);
      expect(await database.countSourceListItems(enabledOnly: true), 2);

      final keywordMatched = await database.countSourceListItems(keyword: '漫画');
      expect(keywordMatched, 1);

      final firstPage = await database.querySourceListItems(
        limit: 2,
        offset: 0,
      );
      final secondPage = await database.querySourceListItems(
        limit: 2,
        offset: 2,
      );

      expect(firstPage, hasLength(2));
      expect(secondPage, hasLength(1));

      final filtered = await database.querySourceListItems(
        limit: 10,
        offset: 0,
        keyword: 'example.com',
      );
      expect(filtered, hasLength(3));

      final byName = await database.querySourceListItems(
        limit: 10,
        offset: 0,
        keyword: '番茄',
      );
      expect(byName, hasLength(1));
      expect(byName.first.id, 's_a');

      final manga = await database.querySourceListItems(
        limit: 10,
        offset: 0,
        keyword: '漫画',
      );
      expect(manga, hasLength(1));
      expect(manga.first.sourceType, 2);
      expect(manga.first.isMangaSource, isTrue);
    });

    test(
      'decodes lastCheckedAt from source list query with correct epoch unit',
      () async {
        final checkedAt = DateTime.parse('2026-02-24T08:30:00.000Z');

        await database.upsertSources([
          SourceDefinition(
            id: 's_checked',
            name: '测试时间源',
            baseUrl: 'https://checked.example.com',
            enabled: true,
            lastCheckStatus: SourceHealthStatus.healthy,
            lastCheckedAt: checkedAt,
            rules: const SourceRuleSet(searchRule: '/search?key={{key}}'),
          ),
        ]);

        final rows = await database.querySourceListItems(limit: 1, offset: 0);
        expect(rows, hasLength(1));
        expect(rows.first.lastCheckedAt, isNotNull);
        expect(rows.first.lastCheckedAt!.year, greaterThan(2020));

        final deltaSeconds =
            rows.first.lastCheckedAt!
                .difference(checkedAt.toLocal())
                .inSeconds
                .abs();
        expect(deltaSeconds, lessThanOrEqualTo(1));
      },
    );
  });
}
