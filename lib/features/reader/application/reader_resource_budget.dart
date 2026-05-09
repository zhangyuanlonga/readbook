enum ReaderDeviceTier { low, normal, high }

enum ReaderBatteryTier { lowBattery, normal }

enum ReaderNetworkTier { offline, metered, unmetered }

enum ReaderWorkScene { foregroundReading, backgroundPrefetch, cacheManagement }

class ReaderResourceBudgetInput {
  const ReaderResourceBudgetInput({
    this.deviceTier = ReaderDeviceTier.normal,
    this.batteryTier = ReaderBatteryTier.normal,
    this.networkTier = ReaderNetworkTier.unmetered,
    this.scene = ReaderWorkScene.foregroundReading,
  });

  final ReaderDeviceTier deviceTier;
  final ReaderBatteryTier batteryTier;
  final ReaderNetworkTier networkTier;
  final ReaderWorkScene scene;
}

class ReaderResourceBudget {
  const ReaderResourceBudget({
    required this.forwardPreloadChapterCount,
    required this.backwardPreloadChapterCount,
    required this.chapterDownloadConcurrency,
    required this.webViewConcurrency,
    required this.mangaCacheExtent,
    required this.paginationMemoryEntries,
    required this.imageDecodeScale,
    required this.allowFarPrefetch,
  });

  final int forwardPreloadChapterCount;
  final int backwardPreloadChapterCount;
  final int chapterDownloadConcurrency;
  final int webViewConcurrency;
  final double mangaCacheExtent;
  final int paginationMemoryEntries;
  final double imageDecodeScale;
  final bool allowFarPrefetch;
}

class ReaderResourceBudgetResolver {
  const ReaderResourceBudgetResolver();

  ReaderResourceBudget resolve(ReaderResourceBudgetInput input) {
    final constrained =
        input.deviceTier == ReaderDeviceTier.low ||
        input.batteryTier == ReaderBatteryTier.lowBattery ||
        input.networkTier != ReaderNetworkTier.unmetered;
    final offline = input.networkTier == ReaderNetworkTier.offline;
    final background = input.scene == ReaderWorkScene.backgroundPrefetch;
    final lowDevice = input.deviceTier == ReaderDeviceTier.low;
    final highDevice = input.deviceTier == ReaderDeviceTier.high;

    return ReaderResourceBudget(
      forwardPreloadChapterCount:
          offline
              ? 0
              : constrained
              ? 1
              : background
              ? 2
              : 3,
      backwardPreloadChapterCount:
          offline
              ? 0
              : constrained
              ? 0
              : 1,
      chapterDownloadConcurrency:
          offline
              ? 0
              : constrained
              ? 1
              : 2,
      webViewConcurrency:
          offline
              ? 0
              : constrained
              ? 1
              : 2,
      mangaCacheExtent:
          lowDevice
              ? 900
              : highDevice && !constrained
              ? 3200
              : constrained
              ? 1200
              : 1800,
      paginationMemoryEntries:
          lowDevice
              ? 12
              : highDevice && !constrained
              ? 36
              : 24,
      imageDecodeScale:
          lowDevice || constrained
              ? 0.75
              : highDevice
              ? 1.25
              : 1,
      allowFarPrefetch: !offline && !constrained && !background,
    );
  }
}
