import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/book/application/book_display_state.dart';

void main() {
  group('BookDisplayState', () {
    test('supports value equality', () {
      const left = BookDisplayState(
        displayTitle: '凡人修仙传',
        displayAuthor: '忘语',
        displayCoverSource: BookDisplayCoverSource.remote,
      );
      const right = BookDisplayState(
        displayTitle: '凡人修仙传',
        displayAuthor: '忘语',
        displayCoverSource: BookDisplayCoverSource.remote,
      );

      expect(left, right);
    });

    test('copyWith updates optional fields and preserves defaults', () {
      const state = BookDisplayState(
        displayTitle: '原始标题',
        displayCoverSource: BookDisplayCoverSource.none,
      );

      final next = state.copyWith(
        displayTitle: '展示标题',
        displayAuthor: '展示作者',
        displayCover: 'https://example.com/cover.jpg',
        displayCoverSource: BookDisplayCoverSource.remote,
        overrideUsed: true,
      );

      expect(next.displayTitle, '展示标题');
      expect(next.displayAuthor, '展示作者');
      expect(next.displayCover, 'https://example.com/cover.jpg');
      expect(next.displayCoverSource, BookDisplayCoverSource.remote);
      expect(next.overrideUsed, isTrue);
      expect(next.localMetadataUsed, isFalse);
    });
  });
}
