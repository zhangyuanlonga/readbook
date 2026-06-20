import 'reader_layout_line.dart';

class ReaderLayoutPage {
  const ReaderLayoutPage({
    required this.chapterId,
    required this.chapterIndex,
    required this.pageIndex,
    required this.startOffset,
    required this.endOffset,
    required this.contentWidth,
    required this.contentHeight,
    required this.layoutSignature,
    this.lines = const <ReaderLayoutLine>[],
    this.blockRefs = const <String>[],
    this.isCompleted = true,
  }) : assert(chapterId.length > 0),
       assert(chapterIndex >= 0),
       assert(pageIndex >= 0),
       assert(startOffset >= 0),
       assert(endOffset >= startOffset),
       assert(contentWidth >= 0),
       assert(contentHeight >= 0);

  final String chapterId;
  final int chapterIndex;
  final int pageIndex;
  final int startOffset;
  final int endOffset;
  final double contentWidth;
  final double contentHeight;
  final List<ReaderLayoutLine> lines;
  final List<String> blockRefs;
  final bool isCompleted;
  final String layoutSignature;

  bool get isEmpty => lines.isEmpty;
  int get lineCount => lines.length;
}
