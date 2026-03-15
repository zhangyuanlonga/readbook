class DeviceIdentity {
  const DeviceIdentity({
    required this.installId,
    required this.deviceUid,
    required this.platform,
    required this.deviceBrand,
    required this.deviceModel,
    required this.osVersion,
    required this.appVersion,
  });

  final String installId;
  final String deviceUid;
  final String platform;
  final String deviceBrand;
  final String deviceModel;
  final String osVersion;
  final String appVersion;

  Map<String, dynamic> toHeartbeatPayload() {
    return {
      'install_id': installId,
      'device_uid': deviceUid,
      'platform': platform,
      'device_brand': deviceBrand,
      'device_model': deviceModel,
      'os_version': osVersion,
      'app_version': appVersion,
    };
  }
}
