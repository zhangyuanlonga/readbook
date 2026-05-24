import '../application/reader_source_switch_coordinator.dart';

class ReaderSourceSwitchController {
  const ReaderSourceSwitchController({
    ReaderSourceSwitchCoordinator coordinator =
        const ReaderSourceSwitchCoordinator(),
  }) : _coordinator = coordinator;

  final ReaderSourceSwitchCoordinator _coordinator;

  Future<ReaderSwitchSourceScopePlan> buildSwitchSourceScope({
    required String currentSourceId,
    required bool isMangaChapter,
  }) async {
    return _coordinator.buildServerGatewaySwitchScope(
      fallbackIsMangaType: isMangaChapter,
    );
  }

  bool canAutoSwitchSourceOnFailure({
    required bool canSwitchSource,
    required bool autoSwitchSourceOnFailureEnabled,
    required bool isAutoSwitchingSource,
    required bool isSwitchSourceLoading,
    required String? sourceId,
    required String? detailUrl,
  }) {
    return _coordinator.canAutoSwitchOnFailure(
      canSwitchSource: canSwitchSource,
      autoSwitchSourceOnFailureEnabled: autoSwitchSourceOnFailureEnabled,
      isAutoSwitchingSource: isAutoSwitchingSource,
      isSwitchSourceLoading: isSwitchSourceLoading,
      sourceId: sourceId,
      detailUrl: detailUrl,
    );
  }

  String formatSignedScore(int score) {
    return score > 0 ? '+$score' : '$score';
  }
}
