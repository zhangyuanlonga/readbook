import 'reader_content_session.dart';
import 'reader_mode_model.dart';

enum ReaderLayoutAnchorConsumer { search, readAloud, autoRead, audioProgress }

enum ReaderLayoutAnchorReadinessType {
  layoutAnchor,
  nonLayoutAnchor,
  blocked,
  notApplicable,
}

class ReaderLayoutAnchorReadinessSnapshot {
  const ReaderLayoutAnchorReadinessSnapshot({
    required this.contentMode,
    required this.viewportKind,
    required this.releaseActive,
    required this.layoutPageCount,
    this.layoutSignature,
  });

  final ReaderContentMode contentMode;
  final ReaderModeViewportKind viewportKind;
  final bool releaseActive;
  final int layoutPageCount;
  final String? layoutSignature;

  bool get hasLayoutPages => layoutPageCount > 0;
  bool get isTextPaged => viewportKind == ReaderModeViewportKind.textPaged;
}

class ReaderLayoutAnchorReadinessDecision {
  const ReaderLayoutAnchorReadinessDecision({
    required this.type,
    required this.reason,
    this.layoutSignature,
  });

  final ReaderLayoutAnchorReadinessType type;
  final String reason;
  final String? layoutSignature;

  bool get usesLayoutAnchor =>
      type == ReaderLayoutAnchorReadinessType.layoutAnchor;
}

class ReaderLayoutAnchorReadinessPolicy {
  const ReaderLayoutAnchorReadinessPolicy();

  ReaderLayoutAnchorReadinessDecision resolve({
    required ReaderLayoutAnchorConsumer consumer,
    required ReaderLayoutAnchorReadinessSnapshot snapshot,
  }) {
    if (consumer == ReaderLayoutAnchorConsumer.audioProgress) {
      return const ReaderLayoutAnchorReadinessDecision(
        type: ReaderLayoutAnchorReadinessType.notApplicable,
        reason: 'audio_surface_uses_audio_progress',
      );
    }

    if (snapshot.contentMode == ReaderContentMode.audio) {
      return const ReaderLayoutAnchorReadinessDecision(
        type: ReaderLayoutAnchorReadinessType.notApplicable,
        reason: 'audio_content_not_text_layout',
      );
    }
    if (snapshot.contentMode != ReaderContentMode.text) {
      return const ReaderLayoutAnchorReadinessDecision(
        type: ReaderLayoutAnchorReadinessType.notApplicable,
        reason: 'non_text_content_not_layout_anchor',
      );
    }
    if (!snapshot.isTextPaged) {
      return const ReaderLayoutAnchorReadinessDecision(
        type: ReaderLayoutAnchorReadinessType.nonLayoutAnchor,
        reason: 'non_paged_text_uses_scroll_anchor',
      );
    }
    if (!snapshot.releaseActive) {
      return const ReaderLayoutAnchorReadinessDecision(
        type: ReaderLayoutAnchorReadinessType.nonLayoutAnchor,
        reason: 'layout_release_inactive',
      );
    }
    if (!snapshot.hasLayoutPages) {
      return const ReaderLayoutAnchorReadinessDecision(
        type: ReaderLayoutAnchorReadinessType.blocked,
        reason: 'layout_pages_not_ready',
      );
    }
    return ReaderLayoutAnchorReadinessDecision(
      type: ReaderLayoutAnchorReadinessType.layoutAnchor,
      reason: _reasonFor(consumer),
      layoutSignature: snapshot.layoutSignature,
    );
  }

  String _reasonFor(ReaderLayoutAnchorConsumer consumer) {
    return switch (consumer) {
      ReaderLayoutAnchorConsumer.search => 'search_uses_layout_range',
      ReaderLayoutAnchorConsumer.readAloud => 'read_aloud_uses_layout_range',
      ReaderLayoutAnchorConsumer.autoRead => 'auto_read_uses_layout_page_clock',
      ReaderLayoutAnchorConsumer.audioProgress =>
        'audio_surface_uses_audio_progress',
    };
  }
}
