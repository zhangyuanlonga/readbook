import 'package:flutter_appread/features/discover/application/discover_preferences_service.dart';
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
  });
}
