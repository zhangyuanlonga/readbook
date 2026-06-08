class SourceAccessScope {
  const SourceAccessScope({
    required this.userId,
    required this.role,
    required this.membershipActive,
    required this.vipLevel,
    required this.features,
    required this.groupCodes,
    required this.sourceIds,
    required this.groupSourceIds,
    required this.sourceScopeSource,
  });

  final String userId;
  final String role;
  final bool membershipActive;
  final String vipLevel;
  final List<String> features;
  final List<String> groupCodes;
  final List<String> sourceIds;
  final Map<String, List<String>> groupSourceIds;
  final String sourceScopeSource;

  bool allowsSourceId(String sourceId) {
    return sourceIds.contains(sourceId.trim());
  }

  factory SourceAccessScope.fromJson(Map<String, dynamic> json) {
    final groups = json['groups'] as List? ?? const <Object?>[];
    return SourceAccessScope(
      userId: _stringOrEmpty(json['user_id']),
      role: _stringOrEmpty(json['role']),
      membershipActive: json['membership_active'] == true,
      vipLevel: _stringOrEmpty(json['vip_level']),
      features: _stringList(json['features']),
      groupCodes: groups
          .whereType<Map>()
          .map((item) => _stringOrEmpty(item['code']))
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      sourceIds: _stringList(json['source_ids']),
      groupSourceIds: _groupSourceIds(json['group_source_ids']),
      sourceScopeSource: _stringOrEmpty(json['source_scope_source']),
    );
  }
}

String _stringOrEmpty(Object? value) => value?.toString().trim() ?? '';

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map(_stringOrEmpty)
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

Map<String, List<String>> _groupSourceIds(Object? value) {
  if (value is! Map) {
    return const <String, List<String>>{};
  }
  return value.map(
    (key, item) => MapEntry(_stringOrEmpty(key), _stringList(item)),
  )..removeWhere((key, _) => key.isEmpty);
}
