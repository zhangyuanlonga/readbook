enum ReaderSelectionAction {
  copy,
  saveBookmark,
  toggleHighlight,
  toggleBold,
  toggleUnderline,
  toggleWavy,
}

class ReaderSelectionActionDecision {
  const ReaderSelectionActionDecision({required this.canExecute, this.message});

  final bool canExecute;
  final String? message;
}

class ReaderSelectionController {
  const ReaderSelectionController();

  ReaderSelectionActionDecision resolveAction({
    required ReaderSelectionAction action,
    required bool textSelectionActive,
    required bool hasSnippet,
    required bool hasExistingBookmark,
  }) {
    if (!textSelectionActive || !hasSnippet) {
      return const ReaderSelectionActionDecision(canExecute: false);
    }
    if (action == ReaderSelectionAction.saveBookmark && hasExistingBookmark) {
      return const ReaderSelectionActionDecision(
        canExecute: false,
        message: '灵感已存在',
      );
    }
    return const ReaderSelectionActionDecision(canExecute: true);
  }
}
