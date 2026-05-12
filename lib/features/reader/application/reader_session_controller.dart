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

class ReaderSessionController {
  int _chapterContentGeneration = 0;
  int _preloadGeneration = 0;
  int _paginationGeneration = 0;

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
