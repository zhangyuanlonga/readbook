import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/search/presentation/widgets/online_search_gate_card.dart';

void main() {
  testWidgets('shows login required message and retry action', (tester) async {
    var retryCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnlineSearchGateCard(
            isChecking: false,
            message: '请登录后查看',
            onRetry: () {
              retryCount += 1;
            },
          ),
        ),
      ),
    );

    expect(find.text('在线搜索暂不可用'), findsOneWidget);
    expect(find.text('请登录后查看'), findsOneWidget);

    await tester.tap(find.text('重试'));
    expect(retryCount, 1);
  });

  testWidgets('shows progress while checking access', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnlineSearchGateCard(
            isChecking: true,
            message: null,
            onRetry: () {},
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('在线搜索暂不可用'), findsNothing);
  });
}
