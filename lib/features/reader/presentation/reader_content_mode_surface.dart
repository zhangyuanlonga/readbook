part of 'reader_page.dart';

extension _ReaderContentModeSurface on _ReaderPageState {
  ReaderContentModeSurfaceModel get _currentContentModeSurfaceModel {
    return _contentModeSurfaceController.buildModel(
      mode: _currentContentMode,
      isTextPagedViewport: _isTextPagedViewport,
      isTextScrollViewport: _isTextScrollViewport,
    );
  }
}
