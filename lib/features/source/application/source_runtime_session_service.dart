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

  Future<SourceLoginTask> createLoginTask({required String sourceId}) {
    return _client.request<SourceLoginTask>(
      method: ApiMethod.get,
      path: 'v1/sources/${_pathId(sourceId)}/login-task',
      attachAccessToken: true,
      enableRetry: false,
      stage: ErrorStage.source,
      decoder: SourceLoginTask.fromJson,
    );
  }

  Future<SourceRuntimeSessionSnapshot> submitSession({
    required String sourceId,
    String? cookie,
    Map<String, String> headers = const <String, String>{},
    String? loginHeaderJson,
    String? loginInfoJson,
    String? sourceVariableJson,
    Map<String, String> localStorage = const <String, String>{},
  }) {
    return _client.request<SourceRuntimeSessionSnapshot>(
      method: ApiMethod.put,
      path: 'v1/sources/${_pathId(sourceId)}/session',
      body: <String, Object?>{
        if (_normalize(cookie) != null) 'cookie': _normalize(cookie),
        if (headers.isNotEmpty) 'headers': _normalizeHeaders(headers),
        if (_normalize(loginHeaderJson) != null)
          'loginHeaderJson': _normalize(loginHeaderJson),
        if (_normalize(loginInfoJson) != null)
          'loginInfoJson': _normalize(loginInfoJson),
        if (_normalize(sourceVariableJson) != null)
          'sourceVariableJson': _normalize(sourceVariableJson),
        if (localStorage.isNotEmpty)
          'localStorage': _normalizeHeaders(localStorage),
      },
      stage: ErrorStage.source,
      decoder: SourceRuntimeSessionSnapshot.fromJson,
    );
  }

  Future<SourceRuntimeSessionSnapshot> submitLoginResult({
    required String sourceId,
    String? cookies,
    Map<String, String> headers = const <String, String>{},
    Map<String, String> localStorage = const <String, String>{},
    String? finalUrl,
    String? loginInfoJson,
    String? sourceVariableJson,
  }) {
    return _client.request<SourceRuntimeSessionSnapshot>(
      method: ApiMethod.post,
      path: 'v1/sources/${_pathId(sourceId)}/login-result',
      body: <String, Object?>{
        'sourceId': fromServerGatewaySourceId(sourceId),
        if (_normalize(cookies) != null) 'cookies': _normalize(cookies),
        if (headers.isNotEmpty) 'headers': _normalizeHeaders(headers),
        if (localStorage.isNotEmpty)
          'localStorage': _normalizeHeaders(localStorage),
        if (_normalize(finalUrl) != null) 'finalUrl': _normalize(finalUrl),
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

class SourceLoginTask {
  const SourceLoginTask({
    required this.taskId,
    required this.sourceId,
    required this.sourceName,
    required this.mode,
    this.loginUrl,
    this.request,
  });

  final String taskId;
  final String sourceId;
  final String sourceName;
  final String mode;
  final String? loginUrl;
  final SourceLoginRequestSnapshot? request;

  factory SourceLoginTask.fromJson(Object? value) {
    final map = _asMap(value);
    return SourceLoginTask(
      taskId: _stringOrDefault(map['taskId'], ''),
      sourceId: _stringOrDefault(map['sourceId'], ''),
      sourceName: _stringOrDefault(map['sourceName'], '书源登录'),
      mode: _stringOrDefault(map['mode'], 'webView'),
      loginUrl: _normalize(map['loginUrl']?.toString()),
      request:
          map['request'] == null
              ? null
              : SourceLoginRequestSnapshot.fromJson(map['request']),
    );
  }
}

class SourceLoginRequestSnapshot {
  const SourceLoginRequestSnapshot({
    required this.url,
    required this.method,
    this.headers = const <String, String>{},
    this.body,
  });

  final String url;
  final String method;
  final Map<String, String> headers;
  final String? body;

  factory SourceLoginRequestSnapshot.fromJson(Object? value) {
    final map = _asMap(value);
    return SourceLoginRequestSnapshot(
      url: _stringOrDefault(map['url'], ''),
      method: _stringOrDefault(map['method'], 'GET').toUpperCase(),
      headers: _normalizeHeaders(_stringMap(map['headers'])),
      body: _normalize(map['body']?.toString()),
    );
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

Map<String, Object?> _asMap(Object? value) {
  if (value is! Map) {
    return const <String, Object?>{};
  }
  return value.map((key, value) => MapEntry(key.toString(), value));
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) {
    return const <String, String>{};
  }
  final result = <String, String>{};
  for (final entry in value.entries) {
    final key = entry.key?.toString().trim() ?? '';
    final itemValue = entry.value?.toString().trim() ?? '';
    if (key.isNotEmpty && itemValue.isNotEmpty) {
      result[key] = itemValue;
    }
  }
  return Map.unmodifiable(result);
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
