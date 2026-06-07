import 'reader_pagination_engine.dart';
import 'reader_pagination_spec.dart';

class ReaderPaginationController {
  const ReaderPaginationController({
    ReaderPaginationEngine paginationEngine = const ReaderPaginationEngine(),
    ReaderPaginationSpecResolver paginationSpecResolver =
        const ReaderPaginationSpecResolver(),
  }) : _paginationEngine = paginationEngine,
       _paginationSpecResolver = paginationSpecResolver;

  final ReaderPaginationEngine _paginationEngine;
  final ReaderPaginationSpecResolver _paginationSpecResolver;

  String buildSignature({
    required String chapterId,
    required ReaderPaginationSpec spec,
  }) {
    return _paginationSpecResolver.buildSignature(
      chapterId: chapterId,
      spec: spec,
    );
  }

  ReaderPaginationEnsurePlan buildEnsurePlan({
    required ReaderPaginationSpec spec,
    required String chapterId,
    required ReaderPaginationSessionState currentState,
    required bool hasExistingPages,
    required double currentProgressRatio,
  }) {
    final signature = buildSignature(chapterId: chapterId, spec: spec);
    return _paginationEngine.buildEnsurePlan(
      ReaderPaginationEnsureRequest(
        spec: spec,
        signature: signature,
        currentState: currentState,
        hasExistingPages: hasExistingPages,
        currentProgressRatio: currentProgressRatio,
      ),
    );
  }
}
