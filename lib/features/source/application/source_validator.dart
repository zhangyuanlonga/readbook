import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../domain/entities/source_definition.dart';

class SourceValidator {
  const SourceValidator();

  void validateAll(List<SourceDefinition> sources) {
    for (var i = 0; i < sources.length; i++) {
      validate(sources[i], index: i + 1);
    }
  }

  void validate(SourceDefinition source, {int? index}) {
    final prefix = index == null ? '' : '第 $index 条书源：';

    if (source.name.trim().isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.source,
        briefMessage: '$prefix书源名称不能为空。',
      );
    }

    final searchRule = source.rules.searchRule?.trim() ?? '';
    if (searchRule.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.source,
        briefMessage: '$prefix缺少搜索规则（ruleSearch/searchUrl）。',
      );
    }

    if (!_hasSearchParseRules(source)) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.source,
        briefMessage: '$prefix缺少搜索解析规则（列表/标题/详情链接）。',
      );
    }

    final baseUrl = source.baseUrl.trim();
    if (!_hasValidHttpBaseUrl(baseUrl) && !_hasAbsoluteSearchUrl(searchRule)) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.source,
        briefMessage: '$prefix书源 URL 非法：$baseUrl',
      );
    }
  }

  List<String> collectCompatibilityWarnings(SourceDefinition source) {
    final warnings = <String>[];

    if (!source.isMangaSource && !_hasTocParseRules(source)) {
      warnings.add('目录规则不完整（chapterList/chapterName/chapterUrl），目录诊断可能失败。');
    }

    if (!_hasContentRule(source)) {
      warnings.add('缺少正文规则（ruleContent），正文诊断可能失败。');
    }

    final searchRule = source.rules.searchRule?.trim() ?? '';
    final baseUrl = source.baseUrl.trim();
    if (!_hasValidHttpBaseUrl(baseUrl) && _hasAbsoluteSearchUrl(searchRule)) {
      warnings.add('baseUrl 非法，虽然可依赖绝对 searchUrl 搜索，但详情/目录阶段可能失败。');
    }

    return List.unmodifiable(warnings);
  }

  bool _hasSearchParseRules(SourceDefinition source) {
    return _isPresent(source.rules.searchListRule) &&
        _isPresent(source.rules.searchTitleRule) &&
        _isPresent(source.rules.searchDetailUrlRule);
  }

  bool _hasTocParseRules(SourceDefinition source) {
    return _isPresent(source.rules.tocListRule) &&
        _isPresent(source.rules.tocTitleRule) &&
        _isPresent(source.rules.tocChapterUrlRule);
  }

  bool _hasContentRule(SourceDefinition source) {
    return _isPresent(source.rules.contentRule) ||
        _isPresent(source.rules.contentDecryptRule);
  }

  bool _isPresent(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  bool _hasValidHttpBaseUrl(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    final isHttp =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    return isHttp && uri.host.isNotEmpty;
  }

  bool _hasAbsoluteSearchUrl(String searchRule) {
    final normalized = searchRule.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final direct = RegExp(r'^(https?://)').hasMatch(normalized);
    if (direct) {
      return true;
    }

    return RegExp(r'https?://').hasMatch(normalized);
  }
}
