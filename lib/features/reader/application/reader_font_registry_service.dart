import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

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
  ReaderFontRegistryService({Future<Directory> Function()? supportDirProvider})
    : _supportDirProvider =
          supportDirProvider ?? getApplicationSupportDirectory;

  static const String _fontFolderName = 'reader_fonts';
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

  final Future<Directory> Function() _supportDirProvider;
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

    final extension = path.extension(pickedFile.name).toLowerCase();
    if (extension != '.ttf' && extension != '.otf') {
      throw ReaderFontRegistryException('仅支持 .ttf 或 .otf 字体文件。');
    }

    final bytes = await pickedFile.readAsBytes();
    if (bytes.isEmpty) {
      throw ReaderFontRegistryException('字体文件为空，无法导入。');
    }

    final fontsDir = await _resolveFontsDirectory();
    final now = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = Random().nextInt(0x7fffffff).toRadixString(16);
    final familyKey = 'reader_custom_${now}_$randomSuffix';
    final targetFile = File(path.join(fontsDir.path, '$familyKey$extension'));
    await targetFile.writeAsBytes(bytes, flush: true);

    await _registerFontFromBytes(familyKey: familyKey, bytes: bytes);

    final displayName = _normalizeDisplayName(
      path.basenameWithoutExtension(pickedFile.name),
    );
    final entry = ReaderCustomFontEntry(
      fontFamilyKey: familyKey,
      displayName: displayName,
      filePath: targetFile.path,
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
      final fontFile = File(removed!.filePath);
      if (await fontFile.exists()) {
        await fontFile.delete();
      }
      _loadedFamilyKeys.remove(removed!.fontFamilyKey);
      await _saveRegistry(entries);
    }
  }

  Future<ReaderSettings> normalizeCustomFontSettings(
    ReaderSettings settings,
  ) async {
    if (settings.fontSource != ReaderFontSource.custom) {
      return settings;
    }

    final fontFamilyKey = settings.fontFamilyKey?.trim() ?? '';
    var customPath = settings.customFontPath?.trim() ?? '';
    if (fontFamilyKey.isEmpty) {
      return _fallbackToSystemFont(settings);
    }

    if (customPath.isEmpty || !await File(customPath).exists()) {
      final entries = await _loadRegistry();
      for (final entry in entries) {
        if (entry.fontFamilyKey != fontFamilyKey) {
          continue;
        }
        final file = File(entry.filePath);
        if (await file.exists()) {
          customPath = entry.filePath;
        }
        break;
      }
    }

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

  Future<Directory> _resolveFontsDirectory() async {
    final supportDir = await _supportDirProvider();
    final directory = Directory(path.join(supportDir.path, _fontFolderName));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File> _resolveRegistryFile() async {
    final directory = await _resolveFontsDirectory();
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
      return entries;
    } catch (_) {
      return <ReaderCustomFontEntry>[];
    }
  }

  Future<void> _saveRegistry(List<ReaderCustomFontEntry> entries) async {
    final registryFile = await _resolveRegistryFile();
    final payload = entries.map((entry) => entry.toJson()).toList();
    await registryFile.writeAsString(jsonEncode(payload), flush: true);
  }
}
