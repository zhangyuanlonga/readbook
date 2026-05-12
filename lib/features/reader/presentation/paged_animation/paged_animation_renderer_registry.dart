import '../../../../domain/entities/reader_settings.dart';
import 'cover_paged_animation_renderer.dart';
import 'fade_paged_animation_renderer.dart';
import 'paged_animation_renderer.dart';
import 'translate_paged_animation_renderer.dart';
import 'vertical_paged_animation_renderer.dart';

class PagedAnimationRendererRegistry {
  const PagedAnimationRendererRegistry();

  PagedAnimationRenderer resolve(ReaderPageAnimationStyle style) {
    return switch (style) {
      ReaderPageAnimationStyle.cover => const CoverPagedAnimationRenderer(),
      ReaderPageAnimationStyle.translate =>
        const TranslatePagedAnimationRenderer(),
      ReaderPageAnimationStyle.vertical =>
        const VerticalPagedAnimationRenderer(),
      ReaderPageAnimationStyle.fade => const FadePagedAnimationRenderer(),
      ReaderPageAnimationStyle.curl ||
      ReaderPageAnimationStyle.none => const FadePagedAnimationRenderer(),
    };
  }
}
