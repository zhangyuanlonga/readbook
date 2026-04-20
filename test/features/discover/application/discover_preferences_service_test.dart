import 'package:shuxiang_reading_next/features/discover/application/discover_preferences_service.dart';
import 'package:shuxiang_reading_next/features/discover/application/explore_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DiscoverPreferencesService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('saves and restores selected source id', () async {
      final service = DiscoverPreferencesService();

      await service.saveSelectedSourceId('source_2');
      final restored = await service.loadSelectedSourceId();

      expect(restored, 'source_2');
    });

    test('clears selected source id when empty', () async {
      final service = DiscoverPreferencesService();

      await service.saveSelectedSourceId('source_2');
      await service.saveSelectedSourceId('');
      final restored = await service.loadSelectedSourceId();

      expect(restored, isNull);
    });

    test('saves and restores discover source snapshot', () async {
      final service = DiscoverPreferencesService();

      await service.saveSourceSnapshot(const <DiscoverSource>[
        DiscoverSource(
          id: 's1',
          name: '源1',
          baseUrl: 'https://a.example.com',
          group: 'A',
        ),
        DiscoverSource(
          id: 's2',
          name: '源2',
          baseUrl: 'https://b.example.com',
          group: 'B',
          sourceType: 2,
        ),
      ]);

      final restored = await service.loadSourceSnapshot();

      expect(restored, hasLength(2));
      expect(restored.first.id, 's1');
      expect(restored.first.name, '源1');
      expect(restored.last.id, 's2');
      expect(restored.last.sourceType, 2);
    });

    test('saves and restores category snapshot for source', () async {
      final service = DiscoverPreferencesService();

      await service.saveCategorySnapshot(
        's1',
        const <ExploreCategoryItem>[
          ExploreCategoryItem(
            title: '推荐',
            url: '/discover',
            style: ExploreCategoryStyle(
              layoutFlexGrow: 1,
              layoutFlexBasisPercent: 25,
            ),
            extra: <String, dynamic>{'tag': 'hot'},
          ),
          ExploreCategoryItem(title: '男频分组'),
        ],
      );

      final restored = await service.loadCategorySnapshot('s1');

      expect(restored, hasLength(2));
      expect(restored.first.title, '推荐');
      expect(restored.first.url, '/discover');
      expect(restored.first.style.layoutFlexBasisPercent, 25);
      expect(restored.first.extra['tag'], 'hot');
      expect(restored.last.title, '男频分组');
      expect(restored.last.isActionable, isFalse);
    });
  });
}
