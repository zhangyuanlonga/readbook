import '../../../domain/entities/bookmark.dart';
import 'reader_annotation_controller.dart';
import 'reader_selection_state.dart';

class ReaderAnnotationPresenterState {
  const ReaderAnnotationPresenterState({
    required this.toolbarState,
    required this.actions,
  });

  final ReaderAnnotationToolbarState toolbarState;
  final List<ReaderAnnotationToolbarAction> actions;
}

class ReaderAnnotationPresenter {
  const ReaderAnnotationPresenter({
    ReaderAnnotationController controller = const ReaderAnnotationController(),
  }) : _controller = controller;

  final ReaderAnnotationController _controller;

  ReaderAnnotationPresenterState resolveState({
    required ReaderSelectionState selectionState,
    required Bookmark? existingBookmark,
  }) {
    final toolbarState = _controller.resolveToolbarState(
      selectionState: selectionState,
      existingBookmark: existingBookmark,
    );
    return ReaderAnnotationPresenterState(
      toolbarState: toolbarState,
      actions: _controller.buildToolbarActions(toolbarState),
    );
  }
}
