import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/features/book/presentation/widgets/book_detail_primary_actions.dart';
import 'package:shuxiang_reading_next/features/book/presentation/widgets/book_detail_quick_actions_presenter.dart';

void main() {
  testWidgets('uses compact two-row layout on very narrow width', (
    tester,
  ) async {
    await _pumpPrimaryActions(
      tester,
      width: 185,
      isInBookshelf: true,
      isShelfStateLoading: false,
      isShelfActionLoading: false,
    );

    expect(find.text('书架'), findsOneWidget);
    expect(find.text('目录'), findsOneWidget);
    expect(find.text('书源'), findsOneWidget);
    expect(find.text('归类'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bookmarks_rounded), findsOneWidget);

    final shelfTop =
        tester.getTopLeft(find.byKey(const Key('book_detail_shelf_button'))).dy;
    final sourceTop =
        tester
            .getTopLeft(find.byKey(const Key('book_detail_source_button')))
            .dy;
    expect(sourceTop, greaterThan(shelfTop));
  });

  testWidgets('uses single-row four-action layout on large width', (
    tester,
  ) async {
    await _pumpPrimaryActions(
      tester,
      width: 430,
      isInBookshelf: true,
      isShelfStateLoading: false,
      isShelfActionLoading: false,
    );

    expect(find.text('书架'), findsOneWidget);
    expect(find.text('目录'), findsOneWidget);
    expect(find.text('书源'), findsOneWidget);
    expect(find.text('归类'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bookmarks_rounded), findsOneWidget);

    final shelfTop =
        tester.getTopLeft(find.byKey(const Key('book_detail_shelf_button'))).dy;
    final sourceTop =
        tester
            .getTopLeft(find.byKey(const Key('book_detail_source_button')))
            .dy;
    expect(sourceTop, shelfTop);
  });

  testWidgets('keeps four actions visible at medium width', (tester) async {
    await _pumpPrimaryActions(
      tester,
      width: 205,
      isInBookshelf: true,
      isShelfStateLoading: false,
      isShelfActionLoading: false,
    );

    expect(find.text('书架'), findsOneWidget);
    expect(find.text('目录'), findsOneWidget);
    expect(find.text('书源'), findsOneWidget);
    expect(find.text('归类'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('loading state disables shelf button', (tester) async {
    await _pumpPrimaryActions(
      tester,
      width: 300,
      isInBookshelf: true,
      isShelfStateLoading: false,
      isShelfActionLoading: true,
    );

    final shelfButton = tester.widget<InkWell>(
      find.byKey(const Key('book_detail_shelf_button')),
    );
    expect(shelfButton.onTap, isNull);
  });

  testWidgets('disables organize button when onOpenOrganize callback is null', (
    tester,
  ) async {
    await _pumpPrimaryActions(
      tester,
      width: 300,
      isInBookshelf: false,
      isShelfStateLoading: false,
      isShelfActionLoading: false,
      onOpenOrganize: null,
    );

    final cacheButton = tester.widget<InkWell>(
      find.byKey(const Key('book_detail_cache_button')),
    );
    expect(cacheButton.onTap, isNull);
  });

  testWidgets('keeps shelf icon stable while shelf state is loading', (
    tester,
  ) async {
    await _pumpPrimaryActions(
      tester,
      width: 300,
      isInBookshelf: false,
      isShelfStateLoading: true,
      isShelfActionLoading: false,
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    final shelfButton = tester.widget<InkWell>(
      find.byKey(const Key('book_detail_shelf_button')),
    );
    expect(shelfButton.onTap, isNull);
  });

  testWidgets('shows progress indicator only while shelf action is running', (
    tester,
  ) async {
    await _pumpPrimaryActions(
      tester,
      width: 300,
      isInBookshelf: true,
      isShelfStateLoading: false,
      isShelfActionLoading: true,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('quick actions presenter maps page state to enabled actions', (
    tester,
  ) async {
    var shelfTapped = false;
    var catalogTapped = false;
    var sourceTapped = false;
    var organizeTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: BookDetailQuickActionsPresenter(
                state: const BookDetailQuickActionsState(
                  isInBookshelf: false,
                  isShelfStateLoading: false,
                  isShelfActionLoading: false,
                  hasCatalog: false,
                  isCatalogLoading: false,
                  hasLoadedResult: true,
                  canSwitchSource: false,
                ),
                onToggleBookshelf: () => shelfTapped = true,
                onOpenCatalog: () => catalogTapped = true,
                onSwitchSource: () => sourceTapped = true,
                onOpenOrganize: () => organizeTapped = true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('book_detail_shelf_button')));
    await tester.tap(find.byKey(const Key('book_detail_catalog_button')));
    await tester.tap(find.byKey(const Key('book_detail_source_button')));
    await tester.tap(find.byKey(const Key('book_detail_cache_button')));

    expect(shelfTapped, isTrue);
    expect(catalogTapped, isFalse);
    expect(sourceTapped, isFalse);
    expect(organizeTapped, isFalse);
  });
}

Future<void> _pumpPrimaryActions(
  WidgetTester tester, {
  required double width,
  required bool isInBookshelf,
  required bool isShelfStateLoading,
  required bool isShelfActionLoading,
  VoidCallback? onToggleBookshelf = _noop,
  VoidCallback? onOpenCatalog = _noop,
  VoidCallback? onSwitchSource = _noop,
  VoidCallback? onOpenOrganize = _noop,
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
                  isShelfStateLoading: isShelfStateLoading,
                  isShelfActionLoading: isShelfActionLoading,
                  onToggleBookshelf: onToggleBookshelf,
                  onOpenCatalog: onOpenCatalog,
                  onSwitchSource: onSwitchSource,
                  onOpenOrganize: onOpenOrganize,
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
