import '../errors/error_stage.dart';
import 'executors/html_executor.dart';
import 'executors/json_executor.dart';
import 'executors/regex_executor.dart';
import 'rule_parser.dart';

class RuleEngine {
  RuleEngine({
    RuleParser? parser,
    HtmlExecutor? htmlExecutor,
    RegexExecutor? regexExecutor,
    JsonExecutor? jsonExecutor,
  }) : _parser = parser ?? const RuleParser(),
       _htmlExecutor = htmlExecutor ?? const HtmlExecutor(),
       _regexExecutor = regexExecutor ?? const RegexExecutor(),
       _jsonExecutor = jsonExecutor ?? const JsonExecutor();

  final RuleParser _parser;
  final HtmlExecutor _htmlExecutor;
  final RegexExecutor _regexExecutor;
  final JsonExecutor _jsonExecutor;

  List<String> executeAll({
    required String content,
    required String expression,
    ErrorStage stage = ErrorStage.search,
  }) {
    final parsed = _parser.parse(expression);
    if (parsed is ParsedHtmlRule) {
      return _htmlExecutor.execute(
        content: content,
        rule: parsed,
        stage: stage,
      );
    }

    if (parsed is ParsedRegexRule) {
      return _regexExecutor.execute(
        content: content,
        rule: parsed,
        stage: stage,
      );
    }

    if (parsed is ParsedJsonRule) {
      return _jsonExecutor.execute(
        content: content,
        rule: parsed,
        stage: stage,
      );
    }

    return const [];
  }

  String executeFirst({
    required String content,
    required String expression,
    ErrorStage stage = ErrorStage.search,
  }) {
    final values = executeAll(
      content: content,
      expression: expression,
      stage: stage,
    );

    return values.first;
  }
}
