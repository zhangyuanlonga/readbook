import 'dart:math';

import 'package:flutter/material.dart';

import '../../../domain/entities/reader_document.dart';
import '../../../domain/entities/reader_settings.dart';
import '../application/reader_content_session.dart';
import '../application/reader_document_render_model.dart';
import '../application/reader_surface_metrics.dart';
import 'reader_body_region.dart';
import 'reader_manga_view.dart';
import 'reader_shell.dart';
import 'reader_text_scroll_view.dart';

typedef ReaderViewportTapAwareBuilder =
    Widget Function({required Widget child});
typedef ReaderViewportBuilderCallback = Widget Function();
typedef ReaderPagedViewportBuilder =
    Widget Function(
      BuildContext context,
      BoxConstraints constraints,
      ReaderPresentationPalette palette,
    );

class ReaderViewportBodyState {
  const ReaderViewportBodyState({
    required this.showBlockingLoading,
    required this.showHiddenLoading,
    required this.showTransientLoadingGap,
    required this.hasRenderableContent,
    this.errorText,
    this.primaryActionLabel,
    this.hasPrimaryErrorAction = false,
    this.canSwitchSource = false,
    this.isSwitchSourceLoading = false,
  });

  final bool showBlockingLoading;
  final bool showHiddenLoading;
  final bool showTransientLoadingGap;
  final bool hasRenderableContent;
  final String? errorText;
  final String? primaryActionLabel;
  final bool hasPrimaryErrorAction;
  final bool canSwitchSource;
  final bool isSwitchSourceLoading;
}

class ReaderViewportBuilder {
  const ReaderViewportBuilder();

  Widget buildBody({
    required ReaderViewportBodyState state,
    required ReaderBodyRegionPalette palette,
    required ReaderViewportTapAwareBuilder tapAwareBuilder,
    required ReaderViewportBuilderCallback contentBuilder,
    required VoidCallback onRetry,
    VoidCallback? onPrimaryErrorAction,
    Future<void> Function()? onPullToRefresh,
    required VoidCallback onCopyDiagnostics,
    required VoidCallback onSwitchSource,
    required bool isLocalContent,
  }) {
    if (state.showBlockingLoading) {
      return tapAwareBuilder(
        child: ReaderBodyRegion(
          model: const ReaderBodyRegionModel.stateCard(
            stateCard: ReaderBodyRegionStateCard(
              title: '正在加载正文',
              message: '请稍候，马上为你展开章节内容。',
              icon: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          palette: palette,
        ),
      );
    }

    if (state.showHiddenLoading) {
      return tapAwareBuilder(
        child: ReaderBodyRegion(
          model: const ReaderBodyRegionModel.content(),
          palette: palette,
          child: const ReaderViewportLoadingPlaceholder(),
        ),
      );
    }

    if (state.showTransientLoadingGap) {
      return tapAwareBuilder(
        child: ReaderBodyRegion(
          model: const ReaderBodyRegionModel.content(),
          palette: palette,
          child: const SizedBox.expand(),
        ),
      );
    }

    if (state.errorText != null) {
      final primaryActionLabel =
          state.hasPrimaryErrorAction ? state.primaryActionLabel?.trim() : null;
      final resolvedPrimaryActionLabel =
          primaryActionLabel == null || primaryActionLabel.isEmpty
              ? '重试'
              : primaryActionLabel;
      final child = ReaderBodyRegion(
        model: ReaderBodyRegionModel.stateCard(
          stateCard: ReaderBodyRegionStateCard(
            title: '加载失败',
            message: state.errorText!,
            icon: Icon(
              Icons.warning_amber_rounded,
              color: palette.metaColor,
              size: 20,
            ),
            action: Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.tonal(
                  onPressed:
                      state.isSwitchSourceLoading
                          ? null
                          : (state.hasPrimaryErrorAction
                              ? onPrimaryErrorAction ?? onRetry
                              : onRetry),
                  child: Text(resolvedPrimaryActionLabel),
                ),
                if (isLocalContent)
                  OutlinedButton.icon(
                    onPressed: onCopyDiagnostics,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('复制诊断信息'),
                  ),
                if (state.canSwitchSource)
                  OutlinedButton.icon(
                    onPressed:
                        state.isSwitchSourceLoading ? null : onSwitchSource,
                    icon:
                        state.isSwitchSourceLoading
                            ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.swap_horiz_rounded),
                    label: Text(
                      state.isSwitchSourceLoading ? '换源中...' : '切换书源',
                    ),
                  ),
              ],
            ),
          ),
        ),
        palette: palette,
      );
      return tapAwareBuilder(
        child: _wrapRefreshableState(
          child: child,
          onPullToRefresh: onPullToRefresh,
        ),
      );
    }

