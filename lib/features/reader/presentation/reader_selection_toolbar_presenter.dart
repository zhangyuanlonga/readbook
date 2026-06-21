import 'package:flutter/material.dart';

import 'reader_annotation_controller.dart';
import 'reader_icons.dart';
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
      return ReaderIcons.delete;
    }
    return iconFor(action.kind);
  }

  IconData iconFor(ReaderAnnotationToolbarActionKind kind) {
    return switch (kind) {
      ReaderAnnotationToolbarActionKind.copy => ReaderIcons.copy,
      ReaderAnnotationToolbarActionKind.saveOrRemoveBookmark =>
        ReaderIcons.inspiration,
      ReaderAnnotationToolbarActionKind.editNote => ReaderIcons.note,
      ReaderAnnotationToolbarActionKind.toggleHighlight =>
        ReaderIcons.highlight,
      ReaderAnnotationToolbarActionKind.toggleBold => ReaderIcons.bold,
      ReaderAnnotationToolbarActionKind.toggleUnderline =>
        ReaderIcons.underline,
      ReaderAnnotationToolbarActionKind.toggleWavy => ReaderIcons.wavyUnderline,
      ReaderAnnotationToolbarActionKind.clearSelection => ReaderIcons.close,
    };
  }
}
