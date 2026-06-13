import 'package:flutter/material.dart';

import 'reader_annotation_controller.dart';
import 'reader_page_support_models.dart';

typedef ReaderSelectionToolbarActionCallback =
    VoidCallback? Function(ReaderAnnotationToolbarAction action);

class ReaderSelectionToolbarPresenter {
  const ReaderSelectionToolbarPresenter();

  List<ReaderInspirationActionItem> buildItems({
    required Iterable<ReaderAnnotationToolbarAction> actions,
    required ReaderSelectionToolbarActionCallback onAction,
  }) {
    return actions
        .map(
          (action) => ReaderInspirationActionItem(
            icon: iconForAction(action),
            label: action.label,
            isActive: action.isActive,
            onPressed: onAction(action) ?? () {},
          ),
        )
        .toList(growable: false);
  }

  IconData iconForAction(ReaderAnnotationToolbarAction action) {
    if (action.kind == ReaderAnnotationToolbarActionKind.saveOrRemoveBookmark &&
        action.isDestructive) {
      return Icons.delete_outline_rounded;
    }
    return iconFor(action.kind);
  }

  IconData iconFor(ReaderAnnotationToolbarActionKind kind) {
    return switch (kind) {
      ReaderAnnotationToolbarActionKind.copy => Icons.copy_all_rounded,
      ReaderAnnotationToolbarActionKind.saveOrRemoveBookmark =>
        Icons.lightbulb_outline_rounded,
      ReaderAnnotationToolbarActionKind.editNote => Icons.edit_note_rounded,
      ReaderAnnotationToolbarActionKind.toggleHighlight =>
        Icons.highlight_alt_rounded,
      ReaderAnnotationToolbarActionKind.toggleBold => Icons.format_bold_rounded,
      ReaderAnnotationToolbarActionKind.toggleUnderline =>
        Icons.format_underlined_rounded,
      ReaderAnnotationToolbarActionKind.toggleWavy =>
        Icons.multiline_chart_rounded,
      ReaderAnnotationToolbarActionKind.clearSelection => Icons.close_rounded,
    };
  }
}
