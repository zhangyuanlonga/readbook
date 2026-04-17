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
import 'local_book_storage_service.dart';

class LocalBookPreviewService {
  LocalBookPreviewService({
    LocalBookRepository? localBookRepository,
    LocalBookStorageService? storageService,
  }) : _localBookRepository =
           localBookRepository ?? LocalBookRepositoryImpl(AppDatabase.instance),
       _storageService = storageService ?? LocalBookStorageService();

  final LocalBookRepository _localBookRepository;
  final LocalBookStorageService _storageService;
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
    final normalizedCharset = _normalizeCharsetName(book.charset);
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
      final content =
          _decodeBytes(bytes, preferredCharset: book.charset).trim();
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
    if (alternateScore == null) {
      return primary;
    }
    if (primaryScore == null) {
      return alternate;
    }
    return primaryScore >= alternateScore ? primary : alternate;
  }

  int? _decodedTextScore(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    var score = 0;
    for (final rune in trimmed.runes) {
      if (rune >= 0x4E00 && rune <= 0x9FFF) {
        score += 5;
      } else if (rune == 0xFFFD) {
        score -= 20;
      } else if (rune < 0x20 && rune != 0x0A && rune != 0x09) {
        score -= 8;
      } else {
        score += 1;
      }
    }
    return score;
  }

  String? _tryDecodeByCharset(List<int> bytes, String charsetName) {
    try {
      final charset = Charset.getByName(charsetName);
      if (charset == null) {
        return null;
      }
      return charset.decode(bytes);
    } catch (_) {
      return null;
    }
  }

  String? _normalizeCharsetName(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
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
      _ => normalized,
    };
  }
}
