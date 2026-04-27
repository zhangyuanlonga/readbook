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
        final parentDir = targetFile.parent;
        if (!await parentDir.exists()) {
          await parentDir.create(recursive: true);
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

      final leadingSample = await _detectEncodingFromLeadingSample(
        effectiveSourceFile,
      );
      final sample =
          leadingSample?.charsetName == 'utf-8'
              ? leadingSample
              : await _detectEncodingFromSamples(effectiveSourceFile);
      try {
        final detectedCharset = await _resolveStoredTxtCharset(
          file: effectiveSourceFile,
          fileLength: fileLength,
          leadingSample: leadingSample,
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

  Future<String?> _resolveStoredTxtCharset({
    required File file,
    required int fileLength,
    required LocalTextDecodeResult? leadingSample,
    required LocalTextDecodeResult? sampledResult,
  }) async {
    final leadingCharset = leadingSample?.charsetName;
    if (leadingCharset != null && leadingCharset.isNotEmpty) {
      return leadingCharset;
    }

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

    final scoredResults = <_ScoredEncodingSample>[];
    final fileLength = await file.length();
    for (final chunk in sampleChunks) {
      final decoded =
          _textEncodingDetector.decodeSampleBestEffort(
            chunk.bytes,
            htmlAware: false,
          ) ??
          await _textEncodingDetector.decodeSampleBestEffortAsync(
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

  Future<LocalTextDecodeResult?> _detectEncodingFromLeadingSample(
    File file,
  ) async {
    final fileLength = await file.length();
    if (fileLength <= 0) {
      return null;
    }
    final sampleLength =
        fileLength < _encodingSampleBytes ? fileLength : _encodingSampleBytes;
    final bytes = await file
        .openRead(0, sampleLength)
        .fold<List<int>>(
          <int>[],
          (buffer, chunk) => <int>[...buffer, ...chunk],
        );
    if (bytes.isEmpty) {
      return null;
    }
    final decoded =
        _textEncodingDetector.decodeSampleBestEffort(bytes, htmlAware: false) ??
        await _textEncodingDetector.decodeSampleBestEffortAsync(
          bytes,
          htmlAware: false,
        );
    if (decoded == null || decoded.text.trim().isEmpty) {
      return null;
    }
    if (_isTrustworthyLeadingSample(decoded)) {
      return decoded;
    }
    return null;
  }

  bool _isTrustworthyLeadingSample(LocalTextDecodeResult decoded) {
    final charsetName = decoded.charsetName;
    if (charsetName == 'utf-8') {
      return !decoded.fallbackUsed &&
          _looksLikeMeaningfulUtf8LeadSample(decoded.text);
    }
    if (charsetName == 'utf-16' ||
        charsetName == 'utf-16le' ||
        charsetName == 'utf-16be') {
      return true;
    }
    return _looksLikeMeaningfulMultibyteLeadSample(decoded.text);
  }

  bool _looksLikeMeaningfulUtf8LeadSample(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final hanCount =
        trimmed.runes.where((rune) => rune >= 0x4E00 && rune <= 0x9FFF).length;
    final punctuationCount =
        trimmed.runes
            .where((rune) => '，。！？；：“”‘’《》、（）【】'.runes.contains(rune))
            .length;
    if (hanCount > 0 || punctuationCount > 0) {
      return true;
    }
    return false;
  }

  bool _looksLikeMeaningfulMultibyteLeadSample(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final hanCount =
        trimmed.runes.where((rune) => rune >= 0x4E00 && rune <= 0x9FFF).length;
    final punctuationCount =
        trimmed.runes
            .where((rune) => '，。！？；：“”‘’《》、（）【】'.runes.contains(rune))
            .length;
    return hanCount > 0 || punctuationCount > 0;
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
