import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_session.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_anchor_readiness_policy.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_mode_model.dart';

void main() {
  group('ReaderLayoutAnchorReadinessPolicy', () {
    const policy = ReaderLayoutAnchorReadinessPolicy();

    test('uses layout anchors when release text pages are ready', () {
      final decision = policy.resolve(
        consumer: ReaderLayoutAnchorConsumer.search,
        snapshot: const ReaderLayoutAnchorReadinessSnapshot(
          contentMode: ReaderContentMode.text,
          viewportKind: ReaderModeViewportKind.textPaged,
          releaseActive: true,
          layoutPageCount: 3,
          layoutSignature: 'sig',
        ),
      );

      expect(decision.usesLayoutAnchor, isTrue);
      expect(decision.layoutSignature, 'sig');
      expect(decision.reason, 'search_uses_layout_range');
    });

    test('blocks release anchors until layout pages are ready', () {
      final decision = policy.resolve(
        consumer: ReaderLayoutAnchorConsumer.readAloud,
        snapshot: const ReaderLayoutAnchorReadinessSnapshot(
          contentMode: ReaderContentMode.text,
          viewportKind: ReaderModeViewportKind.textPaged,
          releaseActive: true,
          layoutPageCount: 0,
        ),
      );

      expect(decision.type, ReaderLayoutAnchorReadinessType.blocked);
      expect(decision.reason, 'layout_pages_not_ready');
    });

    test('uses non-layout anchors for inactive or non paged text surfaces', () {
      final inactive = policy.resolve(
        consumer: ReaderLayoutAnchorConsumer.search,
        snapshot: const ReaderLayoutAnchorReadinessSnapshot(
          contentMode: ReaderContentMode.text,
          viewportKind: ReaderModeViewportKind.textPaged,
          releaseActive: false,
          layoutPageCount: 0,
        ),
      );
      final scroll = policy.resolve(
        consumer: ReaderLayoutAnchorConsumer.search,
        snapshot: const ReaderLayoutAnchorReadinessSnapshot(
          contentMode: ReaderContentMode.text,
          viewportKind: ReaderModeViewportKind.textScroll,
          releaseActive: false,
          layoutPageCount: 0,
        ),
      );

      expect(inactive.type, ReaderLayoutAnchorReadinessType.nonLayoutAnchor);
      expect(scroll.type, ReaderLayoutAnchorReadinessType.nonLayoutAnchor);
      expect(scroll.reason, 'non_paged_text_uses_scroll_anchor');
    });

    test('keeps audio progress outside text layout anchors', () {
      final decision = policy.resolve(
        consumer: ReaderLayoutAnchorConsumer.audioProgress,
        snapshot: const ReaderLayoutAnchorReadinessSnapshot(
          contentMode: ReaderContentMode.audio,
          viewportKind: ReaderModeViewportKind.audio,
          releaseActive: false,
          layoutPageCount: 0,
        ),
      );

      expect(decision.type, ReaderLayoutAnchorReadinessType.notApplicable);
      expect(decision.reason, 'audio_surface_uses_audio_progress');
    });
  });
}
