import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../domain/entities/book.dart';
import '../application/search_service.dart';

class SearchRenderStateController {
  SearchRenderStateController({required int pageSize}) : _pageSize = pageSize;

  final int _pageSize;
  final ValueNotifier<SearchRenderState?> renderStateNotifier =
      ValueNotifier<SearchRenderState?>(null);

  int _renderPrepareTicket = 0;
  String? _lastRenderPrepareFingerprint;

  void dispose() {
    renderStateNotifier.dispose();
  }

  void clear() {
    _renderPrepareTicket += 1;
    _lastRenderPrepareFingerprint = null;
    renderStateNotifier.value = null;
  }

  void appendMoreResults() {
    final renderState = renderStateNotifier.value;
    if (renderState == null) {
      return;
    }

    final total = renderState.visibleBooks.length;
    if (total == 0 || renderState.renderedResultCount >= total) {
      return;
    }

    final nextRenderedCount = (renderState.renderedResultCount + _pageSize)
        .clamp(0, total);
    renderStateNotifier.value = renderState.copyWith(
      renderedResultCount: nextRenderedCount,
    );
  }

  Future<void> prepareRenderState({
    required SearchExecutionReport report,
    required int sessionId,
    required int activeSessionId,
    required bool preciseMatch,
    SearchCancellationToken? token,
    bool force = false,
  }) async {
    final currentState = renderStateNotifier.value;
    final fingerprint = _buildRenderPrepareFingerprint(
      report: report,
      preciseMatch: preciseMatch,
    );
    if (!force &&
        currentState != null &&
        _lastRenderPrepareFingerprint == fingerprint) {
      if (!identical(currentState.report, report)) {
        renderStateNotifier.value = currentState.copyWith(report: report);
      }
      return;
    }

    final ticket = ++_renderPrepareTicket;
    final request = _SearchRenderPrepareRequest(
      keyword: report.keyword,
      preciseMatch: preciseMatch,
      books: report.books
          .map(
            (book) => _SearchRenderBookPayload(
              id: book.id,
              title: book.title,
              intro: book.intro,
              latestChapter: book.latestChapter,
            ),
          )
          .toList(growable: false),
    );
    late final _SearchRenderPrepareResult prepared;
    try {
      prepared = await _prepareSearchRenderDataInIsolate(request);
    } catch (error) {
      debugPrint(
        'Search render isolate failed, fallback to UI isolate: $error',
      );
      prepared = _prepareSearchRenderData(request);
    }

    if (ticket != _renderPrepareTicket) {
      return;
    }
    if (sessionId != activeSessionId) {
      return;
    }
    if (token?.isCancelled ?? false) {
      return;
    }

    final booksById = <String, Book>{
      for (final book in report.books) book.id: book,
    };
    final visibleBooks = <Book>[];
    for (final id in prepared.visibleBookIds) {
      final book = booksById[id];
      if (book != null) {
        visibleBooks.add(book);
      }
    }

    final renderedResultCount =
        visibleBooks.length > _pageSize ? _pageSize : visibleBooks.length;

    renderStateNotifier.value = SearchRenderState(
      report: report,
      booksIdentity: fingerprint,
      keyword: report.keyword,
      preciseMatch: preciseMatch,
      visibleBooks: List<Book>.unmodifiable(visibleBooks),
      normalizedIntros: Map<String, String?>.unmodifiable(
        prepared.normalizedIntros,
      ),
      normalizedLatestChapters: Map<String, String?>.unmodifiable(
        prepared.normalizedLatestChapters,
      ),
      renderedResultCount: renderedResultCount,
    );
    _lastRenderPrepareFingerprint = fingerprint;
  }

  String _buildRenderPrepareFingerprint({
    required SearchExecutionReport report,
    required bool preciseMatch,
  }) {
    final books = report.books;
    final buffer =
        StringBuffer()
          ..write(report.keyword)
          ..write('|')
          ..write(preciseMatch ? '1' : '0')
          ..write('|')
          ..write(books.length);
    for (final book in books) {
      buffer
        ..write('|')
        ..write(book.id)
        ..write('@')
        ..write(book.title)
        ..write('@')
        ..write(book.intro ?? '')
        ..write('@')
        ..write(book.latestChapter ?? '');
    }
    return buffer.toString();
  }
}

class SearchRenderState {
  const SearchRenderState({
    required this.report,
    required this.booksIdentity,
    required this.keyword,
    required this.preciseMatch,
    required this.visibleBooks,
    required this.normalizedIntros,
    required this.normalizedLatestChapters,
    required this.renderedResultCount,
  });

