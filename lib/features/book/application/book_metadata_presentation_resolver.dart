import 'dart:io';

import '../../../domain/entities/book.dart';
import '../../../domain/entities/book_metadata_override.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/reading_record.dart';

enum BookMetadataPresentationCoverSource {
  overrideCustom,
  localManaged,
  remote,
  none,
}

class BookMetadataPresentation {
  const BookMetadataPresentation({
    required this.displayTitle,
    this.displayAuthor,
    this.displayIntro,
    this.displayCover,
    this.realCoverUrl,
    this.customCoverPath,
    this.displayCoverSource = BookMetadataPresentationCoverSource.none,
    this.overrideUsed = false,
    this.localMetadataUsed = false,
  });

  final String displayTitle;
  final String? displayAuthor;
  final String? displayIntro;
  final String? displayCover;
  final String? realCoverUrl;
  final String? customCoverPath;
  final BookMetadataPresentationCoverSource displayCoverSource;
  final bool overrideUsed;
  final bool localMetadataUsed;
}

class BookMetadataPresentationResolver {
  const BookMetadataPresentationResolver();

  BookMetadataPresentation resolveRemoteBook({
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

  BookMetadataPresentation resolveBookshelfBook({
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

  BookMetadataPresentation resolveReadingRecord({
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

  BookMetadataPresentation resolve({
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

    return BookMetadataPresentation(
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
    if (customCoverPath != null && File(customCoverPath).existsSync()) {
      return Uri.file(customCoverPath).toString();
    }
    return realCoverUrl;
  }

  BookMetadataPresentationCoverSource _resolveDisplayCoverSource({
    required String? overrideCoverPath,
    required String? localCoverPath,
    required String? realCoverUrl,
  }) {
    if (overrideCoverPath != null && File(overrideCoverPath).existsSync()) {
      return BookMetadataPresentationCoverSource.overrideCustom;
    }
    if (localCoverPath != null && File(localCoverPath).existsSync()) {
      return BookMetadataPresentationCoverSource.localManaged;
    }
    if (realCoverUrl != null) {
      return BookMetadataPresentationCoverSource.remote;
    }
    return BookMetadataPresentationCoverSource.none;
  }

  String? _normalize(String? value) {
    final normalized = (value ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }
}
