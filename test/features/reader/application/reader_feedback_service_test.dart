import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_feedback_service.dart';

void main() {
  group('ReaderFeedbackService', () {
    const service = ReaderFeedbackService();

    test('dedupes snack requests within window', () {
      final now = DateTime.parse('2026-04-28T12:00:00.000Z');
      final first = service.resolveSnackDecision(
        text: '提示',
        now: now,
        dedupeWindow: const Duration(milliseconds: 900),
        currentState: const ReaderSnackDedupState(),
      );
      final second = service.resolveSnackDecision(
        text: '提示',
        now: now.add(const Duration(milliseconds: 300)),
        dedupeWindow: const Duration(milliseconds: 900),
        currentState: first.nextState,
      );

      expect(first.shouldShow, isTrue);
      expect(second.shouldShow, isFalse);
    });

    test('prompts missing source switch only for eligible state', () {
      expect(
        service.shouldPromptSwitchSourceForMissingSource(
          canSwitchSource: true,
          code: ErrorCode.unknownSource,
          mounted: true,
          hasPromptedMissingSourceSwitch: false,
          isSwitchSourceLoading: false,
        ),
        isTrue,
      );
      expect(
        service.shouldPromptSwitchSourceForMissingSource(
          canSwitchSource: false,
          code: ErrorCode.unknownSource,
          mounted: true,
          hasPromptedMissingSourceSwitch: false,
          isSwitchSourceLoading: false,
        ),
        isFalse,
      );
    });
  });
}
