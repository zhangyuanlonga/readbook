import 'dart:convert';

import '../../errors/app_exception.dart';
import '../../errors/error_codes.dart';
import '../../errors/error_stage.dart';
import '../rule_parser.dart';

class JsonExecutor {
  const JsonExecutor();

  static final RegExp _templatePattern = RegExp(r'\{\{\s*(.+?)\s*\}\}');

  List<String> execute({
    required String content,
    required ParsedJsonRule rule,
    required ErrorStage stage,
  }) {
    final root = _decodeJson(content, stage);
    final segments = _splitPipeline(rule.expression);
    if (segments.isEmpty) {
      throw _ruleError('JSON 规则不能为空。', stage);
    }

    var values = _normalizePipelineValues(
      _evaluatePathSegment(root, segments.first, stage),
    );

    for (final segment in segments.skip(1)) {
      if (_isInlineJsSegment(segment)) {
        values = values
            .map((value) => _evaluateInlineJs(segment, value, stage))
            .toList(growable: false);
        continue;
      }

      if (_looksLikeJsonPathSegment(segment)) {
        values = _normalizePipelineValues(
          values
              .expand((value) => _evaluatePathSegment(value, segment, stage))
              .toList(growable: false),
        );
        continue;
      }

      values = values
          .map((value) => _applyTemplateSegment(segment, value, stage))
          .toList(growable: false);
    }

    final normalized = _normalizePipelineValues(values)
        .map(_toOutputText)
        .where((text) => text.trim().isNotEmpty)
        .toList(growable: false);

    if (normalized.isEmpty) {
      throw RuleMatchEmptyException(
        briefMessage: 'JSON 规则未命中有效内容。',
        stage: stage,
      );
    }

    return normalized;
  }

