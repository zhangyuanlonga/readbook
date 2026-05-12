import '../../../domain/entities/reader_document.dart';
import 'reader_content_session.dart';

class ReaderContentModeResolver {
  const ReaderContentModeResolver();

  ReaderContentMode resolveFromDocument(ReaderDocument document) {
    return document.isPureImageDocument
        ? ReaderContentMode.comic
        : ReaderContentMode.text;
  }

  bool isComicDocument(ReaderDocument document) {
    return resolveFromDocument(document) == ReaderContentMode.comic;
  }
}
