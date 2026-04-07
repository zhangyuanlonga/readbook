import 'audio_reading_mode.dart';
import 'reader_content_session.dart';

class ReaderAnimationPolicy {
  const ReaderAnimationPolicy({
    required this.usesShellOverlayAnimations,
    required this.supportsTextPageTurnAnimations,
    required this.usesMangaModeAnimations,
    required this.reusesTextPageTurnAnimations,
    this.inactiveReason,
  });

  final bool usesShellOverlayAnimations;
  final bool supportsTextPageTurnAnimations;
  final bool usesMangaModeAnimations;
  final bool reusesTextPageTurnAnimations;
  final String? inactiveReason;
}

class ReaderAnimationPolicyResolver {
  const ReaderAnimationPolicyResolver();

  ReaderAnimationPolicy resolve({
    required ReaderContentMode contentMode,
    required bool hasInlineImageParagraphs,
    required bool usesScrollTrigger,
  }) {
    switch (contentMode) {
      case ReaderContentMode.text:
        if (usesScrollTrigger) {
          return const ReaderAnimationPolicy(
            usesShellOverlayAnimations: true,
            supportsTextPageTurnAnimations: false,
            usesMangaModeAnimations: false,
            reusesTextPageTurnAnimations: false,
            inactiveReason: '滚动触发模式下不使用分页动画。',
          );
        }
        if (hasInlineImageParagraphs) {
          return const ReaderAnimationPolicy(
            usesShellOverlayAnimations: true,
            supportsTextPageTurnAnimations: false,
            usesMangaModeAnimations: false,
            reusesTextPageTurnAnimations: false,
            inactiveReason: '当前章节包含插图，已退回滚动正文，本章不会展示分页动画。',
          );
        }
        return const ReaderAnimationPolicy(
          usesShellOverlayAnimations: true,
          supportsTextPageTurnAnimations: true,
          usesMangaModeAnimations: false,
          reusesTextPageTurnAnimations: false,
        );
      case ReaderContentMode.comic:
        return const ReaderAnimationPolicy(
          usesShellOverlayAnimations: true,
          supportsTextPageTurnAnimations: false,
          usesMangaModeAnimations: true,
          reusesTextPageTurnAnimations: false,
          inactiveReason: '漫画模式使用独立的翻图与缩放反馈，不复用正文分页动画。',
        );
      case ReaderContentMode.audio:
        return const ReaderAnimationPolicy(
          usesShellOverlayAnimations: true,
          supportsTextPageTurnAnimations: false,
          usesMangaModeAnimations: false,
          reusesTextPageTurnAnimations: false,
          inactiveReason: '听书模式不使用正文翻页动画。',
        );
    }
  }

  ReaderAnimationPolicy resolveForAudio(AudioReadingMode mode) {
    return const ReaderAnimationPolicy(
      usesShellOverlayAnimations: true,
      supportsTextPageTurnAnimations: false,
      usesMangaModeAnimations: false,
      reusesTextPageTurnAnimations: false,
      inactiveReason: '听书模式不使用正文翻页动画。',
    );
  }
}
