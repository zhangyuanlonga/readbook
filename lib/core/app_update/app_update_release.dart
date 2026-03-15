class AppUpdateRelease {
  const AppUpdateRelease({
    required this.versionName,
    required this.versionCode,
    required this.minSupportedCode,
    required this.forceUpdate,
    required this.rolloutPercent,
    required this.storeUrl,
    required this.downloadUrl,
    required this.changelog,
  });

  final String? versionName;
  final int? versionCode;
  final int? minSupportedCode;
  final bool? forceUpdate;
  final int? rolloutPercent;
  final String? storeUrl;
  final String? downloadUrl;
  final String? changelog;

  factory AppUpdateRelease.fromJson(Map<String, dynamic> json) {
    int? readInt(String key) {
      final value = json[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        return int.tryParse(value.trim());
      }
      return null;
    }

    bool? readBool(String key) {
      final value = json[key];
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') {
          return true;
        }
        if (normalized == 'false' || normalized == '0') {
          return false;
        }
      }
      return null;
    }

    String? readString(String key) {
      final value = json[key]?.toString().trim() ?? '';
      return value.isEmpty ? null : value;
    }

    return AppUpdateRelease(
      versionName: readString('version_name'),
      versionCode: readInt('version_code'),
      minSupportedCode: readInt('min_supported_code'),
      forceUpdate: readBool('force_update'),
      rolloutPercent: readInt('rollout_percent'),
      storeUrl: readString('store_url'),
      downloadUrl: readString('download_url'),
      changelog: readString('changelog'),
    );
  }
}
