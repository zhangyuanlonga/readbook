import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/datasources/local/app_database.dart';
import '../../../core/membership/membership_access_resolver.dart';
import '../../../core/membership/membership_entitlement.dart';
import '../../../core/mobile_features/mobile_feature_module.dart';

const Object _remoteAccessSnapshotUnset = Object();

class RemoteAccessSnapshot {
  const RemoteAccessSnapshot({
    required this.serverSourceGatewayEnabled,
    required this.hasMembership,
    required this.hasThemeCustom,
    required this.serverSourceGatewayLimit,
    required this.cachedAt,
    this.vipExpireAt,
    this.membershipPlanType,
  });

  final bool serverSourceGatewayEnabled;
  final bool hasMembership;
  final bool hasThemeCustom;
  final int serverSourceGatewayLimit;
  final DateTime cachedAt;
  final DateTime? vipExpireAt;
  final String? membershipPlanType;

  bool isFresh({
    Duration ttl = RemoteAccessSnapshotService.defaultTtl,
    DateTime Function()? now,
  }) {
    return (now ?? DateTime.now)().difference(cachedAt) < ttl;
  }

  RemoteAccessSnapshot copyWith({
    bool? serverSourceGatewayEnabled,
    bool? hasMembership,
    bool? hasThemeCustom,
    int? serverSourceGatewayLimit,
    DateTime? cachedAt,
    Object? vipExpireAt = _remoteAccessSnapshotUnset,
    Object? membershipPlanType = _remoteAccessSnapshotUnset,
  }) {
    return RemoteAccessSnapshot(
      serverSourceGatewayEnabled:
          serverSourceGatewayEnabled ?? this.serverSourceGatewayEnabled,
      hasMembership: hasMembership ?? this.hasMembership,
      hasThemeCustom: hasThemeCustom ?? this.hasThemeCustom,
      serverSourceGatewayLimit:
          serverSourceGatewayLimit ?? this.serverSourceGatewayLimit,
      cachedAt: cachedAt ?? this.cachedAt,
      vipExpireAt:
          identical(vipExpireAt, _remoteAccessSnapshotUnset)
              ? this.vipExpireAt
              : vipExpireAt as DateTime?,
      membershipPlanType:
          identical(membershipPlanType, _remoteAccessSnapshotUnset)
              ? this.membershipPlanType
              : membershipPlanType as String?,
    );
  }

  RemoteAccessSnapshot normalizedMembershipAccess() {
    if (!hasMembership || hasThemeCustom) {
      return this;
    }

    // 高级主题是会员基础能力。旧桌面缓存可能只记录会员身份，却把主题权益
    // 留在 false；读取和保存时统一纠正，避免会员页与功能入口判断不一致。
    return copyWith(hasThemeCustom: true);
  }

  factory RemoteAccessSnapshot.fromJson(Map<String, dynamic> json) {
    final rawLimit =
        json['serverSourceGatewayLimit'] ?? json['sourceImportLimit'];
    return RemoteAccessSnapshot(
      serverSourceGatewayEnabled:
          json['serverSourceGatewayEnabled'] == true ||
          json['showSourceEntry'] == true,
      hasMembership: json['hasMembership'] == true,
      hasThemeCustom: json['hasThemeCustom'] == true,
      serverSourceGatewayLimit: rawLimit is int ? rawLimit : 10,
      cachedAt:
          DateTime.tryParse(json['cachedAt']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      vipExpireAt:
          DateTime.tryParse(json['vipExpireAt']?.toString() ?? '')?.toUtc(),
      membershipPlanType: json['membershipPlanType']?.toString().trim(),
    );
  }

  Map<String, Object> toJson() {
    final data = <String, Object>{
      'serverSourceGatewayEnabled': serverSourceGatewayEnabled,
      'hasMembership': hasMembership,
      'hasThemeCustom': hasThemeCustom,
      'serverSourceGatewayLimit': serverSourceGatewayLimit,
      'cachedAt': cachedAt.toUtc().toIso8601String(),
    };
    final expireAt = vipExpireAt;
    if (expireAt != null) {
      data['vipExpireAt'] = expireAt.toUtc().toIso8601String();
    }
    final planType = membershipPlanType?.trim() ?? '';
    if (planType.isNotEmpty) {
      data['membershipPlanType'] = planType;
    }
    return data;
  }
}

class RemoteAccessSnapshotService {
  RemoteAccessSnapshotService({
    SharedPreferences? preferences,
    AppDatabase? database,
  }) : _preferencesFuture =
           preferences == null
               ? SharedPreferences.getInstance()
               : Future.value(preferences),
       _database = database ?? AppDatabase.instance;

