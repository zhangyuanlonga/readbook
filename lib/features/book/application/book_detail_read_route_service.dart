import '../../../domain/entities/chapter.dart';
import '../../reader/application/reader_entry_route_resolver.dart';

class BookDetailReadRouteService {
  const BookDetailReadRouteService({
    required ReaderEntryRouteResolver readerEntryRouteResolver,
  }) : _readerEntryRouteResolver = readerEntryRouteResolver;

  final ReaderEntryRouteResolver _readerEntryRouteResolver;

  List<Chapter> readableChapters(List<Chapter> chapters) {
    return chapters
        .where(
          (chapter) =>
              !chapter.isVolume && chapter.chapterUrl.trim().isNotEmpty,
        )
        .toList(growable: false);
  }

  Chapter? latestReadableChapter(List<Chapter> chapters) {
    final candidates = readableChapters(chapters);
    if (candidates.isEmpty) {
      return null;
    }
    final chapter = candidates.last;
    final title = chapter.title.trim();
    return title.isEmpty ? null : chapter;
  }

  String? buildChapterRoute({
    required String bookId,
    required String sourceId,
    required String detailUrl,
    required Chapter chapter,
  }) {
    if (chapter.isVolume || chapter.chapterUrl.trim().isEmpty) {
      return null;
    }
    final normalizedSourceId = sourceId.trim();
    final normalizedDetailUrl = detailUrl.trim();
    if (normalizedSourceId.isEmpty || normalizedDetailUrl.isEmpty) {
      return null;
    }
    return _readerEntryRouteResolver.buildRouteFromChapter(
      bookId: bookId,
      sourceId: normalizedSourceId,
      detailUrl: normalizedDetailUrl,
      chapter: chapter,
    );
  }
}
