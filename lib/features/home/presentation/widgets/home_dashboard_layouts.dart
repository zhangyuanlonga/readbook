import 'package:flutter/material.dart';

import '../../../../app/layout/app_adaptive.dart';
import '../../../../app/motion/app_motion_widgets.dart';

class HomeMobileDashboardLayout extends StatelessWidget {
  const HomeMobileDashboardLayout({
    super.key,
    required this.metrics,
    required this.checkInSummary,
    required this.sectionHeader,
    required this.continueReading,
    required this.readingGoal,
  });

  final AppAdaptiveMetrics metrics;
  final Widget checkInSummary;
  final Widget sectionHeader;
  final Widget continueReading;
  final Widget readingGoal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFadeSlideTransition(child: checkInSummary),
        SizedBox(height: metrics.sectionGap),
        AppFadeSlideTransition(
          delay: const Duration(milliseconds: 56),
          child: sectionHeader,
        ),
        SizedBox(height: metrics.contentGap),
        AppFadeSlideTransition(
          delay: const Duration(milliseconds: 84),
          child: continueReading,
        ),
        SizedBox(height: metrics.sectionGap),
        AppFadeSlideTransition(
          delay: const Duration(milliseconds: 112),
          child: readingGoal,
        ),
      ],
    );
  }
}

class HomeDesktopDashboardLayout extends StatelessWidget {
  const HomeDesktopDashboardLayout({
    super.key,
    required this.metrics,
    required this.continueReadingPanel,
    required this.readingSummary,
  });

  final AppAdaptiveMetrics metrics;
  final Widget continueReadingPanel;
  final Widget readingSummary;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 13,
          child: AppFadeSlideTransition(child: continueReadingPanel),
        ),
        SizedBox(width: metrics.sectionGap),
        Expanded(
          flex: 7,
          child: AppFadeSlideTransition(
            delay: const Duration(milliseconds: 96),
            child: readingSummary,
          ),
        ),
      ],
    );
  }
}
