import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/managed_asset.dart';
import 'managed_asset_directory_policy.dart';

class ManagedFilePathResolver {
  ManagedFilePathResolver({
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? supportDirectoryProvider,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _supportDirectoryProvider =
           supportDirectoryProvider ?? getApplicationSupportDirectory,
       _usesCustomDocumentsDirectoryProvider =
           documentsDirectoryProvider != null,
       _usesCustomSupportDirectoryProvider =
           supportDirectoryProvider != null;

  final Future<Directory> Function() _documentsDirectoryProvider;
  final Future<Directory> Function() _supportDirectoryProvider;
  final bool _usesCustomDocumentsDirectoryProvider;
  final bool _usesCustomSupportDirectoryProvider;

  static String? _cachedDocumentsDirectoryPath;
  static String? _cachedSupportDirectoryPath;

  static Future<void> primeCurrentRoots({
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? supportDirectoryProvider,
  }) async {
    final documents =
        await (documentsDirectoryProvider ??
            getApplicationDocumentsDirectory)();
    final support =
        await (supportDirectoryProvider ?? getApplicationSupportDirectory)();
    _cachedDocumentsDirectoryPath = documents.path;
    _cachedSupportDirectoryPath = support.path;
  }

  Future<String?> normalizePersistedFilePath(String? rawPath) async {
    final normalized = _normalizeRawPath(rawPath);
    if (normalized == null) {
      return null;
    }
    final resolved = await resolveExistingFilePath(normalized);
    return resolved ?? normalized;
  }

  Future<String?> resolveExistingFilePath(String? rawPath) async {
    final normalized = _normalizeRawPath(rawPath);
    if (normalized == null) {
      return null;
    }
    if (await File(normalized).exists()) {
      return normalized;
    }
    return _resolveManagedCandidate(normalized);
  }

  String? tryResolveExistingFilePathSync(String? rawPath) {
    final normalized = _normalizeRawPath(rawPath);
    if (normalized == null) {
      return null;
    }
    if (File(normalized).existsSync()) {
      return normalized;
    }
    return _resolveManagedCandidateSync(normalized);
  }

  Future<String?> _resolveManagedCandidate(String normalizedPath) async {
    for (final root in const <ManagedAssetRoot>[
      ManagedAssetRoot.documents,
      ManagedAssetRoot.support,
    ]) {
      final baseDirectory = await _resolveBaseDirectoryPath(root);
      for (final policy in ManagedAssetDirectoryPolicies.policiesForRoot(root)) {
        for (final prefix in policy.allKnownRelativePrefixes) {
        final relative = _extractManagedRelativePath(
          normalizedPath: normalizedPath,
          prefix: prefix,
        );
        if (relative == null) {
          continue;
        }
        final candidate = p.normalize(p.join(baseDirectory, relative));
        if (await File(candidate).exists()) {
          return candidate;
        }
      }
      }
    }
    return null;
  }

  String? _resolveManagedCandidateSync(String normalizedPath) {
    for (final root in const <ManagedAssetRoot>[
      ManagedAssetRoot.documents,
      ManagedAssetRoot.support,
    ]) {
      final baseDirectory = switch (root) {
        ManagedAssetRoot.documents => _cachedDocumentsDirectoryPath,
        ManagedAssetRoot.support => _cachedSupportDirectoryPath,
        ManagedAssetRoot.bundled => _cachedSupportDirectoryPath,
      };
      if (baseDirectory == null || baseDirectory.isEmpty) {
        continue;
      }
      for (final policy in ManagedAssetDirectoryPolicies.policiesForRoot(root)) {
        for (final prefix in policy.allKnownRelativePrefixes) {
        final relative = _extractManagedRelativePath(
          normalizedPath: normalizedPath,
          prefix: prefix,
        );
        if (relative == null) {
          continue;
        }
        final candidate = p.normalize(p.join(baseDirectory, relative));
        if (File(candidate).existsSync()) {
          return candidate;
        }
      }
      }
    }
    return null;
  }

  Future<String> _resolveBaseDirectoryPath(ManagedAssetRoot root) async {
    return switch (root) {
      ManagedAssetRoot.documents => await _resolveDocumentsDirectoryPath(),
      ManagedAssetRoot.support => await _resolveSupportDirectoryPath(),
      ManagedAssetRoot.bundled => await _resolveSupportDirectoryPath(),
    };
  }

  Future<String> _resolveDocumentsDirectoryPath() async {
    final cached = _cachedDocumentsDirectoryPath;
    if (!_usesCustomDocumentsDirectoryProvider &&
        cached != null &&
        cached.isNotEmpty) {
      return cached;
    }
    final directory = await _documentsDirectoryProvider();
    if (!_usesCustomDocumentsDirectoryProvider) {
      _cachedDocumentsDirectoryPath = directory.path;
    }
    return directory.path;
  }

  Future<String> _resolveSupportDirectoryPath() async {
    final cached = _cachedSupportDirectoryPath;
    if (!_usesCustomSupportDirectoryProvider &&
        cached != null &&
        cached.isNotEmpty) {
      return cached;
    }
    final directory = await _supportDirectoryProvider();
    if (!_usesCustomSupportDirectoryProvider) {
      _cachedSupportDirectoryPath = directory.path;
    }
    return directory.path;
  }

  String? _extractManagedRelativePath({
    required String normalizedPath,
    required String prefix,
  }) {
    final normalizedPrefix = prefix.replaceAll('\\', '/');
    if (normalizedPath.startsWith(normalizedPrefix)) {
      return p.normalize(normalizedPath);
    }
    final marker = '/$normalizedPrefix';
    final markerIndex = normalizedPath.lastIndexOf(marker);
    if (markerIndex >= 0) {
      return p.normalize(normalizedPath.substring(markerIndex + 1));
    }
    return null;
  }

  String? _normalizeRawPath(String? rawPath) {
    final trimmed = rawPath?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.scheme == 'file') {
      return uri.toFilePath();
    }
    return trimmed.replaceAll('\\', '/');
  }
}
