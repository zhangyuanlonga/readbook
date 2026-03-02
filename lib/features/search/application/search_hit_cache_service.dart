import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/book.dart';

class SearchHitCacheService {
  SearchHitCacheService({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  static final RegExp _spacePattern = RegExp(r'[\u3000\s]+');
  static final RegExp _symbolPattern = RegExp(
    r'''[·•\-_:：|/\\\(\)\[\]【】<>《》"'‘’,.，。!?！？]''',
  );
  static final RegExp _chapterPattern = RegExp(r'第?\s*(\d{1,6})\s*章');
  static final RegExp _numberPattern = RegExp(r'(\d{1,6})');

  Future<void> recordBooks(
    Iterable<Book> books, {
    Map<String, String> sourceNames = const <String, String>{},
  }) async {
    final aggregated = <String, _SearchSourceHitAccumulator>{};

    for (final book in books) {
      final sourceId = book.sourceId.trim();
      final titleNorm = normalizeText(book.title);
      if (sourceId.isEmpty || titleNorm.isEmpty) {
        continue;
      }

      final authorNorm = normalizeText(book.author ?? '');
      final key = '$titleNorm|$authorNorm|$sourceId';
      final incomingLatestNo = _extractLatestChapterNumber(book.latestChapter);

      final existing = aggregated[key];
      if (existing == null) {
        aggregated[key] = _SearchSourceHitAccumulator(
          titleNorm: titleNorm,
          authorNorm: authorNorm,
          sourceId: sourceId,
          sourceName: (sourceNames[sourceId] ?? '').trim(),
          title: book.title.trim(),
          author: book.author?.trim(),
          latestChapter: book.latestChapter?.trim(),
          latestChapterNo: incomingLatestNo,
          hitIncrement: 1,
        );
        continue;
      }

      aggregated[key] = existing.mergeWith(
        sourceName: (sourceNames[sourceId] ?? '').trim(),
        title: book.title.trim(),
        author: book.author?.trim(),
        latestChapter: book.latestChapter?.trim(),
        latestChapterNo: incomingLatestNo,
      );
    }

    if (aggregated.isEmpty) {
      return;
    }

    final upserts = aggregated.values
        .map(
          (item) => SearchSourceHitUpsert(
            titleNorm: item.titleNorm,
            authorNorm: item.authorNorm,
            sourceId: item.sourceId,
            sourceName: item.sourceName,
            title: item.title,
            author: item.author,
            latestChapter: item.latestChapter,
            latestChapterNo: item.latestChapterNo,
            hitIncrement: item.hitIncrement,
          ),
        )
        .toList(growable: false);

    await _database.upsertSearchSourceHits(upserts);
  }

  Future<Map<String, int>> loadSourceHitCounts({
    required String title,
    String? author,
  }) {
    return _database.getSearchSourceHitCounts(
      titleNorm: normalizeText(title),
      authorNorm: normalizeText(author ?? ''),
    );
  }

  String normalizeText(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll(_spacePattern, '')
        .replaceAll(_symbolPattern, '');
  }

  int? _extractLatestChapterNumber(String? rawText) {
    final text = rawText?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }

    final chapterMatch = _chapterPattern.firstMatch(text);
    if (chapterMatch != null) {
      return int.tryParse(chapterMatch.group(1) ?? '');
    }

    final fallback = _numberPattern.firstMatch(text);
    if (fallback != null) {
      return int.tryParse(fallback.group(1) ?? '');
    }
    return null;
  }
}

class _SearchSourceHitAccumulator {
  const _SearchSourceHitAccumulator({
    required this.titleNorm,
    required this.authorNorm,
    required this.sourceId,
    required this.sourceName,
    required this.title,
    required this.author,
    required this.latestChapter,
    required this.latestChapterNo,
    required this.hitIncrement,
  });

  final String titleNorm;
  final String authorNorm;
  final String sourceId;
  final String sourceName;
  final String title;
  final String? author;
  final String? latestChapter;
  final int? latestChapterNo;
  final int hitIncrement;

  _SearchSourceHitAccumulator mergeWith({
    required String sourceName,
    required String title,
    required String? author,
    required String? latestChapter,
    required int? latestChapterNo,
  }) {
    final pickLatestByNumber =
        latestChapterNo != null &&
        (this.latestChapterNo == null ||
            latestChapterNo > this.latestChapterNo!);
    return _SearchSourceHitAccumulator(
      titleNorm: titleNorm,
      authorNorm: authorNorm,
      sourceId: sourceId,
      sourceName: sourceName.isEmpty ? this.sourceName : sourceName,
      title: title.isEmpty ? this.title : title,
      author: (author == null || author.isEmpty) ? this.author : author,
      latestChapter:
          pickLatestByNumber
              ? latestChapter
              : ((this.latestChapter == null || this.latestChapter!.isEmpty)
                  ? latestChapter
                  : this.latestChapter),
      latestChapterNo:
          pickLatestByNumber
              ? latestChapterNo
              : (this.latestChapterNo ?? latestChapterNo),
      hitIncrement: hitIncrement + 1,
    );
  }
}
