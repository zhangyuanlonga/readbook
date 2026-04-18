import 'package:shuxiang_reading_next/core/app_update/app_update_check_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppUpdateCheckResult', () {
    test('parses response without update', () {
      final result = AppUpdateCheckResult.fromJson({
        'has_update': false,
        'force_update': false,
      }, currentVersionCode: 10012);

      expect(result.hasUpdate, isFalse);
      expect(result.forceUpdate, isFalse);
      expect(result.release, isNull);
    });

    test('parses response with latest_version payload', () {
      final result = AppUpdateCheckResult.fromJson({
        'has_update': true,
        'force_update': true,
        'latest_version': {
          'id': 'rel_xxx',
          'app_name': 'reader-app',
          'version_code': 10023,
          'downloads': [
            {
              'platform': 'android',
              'label': 'Android',
              'download_url': 'https://example.com/app.apk',
            },
          ],
          'changelog': '修复已知问题，优化体验',
        },
      }, currentVersionCode: 10012);

      expect(result.hasUpdate, isTrue);
      expect(result.forceUpdate, isTrue);
      expect(result.release, isNotNull);
      expect(result.release?.id, 'rel_xxx');
      expect(result.release?.appName, 'reader-app');
      expect(result.release?.versionCode, 10023);
      expect(result.release?.forceUpdate, isTrue);
      expect(result.release?.downloads.first.downloadUrl, 'https://example.com/app.apk');
      expect(result.release?.changelog, '修复已知问题，优化体验');
    });

    test('top-level force_update overrides nested release flag', () {
      final result = AppUpdateCheckResult.fromJson({
        'has_update': true,
        'force_update': false,
        'latest_version': {
          'id': 'rel_xxx',
          'app_name': 'reader-app',
          'version_code': 10023,
          'force_update': true,
          'downloads': [
            {
              'platform': 'android',
              'label': 'Android',
              'download_url': 'https://example.com/app.apk',
            },
          ],
          'changelog': '修复已知问题，优化体验',
        },
      }, currentVersionCode: 10012);

      expect(result.hasUpdate, isTrue);
      expect(result.forceUpdate, isFalse);
      expect(result.release, isNotNull);
      expect(result.release?.forceUpdate, isFalse);
    });
  });
}
