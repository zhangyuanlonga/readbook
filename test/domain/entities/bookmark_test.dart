import 'package:shuxiang_reading_next/domain/entities/bookmark.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bookmark', () {
    test('supports toJson and fromJson', () {
      final now = DateTime.parse('2026-03-14T00:00:00.000Z');
      final bookmark = Bookmark(
        id: 'bm_1',
        bookId: 'book_1',
        chapterId: 'chapter_1',
        chapterIndex: 3,
        startOffset: 12,
        endOffset: 34,
        snippet: '这是一段喜欢的句子。',
        createdAt: now,
        updatedAt: now,
        isBold: true,
        isUnderline: true,
        isWavy: true,
        color: '#FFCC00',
      );

      final restored = Bookmark.fromJson(bookmark.toJson());

      expect(restored.id, bookmark.id);
      expect(restored.bookId, bookmark.bookId);
      expect(restored.chapterId, bookmark.chapterId);
      expect(restored.chapterIndex, bookmark.chapterIndex);
      expect(restored.startOffset, bookmark.startOffset);
      expect(restored.endOffset, bookmark.endOffset);
      expect(restored.snippet, bookmark.snippet);
      expect(restored.createdAt, bookmark.createdAt);
      expect(restored.updatedAt, bookmark.updatedAt);
      expect(restored.isBold, isTrue);
      expect(restored.isUnderline, isTrue);
      expect(restored.isWavy, isTrue);
      expect(restored.color, bookmark.color);
    });

    test('defaults style flags to false when missing', () {
      final restored = Bookmark.fromJson({
        'id': 'bm_legacy',
        'bookId': 'book_legacy',
        'chapterId': 'chapter_legacy',
        'chapterIndex': 1,
        'startOffset': 2,
        'endOffset': 5,
        'snippet': 'legacy',
        'createdAt': '2026-03-14T00:00:00.000Z',
        'updatedAt': '2026-03-14T00:00:00.000Z',
      });

      expect(restored.isBold, isFalse);
      expect(restored.isUnderline, isFalse);
      expect(restored.isWavy, isFalse);
    });
  });
}
