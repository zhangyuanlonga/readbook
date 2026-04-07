import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_animation_policy.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_session.dart';

void main() {
  group('ReaderAnimationPolicyResolver', () {
    const resolver = ReaderAnimationPolicyResolver();

    test('text mode keeps page turn animation in text flow when allowed', () {
      final policy = resolver.resolve(
        contentMode: ReaderContentMode.text,
        hasInlineImageParagraphs: false,
        usesScrollTrigger: false,
      );

      expect(policy.usesShellOverlayAnimations, isTrue);
      expect(policy.supportsTextPageTurnAnimations, isTrue);
      expect(policy.usesMangaModeAnimations, isFalse);
      expect(policy.reusesTextPageTurnAnimations, isFalse);
      expect(policy.inactiveReason, isNull);
    });

    test('comic mode does not reuse text page turn animations', () {
      final policy = resolver.resolve(
        contentMode: ReaderContentMode.comic,
        hasInlineImageParagraphs: false,
        usesScrollTrigger: false,
      );

      expect(policy.supportsTextPageTurnAnimations, isFalse);
      expect(policy.usesMangaModeAnimations, isTrue);
      expect(policy.reusesTextPageTurnAnimations, isFalse);
      expect(policy.inactiveReason, contains('漫画模式'));
    });

    test('audio mode does not use page turn animations', () {
      final policy = resolver.resolve(
        contentMode: ReaderContentMode.audio,
        hasInlineImageParagraphs: false,
        usesScrollTrigger: false,
      );

      expect(policy.supportsTextPageTurnAnimations, isFalse);
      expect(policy.usesMangaModeAnimations, isFalse);
      expect(policy.reusesTextPageTurnAnimations, isFalse);
      expect(policy.inactiveReason, contains('听书模式'));
    });
  });
}
