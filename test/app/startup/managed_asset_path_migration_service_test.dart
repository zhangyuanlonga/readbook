import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/app/startup/managed_asset_path_migration_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'startup.managedAssetPathMigration.completedVersion': 1,
    });
  });

  test('skips already completed managed asset migration version', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = ManagedAssetPathMigrationService(preferences: prefs);

    await service.migrate();

    expect(
      prefs.getInt('startup.managedAssetPathMigration.completedVersion'),
      1,
    );
  });
}