  final SearchExecutionReport report;
  final Object booksIdentity;
  final String keyword;
  final bool preciseMatch;
  final List<Book> visibleBooks;
  final Map<String, String?> normalizedIntros;
  final Map<String, String?> normalizedLatestChapters;
  final int renderedResultCount;

  SearchRenderState copyWith({
    SearchExecutionReport? report,
    int? renderedResultCount,
  }) {
    return SearchRenderState(
      report: report ?? this.report,
      booksIdentity: booksIdentity,
      keyword: keyword,
      preciseMatch: preciseMatch,
      visibleBooks: visibleBooks,
      normalizedIntros: normalizedIntros,
      normalizedLatestChapters: normalizedLatestChapters,
      renderedResultCount: renderedResultCount ?? this.renderedResultCount,
    );
  }
}

class _SearchRenderPrepareRequest {
  const _SearchRenderPrepareRequest({
    required this.keyword,
    required this.preciseMatch,
    required this.books,
  });

  final String keyword;
  final bool preciseMatch;
  final List<_SearchRenderBookPayload> books;
}

class _SearchRenderBookPayload {
  const _SearchRenderBookPayload({
    required this.id,
    required this.title,
    this.intro,
    this.latestChapter,
  });

  final String id;
  final String title;
  final String? intro;
  final String? latestChapter;
}

class _SearchRenderPrepareResult {
  const _SearchRenderPrepareResult({
    required this.visibleBookIds,
    required this.normalizedIntros,
    required this.normalizedLatestChapters,
  });

  final List<String> visibleBookIds;
  final Map<String, String?> normalizedIntros;
  final Map<String, String?> normalizedLatestChapters;
}

final RegExp _renderPreciseSpaceRegex = RegExp(r'[\u3000\s]+');
final RegExp _renderHtmlTagRegex = RegExp(r'<[^>]+>');
const Set<String> _renderPreciseTitleSeparators = <String>{
  ' ',
  '-',
  '_',
  '.',
  '·',
  ':',
  '：',
  '/',
  '|',
  '(',
  '（',
  '[',
  '【',
  '<',
  '《',
};
const Set<String> _renderPreciseLeadingWrappers = <String>{
  '《',
  '〈',
  '<',
  '「',
  '『',
  '【',
  '[',
  '(',
  '（',
};
const Set<String> _renderPreciseTrailingWrappers = <String>{
  '》',
  '〉',
  '>',
  '」',
  '』',
  '】',
  ']',
  ')',
  '）',
};

_SearchRenderPrepareResult _prepareSearchRenderData(
  _SearchRenderPrepareRequest request,
) {
  final normalizedKeyword = _normalizeRenderPreciseText(request.keyword);
  final hasPreciseKeyword =
      request.preciseMatch && normalizedKeyword.isNotEmpty;

  final visibleBookIds = <String>[];
  final normalizedIntros = <String, String?>{};
  final normalizedLatestChapters = <String, String?>{};

  for (final book in request.books) {
    if (hasPreciseKeyword &&
        !_isRenderPreciseTitleMatch(book.title, normalizedKeyword)) {
      continue;
    }
    visibleBookIds.add(book.id);
    normalizedIntros[book.id] = _normalizeRenderSnippet(book.intro);
    normalizedLatestChapters[book.id] = _normalizeRenderSnippet(
      book.latestChapter,
    );
  }

  return _SearchRenderPrepareResult(
    visibleBookIds: visibleBookIds,
    normalizedIntros: normalizedIntros,
    normalizedLatestChapters: normalizedLatestChapters,
  );
}

String? _normalizeRenderSnippet(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) {
    return null;
  }

  var normalized = text
      .replaceAll(r'\r\n', '\n')
      .replaceAll(r'\n', '\n')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');

  normalized = normalized
      .replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'\{\{[^{}]*\}\}'), '')
      .replaceAll(RegExp(r'\{\{[^\n\r]*'), '');

  if (_renderHtmlTagRegex.hasMatch(normalized)) {
    normalized = html_parser.parseFragment(normalized).text ?? '';
  }

  normalized =
      normalized
          .replaceAll(RegExp(r'[ \t\u00A0]+'), ' ')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();

  return normalized.isEmpty ? null : normalized;
}

