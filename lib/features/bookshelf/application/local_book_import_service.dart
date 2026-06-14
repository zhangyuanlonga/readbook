import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/logging/app_logger.dart';
import '../../../domain/entities/book_identity.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/repositories/local_book_repository.dart';
import '../../reader/application/reader_system_settings_service.dart';
import '../../reader/application/local/local_book_index_service.dart';
import '../../reader/application/local/local_book_storage_service.dart';
import '../../reader/application/local/local_book_workflow_policy.dart';
import '../../source/application/external_import_catalog.dart';
import '../../source/application/external_source_import_bridge.dart';
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
    this.detail,
  });

  final LocalBookImportStage stage;
  final String bookId;
  final String displayName;
  final String? detail;
}

typedef LocalBookImportProgressCallback =
    void Function(LocalBookImportProgress progress);

class LocalBookImportBatchCandidate {
  const LocalBookImportBatchCandidate({
    required this.filePath,
    required this.displayName,
    this.mimeType,
  });

  final String filePath;
  final String displayName;
  final String? mimeType;
}

enum LocalBookImportDuplicateMatch { none, sourcePath, importFingerprint }

enum LocalBookImportDuplicateStrategy {
  replacePreservingUserState,
  skipExisting,
  keepBoth,
}

class LocalBookImportPrecheckResult {
  const LocalBookImportPrecheckResult({
    required this.filePath,
    required this.displayName,
    required this.exists,
    required this.readable,
    required this.format,
    required this.fileSize,
    required this.sourceFileLastModifiedMs,
    required this.duplicateMatch,
    this.mimeType,
    this.errorMessage,
    this.duplicateBook,
  });

  final String filePath;
  final String displayName;
  final String? mimeType;
  final bool exists;
  final bool readable;
  final LocalBookFormat? format;
  final int? fileSize;
  final int? sourceFileLastModifiedMs;
  final String? errorMessage;
  final LocalBook? duplicateBook;
  final LocalBookImportDuplicateMatch duplicateMatch;

  bool get isSupported => format != null;
  bool get isEmptyFile => fileSize == 0;
  bool get hasDuplicate => duplicateBook != null;
  bool get canImport => errorMessage == null;

  AppException toAppException() {
    return AppException(
      code: ErrorCode.validation,
      stage: ErrorStage.detail,
      briefMessage: errorMessage ?? '文件校验失败，请重新选择。',
    );
  }
}

enum LocalBookImportBatchStage {
  validating,
  queued,
  importing,
  completed,
  cancelled,
}

class LocalBookImportBatchProgress {
  const LocalBookImportBatchProgress({
    required this.stage,
    required this.completedCount,
    required this.totalCount,
    this.currentFileLabel,
    this.currentFileIndex,
    this.detail,
    this.importProgress,
  });

  final LocalBookImportBatchStage stage;
  final int completedCount;
  final int totalCount;
  final String? currentFileLabel;
  final int? currentFileIndex;
  final String? detail;
  final LocalBookImportProgress? importProgress;

  double? get progress => totalCount <= 0 ? null : completedCount / totalCount;
}

class LocalBookImportBatchSummary {
  const LocalBookImportBatchSummary({
    required this.successCount,
    required this.failureCount,
    required this.skippedCount,
    required this.totalCount,
    required this.cancelled,
    this.lastError,
    this.lastResult,
  });

  final int successCount;
  final int failureCount;
  final int skippedCount;
  final int totalCount;
  final bool cancelled;
  final String? lastError;
  final LocalBookImportResult? lastResult;

  int get completedCount => successCount + failureCount + skippedCount;
  bool get hasSuccess => successCount > 0;
}

typedef LocalBookImportBatchProgressCallback =
    void Function(LocalBookImportBatchProgress progress);

class LocalBookImportService {
  LocalBookImportService({
    required LocalBookRepository localBookRepository,
    required BookshelfService bookshelfService,
    required ReaderSystemSettingsService readerSystemSettingsService,
    required LocalBookStorageService localBookStorageService,
    required AppLogger logger,
    required LocalBookIndexService localBookIndexService,
    Duration warmUpDelay = const Duration(milliseconds: 350),
  }) : _localBookRepository = localBookRepository,
       _bookshelfService = bookshelfService,
       _readerSystemSettingsService = readerSystemSettingsService,
       _localBookStorageService = localBookStorageService,
       _localBookIndexService = localBookIndexService,
       _logger = logger,
       _warmUpDelay = warmUpDelay;

