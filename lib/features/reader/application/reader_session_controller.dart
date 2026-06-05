import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reader_session_state.dart';

enum ReaderSessionTaskKind { chapterContent, preload, pagination }

enum ReaderSessionIntentKind {
  load,
  jump,
  next,
  previous,
  changeMode,
  changeSettings,
  retry,
}

class ReaderSessionIntent {
  const ReaderSessionIntent(this.kind);

  const ReaderSessionIntent.load() : kind = ReaderSessionIntentKind.load;
  const ReaderSessionIntent.jump() : kind = ReaderSessionIntentKind.jump;
  const ReaderSessionIntent.next() : kind = ReaderSessionIntentKind.next;
  const ReaderSessionIntent.previous()
    : kind = ReaderSessionIntentKind.previous;
  const ReaderSessionIntent.changeMode()
    : kind = ReaderSessionIntentKind.changeMode;
  const ReaderSessionIntent.changeSettings()
    : kind = ReaderSessionIntentKind.changeSettings;
  const ReaderSessionIntent.retry() : kind = ReaderSessionIntentKind.retry;

  final ReaderSessionIntentKind kind;
}

class ReaderSessionTaskToken {
  const ReaderSessionTaskToken({required this.kind, required this.generation});

  final ReaderSessionTaskKind kind;
  final int generation;
}

class ReaderSessionIntentResult {
  const ReaderSessionIntentResult({
    this.chapterContentToken,
    this.preloadTaskToken,
    this.paginationTaskToken,
  });

  final int? chapterContentToken;
  final int? preloadTaskToken;
  final int? paginationTaskToken;
}

final readerSessionControllerProvider = NotifierProvider.family<
  ReaderSessionControllerNotifier,
  ReaderSessionGenerationState,
  String
>(ReaderSessionControllerNotifier.new);

class ReaderSessionControllerNotifier
    extends FamilyNotifier<ReaderSessionGenerationState, String> {
  final ReaderSessionController _controller = ReaderSessionController();

  @override
  ReaderSessionGenerationState build(String arg) {
    return _controller.snapshot;
  }

  int nextChapterContentToken() {
    final token = _controller.nextChapterContentToken();
    state = _controller.snapshot;
    return token;
  }

  int nextPreloadTaskToken() {
    final token = _controller.nextPreloadTaskToken();
    state = _controller.snapshot;
    return token;
  }

  int nextPaginationTaskToken() {
    final token = _controller.nextPaginationTaskToken();
    state = _controller.snapshot;
    return token;
  }

  ReaderSessionTaskToken nextToken(ReaderSessionTaskKind kind) {
    final token = _controller.nextToken(kind);
    state = _controller.snapshot;
    return token;
  }

  ReaderSessionIntentResult beginIntent(ReaderSessionIntent intent) {
    final result = _controller.beginIntent(intent);
    state = _controller.snapshot;
    return result;
  }

  bool isActiveChapterContentToken(int token) {
    return _controller.isActiveChapterContentToken(token);
  }

  bool isActivePreloadTaskToken(int token) {
    return _controller.isActivePreloadTaskToken(token);
  }

  bool isActivePaginationTaskToken(int token) {
    return _controller.isActivePaginationTaskToken(token);
  }

  bool isActive(ReaderSessionTaskToken token) {
    return _controller.isActive(token);
  }

  void cancelChapterContentRequests() {
    _controller.cancelChapterContentRequests();
    state = _controller.snapshot;
  }

  void cancelPreloadTasks() {
    _controller.cancelPreloadTasks();
    state = _controller.snapshot;
  }

  void cancelPaginationTasks() {
    _controller.cancelPaginationTasks();
    state = _controller.snapshot;
  }

  void cancelAll() {
    _controller.cancelAll();
    state = _controller.snapshot;
  }

  /// 页面释放时只需要推进 generation 让异步任务失效，不能同步通知监听者。
  ///
  /// Riverpod 不允许在 `dispose` 等 widget 生命周期里修改 provider state。
  /// 调用方会在当前帧结束后再清理 provider scope。
  void cancelAllForDispose() {
    _controller.cancelAll();
  }

  int get chapterContentGeneration => _controller.chapterContentGeneration;
  int get preloadGeneration => _controller.preloadGeneration;
  int get paginationGeneration => _controller.paginationGeneration;
}

