import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../domain/entities/chapter.dart';
import '../application/chapter_content_service.dart';
import '../application/content_provider.dart';
import '../application/removed_script_source_guard.dart';
import '../application/reader_chapter_navigation.dart';

class ReaderChapterLoadSnapshot {
  const ReaderChapterLoadSnapshot({
    required this.result,
    required this.isCached,
  });

  final ChapterContentResult result;
  final bool isCached;
}

class ReaderContentLoadingPresenter {
  const ReaderContentLoadingPresenter({
    ReaderChapterNavigation chapterNavigation = const ReaderChapterNavigation(),
  }) : _chapterNavigation = chapterNavigation;

  final ReaderChapterNavigation _chapterNavigation;

  Future<ReaderChapterLoadSnapshot> fetchChapterContentSnapshot({
    required ContentProvider contentProvider,
    required String sourceId,
    required String chapterId,
    required String chapterUrl,
    required String? chapterTitle,
    required int? chapterIndex,
    required String currentBookId,
    required String bookTitle,
    required String? detailUrl,
  }) async {
    final contentResult = await contentProvider.loadChapterContent(
      sourceId: sourceId,
      chapterUrl: chapterUrl,
      bookId: currentBookId,
      bookTitle: bookTitle,
      detailUrl: detailUrl,
      chapterId: chapterId,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
    );

    return ReaderChapterLoadSnapshot(
      result: contentResult,
      isCached: contentResult.fromCache,
    );
  }

  int? resolveAdjacentContinuousChapterIndex({
    required List<Chapter> chapters,
    required List<int> loadedChapterIndices,
    required bool forward,
  }) {
    if (loadedChapterIndices.isEmpty) {
      return null;
    }
    final startIndex =
        forward
            ? loadedChapterIndices.last + 1
            : loadedChapterIndices.first - 1;
    return _chapterNavigation.findReadableChapterIndex(
      chapters,
      startIndex,
      forward: forward,
    );
  }

  ContentProvider requireContentProvider({
    required ContentProviderRegistry registry,
    required String? sourceId,
    ErrorStage stage = ErrorStage.unknown,
  }) {
    final normalized = (sourceId ?? '').trim();
    if (normalized.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: stage,
        briefMessage: '缺少 sourceId，无法加载内容。',
      );
    }

    final provider = registry.findForSourceId(normalized);
    if (provider == null) {
      if (isRemovedScriptSourceId(normalized)) {
        throwRemovedScriptSource(stage: stage, sourceId: normalized);
      }
      throw AppException(
        code: ErrorCode.unknownSource,
        stage: stage,
        briefMessage: '未找到可用的内容提供者。',
      );
    }
    return provider;
  }
}
