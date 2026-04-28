import '../../../core/storage/managed_file_path_resolver.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/book_metadata_override.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/reading_record.dart';
import 'book_display_state.dart';

typedef BookMetadataPresentation = BookDisplayState;
typedef BookMetadataPresentationCoverSource = BookDisplayCoverSource;

class BookMetadataPresentationResolver {
  const BookMetadataPresentationResolver();

  static final ManagedFilePathResolver _pathResolver =
      ManagedFilePathResolver();

  BookDisplayState resolveRemoteBook({
    required Book book,
    BookMetadataOverride? metadataOverride,
  }) {
    return resolve(
      fallbackTitle: book.title,
      fallbackAuthor: book.author,
      fallbackIntro: book.intro,
      realCoverUrl: book.coverUrl,
      metadataOverride: metadataOverride,
    );
  }

  BookDisplayState resolveBookshelfBook({
    required BookshelfBook book,
    LocalBook? localBook,
    BookMetadataOverride? metadataOverride,
  }) {
    return resolve(
      fallbackTitle: book.title,
      fallbackAuthor: book.author,
      realCoverUrl: book.coverUrl,
      localBook: localBook,
      metadataOverride: metadataOverride,
    );
  }

  BookDisplayState resolveReadingRecord({
    required ReadingRecord record,
    LocalBook? localBook,
    BookMetadataOverride? metadataOverride,
  }) {
    return resolve(
      fallbackTitle: record.bookTitle,
      fallbackAuthor: record.bookAuthor,
      realCoverUrl: record.coverUrl,
      localBook: localBook,
      metadataOverride: metadataOverride,
    );
  }

  BookDisplayState resolve({
    required String? fallbackTitle,
    String? fallbackAuthor,
    String? fallbackIntro,
    String? realCoverUrl,
    LocalBook? localBook,
    BookMetadataOverride? metadataOverride,
  }) {
    final normalizedOverrideTitle = _normalize(metadataOverride?.title);
    final normalizedOverrideAuthor = _normalize(metadataOverride?.author);
    final normalizedOverrideIntro = _normalize(metadataOverride?.intro);
    final normalizedOverrideCoverPath = _normalize(metadataOverride?.coverPath);

    final normalizedLocalTitle = _normalize(localBook?.title);
    final normalizedLocalAuthor = _normalize(localBook?.author);
    final normalizedLocalIntro = _normalize(localBook?.description);
    final normalizedLocalCoverPath = _normalize(localBook?.coverPath);

    final normalizedFallbackTitle = _normalize(fallbackTitle);
    final normalizedFallbackAuthor = _normalize(fallbackAuthor);
    final normalizedFallbackIntro = _normalize(fallbackIntro);
    final normalizedRealCoverUrl = _normalize(realCoverUrl);

    final displayTitle =
        normalizedOverrideTitle ??
        normalizedLocalTitle ??
        normalizedFallbackTitle ??
        '未命名书籍';
    final displayAuthor =
        normalizedOverrideAuthor ??
        normalizedLocalAuthor ??
        normalizedFallbackAuthor;
    final displayIntro =
        normalizedOverrideIntro ??
        normalizedLocalIntro ??
        normalizedFallbackIntro;

    final preferredCustomCoverPath =
        normalizedOverrideCoverPath ?? normalizedLocalCoverPath;
    final displayCover = _resolveDisplayCover(
      customCoverPath: preferredCustomCoverPath,
      realCoverUrl: normalizedRealCoverUrl,
    );
    final displayCoverSource = _resolveDisplayCoverSource(
      overrideCoverPath: normalizedOverrideCoverPath,
      localCoverPath: normalizedLocalCoverPath,
      realCoverUrl: normalizedRealCoverUrl,
    );

    return BookDisplayState(
      displayTitle: displayTitle,
      displayAuthor: displayAuthor,
      displayIntro: displayIntro,
      displayCover: displayCover,
      realCoverUrl: normalizedRealCoverUrl,
      customCoverPath: preferredCustomCoverPath,
      displayCoverSource: displayCoverSource,
      overrideUsed:
          normalizedOverrideTitle != null ||
          normalizedOverrideAuthor != null ||
          normalizedOverrideIntro != null ||
          normalizedOverrideCoverPath != null,
      localMetadataUsed:
          localBook != null &&
          (normalizedLocalTitle != null ||
              normalizedLocalAuthor != null ||
              normalizedLocalIntro != null ||
              normalizedLocalCoverPath != null),
    );
  }

  String? _resolveDisplayCover({
    required String? customCoverPath,
    required String? realCoverUrl,
  }) {
    final resolvedCustomPath = _pathResolver.tryResolveExistingFilePathSync(
      customCoverPath,
    );
    if (resolvedCustomPath != null) {
      return Uri.file(resolvedCustomPath).toString();
    }
    return realCoverUrl;
  }

  BookDisplayCoverSource _resolveDisplayCoverSource({
    required String? overrideCoverPath,
    required String? localCoverPath,
    required String? realCoverUrl,
  }) {
    if (_pathResolver.tryResolveExistingFilePathSync(overrideCoverPath) !=
        null) {
      return BookDisplayCoverSource.overrideCustom;
    }
    if (_pathResolver.tryResolveExistingFilePathSync(localCoverPath) != null) {
      return BookDisplayCoverSource.localManaged;
    }
    if (realCoverUrl != null) {
      return BookDisplayCoverSource.remote;
    }
    return BookDisplayCoverSource.none;
  }

  String? _normalize(String? value) {
    final normalized = (value ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }
}
