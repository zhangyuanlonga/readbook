import '../../../core/errors/app_exception.dart';
import '../../search/presentation/online_source_error_presentation.dart';
import '../application/local/local_book_workflow_policy.dart';
import '../application/reader_failure_presentation_service.dart';

class ReaderErrorPresenter {
  const ReaderErrorPresenter({
    OnlineSourceErrorPresentationAdapter onlineSourceErrorAdapter =
        const OnlineSourceErrorPresentationAdapter(),
    ReaderFailurePresentationService failurePresentationService =
        const ReaderFailurePresentationService(),
  }) : _onlineSourceErrorAdapter = onlineSourceErrorAdapter,
       _failurePresentationService = failurePresentationService;

  final OnlineSourceErrorPresentationAdapter _onlineSourceErrorAdapter;
  final ReaderFailurePresentationService _failurePresentationService;

  ReaderFailurePresentation? gatewayPresentationFor(AppException error) {
    if (error.gatewayFailure == null) {
      return null;
    }
    return _failurePresentationService.resolve(error);
  }

  String gatewayFailureStageFor(AppException error) {
    final stage = error.gatewayFailure?.stage.trim();
    if (_isWebViewTaskStage(stage)) {
      return stage!;
    }
    final fallback =
        error.gatewayFailure?.toErrorStage(fallback: error.stage) ??
        error.stage;
    return _isWebViewTaskStage(fallback.name) ? fallback.name : 'content';
  }

  String userReadableError(AppException error, {required bool isLocalContent}) {
    final presentation = gatewayPresentationFor(error);
    if (presentation != null) {
      return presentation.message;
    }
    final message = error.briefMessage;
    if (isLocalContent) {
      return LocalBookWorkflowPolicy.readerLoadError(message);
    }
    return _onlineSourceErrorAdapter.forReaderContentException(error);
  }

  bool _isWebViewTaskStage(String? value) {
    return switch (value?.trim()) {
      'search' || 'detail' || 'toc' || 'content' => true,
      _ => false,
    };
  }
}
