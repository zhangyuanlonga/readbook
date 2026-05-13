enum ReaderDeviceTier { low, normal, high }

enum ReaderDevicePlatform { android, ios, desktop, web, unknown }

enum ReaderBatteryTier { lowBattery, normal }

enum ReaderNetworkTier { offline, metered, unmetered }

enum ReaderWorkScene { foregroundReading, backgroundPrefetch, cacheManagement }

class ReaderDeviceTierInput {
  const ReaderDeviceTierInput({
    this.platform = ReaderDevicePlatform.unknown,
    this.modelName,
    this.operatingSystemVersion,
    this.physicalMemoryMb,
    this.isPhysicalDevice,
    this.batteryLevel,
    this.scene = ReaderWorkScene.foregroundReading,
  });

  final ReaderDevicePlatform platform;
  final String? modelName;
  final String? operatingSystemVersion;
  final int? physicalMemoryMb;
  final bool? isPhysicalDevice;
  final int? batteryLevel;
  final ReaderWorkScene scene;
}

class ReaderDeviceTierResolver {
  const ReaderDeviceTierResolver();

  ReaderDeviceTier resolve(ReaderDeviceTierInput input) {
    final batteryLevel = input.batteryLevel;
    if (batteryLevel != null && batteryLevel <= 15) {
      return ReaderDeviceTier.low;
    }
    if (input.scene != ReaderWorkScene.foregroundReading &&
        batteryLevel != null &&
        batteryLevel <= 25) {
      return ReaderDeviceTier.low;
    }

    final memoryMb = input.physicalMemoryMb;
    if (memoryMb != null) {
      if (memoryMb < 3072) {
        return ReaderDeviceTier.low;
      }
      if (memoryMb >= 6144) {
        return ReaderDeviceTier.high;
      }
    }

    final modelName = input.modelName?.toLowerCase().trim() ?? '';
    if (_looksLikeLegacyPhone(modelName)) {
      return ReaderDeviceTier.low;
    }
    if (_looksLikeRecentFlagship(modelName)) {
      return ReaderDeviceTier.high;
    }

    if (input.platform == ReaderDevicePlatform.desktop) {
      return ReaderDeviceTier.high;
    }
    return ReaderDeviceTier.normal;
  }

  bool _looksLikeLegacyPhone(String modelName) {
    if (modelName.isEmpty) {
      return false;
    }
    const lowHints = <String>[
      'iphone 6',
      'iphone 7',
      'iphone 8',
      'iphone se',
      'redmi 6',
      'redmi 7',
      'redmi 8',
      'android go',
      'a10',
      'a20',
    ];
    return lowHints.any(modelName.contains);
  }

  bool _looksLikeRecentFlagship(String modelName) {
    if (modelName.isEmpty) {
      return false;
    }
    const highHints = <String>[
      'iphone 15',
      'iphone 16',
      'iphone 17',
      'ipad pro',
      'pixel 8',
      'pixel 9',
      'galaxy s23',
      'galaxy s24',
      'galaxy s25',
    ];
    return highHints.any(modelName.contains);
  }
}

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
