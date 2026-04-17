import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/widgets/resolved_book_cover.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';
import 'package:shuxiang_reading_next/domain/entities/cover_gallery.dart';

void main() {
  late Directory tempDir;
  late File galleryImageA;
  late File galleryImageB;
  late File customCoverFile;
  late AppAdvancedTheme activeTheme;
  late CoverGallery coverGallery;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('resolved_book_cover_test_');
    galleryImageA = File('${tempDir.path}/gallery_a.png')
      ..writeAsBytesSync(const <int>[0, 1, 2]);
    galleryImageB = File('${tempDir.path}/gallery_b.png')
      ..writeAsBytesSync(const <int>[3, 4, 5]);
    customCoverFile = File('${tempDir.path}/custom.png')
      ..writeAsBytesSync(const <int>[6, 7, 8]);

    coverGallery = CoverGallery(
      id: 'gallery_1',
      name: '封面图集 A',
      createdAt: DateTime.parse('2026-04-17T00:00:00.000Z'),
      updatedAt: DateTime.parse('2026-04-17T00:00:00.000Z'),
      imagePaths: <String>[galleryImageA.path, galleryImageB.path],
    );

    activeTheme = AppAdvancedTheme(
      id: 'theme_1',
      name: '高级主题',
      createdAt: DateTime.parse('2026-04-17T00:00:00.000Z'),
      updatedAt: DateTime.parse('2026-04-17T00:00:00.000Z'),
      lightConfig: const AppAdvancedThemeModeConfig(),
      darkConfig: const AppAdvancedThemeModeConfig(),
      coverGalleryId: coverGallery.id,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('prefers real cover over custom cover and gallery cover', () {
    final resolved = resolveBookCover(
      realCoverUrl: 'https://example.com/cover.jpg',
      customCoverPath: customCoverFile.path,
      activeTheme: activeTheme,
      galleries: <CoverGallery>[coverGallery],
      bookId: 'book_1',
      sourceId: 'source_a',
      detailUrl: 'https://example.com/book/1',
    );

    expect(resolved.source, ResolvedBookCoverSource.real);
    expect(resolved.imageUrl, 'https://example.com/cover.jpg');
  });

  test('prefers custom cover over gallery cover when real cover missing', () {
    final resolved = resolveBookCover(
      customCoverPath: customCoverFile.path,
      activeTheme: activeTheme,
      galleries: <CoverGallery>[coverGallery],
      bookId: 'book_1',
      sourceId: 'source_a',
      detailUrl: 'https://example.com/book/1',
    );

    expect(resolved.source, ResolvedBookCoverSource.custom);
    expect(resolved.filePath, customCoverFile.path);
  });

  test('uses gallery cover when theme is bound and book has no other cover', () {
    final resolved = resolveBookCover(
      activeTheme: activeTheme,
      galleries: <CoverGallery>[coverGallery],
      bookId: 'book_1',
      sourceId: 'source_a',
      detailUrl: 'https://example.com/book/1',
    );

    expect(resolved.source, ResolvedBookCoverSource.gallery);
    expect(
      <String>[galleryImageA.path, galleryImageB.path],
      contains(resolved.filePath),
    );
  });

  test('falls back to placeholder when bound gallery is unavailable', () {
    final resolved = resolveBookCover(
      activeTheme: activeTheme,
      galleries: const <CoverGallery>[],
      bookId: 'book_1',
      sourceId: 'source_a',
      detailUrl: 'https://example.com/book/1',
    );

    expect(resolved.source, ResolvedBookCoverSource.placeholder);
    expect(resolved.filePath, isNull);
  });

  test('reuses the only gallery image for all books when gallery has one image', () {
    final singleImageGallery = coverGallery.copyWith(
      imagePaths: <String>[galleryImageA.path],
    );
    final singleImageTheme = activeTheme.copyWith(
      coverGalleryId: singleImageGallery.id,
    );

    final first = resolveBookCover(
      activeTheme: singleImageTheme,
      galleries: <CoverGallery>[singleImageGallery],
      bookId: 'book_1',
      sourceId: 'source_a',
      detailUrl: 'https://example.com/book/1',
    );
    final second = resolveBookCover(
      activeTheme: singleImageTheme,
      galleries: <CoverGallery>[singleImageGallery],
      bookId: 'book_2',
      sourceId: 'source_a',
      detailUrl: 'https://example.com/book/2',
    );

    expect(first.source, ResolvedBookCoverSource.gallery);
    expect(second.source, ResolvedBookCoverSource.gallery);
    expect(first.filePath, galleryImageA.path);
    expect(second.filePath, galleryImageA.path);
  });

  test('assigns gallery image stably for the same book', () {
    final first = resolveBookCover(
      activeTheme: activeTheme,
      galleries: <CoverGallery>[coverGallery],
      bookId: 'stable_book',
      sourceId: 'source_a',
      detailUrl: 'https://example.com/book/stable',
    );
    final second = resolveBookCover(
      activeTheme: activeTheme,
      galleries: <CoverGallery>[coverGallery],
      bookId: 'stable_book',
      sourceId: 'source_a',
      detailUrl: 'https://example.com/book/stable',
    );

    expect(first.source, ResolvedBookCoverSource.gallery);
    expect(second.source, ResolvedBookCoverSource.gallery);
    expect(first.filePath, second.filePath);
  });

  test('uses sourceId and detailUrl as fallback stable key when bookId missing', () {
    final first = resolveBookCover(
      activeTheme: activeTheme,
      galleries: <CoverGallery>[coverGallery],
      sourceId: 'source_a',
      detailUrl: 'https://example.com/book/fallback-key',
    );
    final second = resolveBookCover(
      activeTheme: activeTheme,
      galleries: <CoverGallery>[coverGallery],
      sourceId: 'source_a',
      detailUrl: 'https://example.com/book/fallback-key',
    );

    expect(first.source, ResolvedBookCoverSource.gallery);
    expect(second.source, ResolvedBookCoverSource.gallery);
    expect(first.filePath, second.filePath);
  });

  test('treats file uri real cover as local custom-style file cover', () {
    final resolved = resolveBookCover(
      realCoverUrl: customCoverFile.uri.toString(),
      activeTheme: activeTheme,
      galleries: <CoverGallery>[coverGallery],
      bookId: 'book_1',
    );

    expect(resolved.source, ResolvedBookCoverSource.custom);
    expect(resolved.filePath, customCoverFile.path);
  });
}
