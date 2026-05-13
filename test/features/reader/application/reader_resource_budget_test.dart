import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_resource_budget.dart';

void main() {
  group('ReaderResourceBudgetResolver', () {
    const resolver = ReaderResourceBudgetResolver();

    test('normal foreground reading keeps balanced budgets', () {
      final budget = resolver.resolve(const ReaderResourceBudgetInput());

      expect(budget.forwardPreloadChapterCount, greaterThanOrEqualTo(2));
      expect(budget.chapterDownloadConcurrency, 2);
      expect(budget.mangaCacheExtent, 1800);
      expect(budget.paginationMemoryEntries, 24);
    });

    test('low battery constrains background work', () {
      final budget = resolver.resolve(
        const ReaderResourceBudgetInput(
          batteryTier: ReaderBatteryTier.lowBattery,
          scene: ReaderWorkScene.backgroundPrefetch,
        ),
      );

      expect(budget.forwardPreloadChapterCount, 1);
      expect(budget.backwardPreloadChapterCount, 0);
      expect(budget.chapterDownloadConcurrency, 1);
      expect(budget.allowFarPrefetch, isFalse);
    });

    test('offline disables network prefetch', () {
      final budget = resolver.resolve(
        const ReaderResourceBudgetInput(networkTier: ReaderNetworkTier.offline),
      );

      expect(budget.forwardPreloadChapterCount, 0);
      expect(budget.chapterDownloadConcurrency, 0);
      expect(budget.webViewConcurrency, 0);
    });

    test('device tier resolver grades low battery and recent devices', () {
      const tierResolver = ReaderDeviceTierResolver();

      expect(
        tierResolver.resolve(
          const ReaderDeviceTierInput(
            platform: ReaderDevicePlatform.android,
            physicalMemoryMb: 2048,
          ),
        ),
        ReaderDeviceTier.low,
      );
      expect(
        tierResolver.resolve(
          const ReaderDeviceTierInput(
            platform: ReaderDevicePlatform.ios,
            modelName: 'iPhone 16 Plus',
            batteryLevel: 80,
          ),
        ),
        ReaderDeviceTier.high,
      );
      expect(
        tierResolver.resolve(
          const ReaderDeviceTierInput(
            platform: ReaderDevicePlatform.ios,
            modelName: 'iPhone 16 Plus',
            batteryLevel: 10,
          ),
        ),
        ReaderDeviceTier.low,
      );
    });
  });
}
