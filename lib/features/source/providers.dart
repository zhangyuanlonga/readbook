import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/composition/app_providers.dart' as app_providers;
import '../../core/auth/auth_session_store.dart';
import '../../core/mobile_features/mobile_feature_service.dart';
import 'application/source_check_service.dart';
import 'application/source_health_service.dart';
import 'application/source_login_browser_service.dart';
import 'application/source_login_entry_resolver.dart';
import 'application/source_login_runtime_service.dart';
import 'application/source_page_access_service.dart';
import 'application/source_page_flow_coordinator.dart';
import 'application/source_runtime_scheduler_service.dart';
import 'application/source_runtime_task_conflict_service.dart';
import 'application/source_script_import_service.dart';
import 'application/source_runtime_facade.dart';

final sourceRuntimeFacadeProvider = Provider<SourceRuntimeFacade>((ref) {
  return ref.watch(app_providers.appSourceRuntimeFacadeProvider);
});

final sourceCheckServiceProvider = Provider<SourceCheckService>((ref) {
  return SourceCheckService(
    sourceRuntimeFacade: ref.watch(sourceRuntimeFacadeProvider),
  );
});

final sourceHealthServiceProvider = Provider<SourceHealthService>((ref) {
  return ref.watch(app_providers.appSourceHealthServiceProvider);
});

final sourceAuthSessionStoreProvider = Provider<AuthSessionStore>((ref) {
  return AuthSessionStore();
});

final sourceMobileFeatureServiceProvider = Provider<MobileFeatureService>((
  ref,
) {
  return MobileFeatureService();
});

final sourceLoginRuntimeServiceProvider = Provider<SourceLoginRuntimeService>((
  ref,
) {
  return SourceLoginRuntimeService(
    sourceRuntimeFacade: ref.watch(sourceRuntimeFacadeProvider),
  );
});

final sourceLoginBrowserServiceProvider = Provider<SourceLoginBrowserService>((
  ref,
) {
  return SourceLoginBrowserService(
    browserExecutor: ref.watch(
      app_providers.appInteractiveVerificationBrowserExecutorProvider,
    ),
  );
});

final sourceLoginEntryResolverProvider = Provider<SourceLoginEntryResolver>((
  ref,
) {
  return SourceLoginEntryResolver(
    sourceRuntimeFacade: ref.watch(sourceRuntimeFacadeProvider),
    sourceLoginRuntimeService: ref.watch(sourceLoginRuntimeServiceProvider),
  );
});

final sourcePageAccessServiceProvider = Provider<SourcePageAccessService>((
  ref,
) {
  return SourcePageAccessService(
    authSessionStore: ref.watch(sourceAuthSessionStoreProvider),
    mobileFeatureService: ref.watch(sourceMobileFeatureServiceProvider),
  );
});

final sourceScriptImportServiceProvider = Provider<SourceScriptImportService>((
  ref,
) {
  return const SourceScriptImportService();
});

typedef SourcePageFlowCoordinatorFactory = SourcePageFlowCoordinator Function();

final sourcePageFlowCoordinatorFactoryProvider =
    Provider<SourcePageFlowCoordinatorFactory>((ref) {
      return () => SourcePageFlowCoordinator(
        externalImportBridge: ref.watch(
          app_providers.appExternalImportBridgeProvider,
        ),
        authEvents: ref.watch(app_providers.appAuthEventStreamProvider),
      );
    });

final sourceRuntimeTaskConflictServiceProvider =
    Provider<SourceRuntimeTaskConflictService>((ref) {
      return ref.watch(
        app_providers.appSourceRuntimeTaskConflictServiceProvider,
      );
    });

final sourceRuntimeSchedulerServiceProvider =
    Provider<SourceRuntimeSchedulerService>((ref) {
      return ref.watch(app_providers.appSourceRuntimeSchedulerServiceProvider);
    });
