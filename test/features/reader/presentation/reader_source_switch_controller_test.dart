import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_source_switch_controller.dart';

void main() {
  group('ReaderSourceSwitchController', () {
    const controller = ReaderSourceSwitchController();

    test('formats signed score with explicit plus sign', () {
      expect(controller.formatSignedScore(2), '+2');
      expect(controller.formatSignedScore(-1), '-1');
    });

    test('delegates auto switch eligibility gate', () {
      final allowed = controller.canAutoSwitchSourceOnFailure(
        canSwitchSource: true,
        autoSwitchSourceOnFailureEnabled: true,
        isAutoSwitchingSource: false,
        isSwitchSourceLoading: false,
        sourceId: 'source-a',
        detailUrl: 'detail://a',
      );

      expect(allowed, isTrue);
    });

    test('blocks switch source when membership session is missing', () {
      final decision = controller.resolveMembershipDecision(
        hasSession: false,
        hasAccess: false,
      );

      expect(decision.canProceed, isFalse);
      expect(decision.shouldOpenMembership, isTrue);
      expect(decision.message, contains('请先登录'));
    });

    test('blocks switch source when membership access is missing', () {
      final decision = controller.resolveMembershipDecision(
        hasSession: true,
        hasAccess: false,
      );

      expect(decision.canProceed, isFalse);
      expect(decision.shouldOpenMembership, isTrue);
      expect(decision.message, contains('开通会员'));
    });

    test('allows switch source when membership access is available', () {
      final decision = controller.resolveMembershipDecision(
        hasSession: true,
        hasAccess: true,
      );

      expect(decision.canProceed, isTrue);
      expect(decision.shouldOpenMembership, isFalse);
      expect(decision.message, isNull);
    });
  });
}
