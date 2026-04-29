import 'package:uuid/uuid.dart';

import '../data/local/sync_local_store.dart';
import '../data/local/sync_secret_store.dart';
import '../domain/sync_profile.dart';
import '../domain/sync_scope.dart';

class SyncProfileService {
  SyncProfileService({
    required SyncLocalStore localStore,
    required SyncSecretStore secretStore,
    Uuid? uuid,
  }) : _localStore = localStore,
       _secretStore = secretStore,
       _uuid = uuid ?? const Uuid();

  final SyncLocalStore _localStore;
  final SyncSecretStore _secretStore;
  final Uuid _uuid;

  Stream<List<SyncProfile>> watchProfiles() => _localStore.watchProfiles();

  Future<List<SyncProfile>> listProfiles() => _localStore.listProfiles();

  Future<SyncProfile?> getProfileById(String id) =>
      _localStore.getProfileById(id);

  Future<String?> loadPassword(String secretRef) {
    return _secretStore.readSecret(secretRef);
  }

  Future<SyncProfile> saveProfile({
    String? profileId,
    required String name,
    required String endpointUrl,
    required String basePath,
    required String username,
    required String password,
    List<SyncScope> enabledScopes = const <SyncScope>[],
    bool isAutoSyncEnabled = false,
  }) async {
    final normalizedName = name.trim().isEmpty ? 'WebDAV 同步' : name.trim();
    final normalizedEndpointUrl = endpointUrl.trim();
    final normalizedBasePath = basePath.trim();
    final normalizedUsername = username.trim();
    if (normalizedEndpointUrl.isEmpty ||
        normalizedBasePath.isEmpty ||
        normalizedUsername.isEmpty) {
      throw const FormatException('保存同步配置前，地址、根目录和用户名不能为空。');
    }

    final now = DateTime.now().toUtc();
    final resolvedId =
        (profileId?.trim().isNotEmpty ?? false)
            ? profileId!.trim()
            : 'sync_profile_${_uuid.v4()}';
    final existing = await _localStore.getProfileById(resolvedId);
    final secretRef =
        existing?.secretRef?.trim().isNotEmpty == true
            ? existing!.secretRef!.trim()
            : 'sync.secret.$resolvedId';

    final profile = SyncProfile(
      id: resolvedId,
      name: normalizedName,
      driverType: SyncDriverType.webdav,
      endpointUrl: normalizedEndpointUrl,
      basePath: normalizedBasePath,
      username: normalizedUsername,
      secretRef: secretRef,
      enabledScopes: List<SyncScope>.unmodifiable(enabledScopes),
      isAutoSyncEnabled: isAutoSyncEnabled,
      lastSyncAt: existing?.lastSyncAt,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _localStore.saveProfile(profile);
    await _secretStore.writeSecret(secretRef: secretRef, secret: password);
    return profile;
  }

  Future<void> deleteProfile(String id) async {
    final existing = await _localStore.getProfileById(id);
    await _localStore.deleteProfile(id);
    final secretRef = existing?.secretRef?.trim() ?? '';
    if (secretRef.isNotEmpty) {
      await _secretStore.deleteSecret(secretRef);
    }
  }
}
