import 'dart:convert';
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
    return p.join('local_books', '$bookId${_extensionForFormat(format)}');
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
  }) async {
    if (await targetFile.exists()) {
      await targetFile.delete();
    }

    if (format != LocalBookFormat.txt) {
      final parentDir = targetFile.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }
      await sourceFile.copy(targetFile.path);
      final copiedStat = await targetFile.stat();
      return LocalBookStorageWriteResult(storageStat: copiedStat);
    }

    final fileLength = await sourceFile.length();
    if (fileLength == 0) {
      await targetFile.writeAsBytes(const <int>[], flush: true);
      final emptyStat = await targetFile.stat();
      return LocalBookStorageWriteResult(
        storageStat: emptyStat,
        normalizedCharset: 'utf-8',
        originalCharset: 'utf-8',
      );
    }

    final sample = await _detectEncodingFromSample(sourceFile);
    if (fileLength >= _largeTxtRawCopyThresholdBytes && sample != null) {
      await _ensureParentDir(targetFile);
      await sourceFile.copy(targetFile.path);
      final copiedStat = await targetFile.stat();
      return LocalBookStorageWriteResult(
        storageStat: copiedStat,
        normalizedCharset: sample.charsetName,
        originalCharset: sample.charsetName,
        convertedToUtf8: false,
      );
    }

    final bytes = await sourceFile.readAsBytes();
    try {
      final decoded = _textEncodingDetector.decodeBestEffort(bytes);
      await _ensureParentDir(targetFile);
      final canKeepOriginalBytes =
          decoded.charsetName == 'utf-8' &&
          decoded.bomLength == 0 &&
          !decoded.fallbackUsed &&
          !decoded.text.startsWith('\uFEFF');
      if (canKeepOriginalBytes) {
        await sourceFile.copy(targetFile.path);
        final copiedStat = await targetFile.stat();
        return LocalBookStorageWriteResult(
          storageStat: copiedStat,
          normalizedCharset: 'utf-8',
          originalCharset: decoded.charsetName,
          convertedToUtf8: false,
        );
      }

      final normalizedText = decoded.text.replaceFirst('\uFEFF', '');
      final normalizedBytes = utf8.encode(normalizedText);
      await targetFile.writeAsBytes(normalizedBytes, flush: true);
      final normalizedStat = await targetFile.stat();
      return LocalBookStorageWriteResult(
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
      await _ensureParentDir(targetFile);
      await sourceFile.copy(targetFile.path);
      final copiedStat = await targetFile.stat();
      return LocalBookStorageWriteResult(storageStat: copiedStat);
    }
  }

  Future<List<int>> _readEncodingSample(File file) async {
    final fileLength = await file.length();
    if (fileLength == 0) {
      return const <int>[];
    }
    final sampleLength =
        fileLength < _encodingSampleBytes ? fileLength : _encodingSampleBytes;
    if (sampleLength <= 0) {
      return const <int>[];
    }
    final builder = BytesBuilder(copy: false);
    await file.openRead(0, sampleLength).forEach(builder.add);
    return builder.takeBytes();
  }

  Future<LocalTextDecodeResult?> _detectEncodingFromSample(File file) async {
    final sampleBytes = await _readEncodingSample(file);
    if (sampleBytes.isEmpty) {
      return null;
    }
    return _textEncodingDetector.decodeSampleBestEffort(
      sampleBytes,
      htmlAware: false,
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
    if (localBook.format == LocalBookFormat.epub) {
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
      return p.normalize(normalized);
    }
    final marker = '/local_books/';
    final markerIndex = normalized.lastIndexOf(marker);
    if (markerIndex >= 0) {
      return p.normalize(normalized.substring(markerIndex + 1));
    }
    return null;
  }

  bool _isEphemeralSourcePath(String path) {
    final normalized = path.replaceAll('\\', '/').toLowerCase();
    return normalized.contains('/tmp/') ||
        normalized.contains('/inbox/') ||
        normalized.contains('-inbox/');
  }

  String _extensionForFormat(LocalBookFormat format) {
    return switch (format) {
      LocalBookFormat.txt => '.txt',
      LocalBookFormat.epub => '.epub',
    };
  }
}
