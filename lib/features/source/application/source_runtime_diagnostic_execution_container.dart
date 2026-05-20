import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../runtime/sources/source_registry.dart';
import '../../../runtime/sources/source_result_models.dart' as runtime_models;

class SourceRuntimeDiagnosticExecutionContainer {
  const SourceRuntimeDiagnosticExecutionContainer({
    required this.source,
  });

  final RegisteredSource source;

  Future<runtime_models.Book> detail(runtime_models.Book book) async {
    throw AppException(
      code: ErrorCode.unknownSource,
      stage: ErrorStage.detail,
      sourceId: source.runtime.id,
      briefMessage: '该本地脚本书源能力已移除，请重新搜索并加入服务器书源版本。',
    );
  }

  Future<List<runtime_models.Chapter>> chapters(runtime_models.Book book) async {
    throw AppException(
      code: ErrorCode.unknownSource,
      stage: ErrorStage.toc,
      sourceId: source.runtime.id,
      briefMessage: '该本地脚本书源能力已移除，请重新搜索并加入服务器书源版本。',
    );
  }

  void dispose() {}
}
