import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_session_store.dart';
import '../../core/mobile_features/mobile_feature_service.dart';
import 'application/source_check_service.dart';
import 'application/source_health_service.dart';
import 'application/source_login_runtime_service.dart';
import 'application/source_page_flow_coordinator.dart';
import 'application/source_runtime_facade.dart';

final sourceRuntimeFacadeProvider = Provider<SourceRuntimeFacade>((ref) {
  return SourceRuntimeFacade.instance;
});

final sourceCheckServiceProvider = Provider<SourceCheckService>((ref) {
  return SourceCheckService(
    sourceRuntimeFacade: ref.watch(sourceRuntimeFacadeProvider),
  );
});

final sourceHealthServiceProvider = Provider<SourceHealthService>((ref) {
  return SourceHealthService.instance;
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

typedef SourcePageFlowCoordinatorFactory = SourcePageFlowCoordinator Function();

final sourcePageFlowCoordinatorFactoryProvider =
    Provider<SourcePageFlowCoordinatorFactory>((ref) {
      return () => SourcePageFlowCoordinator();
    });
