import 'dart:async';

import '../../../core/errors/error_codes.dart';

class ReaderFailureRecord {
  const ReaderFailureRecord({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.chapterTitle,
    required this.message,
    required this.occurredAt,
    this.bookTitle,
    this.sourceId,
    this.detailUrl,
    this.chapterUrl,
    this.errorCode,
  });

  final String id;
  final String bookId;
  final String chapterId;
  final String chapterTitle;
  final String message;
  final DateTime occurredAt;
  final String? bookTitle;
  final String? sourceId;
  final String? detailUrl;
  final String? chapterUrl;
  final ErrorCode? errorCode;

  String get chapterLabel {
    if (chapterTitle.trim().isNotEmpty) {
      return chapterTitle.trim();
    }
    return '未命名章节';
  }

  String get shortMessage {
    final normalized = message.trim();
    if (normalized.length <= 66) {
      return normalized;
    }
    return '${normalized.substring(0, 66)}...';
  }
}

class ReaderErrorCenterService {
  ReaderErrorCenterService._();

  static final ReaderErrorCenterService instance = ReaderErrorCenterService._();

  final List<ReaderFailureRecord> _records = <ReaderFailureRecord>[];
  final StreamController<List<ReaderFailureRecord>> _controller =
      StreamController<List<ReaderFailureRecord>>.broadcast();

  static const int _maxRecords = 40;

  List<ReaderFailureRecord> get records => List.unmodifiable(_records);

  Stream<List<ReaderFailureRecord>> watch() {
    return _controller.stream;
  }

  void addFailure({
    required String bookId,
    required String chapterId,
    required String chapterTitle,
    required String message,
    String? bookTitle,
    String? sourceId,
    String? detailUrl,
    String? chapterUrl,
    ErrorCode? errorCode,
  }) {
    final normalizedBookId = bookId.trim();
    final normalizedChapterId = chapterId.trim();
    final normalizedMessage = message.trim();

    if (normalizedBookId.isEmpty ||
        normalizedChapterId.isEmpty ||
        normalizedMessage.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final dedupeKey = '$normalizedBookId|$normalizedChapterId';

    _records.removeWhere(
      (item) => '${item.bookId}|${item.chapterId}' == dedupeKey,
    );

    _records.insert(
      0,
      ReaderFailureRecord(
        id: '${now.microsecondsSinceEpoch}_$normalizedChapterId',
        bookId: normalizedBookId,
        chapterId: normalizedChapterId,
        chapterTitle: chapterTitle,
        message: normalizedMessage,
        occurredAt: now,
        bookTitle: bookTitle,
        sourceId: sourceId?.trim(),
        detailUrl: detailUrl?.trim(),
        chapterUrl: chapterUrl?.trim(),
        errorCode: errorCode,
      ),
    );

    if (_records.length > _maxRecords) {
      _records.removeRange(_maxRecords, _records.length);
    }

    _notify();
  }

  void remove(String id) {
    _records.removeWhere((item) => item.id == id);
    _notify();
  }

  void clear() {
    if (_records.isEmpty) {
      return;
    }
    _records.clear();
    _notify();
  }

  void _notify() {
    if (_controller.isClosed) {
      return;
    }
    _controller.add(List.unmodifiable(_records));
  }
}
