import 'dart:math';

// UI-GOV-EXEMPT-FILE: list-children
// reason: Phase 10 reviewed this Reader settings frame; short static sections are deferred to Phase 12 sheet migration.

import 'package:flutter/material.dart';

import '../../../../../app/layout/app_adaptive.dart';
import '../../reader_icons.dart';

class ReaderSettingsSheetFrame extends StatelessWidget {
  const ReaderSettingsSheetFrame({
    super.key,
    required this.title,
    required this.safeBottom,
    required this.children,
    this.onBack,
  });

  final String title;
  final double safeBottom;
  final List<Widget> children;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          metrics.pagePadding,
          metrics.isCompactDensity ? 6 : 8,
          metrics.pagePadding,
          max(6.0, safeBottom * 0.35),
        ),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 4,
              margin: EdgeInsets.only(
                bottom: metrics.isCompactDensity ? 8 : 10,
              ),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            SizedBox(
              height: metrics.controlHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (onBack != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: onBack,
                        icon: const Icon(ReaderIcons.back),
                      ),
                    ),
                  Center(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: metrics.isCompactDensity ? 4 : 6),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(bottom: max(4.0, safeBottom * 0.18)),
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
