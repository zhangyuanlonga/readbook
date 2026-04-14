import '../device/device_identity_service.dart';
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
    return MembershipEntitlement.fromJson({
      'vip_level': data['vip_level'],
      'vip_status': 'active',
      'plan_type': data['plan_type'],
      'expire_at': data['expire_at'],
      'source': data['source'],
      'is_trial': data['is_trial'],
      'max_devices': data['max_devices'],
      'features': data['features'],
    });
  }

  Future<MembershipSeatSyncResult> syncCurrentDeviceSeat() async {
    _ensureBaseUrl();
    final identity = await _identityService.loadIdentity();
    final data = await _client.request<Map<String, dynamic>>(
      method: ApiMethod.post,
      path: '/v1/me/device-seats/sync',
      attachAccessToken: true,
      stage: ErrorStage.unknown,
      body: {
        'install_id': identity.installId,
        'device_uid': identity.deviceUid,
        'device_fingerprint': identity.deviceFingerprint,
      },
      decoder: _decodeMap,
    );
    return MembershipSeatSyncResult.fromJson(data);
  }

  Future<List<MembershipDeviceSeat>> fetchDeviceSeats() async {
    _ensureBaseUrl();
    final data = await _client.request<Map<String, dynamic>>(
      method: ApiMethod.get,
      path: '/v1/me/device-seats',
      attachAccessToken: true,
      stage: ErrorStage.unknown,
      decoder: _decodeMap,
    );

    final rawItems = data['items'];
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

    await _client.request<Map<String, dynamic>>(
      method: ApiMethod.delete,
      path: '/v1/me/device-seats/$normalized',
      attachAccessToken: true,
      stage: ErrorStage.unknown,
      decoder: _decodeMap,
    );
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
}
