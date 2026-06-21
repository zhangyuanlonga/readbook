import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/widgets/text_cover_placeholder.dart';

void main() {
  testWidgets('TextCoverPlaceholder renders with theme-driven cover artwork', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4C7D73)),
        ),
        home: const Scaffold(
          body: Center(
            child: TextCoverPlaceholder(
              title: '长夜余火',
              author: '爱潜水的乌贼',
              width: 96,
              height: 136,
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('长'), findsOneWidget);
    expect(find.text('爱潜水的乌贼'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TextCoverPlaceholder stays stable in compact dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF8B6BFF),
            brightness: Brightness.dark,
          ),
        ),
        home: const Scaffold(
          body: Center(
            child: TextCoverPlaceholder(title: '短篇集', width: 48, height: 66),
          ),
        ),
      ),
    );

    expect(find.byType(TextCoverPlaceholder), findsOneWidget);
    expect(find.textContaining('短'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
