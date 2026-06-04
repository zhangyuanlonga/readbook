import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/features/mine/application/mine_page_preferences_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('visibility state persists hidden configurable items', () async {
    final service = MinePagePreferencesService();

    await service.saveVisibilityState(
      MinePageVisibilityState(
        hiddenItemIds: const [
          MinePageItemId.checkUpdate,
          MinePageItemId.inspiration,
        ],
      ),
    );

    final state = await service.loadVisibilityState();

    expect(state.isVisible(MinePageItemId.checkUpdate), isFalse);
    expect(state.isVisible(MinePageItemId.inspiration), isFalse);
  });

  test('visibility state ignores unknown hidden item ids', () {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'mine.page.hiddenItems': <String>['sync', 'missing-item'],
    });

    return SharedPreferences.getInstance().then((prefs) {
      final state = MinePagePreferencesService.readVisibilityState(prefs);

      expect(state.hiddenItemIds, isEmpty);
    });
  });

  test('system settings entry is not displayable on mine page', () {
    final state = MinePageVisibilityState(
      hiddenItemIds: const [MinePageItemId.systemSettings],
    );

    expect(state.isVisible(MinePageItemId.systemSettings), isFalse);
    expect(
      displayableMinePageItemDefinitions.map((definition) => definition.id),
      isNot(contains(MinePageItemId.systemSettings)),
    );
    expect(
      configurableMinePageItemDefinitions.map((definition) => definition.id),
      isNot(contains(MinePageItemId.systemSettings)),
    );
  });

  test(
    'core data management entries stay visible even if old prefs hide them',
    () {
      final state = MinePageVisibilityState(
        hiddenItemIds: const [
          MinePageItemId.tagManagement,
          MinePageItemId.categoryManagement,
          MinePageItemId.fontManagement,
        ],
      );

      expect(state.isVisible(MinePageItemId.tagManagement), isTrue);
      expect(state.isVisible(MinePageItemId.categoryManagement), isTrue);
      expect(state.isVisible(MinePageItemId.fontManagement), isTrue);
      expect(
        configurableMinePageItemDefinitions.map((definition) => definition.id),
        isNot(contains(MinePageItemId.tagManagement)),
      );
      expect(
        configurableMinePageItemDefinitions.map((definition) => definition.id),
        isNot(contains(MinePageItemId.categoryManagement)),
      );
      expect(
        configurableMinePageItemDefinitions.map((definition) => definition.id),
        isNot(contains(MinePageItemId.fontManagement)),
      );
    },
  );

  test(
    'startup destination defaults to bookshelf and normalizes old home',
    () async {
      final service = MinePagePreferencesService();

      expect(
        await service.loadStartupDestination(),
        MinePageStartupDestination.bookshelf,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        MinePagePreferencesService.startupDestinationPreferenceKey,
        'home',
      );

      expect(
        await service.loadStartupDestination(),
        MinePageStartupDestination.bookshelf,
      );

      await service.saveStartupDestination(
        MinePageStartupDestination.bookshelf,
      );

      expect(
        await service.loadStartupDestination(),
        MinePageStartupDestination.bookshelf,
      );
    },
  );

  test('layout mode defaults to null and persists grid mode', () async {
    final service = MinePagePreferencesService();

    expect(await service.loadLayoutMode(), isNull);

    await service.saveLayoutMode(MinePageLayoutMode.grid);

    expect(await service.loadLayoutMode(), MinePageLayoutMode.grid);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(MinePagePreferencesService.layoutModePreferenceKey),
      'grid',
    );
  });
}
