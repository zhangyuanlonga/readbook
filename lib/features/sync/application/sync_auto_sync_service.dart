import 'dart:async';

import '../domain/sync_scope.dart';
import 'sync_profile_service.dart';
import 'sync_stage4_service.dart';

class SyncAutoSyncService {
  SyncAutoSyncService({
    required SyncProfileService profileService,
    required SyncStage4Service syncService,
  }) : _profileService = profileService,
       _syncService = syncService;

  final SyncProfileService _profileService;
  final SyncStage4Service _syncService;

  bool _running = false;
  DateTime? _lastRunAt;
  static const Duration _minimumInterval = Duration(minutes: 2);

  Future<void> handleAppResumed() async {
    if (_running) {
      return;
    }
    final now = DateTime.now();
    final last = _lastRunAt;
    if (last != null && now.difference(last) < _minimumInterval) {
      return;
    }
    _running = true;
    try {
      final profiles = await _profileService.listProfiles();
      for (final profile in profiles) {
        if (!profile.isAutoSyncEnabled) {
          continue;
        }
        if (!profile.enabledScopes.any(_supportsAutoSync)) {
          continue;
        }
        try {
          await _syncService.run(profile.id);
        } catch (_) {
          // Ignore individual auto-sync failures on resume.
        }
      }
      _lastRunAt = now;
    } finally {
      _running = false;
    }
  }

  bool _supportsAutoSync(SyncScope scope) {
    return switch (scope) {
      SyncScope.authSession ||
      SyncScope.sourceLoginState ||
      SyncScope.bookCustomState ||
      SyncScope.discoverCacheSnapshots ||
      SyncScope.sourceHealthSnapshots ||
      SyncScope.sourceRuntimeDiagnostics ||
      SyncScope.searchSourceHits ||
      SyncScope.chapterCaches ||
      SyncScope.localBooks ||
      SyncScope.localChapters ||
      SyncScope.localLibraryFiles => false,
      _ => true,
    };
  }
}
