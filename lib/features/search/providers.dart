import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/composition/app_providers.dart' as app_providers;
import '../book/application/book_presentation_query_service.dart';
import 'application/search_history_service.dart';
import 'application/search_failure_export_service.dart';
import 'application/server_book_gateway_service.dart';
import 'application/server_online_search_service.dart';
import 'application/search_system_settings_service.dart';

final serverOnlineSearchServiceProvider = Provider<ServerOnlineSearchService>((
  ref,
) {
  return ServerOnlineSearchService();
});

final serverBookGatewayServiceProvider = Provider<ServerBookGatewayService>((
  ref,
) {
  return ServerBookGatewayService();
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
