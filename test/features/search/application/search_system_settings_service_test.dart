import 'package:flutter_appread/features/search/application/search_system_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SearchSystemSettingsService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads true by default and persists aggregation toggle', () async {
      final service = SearchSystemSettingsService();

      final defaultValue = await service.loadAggregateByTitleAuthorEnabled();
      expect(defaultValue, isTrue);

      await service.saveAggregateByTitleAuthorEnabled(false);
      final disabledValue = await service.loadAggregateByTitleAuthorEnabled();
      expect(disabledValue, isFalse);

      await service.saveAggregateByTitleAuthorEnabled(true);
      final enabledValue = await service.loadAggregateByTitleAuthorEnabled();
      expect(enabledValue, isTrue);
    });

    test(
      'loads false by default and persists search debug log toggle',
      () async {
        final service = SearchSystemSettingsService();

        final defaultValue = await service.loadSearchDebugLogEnabled();
        expect(defaultValue, isFalse);

        await service.saveSearchDebugLogEnabled(true);
        final enabledValue = await service.loadSearchDebugLogEnabled();
        expect(enabledValue, isTrue);

        await service.saveSearchDebugLogEnabled(false);
        final disabledValue = await service.loadSearchDebugLogEnabled();
        expect(disabledValue, isFalse);
      },
    );
  });
}
