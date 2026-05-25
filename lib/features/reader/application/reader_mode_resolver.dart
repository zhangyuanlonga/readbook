import '../../../domain/entities/reader_settings.dart';
import 'reader_content_session.dart';
import 'reader_mode_model.dart';

class ReaderModeResolver {
  const ReaderModeResolver();

  ReaderModeModel resolve({
    required ReaderContentMode contentMode,
    required ReaderSettings settings,
    required bool canUsePagedText,
  }) {
    switch (contentMode) {
      case ReaderContentMode.text:
        final usesScrollLayout =
            !canUsePagedText || settings.pageTurnMode.usesScrollLayout;
        return ReaderModeModel(
          contentKind: ReaderContentKind.text,
          layoutMode:
              usesScrollLayout
                  ? ReaderLayoutMode.scroll
                  : ReaderLayoutMode.paged,
          viewportKind:
              usesScrollLayout
                  ? ReaderModeViewportKind.textScroll
                  : ReaderModeViewportKind.textPaged,
          supportsTextSelection: true,
          supportsZoomGesture: false,
          supportsAutoRead: true,
          sourcePageTurnMode: settings.pageTurnMode,
          tapTurnEnabled: settings.pageTurnMode.tapEnabled,
          swipeTurnEnabled:
              !usesScrollLayout && settings.pageTurnMode.swipeEnabled,
          pageAnimationStyle:
              usesScrollLayout ? null : settings.pageAnimationStyle,
        );
      case ReaderContentMode.hybrid:
        return ReaderModeModel(
          contentKind: ReaderContentKind.document,
          layoutMode: ReaderLayoutMode.paged,
          viewportKind: ReaderModeViewportKind.hybridPaged,
          supportsTextSelection: false,
          supportsZoomGesture: true,
          supportsAutoRead: false,
          sourcePageTurnMode: settings.pageTurnMode,
          tapTurnEnabled: false,
          swipeTurnEnabled: false,
          pageAnimationStyle: null,
        );
      case ReaderContentMode.comic:
        final isContinuous =
            settings.mangaReadMode == ReaderMangaReadMode.continuous;
        return ReaderModeModel(
          contentKind: ReaderContentKind.image,
          layoutMode:
              isContinuous ? ReaderLayoutMode.scroll : ReaderLayoutMode.paged,
          viewportKind:
              isContinuous
                  ? ReaderModeViewportKind.imageScroll
                  : ReaderModeViewportKind.imagePaged,
          supportsTextSelection: false,
          supportsZoomGesture: true,
          supportsAutoRead: false,
          sourcePageTurnMode: settings.pageTurnMode,
          tapTurnEnabled: false,
          swipeTurnEnabled: false,
          pageAnimationStyle: null,
        );
      case ReaderContentMode.audio:
        return ReaderModeModel(
          contentKind: ReaderContentKind.audio,
          layoutMode: ReaderLayoutMode.scroll,
          viewportKind: ReaderModeViewportKind.textScroll,
          supportsTextSelection: false,
          supportsZoomGesture: false,
          supportsAutoRead: false,
          sourcePageTurnMode: settings.pageTurnMode,
          tapTurnEnabled: false,
          swipeTurnEnabled: false,
          pageAnimationStyle: null,
        );
    }
  }
}
