import 'reader_layout_engine_mode.dart';

class ReaderLayoutDevOptions {
  const ReaderLayoutDevOptions({
    this.mode = ReaderLayoutEngineMode.legacy,
    this.diagnosticsEnabled = false,
    this.includeAdapterMetrics = true,
  });

  const ReaderLayoutDevOptions.adapterOnlyDiagnostics()
    : mode = ReaderLayoutEngineMode.adapterOnly,
      diagnosticsEnabled = true,
      includeAdapterMetrics = true;

  final ReaderLayoutEngineMode mode;
  final bool diagnosticsEnabled;
  final bool includeAdapterMetrics;

  bool get buildsLayout => mode != ReaderLayoutEngineMode.legacy;
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
      'layoutUsedFallback': diagnostics.usedFallback,
      if (diagnostics.surfaceKind != null)
        'layoutSurfaceKind': diagnostics.surfaceKind!.name,
      if (diagnostics.fallbackReason != null)
        'layoutFallbackReason': diagnostics.fallbackReason,
      if (diagnostics.errorMessage != null)
        'layoutErrorMessage': diagnostics.errorMessage,
    };
  }
}
