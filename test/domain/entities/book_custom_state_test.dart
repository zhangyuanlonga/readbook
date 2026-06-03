import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/book_custom_state.dart';

void main() {
  group('BookCustomState', () {
    test('supports toJson and fromJson roundtrip', () {
      final state = BookCustomState(
        bookId: 'book_1',
        sourceId: 'source_a',
        detailUrl: 'https://example.com/book/1',
        updatedAt: DateTime.parse('2026-06-03T12:00:00.000Z'),
        customVariableJson: '{"token":"abc"}',
      );

      final restored = BookCustomState.fromJson(state.toJson());

      expect(restored.bookId, state.bookId);
      expect(restored.sourceId, state.sourceId);
      expect(restored.detailUrl, state.detailUrl);
      expect(restored.customVariableJson, state.customVariableJson);
      expect(restored.updatedAt, state.updatedAt);
    });

    test('copyWith can clear custom variable payload', () {
      final state = BookCustomState(
        bookId: 'book_1',
        sourceId: 'source_a',
        detailUrl: 'https://example.com/book/1',
        updatedAt: DateTime.parse('2026-06-03T12:00:00.000Z'),
        customVariableJson: '{"token":"abc"}',
      );

      final cleared = state.copyWith(clearCustomVariableJson: true);

      expect(cleared.customVariableJson, isNull);
      expect(cleared.isEmpty, isTrue);
    });
  });
}
