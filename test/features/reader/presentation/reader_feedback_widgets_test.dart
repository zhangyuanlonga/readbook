import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_feedback_widgets.dart';

void main() {
  testWidgets('ReaderInlineFeedback shows message and handles tap', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderInlineFeedback(
            message: '图片加载失败，点击重试',
            textColor: Colors.red,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('图片加载失败，点击重试'), findsOneWidget);
    await tester.tap(find.byType(ReaderInlineFeedback));
    expect(tapped, isTrue);
  });
}
