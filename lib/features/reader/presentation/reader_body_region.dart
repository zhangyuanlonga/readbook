import 'package:flutter/material.dart';

enum ReaderBodyRegionMode { content, stateCard, hidden }

class ReaderBodyRegionPalette {
  const ReaderBodyRegionPalette({
    required this.textColor,
    required this.metaColor,
    required this.overlayColor,
    required this.dividerColor,
  });

  final Color textColor;
  final Color metaColor;
  final Color overlayColor;
  final Color dividerColor;
}

class ReaderBodyRegionStateCard {
  const ReaderBodyRegionStateCard({
    required this.title,
    required this.message,
    required this.icon,
    this.action,
  });

  final String title;
  final String message;
  final Widget icon;
  final Widget? action;
}

class ReaderBodyRegionModel {
  const ReaderBodyRegionModel.content()
    : mode = ReaderBodyRegionMode.content,
      stateCard = null;

  const ReaderBodyRegionModel.hidden()
    : mode = ReaderBodyRegionMode.hidden,
      stateCard = null;

  const ReaderBodyRegionModel.stateCard({
    required ReaderBodyRegionStateCard this.stateCard,
  }) : mode = ReaderBodyRegionMode.stateCard;

  final ReaderBodyRegionMode mode;
  final ReaderBodyRegionStateCard? stateCard;
}

class ReaderBodyRegion extends StatelessWidget {
  const ReaderBodyRegion({
    super.key,
    required this.model,
    required this.palette,
    this.child,
  });

  final ReaderBodyRegionModel model;
  final ReaderBodyRegionPalette palette;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return switch (model.mode) {
      ReaderBodyRegionMode.hidden => const SizedBox.expand(),
      ReaderBodyRegionMode.content => child ?? const SizedBox.shrink(),
      ReaderBodyRegionMode.stateCard => _ReaderBodyStateCard(
        palette: palette,
        data: model.stateCard!,
      ),
    };
  }
}

class _ReaderBodyStateCard extends StatelessWidget {
  const _ReaderBodyStateCard({required this.palette, required this.data});

  final ReaderBodyRegionPalette palette;
  final ReaderBodyRegionStateCard data;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: palette.overlayColor.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.dividerColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            data.icon,
            const SizedBox(height: 10),
            Text(
              data.title,
              style: TextStyle(
                color: palette.textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              data.message,
              style: TextStyle(color: palette.metaColor),
              textAlign: TextAlign.center,
            ),
            if (data.action != null) ...[
              const SizedBox(height: 12),
              data.action!,
            ],
          ],
        ),
      ),
    );
  }
}
