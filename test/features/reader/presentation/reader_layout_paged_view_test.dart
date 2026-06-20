import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/domain/entities/reader_layout_models.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_layout_paged_view.dart';

void main() {
  testWidgets('ReaderLayoutPagedView renders text and image placeholders', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderLayoutPagedView(
            pages: <ReaderLayoutPage>[_page()],
            textStyle: const TextStyle(fontSize: 14),
            imagePlaceholderBuilder: (context, fragment) {
              return const ColoredBox(color: Colors.red);
            },
          ),
        ),
      ),
    );

    expect(find.text('正文'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ColoredBox && widget.color == Colors.red,
      ),
      findsOneWidget,
    );
  });
}

ReaderLayoutPage _page() {
  return const ReaderLayoutPage(
    chapterId: 'chapter-1',
    chapterIndex: 0,
    pageIndex: 0,
    startOffset: 0,
    endOffset: 3,
    contentWidth: 320,
    contentHeight: 480,
    layoutSignature: 'sig',
    lines: <ReaderLayoutLine>[
      ReaderLayoutLine(
        lineIndex: 0,
        paragraphIndex: 0,
        text: '正文',
        chapterOffset: 0,
        pageOffset: 0,
        lineTop: 0,
        lineBase: 18,
        lineBottom: 24,
        columns: <ReaderLayoutColumn>[
          ReaderLayoutColumn(
            columnIndex: 0,
            kind: ReaderLayoutColumnKind.text,
            startOffset: 0,
            endOffset: 2,
            rect: ReaderLayoutRect(left: 0, top: 0, right: 80, bottom: 24),
            text: '正文',
          ),
        ],
      ),
      ReaderLayoutLine(
        lineIndex: 1,
        paragraphIndex: 1,
        text: '',
        chapterOffset: 2,
        pageOffset: 2,
        lineTop: 30,
        lineBase: 80,
        lineBottom: 80,
        columns: <ReaderLayoutColumn>[
          ReaderLayoutColumn(
            columnIndex: 0,
            kind: ReaderLayoutColumnKind.image,
            startOffset: 2,
            endOffset: 3,
            rect: ReaderLayoutRect(left: 0, top: 30, right: 120, bottom: 80),
          ),
        ],
        isImage: true,
      ),
    ],
  );
}
