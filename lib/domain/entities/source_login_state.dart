class SourceLoginState {
  const SourceLoginState({
    required this.sourceId,
    required this.updatedAt,
    this.loginHeaderJson,
    this.loginInfoJson,
    this.sourceVariableJson,
  });

  final String sourceId;
  final String? loginHeaderJson;
  final String? loginInfoJson;
  final String? sourceVariableJson;
  final DateTime updatedAt;

  bool get isEmpty =>
      _normalize(loginHeaderJson) == null &&
      _normalize(loginInfoJson) == null &&
      _normalize(sourceVariableJson) == null;

  SourceLoginState copyWith({
    String? sourceId,
    String? loginHeaderJson,
    bool clearLoginHeaderJson = false,
    String? loginInfoJson,
    bool clearLoginInfoJson = false,
    String? sourceVariableJson,
    bool clearSourceVariableJson = false,
    DateTime? updatedAt,
  }) {
    return SourceLoginState(
      sourceId: sourceId ?? this.sourceId,
      loginHeaderJson:
          clearLoginHeaderJson
              ? null
              : (loginHeaderJson ?? this.loginHeaderJson),
      loginInfoJson:
          clearLoginInfoJson ? null : (loginInfoJson ?? this.loginInfoJson),
      sourceVariableJson:
          clearSourceVariableJson
              ? null
              : (sourceVariableJson ?? this.sourceVariableJson),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sourceId': sourceId,
      'loginHeaderJson': loginHeaderJson,
      'loginInfoJson': loginInfoJson,
      'sourceVariableJson': sourceVariableJson,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SourceLoginState.fromJson(Map<String, dynamic> json) {
    return SourceLoginState(
      sourceId: _requiredString(json, 'sourceId'),
      loginHeaderJson: _optionalString(json['loginHeaderJson']),
      loginInfoJson: _optionalString(json['loginInfoJson']),
      sourceVariableJson: _optionalString(json['sourceVariableJson']),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final normalized = _normalize(json[key]?.toString());
    if (normalized == null) {
      throw FormatException('Missing required field: $key');
    }
    return normalized;
  }

  static String? _optionalString(Object? value) {
    return _normalize(value?.toString());
  }

  static String? _normalize(String? value) {
    final normalized = (value ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }

  static DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
    final raw = json[key]?.toString().trim() ?? '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw FormatException('Missing required datetime field: $key');
    }
    return parsed;
  }
}