  static const String localBookSourceId = BookIdentityScheme.localSourceId;

  final LocalBookRepository _localBookRepository;
  final BookshelfService _bookshelfService;
  final ReaderSystemSettingsService _readerSystemSettingsService;
  final LocalBookIndexService _localBookIndexService;
  final AppLogger _logger;
  final LocalBookStorageService _localBookStorageService;
  final Duration _warmUpDelay;
  final Uuid _uuid = const Uuid();
  static const int _batchValidationConcurrency = 4;
  static const int _batchImportConcurrency = 1;

  Future<LocalBookImportPrecheckResult> inspectImportCandidate({
    required String filePath,
    String? displayName,
    String? mimeType,
  }) async {
    final normalizedPath = filePath.trim();
    final normalizedDisplayName = normalizeImportedDisplayName(
      (displayName?.trim().isNotEmpty ?? false)
          ? displayName!
          : p.basename(normalizedPath),
    );
    final normalizedMimeType = _normalizeOptionalText(mimeType);
    if (normalizedPath.isEmpty) {
      return LocalBookImportPrecheckResult(
        filePath: normalizedPath,
        displayName: normalizedDisplayName,
        mimeType: normalizedMimeType,
        exists: false,
        readable: false,
        format: null,
        fileSize: null,
        sourceFileLastModifiedMs: null,
        duplicateMatch: LocalBookImportDuplicateMatch.none,
        errorMessage: '文件路径不能为空。',
      );
    }

    final format = _resolveFormat(
      normalizedPath,
      displayName: normalizedDisplayName,
      mimeType: normalizedMimeType,
    );
    if (format == null) {
      final unsupportedStat = await _statOrNull(File(normalizedPath));
      return LocalBookImportPrecheckResult(
        filePath: normalizedPath,
        displayName: normalizedDisplayName,
        mimeType: normalizedMimeType,
        exists: unsupportedStat != null,
        readable: false,
        format: null,
        fileSize: unsupportedStat?.size,
        sourceFileLastModifiedMs:
            unsupportedStat?.modified.millisecondsSinceEpoch,
        duplicateMatch: LocalBookImportDuplicateMatch.none,
        errorMessage: ExternalImportCatalog.unsupportedFileMessage(
          ExternalImportPayloadType.localBook,
          normalizedDisplayName,
        ),
      );
    }

    final sourceFile = File(normalizedPath);
    FileStat? sourceStat;
    try {
      if (!await sourceFile.exists()) {
        return LocalBookImportPrecheckResult(
          filePath: normalizedPath,
          displayName: normalizedDisplayName,
          mimeType: normalizedMimeType,
          exists: false,
          readable: false,
          format: format,
          fileSize: null,
          sourceFileLastModifiedMs: null,
          duplicateMatch: LocalBookImportDuplicateMatch.none,
          errorMessage: '本地文件不存在，请重新选择：$normalizedDisplayName',
        );
      }
      sourceStat = await sourceFile.stat();
    } on FileSystemException {
      return LocalBookImportPrecheckResult(
        filePath: normalizedPath,
        displayName: normalizedDisplayName,
        mimeType: normalizedMimeType,
        exists: false,
        readable: false,
        format: format,
        fileSize: null,
        sourceFileLastModifiedMs: null,
        duplicateMatch: LocalBookImportDuplicateMatch.none,
        errorMessage: '无法访问本地文件，请检查权限后重试：$normalizedDisplayName',
      );
    }

    if (sourceStat.type == FileSystemEntityType.directory) {
      return LocalBookImportPrecheckResult(
        filePath: normalizedPath,
        displayName: normalizedDisplayName,
        mimeType: normalizedMimeType,
        exists: true,
        readable: false,
        format: format,
        fileSize: sourceStat.size,
        sourceFileLastModifiedMs: sourceStat.modified.millisecondsSinceEpoch,
        duplicateMatch: LocalBookImportDuplicateMatch.none,
        errorMessage: '请选择具体文件，不支持直接导入文件夹：$normalizedDisplayName',
      );
    }

    final readable = await _canOpenForRead(sourceFile);
    if (!readable) {
      return LocalBookImportPrecheckResult(
        filePath: normalizedPath,
        displayName: normalizedDisplayName,
        mimeType: normalizedMimeType,
        exists: true,
        readable: false,
        format: format,
        fileSize: sourceStat.size,
        sourceFileLastModifiedMs: sourceStat.modified.millisecondsSinceEpoch,
        duplicateMatch: LocalBookImportDuplicateMatch.none,
        errorMessage: '文件不可读，请检查文件权限或重新选择：$normalizedDisplayName',
      );
    }

    if (sourceStat.size <= 0) {
      return LocalBookImportPrecheckResult(
        filePath: normalizedPath,
        displayName: normalizedDisplayName,
        mimeType: normalizedMimeType,
        exists: true,
        readable: true,
        format: format,
        fileSize: sourceStat.size,
        sourceFileLastModifiedMs: sourceStat.modified.millisecondsSinceEpoch,
        duplicateMatch: LocalBookImportDuplicateMatch.none,
        errorMessage: '文件内容为空，无法导入：$normalizedDisplayName',
      );
    }

    final title = _resolveTitle(normalizedDisplayName);
    final sourcePathDuplicate = await _findBySourcePath(normalizedPath);
    final fingerprintDuplicate =
        sourcePathDuplicate == null
            ? await _findByImportFingerprint(
              format: format,
              title: title,
              sourceFileSize: sourceStat.size,
            )
            : null;
    final duplicateBook = sourcePathDuplicate ?? fingerprintDuplicate;
    final duplicateMatch =
        sourcePathDuplicate != null
            ? LocalBookImportDuplicateMatch.sourcePath
            : fingerprintDuplicate != null
            ? LocalBookImportDuplicateMatch.importFingerprint
            : LocalBookImportDuplicateMatch.none;

    return LocalBookImportPrecheckResult(
      filePath: normalizedPath,
      displayName: normalizedDisplayName,
      mimeType: normalizedMimeType,
      exists: true,
      readable: true,
      format: format,
      fileSize: sourceStat.size,
      sourceFileLastModifiedMs: sourceStat.modified.millisecondsSinceEpoch,
      duplicateBook: duplicateBook,
      duplicateMatch: duplicateMatch,
    );
  }

