import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../domain/entities/local_book.dart';
import 'local_text_encoding_detector.dart';

class LocalBookStorageWriteResult {
  const LocalBookStorageWriteResult({
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

class LocalBookStorageRestoreResult {
  const LocalBookStorageRestoreResult({
    required this.book,
    required this.shouldReindex,
    this.sourceChanged = false,
    this.storageRestored = false,
  });

  final LocalBook book;
  final bool shouldReindex;
  final bool sourceChanged;
  final bool storageRestored;
}

class _EncodingSampleChunk {
  const _EncodingSampleChunk({required this.start, required this.bytes});

  final int start;
  final List<int> bytes;
}

class LocalBookStorageService {
  LocalBookStorageService({
    LocalTextEncodingDetector? textEncodingDetector,
    AppLogger? logger,
    Future<Directory> Function()? supportDirectoryProvider,
  }) : _textEncodingDetector =
           textEncodingDetector ?? const LocalTextEncodingDetector(),
       _logger = logger ?? AppLogger.instance,
       _supportDirectoryProvider =
           supportDirectoryProvider ?? getApplicationSupportDirectory;

  final LocalTextEncodingDetector _textEncodingDetector;
  final AppLogger _logger;
  final Future<Directory> Function() _supportDirectoryProvider;
  static const int _largeTxtRawCopyThresholdBytes = 1024 * 1024;
  static const int _encodingSampleBytes = 24000;

  String buildStoredStoragePath({
    required String bookId,
    required LocalBookFormat format,
  }) {
    return p.posix.join('local_books', '$bookId${_extensionForFormat(format)}');
  }

  Future<File> resolveStorageFile(LocalBook book) async {
    return File(await resolveStoragePath(book.storagePath));
  }

  Future<String> resolveStoragePath(String storedPath) async {
    final normalized = storedPath.trim();
    if (normalized.isEmpty) {
      return normalized;
    }
    final baseDir = await _supportDirectoryProvider();
    final relative = _extractManagedRelativePath(normalized);
    if (relative != null) {
      return p.join(baseDir.path, relative);
    }
    if (p.isAbsolute(normalized)) {
      return normalized;
    }
    return p.join(baseDir.path, normalized);
  }

  String? normalizeRecoverableSourcePath(String sourcePath) {
    final normalized = sourcePath.trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (_isEphemeralSourcePath(normalized)) {
      return null;
    }
    return normalized;
  }

  Future<Directory> resolveStorageDirectory() async {
    final baseDir = await _supportDirectoryProvider();
    final storageDir = Directory(p.join(baseDir.path, 'local_books'));
    if (!await storageDir.exists()) {
      await storageDir.create(recursive: true);
    }
    return storageDir;
  }

  Future<LocalBookStorageWriteResult> copyIntoStorage({
    required File sourceFile,
    required File targetFile,
    required LocalBookFormat format,
    required String sourcePath,
    required String bookId,
    String? preferredCharset,
  }) async {
    File effectiveSourceFile = sourceFile;
    File? tempSourceFile;
    final normalizedSourcePath =
        sourcePath.trim().isEmpty ? sourceFile.path : sourcePath.trim();
    final targetPath = targetFile.path;
    final isSamePath = p.equals(
      p.normalize(normalizedSourcePath),
      p.normalize(targetPath),
    );

    if (isSamePath) {
      final tempPath =
          '${targetFile.path}.reencode_${DateTime.now().microsecondsSinceEpoch}.tmp';
      tempSourceFile = File(tempPath);
      await sourceFile.copy(tempSourceFile.path);
      effectiveSourceFile = tempSourceFile;
    }

    try {
      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      if (format != LocalBookFormat.txt) {
        await _ensureParentDir(targetFile);
        final movedStat = await _moveEphemeralSourceIntoStorageIfPossible(
          sourceFile: effectiveSourceFile,
          targetFile: targetFile,
          sourcePath: normalizedSourcePath,
          bookId: bookId,
          format: format,
        );
        if (movedStat != null) {
          return LocalBookStorageWriteResult(storageStat: movedStat);
        }
        await effectiveSourceFile.copy(targetFile.path);
        final copiedStat = await targetFile.stat();
        return LocalBookStorageWriteResult(storageStat: copiedStat);
      }

      final fileLength = await effectiveSourceFile.length();
      if (fileLength == 0) {
        await targetFile.writeAsBytes(const <int>[], flush: true);
        final emptyStat = await targetFile.stat();
        return LocalBookStorageWriteResult(
          storageStat: emptyStat,
          normalizedCharset: 'utf-8',
          originalCharset: 'utf-8',
        );
      }

      final normalizedPreferredCharset =
          LocalTextEncodingDetector.normalizeCharsetName(preferredCharset);
      if (normalizedPreferredCharset != null) {
        final copiedStat = await _copyTxtRawBytesIntoStorage(
          sourceFile: effectiveSourceFile,
          targetFile: targetFile,
        );
        return LocalBookStorageWriteResult(
          storageStat: copiedStat,
          normalizedCharset: normalizedPreferredCharset,
          originalCharset: normalizedPreferredCharset,
          convertedToUtf8: false,
        );
      }

      final sample = await _detectEncodingFromSamples(effectiveSourceFile);
      try {
        final detectedCharset = await _resolveStoredTxtCharset(
          file: effectiveSourceFile,
          fileLength: fileLength,
          sampledResult: sample,
        );
        final copiedStat = await _copyTxtRawBytesIntoStorage(
          sourceFile: effectiveSourceFile,
          targetFile: targetFile,
        );
        return LocalBookStorageWriteResult(
          storageStat: copiedStat,
          normalizedCharset: detectedCharset,
          originalCharset: detectedCharset,
          convertedToUtf8: false,
        );
      } catch (error) {
        _logger.warn(
          'Resolve local txt charset failed, fallback to raw copy',
          context: <String, Object?>{
            'bookId': bookId,
            'sourcePath': normalizedSourcePath,
            'targetPath': targetFile.path,
            'error': error.toString(),
          },
        );
        final copiedStat = await _copyTxtRawBytesIntoStorage(
          sourceFile: effectiveSourceFile,
          targetFile: targetFile,
        );
        return LocalBookStorageWriteResult(storageStat: copiedStat);
      }
    } finally {
      if (tempSourceFile != null && await tempSourceFile.exists()) {
        try {
          await tempSourceFile.delete();
        } catch (_) {
          // Ignore temporary cleanup failure.
        }
      }
    }
  }

  Future<FileStat> _copyTxtRawBytesIntoStorage({
    required File sourceFile,
    required File targetFile,
  }) async {
    await _ensureParentDir(targetFile);
    await sourceFile.copy(targetFile.path);
    return targetFile.stat();
  }

  Future<FileStat?> _moveEphemeralSourceIntoStorageIfPossible({
    required File sourceFile,
    required File targetFile,
    required String sourcePath,
    required String bookId,
    required LocalBookFormat format,
  }) async {
    if (!_isEphemeralSourcePath(sourcePath)) {
      return null;
    }
    try {
      final movedFile = await sourceFile.rename(targetFile.path);
      final movedStat = await movedFile.stat();
      _logger.info(
        'Moved cached local book into managed storage',
        context: <String, Object?>{
          'bookId': bookId,
          'format': format.name,
          'size': movedStat.size,
        },
      );
      return movedStat;
    } on FileSystemException catch (error) {
      _logger.debug(
        'Move cached local book failed, fallback to copy',
        context: <String, Object?>{
          'bookId': bookId,
          'format': format.name,
          'sourcePath': sourcePath,
          'targetPath': targetFile.path,
          'error': error.toString(),
        },
      );
      return null;
    }
  }

  Future<String?> _resolveStoredTxtCharset({
    required File file,
    required int fileLength,
    required LocalTextDecodeResult? sampledResult,
  }) async {
    final sampledCharset = sampledResult?.charsetName;
    if (sampledCharset != null && sampledCharset.isNotEmpty) {
      return sampledCharset;
    }

    if (fileLength >= _largeTxtRawCopyThresholdBytes) {
      return null;
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      return 'utf-8';
    }

    final decoded = _textEncodingDetector.decodeBestEffort(bytes);
    final charset = decoded.charsetName.trim();
    if (charset.isNotEmpty) {
      return charset;
    }

    final asyncDecoded = await _textEncodingDetector.decodeBestEffortAsync(
      bytes,
    );
    final asyncCharset = asyncDecoded.charsetName.trim();
    return asyncCharset.isEmpty ? null : asyncCharset;
  }

  Future<List<_EncodingSampleChunk>> _readEncodingSamples(File file) async {
    final fileLength = await file.length();
    if (fileLength == 0) {
      return const <_EncodingSampleChunk>[];
    }
    final sampleLength =
        fileLength < _encodingSampleBytes ? fileLength : _encodingSampleBytes;
    if (sampleLength <= 0) {
      return const <_EncodingSampleChunk>[];
    }
    final ranges = <(int, int)>[(0, sampleLength)];
    if (fileLength > sampleLength * 2) {
      final middleStart = ((fileLength - sampleLength) ~/ 2).clamp(
        0,
        fileLength - sampleLength,
      );
      ranges.add((middleStart, sampleLength));
    }
    if (fileLength > sampleLength * 3) {
      final tailStart = (fileLength - sampleLength).clamp(
        0,
        fileLength - sampleLength,
      );
      ranges.add((tailStart, sampleLength));
    }

    final uniqueRanges = <String, (int, int)>{};
    for (final range in ranges) {
      uniqueRanges['${range.$1}:${range.$2}'] = range;
    }

    final chunks = <_EncodingSampleChunk>[];
    for (final range in uniqueRanges.values) {
      final builder = BytesBuilder(copy: false);
      await file.openRead(range.$1, range.$1 + range.$2).forEach(builder.add);
      final bytes = builder.takeBytes();
      if (bytes.isEmpty) {
        continue;
      }
      chunks.add(_EncodingSampleChunk(start: range.$1, bytes: bytes));
    }
    return chunks;
  }

  Future<LocalTextDecodeResult?> _detectEncodingFromSamples(File file) async {
    final sampleChunks = await _readEncodingSamples(file);
    if (sampleChunks.isEmpty) {
      return null;
    }
    final fileLength = await file.length();
    return _textEncodingDetector.decodeBestEffortFromSamples(
      sampleChunks.map(
        (chunk) =>
            LocalTextDecodeSample(start: chunk.start, bytes: chunk.bytes),
      ),
      totalBytes: fileLength,
    );
  }

  Future<void> _ensureParentDir(File target) async {
    final parentDir = target.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }
  }

  Future<LocalBookStorageRestoreResult> restoreStorageFromSourceIfNeeded(
    LocalBook book,
  ) async {
    var nextBook = book;
    var shouldReindex = false;
    var sourceChanged = false;
    var storageRestored = false;

    final normalizedStoredStoragePath =
        _extractManagedRelativePath(book.storagePath) ??
        book.storagePath.trim();
    if (normalizedStoredStoragePath.isNotEmpty &&
        normalizedStoredStoragePath != book.storagePath) {
      nextBook = nextBook.copyWith(storagePath: normalizedStoredStoragePath);
    }

    final normalizedSourcePath = (book.sourcePath ?? '').trim();
    if (normalizedSourcePath.isNotEmpty) {
      final sourceFile = File(normalizedSourcePath);
      if (await sourceFile.exists()) {
        final storageFile = await resolveStorageFile(nextBook);
        final storageExists = await storageFile.exists();
        final sourceStat = await sourceFile.stat();
        final sourceModifiedMs = sourceStat.modified.millisecondsSinceEpoch;
        sourceChanged =
            book.sourceFileSize != sourceStat.size ||
            book.sourceFileLastModifiedMs != sourceModifiedMs;

        if (!storageExists || sourceChanged) {
          if (storageExists) {
            await storageFile.delete();
          }
          await copyIntoStorage(
            sourceFile: sourceFile,
            targetFile: storageFile,
            format: book.format,
            sourcePath: normalizedSourcePath,
            bookId: book.id,
            preferredCharset: null,
          );
          shouldReindex = true;
          storageRestored = !storageExists;
        }

        final storageStat = await _statOrNull(storageFile);
        nextBook = nextBook.copyWith(
          fileSize: storageStat?.size ?? sourceStat.size,
          sourceFileSize: sourceStat.size,
          sourceFileLastModifiedMs: sourceModifiedMs,
          storageFileLastModifiedMs:
              storageStat?.modified.millisecondsSinceEpoch ??
              nextBook.storageFileLastModifiedMs,
          updatedAt: sourceChanged ? DateTime.now() : nextBook.updatedAt,
        );
      }
    }

    final storageFile = await resolveStorageFile(nextBook);
    final storageStat = await _statOrNull(storageFile);
    if (storageStat == null) {
      final sourceUnavailable =
          normalizedSourcePath.isEmpty ||
          _isEphemeralSourcePath(normalizedSourcePath) ||
          !await File(normalizedSourcePath).exists();
      if (sourceUnavailable) {
        return LocalBookStorageRestoreResult(
          book: nextBook,
          shouldReindex: true,
          sourceChanged: sourceChanged,
          storageRestored: storageRestored,
        );
      }
      return LocalBookStorageRestoreResult(
        book: nextBook,
        shouldReindex: true,
        sourceChanged: sourceChanged,
        storageRestored: storageRestored,
      );
    }

    final storageModifiedMs = storageStat.modified.millisecondsSinceEpoch;
    final storageChanged =
        nextBook.fileSize != storageStat.size ||
        nextBook.storageFileLastModifiedMs != storageModifiedMs;
    if (storageChanged) {
      nextBook = nextBook.copyWith(
        fileSize: storageStat.size,
        storageFileLastModifiedMs: storageModifiedMs,
        updatedAt: DateTime.now(),
      );
      shouldReindex = true;
    }

    return LocalBookStorageRestoreResult(
      book: nextBook,
      shouldReindex: shouldReindex,
      sourceChanged: sourceChanged,
      storageRestored: storageRestored,
    );
  }

  Future<void> deleteStoredBookArtifacts(LocalBook localBook) async {
    final file = await resolveStorageFile(localBook);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (error) {
        _logger.warn(
          'Delete local book file failed',
          context: {
            'bookId': localBook.id,
            'path': localBook.storagePath,
            'error': error.toString(),
          },
        );
      }
    }
    if (localBook.requiresManagedAssetDirectory) {
      final assetDir = await resolveAssetDirectory(localBook);
      if (await assetDir.exists()) {
        try {
          await assetDir.delete(recursive: true);
        } catch (error) {
          _logger.warn(
            'Delete local epub asset directory failed',
            context: {
              'bookId': localBook.id,
              'path': assetDir.path,
              'error': error.toString(),
            },
          );
        }
      }
    }
  }

  Future<Directory> resolveAssetDirectory(LocalBook book) async {
    final storageFile = await resolveStorageFile(book);
    return _resolveAssetDirectoryFromStoragePath(storageFile.path);
  }

  Future<FileStat?> _statOrNull(File file) async {
    try {
      if (!await file.exists()) {
        return null;
      }
      return file.stat();
    } catch (_) {
      return null;
    }
  }

  Directory _resolveAssetDirectoryFromStoragePath(String storagePath) {
    final storageDir = Directory(p.dirname(storagePath));
    final folderName = '${p.basenameWithoutExtension(storagePath)}_assets';
    return Directory(p.join(storageDir.path, folderName));
  }

  String? _extractManagedRelativePath(String storagePath) {
    final normalized = storagePath.trim().replaceAll('\\', '/');
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.startsWith('local_books/')) {
      return p.posix.normalize(normalized);
    }
    final marker = '/local_books/';
    final markerIndex = normalized.lastIndexOf(marker);
    if (markerIndex >= 0) {
      return p.posix.normalize(normalized.substring(markerIndex + 1));
    }
    return null;
  }

  bool _isEphemeralSourcePath(String path) {
    final normalized = path.replaceAll('\\', '/').toLowerCase();
    return normalized.contains('/tmp/') ||
        normalized.contains('/inbox/') ||
        normalized.contains('-inbox/') ||
        normalized.contains('/external_imports/');
  }

  String _extensionForFormat(LocalBookFormat format) {
    return switch (format) {
      LocalBookFormat.txt => '.txt',
      LocalBookFormat.epub => '.epub',
      LocalBookFormat.md => '.md',
      LocalBookFormat.html => '.html',
      LocalBookFormat.pdf => '.pdf',
      LocalBookFormat.mobi => '.mobi',
      LocalBookFormat.azw => '.azw',
      LocalBookFormat.azw3 => '.azw3',
    };
  }
}
