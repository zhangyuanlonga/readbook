import 'package:flutter/material.dart';
import 'package:flutter_appread/domain/entities/book.dart';
import 'package:flutter_appread/domain/entities/book_detail.dart';
import 'package:flutter_appread/domain/entities/chapter.dart';
import 'package:flutter_appread/features/book/application/book_detail_service.dart';
import 'package:flutter_appread/features/book/presentation/book_detail_page.dart';
import 'package:flutter_appread/features/search/application/search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('switches to selected source from detail switch sheet', (
    tester,
  ) async {
    final resultA = BookDetailLoadResult(
      detail: const BookDetail(
        id: 'book_a',
        sourceId: 'source_a',
        title: '凡人修仙传-A',
        detailUrl: 'https://a.example.com/detail',
        author: '忘语',
      ),
      chapters: const <Chapter>[
        Chapter(
          id: 'a_1',
          bookId: 'book_a',
          title: '第1章 入门',
          chapterUrl: 'https://a.example.com/c1',
          index: 0,
        ),
      ],
      sourceName: '源A',
      tocFromCache: false,
    );
    final resultB = BookDetailLoadResult(
      detail: const BookDetail(
        id: 'book_b',
        sourceId: 'source_b',
        title: '凡人修仙传-B',
        detailUrl: 'https://b.example.com/detail',
        author: '忘语',
      ),
      chapters: const <Chapter>[
        Chapter(
          id: 'b_1',
          bookId: 'book_b',
          title: '第1章 入门',
          chapterUrl: 'https://b.example.com/c1',
          index: 0,
        ),
      ],
      sourceName: '源B',
      tocFromCache: false,
    );

    final detailService = _FakeBookDetailService(
      bySourceId: <String, BookDetailLoadResult>{
        'source_a': resultA,
        'source_b': resultB,
      },
    );
    final searchService = _FakeSearchService(
      const SearchExecutionReport(
        keyword: '凡人修仙传',
        sourceCount: 2,
        successSourceCount: 2,
        books: <Book>[
          Book(
            id: 'book_a',
            sourceId: 'source_a',
            title: '凡人修仙传-A',
            detailUrl: 'https://a.example.com/detail',
            author: '忘语',
            latestChapter: '第2章',
          ),
          Book(
            id: 'book_b',
            sourceId: 'source_b',
            title: '凡人修仙传-A',
            detailUrl: 'https://b.example.com/detail',
            author: '忘语',
            latestChapter: '第3章',
          ),
        ],
        failures: <SourceSearchFailure>[],
        sourceNames: <String, String>{'source_a': '源A', 'source_b': '源B'},
      ),
    );

    final router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder:
              (context, state) => BookDetailPage(
                bookId: 'book_a',
                sourceId: 'source_a',
                detailUrl: 'https://a.example.com/detail',
                title: '凡人修仙传',
                bookDetailService: detailService,
                switchSourceSearchService: searchService,
                cachedChapterCountStreamBuilder: (_) => Stream<int>.value(0),
              ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle(const Duration(milliseconds: 120));

    expect(find.text('凡人修仙传-A'), findsWidgets);
    final switchButtonFinder = find.text('去换源');
    expect(switchButtonFinder, findsOneWidget);

    await tester.tap(switchButtonFinder);
    for (
      var i = 0;
      i < 24 && find.textContaining('切换书源（').evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(find.textContaining('切换书源（'), findsOneWidget);
    for (var i = 0; i < 24 && find.textContaining('源B').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.textContaining('源B'), findsWidgets);

    await tester.tap(find.textContaining('源B').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 360));

    expect(find.text('凡人修仙传-B'), findsWidgets);
    expect(find.text('已切换到 源B。'), findsOneWidget);
    expect(detailService.loadedSourceIds, <String>['source_a', 'source_b']);
    expect(searchService.callCount, 1);
  });
}

class _FakeBookDetailService extends BookDetailService {
  _FakeBookDetailService({
    required Map<String, BookDetailLoadResult> bySourceId,
  }) : _bySourceId = bySourceId,
       super();

  final Map<String, BookDetailLoadResult> _bySourceId;
  final List<String> loadedSourceIds = <String>[];

  @override
  Future<BookDetailLoadResult> load({
    required String sourceId,
    required String bookId,
    required String detailUrl,
    String? fallbackTitle,
    String? fallbackAuthor,
    bool forceRefresh = false,
  }) async {
    loadedSourceIds.add(sourceId);
    final result = _bySourceId[sourceId];
    if (result == null) {
      throw StateError('Missing fake detail result for sourceId=$sourceId');
    }
    return result;
  }
}

class _FakeSearchService extends SearchService {
  _FakeSearchService(this._report) : super();

  final SearchExecutionReport _report;
  int callCount = 0;

  @override
  Future<SearchExecutionReport> search({
    required String keyword,
    int page = 1,
    int pageSize = 20,
    SearchCancellationToken? cancellationToken,
    SearchProgressCallback? onProgress,
    SearchContentMode contentMode = SearchContentMode.novel,
    List<String>? sourceIds,
    bool aggregateByTitleAuthor = false,
  }) async {
    callCount += 1;
    return _report;
  }
}
