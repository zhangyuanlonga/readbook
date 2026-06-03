import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_page_state.dart';

void main() {
  group('BookshelfPageStateNotifier', () {
    test('stores filter, sort, and selection state in Riverpod', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(bookshelfPageStateProvider.notifier);

      notifier
        ..setActiveView(const BookshelfViewSelection.tag('连载中'))
        ..setSortMode(BookshelfSortMode.readingProgress)
        ..setSelection(
          const BookshelfSelectionState(
            enabled: true,
            selectedKeys: <String>{'source::detail'},
          ),
        );

      final state = container.read(bookshelfPageStateProvider);

      expect(state.activeView, const BookshelfViewSelection.tag('连载中'));
      expect(state.sortMode, BookshelfSortMode.readingProgress);
      expect(state.selection.enabled, isTrue);
      expect(state.selection.selectedKeys, <String>{'source::detail'});
    });

    test('syncs per-card loading state and prunes stale cards', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(bookshelfPageStateProvider.notifier);

      notifier.syncCardStates(
        validKeys: const <String>{'book-a', 'book-b'},
        resolveState:
            (key) => BookshelfBookCardState(cachedChapterCount: key.length),
      );

      expect(
        container.read(bookshelfPageStateProvider).cardStatesByKey.keys,
        containsAll(<String>['book-a', 'book-b']),
      );

      notifier.syncCardStates(
        validKeys: const <String>{'book-b'},
        resolveState:
            (key) => BookshelfBookCardState(cachedChapterCount: key.length + 1),
      );

      final state = container.read(bookshelfPageStateProvider);
      expect(state.cardStatesByKey.keys, <String>['book-b']);
      expect(state.cardStatesByKey['book-b']?.cachedChapterCount, 7);
    });
  });
}
