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
    required this.hasRenderableContent,
    this.errorText,
    this.canSwitchSource = false,
    this.isSwitchSourceLoading = false,
  });

  final bool showBlockingLoading;
  final bool showHiddenLoading;
  final bool hasRenderableContent;
  final String? errorText;
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
      return ReaderBodyRegion(
        model: const ReaderBodyRegionModel.hidden(),
        palette: palette,
      );
    }

    if (state.errorText != null) {
      return tapAwareBuilder(
        child: ReaderBodyRegion(
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
                    onPressed: state.isSwitchSourceLoading ? null : onRetry,
                    child: const Text('重试'),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
        ),
      );
    }

    if (!state.hasRenderableContent) {
      return tapAwareBuilder(
        child: ReaderBodyRegion(
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
