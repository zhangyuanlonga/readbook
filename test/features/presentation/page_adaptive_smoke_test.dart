import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_appread/features/bookshelf/presentation/bookshelf_page.dart';
import 'package:flutter_appread/features/mine/presentation/mine_page.dart';
import 'package:flutter_appread/features/search/presentation/search_page.dart';
import '../../test_utils/adaptive_test_harness.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('BookshelfPage renders on phone and large screens', (
    tester,
  ) async {
    await runAdaptivePageSmokeMatrix(
      tester,
      pageBuilder: () => const BookshelfPage(prefetchAnnouncementOnInit: false),
      pageName: 'BookshelfPage',
    );
  });

  testWidgets('MinePage renders on phone and large screens', (tester) async {
    await runAdaptivePageSmokeMatrix(
      tester,
      pageBuilder: () => const MinePage(),
      useProviderScope: true,
      pageName: 'MinePage',
    );
  });

  testWidgets('SearchPage renders on phone and large screens', (tester) async {
    await runAdaptivePageSmokeMatrix(
      tester,
      pageBuilder: () => const SearchPage(),
      pageName: 'SearchPage',
    );
  });
}
