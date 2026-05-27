import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_stage.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../search/application/server_gateway_identity.dart';

final sourceRuntimeSessionServiceProvider =
    Provider<SourceRuntimeSessionService>((ref) {
      return SourceRuntimeSessionService();
    });

class SourceRuntimeSessionService {
  SourceRuntimeSessionService({ApiClient? client, String? baseUrl})
    : _client =
          client ??
          ApiClient(
            baseUrl:
                (baseUrl ?? AppApiConfig.effectiveReaderGatewayBaseUrl).trim(),
            defaultTimeout: const Duration(seconds: 20),
          );

  final ApiClient _client;

  Future<SourceRuntimeSessionSnapshot> loadSession({required String sourceId}) {
    return _client.request<SourceRuntimeSessionSnapshot>(
      method: ApiMethod.get,
      path: 'v1/sources/${_pathId(sourceId)}/session',
      stage: ErrorStage.source,
      decoder: SourceRuntimeSessionSnapshot.fromJson,
    );
  }

  Future<SourceRuntimeSessionSnapshot> submitSession({
    required String sourceId,
    String? cookie,
    Map<String, String> headers = const <String, String>{},
    String? loginHeaderJson,
    String? loginInfoJson,
    String? sourceVariableJson,
  }) {
    return _client.request<SourceRuntimeSessionSnapshot>(
      method: ApiMethod.put,
      path: 'v1/sources/${_pathId(sourceId)}/session',
      body: <String, Object?>{
        'bookSourceUrl': fromServerGatewaySourceId(sourceId),
        if (_normalize(cookie) != null) 'cookie': _normalize(cookie),
        if (headers.isNotEmpty) 'headers': _normalizeHeaders(headers),
        if (_normalize(loginHeaderJson) != null)
          'loginHeaderJson': _normalize(loginHeaderJson),
        if (_normalize(loginInfoJson) != null)
          'loginInfoJson': _normalize(loginInfoJson),
        if (_normalize(sourceVariableJson) != null)
          'sourceVariableJson': _normalize(sourceVariableJson),
      },
      stage: ErrorStage.source,
      decoder: SourceRuntimeSessionSnapshot.fromJson,
    );
  }

  Future<SourceRuntimeSessionSnapshot> clearSession({
    required String sourceId,
  }) {
    return _client.request<SourceRuntimeSessionSnapshot>(
      method: ApiMethod.delete,
      path: 'v1/sources/${_pathId(sourceId)}/session',
      stage: ErrorStage.source,
      decoder: SourceRuntimeSessionSnapshot.fromJson,
    );
  }

  String _pathId(String sourceId) {
    return Uri.encodeComponent(fromServerGatewaySourceId(sourceId));
  }
}

class SourceRuntimeSessionSnapshot {
  const SourceRuntimeSessionSnapshot({
    required this.sourceUrl,
    required this.hasCookie,
    required this.hasHeaders,
    required this.hasLoginInfo,
    required this.hasSourceVariable,
    required this.headerNames,
    required this.cookieScope,
    required this.sessionPolicy,
    required this.ttlSeconds,
    this.updatedAt,
  });

  final String sourceUrl;
  final bool hasCookie;
  final bool hasHeaders;
  final bool hasLoginInfo;
  final bool hasSourceVariable;
  final List<String> headerNames;
  final String cookieScope;
  final String sessionPolicy;
  final int? updatedAt;
  final int ttlSeconds;

  factory SourceRuntimeSessionSnapshot.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid source runtime session response');
    }
    final map = value.map((key, value) => MapEntry(key.toString(), value));
    return SourceRuntimeSessionSnapshot(
      sourceUrl: _stringOrDefault(map['sourceUrl'], ''),
      hasCookie: map['hasCookie'] == true,
      hasHeaders: map['hasHeaders'] == true,
      hasLoginInfo: map['hasLoginInfo'] == true,
      hasSourceVariable: map['hasSourceVariable'] == true,
      headerNames: (map['headerNames'] as List? ?? const <Object?>[])
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      cookieScope: _stringOrDefault(map['cookieScope'], 'source'),
      sessionPolicy: _stringOrDefault(
        map['sessionPolicy'],
        'shortRuntimeHeaderOnly',
      ),
      updatedAt: _optionalInt(map['updatedAt']),
      ttlSeconds: _optionalInt(map['ttlSeconds']) ?? 0,
    );
  }
}

Map<String, String> _normalizeHeaders(Map<String, String> headers) {
  final normalized = <String, String>{};
  for (final entry in headers.entries) {
    final key = entry.key.trim();
    final value = entry.value.trim();
    if (key.isNotEmpty && value.isNotEmpty) {
      normalized[key] = value;
    }
  }
  return normalized;
}

String? _normalize(String? value) {
  final normalized = (value ?? '').trim();
  return normalized.isEmpty ? null : normalized;
}

String _stringOrDefault(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int? _optionalInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}
