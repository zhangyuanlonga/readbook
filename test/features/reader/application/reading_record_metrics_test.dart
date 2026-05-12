import 'package:shuxiang_reading_next/features/reader/application/reading_record_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('estimateSessionReadChars', () {
    test('counts only forward progress by default', () {
      final value = estimateSessionReadChars(
        chapterLength: 1000,
        startRatio: 0.2,
        endRatio: 0.6,
      );

      expect(value, 400);
    });

    test('uses furthest progress when user drags back before commit', () {
      final value = estimateSessionReadChars(
        chapterLength: 1000,
        startRatio: 0.1,
        endRatio: 0.3,
        furthestRatio: 0.8,
      );

      expect(value, 700);
    });

    test('does not count backward-only movement as new chars', () {
      final value = estimateSessionReadChars(
        chapterLength: 1000,
        startRatio: 0.7,
        endRatio: 0.4,
      );

      expect(value, 0);
    });

    test('returns zero for manga or non-text content', () {
      final value = estimateSessionReadChars(
        chapterLength: 1200,
        startRatio: 0.0,
        endRatio: 1.0,
        countAsText: false,
      );

      expect(value, 0);
    });
  });
}
