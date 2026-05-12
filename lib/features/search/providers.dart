import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/composition/app_providers.dart' as app_providers;
import '../book/application/book_presentation_query_service.dart';
import '../source/application/source_runtime_facade.dart';
import 'application/search_history_service.dart';
import 'application/search_failure_export_service.dart';
import 'application/search_service.dart';
import 'application/search_system_settings_service.dart';

final searchSourceRuntimeFacadeProvider = Provider<SourceRuntimeFacade>((ref) {
  return ref.watch(app_providers.appSourceRuntimeFacadeProvider);
});

final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService(
    sourceRuntimeFacade: ref.watch(searchSourceRuntimeFacadeProvider),
  );
});

final searchHistoryServiceProvider = Provider<SearchHistoryService>((ref) {
  return SearchHistoryService();
});

final searchSystemSettingsServiceProvider =
    Provider<SearchSystemSettingsService>((ref) {
      return SearchSystemSettingsService();
    });

final searchFailureExportServiceProvider = Provider<SearchFailureExportService>(
  (ref) {
    return SearchFailureExportService();
  },
);

final searchBookPresentationQueryServiceProvider =
    Provider<BookPresentationQueryService>((ref) {
      return ref.watch(app_providers.bookPresentationQueryServiceProvider);
    });
