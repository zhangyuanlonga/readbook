import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/logging/app_logger.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/repositories/local_book_repository.dart';
import '../../reader/application/reader_system_settings_service.dart';
import '../../reader/application/local/local_book_index_service.dart';
import '../../reader/application/local/local_book_storage_service.dart';
import '../../reader/application/local/local_book_workflow_policy.dart';
import '../../source/application/source_login_state_service.dart';
import 'bookshelf_service.dart';

class LocalBookImportResult {
  const LocalBookImportResult({
    required this.localBook,
    required this.bookshelfBook,
  });

  final LocalBook localBook;
  final BookshelfBook bookshelfBook;
}

enum LocalBookImportStage { preparing, persisted, indexing, completed }

class LocalBookImportProgress {
  const LocalBookImportProgress({
    required this.stage,
    required this.bookId,
    required this.displayName,
  });

  final LocalBookImportStage stage;
  final String bookId;
  final String displayName;
}

typedef LocalBookImportProgressCallback =
    void Function(LocalBookImportProgress progress);

class LocalBookImportService {
  LocalBookImportService({
    required LocalBookRepository localBookRepository,
    required BookshelfService bookshelfService,
    required ReaderSystemSettingsService readerSystemSettingsService,
    required LocalBookStorageService localBookStorageService,
    required AppLogger logger,
    required SourceLoginStateService sourceLoginStateService,
    LocalBookIndexService? localBookIndexService,
    Duration warmUpDelay = const Duration(milliseconds: 350),
  }) : _localBookRepository = localBookRepository,
       _bookshelfService = bookshelfService,
       _readerSystemSettingsService = readerSystemSettingsService,
       _localBookStorageService = localBookStorageService,
       _localBookIndexService =
           localBookIndexService ??
           LocalBookIndexService(
             localBookRepository: localBookRepository,
             readerSystemSettingsService: readerSystemSettingsService,
             storageService: localBookStorageService,
             logger: logger,
           ),
       _sourceLoginStateService = sourceLoginStateService,
       _logger = logger,
       _warmUpDelay = warmUpDelay;

  static const String localBookSourceId = '__local_book__';

  final LocalBookRepository _localBookRepository;
  final BookshelfService _bookshelfService;
  final ReaderSystemSettingsService _readerSystemSettingsService;
  final LocalBookIndexService _localBookIndexService;
  final SourceLoginStateService _sourceLoginStateService;
  final AppLogger _logger;
  final LocalBookStorageService _localBookStorageService;
  final Duration _warmUpDelay;
  final Uuid _uuid = const Uuid();

  Future<LocalBookImportResult> importFromFile({
    required String filePath,
    String? displayName,
    bool waitForIndexing = false,
    LocalBookImportProgressCallback? onProgress,
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
        briefMessage: '仅支持导入 txt、epub、md、html、pdf、mobi、azw 或 azw3 文件。',
      );
    }

    final sourceStat = await sourceFile.stat();
    final now = DateTime.now();
    final splitLongChapterDefault =
        await _readerSystemSettingsService
            .loadLocalTxtSplitLongChapterEnabled();
    final existingBook = await _findBySourcePath(normalizedPath);
    final bookId = existingBook?.id ?? _buildBookId();
    final normalizedDisplayName = normalizeImportedDisplayName(
      displayName ?? p.basename(normalizedPath),
    );
    onProgress?.call(
      LocalBookImportProgress(
        stage: LocalBookImportStage.preparing,
        bookId: bookId,
        displayName: normalizedDisplayName,
      ),
    );
    final storedStoragePath = _localBookStorageService.buildStoredStoragePath(
      bookId: bookId,
      format: format,
    );
    final prepared = await _prepareImportedBook(
      sourceFile: sourceFile,
      sourcePath: normalizedPath,
      displayName: displayName,
      format: format,
      sourceStat: sourceStat,
      now: now,
      splitLongChapterDefault: splitLongChapterDefault,
      existingBook: existingBook,
      bookId: bookId,
      storedStoragePath: storedStoragePath,
    );
    await _persistImportedBook(prepared.localBook);
    await _bookshelfService.upsert(prepared.bookshelfBook);
    onProgress?.call(
      LocalBookImportProgress(
        stage: LocalBookImportStage.persisted,
        bookId: bookId,
        displayName: normalizedDisplayName,
      ),
    );

    _logger.info(
      'Local book imported',
      context: {
        'bookId': bookId,
        'format': format.name,
        'indexExecutionMode':
            _resolveImportExecutionMode(
              format: format,
              waitForIndexingRequested: waitForIndexing,
            ).name,
        'sourcePath': normalizedPath,
        if (prepared.storageResult.originalCharset != null)
          'sourceCharset': prepared.storageResult.originalCharset,
        if (prepared.localBook.charset != null)
          'normalizedCharset': prepared.localBook.charset,
        'charsetConverted': prepared.storageResult.convertedToUtf8,
      },
    );

