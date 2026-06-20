enum ReaderLayoutPositionAffinity { upstream, downstream }

class ReaderLayoutPosition implements Comparable<ReaderLayoutPosition> {
  const ReaderLayoutPosition({
    required this.pageIndex,
    required this.lineIndex,
    required this.columnIndex,
    required this.chapterOffset,
    this.affinity = ReaderLayoutPositionAffinity.downstream,
  }) : assert(pageIndex >= 0),
       assert(lineIndex >= 0),
       assert(columnIndex >= 0),
       assert(chapterOffset >= 0);

  final int pageIndex;
  final int lineIndex;
  final int columnIndex;
  final int chapterOffset;
  final ReaderLayoutPositionAffinity affinity;

  @override
  int compareTo(ReaderLayoutPosition other) {
    return compare(this, other);
  }

  static int compare(ReaderLayoutPosition a, ReaderLayoutPosition b) {
    final pageCompare = a.pageIndex.compareTo(b.pageIndex);
    if (pageCompare != 0) {
      return pageCompare;
    }
    final offsetCompare = a.chapterOffset.compareTo(b.chapterOffset);
    if (offsetCompare != 0) {
      return offsetCompare;
    }
    final lineCompare = a.lineIndex.compareTo(b.lineIndex);
    if (lineCompare != 0) {
      return lineCompare;
    }
    return a.columnIndex.compareTo(b.columnIndex);
  }
}
