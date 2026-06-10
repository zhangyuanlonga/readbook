import 'package:shuxiang_reading_next/core/app_update/app_update_service.dart';
import 'package:shuxiang_reading_next/core/device/device_identity.dart';
import 'package:shuxiang_reading_next/core/device/device_identity_service.dart';
import 'package:shuxiang_reading_next/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppUpdateService', () {
    test(
      'sends app_name, version_code and platform to check endpoint',
      () async {
        SharedPreferences.setMockInitialValues({});
        final client = _FakeAppUpdateApiClient();

        final service = AppUpdateService(
          client: client,
          baseUrl: 'http://localhost:8080',
          identityService: _FakeAppUpdateIdentityService(),
        );

        final result = await service.checkUpdate();

        expect(client.capturedPath, '/v1/app-updates/check');
        expect(client.capturedBody, {
          'app_name': 'selune',
          'version_code': 10006,
          'platform': 'android',
        });
        expect(result.hasUpdate, isTrue);
        expect(result.forceUpdate, isFalse);
        expect(result.release?.versionCode, 10012);
      },
    );
  });
}

class _FakeAppUpdateIdentityService extends DeviceIdentityService {
  @override
  Future<int> getAppVersionCode() async => 10006;

  @override
  Future<DeviceIdentity> loadIdentity() async => const DeviceIdentity(
    installId: 'ins_xxx',
    deviceUid: 'dev_xxx',
    deviceFingerprint: 'fp_xxx',
    platform: 'android',
    deviceBrand: 'Google',
    deviceModel: 'Pixel',
    osVersion: '14',
    appVersion: '1.0.0',
  );
}

class _FakeAppUpdateApiClient extends ApiClient {
  String? capturedPath;
  Object? capturedBody;

  @override
  Future<T> request<T>({
    required ApiMethod method,
    required String path,
    Map<String, dynamic> queryParameters = const {},
    Object? body,
    Map<String, String> headers = const {},
    Duration? timeout,
    int? maxRetries,
    bool enableRetry = true,
    bool enableCache = false,
    ApiCachePolicy cachePolicy = ApiCachePolicy.realtime,
    Duration? cacheTtl,
    bool attachAccessToken = false,
    bool enableAuthRefresh = true,
    dynamic stage,
    T Function(Object? data)? decoder,
  }) async {
    capturedPath = path;
    capturedBody = body;

    final payload = {
      'has_update': true,
      'force_update': false,
      'latest_version': {
        'id': 'rel_xxx',
        'app_name': 'selune',
        'version_code': 10012,
        'downloads': [
          {
            'platform': 'android',
            'label': 'Android',
            'download_url': 'https://example.com/app.apk',
          },
        ],
        'changelog': '优化体验',
      },
    };

    if (decoder != null) {
      return decoder(payload);
    }
    return payload as T;
  }
}
