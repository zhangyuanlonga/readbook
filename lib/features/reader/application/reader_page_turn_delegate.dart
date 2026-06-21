import '../../../domain/entities/reader_settings.dart';

class ReaderPageTurnDelegateRequest {
  const ReaderPageTurnDelegateRequest({required this.requestedStyle});

  final ReaderPageAnimationStyle requestedStyle;
}

class ReaderPageTurnDelegateDecision {
  const ReaderPageTurnDelegateDecision({
    required this.requestedStyle,
    required this.effectiveStyle,
    required this.reason,
  });

  final ReaderPageAnimationStyle requestedStyle;
  final ReaderPageAnimationStyle effectiveStyle;
  final String reason;
}

/// Keeps page-turn capability decisions explicit for the layout release surface.
class ReaderPageTurnDelegate {
  const ReaderPageTurnDelegate();

  ReaderPageTurnDelegateDecision resolve(
    ReaderPageTurnDelegateRequest request,
  ) {
    if (_layoutReleaseSupports(request.requestedStyle)) {
      return ReaderPageTurnDelegateDecision(
        requestedStyle: request.requestedStyle,
        effectiveStyle: request.requestedStyle,
        reason: 'layout_release_supported',
      );
    }

    return ReaderPageTurnDelegateDecision(
      requestedStyle: request.requestedStyle,
      effectiveStyle: ReaderPageAnimationStyle.none,
      reason: 'layout_release_degraded_to_none',
    );
  }

  bool _layoutReleaseSupports(ReaderPageAnimationStyle _) {
    return true;
  }
}
