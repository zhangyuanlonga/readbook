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

class _EncodingSampleChunk {
  const _EncodingSampleChunk({required this.start, required this.bytes});

  final int start;
  final List<int> bytes;
}

class _ScoredEncodingSample {
  const _ScoredEncodingSample({required this.result, required this.score});

  final LocalTextDecodeResult result;
  final int score;
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
    String? preferredCharset,
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

    final normalizedPreferredCharset =
        LocalTextEncodingDetector.normalizeCharsetName(preferredCharset);
    if (normalizedPreferredCharset != null) {
      await _ensureParentDir(targetFile);
      await sourceFile.copy(targetFile.path);
      final copiedStat = await targetFile.stat();
      return LocalBookStorageWriteResult(
        storageStat: copiedStat,
        normalizedCharset: normalizedPreferredCharset,
        originalCharset: normalizedPreferredCharset,
        convertedToUtf8: false,
      );
    }

    final sample = await _detectEncodingFromSamples(sourceFile);
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
      final decoded = await _textEncodingDetector.decodeBestEffortAsync(bytes);
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

    final scoredResults = <_ScoredEncodingSample>[];
    final fileLength = await file.length();
    for (final chunk in sampleChunks) {
      final decoded = await _textEncodingDetector.decodeSampleBestEffortAsync(
        chunk.bytes,
        htmlAware: false,
      );
      if (decoded == null || decoded.text.trim().isEmpty) {
        continue;
      }
      scoredResults.add(
        _ScoredEncodingSample(
          result: decoded,
          score: _scoreEncodingSample(
            chunk: chunk,
            fileLength: fileLength,
            decoded: decoded,
          ),
        ),
      );
    }

    if (scoredResults.isEmpty) {
      return null;
    }

    final aggregated = <String, int>{};
    final bestByCharset = <String, _ScoredEncodingSample>{};
    for (final sample in scoredResults) {
      final charset = sample.result.charsetName;
      aggregated[charset] = (aggregated[charset] ?? 0) + sample.score;
      final currentBest = bestByCharset[charset];
      if (currentBest == null || sample.score > currentBest.score) {
        bestByCharset[charset] = sample;
      }
    }

    String? bestCharset;
    var bestScore = -0x7fffffff;
    for (final entry in aggregated.entries) {
      if (entry.value > bestScore) {
        bestCharset = entry.key;
        bestScore = entry.value;
      }
    }
    if (bestCharset == null) {
      return null;
    }
    return bestByCharset[bestCharset]?.result;
  }

  int _scoreEncodingSample({
    required _EncodingSampleChunk chunk,
    required int fileLength,
    required LocalTextDecodeResult decoded,
  }) {
    final text = decoded.text.trim();
    if (text.isEmpty) {
      return -1000;
    }

    var score = 0;
    final lower = text.toLowerCase();
    final hanCount =
        text.runes.where((rune) => rune >= 0x4E00 && rune <= 0x9FFF).length;
    final asciiCount =
        text.runes.where((rune) => rune >= 0x20 && rune <= 0x7E).length;
    final punctuationCount =
        text.runes
            .where((rune) => '，。！？；：“”‘’《》、（）【】'.runes.contains(rune))
            .length;
    final replacementCount = text.runes.where((rune) => rune == 0xFFFD).length;
    final suspiciousMojibakeCount =
        text.runes
            .where(
              (rune) =>
                  rune == 0x00C3 ||
                  rune == 0x00C2 ||
                  rune == 0x00E2 ||
                  rune == 0x00D0 ||
                  rune == 0x00D1 ||
                  rune == 0x00FE ||
                  rune == 0x00FF,
            )
            .length;

    score += hanCount * 6;
    score += punctuationCount * 10;
    score -= replacementCount * 40;
    score -= suspiciousMojibakeCount * 25;
    if (decoded.fallbackUsed) {
      score -= 140;
    }

    if (asciiCount > 0 && hanCount == 0 && punctuationCount == 0) {
      score -= 80;
    }
    if (RegExp(r'第.{0,12}[章节回卷部集]').hasMatch(text)) {
      score += 80;
    }
    if (lower.contains('chapter') || lower.contains('part ')) {
      score += 20;
    }

    final midpoint = chunk.start + (chunk.bytes.length ~/ 2);
    final normalizedPosition =
        fileLength <= 0 ? 0.0 : midpoint / fileLength.toDouble();
    if (normalizedPosition >= 0.25 && normalizedPosition <= 0.75) {
      score += 70;
    } else if (normalizedPosition > 0.75) {
      score += 50;
    } else {
      score += 10;
    }

    if (decoded.charsetName == 'utf-8' &&
        hanCount == 0 &&
        punctuationCount == 0) {
      score -= 20;
    }

    if (decoded.charsetName == 'utf-16be' ||
        decoded.charsetName == 'utf-16le' ||
        decoded.charsetName == 'utf-16') {
      final zeroRatio = _zeroByteRatio(chunk.bytes);
      if (zeroRatio < 0.12) {
        score -= 240;
      } else {
        score += 40;
      }
    }

    return score;
  }

  double _zeroByteRatio(List<int> bytes) {
    if (bytes.isEmpty) {
      return 0;
    }
    final zeroCount = bytes.where((byte) => byte == 0).length;
    return zeroCount / bytes.length;
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
    if (localBook.format == LocalBookFormat.epub ||
        localBook.format == LocalBookFormat.md ||
        localBook.format == LocalBookFormat.html ||
        localBook.format == LocalBookFormat.mobi ||
        localBook.format == LocalBookFormat.azw ||
        localBook.format == LocalBookFormat.azw3) {
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
      LocalBookFormat.md => '.md',
      LocalBookFormat.html => '.html',
      LocalBookFormat.pdf => '.pdf',
      LocalBookFormat.mobi => '.mobi',
      LocalBookFormat.azw => '.azw',
      LocalBookFormat.azw3 => '.azw3',
    };
  }
}
