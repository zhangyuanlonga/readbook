import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_page_turn_gate.dart';

void main() {
  group('ReaderPageTurnGate', () {
    const gate = ReaderPageTurnGate();

    test('allows page and chapter requests while idle', () {
      final page = gate.resolve(
        requestKind: ReaderPageTurnRequestKind.page,
        snapshot: const ReaderPageTurnGateSnapshot.idle(),
      );
      final chapter = gate.resolve(
        requestKind: ReaderPageTurnRequestKind.chapter,
        snapshot: const ReaderPageTurnGateSnapshot.idle(),
      );

      expect(page.shouldAllow, isTrue);
      expect(chapter.shouldAllow, isTrue);
    });

    test('uses deterministic priority when multiple animations are active', () {
      final decision = gate.resolve(
        requestKind: ReaderPageTurnRequestKind.page,
        snapshot: const ReaderPageTurnGateSnapshot(
          pagedTransitionAnimating: true,
          curlAutoTurning: true,
          curlPreviewActive: true,
          crossChapterSnapshotActive: true,
          paperCurlAnimating: true,
          readerInteractionAnimating: true,
        ),
      );

      expect(decision.shouldAllow, isFalse);
      expect(
        decision.blockReason,
        ReaderPageTurnBlockReason.paperCurlAnimating,
      );
      expect(decision.message, contains('纸页卷动'));
    });

    test('blocks chapter jump with a chapter-oriented message', () {
      final decision = gate.resolve(
        requestKind: ReaderPageTurnRequestKind.jump,
        snapshot: const ReaderPageTurnGateSnapshot(
          pagedTransitionAnimating: false,
          curlAutoTurning: false,
          curlPreviewActive: false,
          crossChapterSnapshotActive: true,
          paperCurlAnimating: false,
          readerInteractionAnimating: false,
        ),
      );

      expect(decision.shouldAllow, isFalse);
      expect(
        decision.blockReason,
        ReaderPageTurnBlockReason.crossChapterSnapshotActive,
      );
      expect(decision.message, contains('章节切换'));
    });

    test('does not block reload requests', () {
      final decision = gate.resolve(
        requestKind: ReaderPageTurnRequestKind.reload,
        snapshot: const ReaderPageTurnGateSnapshot(
          pagedTransitionAnimating: true,
          curlAutoTurning: true,
          curlPreviewActive: true,
          crossChapterSnapshotActive: true,
          paperCurlAnimating: true,
          readerInteractionAnimating: true,
        ),
      );

      expect(decision.shouldAllow, isTrue);
    });
  });
}
