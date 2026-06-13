import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../domain/entities/bookmark.dart';
import '../../../domain/entities/reader_document.dart';
import '../../../domain/entities/reader_settings.dart';
import '../application/chapter_content_service.dart';

class ReaderPageChapterLoadSnapshot {
  const ReaderPageChapterLoadSnapshot({
    required this.result,
    required this.isCached,
  });

  final ChapterContentResult result;
  final bool isCached;
}

class ReaderPageContinuousTextChapter {
  const ReaderPageContinuousTextChapter({
    required this.chapterId,
    required this.chapterUrl,
    required this.chapterTitle,
    required this.displayTitle,
    required this.chapterIndex,
    required this.content,
    required this.document,
    required this.paragraphs,
    required this.isCached,
  });

  final String chapterId;
  final String chapterUrl;
  final String chapterTitle;
  final String displayTitle;
  final int chapterIndex;
  final String content;
  final ReaderDocument document;
  final List<String> paragraphs;
  final bool isCached;
}

class ReaderPageContinuousTextChapterLayout {
  const ReaderPageContinuousTextChapterLayout({
    required this.startOffset,
    required this.endOffset,
  });

  final double startOffset;
  final double endOffset;
}

class ReaderScrollEdgeAdvanceState {
  const ReaderScrollEdgeAdvanceState({
    this.overscrollDistance = 0,
    this.isArmed = false,
    this.actionDirection = 0,
  });

  final double overscrollDistance;
  final bool isArmed;
  final int actionDirection;

  ReaderScrollEdgeAdvanceState copyWith({
    double? overscrollDistance,
    bool? isArmed,
    int? actionDirection,
  }) {
    return ReaderScrollEdgeAdvanceState(
      overscrollDistance: overscrollDistance ?? this.overscrollDistance,
      isArmed: isArmed ?? this.isArmed,
      actionDirection: actionDirection ?? this.actionDirection,
    );
  }
}

class ReaderThemeColors {
  const ReaderThemeColors({
    required this.background,
    required this.text,
    required this.meta,
    required this.divider,
    required this.overlay,
  });

  final Color background;
  final Color text;
  final Color meta;
  final Color divider;
  final Color overlay;
}

class ReaderBackgroundColorOption {
  const ReaderBackgroundColorOption({
    required this.label,
    required this.previewColor,
    required this.mode,
    required this.backgroundStyle,
    required this.backgroundTone,
  });

  final String label;
  final Color previewColor;
  final ReaderThemeMode mode;
  final ReaderBackgroundStyle backgroundStyle;
  final ReaderBackgroundTone backgroundTone;
}

class ReaderBackgroundPreset {
  const ReaderBackgroundPreset({required this.label, required this.assetPath});

  final String label;
  final String assetPath;
}

class ReaderSizeReporter extends StatefulWidget {
  const ReaderSizeReporter({
    super.key,
    required this.child,
    required this.onSizeChanged,
  });

  final Widget child;
  final ValueChanged<Size> onSizeChanged;

  @override
  State<ReaderSizeReporter> createState() => _ReaderSizeReporterState();
}

class _ReaderSizeReporterState extends State<ReaderSizeReporter> {
  Size? _lastSize;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final renderBox = _safeFindRenderBox(context);
      if (renderBox is! RenderBox || !renderBox.hasSize) {
        return;
      }
      final size = renderBox.size;
      if (_lastSize != null &&
          (_lastSize!.width - size.width).abs() < 0.5 &&
          (_lastSize!.height - size.height).abs() < 0.5) {
        return;
      }
      _lastSize = size;
      widget.onSizeChanged(size);
    });
    return widget.child;
  }

  RenderBox? _safeFindRenderBox(BuildContext context) {
    try {
      final renderObject = context.findRenderObject();
      return renderObject is RenderBox ? renderObject : null;
    } catch (_) {
      return null;
    }
  }
}

class ReaderCurlTransitionState {
  const ReaderCurlTransitionState({
    this.isAnimating = false,
    this.isPreview = false,
    this.direction = 1,
    this.fromIndex = 0,
    this.toIndex = 0,
    this.previewProgress = 0,
    this.commitOnAnimationEnd = true,
    this.isCrossChapter = false,
  });

  final bool isAnimating;
  final bool isPreview;
  final int direction;
  final int fromIndex;
  final int toIndex;
  final double previewProgress;
  final bool commitOnAnimationEnd;
  final bool isCrossChapter;

