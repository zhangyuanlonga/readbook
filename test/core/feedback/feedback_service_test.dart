import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shuxiang_reading_next/core/auth/auth_session_store.dart';
import 'package:shuxiang_reading_next/core/device/device_identity.dart';
import 'package:shuxiang_reading_next/core/device/device_identity_service.dart';
import 'package:shuxiang_reading_next/core/feedback/feedback_service.dart';
import 'package:shuxiang_reading_next/core/network/api_client.dart';

import '../../test_utils/fake_auth_session_secret_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FeedbackService', () {
    test('fetchFeedbackList attaches install_id and bearer token', () async {
      SharedPreferences.setMockInitialValues({
        'auth.access_token': 'token-123',
      });
      final prefs = await SharedPreferences.getInstance();
      final client = _FakeFeedbackApiClient();
      final service = FeedbackService(
        client: client,
        baseUrl: 'http://localhost:8080',
        identityService: _FakeDeviceIdentityService(),
        sessionStore: AuthSessionStore(
          preferences: prefs,
          secretStore: FakeAuthSessionSecretStore(),
        ),
      );

      final page = await service.fetchFeedbackList(
        keyword: '崩溃',
        type: 'issue',
        status: 'pending',
        page: 2,
        pageSize: 15,
      );

      expect(client.capturedPath, '/v1/feedback');
      expect(client.capturedQueryParameters, <String, dynamic>{
        'install_id': 'uuid-per-install',
        'keyword': '崩溃',
        'type': 'issue',
        'status': 'pending',
        'page': 2,
        'page_size': 15,
      });
      expect(client.capturedHeaders['Authorization'], 'Bearer token-123');
      expect(page.total, 1);
      expect(page.items.single.id, 'feedback_1');
    });

    test('fetchFeedbackDetail attaches install_id and bearer token', () async {
      SharedPreferences.setMockInitialValues({
        'auth.access_token': 'token-xyz',
      });
      final prefs = await SharedPreferences.getInstance();
      final client = _FakeFeedbackApiClient();
      final service = FeedbackService(
        client: client,
        baseUrl: 'http://localhost:8080',
        identityService: _FakeDeviceIdentityService(),
        sessionStore: AuthSessionStore(
          preferences: prefs,
          secretStore: FakeAuthSessionSecretStore(),
        ),
      );

      final item = await service.fetchFeedbackDetail('feedback_42');

      expect(client.capturedPath, '/v1/feedback/feedback_42');
      expect(client.capturedQueryParameters, <String, dynamic>{
        'install_id': 'uuid-per-install',
      });
      expect(client.capturedHeaders['Authorization'], 'Bearer token-xyz');
      expect(item.id, 'feedback_1');
    });
  });
}

class _FakeDeviceIdentityService extends DeviceIdentityService {
  @override
  Future<DeviceIdentity> loadIdentity() async {
    return const DeviceIdentity(
      installId: 'uuid-per-install',
      deviceUid: 'hashed-device-id',
      deviceFingerprint: 'hashed-device-fingerprint',
      platform: 'android',
      deviceBrand: 'xiaomi',
      deviceModel: '2304FPN6DC',
      osVersion: '14',
      appVersion: '1.2.3',
    );
  }
}

class _FakeFeedbackApiClient extends ApiClient {
  String? capturedPath;
  Map<String, dynamic> capturedQueryParameters = const <String, dynamic>{};
  Map<String, String> capturedHeaders = const <String, String>{};

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
    Duration? cacheTtl,
    bool attachAccessToken = false,
    bool enableAuthRefresh = true,
    dynamic stage,
    T Function(Object? data)? decoder,
  }) async {
    capturedPath = path;
    capturedQueryParameters = Map<String, dynamic>.from(queryParameters);
    capturedHeaders = Map<String, String>.from(headers);

    final payload =
        path == '/v1/feedback'
            ? <String, dynamic>{
              'items': <Map<String, dynamic>>[_feedbackItemJson()],
              'total': 1,
              'page': 2,
              'page_size': 15,
            }
            : _feedbackItemJson();

    if (decoder != null) {
      return decoder(payload);
    }
    return payload as T;
  }

  static Map<String, dynamic> _feedbackItemJson() {
    return <String, dynamic>{
      'id': 'feedback_1',
      'type': 'issue',
      'title': '章节没有更新',
      'content': '目录仍然是旧的',
      'status': 'pending',
      'labels': <String>['bookshelf'],
      'created_at': '2026-04-24T10:00:00Z',
      'updated_at': '2026-04-24T10:00:00Z',
    };
  }
}
