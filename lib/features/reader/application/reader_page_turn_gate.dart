enum ReaderPageTurnRequestKind { page, chapter, reload, jump }

enum ReaderPageTurnBlockReason {
  pagedTransitionAnimating,
  curlAutoTurning,
  curlPreviewActive,
  crossChapterSnapshotActive,
  paperCurlAnimating,
  readerInteractionAnimating,
}

class ReaderPageTurnGateSnapshot {
  const ReaderPageTurnGateSnapshot({
    required this.pagedTransitionAnimating,
    required this.curlAutoTurning,
    required this.curlPreviewActive,
    required this.crossChapterSnapshotActive,
    required this.paperCurlAnimating,
    required this.readerInteractionAnimating,
  });

  const ReaderPageTurnGateSnapshot.idle()
    : pagedTransitionAnimating = false,
      curlAutoTurning = false,
      curlPreviewActive = false,
      crossChapterSnapshotActive = false,
      paperCurlAnimating = false,
      readerInteractionAnimating = false;

  final bool pagedTransitionAnimating;
  final bool curlAutoTurning;
  final bool curlPreviewActive;
  final bool crossChapterSnapshotActive;
  final bool paperCurlAnimating;
  final bool readerInteractionAnimating;
}

class ReaderPageTurnGateDecision {
  const ReaderPageTurnGateDecision.allow()
    : shouldAllow = true,
      blockReason = null,
      message = null;

  const ReaderPageTurnGateDecision.block({
    required ReaderPageTurnBlockReason reason,
    required this.message,
  }) : shouldAllow = false,
       blockReason = reason;

  final bool shouldAllow;
  final ReaderPageTurnBlockReason? blockReason;
  final String? message;

  bool get isBlocked => !shouldAllow;
}

class ReaderPageTurnGate {
  const ReaderPageTurnGate();

  ReaderPageTurnGateDecision resolve({
    required ReaderPageTurnRequestKind requestKind,
    required ReaderPageTurnGateSnapshot snapshot,
  }) {
    if (requestKind == ReaderPageTurnRequestKind.reload) {
      return const ReaderPageTurnGateDecision.allow();
    }

    final reason = _firstBlockingReason(snapshot);
    if (reason == null) {
      return const ReaderPageTurnGateDecision.allow();
    }

    return ReaderPageTurnGateDecision.block(
      reason: reason,
      message: _messageFor(reason, requestKind),
    );
  }

  ReaderPageTurnBlockReason? _firstBlockingReason(
    ReaderPageTurnGateSnapshot snapshot,
  ) {
    if (snapshot.paperCurlAnimating) {
      return ReaderPageTurnBlockReason.paperCurlAnimating;
    }
    if (snapshot.crossChapterSnapshotActive) {
      return ReaderPageTurnBlockReason.crossChapterSnapshotActive;
    }
    if (snapshot.pagedTransitionAnimating) {
      return ReaderPageTurnBlockReason.pagedTransitionAnimating;
    }
    if (snapshot.curlAutoTurning) {
      return ReaderPageTurnBlockReason.curlAutoTurning;
    }
    if (snapshot.curlPreviewActive) {
      return ReaderPageTurnBlockReason.curlPreviewActive;
    }
    if (snapshot.readerInteractionAnimating) {
      return ReaderPageTurnBlockReason.readerInteractionAnimating;
    }
    return null;
  }

  String _messageFor(
    ReaderPageTurnBlockReason reason,
    ReaderPageTurnRequestKind requestKind,
  ) {
    final target = switch (requestKind) {
      ReaderPageTurnRequestKind.chapter ||
      ReaderPageTurnRequestKind.jump => '章节切换',
      ReaderPageTurnRequestKind.page => '翻页',
      ReaderPageTurnRequestKind.reload => '刷新',
    };
    final suffix = switch (reason) {
      ReaderPageTurnBlockReason.paperCurlAnimating => '纸页卷动还在进行中',
      ReaderPageTurnBlockReason.crossChapterSnapshotActive => '跨章节动画还在进行中',
      ReaderPageTurnBlockReason.pagedTransitionAnimating => '翻页动画还在进行中',
      ReaderPageTurnBlockReason.curlAutoTurning => '仿真卷曲动画还在进行中',
      ReaderPageTurnBlockReason.curlPreviewActive => '仿真卷曲预览还未结束',
      ReaderPageTurnBlockReason.readerInteractionAnimating => '阅读器交互还在收尾',
    };
    return '$suffix，请稍后再试$target。';
  }
}
