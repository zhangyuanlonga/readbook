import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_performance_budget.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_resource_budget.dart';

void main() {
  group('ReaderPerformanceBudgetResolver', () {
    const resolver = ReaderPerformanceBudgetResolver();
    final normalBudget = const ReaderResourceBudgetResolver().resolve(
      const ReaderResourceBudgetInput(),
    );
    final constrainedBudget = const ReaderResourceBudgetResolver().resolve(
      const ReaderResourceBudgetInput(
        deviceTier: ReaderDeviceTier.low,
        batteryTier: ReaderBatteryTier.lowBattery,
      ),
    );

    test('keeps page turn budget tight for foreground interaction', () {
      final budget = resolver.resolve(
        scenario: ReaderPerformanceScenario.firstPageTurn,
        resourceBudget: normalBudget,
        isWeb: false,
      );

      expect(budget.targetLatency, const Duration(milliseconds: 120));
      expect(budget.mainIsolateBudget, const Duration(milliseconds: 8));
      expect(budget.strategy, ReaderLongTaskStrategy.immediate);
    });

    test('marks parser and pagination work as isolate or chunked tasks', () {
      final epub = resolver.resolve(
        scenario: ReaderPerformanceScenario.epubIndex,
        resourceBudget: normalBudget,
        isWeb: false,
      );
      final txt = resolver.resolve(
        scenario: ReaderPerformanceScenario.txtLargeFileIndex,
        resourceBudget: normalBudget,
        isWeb: false,
      );
      final pagination = resolver.resolve(
        scenario: ReaderPerformanceScenario.textPagination,
        resourceBudget: normalBudget,
        isWeb: false,
      );

      expect(epub.strategy, ReaderLongTaskStrategy.backgroundIsolate);
      expect(txt.strategy, ReaderLongTaskStrategy.chunkedYield);
      expect(pagination.strategy, ReaderLongTaskStrategy.backgroundIsolate);
    });

    test(
      'constrained resources expand latency but keep cache governance required',
      () {
        final normal = resolver.resolve(
          scenario: ReaderPerformanceScenario.imageDecode,
          resourceBudget: normalBudget,
          isWeb: false,
        );
        final constrained = resolver.resolve(
          scenario: ReaderPerformanceScenario.imageDecode,
          resourceBudget: constrainedBudget,
          isWeb: false,
        );

        expect(constrained.targetLatency, greaterThan(normal.targetLatency));
        expect(constrained.memoryBudgetMb, lessThan(normal.memoryBudgetMb));
        expect(constrained.cacheGovernanceRequired, isTrue);
      },
    );

    test(
      'web large chapter keeps low main-isolate budget and web memory cap',
      () {
        final budget = resolver.resolve(
          scenario: ReaderPerformanceScenario.webLargeChapter,
          resourceBudget: normalBudget,
          isWeb: true,
        );

        expect(budget.strategy, ReaderLongTaskStrategy.chunkedYield);
        expect(budget.mainIsolateBudget, const Duration(milliseconds: 8));
        expect(budget.memoryBudgetMb, 96);
      },
    );

    test('requires real target machines for Windows and Linux baselines', () {
      final macos = resolver.platformBaseline(
        platform: ReaderPerformancePlatform.macos,
        measuredInCurrentSession: true,
      );
      final windows = resolver.platformBaseline(
        platform: ReaderPerformancePlatform.windows,
        measuredInCurrentSession: false,
      );

      expect(macos.canUseCurrentSessionResult, isTrue);
      expect(windows.requiresTargetMachine, isTrue);
      expect(windows.canUseCurrentSessionResult, isFalse);
    });
  });
}
