import 'package:flutter/widgets.dart';

import '../reader_paged_viewport_support.dart';
import '../reader_paper_curl_paged_view.dart';
import '../reader_text_paged_view.dart';
import 'curl_paged_animation_renderer.dart';
import 'paged_animation_renderer_registry.dart';

/// Unified paged-reader animation entry.
///
/// The reader page resolves business state into [ReaderPagedViewportTransitionPlan]
/// first; this widget only chooses the presentation surface for that plan.
class ReaderPagedAnimationSurface extends StatelessWidget {
  const ReaderPagedAnimationSurface({
    super.key,
    required this.model,
    required this.plan,
    required this.pageBuilder,
    required this.pagedTransitionAnimation,
    required this.curlAnimation,
    required this.switchInCurve,
    this.staticPageController,
    this.onStaticPageChanged,
    this.onStaticScrollInteractionChanged,
    this.paperCurlKey,
    this.paperCurlSurface,
    this.onPaperCurlPageCommitted,
    this.onPaperCurlTurnStarted,
    this.onPaperCurlTurnRejected,
    this.selectionWrapper = _identityWrapper,
    this.disabledSelectionWrapper = _identityWrapper,
    this.animationRendererRegistry = const PagedAnimationRendererRegistry(),
    this.curlState = ReaderPagedViewportCurlState.idle,
    this.curlRenderer = const CurlPagedAnimationRenderer(),
    this.curlColors = const CurlRendererColors(
      backgroundColor: Color(0x00000000),
      dividerColor: Color(0x00000000),
      overlayColor: Color(0x00000000),
    ),
  });

  final ReaderTextPagedViewModel model;
  final ReaderPagedViewportTransitionPlan plan;
  final ReaderPagedViewportPageBuilder pageBuilder;
  final Animation<double> pagedTransitionAnimation;
  final Animation<double> curlAnimation;
  final Curve switchInCurve;
  final PageController? staticPageController;
  final ValueChanged<int>? onStaticPageChanged;
  final ValueChanged<bool>? onStaticScrollInteractionChanged;
  final GlobalKey<ReaderPaperCurlPagedViewState>? paperCurlKey;
  final ReaderPaperCurlPagedSurface? paperCurlSurface;
  final ValueChanged<int>? onPaperCurlPageCommitted;
  final ValueChanged<int>? onPaperCurlTurnStarted;
  final ValueChanged<int>? onPaperCurlTurnRejected;
  final ReaderPagedViewportWrapper selectionWrapper;
  final ReaderPagedViewportWrapper disabledSelectionWrapper;
  final PagedAnimationRendererRegistry animationRendererRegistry;
  final ReaderPagedViewportCurlState curlState;
  final CurlPagedAnimationRenderer curlRenderer;
  final CurlRendererColors curlColors;

  @override
  Widget build(BuildContext context) {
    return switch (plan.renderMode) {
      ReaderPagedViewportRenderMode.staticPage => _buildStaticPageView(),
      ReaderPagedViewportRenderMode.paperCurlSurface => _buildPaperCurlView(),
      ReaderPagedViewportRenderMode.animatedTransition ||
      ReaderPagedViewportRenderMode.curlTransition => _buildTransitionView(),
    };
  }

  Widget _buildStaticPageView() {
    return selectionWrapper(
      ReaderTextPagedView(
        model: model,
        pageController: staticPageController,
        pageBuilder:
            (context, pageIndex) => pageBuilder(
              pageIndex: pageIndex,
              includeBackgroundDecoration:
                  plan.includeBackgroundDecorationOnPrimaryPage,
            ),
        onPageChanged: onStaticPageChanged,
        onScrollInteractionChanged: onStaticScrollInteractionChanged,
      ),
    );
  }

  Widget _buildPaperCurlView() {
    final surface = paperCurlSurface;
    final onCommitted = onPaperCurlPageCommitted;
    if (surface == null || onCommitted == null) {
      return _buildStaticPageView();
    }
    return ReaderPaperCurlPagedView(
      key: paperCurlKey,
      surface: surface,
      onPageCommitted: onCommitted,
      onTurnStarted: onPaperCurlTurnStarted,
      onTurnRejected: onPaperCurlTurnRejected,
    );
  }

  Widget _buildTransitionView() {
    final pageStack = ReaderPagedViewportTransitionStack(
      plan: plan,
      pageBuilder: pageBuilder,
      pagedTransitionAnimation: pagedTransitionAnimation,
      curlAnimation: curlAnimation,
      switchInCurve: switchInCurve,
      selectionWrapper: selectionWrapper,
      disabledSelectionWrapper: disabledSelectionWrapper,
      animationRendererRegistry: animationRendererRegistry,
      curlState: curlState,
      curlRenderer: curlRenderer,
      curlColors: curlColors,
    );
    return ReaderTextPagedView(model: model, content: pageStack);
  }
}

Widget _identityWrapper(Widget child) => child;
