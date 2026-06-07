import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_selection_controller.dart';

void main() {
  group('ReaderSelectionController', () {
    const controller = ReaderSelectionController();

    test('blocks actions without active selection', () {
      final decision = controller.resolveAction(
        action: ReaderSelectionAction.copy,
        textSelectionActive: false,
        hasSnippet: true,
        hasExistingBookmark: false,
      );

      expect(decision.canExecute, isFalse);
      expect(decision.message, isNull);
    });

    test('blocks saving duplicate bookmark with message', () {
      final decision = controller.resolveAction(
        action: ReaderSelectionAction.saveBookmark,
        textSelectionActive: true,
        hasSnippet: true,
        hasExistingBookmark: true,
      );

      expect(decision.canExecute, isFalse);
      expect(decision.message, '灵感已存在');
    });

    test('allows style action for active selected snippet', () {
      final decision = controller.resolveAction(
        action: ReaderSelectionAction.toggleHighlight,
        textSelectionActive: true,
        hasSnippet: true,
        hasExistingBookmark: false,
      );

      expect(decision.canExecute, isTrue);
      expect(decision.message, isNull);
    });
  });
}
