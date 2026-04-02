import 'package:flutter_appread/features/reader/application/reader_logical_position.dart';
import 'package:flutter_appread/features/reader/application/reader_session_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReaderSessionState', () {
    const baseState = ReaderSessionState(
      currentChapterIndex: 3,
      currentChapterId: 'chapter_3',
      currentChapterUrl: 'https://example.com/3',
      currentChapterTitle: '第三章',
      logicalPosition: ReaderLogicalPosition(
        chapterIndex: 3,
        blockIndex: 1,
        offsetInBlock: 12,
        chapterPositionRatio: 0.42,
      ),
      visiblePosition: ReaderVisiblePosition(pageIndex: 5, pageCount: 10),
      rendererKind: TextReaderRendererKind.paged,
      isAutoReading: false,
      isChapterTransitioning: false,
    );

    test('keeps visible position information after copyWith', () {
      final updated = baseState.copyWith(
        visiblePosition: const ReaderVisiblePosition(
          scrollOffset: 320,
          maxScrollExtent: 860,
        ),
        rendererKind: TextReaderRendererKind.scroll,
      );

      expect(updated.visiblePosition.scrollOffset, 320);
      expect(updated.visiblePosition.maxScrollExtent, 860);
      expect(updated.visiblePosition.pageIndex, isNull);
      expect(updated.rendererKind, TextReaderRendererKind.scroll);
    });
  });
}
