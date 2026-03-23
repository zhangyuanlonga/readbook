import 'dart:convert';
import 'dart:io';

import 'package:charset/charset.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_codes.dart';
import '../../../../core/errors/error_stage.dart';
import '../../../../data/datasources/local/app_database.dart';
import '../../../../data/repositories/local_book_repository_impl.dart';
import '../../../../domain/entities/local_book.dart';
import '../../../../domain/entities/local_chapter.dart';
import '../../../../domain/repositories/local_book_repository.dart';
import 'local_book_index_service.dart';

class LocalChapterContentService {
  LocalChapterContentService({
    LocalBookRepository? localBookRepository,
    LocalBookIndexService? indexService,
  }) : _localBookRepository =
           localBookRepository ?? LocalBookRepositoryImpl(AppDatabase.instance),
       _indexService =
           indexService ??
           LocalBookIndexService(
             localBookRepository:
                 localBookRepository ??
                 LocalBookRepositoryImpl(AppDatabase.instance),
           );

  final LocalBookRepository _localBookRepository;
  final LocalBookIndexService _indexService;

  Future<LocalChapter> load({
    required String bookId,
    String? chapterId,
    int? chapterIndex,
  }) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '本地书籍信息缺失。',
      );
    }

    var book = await _localBookRepository.getBookById(normalizedBookId);
    if (book == null) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '未找到本地书籍，请确认文件是否已移除。',
      );
    }

    if (_needsReindex(book)) {
      await _indexService.ensureIndexed(bookId: normalizedBookId);
      final refreshed = await _localBookRepository.getBookById(
        normalizedBookId,
      );
      if (refreshed != null) {
        book = refreshed;
      }
    }

    final chapter = await _resolveChapter(
      book: book,
      chapterId: chapterId,
      chapterIndex: chapterIndex,
    );
    if (chapter == null) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: '未找到本地章节内容，请重新索引后重试。',
      );
    }

    if (_canUseStoredChapterContent(book: book, chapter: chapter)) {
      return chapter;
    }

    final hydratedContent = await _loadTxtChapterContentByOffsets(
      chapter: chapter,
      book: book,
    );
    return chapter.copyWith(content: hydratedContent);
  }

  bool _needsReindex(LocalBook book) {
    return book.indexStatus != LocalBookIndexStatus.ready ||
        book.chapterCount <= 0;
  }

  Future<LocalChapter?> _resolveChapter({
    required LocalBook book,
    required String? chapterId,
    required int? chapterIndex,
  }) async {
    final normalizedChapterId = (chapterId ?? '').trim();
    if (normalizedChapterId.isNotEmpty) {
      final byId = await _localBookRepository.getChapterById(
        normalizedChapterId,
      );
      if (byId != null) {
        if (byId.bookId.trim() != book.id.trim()) {
          throw AppException(
            code: ErrorCode.validation,
            stage: ErrorStage.content,
            briefMessage: '章节与书籍不匹配，请重新进入阅读页。',
          );
        }
        return byId;
      }
    }

    if (chapterIndex != null) {
      final safeIndex = _safeChapterIndex(
        chapterIndex,
        chapterCount: book.chapterCount,
      );
      final byIndex = await _localBookRepository.getChapterByIndex(
        book.id,
        safeIndex,
      );
      if (byIndex != null) {
        return byIndex;
      }
    }

    final chapters = await _localBookRepository.getChapters(book.id);
    if (chapters.isEmpty) {
      return null;
    }
    if (chapterIndex == null) {
      return chapters.first;
    }
    final fallbackIndex = _safeChapterIndex(
      chapterIndex,
      chapterCount: chapters.length,
    );
    return chapters[fallbackIndex];
  }

  int _safeChapterIndex(int chapterIndex, {required int chapterCount}) {
    if (chapterCount <= 0) {
      return chapterIndex < 0 ? 0 : chapterIndex;
    }
    return chapterIndex.clamp(0, chapterCount - 1).toInt();
  }

  bool _canUseStoredChapterContent({
    required LocalBook book,
    required LocalChapter chapter,
  }) {
    if (chapter.content.trim().isNotEmpty) {
      return true;
    }
    return book.format != LocalBookFormat.txt;
  }

  Future<String> _loadTxtChapterContentByOffsets({
    required LocalChapter chapter,
    required LocalBook book,
  }) async {
    final startOffset = chapter.startOffset;
    final endOffset = chapter.endOffset;
    if (startOffset == null || endOffset == null || endOffset <= startOffset) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: '本地章节缺少有效偏移信息，请重新索引后重试。',
      );
    }

    final file = File(book.storagePath);
    if (!await file.exists()) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '本地文件不存在：${book.storagePath}',
      );
    }

    final fileLength = await file.length();
    final safeStart = startOffset.clamp(0, fileLength).toInt();
    final safeEnd = endOffset.clamp(0, fileLength).toInt();
    if (safeEnd <= safeStart) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: '本地章节内容为空，请重新索引后重试。',
      );
    }

    final handle = await file.open(mode: FileMode.read);
    try {
      await handle.setPosition(safeStart);
      final bytes = await handle.read(safeEnd - safeStart);
      final text = _decodeBytes(bytes, preferredCharset: book.charset).trim();
      if (text.isEmpty) {
        throw AppException(
          code: ErrorCode.ruleMatchEmpty,
          stage: ErrorStage.content,
          briefMessage: '本地章节内容为空，请重新索引后重试。',
        );
      }
      return text;
    } finally {
      await handle.close();
    }
  }

  String _decodeBytes(List<int> bytes, {required String? preferredCharset}) {
    final normalized = _normalizeCharsetName(preferredCharset);
    if (normalized != null) {
      final preferred = _tryDecodeByCharset(bytes, normalized);
      if (preferred != null) {
        return preferred;
      }
    }

    for (final candidate in const <String>[
      'utf-8',
      'utf-16be',
      'utf-16le',
      'gbk',
      'gb18030',
      'latin1',
    ]) {
      final decoded = _tryDecodeByCharset(bytes, candidate);
      if (decoded != null) {
        return decoded;
      }
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  String? _normalizeCharsetName(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    return switch (normalized) {
      'utf8' => 'utf-8',
      'utf-8' => 'utf-8',
      'utf16' => 'utf-16',
      'utf-16' => 'utf-16',
      'utf16be' => 'utf-16be',
      'utf-16be' => 'utf-16be',
      'utf16le' => 'utf-16le',
      'utf-16le' => 'utf-16le',
      'gb2312' => 'gbk',
      'gbk' => 'gbk',
      'gb18030' => 'gb18030',
      'latin1' => 'latin1',
      'iso-8859-1' => 'latin1',
      _ => normalized,
    };
  }

  String? _tryDecodeByCharset(List<int> bytes, String charsetName) {
    try {
      switch (charsetName) {
        case 'utf-8':
          return utf8.decode(bytes, allowMalformed: false);
        case 'latin1':
          return latin1.decode(bytes, allowInvalid: true);
        default:
          final encoding = Charset.getByName(charsetName);
          if (encoding == null) {
            return null;
          }
          return encoding.decode(bytes);
      }
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }
}
