import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/bookshelf/presentation/bookshelf_page.dart';

void main() {
  test('mergeBookshelfTaxonomyNames keeps order-only items visible', () {
    final result = mergeBookshelfTaxonomyNames(
      counts: const {'已读': 2},
      order: const ['在读', '已读'],
    );

    expect(result, orderedEquals(const ['在读', '已读']));
  });

  test(
    'mergeBookshelfTaxonomyNames appends unordered items by count then name',
    () {
      final result = mergeBookshelfTaxonomyNames(
        counts: const {'科幻': 1, '玄幻': 3, '历史': 3},
        order: const ['在读'],
      );

      expect(result, orderedEquals(const ['在读', '历史', '玄幻', '科幻']));
    },
  );

  test(
    'mergeBookshelfTaxonomyNames removes blanks and duplicates from order',
    () {
      final result = mergeBookshelfTaxonomyNames(
        counts: const {'标签A': 1},
        order: const [' ', '标签A', '标签A', '标签B'],
      );

      expect(result, orderedEquals(const ['标签A', '标签B']));
    },
  );
}
