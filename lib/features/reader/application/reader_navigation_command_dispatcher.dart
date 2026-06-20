import 'reader_page_turn_gate.dart';

enum ReaderNavigationCommandType {
  previousPage,
  nextPage,
  previousChapter,
  nextChapter,
  reloadChapter,
  jumpChapter,
}

enum ReaderNavigationCommandSource {
  chrome,
  audio,
  tapZone,
  keyboard,
  swipe,
  volumeKey,
  scrollEdge,
  autoRead,
  catalog,
  unknown,
}

enum ReaderNavigationCommandDecisionType { execute, reject }

enum ReaderNavigationCommandRejectReason {
  notMounted,
  loading,
  pageTurnBusy,
  noChapters,
  noCurrentChapter,
  boundary,
  invalidTarget,
  unsupported,
  selectionActive,
}

class ReaderNavigationCommand {
  const ReaderNavigationCommand._({
    required this.type,
    required this.source,
    this.targetChapterIndex,
  });

  const ReaderNavigationCommand.previousPage({
    ReaderNavigationCommandSource source =
        ReaderNavigationCommandSource.unknown,
  }) : this._(type: ReaderNavigationCommandType.previousPage, source: source);

  const ReaderNavigationCommand.nextPage({
    ReaderNavigationCommandSource source =
        ReaderNavigationCommandSource.unknown,
  }) : this._(type: ReaderNavigationCommandType.nextPage, source: source);

  const ReaderNavigationCommand.previousChapter({
    ReaderNavigationCommandSource source =
        ReaderNavigationCommandSource.unknown,
  }) : this._(
         type: ReaderNavigationCommandType.previousChapter,
         source: source,
       );

  const ReaderNavigationCommand.nextChapter({
    ReaderNavigationCommandSource source =
        ReaderNavigationCommandSource.unknown,
  }) : this._(type: ReaderNavigationCommandType.nextChapter, source: source);

  const ReaderNavigationCommand.reloadChapter({
    ReaderNavigationCommandSource source =
        ReaderNavigationCommandSource.unknown,
  }) : this._(type: ReaderNavigationCommandType.reloadChapter, source: source);

  const ReaderNavigationCommand.jumpChapter({
    required int targetChapterIndex,
    ReaderNavigationCommandSource source =
        ReaderNavigationCommandSource.unknown,
  }) : this._(
         type: ReaderNavigationCommandType.jumpChapter,
         source: source,
         targetChapterIndex: targetChapterIndex,
       );

  final ReaderNavigationCommandType type;
  final ReaderNavigationCommandSource source;
  final int? targetChapterIndex;

  bool get isChapterCommand =>
      type == ReaderNavigationCommandType.previousChapter ||
      type == ReaderNavigationCommandType.nextChapter ||
      type == ReaderNavigationCommandType.jumpChapter;

  bool get isPageCommand =>
      type == ReaderNavigationCommandType.previousPage ||
      type == ReaderNavigationCommandType.nextPage;
}

class ReaderNavigationCommandSnapshot {
  const ReaderNavigationCommandSnapshot({
    required this.mounted,
    required this.bootstrapping,
    required this.loadingContent,
    required this.pageTurnBusy,
    this.pageTurnBusyReason,
    this.pageTurnBusyMessage,
    required this.chapterCount,
    required this.currentChapterIndex,
    required this.overlayVisible,
    required this.isLocalContent,
    required this.usesContinuousTextFlow,
    required this.viewportKind,
    required this.contentMode,
    this.hasError = false,
    this.selectionActive = false,
  });

  final bool mounted;
  final bool bootstrapping;
  final bool loadingContent;
  final bool pageTurnBusy;
  final ReaderPageTurnBlockReason? pageTurnBusyReason;
  final String? pageTurnBusyMessage;
  final int chapterCount;
  final int? currentChapterIndex;
  final bool overlayVisible;
  final bool isLocalContent;
  final bool usesContinuousTextFlow;
  final String viewportKind;
  final String contentMode;
  final bool hasError;
  final bool selectionActive;

  bool get readerLoading => bootstrapping || loadingContent;
}

class ReaderNavigationCommandDecision {
  const ReaderNavigationCommandDecision.execute()
    : type = ReaderNavigationCommandDecisionType.execute,
      rejectReason = null,
      message = null;

  const ReaderNavigationCommandDecision.reject({
    required ReaderNavigationCommandRejectReason reason,
    this.message,
  }) : type = ReaderNavigationCommandDecisionType.reject,
       rejectReason = reason;

  final ReaderNavigationCommandDecisionType type;
  final ReaderNavigationCommandRejectReason? rejectReason;
  final String? message;

