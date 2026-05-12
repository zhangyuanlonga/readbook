import '../domain/sync_scope.dart';

class SyncScopeCatalogGroup {
  const SyncScopeCatalogGroup({required this.title, required this.scopes});

  final String title;
  final List<SyncScope> scopes;
}

class SyncScopeCatalogService {
  const SyncScopeCatalogService();

  List<SyncScope> get allScopes => SyncScope.values;

  List<SyncScope> get firstBatchScopes => SyncScope.values
      .where((item) => item.isFirstBatch)
      .toList(growable: false);

  List<SyncScopeCatalogGroup> buildGroups() {
    return <SyncScopeCatalogGroup>[
      SyncScopeCatalogGroup(
        title: '核心阅读资产',
        scopes: _scopesForCategory(SyncScopeCategory.coreReading),
      ),
      SyncScopeCatalogGroup(
        title: '会员外观',
        scopes: _scopesForCategory(SyncScopeCategory.membershipAppearance),
      ),
      SyncScopeCatalogGroup(
        title: '应用与阅读偏好',
        scopes: _scopesForCategory(SyncScopeCategory.appPreferences),
      ),
      SyncScopeCatalogGroup(
        title: '资源扩展',
        scopes: _scopesForCategory(SyncScopeCategory.resourceExtension),
      ),
      SyncScopeCatalogGroup(
        title: '延后评估',
        scopes: _scopesForCategory(SyncScopeCategory.deferred),
      ),
      SyncScopeCatalogGroup(
        title: '明确排除',
        scopes: _scopesForCategory(SyncScopeCategory.excluded),
      ),
    ];
  }

  List<SyncScope> _scopesForCategory(SyncScopeCategory category) {
    return SyncScope.values
        .where((item) => item.category == category)
        .toList(growable: false);
  }
}