  Future<LocalBookImportResult> importFromFile({
    required String filePath,
    String? displayName,
    String? mimeType,
    bool waitForIndexing = false,
    LocalBookImportDuplicateStrategy duplicateStrategy =
        LocalBookImportDuplicateStrategy.replacePreservingUserState,
    LocalBookImportProgressCallback? onProgress,
  }) async {
    final precheck = await inspectImportCandidate(
      filePath: filePath,
      displayName: displayName,
      mimeType: mimeType,
    );
    if (!precheck.canImport) {
      throw precheck.toAppException();
    }

    if (duplicateStrategy == LocalBookImportDuplicateStrategy.skipExisting &&
        precheck.duplicateBook != null) {
      final existingBook = precheck.duplicateBook!;
      return LocalBookImportResult(
        localBook: existingBook,
        bookshelfBook: _buildBookshelfBook(existingBook, now: DateTime.now()),
      );
    }

    final normalizedPath = precheck.filePath;
    final normalizedDisplayName = precheck.displayName;
    final sourceFile = File(normalizedPath);
    final format = precheck.format!;
    final sourceStat = await sourceFile.stat();
    final now = DateTime.now();
    final splitLongChapterDefault =
        await _readerSystemSettingsService
            .loadLocalTxtSplitLongChapterEnabled();
    final resolvedTitle = _resolveTitle(normalizedDisplayName);
    final existingBook =
        duplicateStrategy == LocalBookImportDuplicateStrategy.keepBoth
            ? null
            : precheck.duplicateBook;
    final bookId = existingBook?.id ?? _buildBookId();
    onProgress?.call(
      LocalBookImportProgress(
        stage: LocalBookImportStage.preparing,
        bookId: bookId,
        displayName: normalizedDisplayName,
        detail: _preparingDetailForFormat(format, sourceStat.size),
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
      title: resolvedTitle,
    );
    await _persistImportedBook(prepared.localBook);
    await _persistImportedBookshelfBook(
      bookshelfBook: prepared.bookshelfBook,
      existingBook: existingBook,
    );
    onProgress?.call(
      LocalBookImportProgress(
        stage: LocalBookImportStage.persisted,
        bookId: bookId,
        displayName: normalizedDisplayName,
        detail: '已写入书架，准备建立目录',
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
          detail: _indexingDetailForFormat(format),
        ),
      );
      await _localBookIndexService.ensureIndexed(bookId: bookId);
      onProgress?.call(
        LocalBookImportProgress(
          stage: LocalBookImportStage.completed,
          bookId: bookId,
          displayName: normalizedDisplayName,
          detail: '目录已建立，可直接阅读',
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

  Future<LocalBookImportBatchSummary> importFromFiles({
    required Iterable<LocalBookImportBatchCandidate> candidates,
    bool waitForIndexing = false,
    LocalBookImportBatchProgressCallback? onProgress,
    bool Function()? shouldCancel,
  }) async {
    final importCandidates = candidates
        .where((candidate) => candidate.filePath.trim().isNotEmpty)
        .toList(growable: false);
    if (importCandidates.isEmpty) {
      return const LocalBookImportBatchSummary(
        successCount: 0,
        failureCount: 0,
        skippedCount: 0,
        totalCount: 0,
        cancelled: false,
      );
    }

    onProgress?.call(
      LocalBookImportBatchProgress(
        stage: LocalBookImportBatchStage.validating,
        completedCount: 0,
        totalCount: importCandidates.length,
        detail: '正在校验文件并规划导入顺序',
      ),
    );
    final plannedItems = await _planBatchImport(importCandidates);
    onProgress?.call(
      LocalBookImportBatchProgress(
        stage: LocalBookImportBatchStage.queued,
        completedCount: 0,
        totalCount: plannedItems.length,
        currentFileLabel:
            plannedItems.isEmpty ? null : plannedItems.first.displayName,
        currentFileIndex: plannedItems.isEmpty ? null : 1,
        detail: '已按格式和文件大小排队，小文件会优先写入书架',
      ),
    );

    var successCount = 0;
    var failureCount = 0;
    var skippedCount = 0;
    var cancelled = false;
    String? lastError;
    LocalBookImportResult? lastResult;
    final importPool = Pool(
      _batchImportConcurrency,
      timeout: const Duration(minutes: 10),
    );
    try {
      for (var index = 0; index < plannedItems.length; index += 1) {
        final item = plannedItems[index];
        if (shouldCancel?.call() ?? false) {
          cancelled = true;
          break;
        }
        if (!item.canImport) {
          skippedCount += 1;
          lastError = item.errorMessage ?? '文件校验失败：${item.displayName}';
          onProgress?.call(
            LocalBookImportBatchProgress(
              stage: LocalBookImportBatchStage.importing,
              completedCount: successCount + failureCount + skippedCount,
              totalCount: plannedItems.length,
              currentFileLabel: item.displayName,
              currentFileIndex: index + 1,
              detail: lastError,
            ),
          );
          continue;
        }

        onProgress?.call(
          LocalBookImportBatchProgress(
            stage: LocalBookImportBatchStage.importing,
            completedCount: successCount + failureCount + skippedCount,
            totalCount: plannedItems.length,
            currentFileLabel: item.displayName,
            currentFileIndex: index + 1,
            detail: '正在写入书架，后台会继续解析目录',
          ),
        );
        try {
          final result = await importPool.withResource(
            () => importFromFile(
              filePath: item.filePath,
              displayName: item.displayName,
              mimeType: item.mimeType,
              waitForIndexing: waitForIndexing,
              onProgress: (progress) {
                onProgress?.call(
                  LocalBookImportBatchProgress(
                    stage: LocalBookImportBatchStage.importing,
                    completedCount: successCount + failureCount + skippedCount,
                    totalCount: plannedItems.length,
                    currentFileLabel: progress.displayName,
                    currentFileIndex: index + 1,
                    detail: progress.detail,
                    importProgress: progress,
                  ),
                );
              },
            ),
          );
          successCount += 1;
          lastResult = result;
        } catch (error) {
          failureCount += 1;
          lastError = _formatBatchImportError(error);
        }
      }
    } finally {
      await importPool.close();
    }

    onProgress?.call(
      LocalBookImportBatchProgress(
        stage:
            cancelled
                ? LocalBookImportBatchStage.cancelled
                : LocalBookImportBatchStage.completed,
        completedCount: successCount + failureCount + skippedCount,
        totalCount: plannedItems.length,
        currentFileLabel: lastResult?.localBook.title,
        detail:
            cancelled ? '已取消排队中的导入，已写入书架的图书会继续后台解析' : '批量导入完成，成功导入的图书会继续后台解析',
      ),
    );
    return LocalBookImportBatchSummary(
      successCount: successCount,
      failureCount: failureCount,
      skippedCount: skippedCount,
      totalCount: plannedItems.length,
      cancelled: cancelled,
      lastError: lastError,
      lastResult: lastResult,
    );
  }

  Future<List<_LocalBookImportBatchPlanItem>> _planBatchImport(
    List<LocalBookImportBatchCandidate> candidates,
  ) async {
    final validationPool = Pool(
      _batchValidationConcurrency,
      timeout: const Duration(minutes: 2),
    );
    try {
      final plannedItems = await Future.wait(
        candidates.map(
          (candidate) => validationPool.withResource(
            () => _inspectBatchImportCandidate(candidate),
          ),
        ),
      );
      final sorted = plannedItems.toList(growable: false);
      sorted.sort(_compareBatchImportPlanItems);
      return sorted;
    } finally {
      await validationPool.close();
    }
  }

  Future<_LocalBookImportBatchPlanItem> _inspectBatchImportCandidate(
    LocalBookImportBatchCandidate candidate,
  ) async {
    final precheck = await inspectImportCandidate(
      filePath: candidate.filePath,
      displayName: candidate.displayName,
      mimeType: candidate.mimeType,
    );
    return _LocalBookImportBatchPlanItem(
      filePath: precheck.filePath,
      displayName: precheck.displayName,
      mimeType: precheck.mimeType,
      format: precheck.format,
      fileSize: precheck.fileSize,
      canImport: precheck.canImport,
      errorMessage: precheck.errorMessage,
    );
  }

  int _compareBatchImportPlanItems(
    _LocalBookImportBatchPlanItem a,
    _LocalBookImportBatchPlanItem b,
  ) {
    final supportedCompare = _supportRank(a).compareTo(_supportRank(b));
    if (supportedCompare != 0) {
      return supportedCompare;
    }
    final formatCompare = _batchFormatRank(
      a.format,
    ).compareTo(_batchFormatRank(b.format));
    if (formatCompare != 0) {
      return formatCompare;
    }
    final sizeCompare = (a.fileSize ?? 0).compareTo(b.fileSize ?? 0);
    if (sizeCompare != 0) {
      return sizeCompare;
    }
    return a.displayName.compareTo(b.displayName);
  }

  int _supportRank(_LocalBookImportBatchPlanItem item) {
    if (item.format == null) {
      return 1;
    }
    if (!item.canImport) {
      return 2;
    }
    return 0;
  }

  int _batchFormatRank(LocalBookFormat? format) {
    return switch (format) {
      LocalBookFormat.txt => 0,
      LocalBookFormat.md || LocalBookFormat.html => 1,
      LocalBookFormat.epub => 2,
      LocalBookFormat.pdf => 3,
      LocalBookFormat.mobi || LocalBookFormat.azw || LocalBookFormat.azw3 => 4,
      null => 5,
    };
  }

  String _formatBatchImportError(Object error) {
    return switch (error) {
      AppException() => error.briefMessage,
      _ => '导入失败：$error',
    };
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

  String _indexingDetailForFormat(LocalBookFormat format) {
    return switch (format) {
      LocalBookFormat.epub => '正在解析图文结构、提取资源并建立目录',
      LocalBookFormat.html => '正在解析 HTML 结构、处理图片并建立目录',
      LocalBookFormat.md => '正在解析 Markdown、转换图文结构并建立目录',
      LocalBookFormat.pdf => '正在建立 PDF 页面索引，正文将在阅读时按需提取',
      LocalBookFormat.mobi ||
      LocalBookFormat.azw ||
      LocalBookFormat.azw3 => '正在解析电子书内容并建立目录',
      LocalBookFormat.txt => '正在切分章节并建立目录',
    };
  }

  String _preparingDetailForFormat(LocalBookFormat format, int fileSize) {
    final sizeText = _formatFileSize(fileSize);
    return switch (format) {
      LocalBookFormat.epub => '正在复制 EPUB 到应用存储$sizeText，目录会在后台继续解析',
      LocalBookFormat.pdf => '正在复制 PDF 到应用存储$sizeText，页面索引会在后台继续建立',
      LocalBookFormat.mobi ||
      LocalBookFormat.azw ||
      LocalBookFormat.azw3 => '正在复制电子书到应用存储$sizeText，目录会在后台继续解析',
      LocalBookFormat.md || LocalBookFormat.html => '正在复制图文文件到应用存储$sizeText',
      LocalBookFormat.txt => '正在识别文本编码并写入应用存储$sizeText',
    };
  }

  String _formatFileSize(int fileSize) {
    if (fileSize <= 0) {
      return '';
    }
    final sizeMb = fileSize / (1024 * 1024);
    if (sizeMb >= 1) {
      return '（${sizeMb.toStringAsFixed(sizeMb >= 10 ? 0 : 1)} MB）';
    }
    final sizeKb = fileSize / 1024;
    return '（${sizeKb.toStringAsFixed(sizeKb >= 10 ? 0 : 1)} KB）';
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
    required String title,
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
      title: title,
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
    required String title,
    required bool splitLongChapterDefault,
    required DateTime now,
  }) {
    final recoverableSourcePath = _localBookStorageService
        .normalizeRecoverableSourcePath(sourcePath);
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

  Future<void> _persistImportedBookshelfBook({
    required BookshelfBook bookshelfBook,
    required LocalBook? existingBook,
  }) async {
    if (existingBook == null) {
      await _bookshelfService.upsert(bookshelfBook);
      return;
    }

    await _bookshelfService.replace(
      previousSourceId: localBookSourceId,
      previousDetailUrl: buildLocalBookDetailUrl(existingBook.id),
      nextBook: bookshelfBook,
      preserveTags: true,
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
      detailUrl: buildLocalBookDetailUrl(localBook.id),
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

  Future<LocalBook?> _findByImportFingerprint({
    required LocalBookFormat format,
    required String title,
    required int sourceFileSize,
  }) {
    return _localBookRepository.findBookByImportFingerprint(
      format: format,
      title: title,
      sourceFileSize: sourceFileSize,
    );
  }

  String _buildBookId() {
    final raw = _uuid.v4().replaceAll('-', '');
    return 'local_$raw';
  }

  Future<bool> _canOpenForRead(File file) async {
    RandomAccessFile? opened;
    try {
      opened = await file.open(mode: FileMode.read);
      return true;
    } on FileSystemException {
      return false;
    } finally {
      await opened?.close();
    }
  }

  Future<FileStat?> _statOrNull(File file) async {
    try {
      if (!await file.exists()) {
        return null;
      }
      return file.stat();
    } on FileSystemException {
      return null;
    }
  }

  String? _normalizeOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  LocalBookFormat? _resolveFormat(
    String path, {
    String? displayName,
    String? mimeType,
  }) {
    final labels = <String>[
      if (displayName?.trim().isNotEmpty ?? false) displayName!.trim(),
      path,
      p.basename(path),
    ];
    final supportedByLabel = labels.any(
      (label) => ExternalImportCatalog.supportsFileLabel(
        ExternalImportPayloadType.localBook,
        label,
      ),
    );
    final supportedByMime = ExternalImportCatalog.supportsMimeType(
      ExternalImportPayloadType.localBook,
      mimeType,
    );
    if (!supportedByLabel && !supportedByMime) {
      return null;
    }

    for (final label in labels) {
      final format = _resolveFormatByExtension(p.extension(label));
      if (format != null) {
        return format;
      }
    }
    return _resolveFormatByMimeType(mimeType);
  }

  LocalBookFormat? _resolveFormatByExtension(String extension) {
    final ext = extension.toLowerCase();
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

  LocalBookFormat? _resolveFormatByMimeType(String? mimeType) {
    final normalized = mimeType?.trim().toLowerCase();
    return switch (normalized) {
      'text/plain' => LocalBookFormat.txt,
      'application/epub+zip' => LocalBookFormat.epub,
      'text/markdown' || 'text/x-markdown' => LocalBookFormat.md,
      'text/html' => LocalBookFormat.html,
      'application/pdf' => LocalBookFormat.pdf,
      'application/x-mobipocket-ebook' => LocalBookFormat.mobi,
      'application/vnd.amazon.ebook' => LocalBookFormat.azw,
      'application/vnd.amazon.mobi8-ebook' => LocalBookFormat.azw3,
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

class _LocalBookImportBatchPlanItem {
  const _LocalBookImportBatchPlanItem({
    required this.filePath,
    required this.displayName,
    required this.mimeType,
    required this.format,
    required this.fileSize,
    required this.canImport,
    required this.errorMessage,
  });

  final String filePath;
  final String displayName;
  final String? mimeType;
  final LocalBookFormat? format;
  final int? fileSize;
  final bool canImport;
  final String? errorMessage;
}
