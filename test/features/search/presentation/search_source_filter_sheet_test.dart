import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/search/application/search_models.dart';
import 'package:shuxiang_reading_next/features/search/application/server_online_search_service.dart';
import 'package:shuxiang_reading_next/features/search/presentation/widgets/search_source_filter_sheet.dart';

import '../../../test_utils/adaptive_test_harness.dart';

void main() {
  testWidgets('shows scope, group, and failed health labels', (tester) async {
    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 420,
        height: 760,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: SearchSourceFilterSheet(
            loadSourcePage: ({
              required SearchContentMode contentMode,
              int page = 1,
              int pageSize = 80,
              String? keyword,
            }) async {
              return const ServerSearchSourcePage(
                page: 1,
                pageSize: 60,
                total: 1,
                hasMore: false,
                items: [
                  ServerSearchSourceSummary(
                    id: 'private_a',
                    name: '私人失败源',
                    contentType: 'novel',
                    enabled: true,
                    group: '玄幻',
                    healthStatus: 'failed',
                    sourceType: 'private',
                  ),
                ],
              );
            },
            loadSourceGroups: ({
              required SearchContentMode contentMode,
              int page = 1,
              int pageSize = 50,
              String? keyword,
            }) async {
              return const ServerSearchSourceGroupPage(
                items: <ServerSearchSourceGroupSummary>[],
                page: 1,
                pageSize: 50,
                total: 0,
                hasMore: false,
              );
            },
            contentMode: SearchContentMode.novel,
            initialSelection: SearchSourceSelection.all,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('书源'));
    await tester.pumpAndSettle();

    expect(find.text('私人失败源'), findsOneWidget);
    expect(find.text('私人 · 检测失败 · 玄幻'), findsOneWidget);
  });

  testWidgets('filters sources and updates apply action', (tester) async {
    final calls = <_SourceLoadCall>[];

    Future<ServerSearchSourcePage> loadSourcePage({
      required SearchContentMode contentMode,
      int page = 1,
      int pageSize = 80,
      String? keyword,
    }) async {
      calls.add(_SourceLoadCall(page: page, keyword: keyword ?? ''));
      final filtered = (keyword ?? '').trim().isNotEmpty;
      return ServerSearchSourcePage(
        page: 1,
        pageSize: pageSize,
        total: 1,
        hasMore: false,
        items: [
          ServerSearchSourceSummary(
            id: filtered ? 'source_filtered' : 'source_all',
            name: filtered ? '玄幻源' : '默认源',
            contentType: 'novel',
            enabled: true,
            group: filtered ? '玄幻' : '默认',
            healthStatus: 'passed',
            sourceType: 'shared',
          ),
        ],
      );
    }

    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 420,
        height: 760,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: SearchSourceFilterSheet(
            loadSourcePage: loadSourcePage,
            loadSourceGroups: ({
              required SearchContentMode contentMode,
              int page = 1,
              int pageSize = 50,
              String? keyword,
            }) async {
              return const ServerSearchSourceGroupPage(
                items: <ServerSearchSourceGroupSummary>[],
                page: 1,
                pageSize: 50,
                total: 0,
                hasMore: false,
              );
            },
            contentMode: SearchContentMode.novel,
            initialSelection: SearchSourceSelection.all,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('书源'));
    await tester.pumpAndSettle();

    expect(find.text('默认源'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '玄幻');
    await tester.pump(const Duration(milliseconds: 330));
    await tester.pumpAndSettle();

    expect(calls.last.keyword, '玄幻');
    expect(find.text('玄幻源'), findsOneWidget);

    await tester.tap(find.text('玄幻源'));
    await tester.pump();

    expect(find.text('搜索 1 个书源'), findsOneWidget);
  });

  testWidgets('shows all sources option and clears group selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 420,
        height: 760,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: SearchSourceFilterSheet(
            loadSourcePage: ({
              required SearchContentMode contentMode,
              int page = 1,
              int pageSize = 80,
              String? keyword,
            }) async {
              return const ServerSearchSourcePage(
                page: 1,
                pageSize: 60,
                total: 0,
                hasMore: false,
                items: <ServerSearchSourceSummary>[],
              );
            },
            loadSourceGroups: ({
              required SearchContentMode contentMode,
              int page = 1,
              int pageSize = 50,
              String? keyword,
            }) async {
              return const ServerSearchSourceGroupPage(
                items: <ServerSearchSourceGroupSummary>[
                  ServerSearchSourceGroupSummary(
                    name: '免费公开书源',
                    totalSourceCount: 15,
                    availableSourceCount: 10,
                  ),
                ],
                page: 1,
                pageSize: 50,
                total: 1,
                hasMore: false,
              );
            },
            contentMode: SearchContentMode.novel,
            initialSelection: const SearchSourceSelection(
              groupNames: <String>{'免费公开书源'},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('全部书源'), findsOneWidget);
    expect(find.text('搜索已选 1 个分组'), findsOneWidget);

    await tester.tap(find.text('全部书源'));
    await tester.pump();

    expect(find.text('搜索全部书源'), findsOneWidget);
  });

  testWidgets('keeps source range lazy loaded until list scrolls', (
    tester,
  ) async {
    final calls = <_SourceLoadCall>[];

    Future<ServerSearchSourcePage> loadSourcePage({
      required SearchContentMode contentMode,
      int page = 1,
      int pageSize = 80,
      String? keyword,
    }) async {
      calls.add(_SourceLoadCall(page: page, keyword: keyword ?? ''));
      return ServerSearchSourcePage(
        page: page,
        pageSize: pageSize,
        total: 9,
        hasMore: page == 1,
        items:
            page == 1
                ? List<ServerSearchSourceSummary>.generate(
                  8,
                  (index) => ServerSearchSourceSummary(
                    id: 'source_${index + 1}',
                    name: '源${index + 1}',
                    contentType: 'novel',
                    enabled: true,
                  ),
                )
                : const [
                  ServerSearchSourceSummary(
                    id: 'source_9',
                    name: '源9',
                    contentType: 'novel',
                    enabled: true,
                  ),
                ],
      );
    }

    await tester.pumpWidget(
      AdaptiveTestHarness(
        width: 390,
        height: 430,
        wrapWithMaterialApp: true,
        child: Scaffold(
          body: SearchSourceFilterSheet(
            loadSourcePage: loadSourcePage,
            loadSourceGroups: ({
              required SearchContentMode contentMode,
              int page = 1,
              int pageSize = 50,
              String? keyword,
            }) async {
              return const ServerSearchSourceGroupPage(
                items: <ServerSearchSourceGroupSummary>[],
                page: 1,
                pageSize: 50,
                total: 0,
                hasMore: false,
              );
            },
            contentMode: SearchContentMode.novel,
            initialSelection: SearchSourceSelection.all,
            pageSize: 8,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('书源'));
    await tester.pumpAndSettle();

    expect(calls.map((call) => call.page), <int>[1]);
    expect(find.text('源1', skipOffstage: false), findsOneWidget);
    expect(find.text('已加载 8/9'), findsOneWidget);
    expect(find.text('源9', skipOffstage: false), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();

    expect(calls.map((call) => call.page), contains(2));
    expect(find.text('源9', skipOffstage: false), findsOneWidget);
  });
}

class _SourceLoadCall {
  const _SourceLoadCall({required this.page, required this.keyword});

  final int page;
  final String keyword;
}
