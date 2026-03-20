import 'dart:async';
import 'dart:isolate';

import '../../../core/logging/app_logger.dart';
import '../../../domain/entities/reader_replace_rule.dart';

class ReaderReplaceExecutionResult {
  const ReaderReplaceExecutionResult({
    required this.content,
    required this.effectiveRules,
  });

  final String content;
  final List<ReaderReplaceRule> effectiveRules;
}

class ReaderReplaceRuleTestResult {
  const ReaderReplaceRuleTestResult({
    required this.originalText,
    required this.resultText,
    required this.hasMatch,
    required this.hasChange,
    required this.matchCount,
  });

  final String originalText;
  final String resultText;
  final bool hasMatch;
  final bool hasChange;
  final int matchCount;
}

class ReaderReplaceRuleExecutor {
  ReaderReplaceRuleExecutor({AppLogger? logger})
    : _logger = logger ?? AppLogger.instance;

  final AppLogger _logger;

  Future<ReaderReplaceExecutionResult> execute({
    required String content,
    required List<ReaderReplaceRule> rules,
    String? bookTitle,
    String? sourceId,
  }) async {
    if (content.isEmpty || rules.isEmpty) {
      return ReaderReplaceExecutionResult(
        content: content,
        effectiveRules: const <ReaderReplaceRule>[],
      );
    }

    var current = content;
    final effectiveRules = <ReaderReplaceRule>[];

    for (final rule in rules) {
      if (!rule.isValid) {
        continue;
      }

      try {
        final next = await _applyRule(
          current,
          rule: rule,
        ).timeout(Duration(milliseconds: rule.safeTimeoutMs));
        if (next != current) {
          current = next;
          effectiveRules.add(rule);
        }
      } on TimeoutException {
        _logger.warn(
          'reader replace rule timeout',
          context: <String, Object?>{
            'ruleId': rule.id,
            'ruleName': rule.name,
            'bookTitle': bookTitle,
            'sourceId': sourceId,
            'stage': 'reader_replace',
          },
        );
      } on FormatException catch (error) {
        _logger.warn(
          'reader replace rule parse failed',
          context: <String, Object?>{
            'ruleId': rule.id,
            'ruleName': rule.name,
            'pattern': rule.pattern,
            'bookTitle': bookTitle,
            'sourceId': sourceId,
            'briefMessage': error.message,
            'stage': 'reader_replace',
          },
        );
      } catch (error) {
        _logger.warn(
          'reader replace rule execute failed',
          context: <String, Object?>{
            'ruleId': rule.id,
            'ruleName': rule.name,
            'bookTitle': bookTitle,
            'sourceId': sourceId,
            'error': error.toString(),
            'stage': 'reader_replace',
          },
        );
      }
    }

    return ReaderReplaceExecutionResult(
      content: current,
      effectiveRules: List<ReaderReplaceRule>.unmodifiable(effectiveRules),
    );
  }

  Future<String> test({
    required ReaderReplaceRule rule,
    required String text,
  }) async {
    final result = await testDetailed(rule: rule, text: text);
    return result.resultText;
  }

  Future<ReaderReplaceRuleTestResult> testDetailed({
    required ReaderReplaceRule rule,
    required String text,
  }) async {
    if (!rule.isValid || text.isEmpty) {
      return ReaderReplaceRuleTestResult(
        originalText: text,
        resultText: text,
        hasMatch: false,
        hasChange: false,
        matchCount: 0,
      );
    }

    final result = await _probeRule(
      text,
      rule: rule,
    ).timeout(Duration(milliseconds: rule.safeTimeoutMs));
    final resultText = result['output'] as String? ?? text;
    final matchCount = result['matchCount'] as int? ?? 0;
    return ReaderReplaceRuleTestResult(
      originalText: text,
      resultText: resultText,
      hasMatch: matchCount > 0,
      hasChange: resultText != text,
      matchCount: matchCount,
    );
  }

  Future<String> _applyRule(
    String input, {
    required ReaderReplaceRule rule,
  }) async {
    if (!rule.isRegex) {
      return input.replaceAll(rule.pattern, rule.replacement);
    }

    return Isolate.run<String>(() {
      final regex = RegExp(rule.pattern, dotAll: true);
      return input.replaceAllMapped(
        regex,
        (match) => _resolveReplacement(rule.replacement, match),
      );
    });
  }

  static String _resolveReplacement(String replacement, Match match) {
    if (replacement.isEmpty) {
      return '';
    }

    return replacement.replaceAllMapped(RegExp(r'\$(\d+)'), (groupMatch) {
      final groupIndex = int.tryParse(groupMatch.group(1) ?? '');
      if (groupIndex == null ||
          groupIndex < 0 ||
          groupIndex > match.groupCount) {
        return groupMatch.group(0) ?? '';
      }
      return match.group(groupIndex) ?? '';
    });
  }

  Future<Map<String, Object>> _probeRule(
    String input, {
    required ReaderReplaceRule rule,
  }) async {
    if (!rule.isRegex) {
      return <String, Object>{
        'output': input.replaceAll(rule.pattern, rule.replacement),
        'matchCount': _countPlainMatches(input, rule.pattern),
      };
    }

    return Isolate.run<Map<String, Object>>(() {
      final regex = RegExp(rule.pattern, dotAll: true);
      final matches = regex.allMatches(input).toList(growable: false);
      final output = input.replaceAllMapped(
        regex,
        (match) => _resolveReplacement(rule.replacement, match),
      );
      return <String, Object>{'output': output, 'matchCount': matches.length};
    });
  }

  int _countPlainMatches(String input, String pattern) {
    if (pattern.isEmpty) {
      return 0;
    }

    var count = 0;
    var start = 0;
    while (start < input.length) {
      final index = input.indexOf(pattern, start);
      if (index < 0) {
        break;
      }
      count += 1;
      start = index + pattern.length;
    }
    return count;
  }
}
