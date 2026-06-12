import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_source_switch_coordinator.dart';

void main() {
  group('ReaderSourceSwitchCoordinator', () {
    const coordinator = ReaderSourceSwitchCoordinator();

    test('validates manual switch source request from context', () {
      final result = coordinator.validateManualSwitchRequestContext(
        const ReaderSwitchSourceRequestContext(
          isSwitchSourceLoading: false,
          canSwitchSource: true,
          sourceId: 'source-a',
          detailUrl: 'https://example.com/book/1',
        ),
      );

      expect(result.canProceed, isTrue);
      expect(result.currentSourceId, 'source-a');
      expect(result.currentDetailUrl, 'https://example.com/book/1');
    });

    test('blocks manual switch source request with missing identity', () {
      final result = coordinator.validateManualSwitchRequestContext(
        const ReaderSwitchSourceRequestContext(
          isSwitchSourceLoading: false,
          canSwitchSource: true,
          sourceId: ' ',
          detailUrl: null,
        ),
      );

      expect(result.canProceed, isFalse);
      expect(result.message, '缺少当前书源信息，暂时无法换源。');
    });

    test('checks auto switch source eligibility from context', () {
      final allowed = coordinator.canAutoSwitchOnFailureContext(
        const ReaderSwitchSourceRequestContext(
          isSwitchSourceLoading: false,
          canSwitchSource: true,
          sourceId: 'source-a',
          detailUrl: 'detail://a',
        ),
        autoSwitchSourceOnFailureEnabled: true,
        isAutoSwitchingSource: false,
      );

      expect(allowed, isTrue);
    });
  });
}
