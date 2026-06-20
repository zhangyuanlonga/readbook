class ReaderLayoutRect {
  const ReaderLayoutRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  }) : assert(right >= left),
       assert(bottom >= top);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  bool get isEmpty => width == 0 || height == 0;

  bool contains({required double dx, required double dy}) {
    return dx >= left && dx <= right && dy >= top && dy <= bottom;
  }
}

enum ReaderLayoutColumnKind { text, image, link, inlinePlaceholder }

class ReaderLayoutColumn {
  const ReaderLayoutColumn({
    required this.columnIndex,
    required this.kind,
    required this.startOffset,
    required this.endOffset,
    required this.rect,
    this.text = '',
    this.styleKey,
    this.payload = const <String, Object?>{},
  }) : assert(columnIndex >= 0),
       assert(endOffset >= startOffset);

  final int columnIndex;
  final ReaderLayoutColumnKind kind;
  final int startOffset;
  final int endOffset;
  final ReaderLayoutRect rect;
  final String text;
  final String? styleKey;
  final Map<String, Object?> payload;

  bool get isText => kind == ReaderLayoutColumnKind.text;
}
