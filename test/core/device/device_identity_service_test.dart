import 'package:flutter_appread/core/device/device_identity_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceIdentityService.normalizeVersionCode', () {
    test('prefers semantic version code over small build number', () {
      final code = DeviceIdentityService.normalizeVersionCode(
        versionName: '1.0.6',
        buildNumber: '1',
      );

      expect(code, 10006);
    });

    test('keeps larger build number when already configured', () {
      final code = DeviceIdentityService.normalizeVersionCode(
        versionName: '1.0.6',
        buildNumber: '10012',
      );

      expect(code, 10012);
    });

    test('parses two segment version names', () {
      final code = DeviceIdentityService.normalizeVersionCode(
        versionName: '1.11',
        buildNumber: '1',
      );

      expect(code, 11100);
    });

    test('falls back to build number when version name is invalid', () {
      final code = DeviceIdentityService.normalizeVersionCode(
        versionName: 'dev-build',
        buildNumber: '23',
      );

      expect(code, 23);
    });
  });
}
