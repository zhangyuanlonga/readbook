import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bookshelf_page_models.dart';

class BookshelfAnimatedProgressSection extends StatefulWidget {
  const BookshelfAnimatedProgressSection({
    super.key,
    required this.progressDisplay,
    required this.summaryStyle,
    required this.trailingStyle,
    required this.fillColor,
    required this.backgroundColor,
    this.summaryText,
    this.showSummaryText = true,
    this.showTrailingText = true,
    this.showBar = true,
    this.minHeight = 3,
    this.spacing = 6,
  });

  final BookshelfProgressDisplay progressDisplay;
  final TextStyle? summaryStyle;
  final TextStyle? trailingStyle;
  final Color fillColor;
  final Color backgroundColor;
  final String? summaryText;
  final bool showSummaryText;
  final bool showTrailingText;
  final bool showBar;
  final double minHeight;
  final double spacing;

  @override
  State<BookshelfAnimatedProgressSection> createState() =>
      _BookshelfAnimatedProgressSectionState();
}

class _BookshelfAnimatedProgressSectionState
    extends State<BookshelfAnimatedProgressSection>
    with TickerProviderStateMixin {
  static const Duration _kInitialDuration = Duration(milliseconds: 320);
  static const Duration _kUpdateDuration = Duration(milliseconds: 260);
  static const Duration _kSweepDuration = Duration(milliseconds: 520);
  static const Duration _kCompletionFlashDuration = Duration(milliseconds: 360);

  late final AnimationController _progressController;
  late final AnimationController _sweepController;
  late final AnimationController _completionFlashController;
  late Animation<double> _progressAnimation;
  bool _hasPlayedInitialAnimation = false;

  double get _targetValue =>
      widget.progressDisplay.progressValue.clamp(0.0, 1.0).toDouble();

  double get _currentAnimatedValue => _progressAnimation.value;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this);
    _sweepController = AnimationController(
      vsync: this,
      duration: _kSweepDuration,
    );
    _completionFlashController = AnimationController(
      vsync: this,
      duration: _kCompletionFlashDuration,
    );
    _configureProgressAnimation(0, 0);
    _startProgressAnimation(
      from: 0,
      to: _targetValue,
      duration: _kInitialDuration,
      playSweep: _targetValue > 0,
      triggerCompletion: _targetValue >= 0.999,
    );
    _hasPlayedInitialAnimation = true;
  }

  @override
  void didUpdateWidget(covariant BookshelfAnimatedProgressSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextTarget = _targetValue;
    final previousTarget =
        oldWidget.progressDisplay.progressValue.clamp(0.0, 1.0).toDouble();
    if ((nextTarget - previousTarget).abs() < 0.0001) {
      return;
    }
    final from = _currentAnimatedValue;
    _startProgressAnimation(
      from: from,
      to: nextTarget,
      duration:
          _hasPlayedInitialAnimation ? _kUpdateDuration : _kInitialDuration,
      playSweep: nextTarget > from,
      triggerCompletion: previousTarget < 0.999 && nextTarget >= 0.999,
    );
    _hasPlayedInitialAnimation = true;
  }

  @override
  void dispose() {
    _progressController.dispose();
    _sweepController.dispose();
    _completionFlashController.dispose();
    super.dispose();
  }

  void _configureProgressAnimation(double begin, double end) {
    _progressAnimation = Tween<double>(begin: begin, end: end).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic),
    );
  }

  void _startProgressAnimation({
    required double from,
    required double to,
    required Duration duration,
    required bool playSweep,
    required bool triggerCompletion,
  }) {
    _progressController.duration = duration;
    _configureProgressAnimation(from, to);
    _progressController.forward(from: 0);
    if (playSweep) {
      _sweepController.forward(from: 0);
    }
    if (triggerCompletion) {
      _completionFlashController.forward(from: 0);
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _progressController,
        _sweepController,
        _completionFlashController,
      ]),
      builder: (context, _) {
        final animatedValue = _progressAnimation.value.clamp(0.0, 1.0);
        final animatedPercent = (animatedValue * 100).round().clamp(0, 100);
        final flashStrength = Curves.easeOut.transform(
          math.sin(_completionFlashController.value * math.pi),
        );
        final fillColor =
            Color.lerp(
              widget.fillColor,
              Color.alphaBlend(
                Colors.white.withValues(alpha: 0.32),
                widget.fillColor,
              ),
              flashStrength,
            )!;

        final showTextRow = widget.showSummaryText || widget.showTrailingText;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTextRow)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.showSummaryText)
                    Expanded(
                      child: Text(
                        widget.summaryText ??
                            widget.progressDisplay.summaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: widget.summaryStyle,
                      ),
                    )
                  else
                    const Spacer(),
                  if (widget.showTrailingText) ...[
                    const SizedBox(width: 8),
                    Text('$animatedPercent%', style: widget.trailingStyle),
                  ],
                ],
              ),
            if (widget.showBar) ...[
              if (showTextRow) SizedBox(height: widget.spacing),
              ClipRRect(
                borderRadius: BorderRadius.circular(widget.minHeight * 2),
                child: _BookshelfAnimatedProgressBar(
                  value: animatedValue,
                  minHeight: widget.minHeight,
                  backgroundColor: widget.backgroundColor,
                  fillColor: fillColor,
                  sweepProgress: _sweepController.value,
                  completionFlashStrength: flashStrength,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _BookshelfAnimatedProgressBar extends StatelessWidget {
  const _BookshelfAnimatedProgressBar({
    required this.value,
    required this.minHeight,
    required this.backgroundColor,
    required this.fillColor,
    required this.sweepProgress,
    required this.completionFlashStrength,
  });

  final double value;
  final double minHeight;
  final Color backgroundColor;
  final Color fillColor;
  final double sweepProgress;
  final double completionFlashStrength;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: minHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(minHeight * 2),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final highlightWidth = math.max(minHeight * 10, width * 0.34);
                  final sweepOffset =
                      (width + highlightWidth) * sweepProgress - highlightWidth;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient:
                              value >= 0.999
                                  ? null
                                  : LinearGradient(
                                    colors: [
                                      fillColor.withValues(alpha: 0.84),
                                      fillColor,
                                    ],
                                  ),
                          color: value >= 0.999 ? fillColor : null,
                          borderRadius: BorderRadius.circular(minHeight * 2),
                          boxShadow:
                              completionFlashStrength > 0
                                  ? [
                                    BoxShadow(
                                      color: fillColor.withValues(
                                        alpha: 0.22 * completionFlashStrength,
                                      ),
                                      blurRadius: 8,
                                      spreadRadius: 0.5,
                                    ),
                                  ]
                                  : null,
                        ),
                      ),
                      if (sweepProgress > 0 && sweepProgress < 1 && width > 0)
                        Transform.translate(
                          offset: Offset(sweepOffset, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: highlightWidth,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.52),
                                    Colors.transparent,
                                  ],
                                  stops: const [0, 0.18, 0.55, 1],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
