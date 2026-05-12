import 'package:shuxiang_reading_next/features/reader/application/source_switch_score_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SourceSwitchScoreService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('adjusts and resets book/source scores incrementally', () async {
      final service = SourceSwitchScoreService();

      final added = await service.adjustBookScore(
        sourceId: 'source_a',
        title: '凡人修仙传',
        author: '忘语',
        delta: 6,
      );
      expect(added.bookScore, 6);
      expect(added.sourceScore, 6);

      final deducted = await service.adjustBookScore(
        sourceId: 'source_a',
        title: '凡人修仙传',
        author: '忘语',
        delta: -2,
      );
      expect(deducted.bookScore, 4);
      expect(deducted.sourceScore, 4);

      final reset = await service.resetBookScore(
        sourceId: 'source_a',
        title: '凡人修仙传',
        author: '忘语',
      );
      expect(reset.bookScore, 0);
      expect(reset.sourceScore, 0);
    });

    test('loads stored non-zero score entries', () async {
      final service = SourceSwitchScoreService();

      await service.adjustBookScore(
        sourceId: 'source_a',
        title: '凡人修仙传',
        author: '忘语',
        delta: 3,
      );
      await service.adjustBookScore(
        sourceId: 'source_b',
        title: '凡人修仙传',
        author: '忘语',
        delta: -1,
      );

      final store = await service.loadStore();
      final keyA = service.buildBookScoreKey(
        sourceId: 'source_a',
        title: '凡人修仙传',
        author: '忘语',
      );
      final keyB = service.buildBookScoreKey(
        sourceId: 'source_b',
        title: '凡人修仙传',
        author: '忘语',
      );

      expect(store.sourceScores['source_a'], 3);
      expect(store.sourceScores['source_b'], -1);
      expect(store.bookScores[keyA], 3);
      expect(store.bookScores[keyB], -1);
    });
  });
}
