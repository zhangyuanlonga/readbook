import 'dart:convert';

import '../../../core/device/device_identity_service.dart';
import '../domain/sync_profile.dart';
import '../domain/sync_remote_driver.dart';

class SyncRemoteBootstrapService {
  SyncRemoteBootstrapService({
    required DeviceIdentityService deviceIdentityService,
  }) : _deviceIdentityService = deviceIdentityService;

  final DeviceIdentityService _deviceIdentityService;

  Future<void> ensureWebDavReady({
    required SyncProfile profile,
    required SyncRemoteDriver driver,
  }) async {
    await driver.ensureReady();
    await driver.ensureDirectory('datasets');
    await driver.ensureDirectory('logs');
    final existingManifest = await driver.readText('manifest.json');
    if ((existingManifest ?? '').trim().isNotEmpty) {
      return;
    }

    final identity = await _deviceIdentityService.loadIdentity();
    final payload = <String, Object?>{
      'schemaVersion': 1,
      'app': 'selune',
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
      'updatedBy': <String, Object?>{
        'installId': identity.installId,
        'platform': identity.platform,
        'appVersion': identity.appVersion,
      },
      'profile': <String, Object?>{
        'id': profile.id,
        'name': profile.name,
        'driverType': profile.driverType.name,
      },
      'datasets': <String, Object?>{},
    };
    await driver.writeText('manifest.json', jsonEncode(payload));
  }
}
