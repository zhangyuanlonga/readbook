import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/features/book/presentation/widgets/book_detail_primary_actions.dart';

void main() {
  testWidgets('uses short copy and hides icons on very narrow width', (
    tester,
  ) async {
    await _pumpPrimaryActions(
      tester,
      width: 185,
      isInBookshelf: true,
      isShelfActionLoading: false,
    );

    expect(find.text('阅读'), findsOneWidget);
    expect(find.text('移出'), findsOneWidget);
    expect(find.text('开始阅读'), findsNothing);
    expect(find.text('移出书架'), findsNothing);
    expect(find.byIcon(Icons.chrome_reader_mode_outlined), findsNothing);
    expect(find.byIcon(Icons.bookmark_remove_outlined), findsNothing);
  });

  testWidgets('uses long copy and shows icons on large-phone width', (
    tester,
  ) async {
    await _pumpPrimaryActions(
      tester,
      width: 430,
      isInBookshelf: true,
      isShelfActionLoading: false,
    );

    expect(find.text('开始阅读'), findsOneWidget);
    expect(find.text('移出书架'), findsOneWidget);
    expect(find.text('阅读'), findsNothing);
    expect(find.text('移出'), findsNothing);
    expect(find.byIcon(Icons.chrome_reader_mode_outlined), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_remove_outlined), findsOneWidget);
  });

  testWidgets('keeps short copy but still shows icons between 186-210', (
    tester,
  ) async {
    await _pumpPrimaryActions(
      tester,
      width: 205,
      isInBookshelf: true,
      isShelfActionLoading: false,
    );

    expect(find.text('阅读'), findsOneWidget);
    expect(find.text('移出'), findsOneWidget);
    expect(find.byIcon(Icons.chrome_reader_mode_outlined), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_remove_outlined), findsOneWidget);
  });

  testWidgets('loading state disables shelf button and hides shelf icon', (
    tester,
  ) async {
    await _pumpPrimaryActions(
      tester,
      width: 300,
      isInBookshelf: true,
      isShelfActionLoading: true,
    );

    expect(find.text('处理中'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_remove_outlined), findsNothing);

    final shelfButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('book_detail_shelf_button')),
    );
    expect(shelfButton.onPressed, isNull);

    final readButton = tester.widget<FilledButton>(
      find.byKey(const Key('book_detail_read_button')),
    );
    expect(readButton.onPressed, isNotNull);
  });

  testWidgets('disables read button when onRead callback is null', (
    tester,
  ) async {
    await _pumpPrimaryActions(
      tester,
      width: 300,
      isInBookshelf: false,
      isShelfActionLoading: false,
      onRead: null,
    );

    final readButton = tester.widget<FilledButton>(
      find.byKey(const Key('book_detail_read_button')),
    );
    expect(readButton.onPressed, isNull);
  });
}

Future<void> _pumpPrimaryActions(
  WidgetTester tester, {
  required double width,
  required bool isInBookshelf,
  required bool isShelfActionLoading,
  VoidCallback? onRead = _noop,
  VoidCallback? onToggleBookshelf = _noop,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return BookDetailPrimaryActions(
                  availableWidth: constraints.maxWidth,
                  isInBookshelf: isInBookshelf,
                  isShelfActionLoading: isShelfActionLoading,
                  onRead: onRead,
                  onToggleBookshelf: onToggleBookshelf,
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void _noop() {}
