import '../../../core/errors/app_exception.dart';
import '../../../core/membership/membership_access_presentation.dart';
import '../application/reader_source_switch_coordinator.dart';

class ReaderSwitchSourceMembershipDecision {
  const ReaderSwitchSourceMembershipDecision({
    required this.canProceed,
    this.message,
    this.shouldOpenMembership = false,
  });

  final bool canProceed;
  final String? message;
  final bool shouldOpenMembership;
}

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

  ReaderSwitchSourceMembershipDecision resolveMembershipDecision({
    required bool hasSession,
    required bool hasAccess,
  }) {
    if (!hasSession) {
      return ReaderSwitchSourceMembershipDecision(
        canProceed: false,
        message: MembershipAccessPresentation.unavailableMessage(
          MembershipFeatureGate.switchSource,
          isLoggedIn: false,
        ),
        shouldOpenMembership: true,
      );
    }
    if (!hasAccess) {
      return ReaderSwitchSourceMembershipDecision(
        canProceed: false,
        message: MembershipAccessPresentation.unavailableMessage(
          MembershipFeatureGate.switchSource,
          isLoggedIn: true,
        ),
        shouldOpenMembership: true,
      );
    }
    return const ReaderSwitchSourceMembershipDecision(canProceed: true);
  }

  ReaderSwitchSourceMembershipDecision resolveMembershipCheckFailure(
    Object error,
  ) {
    return ReaderSwitchSourceMembershipDecision(
      canProceed: false,
      message:
          error is AppException
              ? error.briefMessage
              : MembershipAccessPresentation.checkFailedMessage,
    );
  }
}
