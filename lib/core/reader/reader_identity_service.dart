import 'package:shared_preferences/shared_preferences.dart';

import '../device/device_identity_service.dart';
import '../errors/app_exception.dart';
import '../errors/error_codes.dart';
import '../errors/error_stage.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import 'reader_identity.dart';

class ReaderIdentityService {
  ReaderIdentityService({
    ApiClient? client,
    String? baseUrl,
    DeviceIdentityService? identityService,
    SharedPreferences? preferences,
  }) : _baseUrl = (baseUrl ?? AppApiConfig.baseUrl).trim(),
       _client =
           client ?? ApiClient(baseUrl: (baseUrl ?? AppApiConfig.baseUrl).trim()),
       _identityService = identityService ?? DeviceIdentityService(),
       _preferencesFuture =
           preferences == null
               ? SharedPreferences.getInstance()
               : Future.value(preferences);

  static const String _readerIdKey = 'reader.id';

  final ApiClient _client;
  final String _baseUrl;
  final DeviceIdentityService _identityService;
  final Future<SharedPreferences> _preferencesFuture;

  Future<ReaderIdentity?> getCachedIdentity() async {
    final prefs = await _preferencesFuture;
    final readerId = (prefs.getString(_readerIdKey) ?? '').trim();
    if (readerId.isEmpty) {
      return null;
    }
    return ReaderIdentity(id: readerId);
  }

  Future<ReaderIdentity> register({String? installId}) async {
    _ensureBaseUrl();
    final resolvedInstallId =
        (installId == null || installId.trim().isEmpty)
            ? await _identityService.getInstallId()
            : installId.trim();

    final data = await _client.request<Map<String, dynamic>>(
      method: ApiMethod.post,
      path: '/v1/readers/register',
      body: {'install_id': resolvedInstallId},
      attachAccessToken: true,
      stage: ErrorStage.unknown,
      decoder: _decodeMap,
    );

    final identity = _parseIdentity(data);
    await _persistIdentity(identity);
    return identity;
  }

  Future<ReaderIdentity> ensureRegistered({String? installId}) async {
    final cached = await getCachedIdentity();
    if (cached != null) {
      return cached;
    }
    return register(installId: installId);
  }

  Future<void> _persistIdentity(ReaderIdentity identity) async {
    final prefs = await _preferencesFuture;
    await prefs.setString(_readerIdKey, identity.id);
  }

  void _ensureBaseUrl() {
    if (_baseUrl.isNotEmpty) {
      return;
    }
    throw const AppException(
      code: ErrorCode.validation,
      briefMessage: '缺少读者服务地址，请配置 APPREAD_API_BASE_URL。',
      stage: ErrorStage.unknown,
    );
  }

  Map<String, dynamic> _decodeMap(Object? data) {
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    throw const FormatException('Invalid response payload.');
  }

  ReaderIdentity _parseIdentity(Map<String, dynamic> data) {
    Map<String, dynamic> asMap(Object? value) {
      if (value is Map) {
        return value.map((key, value) => MapEntry(key.toString(), value));
      }
      return const <String, dynamic>{};
    }

    String? asString(Object? value) {
      final raw = value?.toString().trim() ?? '';
      return raw.isEmpty ? null : raw;
    }

    final readerMap = asMap(data['reader']);
    final readerId =
        asString(readerMap['id']) ??
        asString(readerMap['reader_id']) ??
        asString(data['reader_id']) ??
        asString(data['id']);

    if (readerId == null) {
      throw const FormatException('Missing reader id in response.');
    }

    return ReaderIdentity(id: readerId);
  }
}
