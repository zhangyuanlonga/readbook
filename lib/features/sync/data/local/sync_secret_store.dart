import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SyncSecretStore {
  Future<void> writeSecret({required String secretRef, required String secret});

  Future<String?> readSecret(String secretRef);

  Future<void> deleteSecret(String secretRef);
}

class FlutterSecureSyncSecretStore implements SyncSecretStore {
  FlutterSecureSyncSecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> deleteSecret(String secretRef) async {
    final normalized = secretRef.trim();
    if (normalized.isEmpty) {
      return;
    }
    await _storage.delete(key: normalized);
  }

  @override
  Future<String?> readSecret(String secretRef) async {
    final normalized = secretRef.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final value = await _storage.read(key: normalized);
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Future<void> writeSecret({
    required String secretRef,
    required String secret,
  }) async {
    final normalizedRef = secretRef.trim();
    final normalizedSecret = secret.trim();
    if (normalizedRef.isEmpty) {
      return;
    }
    if (normalizedSecret.isEmpty) {
      await _storage.delete(key: normalizedRef);
      return;
    }
    await _storage.write(key: normalizedRef, value: normalizedSecret);
  }
}