  static const Duration defaultTtl = Duration(hours: 12);

  final Future<SharedPreferences> _preferencesFuture;
  final AppDatabase _database;

  Future<RemoteAccessSnapshot?> load(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return null;
    }

    final stored = await _database.getRemoteAccessSnapshot(normalizedUserId);
    if (stored != null) {
      final snapshot = RemoteAccessSnapshot(
        serverSourceGatewayEnabled: stored.serverSourceGatewayEnabled,
        hasMembership: stored.hasMembership,
        hasThemeCustom: stored.hasThemeCustom,
        serverSourceGatewayLimit: stored.serverSourceGatewayLimit,
        cachedAt: stored.cachedAt,
        vipExpireAt: stored.vipExpireAt,
        membershipPlanType: stored.membershipPlanType,
      );
      final hydrated = await _hydrateLegacyMembershipSidecar(
        normalizedUserId,
        snapshot,
      );
      final normalized = hydrated.normalizedMembershipAccess();
      if (normalized.hasThemeCustom != stored.hasThemeCustom ||
          normalized.vipExpireAt != stored.vipExpireAt ||
          normalized.membershipPlanType != stored.membershipPlanType) {
        await save(normalizedUserId, normalized);
      }
      return normalized;
    }

    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_storageKey(normalizedUserId))?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final snapshot =
          RemoteAccessSnapshot.fromJson(decoded).normalizedMembershipAccess();
      await _database.upsertRemoteAccessSnapshot(
        userId: normalizedUserId,
        serverSourceGatewayEnabled: snapshot.serverSourceGatewayEnabled,
        hasMembership: snapshot.hasMembership,
        hasThemeCustom: snapshot.hasThemeCustom,
        serverSourceGatewayLimit: snapshot.serverSourceGatewayLimit,
        cachedAt: snapshot.cachedAt,
        vipExpireAt: snapshot.vipExpireAt,
        membershipPlanType: snapshot.membershipPlanType,
      );
      await prefs.remove(_storageKey(normalizedUserId));
      await prefs.remove(_membershipSidecarKey(normalizedUserId));
      return snapshot;
    } catch (_) {
      await prefs.remove(_storageKey(normalizedUserId));
      return null;
    }
  }

  Future<void> save(String userId, RemoteAccessSnapshot snapshot) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return;
    }
    final normalizedSnapshot = snapshot.normalizedMembershipAccess();
    await _database.upsertRemoteAccessSnapshot(
      userId: normalizedUserId,
      serverSourceGatewayEnabled: normalizedSnapshot.serverSourceGatewayEnabled,
      hasMembership: normalizedSnapshot.hasMembership,
      hasThemeCustom: normalizedSnapshot.hasThemeCustom,
      serverSourceGatewayLimit: normalizedSnapshot.serverSourceGatewayLimit,
      cachedAt: normalizedSnapshot.cachedAt,
      vipExpireAt: normalizedSnapshot.vipExpireAt,
      membershipPlanType: normalizedSnapshot.membershipPlanType,
    );
    final prefs = await _preferencesFuture;
    await prefs.remove(_storageKey(normalizedUserId));
    await prefs.remove(_membershipSidecarKey(normalizedUserId));
  }

  Future<void> clear(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return;
    }
    await _database.deleteRemoteAccessSnapshot(normalizedUserId);
    final prefs = await _preferencesFuture;
    await prefs.remove(_storageKey(normalizedUserId));
    await prefs.remove(_membershipSidecarKey(normalizedUserId));
  }

  Future<void> saveFromModulesAndEntitlement({
    required String userId,
    required List<MobileFeatureModule> modules,
    required MembershipEntitlement entitlement,
  }) {
    return save(
      userId,
      buildFromModulesAndEntitlement(
        modules: modules,
        entitlement: entitlement,
      ),
    );
  }

  Future<void> saveMergedMembership({
    required String userId,
    required MembershipEntitlement entitlement,
  }) async {
    final existing = await load(userId);
    final access = MembershipAccessResolver.fromEntitlement(entitlement);
    final hasMembership = access.hasMembership;
    await save(
      userId,
      (existing ?? _defaultSnapshot()).copyWith(
        hasMembership: hasMembership,
        hasThemeCustom: hasMembership && access.hasThemeCustom,
        vipExpireAt: hasMembership ? access.vipExpireAt : null,
        membershipPlanType: hasMembership ? access.planType : null,
        cachedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> saveMergedModules({
    required String userId,
    required List<MobileFeatureModule> modules,
  }) async {
    final existing = await load(userId);
    final gatewayEntry =
        _findModule(modules, 'server_source_gateway') ??
        _findModule(modules, 'source_entry');
    final gatewayQuota =
        _findModule(modules, 'server_source_gateway_limit') ??
        _findModule(modules, 'source_import');
    await save(
      userId,
      (existing ?? _defaultSnapshot()).copyWith(
        serverSourceGatewayEnabled: gatewayEntry?.visible == true,
        serverSourceGatewayLimit: gatewayQuota?.quotaLimit ?? 10,
        cachedAt: DateTime.now().toUtc(),
      ),
    );
  }

  RemoteAccessSnapshot buildFromModulesAndEntitlement({
    required List<MobileFeatureModule> modules,
    required MembershipEntitlement entitlement,
  }) {
    final access = MembershipAccessResolver.fromEntitlement(entitlement);
    final hasMembership = access.hasMembership;
    final gatewayEntry =
        _findModule(modules, 'server_source_gateway') ??
        _findModule(modules, 'source_entry');
    final gatewayQuota =
        _findModule(modules, 'server_source_gateway_limit') ??
        _findModule(modules, 'source_import');
    return RemoteAccessSnapshot(
      serverSourceGatewayEnabled: gatewayEntry?.visible == true,
      hasMembership: hasMembership,
      hasThemeCustom: hasMembership && access.hasThemeCustom,
      serverSourceGatewayLimit: gatewayQuota?.quotaLimit ?? 10,
      vipExpireAt: hasMembership ? access.vipExpireAt : null,
      membershipPlanType: hasMembership ? access.planType : null,
      cachedAt: DateTime.now().toUtc(),
    );
  }

  String _storageKey(String userId) => 'remote.access.snapshot.v1.$userId';

  String _membershipSidecarKey(String userId) =>
      'remote.access.membership.v1.$userId';

  Future<({DateTime? vipExpireAt, String? membershipPlanType})>
  _loadMembershipSidecar(String userId) async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_membershipSidecarKey(userId))?.trim();
    if (raw == null || raw.isEmpty) {
      return (vipExpireAt: null, membershipPlanType: null);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return (vipExpireAt: null, membershipPlanType: null);
      }
      return (
        vipExpireAt:
            DateTime.tryParse(
              decoded['vipExpireAt']?.toString() ?? '',
            )?.toUtc(),
        membershipPlanType: decoded['membershipPlanType']?.toString().trim(),
      );
    } catch (_) {
      await prefs.remove(_membershipSidecarKey(userId));
      return (vipExpireAt: null, membershipPlanType: null);
    }
  }

  Future<RemoteAccessSnapshot> _hydrateLegacyMembershipSidecar(
    String userId,
    RemoteAccessSnapshot snapshot,
  ) async {
    if (snapshot.vipExpireAt != null ||
        (snapshot.membershipPlanType?.trim().isNotEmpty ?? false)) {
      return snapshot;
    }

    final sidecar = await _loadMembershipSidecar(userId);
    if (sidecar.vipExpireAt == null &&
        (sidecar.membershipPlanType?.trim().isEmpty ?? true)) {
      return snapshot;
    }
    final hydrated = snapshot.copyWith(
      vipExpireAt: sidecar.vipExpireAt,
      membershipPlanType: sidecar.membershipPlanType,
    );
    await _database.upsertRemoteAccessSnapshot(
      userId: userId,
      serverSourceGatewayEnabled: hydrated.serverSourceGatewayEnabled,
      hasMembership: hydrated.hasMembership,
      hasThemeCustom: hydrated.hasThemeCustom,
      serverSourceGatewayLimit: hydrated.serverSourceGatewayLimit,
      cachedAt: hydrated.cachedAt,
      vipExpireAt: hydrated.vipExpireAt,
      membershipPlanType: hydrated.membershipPlanType,
    );
    final prefs = await _preferencesFuture;
    await prefs.remove(_membershipSidecarKey(userId));
    return hydrated;
  }

  MobileFeatureModule? _findModule(
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

  RemoteAccessSnapshot _defaultSnapshot() {
    return RemoteAccessSnapshot(
      serverSourceGatewayEnabled: false,
      hasMembership: false,
      hasThemeCustom: false,
      serverSourceGatewayLimit: 10,
      cachedAt: DateTime.now().toUtc(),
    );
  }
}
