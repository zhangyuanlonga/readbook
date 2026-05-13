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

enum ReaderPagedBlockKind { text, image }

class ReaderPagedBlock {
  const ReaderPagedBlock._({
    required this.kind,
    required this.height,
    this.paragraphIndex,
    this.start,
    this.end,
    this.imageUrl,
  });

  const ReaderPagedBlock.text({
    required int paragraphIndex,
    required int start,
    required int end,
    required double height,
  }) : this._(
         kind: ReaderPagedBlockKind.text,
         paragraphIndex: paragraphIndex,
         start: start,
         end: end,
         height: height,
       );

  const ReaderPagedBlock.image({
    required String imageUrl,
    required double height,
  }) : this._(
         kind: ReaderPagedBlockKind.image,
         imageUrl: imageUrl,
         height: height,
       );

  final ReaderPagedBlockKind kind;
  final int? paragraphIndex;
  final int? start;
  final int? end;
  final String? imageUrl;
  final double height;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'kind': kind.name,
      'paragraphIndex': paragraphIndex,
      'start': start,
      'end': end,
      'imageUrl': imageUrl,
      'height': height,
    };
  }

  factory ReaderPagedBlock.fromJson(Map<String, dynamic> json) {
    final kindName = json['kind']?.toString();
    final height = (json['height'] as num?)?.toDouble() ?? 0;
    if (kindName == ReaderPagedBlockKind.image.name) {
      return ReaderPagedBlock.image(
        imageUrl: json['imageUrl']?.toString() ?? '',
        height: height,
      );
    }
    return ReaderPagedBlock.text(
      paragraphIndex: (json['paragraphIndex'] as num?)?.toInt() ?? 0,
      start: (json['start'] as num?)?.toInt() ?? 0,
      end: (json['end'] as num?)?.toInt() ?? 0,
      height: height,
    );
  }
}

class ReaderBlockPaginationResult {
  const ReaderBlockPaginationResult({required this.pages});

  final List<List<ReaderPagedBlock>> pages;
}

enum ReaderLazyPageSnapshotStatus { loading, ready, failed }

class ReaderLazyPageSnapshot<T> {
  const ReaderLazyPageSnapshot._({
    required this.pageIndex,
    required this.status,
    this.page,
    this.errorMessage,
  });

  const ReaderLazyPageSnapshot.loading({required int pageIndex})
    : this._(
        pageIndex: pageIndex,
        status: ReaderLazyPageSnapshotStatus.loading,
      );

  const ReaderLazyPageSnapshot.ready({required int pageIndex, required T page})
    : this._(
        pageIndex: pageIndex,
        status: ReaderLazyPageSnapshotStatus.ready,
        page: page,
      );

  const ReaderLazyPageSnapshot.failed({
    required int pageIndex,
    required String errorMessage,
  }) : this._(
         pageIndex: pageIndex,
         status: ReaderLazyPageSnapshotStatus.failed,
         errorMessage: errorMessage,
       );

  final int pageIndex;
  final ReaderLazyPageSnapshotStatus status;
  final T? page;
  final String? errorMessage;

  bool get isReady => status == ReaderLazyPageSnapshotStatus.ready;
}

class ReaderPrecomputedChapterLayout {
  const ReaderPrecomputedChapterLayout({
    required this.paragraphs,
    required this.pagedPages,
    required this.paginationSignature,
    this.pagedBlockPages = const <List<ReaderPagedBlock>>[],
  });

  final List<String> paragraphs;
  final List<List<ReaderPagedSlice>> pagedPages;
  final List<List<ReaderPagedBlock>> pagedBlockPages;
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
      'pagedBlockPages': pagedBlockPages
          .map(
            (page) =>
                page.map((block) => block.toJson()).toList(growable: false),
          )
          .toList(growable: false),
    };
  }

  factory ReaderPrecomputedChapterLayout.fromJson(Map<String, dynamic> json) {
    final rawParagraphs = json['paragraphs'];
    final rawPages = json['pagedPages'];
    final rawBlockPages = json['pagedBlockPages'];
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
      pagedBlockPages:
          rawBlockPages is List
              ? rawBlockPages
                  .whereType<List>()
                  .map(
                    (page) => page
                        .whereType<Map>()
                        .map(
                          (block) => ReaderPagedBlock.fromJson(
                            block.map(
                              (key, value) => MapEntry(key.toString(), value),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  )
                  .toList(growable: false)
              : const <List<ReaderPagedBlock>>[],
      paginationSignature: json['paginationSignature']?.toString().trim() ?? '',
    );
  }
}
