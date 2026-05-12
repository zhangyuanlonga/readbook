import 'dart:io';

import 'package:flutter/services.dart';

import '../../../core/errors/app_exception.dart';

String formatAdvancedThemeExportError(Object error) {
  if (error is AppException) {
    final message = _normalizeText(error.briefMessage);
    final cause = _stringifyValue(error.cause);
    if (message != null && cause != null && cause != message) {
      return '$message；详情：$cause';
    }
    return message ?? cause ?? '未知错误';
  }

  if (error is PlatformException) {
    final code = _normalizeText(error.code);
    final message = _normalizeText(error.message);
    final details = _stringifyValue(error.details);
    final parts = <String>[
      if (message != null)
        code == null || code == 'error' || message.contains(code)
            ? message
            : '$message（$code）'
      else if (code != null)
        code,
      if (details != null && details != message) '详情：$details',
    ];
    return parts.isEmpty ? '平台调用失败' : parts.join('；');
  }

  if (error is FileSystemException) {
    final message = _normalizeText(error.message);
    final osMessage = _normalizeText(error.osError?.message);
    final path = _normalizeText(error.path);
    final parts = <String>[
      if (message != null) message,
      if (osMessage != null && osMessage != message) osMessage,
      if (path != null) '路径：$path',
    ];
    return parts.isEmpty ? '文件写入失败' : parts.join('；');
  }

  if (error is FormatException) {
    final message = _normalizeText(error.message);
    final source = _stringifyValue(error.source);
    final parts = <String>[
      if (message != null) message,
      if (source != null) '源：$source',
    ];
    return parts.isEmpty ? '格式错误' : parts.join('；');
  }

  return _stringifyValue(error) ?? '未知错误';
}

String? _stringifyValue(Object? value) {
  if (value == null) {
    return null;
  }
  final normalized = _normalizeText(value.toString());
  if (normalized == null) {
    return null;
  }
  const prefixes = <String>['Exception: ', 'Error: '];
  for (final prefix in prefixes) {
    if (normalized.startsWith(prefix)) {
      final trimmed = _normalizeText(normalized.substring(prefix.length));
      if (trimmed != null) {
        return trimmed;
      }
    }
  }
  return normalized;
}

String? _normalizeText(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}
