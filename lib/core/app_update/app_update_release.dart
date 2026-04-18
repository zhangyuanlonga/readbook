class AppUpdateReleaseDownload {
  const AppUpdateReleaseDownload({
    required this.platform,
    required this.label,
    required this.downloadUrl,
    required this.fileName,
  });

  final String? platform;
  final String? label;
  final String? downloadUrl;
  final String? fileName;

  factory AppUpdateReleaseDownload.fromJson(Map<String, dynamic> json) {
    String? readString(String key) {
      final value = json[key]?.toString().trim() ?? '';
      return value.isEmpty ? null : value;
    }

    return AppUpdateReleaseDownload(
      platform: readString('platform'),
      label: readString('label'),
      downloadUrl: readString('download_url'),
      fileName: readString('file_name'),
    );
  }
}

class AppUpdateRelease {
  const AppUpdateRelease({
    required this.id,
    required this.appName,
    required this.versionName,
    required this.versionCode,
    required this.forceUpdate,
    required this.downloadUrl,
    required this.downloads,
    required this.changelog,
  });

  final String? id;
  final String? appName;
  final String? versionName;
  final int? versionCode;
  final bool? forceUpdate;
  final String? downloadUrl;
  final List<AppUpdateReleaseDownload> downloads;
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

    List<AppUpdateReleaseDownload> readDownloads(String key) {
      final value = json[key];
      if (value is! List) {
        return const [];
      }
      return value
          .whereType<Map>()
          .map(
            (item) => AppUpdateReleaseDownload.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false);
    }

    return AppUpdateRelease(
      id: readString('id'),
      appName: readString('app_name'),
      versionName: readString('version_name'),
      versionCode: readInt('version_code'),
      forceUpdate: readBool('force_update'),
      downloadUrl: readString('download_url'),
      downloads: readDownloads('downloads'),
      changelog: readString('changelog'),
    );
  }
}
