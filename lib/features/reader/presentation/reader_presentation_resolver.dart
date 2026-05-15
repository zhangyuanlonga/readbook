import 'package:flutter/widgets.dart';

import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reader_document.dart';
import '../../../domain/entities/reader_settings.dart';
import '../application/reader_content_session.dart';
import '../application/reader_document_render_model.dart';
import '../application/reader_image_decode_budget.dart';
import '../application/reader_pagination_models.dart';
import '../application/reader_pagination_spec.dart';
import '../application/reader_surface_metrics.dart';
import 'reader_manga_view.dart';
import 'reader_shell.dart';
import 'reader_text_paged_view.dart';
import 'reader_text_scroll_view.dart';

class ReaderSessionSeed {
  const ReaderSessionSeed({
    required this.contentMode,
    required this.bookId,
    required this.sourceId,
    required this.detailUrl,
    required this.bookTitle,
    required this.chapterId,
    this.bookAuthor,
    this.bookCoverUrl,
    this.chapterUrl,
    this.chapterTitle,
    this.chapterIndex,
    this.resolvedContentType,
    this.audioUrl,
    this.audioManifestUrl,
    this.chapters = const <Chapter>[],
  });

  final ReaderContentMode contentMode;
  final String bookId;
  final String sourceId;
  final String detailUrl;
  final String bookTitle;
  final String? bookAuthor;
  final String? bookCoverUrl;
  final String chapterId;
  final String? chapterUrl;
  final String? chapterTitle;
  final int? chapterIndex;
  final String? resolvedContentType;
  final String? audioUrl;
  final String? audioManifestUrl;
  final List<Chapter> chapters;
}

class ReaderShellParts {
  const ReaderShellParts({required this.background, required this.chrome});

  final Widget? background;
  final ReaderShellChromeSlots chrome;
}

class ReaderPresentationResolver {
  const ReaderPresentationResolver();

  ReaderContentSession resolveContentSession({
    required ReaderSessionSeed seed,
    ReaderContentSession? currentSession,
  }) {
    return currentSession ??
        ReaderContentSession(
          contentMode: seed.contentMode,
          bookId: seed.bookId,
          sourceId: seed.sourceId,
          detailUrl: seed.detailUrl,
          bookTitle: seed.bookTitle,
          bookAuthor: seed.bookAuthor,
          bookCoverUrl: seed.bookCoverUrl,
          chapterId: seed.chapterId,
          chapterUrl: seed.chapterUrl,
          chapterTitle: seed.chapterTitle,
          chapterIndex: seed.chapterIndex,
          resolvedContentType: seed.resolvedContentType,
          audioUrl: seed.audioUrl,
          audioManifestUrl: seed.audioManifestUrl,
          chapters: seed.chapters,
        );
  }

  ReaderShellModel buildShellModel({
    required ReaderContentSession contentSession,
    required ReaderSettings settings,
    required ReaderSurfaceMetrics surfaceMetrics,
    required ReaderPresentationViewportKind viewportKind,
    required ReaderPresentationPalette palette,
    required ReaderShellParts parts,
  }) {
    return ReaderShellModel(
      contentSession: contentSession,
      settings: settings,
      surfaceMetrics: surfaceMetrics,
      viewportKind: viewportKind,
      palette: palette,
      background: parts.background,
      chrome: parts.chrome,
    );
  }

  ReaderTextScrollViewModel buildTextScrollModel({
    required ReaderContentSession contentSession,
    required ReaderSettings settings,
    required ReaderDocument document,
    required ReaderSurfaceMetrics surfaceMetrics,
    required ReaderPresentationPalette palette,
    List<ReaderRenderBlockItem> renderItems = const <ReaderRenderBlockItem>[],
    EdgeInsets? contentPadding,
    ReaderImageDecodeBudget? imageDecodeBudget,
  }) {
    return ReaderTextScrollViewModel(
      contentSession: contentSession,
      settings: settings,
      document: document,
      surfaceMetrics: surfaceMetrics,
      palette: palette,
      renderItems: renderItems,
      contentPadding: contentPadding,
      imageDecodeBudget: imageDecodeBudget,
    );
  }

  ReaderTextPagedViewModel buildTextPagedModel({
    required ReaderContentSession contentSession,
    required ReaderSettings settings,
    required ReaderSurfaceMetrics surfaceMetrics,
    required ReaderPaginationSpec paginationSpec,
    required ReaderPresentationPalette palette,
    required int pageCount,
    required int currentPageIndex,
    ReaderDocument? document,
    List<String> paragraphs = const <String>[],
    List<List<ReaderPagedSlice>> pagedPages = const <List<ReaderPagedSlice>>[],
    List<List<ReaderPagedBlock>> pagedBlockPages =
        const <List<ReaderPagedBlock>>[],
    Map<int, ReaderRenderTextItem> textItemsByParagraph =
        const <int, ReaderRenderTextItem>{},
    ReaderImageDecodeBudget? imageDecodeBudget,
  }) {
    return ReaderTextPagedViewModel(
      contentSession: contentSession,
      settings: settings,
      surfaceMetrics: surfaceMetrics,
      paginationSpec: paginationSpec,
      palette: palette,
      pageCount: pageCount,
      currentPageIndex: currentPageIndex,
      document: document,
      paragraphs: paragraphs,
      pagedPages: pagedPages,
      pagedBlockPages: pagedBlockPages,
      textItemsByParagraph: textItemsByParagraph,
      imageDecodeBudget: imageDecodeBudget,
    );
  }

  ReaderMangaViewModel buildMangaModel({
    required ReaderContentSession contentSession,
    required ReaderSettings settings,
    required ReaderSurfaceMetrics surfaceMetrics,
    required ReaderPresentationPalette palette,
    required List<String> imageUrls,
    required int currentIndex,
    required EdgeInsets continuousPadding,
    required EdgeInsets pagedPagePadding,
    required double continuousCacheExtent,
    ReaderImageDecodeBudget? imageDecodeBudget,
  }) {
    return ReaderMangaViewModel(
      contentSession: contentSession,
      settings: settings,
      surfaceMetrics: surfaceMetrics,
      palette: palette,
      imageUrls: imageUrls,
      currentIndex: currentIndex,
      continuousPadding: continuousPadding,
      pagedPagePadding: pagedPagePadding,
      continuousCacheExtent: continuousCacheExtent,
      imageDecodeBudget: imageDecodeBudget,
    );
  }
}
