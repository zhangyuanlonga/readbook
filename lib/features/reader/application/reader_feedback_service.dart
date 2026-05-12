import '../../../core/errors/error_codes.dart';
import 'reader_error_center_service.dart';

class ReaderSnackDedupState {
  const ReaderSnackDedupState({this.lastAt, this.lastKey});

  final DateTime? lastAt;
  final String? lastKey;
}

class ReaderSnackDecision {
  const ReaderSnackDecision({
    required this.shouldShow,
    required this.nextState,
  });

  final bool shouldShow;
  final ReaderSnackDedupState nextState;
}

class ReaderFeedbackService {
  const ReaderFeedbackService();

  ReaderSnackDecision resolveSnackDecision({
    required String text,
    String? dedupeKey,
    required DateTime now,
    required Duration dedupeWindow,
    required ReaderSnackDedupState currentState,
  }) {
    final resolvedKey = (dedupeKey ?? text).trim();
    if (resolvedKey.isEmpty) {
      return ReaderSnackDecision(shouldShow: true, nextState: currentState);
    }
    final lastAt = currentState.lastAt;
    final lastKey = currentState.lastKey;
    final isDuplicate =
        lastKey == resolvedKey &&
        lastAt != null &&
        now.difference(lastAt) < dedupeWindow;
    if (isDuplicate) {
      return ReaderSnackDecision(shouldShow: false, nextState: currentState);
    }
    return ReaderSnackDecision(
      shouldShow: true,
      nextState: ReaderSnackDedupState(lastAt: now, lastKey: resolvedKey),
    );
  }

  String chapterBoundaryMessage({required bool isFirst}) {
    return isFirst ? '已经是第一章。' : '已经是最后一章。';
  }

  bool shouldPromptSwitchSourceForMissingSource({
    required bool canSwitchSource,
    required ErrorCode? code,
    required bool mounted,
    required bool hasPromptedMissingSourceSwitch,
    required bool isSwitchSourceLoading,
  }) {
    if (!canSwitchSource) {
      return false;
    }
    if (code != ErrorCode.unknownSource) {
      return false;
    }
    if (!mounted || hasPromptedMissingSourceSwitch || isSwitchSourceLoading) {
      return false;
    }
    return true;
  }

  void recordFailure({
    required ReaderErrorCenterService readerErrorCenterService,
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
    readerErrorCenterService.addFailure(
      bookId: bookId,
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      message: message,
      bookTitle: bookTitle,
      sourceId: sourceId,
      detailUrl: detailUrl,
      chapterUrl: chapterUrl,
      errorCode: errorCode,
    );
  }
}
