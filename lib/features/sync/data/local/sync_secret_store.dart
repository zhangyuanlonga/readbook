import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

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
    try {
      await _storage.delete(key: normalized);
    } on MissingPluginException catch (_) {
      throw StateError('当前运行中的应用尚未加载安全存储插件，请完整重启应用后再试。');
    }
  }

  @override
  Future<String?> readSecret(String secretRef) async {
    final normalized = secretRef.trim();
    if (normalized.isEmpty) {
      return null;
    }
    String? value;
    try {
      value = await _storage.read(key: normalized);
    } on MissingPluginException catch (_) {
      throw StateError('当前运行中的应用尚未加载安全存储插件，请完整重启应用后再试。');
    }
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
    try {
      await _storage.write(key: normalizedRef, value: normalizedSecret);
    } on MissingPluginException catch (_) {
      throw StateError('当前运行中的应用尚未加载安全存储插件，请完整重启应用后再试。');
    }
  }
}
