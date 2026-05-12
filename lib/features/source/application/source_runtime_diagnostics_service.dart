import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging/app_logger.dart';

class SourceRuntimeInvocationMarker {
  const SourceRuntimeInvocationMarker({
    required this.invocationId,
    required this.sourceId,
    required this.sourceName,
    required this.methodName,
    required this.startedAt,
    this.runtimeChain,
    this.metadata = const <String, Object?>{},
  });

  final String invocationId;
  final String sourceId;
  final String sourceName;
  final String methodName;
  final DateTime startedAt;
  final String? runtimeChain;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'invocationId': invocationId,
      'sourceId': sourceId,
      'sourceName': sourceName,
      'methodName': methodName,
      'startedAt': startedAt.toIso8601String(),
      if (runtimeChain != null && runtimeChain!.trim().isNotEmpty)
        'runtimeChain': runtimeChain,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  static SourceRuntimeInvocationMarker? fromJson(Map<String, Object?> json) {
    final invocationId = json['invocationId']?.toString().trim() ?? '';
    final sourceId = json['sourceId']?.toString().trim() ?? '';
    final sourceName = json['sourceName']?.toString().trim() ?? '';
    final methodName = json['methodName']?.toString().trim() ?? '';
    final startedAtRaw = json['startedAt']?.toString().trim() ?? '';
    if (invocationId.isEmpty ||
        sourceId.isEmpty ||
        sourceName.isEmpty ||
        methodName.isEmpty ||
        startedAtRaw.isEmpty) {
      return null;
    }

    final startedAt = DateTime.tryParse(startedAtRaw);
    if (startedAt == null) {
      return null;
    }

    final metadata = <String, Object?>{};
    final rawMetadata = json['metadata'];
    if (rawMetadata is Map) {
      for (final entry in rawMetadata.entries) {
        metadata[entry.key.toString()] = entry.value;
      }
    }

    return SourceRuntimeInvocationMarker(
      invocationId: invocationId,
      sourceId: sourceId,
      sourceName: sourceName,
      methodName: methodName,
      startedAt: startedAt,
      runtimeChain: json['runtimeChain']?.toString(),
      metadata: metadata,
    );
  }
}

class SourceRuntimeDiagnosticsService {
  SourceRuntimeDiagnosticsService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  static final SourceRuntimeDiagnosticsService instance =
      SourceRuntimeDiagnosticsService();

  static const String _activeStorageKey = 'source.runtime.active_invocations.v1';
  static const int _maxMarkers = 8;

  final Future<SharedPreferences> _preferencesFuture;

  Future<SourceRuntimeInvocationMarker> markInvocationStarted({
    required String sourceId,
    required String sourceName,
    required String methodName,
    String? runtimeChain,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) async {
    final marker = SourceRuntimeInvocationMarker(
      invocationId:
          '${DateTime.now().microsecondsSinceEpoch}:$sourceId:$methodName',
      sourceId: sourceId.trim(),
      sourceName: sourceName.trim().isEmpty ? sourceId.trim() : sourceName.trim(),
      methodName: methodName.trim(),
      startedAt: DateTime.now(),
      runtimeChain: runtimeChain?.trim(),
      metadata: metadata,
    );
    final markers = await _loadActiveMarkers();
    markers.removeWhere((item) => item.invocationId == marker.invocationId);
    markers.add(marker);
    if (markers.length > _maxMarkers) {
      markers.removeRange(0, markers.length - _maxMarkers);
    }
    await _saveActiveMarkers(markers);
    return marker;
  }

  Future<void> markInvocationFinished(String invocationId) async {
    final normalized = invocationId.trim();
    if (normalized.isEmpty) {
      return;
    }
    final markers = await _loadActiveMarkers();
    markers.removeWhere((item) => item.invocationId == normalized);
    await _saveActiveMarkers(markers);
  }

  Future<List<SourceRuntimeInvocationMarker>> loadActiveMarkers() async {
    final markers = await _loadActiveMarkers();
    return List<SourceRuntimeInvocationMarker>.unmodifiable(markers.reversed);
  }

  Future<void> reportRecoveredInvocations({AppLogger? logger}) async {
    final active = await _loadActiveMarkers();
    if (active.isEmpty) {
      return;
    }

    final appLogger = logger ?? AppLogger.instance;
    for (final marker in active.reversed) {
      appLogger.warn(
        'Recovered unfinished source runtime invocation',
        context: <String, Object?>{
          'sourceId': marker.sourceId,
          'sourceName': marker.sourceName,
          'methodName': marker.methodName,
          'runtimeChain': marker.runtimeChain,
          'startedAt': marker.startedAt.toIso8601String(),
          ...marker.metadata,
        },
      );
    }

    await clearActiveMarkers();
  }

  Future<void> clearActiveMarkers() async {
    final prefs = await _preferencesFuture;
    await prefs.remove(_activeStorageKey);
  }

  Future<List<SourceRuntimeInvocationMarker>> _loadActiveMarkers() async {
    final prefs = await _preferencesFuture;
    final raw = (prefs.getString(_activeStorageKey) ?? '').trim();
    if (raw.isEmpty) {
      return <SourceRuntimeInvocationMarker>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <SourceRuntimeInvocationMarker>[];
      }
      final markers = <SourceRuntimeInvocationMarker>[];
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        final marker = SourceRuntimeInvocationMarker.fromJson(
          Map<String, Object?>.from(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        );
        if (marker != null) {
          markers.add(marker);
        }
      }
      return markers;
    } catch (_) {
      return <SourceRuntimeInvocationMarker>[];
    }
  }

  Future<void> _saveActiveMarkers(
    List<SourceRuntimeInvocationMarker> markers,
  ) async {
    final prefs = await _preferencesFuture;
    if (markers.isEmpty) {
      await prefs.remove(_activeStorageKey);
      return;
    }
    await prefs.setString(
      _activeStorageKey,
      jsonEncode(
        markers.map((item) => item.toJson()).toList(growable: false),
      ),
    );
  }
}
