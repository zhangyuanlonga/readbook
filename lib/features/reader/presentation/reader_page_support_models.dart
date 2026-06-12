part of 'reader_page.dart';

class _ChapterLoadSnapshot {
  const _ChapterLoadSnapshot({required this.result, required this.isCached});

  final ChapterContentResult result;
  final bool isCached;
}

class _ContinuousTextChapter {
  const _ContinuousTextChapter({
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

class _ContinuousTextChapterLayout {
  const _ContinuousTextChapterLayout({
    required this.startOffset,
    required this.endOffset,
  });

  final double startOffset;
  final double endOffset;
}

class _ScrollEdgeAdvanceState {
  const _ScrollEdgeAdvanceState({
    this.overscrollDistance = 0,
    this.isArmed = false,
    this.actionDirection = 0,
  });

  final double overscrollDistance;
  final bool isArmed;
  final int actionDirection;

  _ScrollEdgeAdvanceState copyWith({
    double? overscrollDistance,
    bool? isArmed,
    int? actionDirection,
  }) {
    return _ScrollEdgeAdvanceState(
      overscrollDistance: overscrollDistance ?? this.overscrollDistance,
      isArmed: isArmed ?? this.isArmed,
      actionDirection: actionDirection ?? this.actionDirection,
    );
  }
}

class _ReaderThemeColors {
  const _ReaderThemeColors({
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

class _ReaderBackgroundColorOption {
  const _ReaderBackgroundColorOption({
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

class _ReaderBackgroundPreset {
  const _ReaderBackgroundPreset({required this.label, required this.assetPath});

  final String label;
  final String assetPath;
}

class _ReaderSizeReporter extends StatefulWidget {
  const _ReaderSizeReporter({required this.child, required this.onSizeChanged});

  final Widget child;
  final ValueChanged<Size> onSizeChanged;

  @override
  State<_ReaderSizeReporter> createState() => _ReaderSizeReporterState();
}

class _ReaderSizeReporterState extends State<_ReaderSizeReporter> {
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

class _CurlTransitionState {
  const _CurlTransitionState({
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

  _CurlTransitionState copyWith({
    bool? isAnimating,
    bool? isPreview,
    int? direction,
    int? fromIndex,
    int? toIndex,
    double? previewProgress,
    bool? commitOnAnimationEnd,
    bool? isCrossChapter,
  }) {
    return _CurlTransitionState(
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

class _CrossChapterSnapshotTransitionState {
  const _CrossChapterSnapshotTransitionState({
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

  _CrossChapterSnapshotTransitionState copyWith({
    ui.Image? fromImage,
    ui.Image? toImage,
    ReaderPageAnimationStyle? style,
    int? direction,
    int? generation,
    String? completionMode,
  }) {
    return _CrossChapterSnapshotTransitionState(
      fromImage: fromImage ?? this.fromImage,
      toImage: toImage ?? this.toImage,
      style: style ?? this.style,
      direction: direction ?? this.direction,
      generation: generation ?? this.generation,
      completionMode: completionMode ?? this.completionMode,
    );
  }
}

class _BookmarkRange {
  const _BookmarkRange(
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

class _ReaderInspirationSelectionState {
  const _ReaderInspirationSelectionState({
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

class _ReaderInspirationActionItem {
  const _ReaderInspirationActionItem({
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

class _ReaderInspirationActionChip extends StatelessWidget {
  const _ReaderInspirationActionChip({
    required this.action,
    required this.colorScheme,
  });

  final _ReaderInspirationActionItem action;
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

class _DecodedDataUriImage {
  const _DecodedDataUriImage({
    required this.mediaType,
    required this.bytes,
    required this.text,
  });

  final String mediaType;
  final Uint8List bytes;
  final String text;
}

class _ResolvedReaderBackgroundVisual {
  const _ResolvedReaderBackgroundVisual({
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

class _ReaderSurfaceReserves {
  const _ReaderSurfaceReserves({
    required this.scrollBottomReserve,
    required this.pagedHeaderReserve,
    required this.pagedBottomReserve,
  });

  final double scrollBottomReserve;
  final double pagedHeaderReserve;
  final double pagedBottomReserve;
}
