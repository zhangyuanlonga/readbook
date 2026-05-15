import 'chapter_content_service.dart';
import '../../../domain/entities/reader_document.dart';
import 'reader_content_session.dart';

class ReaderContentModeResolver {
  const ReaderContentModeResolver();

  ReaderContentMode resolveFromChapterResult(ChapterContentResult result) {
    final explicitType = (result.contentType ?? '').trim().toLowerCase();
    if (result.hasAudioContent || explicitType == 'audio') {
      return ReaderContentMode.audio;
    }
    if (result.imageUrls.isNotEmpty || explicitType == 'manga') {
      return ReaderContentMode.comic;
    }
    return resolveFromDocument(result.document);
  }

  ReaderContentMode resolveFromDocument(ReaderDocument document) {
    return document.isPureImageDocument
        ? ReaderContentMode.comic
        : ReaderContentMode.text;
  }

  bool isComicDocument(ReaderDocument document) {
    return resolveFromDocument(document) == ReaderContentMode.comic;
  }
}
