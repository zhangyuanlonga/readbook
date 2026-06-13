import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/domain/entities/chapter.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_logical_position.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_progress.dart';
import 'package:shuxiang_reading_next/features/book/application/book_detail_read_route_service.dart';
import 'package:shuxiang_reading_next/features/book/presentation/book_detail_route.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_entry_route_resolver.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_preferences_service.dart';
import 'package:shuxiang_reading_next/features/search/application/search_hit_cache_service.dart';
import 'package:shuxiang_reading_next/features/search/application/search_service.dart';
import 'package:shuxiang_reading_next/features/search/application/server_online_search_service.dart';

void main() {
  group('online reading chain smoke', () {
    late HttpServer server;
    late AppDatabase database;

    setUp(() async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      SharedPreferences.setMockInitialValues(<String, Object>{});
      database = AppDatabase(executor: NativeDatabase.memory());
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen(_handleGatewayRequest);
    });

    tearDown(() async {
      await database.close();
      await server.close(force: true);
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
    });

    test(
      'searches 斗破苍穹, opens detail, reads, saves and restores progress',
      () async {
        final searchService = SearchService(
          serverOnlineSearchService: ServerOnlineSearchService(
            baseUrl: 'http://${server.address.host}:${server.port}/',
            searchHitCacheService: SearchHitCacheService(database: database),
          ),
        );
        final progressReports = <int>[];

        final report = await searchService.search(
          keyword: '斗破苍穹',
          contentMode: SearchContentMode.novel,
          onProgress:
              (report) => progressReports.add(report.processedSourceCount),
        );

        expect(progressReports, isNotEmpty);
        expect(report.keyword, '斗破苍穹');
        expect(report.sourceCount, 1);
        expect(report.successSourceCount, 1);
        expect(report.books, hasLength(1));
        final book = report.books.single;
        expect(book.title, '斗破苍穹');
        expect(book.author, '天蚕土豆');
        expect(book.sourceId, 'server-gateway:source_dpcq');

        final detailRoute = buildBookDetailRoute(
          bookId: book.id,
          sourceId: book.sourceId,
          detailUrl: book.detailUrl,
          title: book.title,
          author: book.author,
          coverUrl: book.coverUrl,
        );
        expect(detailRoute, startsWith('/book/dpcq'));
        expect(detailRoute, contains(Uri.encodeQueryComponent(book.detailUrl)));

        final routeService = BookDetailReadRouteService(
          readerEntryRouteResolver: const ReaderEntryRouteResolver(),
        );
        const chapters = <Chapter>[
          Chapter(
            id: 'volume_1',
            bookId: 'dpcq',
            title: '第一卷',
            chapterUrl: '',
            index: 0,
            isVolume: true,
          ),
          Chapter(
            id: 'chapter_1',
            bookId: 'dpcq',
            title: '第一章 陨落的天才',
            chapterUrl: 'https://novel.example/dpcq/1',
            index: 1,
          ),
        ];

        final readable = routeService.readableChapters(chapters);
        expect(readable, hasLength(1));
        final readerRoute = routeService.buildChapterRoute(
          bookId: book.id,
          sourceId: book.sourceId,
          detailUrl: book.detailUrl,
          chapter: readable.single,
        );
        expect(readerRoute, isNotNull);
        expect(readerRoute, contains('/reader/dpcq/chapter_1'));
        expect(
          readerRoute,
          contains(Uri.encodeQueryComponent('https://novel.example/dpcq/1')),
        );

        final preferencesService = ReaderPreferencesService(database: database);
        final progress = ReadingProgress(
          bookId: book.id,
          sourceId: book.sourceId,
          detailUrl: book.detailUrl,
          chapterId: 'chapter_1',
          chapterUrl: 'https://novel.example/dpcq/1',
          chapterTitle: '第一章 陨落的天才',
          chapterIndex: 1,
          updatedAt: DateTime.parse('2026-06-02T12:00:00.000Z'),
          chapterPositionRatio: 0.42,
          logicalPosition: const ReaderLogicalPosition(
            chapterIndex: 1,
            blockIndex: 8,
            offsetInBlock: 16,
            chapterPositionRatio: 0.42,
          ),
        );
        await preferencesService.saveProgress(progress);

        final restored = await preferencesService.loadProgress(book.id);
        expect(restored, isNotNull);
        expect(restored!.chapterId, 'chapter_1');
        expect(restored.chapterPositionRatio, closeTo(0.42, 0.0001));
        expect(restored.logicalPosition?.blockIndex, 8);

        final restoreRoute = const ReaderEntryRouteResolver()
            .buildRouteFromProgress(restored, openRouteKind: 'progress');
        expect(restoreRoute, contains('/reader/dpcq/chapter_1'));
        expect(restoreRoute, contains('openRouteKind=progress'));
      },
    );
  });
}

Future<void> _handleGatewayRequest(HttpRequest request) async {
  if (request.uri.path != '/v1/books/search/stream' &&
      request.uri.path != '/api/v1/books/search/stream') {
    request.response
      ..statusCode = HttpStatus.notFound
      ..write('not found');
    await request.response.close();
    return;
  }
  expect(request.uri.queryParameters['keyword'], '斗破苍穹');
  expect(request.uri.queryParameters['contentType'], 'novel');

  request.response.statusCode = HttpStatus.ok;
  request.response.headers.contentType = ContentType(
    'text',
    'event-stream',
    charset: 'utf-8',
  );
  _writeSse(request.response, 'start', <String, Object?>{'sourceCount': 1});
  _writeSse(request.response, 'sourceResult', <String, Object?>{
    'sourceId': 'source_dpcq',
    'sourceName': '测试书源',
    'items': <Object?>[
      <String, Object?>{
        'bookId': 'dpcq',
        'sourceId': 'source_dpcq',
        'sourceName': '测试书源',
        'title': '斗破苍穹',
        'author': '天蚕土豆',
        'detailUrl': 'https://novel.example/dpcq',
        'tocUrl': 'https://novel.example/dpcq/toc',
        'coverUrl': 'https://novel.example/dpcq.jpg',
        'latestChapter': '第一章 陨落的天才',
        'sourceHitCount': 1,
      },
    ],
  });
  _writeSse(request.response, 'end', <String, Object?>{
    'items': <Object?>[],
    'reports': <String, Object?>{
      'sourceCount': 1,
      'processedSourceCount': 1,
      'successSourceCount': 1,
      'failures': <Object?>[],
    },
  });
  await request.response.close();
}

void _writeSse(HttpResponse response, String event, Object data) {
  response.write('event: $event\n');
  response.write('data: ${jsonEncode(data)}\n\n');
}