bool _isRenderPreciseTitleMatch(String title, String normalizedKeyword) {
  final normalizedTitle = _normalizeRenderPreciseText(title);
  if (normalizedTitle.isEmpty) {
    return false;
  }

  if (normalizedTitle == normalizedKeyword) {
    return true;
  }

  if (!normalizedTitle.startsWith(normalizedKeyword) ||
      normalizedTitle.length <= normalizedKeyword.length) {
    return false;
  }

  final nextChar = normalizedTitle[normalizedKeyword.length];
  return _renderPreciseTitleSeparators.contains(nextChar);
}

String _normalizeRenderPreciseText(String raw) {
  var normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty) {
    return '';
  }

  if (normalized.contains('<') && normalized.contains('>')) {
    normalized = normalized.replaceAll(_renderHtmlTagRegex, ' ');
  }

  normalized = normalized.replaceAll(_renderPreciseSpaceRegex, ' ').trim();
  return _trimRenderPreciseWrappers(normalized);
}

String _trimRenderPreciseWrappers(String value) {
  var normalized = value;
  while (normalized.isNotEmpty &&
      _renderPreciseLeadingWrappers.contains(normalized[0])) {
    normalized = normalized.substring(1).trimLeft();
  }

  while (normalized.isNotEmpty &&
      _renderPreciseTrailingWrappers.contains(
        normalized[normalized.length - 1],
      )) {
    normalized = normalized.substring(0, normalized.length - 1).trimRight();
  }

  return normalized;
}

Future<_SearchRenderPrepareResult> _prepareSearchRenderDataInIsolate(
  _SearchRenderPrepareRequest request,
) async {
  final message = _searchRenderPrepareRequestToMessage(request);
  final resultMessage = await Isolate.run(
    () => _prepareSearchRenderDataInIsolateEntry(message),
  );
  return _searchRenderPrepareResultFromMessage(resultMessage);
}

Map<String, Object?> _prepareSearchRenderDataInIsolateEntry(
  Map<String, Object?> message,
) {
  final request = _searchRenderPrepareRequestFromMessage(message);
  final result = _prepareSearchRenderData(request);
  return _searchRenderPrepareResultToMessage(result);
}

Map<String, Object?> _searchRenderPrepareRequestToMessage(
  _SearchRenderPrepareRequest request,
) {
  return <String, Object?>{
    'keyword': request.keyword,
    'preciseMatch': request.preciseMatch,
    'books': request.books
        .map(
          (book) => <String, Object?>{
            'id': book.id,
            'title': book.title,
            'intro': book.intro,
            'latestChapter': book.latestChapter,
          },
        )
        .toList(growable: false),
  };
}

_SearchRenderPrepareRequest _searchRenderPrepareRequestFromMessage(
  Map<String, Object?> message,
) {
  final rawBooks =
      (message['books'] as List<Object?>? ?? const <Object?>[])
          .whereType<Map<Object?, Object?>>();
  return _SearchRenderPrepareRequest(
    keyword: message['keyword']?.toString() ?? '',
    preciseMatch: message['preciseMatch'] == true,
    books: rawBooks
        .map(
          (book) => _SearchRenderBookPayload(
            id: book['id']?.toString() ?? '',
            title: book['title']?.toString() ?? '',
            intro: book['intro']?.toString(),
            latestChapter: book['latestChapter']?.toString(),
          ),
        )
        .toList(growable: false),
  );
}

Map<String, Object?> _searchRenderPrepareResultToMessage(
  _SearchRenderPrepareResult result,
) {
  return <String, Object?>{
    'visibleBookIds': result.visibleBookIds,
    'normalizedIntros': result.normalizedIntros,
    'normalizedLatestChapters': result.normalizedLatestChapters,
  };
}

_SearchRenderPrepareResult _searchRenderPrepareResultFromMessage(
  Map<String, Object?> message,
) {
  final rawVisibleIds = (message['visibleBookIds'] as List<Object?>? ??
          const <Object?>[])
      .map((item) => item?.toString() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  Map<String, String?> toNullableStringMap(Object? raw) {
    final map = <String, String?>{};
    if (raw is! Map<Object?, Object?>) {
      return map;
    }
    for (final entry in raw.entries) {
      final key = entry.key?.toString();
      if (key == null || key.isEmpty) {
        continue;
      }
      map[key] = entry.value?.toString();
    }
    return map;
  }

  return _SearchRenderPrepareResult(
    visibleBookIds: rawVisibleIds,
    normalizedIntros: toNullableStringMap(message['normalizedIntros']),
    normalizedLatestChapters: toNullableStringMap(
      message['normalizedLatestChapters'],
    ),
  );
}
