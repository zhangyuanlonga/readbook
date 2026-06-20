import '../../../domain/entities/reader_settings.dart';

enum ReaderPageTurnRendererSurface { legacy, layoutRelease }

enum ReaderPageTurnDelegateDecisionType { useRequestedStyle, useLegacyFallback }

class ReaderPageTurnDelegateRequest {
  const ReaderPageTurnDelegateRequest({
    required this.surface,
    required this.requestedStyle,
    this.canUseLegacyFallback = true,
  });

  final ReaderPageTurnRendererSurface surface;
  final ReaderPageAnimationStyle requestedStyle;
  final bool canUseLegacyFallback;
}

class ReaderPageTurnDelegateDecision {
  const ReaderPageTurnDelegateDecision({
    required this.type,
    required this.requestedStyle,
    required this.effectiveStyle,
    required this.reason,
  });

  final ReaderPageTurnDelegateDecisionType type;
  final ReaderPageAnimationStyle requestedStyle;
  final ReaderPageAnimationStyle effectiveStyle;
  final String reason;

  bool get usesLegacyFallback =>
      type == ReaderPageTurnDelegateDecisionType.useLegacyFallback;
}

/// Keeps old page-turn capabilities available while the layout renderer catches up.
class ReaderPageTurnDelegate {
  const ReaderPageTurnDelegate();

  ReaderPageTurnDelegateDecision resolve(
    ReaderPageTurnDelegateRequest request,
  ) {
    if (request.surface != ReaderPageTurnRendererSurface.layoutRelease) {
      return ReaderPageTurnDelegateDecision(
        type: ReaderPageTurnDelegateDecisionType.useRequestedStyle,
        requestedStyle: request.requestedStyle,
        effectiveStyle: request.requestedStyle,
        reason: 'legacy_renderer',
      );
    }

    if (_layoutReleaseSupports(request.requestedStyle)) {
      return ReaderPageTurnDelegateDecision(
        type: ReaderPageTurnDelegateDecisionType.useRequestedStyle,
        requestedStyle: request.requestedStyle,
        effectiveStyle: request.requestedStyle,
        reason: 'layout_release_supported',
      );
    }

    if (request.canUseLegacyFallback) {
      return ReaderPageTurnDelegateDecision(
        type: ReaderPageTurnDelegateDecisionType.useLegacyFallback,
        requestedStyle: request.requestedStyle,
        effectiveStyle: request.requestedStyle,
        reason: 'layout_release_page_animation_requires_legacy',
      );
    }

    return ReaderPageTurnDelegateDecision(
      type: ReaderPageTurnDelegateDecisionType.useRequestedStyle,
      requestedStyle: request.requestedStyle,
      effectiveStyle: ReaderPageAnimationStyle.none,
      reason: 'layout_release_degraded_to_none',
    );
  }

  bool _layoutReleaseSupports(ReaderPageAnimationStyle style) {
    return style == ReaderPageAnimationStyle.none;
  }
}
