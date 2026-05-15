import '../device/device_identity_service.dart';
import '../device/device_identity.dart';
import '../errors/app_exception.dart';
import '../errors/error_codes.dart';
import '../errors/error_stage.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import 'membership_device_seat.dart';
import 'membership_entitlement.dart';
import 'membership_seat_sync_result.dart';

class MembershipService {
  MembershipService({
    ApiClient? client,
    String? baseUrl,
    DeviceIdentityService? identityService,
  }) : _baseUrl = (baseUrl ?? AppApiConfig.baseUrl).trim(),
       _client =
           client ??
           ApiClient(baseUrl: (baseUrl ?? AppApiConfig.baseUrl).trim()),
       _identityService = identityService ?? DeviceIdentityService();

  final ApiClient _client;
  final String _baseUrl;
  final DeviceIdentityService _identityService;

  Future<MembershipEntitlement> fetchEntitlement() async {
    _ensureBaseUrl();
    final data = await _client.request<Map<String, dynamic>>(
      method: ApiMethod.get,
      path: '/v1/entitlements/me',
      attachAccessToken: true,
      stage: ErrorStage.unknown,
      decoder: _decodeMap,
    );
    return MembershipEntitlement.fromJson(data);
  }

  Future<MembershipEntitlement> redeemActivationCode(String code) async {
    _ensureBaseUrl();
    final normalized = code.trim();
    if (normalized.isEmpty) {
      throw const AppException(
        code: ErrorCode.validation,
        briefMessage: '请输入许可证码。',
        stage: ErrorStage.unknown,
      );
    }

    final identity = await _identityService.loadIdentity();
    final data = await _client.request<Map<String, dynamic>>(
      method: ApiMethod.post,
      path: '/v1/activation-codes/redeem',
      attachAccessToken: true,
      stage: ErrorStage.unknown,
      body: {
        'code': normalized,
        'install_id': identity.installId,
        'device_uid': identity.deviceUid,
        'device_fingerprint': identity.deviceFingerprint,
      },
      decoder: _decodeMap,
    );
    return MembershipEntitlement.fromJson(_extractEntitlementPayload(data));
  }

  Future<MembershipEntitlement> claimTrialMembership({
    String trialType = 'new_user_7d',
  }) async {
    _ensureBaseUrl();
    final normalizedTrialType = trialType.trim();
    if (normalizedTrialType.isEmpty) {
      throw const AppException(
        code: ErrorCode.validation,
        briefMessage: '缺少试用类型配置。',
        stage: ErrorStage.unknown,
      );
    }

    final identity = await _identityService.loadIdentity();
    try {
      final data = await _client.request<Map<String, dynamic>>(
        method: ApiMethod.post,
        path: '/v1/trials/claim',
        attachAccessToken: true,
        stage: ErrorStage.unknown,
        body: {
          'trial_type': normalizedTrialType,
          'install_id': identity.installId,
          'device_uid': identity.deviceUid,
          'device_fingerprint': identity.deviceFingerprint,
        },
        decoder: _decodeMap,
      );
      return MembershipEntitlement.fromJson(_extractEntitlementPayload(data));
    } on ApiException catch (error) {
      if (error.apiCode == 'TRIAL_ALREADY_CLAIMED') {
        throw const AppException(
          code: ErrorCode.validation,
          briefMessage: '当前账号已领取过试用会员，可通过许可证继续开通正式会员。',
          stage: ErrorStage.unknown,
        );
      }
      rethrow;
    }
  }

  Future<MembershipSeatSyncResult> syncCurrentDeviceSeat() async {
    _ensureBaseUrl();
    final identity = await _identityService.loadIdentity();
    final payload = <String, dynamic>{
      'install_id': identity.installId,
      'device_uid': identity.deviceUid,
      'device_fingerprint': identity.deviceFingerprint,
    };
    final data = await _requestWithLegacyFallback(
      method: ApiMethod.post,
      primaryPath: '/v1/me/device-seats/sync',
      legacyPath: '/v1/me/devices/activate',
      attachAccessToken: true,
      stage: ErrorStage.unknown,
      body: payload,
    );
    return MembershipSeatSyncResult.fromJson(_extractSeatSyncPayload(data));
  }

