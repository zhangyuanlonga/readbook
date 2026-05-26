import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/core/errors/error_stage.dart';
import 'package:shuxiang_reading_next/core/errors/gateway_failure.dart';
import 'package:shuxiang_reading_next/features/search/application/search_models.dart';
import 'package:shuxiang_reading_next/features/search/presentation/widgets/search_failure_banner.dart';

void main() {
  testWidgets('shows gateway failure code, hint, and retry suggestion', (
    tester,
  ) async {
    const report = SearchExecutionReport(
      keyword: '剑来',
      sourceCount: 1,
      successSourceCount: 0,
      books: [],
      sourceNames: {'server-gateway:source_a': '测试源'},
      failures: [
        SourceSearchFailure(
          sourceId: 'server-gateway:source_a',
          sourceName: '测试源',
          message: '搜索超时',
          code: ErrorCode.network,
          stage: ErrorStage.search,
          gatewayFailure: GatewayFailure(
            stage: 'search',
            category: 'timeout',
            code: 'UPSTREAM_TIMEOUT',
            message: '搜索超时',
            retryable: true,
            hint: '降低并发后重试',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SearchFailureBanner(report: report)),
      ),
    );

    expect(find.text('1 个书源异常'), findsOneWidget);

    await tester.tap(find.byType(SearchFailureBanner));
    await tester.pumpAndSettle();

    expect(find.text('UPSTREAM_TIMEOUT'), findsOneWidget);
    expect(find.text('降低并发后重试'), findsOneWidget);
    expect(find.text('可以稍后重试，或切换其他书源。'), findsOneWidget);
  });
}
