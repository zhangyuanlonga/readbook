import '../domain/entities/reader_layout_models.dart';
import 'reader_layout_cache_service.dart';
import 'reader_layout_diagnostics_service.dart';
import 'reader_layout_engine.dart';
import 'reader_layout_engine_mode.dart';
import 'reader_layout_request.dart';
import 'reader_layout_stream_controller.dart';

enum ReaderLayoutRendererStateKind { loading, ready, failed }

class ReaderLayoutRendererState {
  const ReaderLayoutRendererState({
    required this.kind,
    required this.requestedMode,
    required this.effectiveMode,
    required this.pages,
    required this.pageIndex,
    required this.completed,
    required this.fromCache,
    required this.diagnostics,
    required this.diagnosticsContext,
    this.errorMessage,
  });

  final ReaderLayoutRendererStateKind kind;
  final ReaderLayoutEngineMode requestedMode;
  final ReaderLayoutEngineMode effectiveMode;
  final List<ReaderLayoutPage> pages;
  final int pageIndex;
  final bool completed;
  final bool fromCache;
  final ReaderLayoutDiagnostics diagnostics;
  final Map<String, Object?> diagnosticsContext;
  final String? errorMessage;

  bool get hasFailure => kind == ReaderLayoutRendererStateKind.failed;

  bool get canRenderLayout {
    return kind == ReaderLayoutRendererStateKind.ready && pages.isNotEmpty;
  }
}

class ReaderLayoutRendererController {
  ReaderLayoutRendererController({
    ReaderLayoutStreamController? streamController,
    ReaderLayoutCacheService? cacheService,
    this.diagnosticsPresenter = const ReaderLayoutDiagnosticsPresenter(),
  }) : _streamController = streamController ?? ReaderLayoutStreamController(),
       _cacheService = cacheService ?? ReaderLayoutCacheService();

  final ReaderLayoutStreamController _streamController;
  final ReaderLayoutCacheService _cacheService;
  final ReaderLayoutDiagnosticsPresenter diagnosticsPresenter;

  Stream<ReaderLayoutRendererState> watch(
    ReaderLayoutRequest request, {
    ReaderLayoutDevOptions options = const ReaderLayoutDevOptions(),
    double targetRatio = 0,
    int? initialPageIndex,
    int nearbyPageRadius = 1,
  }) async* {
    final requestedMode = options.mode;
    final normalizedRatio = targetRatio.clamp(0.0, 1.0);
    final stopwatch = Stopwatch()..start();
    final cacheEntry = await _tryReadCache(request);
    if (cacheEntry != null && cacheEntry.pages.isNotEmpty) {
      stopwatch.stop();
      yield _state(
        kind: ReaderLayoutRendererStateKind.ready,
        requestedMode: requestedMode,
        effectiveMode: ReaderLayoutEngineMode.experimental,
        pages: cacheEntry.pages,
        pageIndex: _resolvePageIndex(
          pageCount: cacheEntry.pages.length,
          targetRatio: normalizedRatio,
          initialPageIndex: initialPageIndex,
        ),
        completed: true,
        fromCache: true,
        elapsedMicros: stopwatch.elapsedMicroseconds,
      );
      return;
    }

    await for (final event in _streamController.layout(
      request,
      targetRatio: normalizedRatio,
      nearbyPageRadius: nearbyPageRadius,
    )) {
      final elapsedMicros = stopwatch.elapsedMicroseconds;
      switch (event.type) {
        case ReaderLayoutStreamEventType.loading:
          yield _state(
            kind: ReaderLayoutRendererStateKind.loading,
            requestedMode: requestedMode,
            effectiveMode: ReaderLayoutEngineMode.experimental,
            pages: const <ReaderLayoutPage>[],
            pageIndex: 0,
            completed: false,
            fromCache: false,
            elapsedMicros: elapsedMicros,
          );
        case ReaderLayoutStreamEventType.currentPageReady:
        case ReaderLayoutStreamEventType.nearbyPageReady:
          if (event.pages.isEmpty) {
            continue;
          }
          yield _state(
            kind: ReaderLayoutRendererStateKind.ready,
            requestedMode: requestedMode,
            effectiveMode: ReaderLayoutEngineMode.experimental,
            pages: event.pages,
            pageIndex: _resolvePageIndex(
              pageCount: event.pages.length,
              targetRatio: normalizedRatio,
              initialPageIndex: initialPageIndex,
            ),
            completed: false,
            fromCache: false,
            elapsedMicros: elapsedMicros,
          );
        case ReaderLayoutStreamEventType.complete:
          stopwatch.stop();
          if (event.pages.isEmpty) {
            yield _failureState(
              requestedMode: requestedMode,
              reason: 'empty_layout_result',
              errorMessage: null,
              elapsedMicros: stopwatch.elapsedMicroseconds,
            );
            continue;
          }
          await _tryWriteCache(
            ReaderLayoutResult(
              request: request,
              pages: event.pages,
              elapsedMicros: stopwatch.elapsedMicroseconds,
            ),
          );
          yield _state(
            kind: ReaderLayoutRendererStateKind.ready,
            requestedMode: requestedMode,
            effectiveMode: ReaderLayoutEngineMode.experimental,
            pages: event.pages,
            pageIndex: _resolvePageIndex(
              pageCount: event.pages.length,
              targetRatio: normalizedRatio,
              initialPageIndex: initialPageIndex,
            ),
            completed: true,
            fromCache: false,
            elapsedMicros: stopwatch.elapsedMicroseconds,
          );
        case ReaderLayoutStreamEventType.cancelled:
          stopwatch.stop();
          yield _failureState(
            requestedMode: requestedMode,
            reason: 'layout_cancelled',
            errorMessage: event.errorMessage,
            elapsedMicros: stopwatch.elapsedMicroseconds,
          );
        case ReaderLayoutStreamEventType.failed:
          stopwatch.stop();
          yield _failureState(
            requestedMode: requestedMode,
            reason: 'layout_stream_failed',
            errorMessage: event.errorMessage,
            elapsedMicros: stopwatch.elapsedMicroseconds,
          );
      }
    }
  }

