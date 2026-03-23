import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/logging/app_logger.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/repositories/local_book_repository_impl.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/repositories/local_book_repository.dart';
import '../../reader/application/reader_system_settings_service.dart';
import '../../reader/application/local/epub_local_book_parser.dart';
import '../../reader/application/local/local_text_encoding_detector.dart';
import 'bookshelf_service.dart';

class LocalBookImportResult {
  const LocalBookImportResult({
    required this.localBook,
    required this.bookshelfBook,
  });

  final LocalBook localBook;
  final BookshelfBook bookshelfBook;
}

class LocalBookImportService {
  LocalBookImportService({
    LocalBookRepository? localBookRepository,
    BookshelfService? bookshelfService,
    ReaderSystemSettingsService? readerSystemSettingsService,
    LocalTextEncodingDetector? textEncodingDetector,
    AppLogger? logger,
    Future<Directory> Function()? supportDirectoryProvider,
  }) : _localBookRepository =
           localBookRepository ?? LocalBookRepositoryImpl(AppDatabase.instance),
       _bookshelfService = bookshelfService ?? BookshelfService(),
       _readerSystemSettingsService =
           readerSystemSettingsService ?? ReaderSystemSettingsService(),
       _textEncodingDetector =
           textEncodingDetector ?? const LocalTextEncodingDetector(),
       _logger = logger ?? AppLogger.instance,
       _supportDirectoryProvider =
           supportDirectoryProvider ?? getApplicationSupportDirectory;

  static const String localBookSourceId = '__local_book__';

  final LocalBookRepository _localBookRepository;
  final BookshelfService _bookshelfService;
  final ReaderSystemSettingsService _readerSystemSettingsService;
  final LocalTextEncodingDetector _textEncodingDetector;
  final AppLogger _logger;
  final Future<Directory> Function() _supportDirectoryProvider;
  final Uuid _uuid = const Uuid();

  Future<LocalBookImportResult> importFromFile({
    required String filePath,
    String? displayName,
  }) async {
    final normalizedPath = filePath.trim();
    if (normalizedPath.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.detail,
        briefMessage: '文件路径不能为空。',
      );
    }