  bool get shouldExecute => type == ReaderNavigationCommandDecisionType.execute;
}

class ReaderNavigationCommandDispatcher {
  const ReaderNavigationCommandDispatcher();

  ReaderNavigationCommandDecision resolve({
    required ReaderNavigationCommand command,
    required ReaderNavigationCommandSnapshot snapshot,
  }) {
    if (!snapshot.mounted) {
      return const ReaderNavigationCommandDecision.reject(
        reason: ReaderNavigationCommandRejectReason.notMounted,
      );
    }

    if (snapshot.readerLoading) {
      return const ReaderNavigationCommandDecision.reject(
        reason: ReaderNavigationCommandRejectReason.loading,
        message: '章节正在加载，请稍后再试。',
      );
    }

    if (snapshot.pageTurnBusy && command.isPageCommand) {
      return ReaderNavigationCommandDecision.reject(
        reason: ReaderNavigationCommandRejectReason.pageTurnBusy,
        message: snapshot.pageTurnBusyMessage ?? '翻页动画进行中，请稍后再试。',
      );
    }

    if (snapshot.pageTurnBusy && command.isChapterCommand) {
      return ReaderNavigationCommandDecision.reject(
        reason: ReaderNavigationCommandRejectReason.pageTurnBusy,
        message: snapshot.pageTurnBusyMessage ?? '章节切换处理中，请稍后再试。',
      );
    }

    if (snapshot.selectionActive && command.isPageCommand) {
      return const ReaderNavigationCommandDecision.reject(
        reason: ReaderNavigationCommandRejectReason.selectionActive,
        message: '文本选择中，请先完成当前操作。',
      );
    }

    return switch (command.type) {
      ReaderNavigationCommandType.previousPage ||
      ReaderNavigationCommandType.nextPage ||
      ReaderNavigationCommandType
          .reloadChapter => const ReaderNavigationCommandDecision.execute(),
      ReaderNavigationCommandType.previousChapter => _resolvePreviousChapter(
        snapshot,
      ),
      ReaderNavigationCommandType.nextChapter => _resolveNextChapter(snapshot),
      ReaderNavigationCommandType.jumpChapter => _resolveJumpChapter(
        command,
        snapshot,
      ),
    };
  }

  ReaderNavigationCommandDecision _resolvePreviousChapter(
    ReaderNavigationCommandSnapshot snapshot,
  ) {
    final currentIndex = snapshot.currentChapterIndex;
    if (snapshot.chapterCount <= 0) {
      return const ReaderNavigationCommandDecision.reject(
        reason: ReaderNavigationCommandRejectReason.noChapters,
        message: '目录还没有加载完成，请稍后再试。',
      );
    }
    if (currentIndex == null) {
      return const ReaderNavigationCommandDecision.reject(
        reason: ReaderNavigationCommandRejectReason.noCurrentChapter,
        message: '当前章节定位失败，请从目录重新进入。',
      );
    }
    if (currentIndex <= 0) {
      return const ReaderNavigationCommandDecision.reject(
        reason: ReaderNavigationCommandRejectReason.boundary,
      );
    }
    return const ReaderNavigationCommandDecision.execute();
  }

  ReaderNavigationCommandDecision _resolveNextChapter(
    ReaderNavigationCommandSnapshot snapshot,
  ) {
    final currentIndex = snapshot.currentChapterIndex;
    if (snapshot.chapterCount <= 0) {
      return const ReaderNavigationCommandDecision.reject(
        reason: ReaderNavigationCommandRejectReason.noChapters,
        message: '目录还没有加载完成，请稍后再试。',
      );
    }
    if (currentIndex == null) {
      return const ReaderNavigationCommandDecision.reject(
        reason: ReaderNavigationCommandRejectReason.noCurrentChapter,
        message: '当前章节定位失败，请从目录重新进入。',
      );
    }
    if (currentIndex >= snapshot.chapterCount - 1) {
      return const ReaderNavigationCommandDecision.reject(
        reason: ReaderNavigationCommandRejectReason.boundary,
      );
    }
    return const ReaderNavigationCommandDecision.execute();
  }

  ReaderNavigationCommandDecision _resolveJumpChapter(
    ReaderNavigationCommand command,
    ReaderNavigationCommandSnapshot snapshot,
  ) {
    final target = command.targetChapterIndex;
    if (target == null || target < 0 || target >= snapshot.chapterCount) {
      return const ReaderNavigationCommandDecision.reject(
        reason: ReaderNavigationCommandRejectReason.invalidTarget,
        message: '目标章节无效。',
      );
    }
    return const ReaderNavigationCommandDecision.execute();
  }
}
