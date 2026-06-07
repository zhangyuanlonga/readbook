import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/ui/app_ui_unification_contracts.dart';

void main() {
  group('AppUiUnificationContract', () {
    test('baseline covers every BL-06 domain', () {
      const contract = AppUiUnificationContract.baseline;

      expect(contract.coversBl06, isTrue);
      expect(contract.pageSkeletons, containsAll(AppPageSkeletonKind.values));
      expect(
        contract.operationSurfaces,
        containsAll(AppOperationSurfaceKind.values),
      );
      expect(
        contract.stateComponents,
        containsAll(AppStateComponentKind.values),
      );
      expect(
        contract.toolbarCapabilities,
        containsAll(AppToolbarCapability.values),
      );
      expect(contract.tokenDomains, containsAll(AppTokenDomain.values));
      expect(
        contract.desktopInteractionStates,
        containsAll(AppDesktopInteractionState.values),
      );
      expect(
        contract.mobileAdaptiveRules,
        containsAll(AppMobileAdaptiveRule.values),
      );
    });

    test('mobile policy keeps safe area and small screen overflow rules', () {
      const policy = AppMobileInteractionPolicy();

      expect(policy.minTouchTarget, greaterThanOrEqualTo(44));
      expect(policy.shouldPreferOverflow(360), isTrue);
      expect(policy.shouldPreferOverflow(480), isFalse);
      expect(
        policy.safeAreaPaddingFor(const EdgeInsets.fromLTRB(4, 8, 12, 16)),
        const EdgeInsets.only(left: 4, right: 12, bottom: 16),
      );
    });

    test('desktop policy gives distinct visual feedback strengths', () {
      const policy = AppDesktopInteractionPolicy();
      const base = Color(0xFF336699);

      final hover = policy.overlayColor(
        baseColor: base,
        state: AppDesktopInteractionState.hover,
      );
      final selected = policy.overlayColor(
        baseColor: base,
        state: AppDesktopInteractionState.selected,
      );
      final disabled = policy.overlayColor(
        baseColor: base,
        state: AppDesktopInteractionState.disabled,
      );

      expect(hover.a, lessThan(selected.a));
      expect(selected.a, lessThan(disabled.a));
    });
  });
}
