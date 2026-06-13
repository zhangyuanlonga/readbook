import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'cache_scope.dart';

class AppCacheKey {
  AppCacheKey({
    required this.scope,
    String owner = 'app',
    Map<String, Object?> parts = const <String, Object?>{},
  }) : owner = _normalizeSegment(owner),
       parts = Map<String, String>.unmodifiable(_normalizeParts(parts));

  final AppCacheScope scope;
  final String owner;
  final Map<String, String> parts;

  String get normalized {
    final buffer =
        StringBuffer()
          ..write('scope=')
          ..write(scope.name)
          ..write('|owner=')
          ..write(owner);
    for (final entry in parts.entries) {
      buffer
        ..write('|')
        ..write(entry.key)
        ..write('=')
        ..write(entry.value);
    }
    return buffer.toString();
  }

  String toStorageKey() {
    final digest = sha256.convert(utf8.encode(normalized)).toString();
    return '${scope.name}.${_safeStorageSegment(owner)}.$digest';
  }

  @override
  String toString() => normalized;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is AppCacheKey && other.normalized == normalized;
  }

  @override
  int get hashCode => normalized.hashCode;

  static Map<String, String> _normalizeParts(Map<String, Object?> source) {
    final entries =
        source.entries
            .map(
              (entry) => MapEntry(
                _normalizeSegment(entry.key),
                _normalizeSegment(entry.value),
              ),
            )
            .where((entry) => entry.key.isNotEmpty && entry.value.isNotEmpty)
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    return Map<String, String>.fromEntries(entries);
  }

  static String _normalizeSegment(Object? value) {
    return (value?.toString() ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _safeStorageSegment(String value) {
    final normalized = _normalizeSegment(value)
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return normalized.isEmpty ? 'app' : normalized;
  }
}