  Future<List<MembershipDeviceSeat>> fetchDeviceSeats() async {
    _ensureBaseUrl();
    final data = await _requestWithLegacyFallback(
      method: ApiMethod.get,
      primaryPath: '/v1/me/device-seats',
      legacyPath: '/v1/me/devices',
      attachAccessToken: true,
      stage: ErrorStage.unknown,
    );

    final rawItems = _extractSeatItems(data);
    if (rawItems is! List) {
      return const <MembershipDeviceSeat>[];
    }
    return rawItems
        .whereType<Map>()
        .map(
          (item) => MembershipDeviceSeat.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  Future<void> releaseSeat(String seatId) async {
    _ensureBaseUrl();
    final normalized = seatId.trim();
    if (normalized.isEmpty) {
      throw const AppException(
        code: ErrorCode.validation,
        briefMessage: '缺少设备席位标识。',
        stage: ErrorStage.unknown,
      );
    }

    await _requestWithLegacyFallback(
      method: ApiMethod.delete,
      primaryPath: '/v1/me/device-seats/$normalized',
      legacyPath: '/v1/me/devices/$normalized',
      attachAccessToken: true,
      stage: ErrorStage.unknown,
    );
  }

  Future<DeviceIdentity> loadCurrentDeviceIdentity() {
    return _identityService.loadIdentity();
  }

  bool currentDeviceHasActiveSeat(
    List<MembershipDeviceSeat> seats,
    DeviceIdentity identity,
  ) {
    return seats.any((seat) {
      if (!seat.isActive) {
        return false;
      }
      return seat.installId == identity.installId ||
          (seat.deviceUid != null && seat.deviceUid == identity.deviceUid) ||
          (seat.deviceFingerprint != null &&
              seat.deviceFingerprint == identity.deviceFingerprint);
    });
  }

  void _ensureBaseUrl() {
    if (_baseUrl.isNotEmpty) {
      return;
    }
    throw const AppException(
      code: ErrorCode.validation,
      briefMessage: '缺少会员服务地址，请配置 APPREAD_API_BASE_URL。',
      stage: ErrorStage.unknown,
    );
  }

  Map<String, dynamic> _decodeMap(Object? data) {
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _requestWithLegacyFallback({
    required ApiMethod method,
    required String primaryPath,
    required String legacyPath,
    required bool attachAccessToken,
    required ErrorStage stage,
    Object? body,
  }) async {
    try {
      return await _client.request<Map<String, dynamic>>(
        method: method,
        path: primaryPath,
        attachAccessToken: attachAccessToken,
        stage: stage,
        body: body,
        decoder: _decodeMap,
      );
    } on ApiException catch (error) {
      if (!_shouldFallbackToLegacyEndpoint(error)) {
        rethrow;
      }
    }

    return _client.request<Map<String, dynamic>>(
      method: method,
      path: legacyPath,
      attachAccessToken: attachAccessToken,
      stage: stage,
      body: body,
      decoder: _decodeMap,
    );
  }

  bool _shouldFallbackToLegacyEndpoint(ApiException error) {
    return error.statusCode == 404 || error.apiCode == 'NOT_FOUND';
  }

  Map<String, dynamic> _extractEntitlementPayload(Map<String, dynamic> data) {
    final nested =
        _readNestedMap(data['entitlement']) ??
        _readNestedMap(data['membership']) ??
        _readNestedMap(data['benefit']) ??
        _readNestedMap(data['result']);
    final source = nested ?? data;

    return <String, dynamic>{
      'vip_level': source['vip_level'] ?? data['vip_level'],
      'membership_level':
          source['membership_level'] ?? data['membership_level'],
      'vip_status': source['vip_status'] ?? data['vip_status'] ?? 'active',
      'plan_type': source['plan_type'] ?? data['plan_type'],
      'expire_at': source['expire_at'] ?? data['expire_at'],
      'source': source['source'] ?? data['source'],
      'grant_type': source['grant_type'] ?? data['grant_type'],
      'grant_subtype': source['grant_subtype'] ?? data['grant_subtype'],
      'grant_label': source['grant_label'] ?? data['grant_label'],
      'is_custom_expire':
          source['is_custom_expire'] ?? data['is_custom_expire'],
      'is_trial': source['is_trial'] ?? data['is_trial'],
      'max_devices': source['max_devices'] ?? data['max_devices'],
      'features': source['features'] ?? data['features'],
    };
  }

  Map<String, dynamic> _extractSeatSyncPayload(Map<String, dynamic> data) {
    return _readNestedMap(data['seat_sync']) ??
        _readNestedMap(data['device']) ??
        _readNestedMap(data['result']) ??
        data;
  }

  Object? _extractSeatItems(Map<String, dynamic> data) {
    return data['items'] ?? data['seats'] ?? data['devices'];
  }

  Map<String, dynamic>? _readNestedMap(Object? value) {
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }
}
