import 'sync_scope.dart';

enum SyncDriverType { webdav }

class SyncProfile {
  const SyncProfile({
    required this.id,
    required this.name,
    required this.driverType,
    required this.endpointUrl,
    required this.basePath,
    required this.username,
    this.secretRef,
    this.enabledScopes = const <SyncScope>[],
    this.scopeConfigJson,
    this.isAutoSyncEnabled = false,
    this.lastSyncAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final SyncDriverType driverType;
  final String endpointUrl;
  final String basePath;
  final String username;
  final String? secretRef;
  final List<SyncScope> enabledScopes;
  final String? scopeConfigJson;
  final bool isAutoSyncEnabled;
  final DateTime? lastSyncAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  SyncProfile copyWith({
    String? id,
    String? name,
    SyncDriverType? driverType,
    String? endpointUrl,
    String? basePath,
    String? username,
    String? secretRef,
    bool clearSecretRef = false,
    List<SyncScope>? enabledScopes,
    String? scopeConfigJson,
    bool clearScopeConfigJson = false,
    bool? isAutoSyncEnabled,
    DateTime? lastSyncAt,
    bool clearLastSyncAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SyncProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      driverType: driverType ?? this.driverType,
      endpointUrl: endpointUrl ?? this.endpointUrl,
      basePath: basePath ?? this.basePath,
      username: username ?? this.username,
      secretRef: clearSecretRef ? null : (secretRef ?? this.secretRef),
      enabledScopes: enabledScopes ?? this.enabledScopes,
      scopeConfigJson:
          clearScopeConfigJson
              ? null
              : (scopeConfigJson ?? this.scopeConfigJson),
      isAutoSyncEnabled: isAutoSyncEnabled ?? this.isAutoSyncEnabled,
      lastSyncAt: clearLastSyncAt ? null : (lastSyncAt ?? this.lastSyncAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'driverType': driverType.name,
      'endpointUrl': endpointUrl,
      'basePath': basePath,
      'username': username,
      'secretRef': secretRef,
      'enabledScopes': enabledScopes.map((item) => item.name).toList(),
      'scopeConfigJson': scopeConfigJson,
      'isAutoSyncEnabled': isAutoSyncEnabled,
      'lastSyncAt': lastSyncAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SyncProfile.fromJson(Map<String, dynamic> json) {
    return SyncProfile(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      driverType: _parseDriverType(json['driverType']),
      endpointUrl: _requiredString(json, 'endpointUrl'),
      basePath: _requiredString(json, 'basePath'),
      username: _requiredString(json, 'username'),
      secretRef: _optionalString(json['secretRef']),
      enabledScopes: _parseScopes(json['enabledScopes']),
      scopeConfigJson: _optionalString(json['scopeConfigJson']),
      isAutoSyncEnabled: _asBool(json['isAutoSyncEnabled']) ?? false,
      lastSyncAt: _optionalDateTime(json['lastSyncAt']),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }

  static List<SyncScope> _parseScopes(Object? value) {
    if (value is! List) {
      return const <SyncScope>[];
    }
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .map(_scopeFromName)
        .whereType<SyncScope>()
        .toList(growable: false);
  }

  static SyncScope? _scopeFromName(String name) {
    for (final scope in SyncScope.values) {
      if (scope.name == name) {
        return scope;
      }
    }
    return null;
  }

  static SyncDriverType _parseDriverType(Object? value) {
    final name = value?.toString().trim();
    return SyncDriverType.values.firstWhere(
      (item) => item.name == name,
      orElse: () => SyncDriverType.webdav,
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      throw FormatException('Missing required field: $key');
    }
    return value;
  }

  static String? _optionalString(Object? value) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  static bool? _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
    return null;
  }

  static DateTime? _optionalDateTime(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  static DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
    final parsed = _optionalDateTime(json[key]);
    if (parsed == null) {
      throw FormatException('Missing required field: $key');
    }
    return parsed;
  }
}
