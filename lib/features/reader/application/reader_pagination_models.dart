class ReaderPagedSlice {
  const ReaderPagedSlice({
    required this.paragraphIndex,
    required this.start,
    required this.end,
    required this.height,
  });

  final int paragraphIndex;
  final int start;
  final int end;
  final double height;

  Map<String, Object> toJson() {
    return <String, Object>{
      'paragraphIndex': paragraphIndex,
      'start': start,
      'end': end,
      'height': height,
    };
  }

  factory ReaderPagedSlice.fromJson(Map<String, dynamic> json) {
    return ReaderPagedSlice(
      paragraphIndex: (json['paragraphIndex'] as num?)?.toInt() ?? 0,
      start: (json['start'] as num?)?.toInt() ?? 0,
      end: (json['end'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ReaderPrecomputedChapterLayout {
  const ReaderPrecomputedChapterLayout({
    required this.paragraphs,
    required this.pagedPages,
    required this.paginationSignature,
  });

  final List<String> paragraphs;
  final List<List<ReaderPagedSlice>> pagedPages;
  final String paginationSignature;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'paragraphs': paragraphs,
      'paginationSignature': paginationSignature,
      'pagedPages': pagedPages
          .map(
            (page) =>
                page.map((slice) => slice.toJson()).toList(growable: false),
          )
          .toList(growable: false),
    };
  }

  factory ReaderPrecomputedChapterLayout.fromJson(Map<String, dynamic> json) {
    final rawParagraphs = json['paragraphs'];
    final rawPages = json['pagedPages'];
    return ReaderPrecomputedChapterLayout(
      paragraphs:
          rawParagraphs is List
              ? rawParagraphs
                  .map((item) => item.toString())
                  .toList(growable: false)
              : const <String>[],
      pagedPages:
          rawPages is List
              ? rawPages
                  .whereType<List>()
                  .map(
                    (page) => page
                        .whereType<Map>()
                        .map(
                          (slice) => ReaderPagedSlice.fromJson(
                            slice.map(
                              (key, value) => MapEntry(key.toString(), value),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  )
                  .toList(growable: false)
              : const <List<ReaderPagedSlice>>[],
      paginationSignature: json['paginationSignature']?.toString().trim() ?? '',
    );
  }
}
