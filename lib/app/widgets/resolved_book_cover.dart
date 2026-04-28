import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/storage/managed_file_path_resolver.dart';
import '../../domain/entities/app_advanced_theme.dart';
import '../../domain/entities/cover_gallery.dart';
import 'disk_cached_cover_image.dart';
import 'text_cover_placeholder.dart';

enum ResolvedBookCoverSource { real, custom, gallery, placeholder }

class ResolvedBookCover {
  const ResolvedBookCover._({
    required this.source,
    this.imageUrl,
    this.filePath,
  });

  const ResolvedBookCover.real(String imageUrl)
    : this._(source: ResolvedBookCoverSource.real, imageUrl: imageUrl);

  const ResolvedBookCover.custom(String filePath)
    : this._(source: ResolvedBookCoverSource.custom, filePath: filePath);

  const ResolvedBookCover.gallery(String filePath)
    : this._(source: ResolvedBookCoverSource.gallery, filePath: filePath);

  const ResolvedBookCover.placeholder()
    : this._(source: ResolvedBookCoverSource.placeholder);

  final ResolvedBookCoverSource source;
  final String? imageUrl;
  final String? filePath;
}

final ManagedFilePathResolver _managedFilePathResolver =
    ManagedFilePathResolver();

ResolvedBookCover resolveBookCover({
  String? realCoverUrl,
  String? customCoverPath,
  AppAdvancedTheme? activeTheme,
  Iterable<CoverGallery> galleries = const <CoverGallery>[],
  String? bookId,
  String? sourceId,
  String? detailUrl,
}) {
  final resolvedCustom = _resolveCustomCover(customCoverPath);
  if (resolvedCustom != null) {
    return resolvedCustom;
  }

  final resolvedReal = _resolveRealCover(realCoverUrl);
  if (resolvedReal != null) {
    return resolvedReal;
  }

  final galleryId = activeTheme?.coverGalleryId?.trim() ?? '';
  if (galleryId.isNotEmpty) {
    final gallery = _findGalleryById(galleries, galleryId);
    final galleryPath = _resolveGalleryImagePath(
      gallery,
      bookId: bookId,
      sourceId: sourceId,
      detailUrl: detailUrl,
    );
    if (galleryPath != null) {
      return ResolvedBookCover.gallery(galleryPath);
    }
  }

  return const ResolvedBookCover.placeholder();
}

class ResolvedBookCoverView extends StatelessWidget {
  const ResolvedBookCoverView({
    super.key,
    required this.cover,
    required this.title,
    this.author,
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  final ResolvedBookCover cover;
  final String title;
  final String? author;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return switch (cover.source) {
      ResolvedBookCoverSource.real => ClipRRect(
        borderRadius: borderRadius,
        child: DiskCachedCoverImage(
          imageUrl: cover.imageUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
          fallback: _buildPlaceholder(),
        ),
      ),
      ResolvedBookCoverSource.custom ||
      ResolvedBookCoverSource.gallery => ClipRRect(
        borderRadius: borderRadius,
        child: Image.file(
          File(cover.filePath!),
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        ),
      ),
      ResolvedBookCoverSource.placeholder => _buildPlaceholder(),
    };
  }

  Widget _buildPlaceholder() {
    return TextCoverPlaceholder(
      title: title,
      author: author,
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }
}

ResolvedBookCover? _resolveRealCover(String? realCoverUrl) {
  final normalized = realCoverUrl?.trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(normalized);
  if (uri == null || !uri.hasScheme) {
    return null;
  }
  if (uri.scheme == 'file') {
    final resolvedPath = _managedFilePathResolver
        .tryResolveExistingFilePathSync(File.fromUri(uri).path);
    if (resolvedPath == null) {
      return null;
    }
    return ResolvedBookCover.custom(resolvedPath);
  }
  return ResolvedBookCover.real(normalized);
}

ResolvedBookCover? _resolveCustomCover(String? customCoverPath) {
  final normalized = _managedFilePathResolver.tryResolveExistingFilePathSync(
    customCoverPath,
  );
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return ResolvedBookCover.custom(normalized);
}

CoverGallery? _findGalleryById(
  Iterable<CoverGallery> galleries,
  String galleryId,
) {
  for (final gallery in galleries) {
    if (gallery.id == galleryId) {
      return gallery;
    }
  }
  return null;
}

String? _resolveGalleryImagePath(
  CoverGallery? gallery, {
  String? bookId,
  String? sourceId,
  String? detailUrl,
}) {
  if (gallery == null) {
    return null;
  }

  final validPaths = gallery.imagePaths
      .map(
        (path) => _managedFilePathResolver.tryResolveExistingFilePathSync(path),
      )
      .whereType<String>()
      .toList(growable: false);
  if (validPaths.isEmpty) {
    return null;
  }
  if (validPaths.length == 1) {
    return validPaths.first;
  }

  final stableKey = _buildStableBookKey(
    bookId: bookId,
    sourceId: sourceId,
    detailUrl: detailUrl,
  );
  if (stableKey == null) {
    return validPaths.first;
  }
  final index = _stableHash(stableKey) % validPaths.length;
  return validPaths[index];
}

String? _buildStableBookKey({
  String? bookId,
  String? sourceId,
  String? detailUrl,
}) {
  final normalizedBookId = bookId?.trim() ?? '';
  if (normalizedBookId.isNotEmpty) {
    return normalizedBookId;
  }
  final normalizedSourceId = sourceId?.trim() ?? '';
  final normalizedDetailUrl = detailUrl?.trim() ?? '';
  if (normalizedSourceId.isEmpty || normalizedDetailUrl.isEmpty) {
    return null;
  }
  return '$normalizedSourceId::$normalizedDetailUrl';
}

int _stableHash(String input) {
  var hash = 0x811C9DC5;
  for (final codeUnit in input.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7FFFFFFF;
  }
  return hash;
}
