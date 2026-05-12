import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/features/book/application/book_presentation_query_service.dart';
import 'package:shuxiang_reading_next/features/search/application/search_history_service.dart';
import 'package:shuxiang_reading_next/features/search/application/search_service.dart';
import 'package:shuxiang_reading_next/features/search/application/search_system_settings_service.dart';
import 'package:shuxiang_reading_next/features/search/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  test('search providers expose services and shared presentation query', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(searchServiceProvider), isA<SearchService>());
    expect(
      container.read(searchHistoryServiceProvider),
      isA<SearchHistoryService>(),
    );
    expect(
      container.read(searchSystemSettingsServiceProvider),
      isA<SearchSystemSettingsService>(),
    );
    expect(
      container.read(searchBookPresentationQueryServiceProvider),
      isA<BookPresentationQueryService>(),
    );
  });
}
