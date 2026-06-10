import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_logger.dart';
import '../device/device_identity_service.dart';
import 'auth_session_store.dart';

class AuthInstallRecoveryService {
  AuthInstallRecoveryService({
    SharedPreferences? preferences,
    AuthSessionStore? sessionStore,
    AppLogger? logger,
  }) : _preferencesFuture =
           preferences == null
               ? SharedPreferences.getInstance()
               : Future.value(preferences),
       _sessionStore =
           sessionStore ?? AuthSessionStore(preferences: preferences),
       _logger = logger ?? AppLogger.instance;

  final Future<SharedPreferences> _preferencesFuture;
  final AuthSessionStore _sessionStore;
  final AppLogger _logger;

  Future<bool> clearAuthStateIfFreshInstall() async {
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      return false;
    }

    final prefs = await _preferencesFuture;
    final installId =
        (prefs.getString(DeviceIdentityService.installIdKey) ?? '').trim();
    if (installId.isNotEmpty) {
      return false;
    }

    await _sessionStore.clear();
    _logger.info(
      'Fresh install auth recovery cleared persisted session state',
      context: const <String, Object?>{'platform': 'mobile'},
    );
    return true;
  }
}
