import 'dart:io';

import '../../../domain/entities/book_metadata_override.dart';
import '../../../domain/entities/local_book.dart';

class BookMetadataPresentation {
  const BookMetadataPresentation({
    required this.displayTitle,
    this.displayAuthor,
    this.displayIntro,
    this.displayCover,
    this.realCoverUrl,
    this.customCoverPath,
    this.overrideUsed = false,
    this.localMetadataUsed = false,
  });

  final String displayTitle;
  final String? displayAuthor;
  final String? displayIntro;
  final String? displayCover;
  final String? realCoverUrl;
  final String? customCoverPath;
  final bool overrideUsed;
  final bool localMetadataUsed;
}

class BookMetadataPresentationResolver {
  const BookMetadataPresentationResolver();

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

    return BookMetadataPresentation(
      displayTitle: displayTitle,
      displayAuthor: displayAuthor,
      displayIntro: displayIntro,
      displayCover: displayCover,
      realCoverUrl: normalizedRealCoverUrl,
      customCoverPath: preferredCustomCoverPath,
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

  String? _normalize(String? value) {
    final normalized = (value ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }
}
