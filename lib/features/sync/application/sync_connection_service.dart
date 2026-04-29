import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../../core/logging/app_logger.dart';
import '../data/local/sync_local_store.dart';
import '../data/remote/webdav_sync_remote_driver.dart';
import '../domain/sync_job.dart';
import '../domain/sync_profile.dart';
import 'sync_profile_service.dart';
import 'sync_remote_bootstrap_service.dart';

class SyncConnectionTestResult {
  const SyncConnectionTestResult({
    required this.job,
    required this.succeeded,
    required this.message,
  });

  final SyncJob job;
  final bool succeeded;
  final String message;
}

class SyncConnectionService {
  SyncConnectionService({
    required SyncProfileService profileService,
    required SyncLocalStore localStore,
    required SyncRemoteBootstrapService remoteBootstrapService,
    AppLogger? logger,
    Uuid? uuid,
  }) : _profileService = profileService,
       _localStore = localStore,
       _remoteBootstrapService = remoteBootstrapService,
       _logger = logger ?? AppLogger.instance,
       _uuid = uuid ?? const Uuid();

  final SyncProfileService _profileService;
  final SyncLocalStore _localStore;
  final SyncRemoteBootstrapService _remoteBootstrapService;
  final AppLogger _logger;
  final Uuid _uuid;

  Stream<List<SyncJob>> watchJobs({String? profileId}) {
    return _localStore.watchJobs(profileId: profileId);
  }

  Future<SyncConnectionTestResult> testProfileConnection(
    String profileId,
  ) async {
    final profile = await _profileService.getProfileById(profileId);
    if (profile == null) {
      throw const FormatException('未找到要测试的同步配置。');
    }
    final secretRef = profile.secretRef?.trim() ?? '';
    if (secretRef.isEmpty) {
      throw const FormatException('同步配置缺少安全凭据引用。');
    }
    final password = await _profileService.loadPassword(secretRef);
    if (password == null || password.isEmpty) {
      throw const FormatException('未找到同步配置对应的密码。');
    }
    return _runConnectionTest(profile: profile, password: password);
  }

  Future<SyncConnectionTestResult> testDraft({
    required String endpointUrl,
    required String basePath,
    required String username,
    required String password,
  }) async {
    final now = DateTime.now().toUtc();
    final profile = SyncProfile(
      id: 'draft',
      name: 'draft',
      driverType: SyncDriverType.webdav,
      endpointUrl: endpointUrl.trim(),
      basePath: basePath.trim(),
      username: username.trim(),
      createdAt: now,
      updatedAt: now,
    );
    final job = SyncJob(
      id: 'draft_job_${_uuid.v4()}',
      profileId: profile.id,
      triggerKind: SyncJobTriggerKind.manual,
      status: SyncJobStatus.running,
      startedAt: now,
    );
    try {
      final driver = WebDavSyncRemoteDriver(
        endpointUrl: profile.endpointUrl,
        basePath: profile.basePath,
        username: profile.username,
        password: password,
      );
      await _remoteBootstrapService.ensureWebDavReady(
        profile: profile,
        driver: driver,
      );
      final completed = job.copyWith(
        status: SyncJobStatus.success,
        endedAt: DateTime.now().toUtc(),
        summaryJson: jsonEncode(<String, Object?>{
          'endpointUrl': profile.endpointUrl,
          'draft': true,
        }),
      );
      return SyncConnectionTestResult(
        job: completed,
        succeeded: true,
        message: '草稿连接成功，远端目录与 manifest 已可访问。',
      );
    } catch (error) {
      _logger.error(
        'Draft sync connection test failed',
        context: <String, Object?>{'endpointUrl': profile.endpointUrl},
      );
      return SyncConnectionTestResult(
        job: job.copyWith(
          status: SyncJobStatus.failed,
          endedAt: DateTime.now().toUtc(),
          errorMessage: error.toString(),
        ),
        succeeded: false,
        message: '草稿连接失败：$error',
      );
    }
  }

  Future<SyncConnectionTestResult> _runConnectionTest({
    required SyncProfile profile,
    required String password,
  }) async {
    final runningJob = SyncJob(
      id: 'sync_job_${_uuid.v4()}',
      profileId: profile.id,
      triggerKind: SyncJobTriggerKind.manual,
      status: SyncJobStatus.running,
      startedAt: DateTime.now().toUtc(),
    );
    await _localStore.saveJob(runningJob);

    try {
      final driver = WebDavSyncRemoteDriver(
        endpointUrl: profile.endpointUrl,
        basePath: profile.basePath,
        username: profile.username,
        password: password,
      );
      await _remoteBootstrapService.ensureWebDavReady(
        profile: profile,
        driver: driver,
      );
      final completed = runningJob.copyWith(
        status: SyncJobStatus.success,
        endedAt: DateTime.now().toUtc(),
        summaryJson: jsonEncode(<String, Object?>{
          'driverType': profile.driverType.name,
          'endpointUrl': profile.endpointUrl,
          'basePath': profile.basePath,
        }),
      );
      await _localStore.saveJob(completed);
      await _localStore.saveProfile(
        profile.copyWith(
          lastSyncAt: completed.endedAt,
          updatedAt: completed.endedAt ?? DateTime.now().toUtc(),
        ),
      );
      return SyncConnectionTestResult(
        job: completed,
        succeeded: true,
        message: '连接成功，已确认远端目录并写入最小 manifest。',
      );
    } catch (error) {
      final failed = runningJob.copyWith(
        status: SyncJobStatus.failed,
        endedAt: DateTime.now().toUtc(),
        errorMessage: error.toString(),
      );
      await _localStore.saveJob(failed);
      _logger.warn(
        'Sync profile connection test failed',
        context: <String, Object?>{
          'profileId': profile.id,
          'endpointUrl': profile.endpointUrl,
          'error': error.toString(),
        },
      );
      return SyncConnectionTestResult(
        job: failed,
        succeeded: false,
        message: '连接失败：$error',
      );
    }
  }
}
