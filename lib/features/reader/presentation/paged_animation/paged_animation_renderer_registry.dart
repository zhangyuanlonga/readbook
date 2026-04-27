import 'package:flutter/widgets.dart';

import '../../../../domain/entities/reader_settings.dart';
import 'cover_paged_animation_renderer.dart';
import 'curl_paged_animation_renderer.dart';
import 'fade_paged_animation_renderer.dart';
import 'paged_animation_renderer.dart';
import 'translate_paged_animation_renderer.dart';
import 'vertical_paged_animation_renderer.dart';

class PagedAnimationRendererRegistry {
  const PagedAnimationRendererRegistry();

  PagedAnimationRenderer resolve(ReaderPageAnimationStyle style) {
    return switch (style) {
      ReaderPageAnimationStyle.curl => const _CurlPagedAnimationAdapter(),
      ReaderPageAnimationStyle.cover => const CoverPagedAnimationRenderer(),
      ReaderPageAnimationStyle.translate =>
        const TranslatePagedAnimationRenderer(),
      ReaderPageAnimationStyle.vertical =>
        const VerticalPagedAnimationRenderer(),
      ReaderPageAnimationStyle.fade => const FadePagedAnimationRenderer(),
      ReaderPageAnimationStyle.none => const FadePagedAnimationRenderer(),
    };
  }
}

class _CurlPagedAnimationAdapter extends PagedAnimationRenderer {
  const _CurlPagedAnimationAdapter();

  static const CurlPagedAnimationRenderer _renderer =
      CurlPagedAnimationRenderer();
  static const CurlRendererColors _colors = CurlRendererColors(
    backgroundColor: Color(0x00000000),
    dividerColor: Color(0x00000000),
    overlayColor: Color(0x00000000),
  );

  @override
  Widget build({
    required Widget fromPage,
    required Widget toPage,
    required double progress,
    required double direction,
  }) {
    return _renderer.build(
      currentPage: fromPage,
      targetPage: toPage,
      progress: progress,
      direction: direction >= 0 ? 1 : -1,
      touchYFactor: 0.82,
      colors: _colors,
    );
  }
}
