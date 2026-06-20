import 'reader_layout_column.dart';
import 'reader_layout_position.dart';

class ReaderLayoutRange {
  ReaderLayoutRange({
    required this.start,
    required this.end,
    this.selectedText = '',
    this.rects = const <ReaderLayoutRect>[],
  }) : assert(ReaderLayoutPosition.compare(start, end) <= 0);

  final ReaderLayoutPosition start;
  final ReaderLayoutPosition end;
  final String selectedText;
  final List<ReaderLayoutRect> rects;

  bool get isCollapsed => ReaderLayoutPosition.compare(start, end) == 0;
  bool get spansMultipleLines => start.lineIndex != end.lineIndex;
  bool get spansMultiplePages => start.pageIndex != end.pageIndex;
}
