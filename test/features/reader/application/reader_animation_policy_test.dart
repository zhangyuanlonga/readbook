import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_animation_policy.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_session.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_mode_resolver.dart';

void main() {
  group('ReaderAnimationPolicyResolver', () {
    const resolver = ReaderAnimationPolicyResolver();
    const modeResolver = ReaderModeResolver();

    test('text mode keeps page turn animation in text flow when allowed', () {
      final mode = modeResolver.resolve(
        contentMode: ReaderContentMode.text,
        settings: const ReaderSettings(
          pageTurnMode: ReaderPageTurnMode.tapAndSwipe,
        ),
        canUsePagedText: true,
      );
      final policy = resolver.resolve(
        mode: mode,
        hasInlineImageParagraphs: false,
      );

      expect(policy.usesShellOverlayAnimations, isTrue);
      expect(policy.supportsTextPageTurnAnimations, isTrue);
      expect(policy.usesMangaModeAnimations, isFalse);
      expect(policy.reusesTextPageTurnAnimations, isFalse);
      expect(policy.inactiveReason, isNull);
    });

    test('comic mode does not reuse text page turn animations', () {
      final mode = modeResolver.resolve(
        contentMode: ReaderContentMode.comic,
        settings: const ReaderSettings(),
        canUsePagedText: false,
      );
      final policy = resolver.resolve(
        mode: mode,
        hasInlineImageParagraphs: false,
      );

      expect(policy.supportsTextPageTurnAnimations, isFalse);
      expect(policy.usesMangaModeAnimations, isTrue);
      expect(policy.reusesTextPageTurnAnimations, isFalse);
      expect(policy.inactiveReason, contains('漫画模式'));
    });

    test('audio mode does not use page turn animations', () {
      final mode = modeResolver.resolve(
        contentMode: ReaderContentMode.audio,
        settings: const ReaderSettings(),
        canUsePagedText: false,
      );
      final policy = resolver.resolve(
        mode: mode,
        hasInlineImageParagraphs: false,
      );

      expect(policy.supportsTextPageTurnAnimations, isFalse);
      expect(policy.usesMangaModeAnimations, isFalse);
      expect(policy.reusesTextPageTurnAnimations, isFalse);
      expect(policy.inactiveReason, contains('听书模式'));
    });

    test('inline image fallback disables paged text animation', () {
      final mode = modeResolver.resolve(
        contentMode: ReaderContentMode.text,
        settings: const ReaderSettings(
          pageTurnMode: ReaderPageTurnMode.tapAndSwipe,
        ),
        canUsePagedText: false,
      );
      final policy = resolver.resolve(
        mode: mode,
        hasInlineImageParagraphs: true,
      );

      expect(policy.supportsTextPageTurnAnimations, isFalse);
      expect(policy.inactiveReason, contains('包含插图'));
    });
  });
}
