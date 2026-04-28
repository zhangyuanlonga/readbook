import '../../../core/auth/auth_session_store.dart';
import '../../../core/mobile_features/mobile_feature_module.dart';
import '../../../core/mobile_features/mobile_feature_service.dart';

class SourcePageFeatureAccess {
  const SourcePageFeatureAccess({
    required this.canAccessSourcePage,
    required this.sourceImportLimit,
  });

  final bool canAccessSourcePage;
  final int sourceImportLimit;
}

class SourcePageAccessService {
  const SourcePageAccessService({
    required AuthSessionStore authSessionStore,
    required MobileFeatureService mobileFeatureService,
  }) : _authSessionStore = authSessionStore,
       _mobileFeatureService = mobileFeatureService;

  final AuthSessionStore _authSessionStore;
  final MobileFeatureService _mobileFeatureService;

  Future<SourcePageFeatureAccess> loadFeatureAccess() async {
    final session = await _authSessionStore.getSession();
    final modules = await (session == null
            ? _mobileFeatureService.fetchPublicModules()
            : _mobileFeatureService.fetchMyModules())
        .timeout(const Duration(seconds: 5));
    final sourceEntry = _findFeatureModule(modules, 'source_entry');
    final sourceImport = _findFeatureModule(modules, 'source_import');
    return SourcePageFeatureAccess(
      canAccessSourcePage: _isSourceEntryAccessible(sourceEntry),
      sourceImportLimit: sourceImport?.quotaLimit ?? 10,
    );
  }

  bool canAddSource({
    required bool isLoading,
    required int sourceImportLimit,
    required int currentSourceCount,
  }) {
    if (isLoading) {
      return false;
    }
    if (sourceImportLimit < 0) {
      return true;
    }
    return currentSourceCount < sourceImportLimit;
  }

  int remainingSourceImportSlots({
    required int sourceImportLimit,
    required int currentSourceCount,
  }) {
    if (sourceImportLimit < 0) {
      return -1;
    }
    final remaining = sourceImportLimit - currentSourceCount;
    return remaining < 0 ? 0 : remaining;
  }

  MobileFeatureModule? _findFeatureModule(
    List<MobileFeatureModule> modules,
    String code,
  ) {
    for (final item in modules) {
      if (item.code == code) {
        return item;
      }
    }
    return null;
  }

  bool _isSourceEntryAccessible(MobileFeatureModule? sourceEntry) {
    if (sourceEntry == null) {
      return true;
    }
    return sourceEntry.visible && sourceEntry.enabled;
  }
}
