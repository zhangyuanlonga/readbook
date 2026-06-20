import 'package:flutter/material.dart';

import '../application/reader_layout_render_model.dart';
import '../domain/entities/reader_layout_models.dart';

typedef ReaderLayoutImagePlaceholderBuilder =
    Widget Function(BuildContext context, ReaderLayoutRenderFragment fragment);

class ReaderLayoutPagedView extends StatelessWidget {
  const ReaderLayoutPagedView({
    super.key,
    required this.pages,
    this.pageIndex = 0,
    this.textStyle,
    this.titleStyle,
    this.imagePlaceholderBuilder,
  });

  final List<ReaderLayoutPage> pages;
  final int pageIndex;
  final TextStyle? textStyle;
  final TextStyle? titleStyle;
  final ReaderLayoutImagePlaceholderBuilder? imagePlaceholderBuilder;

  @override
  Widget build(BuildContext context) {
    if (pages.isEmpty) {
      return const SizedBox.shrink();
    }
    final page = pages[pageIndex.clamp(0, pages.length - 1)];
    final renderPage =
        const ReaderLayoutRenderModelBuilder().buildPages(<ReaderLayoutPage>[
          page,
        ]).single;
    return ReaderLayoutPageView(
      page: renderPage,
      textStyle: textStyle,
      titleStyle: titleStyle,
      imagePlaceholderBuilder: imagePlaceholderBuilder,
    );
  }
}

class ReaderLayoutPageView extends StatelessWidget {
  const ReaderLayoutPageView({
    super.key,
    required this.page,
    this.textStyle,
    this.titleStyle,
    this.imagePlaceholderBuilder,
  });

  final ReaderLayoutRenderPage page;
  final TextStyle? textStyle;
  final TextStyle? titleStyle;
  final ReaderLayoutImagePlaceholderBuilder? imagePlaceholderBuilder;

  @override
  Widget build(BuildContext context) {
    final defaultTextStyle = textStyle ?? DefaultTextStyle.of(context).style;
    final resolvedTitleStyle =
        titleStyle ?? defaultTextStyle.copyWith(fontWeight: FontWeight.w600);
    return SizedBox(
      width: page.contentWidth,
      height: page.contentHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: page.fragments
            .map(
              (fragment) => Positioned(
                left: fragment.rect.left,
                top: fragment.rect.top,
                width: fragment.rect.width,
                height: fragment.rect.height,
                child: _ReaderLayoutFragmentView(
                  fragment: fragment,
                  textStyle:
                      fragment.styleKey == 'title'
                          ? resolvedTitleStyle
                          : defaultTextStyle,
                  imagePlaceholderBuilder: imagePlaceholderBuilder,
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _ReaderLayoutFragmentView extends StatelessWidget {
  const _ReaderLayoutFragmentView({
    required this.fragment,
    required this.textStyle,
    this.imagePlaceholderBuilder,
  });

  final ReaderLayoutRenderFragment fragment;
  final TextStyle textStyle;
  final ReaderLayoutImagePlaceholderBuilder? imagePlaceholderBuilder;

  @override
  Widget build(BuildContext context) {
    return switch (fragment.kind) {
      ReaderLayoutRenderFragmentKind.text => Text(
        fragment.text,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: textStyle,
      ),
      ReaderLayoutRenderFragmentKind.image =>
        imagePlaceholderBuilder?.call(context, fragment) ??
            const ColoredBox(color: Color(0xFFE0E0E0)),
      ReaderLayoutRenderFragmentKind.placeholder => const SizedBox.expand(),
    };
  }
}
