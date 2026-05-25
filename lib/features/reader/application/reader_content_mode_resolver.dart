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
    if (_isHybridExplicitType(explicitType)) {
      return ReaderContentMode.hybrid;
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

  ReaderHybridSubMode? resolveHybridSubMode(ChapterContentResult result) {
    final explicitType = (result.contentType ?? '').trim().toLowerCase();
    switch (explicitType) {
      case 'pdf':
        return ReaderHybridSubMode.pdf;
      case 'epub-fixed':
      case 'epub_fixed':
      case 'epubfixed':
      case 'fixed-epub':
      case 'fixed_epub':
        return ReaderHybridSubMode.epubFixed;
      case 'picture-book':
      case 'picture_book':
      case 'picturebook':
      case 'magazine':
      case 'comic-book':
      case 'comic_book':
      case 'picture-book-page':
        return ReaderHybridSubMode.pictureBook;
      case 'document-image':
      case 'document_image':
      case 'scanned-document':
      case 'scanned_document':
        return ReaderHybridSubMode.documentImage;
    }
    return null;
  }

  bool isComicDocument(ReaderDocument document) {
    return resolveFromDocument(document) == ReaderContentMode.comic;
  }

  bool _isHybridExplicitType(String explicitType) {
    return explicitType == 'pdf' ||
        explicitType == 'epub-fixed' ||
        explicitType == 'epub_fixed' ||
        explicitType == 'epubfixed' ||
        explicitType == 'fixed-epub' ||
        explicitType == 'fixed_epub' ||
        explicitType == 'picture-book' ||
        explicitType == 'picture_book' ||
        explicitType == 'picturebook' ||
        explicitType == 'magazine' ||
        explicitType == 'document-image' ||
        explicitType == 'document_image' ||
        explicitType == 'scanned-document' ||
        explicitType == 'scanned_document';
  }
}