  dynamic _decodeJson(String source, ErrorStage stage) {
    try {
      return jsonDecode(source);
    } on FormatException catch (error, stackTrace) {
      throw AppException(
        code: ErrorCode.decode,
        stage: stage,
        briefMessage: 'JSON 解析失败：${error.message}',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  List<String> _splitPipeline(String expression) {
    final normalized = expression.replaceAll(r'\n', '\n');
    final rawLines = normalized.split('\n');
    final segments = <String>[];
    final templateBuffer = StringBuffer();

    void flushTemplateBuffer() {
      if (templateBuffer.isEmpty) {
        return;
      }
      final segment = templateBuffer.toString().trim();
      templateBuffer.clear();
      if (segment.isNotEmpty) {
        segments.add(segment);
      }
    }

    for (final rawLine in rawLines) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      final isPathSegment = _looksLikeJsonPathSegment(trimmed);
      final isJsSegment = _isInlineJsSegment(trimmed);
      if (isPathSegment || isJsSegment) {
        flushTemplateBuffer();
        segments.add(trimmed);
        continue;
      }

      if (templateBuffer.isNotEmpty) {
        templateBuffer.write('\n');
      }
      templateBuffer.write(rawLine);
    }

    flushTemplateBuffer();
    return List.unmodifiable(segments);
  }

  bool _looksLikeJsonPathSegment(String segment) {
    final token = segment.trim();
    return token.startsWith(r'$') || token.startsWith(r'\$');
  }

  List<dynamic> _evaluatePathSegment(
    dynamic root,
    String segment,
    ErrorStage stage,
  ) {
    final parsed = _parseSegment(segment);
    final matched = _queryPath(root, parsed.path, stage);
    if (matched.isEmpty) {
      return const [];
    }

    if (parsed.replacePattern == null) {
      return matched;
    }

    final regex = _buildRegex(parsed.replacePattern!, stage);
    final replacement = parsed.replaceValue ?? '';

    return matched
        .map((value) {
          final text = _toOutputText(value);
          return text.replaceAll(regex, replacement);
        })
        .toList(growable: false);
  }

  _JsonRuleSegment _parseSegment(String segment) {
    final parts = segment.split('##');
    final path = parts.first.trim();

    if (parts.length == 1) {
      return _JsonRuleSegment(path: path);
    }

    final replacePattern = parts[1].trim();
    final replaceValue =
        parts.length >= 3 ? parts.sublist(2).join('##').trim() : '';

    return _JsonRuleSegment(
      path: path,
      replacePattern: replacePattern,
      replaceValue: replaceValue,
    );
  }

  RegExp _buildRegex(String pattern, ErrorStage stage) {
    try {
      return RegExp(pattern);
    } on FormatException {
      throw _ruleError('JSON 替换规则正则不合法：$pattern', stage);
    }
  }

  List<dynamic> _normalizePipelineValues(List<dynamic> values) {
    final normalized = <dynamic>[];
    for (final value in values) {
      if (value is List) {
        normalized.addAll(value);
      } else {
        normalized.add(value);
      }
    }
    return normalized;
  }

  List<dynamic> _queryPath(dynamic root, String path, ErrorStage stage) {
    var normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      throw _ruleError('JSONPath 不能为空。', stage);
    }

    if (normalizedPath.startsWith(r'\$')) {
      normalizedPath = normalizedPath.substring(1);
    }

    if (normalizedPath == r'$') {
      return [root];
    }

    if (!normalizedPath.startsWith(r'$')) {
      throw _ruleError('JSONPath 必须以 \$ 开头：$normalizedPath', stage);
    }

    var nodes = <dynamic>[root];
    var cursor = 1;

    while (cursor < normalizedPath.length) {
      final char = normalizedPath[cursor];

      if (char == '.') {
        cursor += 1;
        final start = cursor;
        while (cursor < normalizedPath.length) {
          final current = normalizedPath[cursor];
          final isWord = RegExp(r'[a-zA-Z0-9_]').hasMatch(current);
          if (!isWord) {
            break;
          }
          cursor += 1;
        }

        final key = normalizedPath.substring(start, cursor).trim();
        if (key.isEmpty) {
          throw _ruleError('JSONPath 字段为空：$normalizedPath', stage);
        }

        nodes = _expandByKey(nodes, key);
        continue;
      }

      if (char == '[') {
        final end = normalizedPath.indexOf(']', cursor);
        if (end <= cursor) {
          throw _ruleError('JSONPath 缺少 ]：$normalizedPath', stage);
        }

        final token = normalizedPath.substring(cursor + 1, end).trim();
        nodes = _expandByBracket(nodes, token, stage);
        cursor = end + 1;
        continue;
      }

      throw _ruleError('JSONPath 语法不支持：$normalizedPath', stage);
    }

    return nodes;
  }

  List<dynamic> _expandByKey(List<dynamic> nodes, String key) {
    final output = <dynamic>[];

    for (final node in nodes) {
      if (node is Map && node.containsKey(key)) {
        output.add(node[key]);
      }
    }

    return output;
  }

  List<dynamic> _expandByBracket(
    List<dynamic> nodes,
    String token,
    ErrorStage stage,
  ) {
    if (token == '*') {
      final output = <dynamic>[];
      for (final node in nodes) {
        if (node is List) {
          output.addAll(node);
        } else if (node is Map) {
          output.addAll(node.values);
        }
      }
      return output;
    }

    final index = int.tryParse(token);
    if (index != null) {
      final output = <dynamic>[];
      for (final node in nodes) {
        if (node is List && index >= 0 && index < node.length) {
          output.add(node[index]);
        }
      }
      return output;
    }

    final isQuoted =
        (token.startsWith('"') && token.endsWith('"')) ||
        (token.startsWith("'") && token.endsWith("'"));
    if (isQuoted && token.length >= 2) {
      final key = token.substring(1, token.length - 1);
      return _expandByKey(nodes, key);
    }

    throw _ruleError('JSONPath [] 语法不支持：[$token]', stage);
  }

  bool _isInlineJsSegment(String segment) {
    return segment.startsWith('<js>') && segment.endsWith('</js>');
  }

  String _evaluateInlineJs(String segment, dynamic value, ErrorStage stage) {
    final script = segment.substring(4, segment.length - 5).trim();
    final result = _toOutputText(value).trim();

    if (script == 'result') {
      return result;
    }

    if (script == 'parseInt(result)') {
      final parsed = int.tryParse(result);
      if (parsed == null) {
        throw _ruleError('inline js parseInt(result) 执行失败。', stage);
      }
      return parsed.toString();
    }

    final leftAdd = RegExp(
      r'^(\d+)\s*\+\s*parseInt\(result\)$',
    ).firstMatch(script);
    if (leftAdd != null) {
      final constant = int.parse(leftAdd.group(1)!);
      final parsed = int.tryParse(result);
      if (parsed == null) {
        throw _ruleError('inline js 加法执行失败：$script', stage);
      }
      return (constant + parsed).toString();
    }

    final rightAdd = RegExp(
      r'^parseInt\(result\)\s*\+\s*(\d+)$',
    ).firstMatch(script);
    if (rightAdd != null) {
      final parsed = int.tryParse(result);
      if (parsed == null) {
        throw _ruleError('inline js 加法执行失败：$script', stage);
      }
      final constant = int.parse(rightAdd.group(1)!);
      return (parsed + constant).toString();
    }

    final rightSub = RegExp(
      r'^parseInt\(result\)\s*-\s*(\d+)$',
    ).firstMatch(script);
    if (rightSub != null) {
      final parsed = int.tryParse(result);
      if (parsed == null) {
        throw _ruleError('inline js 减法执行失败：$script', stage);
      }
      final constant = int.parse(rightSub.group(1)!);
      return (parsed - constant).toString();
    }

    throw _ruleError('inline js 暂不支持：$script', stage);
  }

  String _applyTemplateSegment(
    String segment,
    dynamic value,
    ErrorStage stage,
  ) {
    return segment.replaceAllMapped(_templatePattern, (match) {
      final token = match.group(1)?.trim() ?? '';
      return _resolveTemplateToken(token, value, stage);
    });
  }

  String _resolveTemplateToken(String token, dynamic value, ErrorStage stage) {
    if (token.isEmpty) {
      return '';
    }

    if (token == 'result') {
      return _toOutputText(value);
    }

    if (_looksLikeJsonPathSegment(token)) {
      final result = _queryPath(value, token, stage);
      if (result.isEmpty) {
        return '';
      }
      return _toOutputText(result.first);
    }

    final baseMatch = RegExp(
      r'^baseUrl\.match\(/(.+?)/\)\[(\d+)\]$',
    ).firstMatch(token);
    if (baseMatch != null) {
      final baseUrl = _extractMapValue(value, 'baseUrl');
      if (baseUrl == null) {
        return '';
      }

      final regexSource = baseMatch.group(1)!;
      final groupIndex = int.tryParse(baseMatch.group(2)!) ?? 0;

      final regex = RegExp(regexSource);
      final matched = regex.firstMatch(baseUrl);
      if (matched == null || groupIndex > matched.groupCount) {
        return '';
      }
      return matched.group(groupIndex) ?? '';
    }

    final simpleValue = _extractMapValue(value, token);
    if (simpleValue != null) {
      return simpleValue;
    }

    return '';
  }

  String? _extractMapValue(dynamic value, String key) {
    if (value is! Map) {
      return null;
    }

    if (!value.containsKey(key)) {
      return null;
    }

    return _toOutputText(value[key]);
  }

  String _toOutputText(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      return value;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    if (value is List || value is Map) {
      return jsonEncode(value);
    }
    return value.toString();
  }

  AppException _ruleError(String message, ErrorStage stage) {
    return AppException(
      code: ErrorCode.ruleParse,
      stage: stage,
      briefMessage: message,
    );
  }
}

class _JsonRuleSegment {
  const _JsonRuleSegment({
    required this.path,
    this.replacePattern,
    this.replaceValue,
  });

  final String path;
  final String? replacePattern;
  final String? replaceValue;
}
