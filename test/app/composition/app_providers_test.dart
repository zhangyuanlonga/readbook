import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/app/composition/app_providers.dart';
import 'package:shuxiang_reading_next/features/book/providers.dart';
import 'package:shuxiang_reading_next/features/bookshelf/providers.dart';
import 'package:shuxiang_reading_next/features/mine/providers.dart';
import 'package:shuxiang_reading_next/features/source/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  test('app composition providers are reused by feature providers', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(bookBookmarkRepositoryProvider),
      same(container.read(bookmarkRepositoryProvider)),
    );
    expect(
      container.read(bookLocalBookRepositoryProvider),
      same(container.read(localBookRepositoryProvider)),
    );
    expect(
      container.read(bookshelfLocalBookRepositoryProvider),
      same(container.read(localBookRepositoryProvider)),
    );
    expect(
      container.read(mineBookmarkRepositoryProvider),
      same(container.read(bookmarkRepositoryProvider)),
    );
    expect(
      container.read(sourceRuntimeFacadeProvider),
      same(container.read(appSourceRuntimeFacadeProvider)),
    );
    expect(
      container.read(bookSourceRuntimeFacadeProvider),
      same(container.read(appSourceRuntimeFacadeProvider)),
    );
    expect(
      container.read(bookshelfSourceRuntimeFacadeProvider),
      same(container.read(appSourceRuntimeFacadeProvider)),
    );
  });
}
