import '../../../domain/entities/search_request_context.dart';
import '../../errors/app_exception.dart';
import '../../errors/error_codes.dart';
import '../../errors/error_stage.dart';

class UrlTemplateResolver {
  const UrlTemplateResolver();

  static final RegExp _placeholderPattern = RegExp(
    r'\{\{\s*([^}|]+?)(?:\|([a-zA-Z]+))?\s*\}\}',
  );

  static final RegExp _offsetExpressionPattern = RegExp(
    r'^([a-zA-Z0-9_]+)\s*([+-])\s*(\d+)$',
  );

  String resolve({
    required String template,
    required SearchRequestContext context,
    String? baseUrl,
    Map<String, String> extraVariables = const {},
    bool encodeKeywordByDefault = true,
  }) {
    final normalizedTemplate = template.trim();
    if (normalizedTemplate.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.search,
        briefMessage: 'URL 模板不能为空。',
      );
    }

    final variables = <String, String>{
      ...context.toVariables(),
      ...extraVariables,
    };

    final replaced = normalizedTemplate.replaceAllMapped(_placeholderPattern, (
      match,
    ) {
      final token = match.group(1)?.trim() ?? '';
      final modifier = match.group(2)?.toLowerCase();
      final resolved = _resolveVariable(token, variables);

      return _transformValue(
        key: resolved.key,
        value: resolved.value,
        modifier: modifier,
        encodeKeywordByDefault: encodeKeywordByDefault,
      );
    });

    if (baseUrl == null || baseUrl.trim().isEmpty) {
      return replaced;
    }

    return _resolveWithBaseUrl(replaced, baseUrl);
  }

  _ResolvedVariable _resolveVariable(
    String token,
    Map<String, String> variables,
  ) {
    if (token.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.search,
        briefMessage: 'URL 模板变量不能为空。',
      );
    }

    final directValue = variables[token];
    if (directValue != null) {
      return _ResolvedVariable(key: token, value: directValue);
    }

    final expressionMatch = _offsetExpressionPattern.firstMatch(token);
    if (expressionMatch == null) {
      return _ResolvedVariable(key: token, value: '');
    }

    final baseKey = expressionMatch.group(1)!;
    final operator = expressionMatch.group(2)!;
    final offsetText = expressionMatch.group(3)!;

    final baseValue = variables[baseKey];
    if (baseValue == null) {
      return _ResolvedVariable(key: baseKey, value: '');
    }

    final baseNumber = int.tryParse(baseValue);
    final offsetNumber = int.tryParse(offsetText);
    if (baseNumber == null || offsetNumber == null) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.search,
        briefMessage: 'URL 模板变量不支持算术运算：$token',
      );
    }

    final computedValue =
        operator == '+' ? baseNumber + offsetNumber : baseNumber - offsetNumber;

    return _ResolvedVariable(key: baseKey, value: computedValue.toString());
  }

  String _transformValue({
    required String key,
    required String value,
    required String? modifier,
    required bool encodeKeywordByDefault,
  }) {
    switch (modifier) {
      case null:
        if (encodeKeywordByDefault && (key == 'key' || key == 'keyword')) {
          return Uri.encodeQueryComponent(value);
        }
        return value;
      case 'raw':
        return value;
      case 'encode':
        return Uri.encodeQueryComponent(value);
      default:
        throw AppException(
          code: ErrorCode.validation,
          stage: ErrorStage.search,
          briefMessage: '不支持的模板变量修饰符：$modifier',
        );
    }
  }

  String _resolveWithBaseUrl(String pathOrUrl, String baseUrl) {
    final normalized = pathOrUrl.trim();
    final uri = Uri.tryParse(normalized);
    if (uri != null && uri.hasScheme) {
      return normalized;
    }

    if (_looksLikeHtmlFragment(normalized)) {
      return normalized;
    }

    final baseUri = Uri.tryParse(baseUrl);
    if (baseUri == null || !baseUri.hasScheme) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.search,
        briefMessage: 'baseUrl 非法：$baseUrl',
      );
    }

    try {
      return baseUri.resolve(normalized).toString();
    } on FormatException {
      return normalized;
    }
  }

  bool _looksLikeHtmlFragment(String value) {
    final normalized = value.trimLeft().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }

    if (normalized.startsWith('<!doctype') ||
        normalized.startsWith('<html') ||
        normalized.startsWith('<body') ||
        normalized.startsWith('<div') ||
        normalized.startsWith('<p') ||
        normalized.startsWith('<span') ||
        normalized.startsWith('<script')) {
      return true;
    }

    return RegExp(r'^<[^>]+>').hasMatch(normalized);
  }
}

class _ResolvedVariable {
  const _ResolvedVariable({required this.key, required this.value});

  final String key;
  final String value;
}
