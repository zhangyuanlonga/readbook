import 'reader_layout_engine_mode.dart';

class ReaderLayoutDevOptions {
  const ReaderLayoutDevOptions({
    this.mode = ReaderLayoutEngineMode.experimental,
    this.diagnosticsEnabled = false,
    this.includeAdapterMetrics = true,
    this.strictReleaseValidation = false,
  });

  final ReaderLayoutEngineMode mode;
  final bool diagnosticsEnabled;
  final bool includeAdapterMetrics;
  final bool strictReleaseValidation;

  bool get buildsLayout => true;
}

class ReaderLayoutDiagnosticsPresenter {
  const ReaderLayoutDiagnosticsPresenter();

  Map<String, Object?> toReaderDiagnosticsContext(
    ReaderLayoutDiagnostics diagnostics,
  ) {
    return <String, Object?>{
      'layoutRequestedMode': diagnostics.requestedMode.name,
      'layoutEffectiveMode': diagnostics.effectiveMode.name,
      'layoutPageCount': diagnostics.layoutPageCount,
      'layoutElapsedMicros': diagnostics.elapsedMicros,
      'layoutHasFailure': diagnostics.hasFailure,
      if (diagnostics.surfaceKind != null)
        'layoutSurfaceKind': diagnostics.surfaceKind!.name,
      if (diagnostics.failureReason != null)
        'layoutFailureReason': diagnostics.failureReason,
      if (diagnostics.errorMessage != null)
        'layoutErrorMessage': diagnostics.errorMessage,
    };
  }
}
