import 'reader_reading_record_coordinator.dart';
import 'reader_runtime_wake_policy.dart';

/// 阅读器运行时协作门面。
///
/// 这个 facade 先承接进度保存防抖和阅读记录 session 的纯业务决策，
/// 页面层仍负责持有 timer、滚动控制器和 UI 状态。后续继续拆
/// `ReaderPage` 时，应优先把章节加载、预取和错误态也逐步迁到这里，
/// 但不能在一次迁移里改变移动端触控或桌面输入行为。
class ReaderRuntimeFacade {
  const ReaderRuntimeFacade({
    this.wakePolicy = const ReaderRuntimeWakePolicy(),
    this.readingRecordCoordinator = const ReaderReadingRecordCoordinator(),
  });

  final ReaderRuntimeWakePolicy wakePolicy;
  final ReaderReadingRecordCoordinator readingRecordCoordinator;

  /// 解析本次进度保存是否应立即 flush，或需要等待多久再保存。
  ///
  /// 阅读器会被滚动、翻页、目录跳转和窗口恢复频繁触发保存；统一防抖可以
  /// 减少存储写入，同时保留退出前 flush 的即时恢复能力。
  ReaderProgressSaveDecision resolveProgressSaveDecision({
    required DateTime? lastSavedAt,
    required DateTime now,
  }) {
    final delay = wakePolicy.progressSaveDelay(
      lastSavedAt: lastSavedAt,
      now: now,
    );
    if (delay <= Duration.zero) {
      return const ReaderProgressSaveDecision.flushNow();
    }
    return ReaderProgressSaveDecision.debounce(delay);
  }

  ReaderReadingRecordSessionStartResult startOrUpdateReadingRecordSession({
    required bool readingRecordEnabled,
    required bool isBootstrapping,
    required bool isLoadingContent,
    required bool hasError,
    required bool hasVisibleReaderContent,
    required String? sourceId,
    required String? detailUrl,
    required String bookTitle,
    required String currentBookId,
    required String chapterId,
    required String? chapterUrl,
    required String? chapterTitle,
    required int? chapterIndex,
    required String? bookAuthor,
    required String? coverUrl,
    required double initialRatio,
    required DateTime now,
    required ReaderReadingRecordSession? existingSession,
  }) {
    return readingRecordCoordinator.startOrUpdateSession(
      readingRecordEnabled: readingRecordEnabled,
      isBootstrapping: isBootstrapping,
      isLoadingContent: isLoadingContent,
      hasError: hasError,
      hasVisibleReaderContent: hasVisibleReaderContent,
      sourceId: sourceId,
      detailUrl: detailUrl,
      bookTitle: bookTitle,
      currentBookId: currentBookId,
      chapterId: chapterId,
      chapterUrl: chapterUrl,
      chapterTitle: chapterTitle,
      chapterIndex: chapterIndex,
      bookAuthor: bookAuthor,
      coverUrl: coverUrl,
      initialRatio: initialRatio,
      now: now,
      existingSession: existingSession,
    );
  }

  ReaderReadingRecordSession? syncReadingRecordSessionProgress({
    required ReaderReadingRecordSession? session,
    required double ratio,
  }) {
    if (session == null) {
      return null;
    }
    return readingRecordCoordinator.syncProgress(
      session: session,
      ratio: ratio,
    );
  }

  Duration autoCommitInterval({required ReaderReadingRecordSession? session}) {
    return readingRecordCoordinator.autoCommitInterval(
      hasActiveSession: session != null,
    );
  }
}

class ReaderProgressSaveDecision {
  const ReaderProgressSaveDecision._({
    required this.flushImmediately,
    required this.debounce,
  });

  const ReaderProgressSaveDecision.flushNow()
    : this._(flushImmediately: true, debounce: Duration.zero);

  const ReaderProgressSaveDecision.debounce(Duration delay)
    : this._(flushImmediately: false, debounce: delay);

  final bool flushImmediately;
  final Duration debounce;
}
