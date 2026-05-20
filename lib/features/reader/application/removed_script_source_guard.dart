import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../bookshelf/application/local_book_import_service.dart';
import '../../search/application/server_gateway_identity.dart';

bool isRemovedScriptSourceId(String sourceId) {
  final normalized = sourceId.trim();
  if (normalized.isEmpty) {
    return false;
  }
  if (normalized == LocalBookImportService.localBookSourceId) {
    return false;
  }
  if (isServerGatewaySourceId(normalized)) {
    return false;
  }
  return true;
}

String removedScriptSourceMessage() {
  return '该本地脚本书源能力已移除，请重新搜索并加入服务器书源版本。';
}

Never throwRemovedScriptSource({
  required ErrorStage stage,
  String? sourceId,
}) {
  throw AppException(
    code: ErrorCode.unknownSource,
    stage: stage,
    sourceId: sourceId?.trim().isEmpty ?? true ? null : sourceId!.trim(),
    briefMessage: removedScriptSourceMessage(),
  );
}
