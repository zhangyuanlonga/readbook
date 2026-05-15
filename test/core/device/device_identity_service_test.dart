import 'package:shuxiang_reading_next/core/device/device_identity_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceIdentityService.selectAndroidHardwareId', () {
    test('accepts serial number when available', () {
      final value = DeviceIdentityService.selectAndroidHardwareId(
        serialNumber: 'SERIAL-123',
      );

      expect(value, 'SERIAL-123');
    });

    test('drops blank or unknown serial number', () {
      expect(
        DeviceIdentityService.selectAndroidHardwareId(serialNumber: ''),
        isNull,
      );
      expect(
        DeviceIdentityService.selectAndroidHardwareId(serialNumber: 'unknown'),
        isNull,
      );
    });
  });

  group('DeviceIdentityService.normalizeHardwareId', () {
    test('returns null for blank or unknown values', () {
      expect(DeviceIdentityService.normalizeHardwareId(''), isNull);
      expect(DeviceIdentityService.normalizeHardwareId('unknown'), isNull);
      expect(DeviceIdentityService.normalizeHardwareId('  '), isNull);
    });

    test('keeps non-empty stable identifiers', () {
      expect(
        DeviceIdentityService.normalizeHardwareId('device-stable-id'),
        'device-stable-id',
      );
    });
  });

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
