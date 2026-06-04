import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local book import feedback stays page scoped', () async {
    final localLibrarySource =
        await File(
          'lib/features/bookshelf/presentation/local_library_page.dart',
        ).readAsString();

    expect(localLibrarySource, contains('ImportExportTaskSheet'));
    expect(localLibrarySource, contains('立即阅读'));
    expect(localLibrarySource, contains('导入失败'));
    expect(localLibrarySource, isNot(contains('appTaskManagerProvider')));
    expect(localLibrarySource, isNot(contains('AppTaskManager')));
    expect(localLibrarySource, isNot(contains('local-book-import')));
    expect(localLibrarySource, isNot(contains('local-book-reindex')));
  });

  test(
    'external local book import sheet does not publish global tasks',
    () async {
      final bookshelfFlowSource =
          await File(
            'lib/features/bookshelf/presentation/bookshelf_page_flow.dart',
          ).readAsString();
      final externalSheetStart = bookshelfFlowSource.indexOf(
        'class _BookshelfExternalImportSheet',
      );
      final localImportSheetStart = bookshelfFlowSource.indexOf(
        'class _BookshelfImportLocalBooksSheet',
      );

      expect(externalSheetStart, greaterThanOrEqualTo(0));
      expect(localImportSheetStart, greaterThan(externalSheetStart));

      final externalSheetSource = bookshelfFlowSource.substring(
        externalSheetStart,
        localImportSheetStart,
      );

      expect(externalSheetSource, contains('ImportExportTaskSheet'));
      expect(externalSheetSource, contains('导入外部图书失败'));
      expect(externalSheetSource, isNot(contains('AppTaskManager')));
      expect(externalSheetSource, isNot(contains('toAppTaskStatusData')));
      expect(externalSheetSource, isNot(contains('localBookImport')));
      expect(externalSheetSource, isNot(contains('external-book-import')));
    },
  );
}
