import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/features/book/application/book_local_metadata_service.dart';
import 'package:shuxiang_reading_next/features/book/application/local_book_detail_service.dart';
import 'package:shuxiang_reading_next/features/book/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  test('book providers expose detail dependencies and local services', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final dependencies = container.read(bookDetailDependenciesProvider);
    final metadataService = container.read(bookLocalMetadataServiceProvider);
    final localBookDetailService = container.read(
      bookLocalBookDetailServiceProvider,
    );

    expect(dependencies, isA<BookDetailDependencies>());
    expect(metadataService, isA<BookLocalMetadataService>());
    expect(localBookDetailService, isA<LocalBookDetailService>());
  });
}
