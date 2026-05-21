import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/datasources/local/app_database.dart';
import '../../../core/membership/membership_entitlement.dart';
import '../../../core/membership/membership_features.dart';
import '../../../core/mobile_features/mobile_feature_module.dart';

class RemoteAccessSnapshot {
  const RemoteAccessSnapshot({
    required this.showSourceEntry,
    required this.hasMembership,
    required this.hasThemeCustom,
    required this.sourceImportLimit,
    required this.cachedAt,
  });

  final bool showSourceEntry;
  final bool hasMembership;
  final bool hasThemeCustom;
  final int sourceImportLimit;
  final DateTime cachedAt;

  bool isFresh({
    Duration ttl = RemoteAccessSnapshotService.defaultTtl,
    DateTime Function()? now,
  }) {
    return (now ?? DateTime.now)().difference(cachedAt) < ttl;
  }

  RemoteAccessSnapshot copyWith({
    bool? showSourceEntry,
    bool? hasMembership,
    bool? hasThemeCustom,
    int? sourceImportLimit,
    DateTime? cachedAt,
  }) {
    return RemoteAccessSnapshot(
      showSourceEntry: showSourceEntry ?? this.showSourceEntry,
      hasMembership: hasMembership ?? this.hasMembership,
      hasThemeCustom: hasThemeCustom ?? this.hasThemeCustom,
      sourceImportLimit: sourceImportLimit ?? this.sourceImportLimit,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  factory RemoteAccessSnapshot.fromJson(Map<String, dynamic> json) {
    return RemoteAccessSnapshot(
      showSourceEntry: json['showSourceEntry'] == true,
      hasMembership: json['hasMembership'] == true,
      hasThemeCustom: json['hasThemeCustom'] == true,
      sourceImportLimit:
          json['sourceImportLimit'] is int
              ? json['sourceImportLimit'] as int
              : 10,
      cachedAt:
          DateTime.tryParse(json['cachedAt']?.toString() ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'showSourceEntry': showSourceEntry,
      'hasMembership': hasMembership,
      'hasThemeCustom': hasThemeCustom,
      'sourceImportLimit': sourceImportLimit,
      'cachedAt': cachedAt.toUtc().toIso8601String(),
    };
  }
}

class RemoteAccessSnapshotService {
  RemoteAccessSnapshotService({
    SharedPreferences? preferences,
    AppDatabase? database,
  })
    : _preferencesFuture =
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
      return RemoteAccessSnapshot(
        showSourceEntry: stored.showSourceEntry,
        hasMembership: stored.hasMembership,
        hasThemeCustom: stored.hasThemeCustom,
        sourceImportLimit: stored.sourceImportLimit,
        cachedAt: stored.cachedAt,
      );
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
      final snapshot = RemoteAccessSnapshot.fromJson(decoded);
      await _database.upsertRemoteAccessSnapshot(
        userId: normalizedUserId,
        showSourceEntry: snapshot.showSourceEntry,
        hasMembership: snapshot.hasMembership,
        hasThemeCustom: snapshot.hasThemeCustom,
        sourceImportLimit: snapshot.sourceImportLimit,
        cachedAt: snapshot.cachedAt,
      );
      await prefs.remove(_storageKey(normalizedUserId));
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
    await _database.upsertRemoteAccessSnapshot(
      userId: normalizedUserId,
      showSourceEntry: snapshot.showSourceEntry,
      hasMembership: snapshot.hasMembership,
      hasThemeCustom: snapshot.hasThemeCustom,
      sourceImportLimit: snapshot.sourceImportLimit,
      cachedAt: snapshot.cachedAt,
    );
    final prefs = await _preferencesFuture;
    await prefs.remove(_storageKey(normalizedUserId));
  }

  Future<void> clear(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return;
    }
    await _database.deleteRemoteAccessSnapshot(normalizedUserId);
    final prefs = await _preferencesFuture;
    await prefs.remove(_storageKey(normalizedUserId));
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
    await save(
      userId,
      (existing ?? _defaultSnapshot()).copyWith(
        hasMembership: entitlement.isActive,
        hasThemeCustom: MembershipFeatures.hasFeature(
          entitlement,
          MembershipFeatures.themeCustom,
        ),
        cachedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> saveMergedModules({
    required String userId,
    required List<MobileFeatureModule> modules,
  }) async {
    final existing = await load(userId);
    final sourceEntry = _findModule(modules, 'source_entry');
    final sourceImport = _findModule(modules, 'source_import');
    await save(
      userId,
      (existing ?? _defaultSnapshot()).copyWith(
        showSourceEntry: sourceEntry?.visible == true,
        sourceImportLimit: sourceImport?.quotaLimit ?? 10,
        cachedAt: DateTime.now().toUtc(),
      ),
    );
  }

  RemoteAccessSnapshot buildFromModulesAndEntitlement({
    required List<MobileFeatureModule> modules,
    required MembershipEntitlement entitlement,
  }) {
    final sourceEntry = _findModule(modules, 'source_entry');
    final sourceImport = _findModule(modules, 'source_import');
    return RemoteAccessSnapshot(
      showSourceEntry: sourceEntry?.visible == true,
      hasMembership: entitlement.isActive,
      hasThemeCustom: MembershipFeatures.hasFeature(
        entitlement,
        MembershipFeatures.themeCustom,
      ),
      sourceImportLimit: sourceImport?.quotaLimit ?? 10,
      cachedAt: DateTime.now().toUtc(),
    );
  }

  String _storageKey(String userId) => 'remote.access.snapshot.v1.$userId';

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
      showSourceEntry: false,
      hasMembership: false,
      hasThemeCustom: false,
      sourceImportLimit: 10,
      cachedAt: DateTime.now().toUtc(),
    );
  }
}
