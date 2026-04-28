import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../../../core/storage/managed_asset_store.dart';
import '../../../domain/entities/managed_asset.dart';
import '../../../domain/entities/reader_settings.dart';

class ReaderCustomFontEntry {
  const ReaderCustomFontEntry({
    required this.fontFamilyKey,
    required this.displayName,
    required this.filePath,
    required this.importedAtEpochMs,
  });

  final String fontFamilyKey;
  final String displayName;
  final String filePath;
  final int importedAtEpochMs;

  Map<String, dynamic> toJson() {
    return {
      'fontFamilyKey': fontFamilyKey,
      'displayName': displayName,
      'filePath': filePath,
      'importedAtEpochMs': importedAtEpochMs,
    };
  }

  factory ReaderCustomFontEntry.fromJson(Map<String, dynamic> json) {
    final importedAt = json['importedAtEpochMs'];
    return ReaderCustomFontEntry(
      fontFamilyKey: (json['fontFamilyKey'] ?? '').toString().trim(),
      displayName: (json['displayName'] ?? '').toString().trim(),
      filePath: (json['filePath'] ?? '').toString().trim(),
      importedAtEpochMs:
          importedAt is int
              ? importedAt
              : int.tryParse(importedAt?.toString() ?? '') ?? 0,
    );
  }
}

