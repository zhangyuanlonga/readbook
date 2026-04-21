import 'dart:io';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_codes.dart';
import '../../../../core/errors/error_stage.dart';
import '../../../../data/datasources/local/app_database.dart';
import '../../../../data/repositories/local_book_repository_impl.dart';
import '../../../../domain/entities/local_book.dart';
import '../../../../domain/entities/local_chapter.dart';
import '../../../../domain/repositories/local_book_repository.dart';
import 'local_book_storage_service.dart';
import 'local_text_encoding_detector.dart';

class LocalBookPreviewService {
  LocalBookPreviewService({
    LocalBookRepository? localBookRepository,
    LocalBookStorageService? storageService,
    LocalTextEncodingDetector? textEncodingDetector,
  }) : _localBookRepository =
           localBookRepository ?? LocalBookRepositoryImpl(AppDatabase.instance),
       _storageService = storageService ?? LocalBookStorageService(),
       _textEncodingDetector =
           textEncodingDetector ?? const LocalTextEncodingDetector();

  final LocalBookRepository _localBookRepository;
  final LocalBookStorageService _storageService;
  final LocalTextEncodingDetector _textEncodingDetector;
  static const int _txtBootstrapReadBytes = 64 * 1024;

  Future<LocalChapter> loadTxtBootstrapPreview({required String bookId}) async {
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
    if (book.format != LocalBookFormat.txt) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '仅 TXT 本地图书支持正文预览。',
      );
    }

    book = await _hydrateReadableBook(book);
    return _loadTxtBootstrapChapter(book: book);
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

  Future<LocalChapter> _loadTxtBootstrapChapter({
    required LocalBook book,
  }) async {
    final file = File(book.storagePath);
    if (!await file.exists()) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '本地文件不存在：${book.storagePath}',
      );
    }

    final fileLength = await file.length();
    if (fileLength <= 0) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: '文本文件为空，无法读取正文。',
      );
    }

    var end =
        fileLength < _txtBootstrapReadBytes
            ? fileLength
            : _txtBootstrapReadBytes;
    final normalizedCharset = LocalTextEncodingDetector.normalizeCharsetName(
      book.charset,
    );
    if ((normalizedCharset == 'utf-16' ||
            normalizedCharset == 'utf-16le' ||
            normalizedCharset == 'utf-16be') &&
        end.isOdd) {
      end -= 1;
    }

    final handle = await file.open(mode: FileMode.read);
    try {
      await handle.setPosition(0);
      final bytes = await handle.read(end);
      final decoded = await _textEncodingDetector.decodeDirectBytesAsync(
        bytes,
        preferredCharset: book.charset,
        hintedCharset: book.charset,
      );
      final content = decoded?.text.trim() ?? '';
      if (content.isEmpty) {
        throw AppException(
          code: ErrorCode.ruleMatchEmpty,
          stage: ErrorStage.content,
          briefMessage: '本地章节内容为空，请检查编码或重新导入。',
        );
      }

      final now = DateTime.now();
      return LocalChapter(
        id: '${book.id}_bootstrap',
        bookId: book.id,
        chapterIndex: 0,
        title: '开始阅读',
        content: content,
        createdAt: now,
        updatedAt: now,
        startOffset: 0,
        endOffset: end,
      );
    } finally {
      await handle.close();
    }
  }
}
