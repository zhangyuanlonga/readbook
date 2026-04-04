part of 'search_service.dart';

class _ScriptSourceSearchRunner {
  const _ScriptSourceSearchRunner({
    required SourceRuntimeFacade? sourceRuntimeFacade,
  }) : _sourceRuntimeFacade = sourceRuntimeFacade;

  final SourceRuntimeFacade? _sourceRuntimeFacade;

  Future<_SourceSearchOutput> run({
    required RegisteredSource source,
    required String keyword,
    required bool allowInteractiveChallenge,
    SearchCancellationToken? cancellationToken,
  }) async {
    final facade = _sourceRuntimeFacade;
    if (facade == null) {
      throw StateError('SourceRuntimeFacade is unavailable.');
    }

    final books = await facade.search(
      sourceId: source.runtime.id,
      keyword: keyword,
      allowInteractiveChallenge: allowInteractiveChallenge,
      cancellationHandle:
          cancellationToken == null
              ? null
              : SessionCancellationHandle(
                isCancelled: () => cancellationToken.isCancelled,
              ),
    );
    return _SourceSearchOutput(
      requestUrl: '',
      method: HttpRequestMethod.get,
      statusCode: 200,
      books:
          books
              .map(
                (book) =>
                    _mapRuntimeBookToDomain(book, sourceId: source.runtime.id),
              )
              .toList(growable: false),
    );
  }

  Book _mapRuntimeBookToDomain(
    runtime_models.Book book, {
    required String sourceId,
  }) {
    final normalizedDetailUrl = book.detailUrl.trim();
    final resolvedId = _buildRuntimeBookId(
      sourceId: sourceId,
      detailUrl: normalizedDetailUrl,
      title: book.title,
    );
    return Book(
      id: resolvedId,
      sourceId: sourceId,
      title: book.title.trim().isEmpty ? '未命名书籍' : book.title.trim(),
      detailUrl: normalizedDetailUrl,
      author: _normalizeOptionalText(book.author),
      intro: _normalizeOptionalText(book.intro),
      coverUrl: _normalizeOptionalText(book.cover),
      latestChapter: _normalizeOptionalText(book.latestChapter),
    );
  }

  String _buildRuntimeBookId({
    required String sourceId,
    required String detailUrl,
    required String title,
  }) {
    final normalizedDetailUrl = detailUrl.trim();
    if (normalizedDetailUrl.isNotEmpty) {
      return '$sourceId:${Uri.encodeComponent(normalizedDetailUrl)}';
    }
    return '$sourceId:${Uri.encodeComponent(title.trim())}';
  }

  String? _normalizeOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}

class _SourceSearchOutput {
  const _SourceSearchOutput({
    required this.requestUrl,
    required this.method,
    required this.statusCode,
    required this.books,
  });

  final String requestUrl;
  final HttpRequestMethod method;
  final int statusCode;
  final List<Book> books;
}
