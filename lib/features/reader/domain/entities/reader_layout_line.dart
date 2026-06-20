import 'reader_layout_column.dart';

class ReaderLayoutLine {
  const ReaderLayoutLine({
    required this.lineIndex,
    required this.paragraphIndex,
    required this.text,
    required this.chapterOffset,
    required this.pageOffset,
    required this.lineTop,
    required this.lineBase,
    required this.lineBottom,
    this.columns = const <ReaderLayoutColumn>[],
    this.isTitle = false,
    this.isImage = false,
    this.isHtml = false,
    this.isParagraphEnd = false,
  }) : assert(lineIndex >= 0),
       assert(paragraphIndex >= 0),
       assert(chapterOffset >= 0),
       assert(pageOffset >= 0),
       assert(lineBottom >= lineTop),
       assert(lineBase >= lineTop),
       assert(lineBase <= lineBottom);

  final int lineIndex;
  final int paragraphIndex;
  final String text;
  final int chapterOffset;
  final int pageOffset;
  final double lineTop;
  final double lineBase;
  final double lineBottom;
  final List<ReaderLayoutColumn> columns;
  final bool isTitle;
  final bool isImage;
  final bool isHtml;
  final bool isParagraphEnd;

  double get height => lineBottom - lineTop;

  int get endChapterOffset {
    return columns.fold<int>(
      chapterOffset + text.length,
      (current, column) =>
          column.endOffset > current ? column.endOffset : current,
    );
  }
}
