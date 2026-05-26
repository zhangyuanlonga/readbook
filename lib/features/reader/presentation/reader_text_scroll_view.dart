import 'package:flutter/material.dart';

import '../../../domain/entities/reader_document.dart';
import '../../../domain/entities/reader_settings.dart';
import '../application/reader_content_session.dart';
import '../application/reader_document_render_model.dart';
import '../application/reader_image_decode_budget.dart';
import '../application/reader_session_state.dart';
import '../application/reader_surface_metrics.dart';
import 'reader_shell.dart';
import 'reader_text_block_presentation.dart';

typedef ReaderScrollImageBuilder =
    Widget Function(BuildContext context, ReaderRenderImageItem item);

typedef ReaderScrollBlockWrapper =
    Widget Function(
      BuildContext context,
      ReaderRenderBlockItem item,
      bool isLast,
      Widget child,
    );

class ReaderTextScrollViewModel {
  const ReaderTextScrollViewModel({
    required this.contentSession,
    required this.settings,
    required this.document,
    required this.surfaceMetrics,
    required this.palette,
    this.renderItems = const <ReaderRenderBlockItem>[],
    this.allowSelection = false,
    this.textAlign,
    this.imageDecodeBudget,
    this.emptyMessage,
    this.contentPadding,
  });

  final ReaderContentSession contentSession;
  final ReaderSettings settings;
  final ReaderDocument document;
  final ReaderSurfaceMetrics surfaceMetrics;
  final ReaderPresentationPalette palette;
  final List<ReaderRenderBlockItem> renderItems;
  final bool allowSelection;
  final TextAlign? textAlign;
  final ReaderImageDecodeBudget? imageDecodeBudget;
  final String? emptyMessage;
  final EdgeInsets? contentPadding;
}

class ReaderTextScrollView extends StatelessWidget {
  const ReaderTextScrollView({
    super.key,
    required this.model,
    this.scrollController,
    this.onVisiblePositionChanged,
    this.imageBuilder,
    this.blockWrapper,
    this.content,
    this.overlay,
  });

  final ReaderTextScrollViewModel model;
  final ScrollController? scrollController;
  final ValueChanged<ReaderVisiblePosition>? onVisiblePositionChanged;
  final ReaderScrollImageBuilder? imageBuilder;
  final ReaderScrollBlockWrapper? blockWrapper;
  final Widget? content;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    if (content != null) {
      return Stack(
        children: [
          Positioned.fill(child: content!),
          if (overlay != null) _positionOverlay(overlay!),
        ],
      );
    }

    final items =
        model.renderItems.isNotEmpty
            ? model.renderItems
            : buildReaderRenderBlockItems(model.document);
    if (items.isEmpty) {
      return Center(
        child: Text(
          model.emptyMessage ?? '当前章节暂无正文内容',
          style: TextStyle(color: model.palette.secondaryTextColor),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) {
          return false;
        }
        onVisiblePositionChanged?.call(
          ReaderVisiblePosition(
            scrollOffset: notification.metrics.pixels,
            maxScrollExtent: notification.metrics.maxScrollExtent,
          ),
        );
        return false;
      },
      child: ListView.builder(
        controller: scrollController,
        padding: model.contentPadding ?? model.surfaceMetrics.scrollBodyPadding,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isLast = index == items.length - 1;
          final child = switch (item) {
            ReaderRenderTextItem() => _ReaderScrollTextBlock(
              model: model,
              item: item,
              isLast: isLast,
            ),
            ReaderRenderImageItem() => Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : model.settings.paragraphSpacing,
              ),
              child:
                  imageBuilder?.call(context, item) ??
                  _DefaultReaderImage(
                    item: item,
                    decodeBudget: model.imageDecodeBudget,
                  ),
            ),
            _ => const SizedBox.shrink(),
          };
          return blockWrapper?.call(context, item, isLast, child) ?? child;
        },
      ),
    );
  }

  Widget _positionOverlay(Widget overlay) {
    if (overlay is Positioned) {
      return overlay;
    }
    return Positioned.fill(child: overlay);
  }
}

class _ReaderScrollTextBlock extends StatelessWidget {
  const _ReaderScrollTextBlock({
    required this.model,
    required this.item,
    required this.isLast,
  });

  final ReaderTextScrollViewModel model;
  final ReaderRenderTextItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveReaderTextBlockPresentation(
      settings: model.settings,
      primaryTextColor: model.palette.primaryTextColor,
      secondaryTextColor: model.palette.secondaryTextColor,
      item: item,
      isLast: isLast,
      paragraphTextAlign: model.textAlign,
    );
    final data = resolved.displayText.trim();
    final textWidget =
        model.allowSelection
            ? SelectableText(
              data,
              textAlign: resolved.textAlign,
              style: resolved.textStyle,
            )
            : Text(
              data,
              textAlign: resolved.textAlign,
              style: resolved.textStyle,
            );
    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(bottom: resolved.spacingAfter),
        child: textWidget,
      ),
    );
  }
}

class _DefaultReaderImage extends StatelessWidget {
  const _DefaultReaderImage({required this.item, this.decodeBudget});

  final ReaderRenderImageItem item;
  final ReaderImageDecodeBudget? decodeBudget;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        item.imageUrl,
        fit: BoxFit.cover,
        cacheWidth: decodeBudget?.cacheWidth,
        cacheHeight: decodeBudget?.cacheHeight,
        errorBuilder:
            (_, __, ___) => AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: Colors.black12,
                child: Center(
                  child: Text(
                    '图片加载失败',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
      ),
    );
  }
}
