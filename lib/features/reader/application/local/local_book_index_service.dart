import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_codes.dart';
import '../../../../core/errors/error_stage.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../data/datasources/local/app_database.dart';
import '../../../../data/repositories/local_book_repository_impl.dart';
import '../../../../domain/entities/local_book.dart';
import '../../../../domain/entities/local_chapter.dart';
import '../../../../domain/repositories/local_book_repository.dart';
import 'epub_local_book_parser.dart';
import 'local_book_parser.dart';
import 'txt_local_book_parser.dart';
import 'txt_toc_rule_settings_service.dart';
import 'dart:io';

class LocalBookIndexService {
  LocalBookIndexService({
    LocalBookRepository? localBookRepository,
    List<LocalBookParser>? parsers,
    AppLogger? logger,
    TxtTocRuleSettingsService? txtTocRuleSettingsService,
  }) : _localBookRepository =
           localBookRepository ?? LocalBookRepositoryImpl(AppDatabase.instance),
       _parsers =
           parsers ??
           <LocalBookParser>[
             TxtLocalBookParser(
               ruleSettingsService:
                   txtTocRuleSettingsService ?? TxtTocRuleSettingsService(),
             ),
             const EpubLocalBookParser(),
           ],
       _logger = logger ?? AppLogger.instance;

  final LocalBookRepository _localBookRepository;
  final List<LocalBookParser> _parsers;
  final AppLogger _logger;

  Future<List<LocalChapter>> ensureIndexed({
    required String bookId,
    bool force = false,
  }) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: 'bookId 不能为空。',
      );
    }

    var book = await _localBookRepository.getBookById(normalizedBookId);
    if (book == null) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '未找到本地书籍：$normalizedBookId',
      );
    }

    if (!force &&
        book.indexStatus == LocalBookIndexStatus.ready &&
        book.chapterCount > 0) {
      final chapters = await _localBookRepository.getChapters(normalizedBookId);
      if (chapters.isNotEmpty) {
        return chapters;
      }
    }

    final parser = _parsers.firstWhere(
      (item) => item.supports(book.format),
      orElse: () => _UnsupportedLocalBookParser(book.format),
    );

    await _localBookRepository.updateBookIndexState(
      bookId: normalizedBookId,
      status: LocalBookIndexStatus.indexing,
      clearLastError: true,
    );

    try {
      final parsed = await parser.parse(book);
      if (parsed.chapters.isEmpty) {
        throw AppException(
          code: ErrorCode.ruleMatchEmpty,
          stage: ErrorStage.content,
          briefMessage: '解析完成但没有可用章节。',
        );
      }

      final now = DateTime.now();
      final refreshedFileSize = await File(
        book.storagePath,
      ).stat().then((stat) => stat.size).catchError((_) => book.fileSize);
      final updatedBook = book.copyWith(
        title: _nonEmptyOrFallback(parsed.title, fallback: book.title),
        author: _nonEmptyOrNull(parsed.author, fallback: book.author),
        indexStatus: LocalBookIndexStatus.ready,
        chapterCount: parsed.chapters.length,
        fileSize: refreshedFileSize,
        updatedAt: now,
        clearLastError: true,
      );

      final chapters = parsed.chapters
          .asMap()
          .entries
          .map((entry) {
            final chapter = entry.value;
            return LocalChapter(
              id: '${normalizedBookId}_${entry.key}',
              bookId: normalizedBookId,
              chapterIndex: entry.key,
              title: _nonEmptyOrFallback(
                chapter.title,
                fallback: '第 ${entry.key + 1} 章',
              ),
              content:
                  book.format == LocalBookFormat.txt &&
                          chapter.startOffset != null &&
                          chapter.endOffset != null &&
                          chapter.endOffset! > chapter.startOffset!
                      ? ''
                      : chapter.content,
              createdAt: now,
              updatedAt: now,
              startOffset: chapter.startOffset,
              endOffset: chapter.endOffset,
            );
          })
          .toList(growable: false);

      await _localBookRepository.upsertBook(updatedBook);
      await _localBookRepository.replaceChapters(
        bookId: normalizedBookId,
        chapters: chapters,
      );
      await _localBookRepository.updateBookIndexState(
        bookId: normalizedBookId,
        status: LocalBookIndexStatus.ready,
        chapterCount: chapters.length,
        clearLastError: true,
      );

      return chapters;
    } on AppException catch (error) {
      await _localBookRepository.updateBookIndexState(
        bookId: normalizedBookId,
        status: LocalBookIndexStatus.failed,
        chapterCount: 0,
        lastError: error.briefMessage,
      );
      rethrow;
    } catch (error) {
      final message = '本地书籍索引失败：$error';
      await _localBookRepository.updateBookIndexState(
        bookId: normalizedBookId,
        status: LocalBookIndexStatus.failed,
        chapterCount: 0,
        lastError: message,
      );
      _logger.error(
        'Local book indexing failed',
        exception: AppException(
          code: ErrorCode.unknown,
          stage: ErrorStage.content,
          briefMessage: message,
          cause: error,
        ),
      );
      throw AppException(
        code: ErrorCode.unknown,
        stage: ErrorStage.content,
        briefMessage: message,
        cause: error,
      );
    }
  }

  String _nonEmptyOrFallback(String? value, {required String fallback}) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return fallback;
    }
    return normalized;
  }

  String? _nonEmptyOrNull(String? value, {required String? fallback}) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
    final fallbackNormalized = fallback?.trim();
    if (fallbackNormalized == null || fallbackNormalized.isEmpty) {
      return null;
    }
    return fallbackNormalized;
  }
}

class _UnsupportedLocalBookParser implements LocalBookParser {
  const _UnsupportedLocalBookParser(this.format);

  final LocalBookFormat format;

  @override
  Future<LocalParsedBook> parse(LocalBook book) {
    throw AppException(
      code: ErrorCode.validation,
      stage: ErrorStage.content,
      briefMessage: '暂不支持 ${format.name} 格式的章节解析。',
    );
  }

  @override
  bool supports(LocalBookFormat format) {
    return this.format == format;
  }
}