class ReaderFontRegistryException implements Exception {
  ReaderFontRegistryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReaderFontRegistryService {
  ReaderFontRegistryService({
    Future<Directory> Function()? supportDirProvider,
    ManagedAssetStore? assetStore,
  })
    : _assetStore =
          assetStore ??
          ManagedAssetStore(supportDirectoryProvider: supportDirProvider);

  static const String _registryFileName = 'registry.json';
  static const XTypeGroup _fontTypeGroup = XTypeGroup(
    label: 'font',
    extensions: ['ttf', 'otf'],
    mimeTypes: ['font/ttf', 'font/otf', 'application/font-sfnt'],
    uniformTypeIdentifiers: [
      'public.truetype-ttf-font',
      'public.opentype-font',
    ],
  );

  final ManagedAssetStore _assetStore;
  final Set<String> _loadedFamilyKeys = <String>{};

  Future<void> restoreRegisteredFonts() async {
    final entries = await _loadRegistry();
    if (entries.isEmpty) {
      return;
    }

    final availableEntries = <ReaderCustomFontEntry>[];
    for (final entry in entries) {
      if (entry.fontFamilyKey.isEmpty || entry.filePath.isEmpty) {
        continue;
      }
      final file = File(entry.filePath);
      if (!await file.exists()) {
        continue;
      }
      try {
        await _registerFontFromFile(familyKey: entry.fontFamilyKey, file: file);
        availableEntries.add(entry);
      } catch (_) {
        // Ignore broken font files and cleanup stale registry below.
      }
    }

    if (availableEntries.length != entries.length) {
      await _saveRegistry(availableEntries);
    }
  }

  Future<List<ReaderCustomFontEntry>> listRegisteredFonts() async {
    final entries = await _loadRegistry();
    entries.sort((a, b) => b.importedAtEpochMs.compareTo(a.importedAtEpochMs));
    return entries;
  }

  Future<ReaderCustomFontEntry?> pickAndImportFont({
    String confirmButtonText = '导入字体',
  }) async {
    final pickedFile = await openFile(
      acceptedTypeGroups: const [_fontTypeGroup],
      confirmButtonText: confirmButtonText,
    );
    if (pickedFile == null) {
      return null;
    }

    return importFontFile(
      filePath: pickedFile.path,
      displayName: path.basenameWithoutExtension(pickedFile.name),
    );
  }

  Future<ReaderCustomFontEntry> importFontFile({
    required String filePath,
    String? displayName,
  }) async {
    final normalizedPath = filePath.trim();
    if (normalizedPath.isEmpty) {
      throw ReaderFontRegistryException('字体文件路径无效。');
    }
    final sourceFile = File(normalizedPath);
    if (!await sourceFile.exists()) {
      throw ReaderFontRegistryException('字体文件不存在，无法导入。');
    }

    final extension = path.extension(sourceFile.path).toLowerCase();
    if (extension != '.ttf' && extension != '.otf') {
      throw ReaderFontRegistryException('仅支持 .ttf 或 .otf 字体文件。');
    }

    final bytes = await sourceFile.readAsBytes();
    if (bytes.isEmpty) {
      throw ReaderFontRegistryException('字体文件为空，无法导入。');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = Random().nextInt(0x7fffffff).toRadixString(16);
    final familyKey = 'reader_custom_${now}_$randomSuffix';
    final asset = await _assetStore.persistBytes(
      type: ManagedAssetType.readerFont,
      scope: ManagedAssetScope.typography,
      bytes: bytes,
      fileName: '$familyKey$extension',
      assetId: familyKey,
      displayName: displayName ?? path.basenameWithoutExtension(sourceFile.path),
      targetNamePrefix: familyKey,
    );
    final targetPath = asset.resolvedPath!;

    await _registerFontFromBytes(familyKey: familyKey, bytes: bytes);

    final normalizedDisplayName = _normalizeDisplayName(
      displayName ?? path.basenameWithoutExtension(sourceFile.path),
    );
    final entry = ReaderCustomFontEntry(
      fontFamilyKey: familyKey,
      displayName: normalizedDisplayName,
      filePath: targetPath,
      importedAtEpochMs: now,
    );

    final entries = await _loadRegistry();
    entries.removeWhere((item) => item.fontFamilyKey == familyKey);
    entries.add(entry);
    await _saveRegistry(entries);
    return entry;
  }

  Future<void> removeFont(String familyKey) async {
    final normalized = familyKey.trim();
    if (normalized.isEmpty) {
      return;
    }

    final entries = await _loadRegistry();
    ReaderCustomFontEntry? removed;
    entries.removeWhere((entry) {
      if (entry.fontFamilyKey == normalized) {
        removed = entry;
        return true;
      }
      return false;
    });

    if (removed != null) {
      await _assetStore.deletePath(removed!.filePath);
      _loadedFamilyKeys.remove(removed!.fontFamilyKey);
      await _saveRegistry(entries);
    }
  }

  Future<void> renameFontDisplayName({
    required String familyKey,
    required String displayName,
  }) async {
    final normalizedFamilyKey = familyKey.trim();
    if (normalizedFamilyKey.isEmpty) {
      throw ReaderFontRegistryException('字体标识无效。');
    }
    final normalizedDisplayName = _normalizeDisplayName(displayName);
    final entries = await _loadRegistry();
    final index = entries.indexWhere(
      (entry) => entry.fontFamilyKey == normalizedFamilyKey,
    );
    if (index < 0) {
      throw ReaderFontRegistryException('未找到要重命名的字体。');
    }
    final current = entries[index];
    entries[index] = ReaderCustomFontEntry(
      fontFamilyKey: current.fontFamilyKey,
      displayName: normalizedDisplayName,
      filePath: current.filePath,
      importedAtEpochMs: current.importedAtEpochMs,
    );
    await _saveRegistry(entries);
  }

  Future<ReaderSettings> normalizeCustomFontSettings(
    ReaderSettings settings,
  ) async {
    if (settings.fontSource != ReaderFontSource.custom) {
      return settings;
    }

    final fontFamilyKey = settings.fontFamilyKey?.trim() ?? '';
    var customPath =
        await _assetStore.resolvePersistedPath(settings.customFontPath) ??
        settings.customFontPath?.trim() ??
        '';
    if (fontFamilyKey.isEmpty) {
      return _fallbackToSystemFont(settings);
    }

    if (customPath.isEmpty || !await File(customPath).exists()) {
      final entries = await _loadRegistry();
      for (final entry in entries) {
        if (entry.fontFamilyKey != fontFamilyKey) {
          continue;
        }
        final resolvedEntryPath =
            await _assetStore.resolvePersistedPath(entry.filePath) ??
            entry.filePath;
        final file = File(resolvedEntryPath);
        if (await file.exists()) {
          customPath = entry.filePath;
        }
        break;
      }
    }

    customPath = await _assetStore.resolvePersistedPath(customPath) ?? customPath;
    if (customPath.isEmpty || !await File(customPath).exists()) {
      return _fallbackToSystemFont(settings);
    }

    try {
      await _registerFontFromFile(
        familyKey: fontFamilyKey,
        file: File(customPath),
      );
      return settings.copyWith(
        fontSource: ReaderFontSource.custom,
        fontFamilyKey: fontFamilyKey,
        customFontPath: customPath,
      );
    } catch (_) {
      return _fallbackToSystemFont(settings);
    }
  }

  ReaderSettings _fallbackToSystemFont(ReaderSettings settings) {
    return settings.copyWith(
      fontSource: ReaderFontSource.system,
      clearFontFamilyKey: true,
      clearCustomFontPath: true,
    );
  }

  Future<void> _registerFontFromFile({
    required String familyKey,
    required File file,
  }) async {
    if (_loadedFamilyKeys.contains(familyKey)) {
      return;
    }
    final bytes = await file.readAsBytes();
    await _registerFontFromBytes(familyKey: familyKey, bytes: bytes);
  }

  Future<void> _registerFontFromBytes({
    required String familyKey,
    required Uint8List bytes,
  }) async {
    if (_loadedFamilyKeys.contains(familyKey)) {
      return;
    }
    final loader = FontLoader(familyKey)..addFont(
      Future<ByteData>.value(
        ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes),
      ),
    );
    await loader.load();
    _loadedFamilyKeys.add(familyKey);
  }

  String _normalizeDisplayName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '自定义字体';
    }
    return trimmed.replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<File> _resolveRegistryFile() async {
    final directory = await _assetStore.resolveDirectory(
      ManagedAssetType.readerFont,
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File(path.join(directory.path, _registryFileName));
  }

  Future<List<ReaderCustomFontEntry>> _loadRegistry() async {
    final registryFile = await _resolveRegistryFile();
    if (!await registryFile.exists()) {
      return <ReaderCustomFontEntry>[];
    }

    try {
      final raw = await registryFile.readAsString();
      if (raw.trim().isEmpty) {
        return <ReaderCustomFontEntry>[];
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <ReaderCustomFontEntry>[];
      }
      final entries = <ReaderCustomFontEntry>[];
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        final entry = ReaderCustomFontEntry.fromJson(
          item.map((key, value) => MapEntry(key.toString(), value)),
        );
        if (entry.fontFamilyKey.isEmpty || entry.filePath.isEmpty) {
          continue;
        }
        entries.add(entry);
      }
      var changed = false;
      final normalizedEntries = <ReaderCustomFontEntry>[];
      for (final entry in entries) {
        final persisted =
            await _assetStore.relativizePersistedPath(entry.filePath) ??
            entry.filePath;
        final resolved =
            await _assetStore.resolvePersistedPath(persisted) ??
            entry.filePath;
        if (persisted != entry.filePath || resolved != entry.filePath) {
          changed = true;
          normalizedEntries.add(
            ReaderCustomFontEntry(
              fontFamilyKey: entry.fontFamilyKey,
              displayName: entry.displayName,
              filePath: resolved,
              importedAtEpochMs: entry.importedAtEpochMs,
            ),
          );
          continue;
        }
        normalizedEntries.add(entry);
      }
      if (changed) {
        await _saveRegistry(normalizedEntries);
      }
      return normalizedEntries;
    } catch (_) {
      return <ReaderCustomFontEntry>[];
    }
  }

  Future<void> _saveRegistry(List<ReaderCustomFontEntry> entries) async {
    final registryFile = await _resolveRegistryFile();
    final payload = <Map<String, dynamic>>[];
    for (final entry in entries) {
      payload.add(
        ReaderCustomFontEntry(
          fontFamilyKey: entry.fontFamilyKey,
          displayName: entry.displayName,
          filePath:
              await _assetStore.relativizePersistedPath(entry.filePath) ??
              entry.filePath,
          importedAtEpochMs: entry.importedAtEpochMs,
        ).toJson(),
      );
    }
    await registryFile.writeAsString(jsonEncode(payload), flush: true);
  }
}
