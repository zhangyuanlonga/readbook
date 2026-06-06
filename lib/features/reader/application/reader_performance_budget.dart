import 'reader_resource_budget.dart';

enum ReaderPerformanceScenario {
  startupToFirstVisible,
  firstChapterLoad,
  firstPageTurn,
  chapterSwitch,
  catalogOpen,
  settingsOpen,
  textPagination,
  imageDecode,
  epubIndex,
  txtLargeFileIndex,
  pdfOpen,
  webLargeChapter,
}

enum ReaderLongTaskStrategy {
  immediate,
  debounceUi,
  chunkedYield,
  backgroundIsolate,
  lazyPage,
}

enum ReaderPerformancePlatform { android, ios, webJs, macos, windows, linux }

/// 阅读器性能预算策略。
///
/// 该策略把首屏、翻页、设置 / 目录打开、解析和 Web 大章节等场景的目标预算
/// 固定成可测试模型。真实耗时仍需真机 / 目标平台 smoke 采集，本模型只负责
/// 约束后续实现不要把长任务重新塞回 UI isolate。
class ReaderPerformanceBudgetResolver {
  const ReaderPerformanceBudgetResolver();

  ReaderPerformanceBudget resolve({
    required ReaderPerformanceScenario scenario,
    required ReaderResourceBudget resourceBudget,
    required bool isWeb,
  }) {
    final constrained =
        resourceBudget.chapterDownloadConcurrency <= 1 ||
        resourceBudget.imageDecodeScale < 1;
    final multiplier = constrained ? 1.35 : 1.0;
    switch (scenario) {
      case ReaderPerformanceScenario.startupToFirstVisible:
        return _budget(
          targetMs: 1500,
          mainIsolateMs: 32,
          multiplier: multiplier,
          strategy: ReaderLongTaskStrategy.immediate,
          memoryMb: isWeb ? 96 : 128,
        );
      case ReaderPerformanceScenario.firstChapterLoad:
        return _budget(
          targetMs: 1200,
          mainIsolateMs: 24,
          multiplier: multiplier,
          strategy: ReaderLongTaskStrategy.chunkedYield,
          memoryMb: isWeb ? 96 : 160,
        );
      case ReaderPerformanceScenario.firstPageTurn:
        return _budget(
          targetMs: 120,
          mainIsolateMs: 8,
          multiplier: multiplier,
          strategy: ReaderLongTaskStrategy.immediate,
          memoryMb: 64,
        );
      case ReaderPerformanceScenario.chapterSwitch:
        return _budget(
          targetMs: 700,
          mainIsolateMs: 16,
          multiplier: multiplier,
          strategy: ReaderLongTaskStrategy.chunkedYield,
          memoryMb: isWeb ? 96 : 128,
        );
      case ReaderPerformanceScenario.catalogOpen:
      case ReaderPerformanceScenario.settingsOpen:
        return _budget(
          targetMs: 250,
          mainIsolateMs: 12,
          multiplier: multiplier,
          strategy: ReaderLongTaskStrategy.debounceUi,
          memoryMb: 48,
        );
      case ReaderPerformanceScenario.textPagination:
        return _budget(
          targetMs: 450,
          mainIsolateMs: 8,
          multiplier: multiplier,
          strategy: ReaderLongTaskStrategy.backgroundIsolate,
          memoryMb: isWeb ? 96 : 128,
        );
      case ReaderPerformanceScenario.imageDecode:
        return _budget(
          targetMs: 350,
          mainIsolateMs: 8,
          multiplier: multiplier,
          strategy: ReaderLongTaskStrategy.lazyPage,
          memoryMb:
              resourceBudget.imageDecodeScale < 1
                  ? 48
                  : isWeb
                  ? 96
                  : 128,
        );
      case ReaderPerformanceScenario.epubIndex:
        return _budget(
          targetMs: 3000,
          mainIsolateMs: 16,
          multiplier: multiplier,
          strategy: ReaderLongTaskStrategy.backgroundIsolate,
          memoryMb: isWeb ? 128 : 192,
        );
      case ReaderPerformanceScenario.txtLargeFileIndex:
        return _budget(
          targetMs: 3000,
          mainIsolateMs: 8,
          multiplier: multiplier,
          strategy: ReaderLongTaskStrategy.chunkedYield,
          memoryMb: isWeb ? 96 : 160,
        );
      case ReaderPerformanceScenario.pdfOpen:
        return _budget(
          targetMs: 1800,
          mainIsolateMs: 16,
          multiplier: multiplier,
          strategy: ReaderLongTaskStrategy.lazyPage,
          memoryMb: isWeb ? 128 : 192,
        );
      case ReaderPerformanceScenario.webLargeChapter:
        return _budget(
          targetMs: 2200,
          mainIsolateMs: 8,
          multiplier: multiplier,
          strategy: ReaderLongTaskStrategy.chunkedYield,
          memoryMb: 96,
        );
    }
  }

  ReaderPlatformPerformanceBaseline platformBaseline({
    required ReaderPerformancePlatform platform,
    required bool measuredInCurrentSession,
  }) {
    final needsTargetMachine =
        platform == ReaderPerformancePlatform.windows ||
        platform == ReaderPerformancePlatform.linux;
    return ReaderPlatformPerformanceBaseline(
      platform: platform,
      measuredInCurrentSession: measuredInCurrentSession,
      requiresTargetMachine: needsTargetMachine,
      canUseCurrentSessionResult:
          measuredInCurrentSession && !needsTargetMachine,
    );
  }

  ReaderPerformanceBudget _budget({
    required int targetMs,
    required int mainIsolateMs,
    required double multiplier,
    required ReaderLongTaskStrategy strategy,
    required int memoryMb,
  }) {
    return ReaderPerformanceBudget(
      targetLatency: Duration(milliseconds: (targetMs * multiplier).round()),
      mainIsolateBudget: Duration(milliseconds: mainIsolateMs),
      strategy: strategy,
      memoryBudgetMb: memoryMb,
      cacheGovernanceRequired: true,
    );
  }
}

class ReaderPerformanceBudget {
  const ReaderPerformanceBudget({
    required this.targetLatency,
    required this.mainIsolateBudget,
    required this.strategy,
    required this.memoryBudgetMb,
    required this.cacheGovernanceRequired,
  });

  final Duration targetLatency;
  final Duration mainIsolateBudget;
  final ReaderLongTaskStrategy strategy;
  final int memoryBudgetMb;
  final bool cacheGovernanceRequired;
}

class ReaderPlatformPerformanceBaseline {
  const ReaderPlatformPerformanceBaseline({
    required this.platform,
    required this.measuredInCurrentSession,
    required this.requiresTargetMachine,
    required this.canUseCurrentSessionResult,
  });

  final ReaderPerformancePlatform platform;
  final bool measuredInCurrentSession;
  final bool requiresTargetMachine;
  final bool canUseCurrentSessionResult;
}
