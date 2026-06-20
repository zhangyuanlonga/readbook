import 'dart:async';

import '../domain/entities/reader_layout_models.dart';
import 'reader_layout_engine.dart';
import 'reader_layout_request.dart';

enum ReaderLayoutStreamEventType {
  loading,
  currentPageReady,
  nearbyPageReady,
  complete,
  cancelled,
  failed,
}

class ReaderLayoutStreamEvent {
  const ReaderLayoutStreamEvent({
    required this.type,
    required this.pages,
    required this.completed,
    required this.generation,
    this.errorMessage,
  });

  final ReaderLayoutStreamEventType type;
  final List<ReaderLayoutPage> pages;
  final bool completed;
  final int generation;
  final String? errorMessage;
}

class ReaderLayoutStreamController {
  ReaderLayoutStreamController({
    ReaderLayoutEngine engine = const ReaderLayoutEngine(),
  }) : _engine = engine;

  final ReaderLayoutEngine _engine;
  ReaderLayoutCancellationToken? _activeToken;
  int _generation = 0;

  Stream<ReaderLayoutStreamEvent> layout(
    ReaderLayoutRequest request, {
    double targetRatio = 0,
    int nearbyPageRadius = 1,
  }) {
    _activeToken?.cancel();
    final token = ReaderLayoutCancellationToken();
    _activeToken = token;
    final generation = _generation + 1;
    _generation = generation;

    final controller = StreamController<ReaderLayoutStreamEvent>();
    unawaited(
      _layoutIntoController(
        controller: controller,
        request: request,
        token: token,
        generation: generation,
        targetRatio: targetRatio.clamp(0.0, 1.0),
        nearbyPageRadius: nearbyPageRadius < 0 ? 0 : nearbyPageRadius,
      ),
    );
    return controller.stream;
  }

  void cancelActive() {
    _activeToken?.cancel();
  }

  Future<void> _layoutIntoController({
    required StreamController<ReaderLayoutStreamEvent> controller,
    required ReaderLayoutRequest request,
    required ReaderLayoutCancellationToken token,
    required int generation,
    required double targetRatio,
    required int nearbyPageRadius,
  }) async {
    final pagesSoFar = <ReaderLayoutPage>[];
    final targetOffset = (request.totalContentLength * targetRatio).round();
    var currentPageEmitted = false;
    var currentPageCount = 0;
    var nearbyPageEmitted = false;

    void emit(ReaderLayoutStreamEvent event) {
      if (!controller.isClosed) {
        controller.add(event);
      }
    }

    try {
      emit(
        ReaderLayoutStreamEvent(
          type: ReaderLayoutStreamEventType.loading,
          pages: const <ReaderLayoutPage>[],
          completed: false,
          generation: generation,
        ),
      );

      final result = await _engine.layout(
        request,
        cancellationToken: token,
        onPageReady: (page) {
          if (token.isCancelled) {
            return;
          }
          pagesSoFar.add(page);
          if (!currentPageEmitted && page.endOffset >= targetOffset) {
            currentPageEmitted = true;
            currentPageCount = pagesSoFar.length;
            emit(
              ReaderLayoutStreamEvent(
                type: ReaderLayoutStreamEventType.currentPageReady,
                pages: List<ReaderLayoutPage>.unmodifiable(pagesSoFar),
                completed: false,
                generation: generation,
              ),
            );
          }
          if (currentPageEmitted &&
              !nearbyPageEmitted &&
              pagesSoFar.length >= currentPageCount + nearbyPageRadius) {
            nearbyPageEmitted = true;
            emit(
              ReaderLayoutStreamEvent(
                type: ReaderLayoutStreamEventType.nearbyPageReady,
                pages: List<ReaderLayoutPage>.unmodifiable(pagesSoFar),
                completed: false,
                generation: generation,
              ),
            );
          }
        },
      );

      if (token.isCancelled || result == null) {
        emit(
          ReaderLayoutStreamEvent(
            type: ReaderLayoutStreamEventType.cancelled,
            pages: const <ReaderLayoutPage>[],
            completed: false,
            generation: generation,
          ),
        );
        return;
      }

      if (!currentPageEmitted && result.pages.isNotEmpty) {
        emit(
          ReaderLayoutStreamEvent(
            type: ReaderLayoutStreamEventType.currentPageReady,
            pages: _prefixThrough(
              result.pages,
              _pageIndexForRatio(targetRatio, result.pages.length),
            ),
            completed: false,
            generation: generation,
          ),
        );
      }

      emit(
        ReaderLayoutStreamEvent(
          type: ReaderLayoutStreamEventType.complete,
          pages: result.pages,
          completed: true,
          generation: generation,
        ),
      );
    } catch (error) {
      emit(
        ReaderLayoutStreamEvent(
          type: ReaderLayoutStreamEventType.failed,
          pages: const <ReaderLayoutPage>[],
          completed: false,
          generation: generation,
          errorMessage: error.toString(),
        ),
      );
    } finally {
      await controller.close();
    }
  }

  List<ReaderLayoutPage> _prefixThrough(
    List<ReaderLayoutPage> pages,
    int pageIndex,
  ) {
    if (pages.isEmpty) {
      return const <ReaderLayoutPage>[];
    }
    final end = (pageIndex + 1).clamp(1, pages.length);
    return List<ReaderLayoutPage>.unmodifiable(pages.take(end));
  }

  int _pageIndexForRatio(double ratio, int pageCount) {
    if (pageCount <= 0) {
      return 0;
    }
    return ((pageCount - 1) * ratio).round().clamp(0, pageCount - 1);
  }
}
