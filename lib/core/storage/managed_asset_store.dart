import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/managed_asset.dart';
import 'managed_asset_directory_policy.dart';
import 'managed_file_path_resolver.dart';

class ManagedAssetStore {
  ManagedAssetStore({
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? supportDirectoryProvider,
    ManagedFilePathResolver? pathResolver,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _supportDirectoryProvider =
           supportDirectoryProvider ?? getApplicationSupportDirectory,
       _pathResolver =
           pathResolver ??
           ManagedFilePathResolver(
             documentsDirectoryProvider: documentsDirectoryProvider,
             supportDirectoryProvider: supportDirectoryProvider,
           );

  final Future<Directory> Function() _documentsDirectoryProvider;
  final Future<Directory> Function() _supportDirectoryProvider;
  final ManagedFilePathResolver _pathResolver;

  Future<Directory> resolveDirectory(
    ManagedAssetType type, {
    String? collectionId,
  }) async {
    final policy = _policyFor(type);
    final baseDirectory = await _resolveBaseDirectory(policy.root);
    final normalizedCollectionId = _normalizeCollectionId(collectionId);
    final pathSegments = <String>[
      baseDirectory.path,
      policy.relativeDirectory,
      if (normalizedCollectionId != null) normalizedCollectionId,
    ];
    return Directory(
      p.joinAll(pathSegments),
    );
  }

  Future<List<String>> listResolvedFilePaths(
    ManagedAssetType type, {
    String? collectionId,
  }) async {
    final directory = await resolveDirectory(type, collectionId: collectionId);
    if (!await directory.exists()) {
      return const <String>[];
    }
    return directory
        .listSync(followLinks: false)
        .whereType<File>()
        .map((file) => file.path)
        .toList(growable: false);
  }

  Future<ManagedAssetRef> persistBytes({
    required ManagedAssetType type,
    required ManagedAssetScope scope,
    required List<int> bytes,
    required String fileName,
    String? collectionId,
    String? assetId,
    String? displayName,
    String? targetNamePrefix,
  }) async {
    final policy = _policyFor(type);
    final directory = await resolveDirectory(type, collectionId: collectionId);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final normalizedExtension = _normalizeExtension(fileName);
    final safePrefix = _normalizeFileStem(
      targetNamePrefix?.trim().isNotEmpty == true
          ? targetNamePrefix!
          : p.basenameWithoutExtension(fileName),
    );
    final targetFile = File(
      p.join(
        directory.path,
        '${safePrefix}_${DateTime.now().millisecondsSinceEpoch}$normalizedExtension',
      ),
    );
    await targetFile.writeAsBytes(bytes, flush: true);
    return ManagedAssetRef(
      type: type,
      scope: scope,
      root: policy.root,
      relativePath: await relativizePersistedPath(targetFile.path) ??
          _relativePathFor(policy, targetFile.path),
      collectionId: _normalizeCollectionId(collectionId),
      assetId: _normalizeOptional(assetId),
      displayName: _normalizeOptional(displayName),
      resolvedPath: targetFile.path,
    );
  }

  Future<ManagedAssetRef> importFile({
    required ManagedAssetType type,
    required ManagedAssetScope scope,
    required String sourcePath,
    String? collectionId,
    String? assetId,
    String? displayName,
    String? fileName,
    String? targetNamePrefix,
  }) async {
    final sourceFile = File(sourcePath.trim());
    if (!await sourceFile.exists()) {
      throw FileSystemException('Managed asset source file does not exist.');
    }
    return persistBytes(
      type: type,
      scope: scope,
      bytes: await sourceFile.readAsBytes(),
      fileName: fileName ?? p.basename(sourceFile.path),
      collectionId: collectionId,
      assetId: assetId,
      displayName: displayName,
      targetNamePrefix: targetNamePrefix,
    );
  }

  Future<String?> relativizePersistedPath(String? rawPath) async {
    final normalized = _normalizeRawPath(rawPath);
    if (normalized == null) {
      return null;
    }
    if (_looksManagedRelativePath(normalized)) {
      return p.normalize(normalized).replaceAll('\\', '/');
    }
    final resolved = await _pathResolver.resolveExistingFilePath(normalized);
    final candidate = resolved ?? normalized;
    for (final policy in ManagedAssetDirectoryPolicies.all) {
      final baseDirectory = await _resolveBaseDirectory(policy.root);
      final rootPrefix = p.normalize(
        p.join(baseDirectory.path, policy.relativeDirectory),
      );
      if (_isWithinDirectory(candidate, rootPrefix)) {
        return p
            .relative(candidate, from: baseDirectory.path)
            .replaceAll('\\', '/');
      }
      for (final legacyPrefix in policy.legacyRelativePrefixes) {
        final legacyRoot = p.normalize(p.join(baseDirectory.path, legacyPrefix));
        if (_isWithinDirectory(candidate, legacyRoot)) {
          final relativeInLegacy = p.relative(candidate, from: legacyRoot);
          return p
              .join(policy.relativeDirectory, relativeInLegacy)
              .replaceAll('\\', '/');
        }
      }
    }
    return candidate.replaceAll('\\', '/');
  }

  Future<String?> resolvePersistedPath(String? rawPath) {
    return _pathResolver.normalizePersistedFilePath(rawPath);
  }

  Future<ManagedAssetRef?> relativizeRef(ManagedAssetRef? ref) async {
    if (ref == null) {
      return null;
    }
    final relative = await relativizePersistedPath(
      ref.resolvedPath ?? ref.relativePath,
    );
    if (relative == null) {
      return null;
    }
    return ref.copyWith(relativePath: relative);
  }

  Future<ManagedAssetRef?> normalizeRefForRuntime(ManagedAssetRef? ref) async {
    if (ref == null) {
      return null;
    }
    final relative = await relativizePersistedPath(ref.relativePath) ??
        ref.normalizedRelativePath;
    final resolved = await resolvePersistedPath(ref.resolvedPath ?? relative);
    return ref.copyWith(
      relativePath: relative,
      resolvedPath: resolved,
      clearResolvedPath: resolved == null,
    );
  }

  Future<void> deletePath(String? rawPath) async {
    final resolved = await resolvePersistedPath(rawPath);
    final normalized = resolved?.trim() ?? rawPath?.trim() ?? '';
    if (normalized.isEmpty) {
      return;
    }
    final file = File(normalized);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> deleteRef(ManagedAssetRef? ref) async {
    if (ref == null) {
      return;
    }
    await deletePath(ref.resolvedPath ?? ref.relativePath);
  }

  ManagedAssetDirectoryPolicy _policyFor(ManagedAssetType type) {
    final policy = ManagedAssetDirectoryPolicies.policyFor(type);
    if (policy == null) {
      throw StateError('Missing managed asset policy for ${type.name}.');
    }
    return policy;
  }

  Future<Directory> _resolveBaseDirectory(ManagedAssetRoot root) async {
    return switch (root) {
      ManagedAssetRoot.documents => _documentsDirectoryProvider(),
      ManagedAssetRoot.support => _supportDirectoryProvider(),
      ManagedAssetRoot.bundled => _supportDirectoryProvider(),
    };
  }

  String _relativePathFor(ManagedAssetDirectoryPolicy policy, String filePath) {
    final normalizedCollectionId = _normalizeCollectionId(
      p.basename(p.dirname(filePath)) == p.basename(policy.relativeDirectory)
          ? null
          : p.basename(p.dirname(filePath)),
    );
    final pathSegments = <String>[
      policy.relativeDirectory,
      if (normalizedCollectionId != null) normalizedCollectionId,
      p.basename(filePath),
    ];
    return p.joinAll(pathSegments).replaceAll('\\', '/');
  }

  bool _looksManagedRelativePath(String normalized) {
    for (final policy in ManagedAssetDirectoryPolicies.all) {
      for (final prefix in policy.allKnownRelativePrefixes) {
        final normalizedPrefix = prefix.replaceAll('\\', '/');
        if (normalized.startsWith(normalizedPrefix)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isWithinDirectory(String filePath, String directoryPath) {
    final normalizedFile = p.normalize(filePath);
    final normalizedDirectory = p.normalize(directoryPath);
    return normalizedFile == normalizedDirectory ||
        p.isWithin(normalizedDirectory, normalizedFile);
  }

  String _normalizeExtension(String fileName) {
    final extension = p.extension(fileName).trim();
    if (extension.isEmpty) {
      return '.bin';
    }
    return extension.toLowerCase();
  }

  String _normalizeFileStem(String raw) {
    final normalized = raw.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_');
    if (normalized.isEmpty) {
      return 'asset';
    }
    return normalized;
  }

  String? _normalizeCollectionId(String? value) {
    final normalized = _normalizeOptional(value);
    if (normalized == null) {
      return null;
    }
    return normalized.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_');
  }

  String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
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
