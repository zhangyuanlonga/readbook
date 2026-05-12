import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_flow_coordinator.dart';

void main() {
  group('BookshelfFlowCoordinator', () {
    const coordinator = BookshelfFlowCoordinator();

    test('collapses search only when no focus keyword or pinned visibility', () {
      expect(
        coordinator.shouldCollapseSearch(
          hasFocus: false,
          hasKeyword: false,
          alwaysShowSearchBar: false,
          isSearchExpanded: true,
        ),
        isTrue,
      );
      expect(
        coordinator.shouldCollapseSearch(
          hasFocus: true,
          hasKeyword: false,
          alwaysShowSearchBar: false,
          isSearchExpanded: true,
        ),
        isFalse,
      );
    });

    test('selection helpers toggle select all and sync visible keys', () {
      final toggled = coordinator.toggleSelectedKeys(const {'a'}, 'b');
      expect(toggled, {'a', 'b'});

      final untoggled = coordinator.toggleSelectedKeys(toggled, 'a');
      expect(untoggled, {'b'});

      final selectedAll = coordinator.selectAllVisibleKeys(const ['a', 'b']);
      expect(selectedAll, {'a', 'b'});

      final synced = coordinator.syncSelectedKeys(
        selectedKeys: const {'a', 'b', 'c'},
        visibleKeys: const ['b', 'c', 'd'],
      );
      expect(synced, {'b', 'c'});
    });

    test('imports local books and aggregates result', () async {
      final imported = <String>[];
      final summary = await coordinator.importLocalBooks(
        candidates: const [
          BookshelfImportCandidate(filePath: '/tmp/a.txt', displayName: 'A'),
          BookshelfImportCandidate(filePath: '/tmp/b.txt', displayName: 'B'),
        ],
        importer: (candidate) async {
          if (candidate.displayName == 'B') {
            throw StateError('boom');
          }
          imported.add(candidate.displayName);
        },
        errorFormatter: (error) => '导入失败：$error',
      );

      expect(imported, ['A']);
      expect(summary.successCount, 1);
      expect(summary.failureCount, 1);
      expect(summary.lastError, contains('导入失败'));
    });
  });
}
