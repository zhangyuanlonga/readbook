import '../../errors/app_exception.dart';
import '../../errors/error_codes.dart';
import '../../errors/error_stage.dart';
import '../rule_parser.dart';

class RegexExecutor {
  const RegexExecutor();

  List<String> execute({
    required String content,
    required ParsedRegexRule rule,
    ErrorStage stage = ErrorStage.search,
  }) {
    final pattern = rule.pattern.trim();
    if (pattern.isEmpty) {
      throw AppException(
        code: ErrorCode.ruleParse,
        stage: stage,
        briefMessage: 'Regex pattern 不能为空。',
      );
    }

    final regExp = RegExp(
      pattern,
      caseSensitive: rule.caseSensitive,
      multiLine: rule.multiLine,
      dotAll: rule.dotAll,
    );

    final matches = regExp.allMatches(content).toList(growable: false);
    if (matches.isEmpty) {
      throw RuleMatchEmptyException(
        briefMessage: 'Regex 规则未命中：$pattern',
        stage: stage,
      );
    }

    final result = <String>[];
    for (final match in matches) {
      if (rule.group > match.groupCount) {
        throw AppException(
          code: ErrorCode.ruleParse,
          stage: stage,
          briefMessage: 'Regex group 越界：group=${rule.group}, count=${match.groupCount}',
        );
      }

      final value = match.group(rule.group)?.trim();
      if (value != null && value.isNotEmpty) {
        result.add(value);
      }
    }

    if (result.isEmpty) {
      throw RuleMatchEmptyException(
        briefMessage: 'Regex 提取结果为空：$pattern',
        stage: stage,
      );
    }

    return result;
  }
}