    final sourceFile = File(normalizedPath);
    if (!await sourceFile.exists()) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.detail,
        briefMessage: '本地文件不存在，请重新选择。',
      );
    }

    final format = _resolveFormat(normalizedPath);
    if (format == null) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.detail,
        briefMessage: '仅支持导入 txt 或 epub 文件。',
      );
    }

    final sourceStat = await sourceFile.stat();
    final now = DateTime.now();
    final splitLongChapterDefault =
        await _readerSystemSettingsService
            .loadLocalTxtSplitLongChapterEnabled();
    final existingBook = await _findBySourcePath(normalizedPath);
    final bookId = existingBook?.id ?? _buildBookId();

    final storageDir = await _resolveStorageDirectory();
    final targetFile = File(
      p.join(storageDir.path, '$bookId${_extensionForFormat(format)}'),
    );

    final storageResult = await _copyIntoStorage(
      sourceFile: sourceFile,
      targetFile: targetFile,
      format: format,
      sourcePath: normalizedPath,
      bookId: bookId,
    );
    final targetStat = storageResult.storageStat;
    final normalizedCharset = storageResult.normalizedCharset;

    final title = _resolveTitle(displayName ?? p.basename(normalizedPath));
    final localBook =
        existingBook?.copyWith(
          title: title,
          format: format,
          storagePath: targetFile.path,
          sourcePath: normalizedPath,
          fileSize: targetStat.size,
          sourceFileSize: sourceStat.size,
          sourceFileLastModifiedMs: sourceStat.modified.millisecondsSinceEpoch,
          storageFileLastModifiedMs: targetStat.modified.millisecondsSinceEpoch,
          indexStatus: LocalBookIndexStatus.pending,
          chapterCount: 0,
          splitLongChapter: splitLongChapterDefault,
          updatedAt: now,
          charset: normalizedCharset,
          clearCharset: normalizedCharset == null,
          clearLastError: true,
          clearTxtTocRuleName: true,
          clearTxtTocRulePattern: true,
        ) ??
        LocalBook(
          id: bookId,
          title: title,
          format: format,
          storagePath: targetFile.path,
          sourcePath: normalizedPath,
          fileSize: targetStat.size,
          sourceFileSize: sourceStat.size,
          sourceFileLastModifiedMs: sourceStat.modified.millisecondsSinceEpoch,
          storageFileLastModifiedMs: targetStat.modified.millisecondsSinceEpoch,
          indexStatus: LocalBookIndexStatus.pending,
          chapterCount: 0,
          splitLongChapter: splitLongChapterDefault,
          createdAt: now,
          updatedAt: now,
          charset: normalizedCharset,
          author: existingBook?.author,
          coverPath: existingBook?.coverPath,
        );

    await _localBookRepository.upsertBook(localBook);
    await _localBookRepository.replaceChapters(
      bookId: bookId,
      chapters: const [],
    );
    await _localBookRepository.updateBookIndexState(
      bookId: bookId,
      status: LocalBookIndexStatus.pending,
      chapterCount: 0,
      clearLastError: true,
    );

    final shelfBook = BookshelfBook(
      bookId: bookId,
      sourceId: localBookSourceId,
      title: title,
      detailUrl: 'local://book/$bookId',
      addedAt: now,
      author: '本地导入',
    );
    await _bookshelfService.upsert(shelfBook);

    _logger.info(
      'Local book imported',
      context: {
        'bookId': bookId,
        'format': format.name,
        'sourcePath': normalizedPath,
        if (storageResult.originalCharset != null)
          'sourceCharset': storageResult.originalCharset,
        if (normalizedCharset != null) 'normalizedCharset': normalizedCharset,
        'charsetConverted': storageResult.convertedToUtf8,
      },
    );

    return LocalBookImportResult(
      localBook: localBook,
      bookshelfBook: shelfBook,
    );
  }

  Future<void> removeLocalBook({
    required String bookId,
    required String detailUrl,
  }) async {
    final normalizedBookId = bookId.trim();
    final normalizedDetailUrl = detailUrl.trim();
    if (normalizedBookId.isEmpty || normalizedDetailUrl.isEmpty) {
      return;
    }

    final localBook = await _localBookRepository.getBookById(normalizedBookId);
    if (localBook != null) {
      final file = File(localBook.storagePath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (error) {
          _logger.warn(
            'Delete local book file failed',
            context: {
              'bookId': normalizedBookId,
              'path': localBook.storagePath,
              'error': error.toString(),
            },
          );
        }
      }
      if (localBook.format == LocalBookFormat.epub) {
        final assetDir = EpubLocalBookParser.resolveAssetDirectory(localBook);
        if (await assetDir.exists()) {
          try {
            await assetDir.delete(recursive: true);
          } catch (error) {
            _logger.warn(
              'Delete local epub asset directory failed',
              context: {
                'bookId': normalizedBookId,
                'path': assetDir.path,
                'error': error.toString(),
              },
            );
          }
        }
      }
    }

    await _localBookRepository.deleteBook(normalizedBookId);
    await _bookshelfService.remove(
      sourceId: localBookSourceId,
      detailUrl: normalizedDetailUrl,
    );
  }

  Future<LocalBook?> _findBySourcePath(String sourcePath) async {
    final normalized = sourcePath.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final books = await _localBookRepository.getAllBooks();
    for (final book in books) {
      if (book.sourcePath == normalized) {
        return book;
      }
    }

    return null;
  }

  Future<Directory> _resolveStorageDirectory() async {
    final baseDir = await _supportDirectoryProvider();
    final storageDir = Directory(p.join(baseDir.path, 'local_books'));
    if (!await storageDir.exists()) {
      await storageDir.create(recursive: true);
    }
    return storageDir;
  }

  Future<_LocalStorageWriteResult> _copyIntoStorage({
    required File sourceFile,
    required File targetFile,
    required LocalBookFormat format,
    required String sourcePath,
    required String bookId,
  }) async {
    if (await targetFile.exists()) {
      await targetFile.delete();
    }

    if (format != LocalBookFormat.txt) {
      await sourceFile.copy(targetFile.path);
      final copiedStat = await targetFile.stat();
      return _LocalStorageWriteResult(storageStat: copiedStat);
    }

    final bytes = await sourceFile.readAsBytes();
    if (bytes.isEmpty) {
      await targetFile.writeAsBytes(const <int>[], flush: true);
      final emptyStat = await targetFile.stat();
      return _LocalStorageWriteResult(
        storageStat: emptyStat,
        normalizedCharset: 'utf-8',
        originalCharset: 'utf-8',
      );
    }

    try {
      final decoded = _textEncodingDetector.decodeBestEffort(bytes);
      final normalizedText = decoded.text.replaceFirst('\uFEFF', '');
      final normalizedBytes = utf8.encode(normalizedText);
      await targetFile.writeAsBytes(normalizedBytes, flush: true);
      final normalizedStat = await targetFile.stat();
      return _LocalStorageWriteResult(
        storageStat: normalizedStat,
        normalizedCharset: 'utf-8',
        originalCharset: decoded.charsetName,
        convertedToUtf8:
            decoded.charsetName != 'utf-8' ||
            decoded.bomLength > 0 ||
            decoded.fallbackUsed,
      );
    } catch (error) {
      _logger.warn(
        'Normalize local txt encoding failed, fallback to raw copy',
        context: <String, Object?>{
          'bookId': bookId,
          'sourcePath': sourcePath,
          'targetPath': targetFile.path,
          'error': error.toString(),
        },
      );
      await sourceFile.copy(targetFile.path);
      final copiedStat = await targetFile.stat();
      return _LocalStorageWriteResult(storageStat: copiedStat);
    }
  }

  String _buildBookId() {
    final raw = _uuid.v4().replaceAll('-', '');
    return 'local_$raw';
  }

  LocalBookFormat? _resolveFormat(String path) {
    final ext = p.extension(path).toLowerCase();
    return switch (ext) {
      '.txt' => LocalBookFormat.txt,
      '.epub' => LocalBookFormat.epub,
      _ => null,
    };
  }

  String _extensionForFormat(LocalBookFormat format) {
    return switch (format) {
      LocalBookFormat.txt => '.txt',
      LocalBookFormat.epub => '.epub',
    };
  }

  String _resolveTitle(String fileName) {
    final trimmed = fileName.trim();
    if (trimmed.isEmpty) {
      return '未命名本地书籍';
    }

    final dotIndex = trimmed.lastIndexOf('.');
    if (dotIndex <= 0) {
      return trimmed;
    }

    return trimmed.substring(0, dotIndex).trim();
  }
}

class _LocalStorageWriteResult {
  const _LocalStorageWriteResult({
    required this.storageStat,
    this.normalizedCharset,
    this.originalCharset,
    this.convertedToUtf8 = false,
  });

  final FileStat storageStat;
  final String? normalizedCharset;
  final String? originalCharset;
  final bool convertedToUtf8;
}
