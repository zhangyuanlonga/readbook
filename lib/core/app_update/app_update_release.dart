class AppUpdateRelease {
  const AppUpdateRelease({
    required this.id,
    required this.appName,
    required this.versionName,
    required this.versionCode,
    required this.forceUpdate,
    required this.downloadUrl,
    required this.changelog,
  });

  final String? id;
  final String? appName;
  final String? versionName;
  final int? versionCode;
  final bool? forceUpdate;
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
      id: readString('id'),
      appName: readString('app_name'),
      versionName: readString('version_name'),
      versionCode: readInt('version_code'),
      forceUpdate: readBool('force_update'),
      downloadUrl: readString('download_url'),
      changelog: readString('changelog'),
    );
  }
}
