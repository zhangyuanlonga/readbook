import 'reader_content_session.dart';

class ReaderContentModeSurfaceModel {
  const ReaderContentModeSurfaceModel({
    required this.mode,
    required this.viewportLabel,
    required this.supportsTextSelection,
    required this.supportsPagedText,
  });

  final ReaderContentMode mode;
  final String viewportLabel;
  final bool supportsTextSelection;
  final bool supportsPagedText;
}

class ReaderContentModeSurfaceController {
  const ReaderContentModeSurfaceController();

  ReaderContentModeSurfaceModel buildModel({
    required ReaderContentMode mode,
    required bool isTextPagedViewport,
    required bool isTextScrollViewport,
  }) {
    return ReaderContentModeSurfaceModel(
      mode: mode,
      viewportLabel: switch (mode) {
        ReaderContentMode.text => isTextPagedViewport ? '文本分页' : '文本滚动',
        ReaderContentMode.hybrid => '图文混排',
        ReaderContentMode.comic => '漫画阅读',
        ReaderContentMode.audio => '听书',
      },
      supportsTextSelection:
          mode == ReaderContentMode.text &&
          (isTextPagedViewport || isTextScrollViewport),
      supportsPagedText: mode == ReaderContentMode.text && isTextPagedViewport,
    );
  }
}
