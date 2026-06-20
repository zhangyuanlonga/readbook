import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_selection_runtime.dart';
import 'package:shuxiang_reading_next/features/reader/domain/entities/reader_layout_models.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_layout_paged_view.dart';

void main() {
  testWidgets('ReaderLayoutPagedView renders text and image placeholders', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 480,
            child: ReaderLayoutPagedView(
              pages: <ReaderLayoutPage>[_page(text: '正文')],
              textStyle: const TextStyle(fontSize: 14),
              annotationRanges: const <ReaderLayoutTextAnnotationRange>[
                ReaderLayoutTextAnnotationRange(startOffset: 0, endOffset: 1),
              ],
              imagePlaceholderBuilder: (context, fragment) {
                return const ColoredBox(color: Colors.red);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('正文'), findsOneWidget);
    expect(find.byType(ReaderLayoutTextPainter), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == Colors.red,
      ),
      findsOneWidget,
    );
  });

  testWidgets('ReaderLayoutPagedView supports page turning', (tester) async {
    var changedPage = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 480,
            child: ReaderLayoutPagedView(
              pages: <ReaderLayoutPage>[
                _page(text: '第一页'),
                _page(text: '第二页', pageIndex: 1, startOffset: 4),
              ],
              textStyle: const TextStyle(fontSize: 14),
              onPageChanged: (pageIndex) {
                changedPage = pageIndex;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-340, 0));
    await tester.pumpAndSettle();

    expect(changedPage, 1);
    expect(find.text('第二页'), findsOneWidget);
  });

  testWidgets('ReaderLayoutPagedView reports runtime selection on long press', (
    tester,
  ) async {
    ReaderLayoutSelectionSnapshot? selection;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 480,
            child: ReaderLayoutPagedView(
              pages: <ReaderLayoutPage>[_page(text: 'hello')],
              textStyle: const TextStyle(fontSize: 14),
              onSelectionChanged: (value) {
                selection = value;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('hello')),
    );
    await tester.pump(const Duration(milliseconds: 650));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(selection, isNotNull);
    expect(selection!.selectedText, 'hello');
  });
}

ReaderLayoutPage _page({
  required String text,
  int pageIndex = 0,
  int startOffset = 0,
}) {
  final endOffset = startOffset + text.length + 1;
  return ReaderLayoutPage(
    chapterId: 'chapter-1',
    chapterIndex: 0,
    pageIndex: pageIndex,
    startOffset: startOffset,
    endOffset: endOffset,
    contentWidth: 320,
    contentHeight: 480,
    layoutSignature: 'sig',
    lines: <ReaderLayoutLine>[
      ReaderLayoutLine(
        lineIndex: 0,
        paragraphIndex: 0,
        text: text,
        chapterOffset: startOffset,
        pageOffset: 0,
        lineTop: 0,
        lineBase: 18,
        lineBottom: 24,
        columns: <ReaderLayoutColumn>[
          ReaderLayoutColumn(
            columnIndex: 0,
            kind: ReaderLayoutColumnKind.text,
            startOffset: startOffset,
            endOffset: startOffset + text.length,
            rect: ReaderLayoutRect(left: 0, top: 0, right: 80, bottom: 24),
            text: text,
          ),
        ],
      ),
      ReaderLayoutLine(
        lineIndex: 1,
        paragraphIndex: 1,
        text: '',
        chapterOffset: startOffset + text.length,
        pageOffset: text.length,
        lineTop: 30,
        lineBase: 80,
        lineBottom: 80,
        columns: <ReaderLayoutColumn>[
          ReaderLayoutColumn(
            columnIndex: 0,
            kind: ReaderLayoutColumnKind.image,
            startOffset: startOffset + text.length,
            endOffset: endOffset,
            rect: ReaderLayoutRect(left: 0, top: 30, right: 120, bottom: 80),
          ),
        ],
        isImage: true,
      ),
    ],
  );
}
