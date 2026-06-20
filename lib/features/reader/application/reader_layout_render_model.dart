import '../domain/entities/reader_layout_models.dart';

enum ReaderLayoutRenderFragmentKind { text, image, placeholder }

class ReaderLayoutRenderFragment {
  const ReaderLayoutRenderFragment({
    required this.kind,
    required this.pageIndex,
    required this.lineIndex,
    required this.columnIndex,
    required this.startOffset,
    required this.endOffset,
    required this.rect,
    this.text = '',
    this.styleKey,
    this.payload = const <String, Object?>{},
  });

  final ReaderLayoutRenderFragmentKind kind;
  final int pageIndex;
  final int lineIndex;
  final int columnIndex;
  final int startOffset;
  final int endOffset;
  final ReaderLayoutRect rect;
  final String text;
  final String? styleKey;
  final Map<String, Object?> payload;
}

class ReaderLayoutRenderPage {
  const ReaderLayoutRenderPage({
    required this.pageIndex,
    required this.contentWidth,
    required this.contentHeight,
    required this.fragments,
  });

  final int pageIndex;
  final double contentWidth;
  final double contentHeight;
  final List<ReaderLayoutRenderFragment> fragments;
}

class ReaderLayoutRenderModelBuilder {
  const ReaderLayoutRenderModelBuilder();

  List<ReaderLayoutRenderPage> buildPages(List<ReaderLayoutPage> pages) {
    return pages.map(_buildPage).toList(growable: false);
  }

  ReaderLayoutRenderPage _buildPage(ReaderLayoutPage page) {
    final fragments = <ReaderLayoutRenderFragment>[];
    for (final line in page.lines) {
      for (final column in line.columns) {
        fragments.add(
          ReaderLayoutRenderFragment(
            kind: _fragmentKind(column),
            pageIndex: page.pageIndex,
            lineIndex: line.lineIndex,
            columnIndex: column.columnIndex,
            startOffset: column.startOffset,
            endOffset: column.endOffset,
            rect: column.rect,
            text: column.text,
            styleKey: column.styleKey,
            payload: column.payload,
          ),
        );
      }
    }
    return ReaderLayoutRenderPage(
      pageIndex: page.pageIndex,
      contentWidth: page.contentWidth,
      contentHeight: page.contentHeight,
      fragments: List<ReaderLayoutRenderFragment>.unmodifiable(fragments),
    );
  }

  ReaderLayoutRenderFragmentKind _fragmentKind(ReaderLayoutColumn column) {
    return switch (column.kind) {
      ReaderLayoutColumnKind.image => ReaderLayoutRenderFragmentKind.image,
      ReaderLayoutColumnKind.inlinePlaceholder =>
        ReaderLayoutRenderFragmentKind.placeholder,
      ReaderLayoutColumnKind.text ||
      ReaderLayoutColumnKind.link => ReaderLayoutRenderFragmentKind.text,
    };
  }
}
