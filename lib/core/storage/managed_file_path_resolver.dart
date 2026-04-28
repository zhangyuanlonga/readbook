import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum _ManagedFileRoot { documents, support }

class _ManagedFilePrefixRule {
  const _ManagedFilePrefixRule({required this.root, required this.prefixes});

  final _ManagedFileRoot root;
  final List<String> prefixes;
}

class ManagedFilePathResolver {
  ManagedFilePathResolver({
    Future<Directory> Function()? documentsDirectoryProvider,
    Future<Directory> Function()? supportDirectoryProvider,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _supportDirectoryProvider =
           supportDirectoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _documentsDirectoryProvider;
  final Future<Directory> Function() _supportDirectoryProvider;

  static String? _cachedDocumentsDirectoryPath;
  static String? _cachedSupportDirectoryPath;

  static const List<_ManagedFilePrefixRule> _rules = <_ManagedFilePrefixRule>[
    _ManagedFilePrefixRule(
      root: _ManagedFileRoot.documents,
      prefixes: <String>[
        'advanced_themes/',
        'backgrounds/',
        'reader_backgrounds/',
        'cover_galleries/',
        'launch_image_galleries/',
      ],
    ),
    _ManagedFilePrefixRule(
      root: _ManagedFileRoot.support,
      prefixes: <String>[
        'shuxiang_reading_next/custom_covers/',
        'bottom_nav_icon_galleries/',
        'reader_fonts/',
        'local_books/',
        'custom_covers/',
      ],
    ),
  ];

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
    for (final rule in _rules) {
      final baseDirectory = await _resolveBaseDirectoryPath(rule.root);
      for (final prefix in rule.prefixes) {
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
    return null;
  }

  String? _resolveManagedCandidateSync(String normalizedPath) {
    for (final rule in _rules) {
      final baseDirectory = switch (rule.root) {
        _ManagedFileRoot.documents => _cachedDocumentsDirectoryPath,
        _ManagedFileRoot.support => _cachedSupportDirectoryPath,
      };
      if (baseDirectory == null || baseDirectory.isEmpty) {
        continue;
      }
      for (final prefix in rule.prefixes) {
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
    return null;
  }

  Future<String> _resolveBaseDirectoryPath(_ManagedFileRoot root) async {
    return switch (root) {
      _ManagedFileRoot.documents => await _resolveDocumentsDirectoryPath(),
      _ManagedFileRoot.support => await _resolveSupportDirectoryPath(),
    };
  }

  Future<String> _resolveDocumentsDirectoryPath() async {
    final cached = _cachedDocumentsDirectoryPath;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final directory = await _documentsDirectoryProvider();
    _cachedDocumentsDirectoryPath = directory.path;
    return directory.path;
  }

  Future<String> _resolveSupportDirectoryPath() async {
    final cached = _cachedSupportDirectoryPath;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final directory = await _supportDirectoryProvider();
    _cachedSupportDirectoryPath = directory.path;
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
