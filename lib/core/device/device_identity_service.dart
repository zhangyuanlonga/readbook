import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'device_identity.dart';

class DeviceIdentityService {
  DeviceIdentityService({
    SharedPreferences? preferences,
    DeviceInfoPlugin? deviceInfo,
    Uuid? uuid,
  }) : _preferencesFuture =
           preferences == null
               ? SharedPreferences.getInstance()
               : Future.value(preferences),
       _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
       _uuid = uuid ?? const Uuid();

  static const String _installIdKey = 'app.install_id';

  final Future<SharedPreferences> _preferencesFuture;
  final DeviceInfoPlugin _deviceInfo;
  final Uuid _uuid;
  DeviceIdentity? _cachedIdentity;
  Future<DeviceIdentity>? _identityFuture;

  Future<String> getInstallId() async {
    final prefs = await _preferencesFuture;
    final cached = (prefs.getString(_installIdKey) ?? '').trim();
    if (cached.isNotEmpty) {
      return cached;
    }
    final generated = _uuid.v4();
    await prefs.setString(_installIdKey, generated);
    return generated;
  }

  Future<int> getAppVersionCode() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return normalizeVersionCode(
        versionName: info.version,
        buildNumber: info.buildNumber,
      );
    } catch (_) {
      return 0;
    }
  }

  Future<String> getAppVersionName() async {
    return _resolveAppVersion();
  }

  Future<DeviceIdentity> loadIdentity() async {
    final cached = _cachedIdentity;
    if (cached != null) {
      return cached;
    }
    final pending = _identityFuture;
    if (pending != null) {
      return pending;
    }

    final future = _loadIdentityInternal();
    _identityFuture = future;
    return future;
  }

  Future<DeviceIdentity> _loadIdentityInternal() async {
    try {
      final installId = await getInstallId();
      final platform = _platformLabel();
      final info = await _resolveDeviceInfo();
      final appVersion = await _resolveAppVersion();
      final deviceUid = _hashDeviceUid(
        platform: platform,
        hardwareId: info.hardwareId,
        fallback: installId,
      );

      final identity = DeviceIdentity(
        installId: installId,
        deviceUid: deviceUid,
        platform: platform,
        deviceBrand: _nonEmpty(info.brand, 'unknown'),
        deviceModel: _nonEmpty(info.model, 'unknown'),
        osVersion: _nonEmpty(info.osVersion, 'unknown'),
        appVersion: _nonEmpty(appVersion, 'unknown'),
      );
      _cachedIdentity = identity;
      return identity;
    } finally {
      _identityFuture = null;
    }
  }

  String _platformLabel() {
    if (kIsWeb) {
      return 'web';
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  Future<_ResolvedDeviceInfo> _resolveDeviceInfo() async {
    if (kIsWeb) {
      final web = await _deviceInfo.webBrowserInfo;
      return _ResolvedDeviceInfo(
        brand: 'web',
        model: _nonEmpty(web.browserName.name, 'browser'),
        osVersion: _nonEmpty(web.userAgent, web.appVersion ?? 'web'),
        hardwareId: web.userAgent,
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final info = await _deviceInfo.androidInfo;
        final hardwareId = _firstNonEmpty([
          info.serialNumber,
          info.id,
          info.fingerprint,
        ]);
        return _ResolvedDeviceInfo(
          brand: info.brand,
          model: info.model,
          osVersion: info.version.release,
          hardwareId: hardwareId,
        );
      case TargetPlatform.iOS:
        final info = await _deviceInfo.iosInfo;
        return _ResolvedDeviceInfo(
          brand: 'Apple',
          model: info.utsname.machine,
          osVersion: info.systemVersion,
          hardwareId: info.identifierForVendor,
        );
      case TargetPlatform.macOS:
        final info = await _deviceInfo.macOsInfo;
        return _ResolvedDeviceInfo(
          brand: 'Apple',
          model: info.model,
          osVersion: info.osRelease,
          hardwareId: info.systemGUID,
        );
      case TargetPlatform.windows:
        final info = await _deviceInfo.windowsInfo;
        return _ResolvedDeviceInfo(
          brand: 'Microsoft',
          model: info.productName,
          osVersion: info.releaseId,
          hardwareId: info.deviceId,
        );
      case TargetPlatform.linux:
        final info = await _deviceInfo.linuxInfo;
        return _ResolvedDeviceInfo(
          brand: info.name,
          model: info.prettyName,
          osVersion: info.version,
          hardwareId: info.machineId,
        );
      case TargetPlatform.fuchsia:
        final info = await _deviceInfo.deviceInfo;
        return _ResolvedDeviceInfo(
          brand: 'fuchsia',
          model: info.data['name']?.toString(),
          osVersion: info.data['buildVersion']?.toString(),
          hardwareId: info.data['id']?.toString(),
        );
    }
  }

  Future<String> _resolveAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version.trim();
    } catch (_) {
      return '';
    }
  }

  String _hashDeviceUid({
    required String platform,
    required String? hardwareId,
    required String fallback,
  }) {
    final raw = '${platform.trim()}|${(hardwareId ?? '').trim()}';
    final normalized = raw.trim().isEmpty ? fallback.trim() : raw.trim();
    final digest = sha256.convert(utf8.encode(normalized));
    return digest.toString();
  }

  String _nonEmpty(String? value, String fallback) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? fallback : normalized;
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final normalized = value?.trim() ?? '';
      if (normalized.isNotEmpty && normalized.toLowerCase() != 'unknown') {
        return normalized;
      }
    }
    return null;
  }

  static int normalizeVersionCode({
    required String versionName,
    String? buildNumber,
  }) {
    final normalizedVersion = versionName.trim();
    final normalizedBuild = buildNumber?.trim() ?? '';
    final buildCode = int.tryParse(normalizedBuild) ?? 0;

    final match = RegExp(
      r'^(\d+)(?:\.(\d+))?(?:\.(\d+))?',
    ).firstMatch(normalizedVersion);
    if (match == null) {
      return buildCode;
    }

    final major = int.tryParse(match.group(1) ?? '') ?? 0;
    final minor = int.tryParse(match.group(2) ?? '') ?? 0;
    final patch = int.tryParse(match.group(3) ?? '') ?? 0;
    final semanticCode = (major * 10000) + (minor * 100) + patch;
    if (semanticCode <= 0) {
      return buildCode;
    }
    return semanticCode >= buildCode ? semanticCode : buildCode;
  }
}

class _ResolvedDeviceInfo {
  const _ResolvedDeviceInfo({
    required this.brand,
    required this.model,
    required this.osVersion,
    required this.hardwareId,
  });

  final String? brand;
  final String? model;
  final String? osVersion;
  final String? hardwareId;
}
