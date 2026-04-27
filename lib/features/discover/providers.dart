import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/composition/app_providers.dart' as app_providers;
import '../book/application/book_presentation_query_service.dart';
import '../source/application/source_health_service.dart';
import '../source/application/source_runtime_scheduler_service.dart';
import '../source/application/source_runtime_task_conflict_service.dart';
import 'application/discover_preferences_service.dart';
import 'application/explore_service.dart';

final discoverExploreServiceProvider = Provider<ExploreService>((ref) {
  return ExploreService();
});

final discoverPreferencesServiceProvider = Provider<DiscoverPreferencesService>(
  (ref) {
    return DiscoverPreferencesService();
  },
);

final discoverSourceHealthServiceProvider = Provider<SourceHealthService>((
  ref,
) {
  return SourceHealthService.instance;
});

final discoverTaskConflictServiceProvider =
    Provider<SourceRuntimeTaskConflictService>((ref) {
      return SourceRuntimeTaskConflictService.instance;
    });

final discoverTaskSchedulerProvider = Provider<SourceRuntimeSchedulerService>((
  ref,
) {
  return SourceRuntimeSchedulerService.instance;
});

final discoverBookPresentationQueryServiceProvider =
    Provider<BookPresentationQueryService>((ref) {
      return ref.watch(app_providers.bookPresentationQueryServiceProvider);
    });
