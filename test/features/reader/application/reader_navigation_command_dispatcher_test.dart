import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_navigation_command_dispatcher.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_page_turn_gate.dart';

void main() {
  group('ReaderNavigationCommandDispatcher', () {
    const dispatcher = ReaderNavigationCommandDispatcher();

    test('executes adjacent chapter commands when reader is ready', () {
      final previous = dispatcher.resolve(
        command: const ReaderNavigationCommand.previousChapter(
          source: ReaderNavigationCommandSource.chrome,
        ),
        snapshot: _snapshot(currentChapterIndex: 1, chapterCount: 3),
      );
      final next = dispatcher.resolve(
        command: const ReaderNavigationCommand.nextChapter(
          source: ReaderNavigationCommandSource.chrome,
        ),
        snapshot: _snapshot(currentChapterIndex: 1, chapterCount: 3),
      );

      expect(previous.shouldExecute, isTrue);
      expect(next.shouldExecute, isTrue);
    });

    test('rejects chapter commands while content is loading', () {
      final decision = dispatcher.resolve(
        command: const ReaderNavigationCommand.nextChapter(
          source: ReaderNavigationCommandSource.chrome,
        ),
        snapshot: _snapshot(loadingContent: true),
      );

      expect(decision.shouldExecute, isFalse);
      expect(
        decision.rejectReason,
        ReaderNavigationCommandRejectReason.loading,
      );
      expect(decision.message, '章节正在加载，请稍后再试。');
    });

    test('rejects adjacent chapter boundaries', () {
      final previous = dispatcher.resolve(
        command: const ReaderNavigationCommand.previousChapter(),
        snapshot: _snapshot(currentChapterIndex: 0, chapterCount: 3),
      );
      final next = dispatcher.resolve(
        command: const ReaderNavigationCommand.nextChapter(),
        snapshot: _snapshot(currentChapterIndex: 2, chapterCount: 3),
      );

      expect(
        previous.rejectReason,
        ReaderNavigationCommandRejectReason.boundary,
      );
      expect(next.rejectReason, ReaderNavigationCommandRejectReason.boundary);
    });

    test('allows chapter navigation from error state', () {
      final decision = dispatcher.resolve(
        command: const ReaderNavigationCommand.nextChapter(),
        snapshot: _snapshot(hasError: true, currentChapterIndex: 1),
      );

      expect(decision.shouldExecute, isTrue);
    });

    test('rejects page commands while page turn is busy', () {
      final decision = dispatcher.resolve(
        command: const ReaderNavigationCommand.nextPage(
          source: ReaderNavigationCommandSource.swipe,
        ),
        snapshot: _snapshot(
          pageTurnBusy: true,
          pageTurnBusyReason: ReaderPageTurnBlockReason.paperCurlAnimating,
          pageTurnBusyMessage: '纸页卷动还在进行中，请稍后再试翻页。',
        ),
      );

      expect(decision.shouldExecute, isFalse);
      expect(
        decision.rejectReason,
        ReaderNavigationCommandRejectReason.pageTurnBusy,
      );
      expect(decision.message, contains('纸页卷动'));
    });

    test('validates jump chapter target', () {
      final invalid = dispatcher.resolve(
        command: const ReaderNavigationCommand.jumpChapter(
          targetChapterIndex: 5,
        ),
        snapshot: _snapshot(chapterCount: 3),
      );
      final valid = dispatcher.resolve(
        command: const ReaderNavigationCommand.jumpChapter(
          targetChapterIndex: 2,
        ),
        snapshot: _snapshot(chapterCount: 3),
      );

      expect(
        invalid.rejectReason,
        ReaderNavigationCommandRejectReason.invalidTarget,
      );
      expect(valid.shouldExecute, isTrue);
    });
  });
}

ReaderNavigationCommandSnapshot _snapshot({
  bool mounted = true,
  bool bootstrapping = false,
  bool loadingContent = false,
  bool pageTurnBusy = false,
  ReaderPageTurnBlockReason? pageTurnBusyReason,
  String? pageTurnBusyMessage,
  int chapterCount = 3,
  int? currentChapterIndex = 1,
  bool overlayVisible = false,
  bool isLocalContent = false,
  bool usesContinuousTextFlow = false,
  bool hasError = false,
}) {
  return ReaderNavigationCommandSnapshot(
    mounted: mounted,
    bootstrapping: bootstrapping,
    loadingContent: loadingContent,
    pageTurnBusy: pageTurnBusy,
    pageTurnBusyReason: pageTurnBusyReason,
    pageTurnBusyMessage: pageTurnBusyMessage,
    chapterCount: chapterCount,
    currentChapterIndex: currentChapterIndex,
    overlayVisible: overlayVisible,
    isLocalContent: isLocalContent,
    usesContinuousTextFlow: usesContinuousTextFlow,
    viewportKind: 'textPaged',
    contentMode: 'text',
    hasError: hasError,
  );
}
