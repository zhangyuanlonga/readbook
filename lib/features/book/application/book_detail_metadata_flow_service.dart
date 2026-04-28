import '../../../domain/entities/book_metadata_override.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/local_book.dart';
import 'book_detail_service.dart';
import 'book_metadata_edit_service.dart';
import 'book_metadata_presentation_resolver.dart';
import 'book_presentation_sync_service.dart';

class BookDetailMetadataEditDraft {
  const BookDetailMetadataEditDraft({
    required this.title,
    required this.author,
    required this.intro,
    this.customCoverPath,
    this.charset,
    required this.splitLongChapter,
  });

  final String title;
  final String author;
  final String intro;
  final String? customCoverPath;
  final String? charset;
  final bool splitLongChapter;
}

class BookDetailMetadataFlowResult {
  const BookDetailMetadataFlowResult({
    required this.presentation,
    required this.successMessage,
    this.metadataOverride,
    this.localBook,
    this.needsReindex = false,
  });

  final BookDisplayState presentation;
  final String successMessage;
  final BookMetadataOverride? metadataOverride;
  final LocalBook? localBook;
  final bool needsReindex;
}

class BookDetailMetadataFlowService {
  const BookDetailMetadataFlowService({
    required BookMetadataEditService bookMetadataEditService,
    required BookPresentationSyncService bookPresentationSyncService,
    required BookDisplayStateResolver presentationResolver,
  }) : _bookMetadataEditService = bookMetadataEditService,
       _bookPresentationSyncService = bookPresentationSyncService,
       _presentationResolver = presentationResolver;

  final BookMetadataEditService _bookMetadataEditService;
  final BookPresentationSyncService _bookPresentationSyncService;
  final BookDisplayStateResolver _presentationResolver;

  Future<BookDetailMetadataFlowResult> saveRemoteMetadata({
    required BookDetailLoadResult result,
    required BookDetailMetadataEditDraft draft,
    required bool isInBookshelf,
    String? latestChapterTitle,
  }) async {
    final saveResult = await _bookMetadataEditService.saveRemoteBookMetadata(
      detail: result.detail,
      title: draft.title,
      author: draft.author,
      intro: draft.intro,
      customCoverPath: draft.customCoverPath,
    );
    return _syncAndBuildResult(
      result: result,
      metadataOverride: saveResult.metadataOverride,
      localBook: null,
      isInBookshelf: isInBookshelf,
      latestChapterTitle: latestChapterTitle,
      successMessage: '已保存书籍信息。',
    );
  }

  Future<BookDetailMetadataFlowResult> saveLocalMetadata({
    required BookDetailLoadResult result,
    required LocalBook localBook,
    required BookDetailMetadataEditDraft draft,
    required bool isInBookshelf,
    String? latestChapterTitle,
  }) async {
    final saveResult = await _bookMetadataEditService.saveLocalBookMetadata(
      localBook: localBook,
      title: draft.title,
      author: draft.author,
      intro: draft.intro,
      customCoverPath: draft.customCoverPath,
      charset: draft.charset,
      splitLongChapter: draft.splitLongChapter,
    );
    final synced = await _syncAndBuildResult(
      result: result,
      metadataOverride: null,
      localBook: saveResult.localBook,
      isInBookshelf: isInBookshelf,
      latestChapterTitle: latestChapterTitle,
      successMessage: '已保存本地图书信息。',
    );
    return BookDetailMetadataFlowResult(
      presentation: synced.presentation,
      successMessage: synced.successMessage,
      localBook: saveResult.localBook,
      needsReindex: saveResult.needsReindex,
    );
  }

  Future<BookDetailMetadataFlowResult> resetRemoteMetadata({
    required BookDetailLoadResult result,
    required bool isInBookshelf,
    String? latestChapterTitle,
  }) async {
    await _bookMetadataEditService.resetRemoteBookMetadata(detail: result.detail);
    return _syncAndBuildResult(
      result: result,
      metadataOverride: null,
      localBook: null,
      isInBookshelf: isInBookshelf,
      latestChapterTitle: latestChapterTitle,
      successMessage: '已恢复默认展示。',
    );
  }

  Future<BookDetailMetadataFlowResult> resetLocalMetadata({
    required BookDetailLoadResult result,
    required LocalBook localBook,
    required bool defaultSplitLongChapterEnabled,
    required bool isInBookshelf,
    String? latestChapterTitle,
  }) async {
    final nextLocalBook = await _bookMetadataEditService.resetLocalBookMetadata(
      detail: result.detail,
      localBook: localBook,
      defaultSplitLongChapterEnabled: defaultSplitLongChapterEnabled,
    );
    final synced = await _syncAndBuildResult(
      result: result,
      metadataOverride: null,
      localBook: nextLocalBook,
      isInBookshelf: isInBookshelf,
      latestChapterTitle: latestChapterTitle,
      successMessage: '已恢复默认展示。',
    );
    return BookDetailMetadataFlowResult(
      presentation: synced.presentation,
      successMessage: synced.successMessage,
      localBook: nextLocalBook,
    );
  }

  Future<BookDetailMetadataFlowResult> _syncAndBuildResult({
    required BookDetailLoadResult result,
    required BookMetadataOverride? metadataOverride,
    required LocalBook? localBook,
    required bool isInBookshelf,
    required String successMessage,
    String? latestChapterTitle,
  }) async {
    final presentation = _resolvePresentation(
      detail: result.detail,
      chapters: result.chapters,
      metadataOverride: metadataOverride,
      localBook: localBook,
    );
    await _bookPresentationSyncService.syncPresentation(
      detail: result.detail,
      chapters: result.chapters,
      presentation: presentation,
      isInBookshelf: isInBookshelf,
      latestChapterTitle: latestChapterTitle,
    );
    return BookDetailMetadataFlowResult(
      presentation: presentation,
      successMessage: successMessage,
      metadataOverride: metadataOverride,
      localBook: localBook,
    );
  }

  BookDisplayState _resolvePresentation({
    required detail,
    required List<Chapter> chapters,
    required BookMetadataOverride? metadataOverride,
    required LocalBook? localBook,
  }) {
    return _presentationResolver.resolve(
      fallbackTitle: detail.title,
      fallbackAuthor: detail.author,
      fallbackIntro: detail.intro,
      realCoverUrl: detail.coverUrl,
      localBook: localBook,
      metadataOverride: metadataOverride,
    );
  }
}
