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
          MinePageItemId.sync,
          MinePageItemId.checkUpdate,
          MinePageItemId.membershipCenter,
        ],
      ),
    );

    final state = await service.loadVisibilityState();

    expect(state.isVisible(MinePageItemId.sync), isFalse);
    expect(state.isVisible(MinePageItemId.checkUpdate), isFalse);
    expect(state.isVisible(MinePageItemId.membershipCenter), isTrue);
  });

  test('visibility state ignores unknown hidden item ids', () {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'mine.page.hiddenItems': <String>['sync', 'missing-item'],
    });

    return SharedPreferences.getInstance().then((prefs) {
      final state = MinePagePreferencesService.readVisibilityState(prefs);

      expect(state.isVisible(MinePageItemId.sync), isFalse);
      expect(state.hiddenItemIds, hasLength(1));
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

  test('startup destination defaults to home and persists bookshelf', () async {
    final service = MinePagePreferencesService();

    expect(
      await service.loadStartupDestination(),
      MinePageStartupDestination.home,
    );

    await service.saveStartupDestination(MinePageStartupDestination.bookshelf);

    expect(
      await service.loadStartupDestination(),
      MinePageStartupDestination.bookshelf,
    );
  });
}
