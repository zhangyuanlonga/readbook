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

    final baseUrl = source.baseUrl.trim();
    final uri = Uri.tryParse(baseUrl);
    final isHttp =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    if ((!isHttp || uri.host.isEmpty) && !_hasAbsoluteSearchUrl(searchRule)) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.source,
        briefMessage: '$prefix书源 URL 非法：$baseUrl',
      );
    }
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
