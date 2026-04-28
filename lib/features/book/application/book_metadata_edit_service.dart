import '../../../core/media/image_selection_service.dart';
import '../../../domain/entities/book_detail.dart';
import '../../../domain/entities/book_metadata_override.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/repositories/book_metadata_override_repository.dart';
import '../../../domain/repositories/local_book_repository.dart';
import 'custom_cover_storage_service.dart';

class RemoteBookMetadataSaveResult {
  const RemoteBookMetadataSaveResult({required this.metadataOverride});

  final BookMetadataOverride? metadataOverride;
}

class LocalBookMetadataSaveResult {
  const LocalBookMetadataSaveResult({
    required this.localBook,
    required this.needsReindex,
  });

  final LocalBook localBook;
  final bool needsReindex;
}

class BookMetadataEditService {
  const BookMetadataEditService({
    required BookMetadataOverrideRepository bookMetadataOverrideRepository,
    required LocalBookRepository localBookRepository,
    required ImageSelectionService imageSelectionService,
    required CustomCoverStorageService customCoverStorageService,
  }) : _bookMetadataOverrideRepository = bookMetadataOverrideRepository,
       _localBookRepository = localBookRepository,
       _imageSelectionService = imageSelectionService,
       _customCoverStorageService = customCoverStorageService;

  final BookMetadataOverrideRepository _bookMetadataOverrideRepository;
  final LocalBookRepository _localBookRepository;
  final ImageSelectionService _imageSelectionService;
  final CustomCoverStorageService _customCoverStorageService;

  Future<String?> pickAndPersistCustomCover({
    required BookDetail detail,
  }) async {
    final picked = await _imageSelectionService.pickImage(
      confirmButtonText: '选择封面',
      allowedExtensions: const {'jpg', 'jpeg', 'png', 'webp', 'gif'},
    );
    if (picked == null) {
      return null;
    }

    final storedCoverPath = await _customCoverStorageService.persistForBook(
      sourceId: detail.sourceId,
      detailUrl: detail.detailUrl,
      picked: picked,
    );
    if (storedCoverPath == null) {
      return null;
    }
    return storedCoverPath;
  }

  Future<RemoteBookMetadataSaveResult> saveRemoteBookMetadata({
    required BookDetail detail,
    required String title,
    String? author,
    String? intro,
    String? customCoverPath,
  }) async {
    final normalizedTitle = title.trim();
    final normalizedAuthor = _normalizeOptional(author);
    final normalizedIntro = _normalizeOptional(intro);
    final normalizedCoverPath = _normalizeOptional(customCoverPath);

    final rawTitle = detail.title.trim();
    final rawAuthor = _normalizeOptional(detail.author);
    final rawIntro = _normalizeOptional(detail.intro);

    final noDiff =
        normalizedTitle == rawTitle &&
        normalizedAuthor == rawAuthor &&
        normalizedIntro == rawIntro &&
        normalizedCoverPath == null;

    if (noDiff) {
      await _bookMetadataOverrideRepository.deleteByRemoteBook(
        sourceId: detail.sourceId,
        detailUrl: detail.detailUrl,
      );
      return const RemoteBookMetadataSaveResult(metadataOverride: null);
    }

    final nextOverride = BookMetadataOverride.forRemote(
      sourceId: detail.sourceId,
      detailUrl: detail.detailUrl,
      title: normalizedTitle,
      author: normalizedAuthor,
      intro: normalizedIntro,
      coverPath: normalizedCoverPath,
    );
    await _bookMetadataOverrideRepository.upsert(nextOverride);
    return RemoteBookMetadataSaveResult(metadataOverride: nextOverride);
  }

  Future<LocalBookMetadataSaveResult> saveLocalBookMetadata({
    required LocalBook localBook,
    required String title,
    String? author,
    String? intro,
    String? customCoverPath,
    String? charset,
    required bool splitLongChapter,
  }) async {
    final normalizedTitle = title.trim();
    final normalizedAuthor = _normalizeOptional(author);
    final normalizedIntro = _normalizeOptional(intro);
    final normalizedCoverPath = _normalizeOptional(customCoverPath);
    final normalizedCharset = _normalizeOptional(charset);

    final nextLocalBook = localBook.copyWith(
      title: normalizedTitle,
      author: normalizedAuthor,
      clearAuthor: normalizedAuthor == null,
      description: normalizedIntro,
      clearDescription: normalizedIntro == null,
      coverPath: normalizedCoverPath,
      clearCoverPath: normalizedCoverPath == null,
      charset: normalizedCharset,
      clearCharset: normalizedCharset == null,
      splitLongChapter: splitLongChapter,
      updatedAt: DateTime.now(),
    );
    await _localBookRepository.upsertBook(nextLocalBook);

    final needsReindex =
        (localBook.charset?.trim() ?? '') !=
            (nextLocalBook.charset?.trim() ?? '') ||
        localBook.splitLongChapter != nextLocalBook.splitLongChapter;

    return LocalBookMetadataSaveResult(
      localBook: nextLocalBook,
      needsReindex: needsReindex,
    );
  }

  Future<void> resetRemoteBookMetadata({required BookDetail detail}) async {
    await _bookMetadataOverrideRepository.deleteByRemoteBook(
      sourceId: detail.sourceId,
      detailUrl: detail.detailUrl,
    );
  }

  Future<LocalBook> resetLocalBookMetadata({
    required BookDetail detail,
    required LocalBook localBook,
    required bool defaultSplitLongChapterEnabled,
  }) async {
    final fallbackTitle =
        detail.title.trim().isNotEmpty ? detail.title.trim() : localBook.title;
    final fallbackAuthor = _normalizeOptional(detail.author);
    final fallbackIntro = _normalizeOptional(detail.intro);
    final nextLocalBook = localBook.copyWith(
      title: fallbackTitle,
      author: fallbackAuthor,
      clearAuthor: fallbackAuthor == null,
      description: fallbackIntro,
      clearDescription: fallbackIntro == null,
      clearCoverPath: true,
      clearCharset: true,
      splitLongChapter: defaultSplitLongChapterEnabled,
      updatedAt: DateTime.now(),
    );
    await _localBookRepository.upsertBook(nextLocalBook);
    return nextLocalBook;
  }

  String? _normalizeOptional(String? value) {
    final normalized = (value ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }
}