  ReaderCurlTransitionState copyWith({
    bool? isAnimating,
    bool? isPreview,
    int? direction,
    int? fromIndex,
    int? toIndex,
    double? previewProgress,
    bool? commitOnAnimationEnd,
    bool? isCrossChapter,
  }) {
    return ReaderCurlTransitionState(
      isAnimating: isAnimating ?? this.isAnimating,
      isPreview: isPreview ?? this.isPreview,
      direction: direction ?? this.direction,
      fromIndex: fromIndex ?? this.fromIndex,
      toIndex: toIndex ?? this.toIndex,
      previewProgress: previewProgress ?? this.previewProgress,
      commitOnAnimationEnd: commitOnAnimationEnd ?? this.commitOnAnimationEnd,
      isCrossChapter: isCrossChapter ?? this.isCrossChapter,
    );
  }
}

class ReaderCrossChapterSnapshotTransitionState {
  const ReaderCrossChapterSnapshotTransitionState({
    this.fromImage,
    this.toImage,
    this.style = ReaderPageAnimationStyle.none,
    this.direction = 1,
    this.generation = 0,
    this.completionMode = 'cross_chapter',
  });

  final ui.Image? fromImage;
  final ui.Image? toImage;
  final ReaderPageAnimationStyle style;
  final int direction;
  final int generation;
  final String completionMode;

  bool get isActive => fromImage != null;
  bool get hasTarget => fromImage != null && toImage != null;

  ReaderCrossChapterSnapshotTransitionState copyWith({
    ui.Image? fromImage,
    ui.Image? toImage,
    ReaderPageAnimationStyle? style,
    int? direction,
    int? generation,
    String? completionMode,
  }) {
    return ReaderCrossChapterSnapshotTransitionState(
      fromImage: fromImage ?? this.fromImage,
      toImage: toImage ?? this.toImage,
      style: style ?? this.style,
      direction: direction ?? this.direction,
      generation: generation ?? this.generation,
      completionMode: completionMode ?? this.completionMode,
    );
  }
}

class ReaderBookmarkRange {
  const ReaderBookmarkRange(
    this.start,
    this.end, {
    required this.hasHighlight,
    required this.isBold,
    required this.isUnderline,
    required this.isWavy,
  });

  final int start;
  final int end;
  final bool hasHighlight;
  final bool isBold;
  final bool isUnderline;
  final bool isWavy;
}

class ReaderInspirationSelectionState {
  const ReaderInspirationSelectionState({
    required this.hasSelection,
    required this.existingBookmark,
    required this.isHighlight,
    required this.isBold,
    required this.isUnderline,
    required this.isWavy,
  });

  final bool hasSelection;
  final Bookmark? existingBookmark;
  final bool isHighlight;
  final bool isBold;
  final bool isUnderline;
  final bool isWavy;

  bool get hasExistingBookmark => existingBookmark != null;
}

class ReaderInspirationActionItem {
  const ReaderInspirationActionItem({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isActive;
}

class ReaderInspirationActionChip extends StatelessWidget {
  const ReaderInspirationActionChip({
    super.key,
    required this.action,
    required this.colorScheme,
  });

  final ReaderInspirationActionItem action;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor =
        action.isActive
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerLow;
    final foregroundColor =
        action.isActive
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurface;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: action.onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 18, color: foregroundColor),
              const SizedBox(width: 6),
              Text(
                action.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReaderDecodedDataUriImage {
  const ReaderDecodedDataUriImage({
    required this.mediaType,
    required this.bytes,
    required this.text,
  });

  final String mediaType;
  final Uint8List bytes;
  final String text;
}

class ReaderResolvedBackgroundVisual {
  const ReaderResolvedBackgroundVisual({
    required this.imageProvider,
    required this.fit,
    required this.opacity,
    required this.blurSigma,
    required this.overlayOpacity,
  });

  final ImageProvider imageProvider;
  final BoxFit fit;
  final double opacity;
  final double blurSigma;
  final double overlayOpacity;
}

class ReaderSurfaceReserves {
  const ReaderSurfaceReserves({
    required this.scrollBottomReserve,
    required this.pagedHeaderReserve,
    required this.pagedBottomReserve,
  });

  final double scrollBottomReserve;
  final double pagedHeaderReserve;
  final double pagedBottomReserve;
}