    final executionMode = _resolveImportExecutionMode(
      format: format,
      waitForIndexingRequested: waitForIndexing,
    );
    if (executionMode == LocalBookImportExecutionMode.immediateIndex) {
      onProgress?.call(
        LocalBookImportProgress(
          stage: LocalBookImportStage.indexing,
          bookId: bookId,
          displayName: normalizedDisplayName,
        ),
      );
      await _localBookIndexService.ensureIndexed(bookId: bookId);
      onProgress?.call(
        LocalBookImportProgress(
          stage: LocalBookImportStage.completed,
          bookId: bookId,
          displayName: normalizedDisplayName,
        ),
      );
    } else {
      unawaited(_warmUpLocalBookIndex(bookId));
    }

    return LocalBookImportResult(
      localBook: prepared.localBook,
      bookshelfBook: prepared.bookshelfBook,
    );
  }

  Future<void> _warmUpLocalBookIndex(String bookId) async {
    try {
      if (_warmUpDelay > Duration.zero) {
        await Future<void>.delayed(_warmUpDelay);
      }
      await _localBookIndexService.ensureIndexed(bookId: bookId);
    } catch (error) {
      if (_shouldIgnoreWarmUpError(error)) {
        return;
      }
      _logger.warn(
        'Warm up local book index failed',
        context: {'bookId': bookId, 'error': error.toString()},
      );
    }
  }

  LocalBookImportExecutionMode _resolveImportExecutionMode({
    required LocalBookFormat format,
    required bool waitForIndexingRequested,
  }) {
    return LocalBookWorkflowPolicy.resolveImportExecutionMode(
      format: format,
      waitForIndexingRequested: waitForIndexingRequested,
    );
  }

  bool _shouldIgnoreWarmUpError(Object error) {
    if (error is AppException) {
      final message = error.briefMessage.trim();
      if (message.contains('本地书籍文件已失效') || message.contains('未找到本地书籍')) {
        return true;
      }
    }

    final text = error.toString();
    if (text.contains("Can't re-open a database after closing it")) {
      return true;
    }
    return false;
  }

  Future<_PreparedImportedBook> _prepareImportedBook({
    required File sourceFile,
    required String sourcePath,
    required String? displayName,
    required LocalBookFormat format,
    required FileStat sourceStat,
    required DateTime now,
    required bool splitLongChapterDefault,
    required LocalBook? existingBook,
    required String bookId,
    required String storedStoragePath,
  }) async {
    final resolvedStoragePath = await _localBookStorageService
        .resolveStoragePath(storedStoragePath);
    final targetFile = File(resolvedStoragePath);
    final storageResult = await _localBookStorageService.copyIntoStorage(
      sourceFile: sourceFile,
      targetFile: targetFile,
      format: format,
      sourcePath: sourcePath,
      bookId: bookId,
    );
    final localBook = _buildImportedLocalBook(
      existingBook: existingBook,
      bookId: bookId,
      format: format,
      storedStoragePath: storedStoragePath,
      sourcePath: sourcePath,
      targetFile: targetFile,
      sourceStat: sourceStat,
      storageStat: storageResult.storageStat,
      normalizedCharset: storageResult.normalizedCharset,
      displayName: displayName,
      splitLongChapterDefault: splitLongChapterDefault,
      now: now,
    );
    return _PreparedImportedBook(
      localBook: localBook,
      bookshelfBook: _buildBookshelfBook(localBook, now: now),
      storageResult: storageResult,
    );
  }

  LocalBook _buildImportedLocalBook({
    required LocalBook? existingBook,
    required String bookId,
    required LocalBookFormat format,
    required String storedStoragePath,
    required String sourcePath,
    required File targetFile,
    required FileStat sourceStat,
    required FileStat storageStat,
    required String? normalizedCharset,
    required String? displayName,
    required bool splitLongChapterDefault,
    required DateTime now,
  }) {
    final recoverableSourcePath = _localBookStorageService
        .normalizeRecoverableSourcePath(sourcePath);
    final title = _resolveTitle(displayName ?? p.basename(sourcePath));
    return existingBook?.copyWith(
          title: title,
          format: format,
          storagePath: storedStoragePath,
          sourcePath: recoverableSourcePath,
          clearSourcePath: recoverableSourcePath == null,
          fileSize: storageStat.size,
          sourceFileSize: sourceStat.size,
          sourceFileLastModifiedMs: sourceStat.modified.millisecondsSinceEpoch,
          storageFileLastModifiedMs:
              storageStat.modified.millisecondsSinceEpoch,
          indexStatus: LocalBookIndexStatus.pending,
          chapterCount: 0,
          splitLongChapter: splitLongChapterDefault,
          updatedAt: now,
          charset: normalizedCharset,
          clearCharset: normalizedCharset == null,
          clearLastError: true,
        ) ??
        LocalBook(
          id: bookId,
          title: title,
          format: format,
          storagePath: storedStoragePath,
          sourcePath: recoverableSourcePath,
          fileSize: storageStat.size,
          sourceFileSize: sourceStat.size,
          sourceFileLastModifiedMs: sourceStat.modified.millisecondsSinceEpoch,
          storageFileLastModifiedMs:
              storageStat.modified.millisecondsSinceEpoch,
          indexStatus: LocalBookIndexStatus.pending,
          chapterCount: 0,
          splitLongChapter: splitLongChapterDefault,
          createdAt: now,
          updatedAt: now,
          charset: normalizedCharset,
          author: existingBook?.author,
          coverPath: existingBook?.coverPath,
        );
  }

  Future<void> _persistImportedBook(LocalBook localBook) async {
    await _localBookRepository.upsertBook(localBook);
    await _localBookRepository.replaceChapters(
      bookId: localBook.id,
      chapters: const [],
    );
    await _localBookRepository.updateBookIndexState(
      bookId: localBook.id,
      status: LocalBookIndexStatus.pending,
      chapterCount: 0,
      clearLastError: true,
    );
  }

  BookshelfBook _buildBookshelfBook(
    LocalBook localBook, {
    required DateTime now,
  }) {
    return BookshelfBook(
      bookId: localBook.id,
      sourceId: localBookSourceId,
      title: localBook.title,
      detailUrl: 'local://book/${localBook.id}',
      addedAt: now,
      author: localBook.author,
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
      await _localBookStorageService.deleteStoredBookArtifacts(localBook);
    }

    await _localBookRepository.deleteBook(normalizedBookId);
    await _sourceLoginStateService.removeBookCustomStatesForBook(
      normalizedBookId,
    );
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
    return _localBookRepository.getBookBySourcePath(normalized);
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
      '.md' => LocalBookFormat.md,
      '.markdown' => LocalBookFormat.md,
      '.html' => LocalBookFormat.html,
      '.htm' => LocalBookFormat.html,
      '.pdf' => LocalBookFormat.pdf,
      '.mobi' => LocalBookFormat.mobi,
      '.azw' => LocalBookFormat.azw,
      '.azw3' => LocalBookFormat.azw3,
      _ => null,
    };
  }

  String _resolveTitle(String fileName) {
    final trimmed = _normalizeImportedFileName(fileName);
    if (trimmed.isEmpty) {
      return '未命名本地书籍';
    }

    final dotIndex = trimmed.lastIndexOf('.');
    if (dotIndex <= 0) {
      return trimmed;
    }

    return trimmed.substring(0, dotIndex).trim();
  }

  static String normalizeImportedDisplayName(String rawName) {
    final normalized = _normalizeImportedFileName(rawName).trim();
    return normalized.isEmpty ? rawName.trim() : normalized;
  }

  static String _normalizeImportedFileName(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    final candidates = <String>[trimmed];
    final utf8Candidate = _tryRepairUtf8Mojibake(trimmed);
    if (utf8Candidate != null && utf8Candidate.trim().isNotEmpty) {
      candidates.add(utf8Candidate);
    }

    String best = trimmed;
    var bestScore = _scoreImportedFileName(trimmed);
    for (final candidate in candidates) {
      final score = _scoreImportedFileName(candidate);
      if (score > bestScore) {
        best = candidate;
        bestScore = score;
      }
    }
    return best;
  }

  static String? _tryRepairUtf8Mojibake(String value) {
    try {
      final repaired =
          utf8.decode(latin1.encode(value), allowMalformed: true).trim();
      return repaired.isEmpty ? null : repaired;
    } catch (_) {
      return null;
    }
  }

  static int _scoreImportedFileName(String value) {
    if (value.isEmpty) {
      return -9999;
    }
    var score = 0;
    for (final rune in value.runes) {
      if (rune >= 0x4E00 && rune <= 0x9FFF) {
        score += 8;
      } else if ((rune >= 0x30 && rune <= 0x39) ||
          (rune >= 0x41 && rune <= 0x5A) ||
          (rune >= 0x61 && rune <= 0x7A)) {
        score += 2;
      } else if (rune == 0xFFFD) {
        score -= 20;
      } else if (rune < 0x20) {
        score -= 10;
      } else if ('ÃÂâõðþÿ�'.contains(String.fromCharCode(rune))) {
        score -= 6;
      }
    }
    return score;
  }
}

class _PreparedImportedBook {
  const _PreparedImportedBook({
    required this.localBook,
    required this.bookshelfBook,
    required this.storageResult,
  });

  final LocalBook localBook;
  final BookshelfBook bookshelfBook;
  final LocalBookStorageWriteResult storageResult;
}
