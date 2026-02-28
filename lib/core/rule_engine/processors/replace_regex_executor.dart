import 'dart:async';
import 'dart:isolate';

import '../../logging/app_logger.dart';

class ReplaceRegexExecutor {
  ReplaceRegexExecutor({
    this.perRuleTimeout = const Duration(milliseconds: 200),
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;

  final Duration perRuleTimeout;
  final AppLogger _logger;

  Future<String> execute({
    required String content,
    required String replaceRegex,
    String? sourceId,
  }) async {
    final normalized = replaceRegex.trim();
    if (normalized.isEmpty || content.isEmpty) {
      return content;
    }

    var current = content;
    final rules = _splitRules(normalized);
    for (final rule in rules) {
      final pattern = rule.pattern.trim();
      final replacement = rule.replacement;
      if (pattern.isEmpty) {
        continue;
      }

      try {
        current = await Isolate.run<String>(() {
          final regex = RegExp(pattern, dotAll: true);
          return current.replaceAllMapped(
            regex,
            (match) => _resolveReplacement(replacement, match),
          );
        }).timeout(perRuleTimeout);
      } on TimeoutException {
        _logger.warn(
          'replaceRegex rule timeout',
          context: <String, Object?>{
            'sourceId': sourceId,
            'stage': 'content',
            'pattern': pattern,
          },
        );
      } on FormatException catch (error) {
        _logger.warn(
          'replaceRegex pattern parse failed',
          context: <String, Object?>{
            'sourceId': sourceId,
            'stage': 'content',
            'pattern': pattern,
            'briefMessage': error.message,
          },
        );
      }
    }

    return current;
  }

  List<_ReplaceRule> _splitRules(String replaceRegex) {
    return replaceRegex
        .split('&&')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .map((item) {
          final separator = item.indexOf('##');
          if (separator < 0) {
            return _ReplaceRule(pattern: item, replacement: '');
          }

          final pattern = item.substring(0, separator).trim();
          final replacement = item.substring(separator + 2);
          return _ReplaceRule(pattern: pattern, replacement: replacement);
        })
        .where((item) => item.pattern.isNotEmpty)
        .toList(growable: false);
  }

  static String _resolveReplacement(String replacement, Match match) {
    if (replacement.isEmpty) {
      return '';
    }

    return replacement.replaceAllMapped(RegExp(r'\$(\d+)'), (groupMatch) {
      final group = int.tryParse(groupMatch.group(1) ?? '');
      if (group == null || group < 0 || group > match.groupCount) {
        return groupMatch.group(0) ?? '';
      }
      return match.group(group) ?? '';
    });
  }
}

class _ReplaceRule {
  const _ReplaceRule({required this.pattern, required this.replacement});

  final String pattern;
  final String replacement;
}