  void cancelActive() {
    _streamController.cancelActive();
  }

  Future<ReaderLayoutCacheEntry?> _tryReadCache(
    ReaderLayoutRequest request,
  ) async {
    try {
      return await _cacheService.read(request);
    } catch (_) {
      return null;
    }
  }

  Future<void> _tryWriteCache(ReaderLayoutResult result) async {
    try {
      await _cacheService.write(result);
    } catch (_) {
      return;
    }
  }

  ReaderLayoutRendererState _failureState({
    required ReaderLayoutEngineMode requestedMode,
    required String reason,
    required String? errorMessage,
    required int elapsedMicros,
  }) {
    return _state(
      kind: ReaderLayoutRendererStateKind.failed,
      requestedMode: requestedMode,
      effectiveMode: ReaderLayoutEngineMode.experimental,
      pages: const <ReaderLayoutPage>[],
      pageIndex: 0,
      completed: true,
      fromCache: false,
      elapsedMicros: elapsedMicros,
      failureReason: reason,
      errorMessage: errorMessage,
    );
  }

  ReaderLayoutRendererState _state({
    required ReaderLayoutRendererStateKind kind,
    required ReaderLayoutEngineMode requestedMode,
    required ReaderLayoutEngineMode effectiveMode,
    required List<ReaderLayoutPage> pages,
    required int pageIndex,
    required bool completed,
    required bool fromCache,
    required int elapsedMicros,
    String? failureReason,
    String? errorMessage,
  }) {
    final diagnostics = ReaderLayoutDiagnostics(
      requestedMode: requestedMode,
      effectiveMode: effectiveMode,
      layoutPageCount: pages.length,
      elapsedMicros: elapsedMicros,
      failureReason: failureReason,
      errorMessage: errorMessage,
    );
    return ReaderLayoutRendererState(
      kind: kind,
      requestedMode: requestedMode,
      effectiveMode: effectiveMode,
      pages: List<ReaderLayoutPage>.unmodifiable(pages),
      pageIndex: _resolvePageIndex(
        pageCount: pages.length,
        targetRatio: 0,
        initialPageIndex: pageIndex,
      ),
      completed: completed,
      fromCache: fromCache,
      diagnostics: diagnostics,
      diagnosticsContext: diagnosticsPresenter.toReaderDiagnosticsContext(
        diagnostics,
      ),
      errorMessage: errorMessage,
    );
  }

  int _resolvePageIndex({
    required int pageCount,
    required double targetRatio,
    int? initialPageIndex,
  }) {
    if (pageCount <= 0) {
      return 0;
    }
    if (initialPageIndex != null) {
      return initialPageIndex.clamp(0, pageCount - 1);
    }
    return (targetRatio.clamp(0.0, 1.0) * (pageCount - 1)).round().clamp(
      0,
      pageCount - 1,
    );
  }
}
