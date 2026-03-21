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

import 'local_book_index_service.dart';

class LocalChapterContentService {
  LocalChapterContentService({
    LocalBookRepository? localBookRepository,
    LocalBookIndexService? indexService,
  }) : _localBookRepository =
           localBookRepository ?? LocalBookRepositoryImpl(AppDatabase.instance),
       _indexService =
           indexService ??
           LocalBookIndexService(
             localBookRepository:
                 localBookRepository ??
                 LocalBookRepositoryImpl(AppDatabase.instance),
           );

  final LocalBookRepository _localBookRepository;
  final LocalBookIndexService _indexService;

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

    if (book.indexStatus != LocalBookIndexStatus.ready ||
        book.chapterCount <= 0) {
      await _indexService.ensureIndexed(bookId: normalizedBookId);
      final refreshed = await _localBookRepository.getBookById(
        normalizedBookId,
      );
      if (refreshed != null) {
        book = refreshed;
      }
    }

    LocalChapter? chapter;
    final normalizedChapterId = (chapterId ?? '').trim();
    if (normalizedChapterId.isNotEmpty) {
      chapter = await _localBookRepository.getChapterById(normalizedChapterId);
    }

    if (chapter == null && chapterIndex != null) {
      final rawIndex = chapterIndex < 0 ? 0 : chapterIndex;
      var safeIndex = rawIndex;
      if (book.chapterCount > 0) {
        safeIndex = rawIndex.clamp(0, book.chapterCount - 1).toInt();
      }

      chapter = await _localBookRepository.getChapterByIndex(
        normalizedBookId,
        safeIndex,
      );

      if (chapter == null && safeIndex != rawIndex) {
        chapter = await _localBookRepository.getChapterByIndex(
          normalizedBookId,
          rawIndex,
        );
      }

      if (chapter == null) {
        final chapters = await _localBookRepository.getChapters(
          normalizedBookId,
        );
        if (chapters.isNotEmpty) {
          final fallbackIndex = rawIndex.clamp(0, chapters.length - 1).toInt();
          chapter = chapters[fallbackIndex];
        }
      }
    }

    if (chapter == null) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: '未找到本地章节内容，请重新索引后重试。',
      );
    }

    if (chapter.content.trim().isNotEmpty ||
        book.format != LocalBookFormat.txt) {
      return chapter;
    }

    final startOffset = chapter.startOffset;
    final endOffset = chapter.endOffset;
    if (startOffset == null || endOffset == null || endOffset <= startOffset) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: '本地章节缺少有效偏移信息，请重新索引后重试。',
      );
    }

    final content = await _readTxtChapterContent(
      storagePath: book.storagePath,
      startOffset: startOffset,
      endOffset: endOffset,
      charsetName: book.charset,
    );
    if (content.trim().isEmpty) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: '本地章节内容为空，请重新索引后重试。',
      );
    }

    return chapter.copyWith(content: content);
  }

  Future<String> _readTxtChapterContent({
    required String storagePath,
    required int startOffset,
    required int endOffset,
    required String? charsetName,
  }) async {
    final file = File(storagePath);
    if (!await file.exists()) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '本地文件不存在：$storagePath',
      );
    }

    final fileLength = await file.length();
    final safeStart = startOffset.clamp(0, fileLength).toInt();
    final safeEnd = endOffset.clamp(0, fileLength).toInt();
    if (safeEnd <= safeStart) {
      return '';
    }

    final fileHandle = await file.open(mode: FileMode.read);
    try {
      await fileHandle.setPosition(safeStart);
      final bytes = await fileHandle.read(safeEnd - safeStart);
      return _decodeText(bytes, charsetName).trim();
    } finally {
      await fileHandle.close();
    }
  }

  String _decodeText(List<int> bytes, String? charsetName) {
    final preferredCharset = _normalizeCharsetName(charsetName);
    if (preferredCharset != null) {
      final preferredText = _tryDecodeByCharset(bytes, preferredCharset);
      if (preferredText != null) {
        return preferredText;
      }
    }

    for (final candidate in const <String>[
      'utf-8',
      'utf-16be',
      'utf-16le',
      'gbk',
      'gb18030',
    ]) {
      final decoded = _tryDecodeByCharset(bytes, candidate);
      if (decoded != null) {
        return decoded;
      }
    }

    return utf8.decode(bytes, allowMalformed: true);
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
