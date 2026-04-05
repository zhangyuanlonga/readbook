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
import 'epub_local_book_parser.dart';
import 'local_book_parser.dart';
import 'local_book_index_service.dart';
import 'local_book_storage_service.dart';

class LocalChapterContentService {
  LocalChapterContentService({
    LocalBookRepository? localBookRepository,
    LocalBookIndexService? indexService,
    EpubLocalBookParser? epubParser,
    LocalBookStorageService? storageService,
  }) : _localBookRepository =
           localBookRepository ?? LocalBookRepositoryImpl(AppDatabase.instance),
       _indexService =
           indexService ??
           LocalBookIndexService(
             localBookRepository:
                 localBookRepository ??
                 LocalBookRepositoryImpl(AppDatabase.instance),
           ),
       _epubParser = epubParser ?? const EpubLocalBookParser(),
       _storageService = storageService ?? LocalBookStorageService();

  final LocalBookRepository _localBookRepository;
  final LocalBookIndexService _indexService;
  final EpubLocalBookParser _epubParser;
  final LocalBookStorageService _storageService;

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

    final refreshedBook = await _indexService.refreshBookState(
      bookId: normalizedBookId,
    );
    if (refreshedBook != null) {
      book = refreshedBook;
    }
    _ensureBookReadyForReading(book);

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

    if (_canUseStoredChapterContent(chapter: chapter)) {
      return chapter;
    }

    final readableBook = await _hydrateReadableBook(book);

    if (book.format == LocalBookFormat.txt) {
      final hydratedContent = await _loadTxtChapterContentByOffsets(
        chapter: chapter,
        book: readableBook,
      );
      return chapter.copyWith(content: hydratedContent);
    }

    final hydrated = await _loadEpubChapterContent(
      chapter: chapter,
      book: readableBook,
    );
    await _localBookRepository.updateChapterContent(
      chapterId: chapter.id,
      content: hydrated.content,
      imageUrls: hydrated.imageUrls,
      document: hydrated.document,
    );
    return chapter.copyWith(
      content: hydrated.content,
      imageUrls: hydrated.imageUrls,
      document: hydrated.document,
    );
  }

  bool _needsReindex(LocalBook book) {
    return book.indexStatus != LocalBookIndexStatus.ready ||
        book.chapterCount <= 0;
  }

  void _ensureBookReadyForReading(LocalBook book) {
    if (!_needsReindex(book)) {
      return;
    }

    switch (book.indexStatus) {
      case LocalBookIndexStatus.pending:
        throw AppException(
          code: ErrorCode.validation,
          stage: ErrorStage.content,
          briefMessage: '本地图书目录尚未建立完成，请稍后重试。',
        );
      case LocalBookIndexStatus.indexing:
        throw AppException(
          code: ErrorCode.validation,
          stage: ErrorStage.content,
          briefMessage: '本地图书正在建立目录，请稍后重试。',
        );
      case LocalBookIndexStatus.stale:
        throw AppException(
          code: ErrorCode.validation,
          stage: ErrorStage.content,
          briefMessage: '本地图书目录已过期，请先重新索引。',
        );
      case LocalBookIndexStatus.failed:
        final lastError = book.lastError?.trim();
        throw AppException(
          code: ErrorCode.validation,
          stage: ErrorStage.content,
          briefMessage:
              (lastError != null && lastError.isNotEmpty)
                  ? '本地图书索引失败：$lastError'
                  : '本地图书索引失败，请先重新索引。',
        );
      case LocalBookIndexStatus.ready:
        throw AppException(
          code: ErrorCode.ruleMatchEmpty,
          stage: ErrorStage.content,
          briefMessage: '未解析到可读章节，请重新索引后重试。',
        );
    }
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

  bool _canUseStoredChapterContent({required LocalChapter chapter}) {
    return chapter.content.trim().isNotEmpty;
  }

  Future<LocalParsedChapter> _loadEpubChapterContent({
    required LocalChapter chapter,
    required LocalBook book,
  }) {
    return _epubParser.parseChapter(book: book, chapter: chapter);
  }

  Future<LocalBook> _hydrateReadableBook(LocalBook book) async {
    final resolvedStoragePath = await _storageService.resolveStoragePath(
      book.storagePath,
    );
    if (resolvedStoragePath == book.storagePath) {
      return book;
    }
    return book.copyWith(storagePath: resolvedStoragePath);
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
    var safeStart = startOffset.clamp(0, fileLength).toInt();
    var safeEnd = endOffset.clamp(0, fileLength).toInt();
    final normalizedCharset = _normalizeCharsetName(book.charset);
    if (normalizedCharset == 'utf-16' ||
        normalizedCharset == 'utf-16le' ||
        normalizedCharset == 'utf-16be') {
      if (safeStart.isOdd) {
        safeStart -= 1;
      }
      if (safeEnd.isOdd) {
        safeEnd -= 1;
      }
    }
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
      if (normalized == 'utf-16le' || normalized == 'utf-16be') {
        final preferred = _tryDecodeByCharset(bytes, normalized);
        final alternate = _tryDecodeByCharset(
          bytes,
          normalized == 'utf-16le' ? 'utf-16be' : 'utf-16le',
        );
        final best = _pickBetterDecodedText(preferred, alternate);
        if (best != null) {
          return best;
        }
      }
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

  String? _pickBetterDecodedText(String? primary, String? alternate) {
    final primaryScore = _decodedTextScore(primary);
    final alternateScore = _decodedTextScore(alternate);
    if (primaryScore == null && alternateScore == null) {
      return null;
    }
    if (alternateScore != null &&
        (primaryScore == null || alternateScore > primaryScore)) {
      return alternate;
    }
    return primary;
  }

  int? _decodedTextScore(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    var hanCount = 0;
    var replacementCount = 0;
    var nulCount = 0;
    var controlCount = 0;
    for (final rune in text.runes) {
      if (rune >= 0x4E00 && rune <= 0x9FFF) {
        hanCount += 1;
      }
      if (rune == 0xFFFD) {
        replacementCount += 1;
      }
      if (rune == 0) {
        nulCount += 1;
      }
      if (rune < 0x20 && rune != 0x09 && rune != 0x0A && rune != 0x0D) {
        controlCount += 1;
      }
    }
    return hanCount * 8 -
        replacementCount * 20 -
        nulCount * 40 -
        controlCount * 12;
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
