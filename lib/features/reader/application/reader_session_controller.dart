enum ReaderSessionTaskKind { chapterContent, preload, pagination }

class ReaderSessionTaskToken {
  const ReaderSessionTaskToken({required this.kind, required this.generation});

  final ReaderSessionTaskKind kind;
  final int generation;
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