class ReaderSessionController {
  int _chapterContentGeneration = 0;
  int _preloadGeneration = 0;
  int _paginationGeneration = 0;

  ReaderSessionGenerationState get snapshot {
    return ReaderSessionGenerationState(
      chapterContentGeneration: _chapterContentGeneration,
      preloadGeneration: _preloadGeneration,
      paginationGeneration: _paginationGeneration,
    );
  }

  int nextChapterContentToken() {
    _chapterContentGeneration += 1;
    return _chapterContentGeneration;
  }

  int nextPreloadTaskToken() {
    _preloadGeneration += 1;
    return _preloadGeneration;
  }

  int nextPaginationTaskToken() {
    _paginationGeneration += 1;
    return _paginationGeneration;
  }

  ReaderSessionTaskToken nextToken(ReaderSessionTaskKind kind) {
    return ReaderSessionTaskToken(
      kind: kind,
      generation: switch (kind) {
        ReaderSessionTaskKind.chapterContent => nextChapterContentToken(),
        ReaderSessionTaskKind.preload => nextPreloadTaskToken(),
        ReaderSessionTaskKind.pagination => nextPaginationTaskToken(),
      },
    );
  }

  ReaderSessionIntentResult beginIntent(ReaderSessionIntent intent) {
    return switch (intent.kind) {
      ReaderSessionIntentKind.load ||
      ReaderSessionIntentKind.jump ||
      ReaderSessionIntentKind.next ||
      ReaderSessionIntentKind.previous ||
      ReaderSessionIntentKind.retry => _beginChapterContentIntent(),
      ReaderSessionIntentKind.changeMode ||
      ReaderSessionIntentKind.changeSettings => _beginPaginationIntent(),
    };
  }

  ReaderSessionIntentResult _beginChapterContentIntent() {
    cancelPreloadTasks();
    cancelPaginationTasks();
    return ReaderSessionIntentResult(
      chapterContentToken: nextChapterContentToken(),
    );
  }

  ReaderSessionIntentResult _beginPaginationIntent() {
    cancelPreloadTasks();
    return ReaderSessionIntentResult(
      paginationTaskToken: nextPaginationTaskToken(),
    );
  }

  bool isActiveChapterContentToken(int token) {
    return token > 0 && token == _chapterContentGeneration;
  }

  bool isActivePreloadTaskToken(int token) {
    return token > 0 && token == _preloadGeneration;
  }

  bool isActivePaginationTaskToken(int token) {
    return token > 0 && token == _paginationGeneration;
  }

  bool isActive(ReaderSessionTaskToken token) {
    return switch (token.kind) {
      ReaderSessionTaskKind.chapterContent => isActiveChapterContentToken(
        token.generation,
      ),
      ReaderSessionTaskKind.preload => isActivePreloadTaskToken(
        token.generation,
      ),
      ReaderSessionTaskKind.pagination => isActivePaginationTaskToken(
        token.generation,
      ),
    };
  }

  void cancelChapterContentRequests() {
    _chapterContentGeneration += 1;
  }

  void cancelPreloadTasks() {
    _preloadGeneration += 1;
  }

  void cancelPaginationTasks() {
    _paginationGeneration += 1;
  }

  void cancelAll() {
    cancelChapterContentRequests();
    cancelPreloadTasks();
    cancelPaginationTasks();
  }

  int get chapterContentGeneration => _chapterContentGeneration;
  int get preloadGeneration => _preloadGeneration;
  int get paginationGeneration => _paginationGeneration;
}
