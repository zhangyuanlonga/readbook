import 'dart:convert';

import 'app_exception.dart';

class AppExceptionDiagnostics {
  AppExceptionDiagnostics({
    required this.title,
    required this.scene,
    required this.userMessage,
    required this.timestamp,
    required this.code,
    required this.stage,
    required this.briefMessage,
    this.sourceId,
    this.requestUrl,
    this.gatewayFailure,
    this.context = const <String, Object?>{},
  });

  factory AppExceptionDiagnostics.fromException({
    required String title,
    required String scene,
    required String userMessage,
    required AppException error,
    Map<String, Object?> context = const <String, Object?>{},
    DateTime? timestamp,
  }) {
    return AppExceptionDiagnostics(
      title: title,
      scene: scene,
      userMessage: userMessage,
      timestamp: timestamp ?? DateTime.now(),
      code: error.code.name,
      stage: error.stage.name,
      briefMessage: error.briefMessage,
      sourceId: error.sourceId,
      requestUrl: error.requestUrl,
      gatewayFailure: error.gatewayFailure?.toJson(),
      context: context,
    );
  }

  factory AppExceptionDiagnostics.fromMessage({
    required String title,
    required String scene,
    required String userMessage,
    Map<String, Object?> context = const <String, Object?>{},
    DateTime? timestamp,
  }) {
    return AppExceptionDiagnostics(
      title: title,
      scene: scene,
      userMessage: userMessage,
      timestamp: timestamp ?? DateTime.now(),
      code: 'unknown',
      stage: 'unknown',
      briefMessage: userMessage,
      context: context,
    );
  }

  final String title;
  final String scene;
  final String userMessage;
  final DateTime timestamp;
  final String code;
  final String stage;
  final String briefMessage;
  final String? sourceId;
  final String? requestUrl;
  final Map<String, Object?>? gatewayFailure;
  final Map<String, Object?> context;

  Map<String, Object?> toJson() {
    return _cleanMap(<String, Object?>{
      'title': title,
      'scene': scene,
      'time': timestamp.toIso8601String(),
      'userMessage': _redactSensitiveText(userMessage),
      'error': <String, Object?>{
        'code': code,
        'stage': stage,
        'briefMessage': _redactSensitiveText(briefMessage),
        'sourceId': sourceId,
        'requestUrl': _redactSensitiveText(requestUrl),
      },
      'gatewayFailure': gatewayFailure,
      'context': context,
    });
  }

  String toClipboardText() {
    final lines = <String>[
      title,
      'scene: $scene',
      'time: ${timestamp.toIso8601String()}',
      'userMessage: ${_redactSensitiveText(userMessage)}',
      'code: $code',
      'stage: $stage',
      'briefMessage: ${_redactSensitiveText(briefMessage)}',
    ];
    _appendOptional(lines, 'sourceId', sourceId);
    _appendOptional(lines, 'requestUrl', _redactSensitiveText(requestUrl));

    final gateway = gatewayFailure;
    if (gateway != null && gateway.isNotEmpty) {
      lines.add('gatewayFailure:');
      for (final entry in gateway.entries) {
        final value = entry.value;
        if (value == null || value.toString().trim().isEmpty) {
          continue;
        }
        lines.add(
          '  ${entry.key}: ${_formatValue(_sanitizeValue(entry.key, value))}',
        );
      }
    }

    final cleanedContext = _cleanMap(context);
    if (cleanedContext.isNotEmpty) {
      lines.add('context:');
      for (final entry in cleanedContext.entries) {
        lines.add('  ${entry.key}: ${_formatValue(entry.value)}');
      }
    }

    const encoder = JsonEncoder.withIndent('  ');
    lines
      ..add('json:')
      ..add(encoder.convert(toJson()));
    return lines.join('\n');
  }

  static void _appendOptional(List<String> lines, String key, Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      lines.add('$key: $text');
    }
  }

  static String _formatValue(Object? value) {
    if (value is Iterable) {
      return value.map((item) => item.toString()).join(', ');
    }
    if (value is Map) {
      return jsonEncode(_cleanMap(value.cast<String, Object?>()));
    }
    return value?.toString() ?? '';
  }

  static Map<String, Object?> _cleanMap(Map<String, Object?> map) {
    final cleaned = <String, Object?>{};
    for (final entry in map.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      if (value is String && value.trim().isEmpty) {
        continue;
      }
      if (value is Map) {
        final nested = _cleanMap(value.cast<String, Object?>());
        if (nested.isNotEmpty) {
          cleaned[entry.key] = nested;
        }
        continue;
      }
      if (value is Iterable && value.isEmpty) {
        continue;
      }
      cleaned[entry.key] = _sanitizeValue(entry.key, value);
    }
    return cleaned;
  }

  static Object? _sanitizeValue(String key, Object? value) {
    if (_isSensitiveKey(key)) {
      return '[redacted]';
    }
    if (value is String) {
      return _redactSensitiveText(value);
    }
    if (value is Map) {
      return _cleanMap(value.cast<String, Object?>());
    }
    if (value is Iterable) {
      return value
          .map((item) {
            if (item is String) {
              return _redactSensitiveText(item);
            }
            return item;
          })
          .toList(growable: false);
    }
    return value;
  }

  static bool _isSensitiveKey(String key) {
    final normalized = key.toLowerCase();
    return normalized.contains('token') ||
        normalized.contains('cookie') ||
        normalized.contains('authorization') ||
        normalized.contains('password') ||
        normalized.contains('secret') ||
        normalized.contains('session');
  }

  static String? _redactSensitiveText(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return value;
    }
    final redactedQuery = text.replaceAllMapped(
      RegExp(
        r'([?&](?:token|access_token|refresh_token|cookie|session|auth|authorization|password|secret)=)[^&#\s]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[redacted]',
    );
    return redactedQuery.replaceAllMapped(
      RegExp(
        r'\b(token|cookie|authorization|password|secret|session)\s*[:=]\s*[^,\s;]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}=[redacted]',
    );
  }
}
