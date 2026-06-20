import '../domain/entities/reader_layout_models.dart';
import 'reader_paged_slice_layout_adapter.dart';
import 'reader_pagination_models.dart';
import 'reader_pagination_spec.dart';
import 'reader_surface_position.dart';

enum ReaderLayoutEngineMode { legacy, adapterOnly, experimental }

class ReaderLayoutDiagnostics {
  const ReaderLayoutDiagnostics({
    required this.requestedMode,
    required this.effectiveMode,
    required this.layoutPageCount,
    required this.elapsedMicros,
    this.surfaceKind,
    this.fallbackReason,
    this.errorMessage,
  });

  final ReaderLayoutEngineMode requestedMode;
  final ReaderLayoutEngineMode effectiveMode;
  final int layoutPageCount;
  final int elapsedMicros;
  final ReaderSurfaceKind? surfaceKind;
  final String? fallbackReason;
  final String? errorMessage;

  bool get usedFallback => fallbackReason != null;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'requestedMode': requestedMode.name,
      'effectiveMode': effectiveMode.name,
      'layoutPageCount': layoutPageCount,
      'elapsedMicros': elapsedMicros,
      if (surfaceKind != null) 'surfaceKind': surfaceKind!.name,
      if (fallbackReason != null) 'fallbackReason': fallbackReason,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }
}

class ReaderLayoutBuildResult {
  const ReaderLayoutBuildResult({
    required this.pages,
    required this.diagnostics,
  });

  final List<ReaderLayoutPage> pages;
  final ReaderLayoutDiagnostics diagnostics;

  bool get usedFallback => diagnostics.usedFallback;
}

class ReaderLayoutFallbackRunner {
  const ReaderLayoutFallbackRunner({
    this.adapter = const ReaderPagedSliceLayoutAdapter(),
  });

  final ReaderPagedSliceLayoutAdapter adapter;

  ReaderLayoutBuildResult build({
    required ReaderLayoutEngineMode mode,
    required String chapterId,
    required int chapterIndex,
    required List<String> paragraphs,
    required List<List<ReaderPagedSlice>> pagedPages,
    required ReaderPaginationSpec spec,
    required String layoutSignature,
    ReaderSurfaceKind? surfaceKind,
    int paragraphSeparatorLength = 2,
  }) {
    if (mode == ReaderLayoutEngineMode.legacy) {
      return ReaderLayoutBuildResult(
        pages: const <ReaderLayoutPage>[],
        diagnostics: ReaderLayoutDiagnostics(
          requestedMode: mode,
          effectiveMode: ReaderLayoutEngineMode.legacy,
          layoutPageCount: 0,
          elapsedMicros: 0,
          surfaceKind: surfaceKind,
        ),
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      final pages = adapter.buildPages(
        chapterId: chapterId,
        chapterIndex: chapterIndex,
        paragraphs: paragraphs,
        pagedPages: pagedPages,
        spec: spec,
        layoutSignature: layoutSignature,
        paragraphSeparatorLength: paragraphSeparatorLength,
      );
      stopwatch.stop();
      return ReaderLayoutBuildResult(
        pages: pages,
        diagnostics: ReaderLayoutDiagnostics(
          requestedMode: mode,
          effectiveMode: mode,
          layoutPageCount: pages.length,
          elapsedMicros: stopwatch.elapsedMicroseconds,
          surfaceKind: surfaceKind,
        ),
      );
    } catch (error) {
      stopwatch.stop();
      return ReaderLayoutBuildResult(
        pages: const <ReaderLayoutPage>[],
        diagnostics: ReaderLayoutDiagnostics(
          requestedMode: mode,
          effectiveMode: ReaderLayoutEngineMode.legacy,
          layoutPageCount: 0,
          elapsedMicros: stopwatch.elapsedMicroseconds,
          surfaceKind: surfaceKind,
          fallbackReason: 'adapter_error',
          errorMessage: error.toString(),
        ),
      );
    }
  }
}