    if (!state.hasRenderableContent) {
      final child = ReaderBodyRegion(
        model: ReaderBodyRegionModel.stateCard(
          stateCard: ReaderBodyRegionStateCard(
            title: '暂无正文',
            message: '当前章节没有可展示的内容。',
            icon: Icon(
              Icons.article_outlined,
              color: palette.metaColor,
              size: 20,
            ),
          ),
        ),
        palette: palette,
      );
      return tapAwareBuilder(
        child: _wrapRefreshableState(
          child: child,
          onPullToRefresh: onPullToRefresh,
        ),
      );
    }

    return tapAwareBuilder(
      child: ReaderBodyRegion(
        model: const ReaderBodyRegionModel.content(),
        palette: palette,
        child: contentBuilder(),
      ),
    );
  }

  Widget _wrapRefreshableState({
    required Widget child,
    required Future<void> Function()? onPullToRefresh,
  }) {
    if (onPullToRefresh == null) {
      return child;
    }
    return RefreshIndicator(
      onRefresh: onPullToRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [SizedBox(height: 520, child: child)],
      ),
    );
  }

  Widget buildStandardTextViewport({
    required ReaderTextScrollViewModel model,
    required ScrollController scrollController,
    required Key bodyKey,
    required Widget Function({required Widget child}) selectionWrapper,
    required NotificationListenerCallback<ScrollNotification>
    onScrollNotification,
    required ReaderScrollImageBuilder imageBuilder,
    required ReaderScrollBlockWrapper blockWrapper,
    Widget? overlay,
  }) {
    final scrollView = NotificationListener<ScrollNotification>(
      onNotification: onScrollNotification,
      child: ReaderTextScrollView(
        model: model,
        scrollController: scrollController,
        imageBuilder: imageBuilder,
        blockWrapper: blockWrapper,
        overlay: overlay,
      ),
    );

    return KeyedSubtree(
      key: bodyKey,
      child: selectionWrapper(child: scrollView),
    );
  }

  Widget buildContinuousTextViewport({
    required Widget listView,
    required Key bodyKey,
    ReaderTextScrollViewModel? shellModel,
    Widget? overlay,
  }) {
    if (shellModel == null) {
      return Stack(
        key: bodyKey,
        children: [listView, if (overlay != null) overlay],
      );
    }

    return ReaderTextScrollView(
      model: shellModel,
      content: listView,
      overlay: overlay,
    );
  }

  Widget buildMangaViewport({
    required ReaderMangaViewModel model,
    required ScrollController scrollController,
    required PageController pageController,
    required ValueChanged<int> onPageChanged,
    required ReaderMangaImageBuilder imageBuilder,
    required ReaderMangaPagedViewportBuilder pagedViewportBuilder,
  }) {
    return ReaderMangaView(
      model: model,
      scrollController: scrollController,
      pageController: pageController,
      onPageChanged: onPageChanged,
      imageBuilder: imageBuilder,
      pagedViewportBuilder: pagedViewportBuilder,
    );
  }

  Widget buildPagedViewport({required ReaderPagedViewportBuilder builder}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return builder(
          context,
          constraints,
          ReaderPresentationPalette.fromColorScheme(
            Theme.of(context).colorScheme,
          ),
        );
      },
    );
  }

  double continuousSeparatorHeight({
    required ReaderSettings settings,
    double minimum = 18,
    double multiplier = 1.2,
  }) {
    return max(minimum, settings.paragraphSpacing * multiplier);
  }

  List<ReaderRenderBlockItem> resolveContinuousChapterRenderItems(
    ReaderDocument document,
  ) {
    return buildReaderRenderBlockItems(document);
  }

  ReaderTextScrollViewModel buildContinuousShellModel({
    required ReaderContentSession contentSession,
    required ReaderSettings settings,
    required ReaderDocument document,
    required ReaderSurfaceMetrics surfaceMetrics,
    required ReaderPresentationPalette palette,
  }) {
    return ReaderTextScrollViewModel(
      contentSession: contentSession,
      settings: settings,
      document: document,
      surfaceMetrics: surfaceMetrics,
      palette: palette,
    );
  }
}

class ReaderViewportLoadingPlaceholder extends StatelessWidget {
  const ReaderViewportLoadingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final divider = colorScheme.outlineVariant.withValues(alpha: 0.28);
    final fill = colorScheme.onSurface.withValues(alpha: 0.06);
    final accent = colorScheme.primary.withValues(alpha: 0.55);

    Widget line(double widthFactor, {double height = 12}) {
      return FractionallySizedBox(
        widthFactor: widthFactor,
        alignment: Alignment.centerLeft,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
          child: Column(
            key: const Key('reader_viewport_loading_placeholder'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 20),
              line(0.48, height: 18),
              const SizedBox(height: 18),
              line(1),
              const SizedBox(height: 10),
              line(0.94),
              const SizedBox(height: 10),
              line(0.98),
              const SizedBox(height: 10),
              line(0.86),
              const SizedBox(height: 10),
              line(0.66),
              const SizedBox(height: 18),
              Divider(height: 1, color: divider),
            ],
          ),
        ),
      ),
    );
  }
}
