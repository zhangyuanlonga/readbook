import 'dart:convert';
import 'dart:io';

import 'package:flutter_appread/core/analytics/analytics_service.dart';
import 'package:flutter_appread/core/auth/auth_session_store.dart';
import 'package:flutter_appread/core/device/device_identity.dart';
import 'package:flutter_appread/core/device/device_identity_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AnalyticsService', () {
    test('sends visit payload with bearer token when logged in', () async {
      SharedPreferences.setMockInitialValues({
        'auth.access_token': 'token-123',
      });
      final prefs = await SharedPreferences.getInstance();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

      Map<String, dynamic>? requestBody;
      String? authorization;
      String? requestPath;

      server.listen((request) async {
        requestPath = request.uri.path;
        authorization = request.headers.value(HttpHeaders.authorizationHeader);
        requestBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response.statusCode = 200;
        request.response.write(
          jsonEncode({
            'code': 'OK',
            'message': 'success',
            'data': {
              'open_event': {'id': 'evt_open_xxx'},
              'visit_event': {'id': 'evt_visit_xxx'},
            },
          }),
        );
        await request.response.close();
      });

      final service = AnalyticsService(
        baseUrl: 'http://${server.address.host}:${server.port}',
        identityService: _FakeDeviceIdentityService(),
        sessionStore: AuthSessionStore(preferences: prefs),
      );

      await service.trackVisit(
        occurredAt: DateTime.utc(2026, 3, 15, 8),
        visitCount: 1,
        visitSeconds: 120,
      );

      expect(requestPath, '/v1/analytics/visit');
      expect(authorization, 'Bearer token-123');
      expect(requestBody, isNotNull);
      expect(requestBody?['install_id'], 'uuid-per-install');
      expect(requestBody?['platform'], 'android');
      expect(requestBody?['channel'], 'stable');
      expect(requestBody?['app_version'], '1.2.3');
      expect(requestBody?['visit_count'], 1);
      expect(requestBody?['visit_seconds'], 120);
      expect(requestBody?['occurred_at'], '2026-03-15T08:00:00Z');
      expect(requestBody?.containsKey('user_id'), isFalse);

      await server.close(force: true);
    });

    test('omits bearer token when user is not logged in', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

      String? authorization;

      server.listen((request) async {
        authorization = request.headers.value(HttpHeaders.authorizationHeader);
        request.response.statusCode = 200;
        request.response.write(
          jsonEncode({
            'code': 'OK',
            'message': 'success',
            'data': {
              'open_event': {'id': 'evt_open_xxx'},
              'visit_event': {'id': 'evt_visit_xxx'},
            },
          }),
        );
        await request.response.close();
      });

      final service = AnalyticsService(
        baseUrl: 'http://${server.address.host}:${server.port}',
        identityService: _FakeDeviceIdentityService(),
        sessionStore: AuthSessionStore(preferences: prefs),
      );

      await service.trackVisit(occurredAt: DateTime.utc(2026, 3, 15, 8));

      expect(authorization, isNull);

      await server.close(force: true);
    });
  });
}

class _FakeDeviceIdentityService extends DeviceIdentityService {
  @override
  Future<DeviceIdentity> loadIdentity() async {
    return const DeviceIdentity(
      installId: 'uuid-per-install',
      deviceUid: 'hashed-device-id',
      platform: 'android',
      deviceBrand: 'xiaomi',
      deviceModel: '2304FPN6DC',
      osVersion: '14',
      appVersion: '1.2.3',
    );
  }
}
