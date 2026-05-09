import 'package:flutter/material.dart';

import '../layout/app_adaptive.dart';
import 'adaptive_content_container.dart';

class AdaptivePageScaffold extends StatelessWidget {
  const AdaptivePageScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.maxContentWidth,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.useContentContainer = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final double? maxContentWidth;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;
  final bool useContentContainer;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final content =
        useContentContainer
            ? AdaptiveContentContainer(
              maxWidth: maxContentWidth ?? _defaultMaxWidth(metrics),
              child: body,
            )
            : body;
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: content,
    );
  }

  double _defaultMaxWidth(AppAdaptiveMetrics metrics) {
    return switch (metrics.windowClass) {
      AppWindowClass.compact => metrics.width,
      AppWindowClass.medium => 760,
      AppWindowClass.expanded => 960,
    };
  }
}
