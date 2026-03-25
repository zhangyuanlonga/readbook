class ScriptSource {
  const ScriptSource({
    required this.id,
    required this.name,
    required this.sourceCode,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    this.group,
    this.author,
    this.description,
  });

  final String id;
  final String name;
  final String sourceCode;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? group;
  final String? author;
  final String? description;

  ScriptSource copyWith({
    String? id,
    String? name,
    String? sourceCode,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? group,
    bool clearGroup = false,
    String? author,
    bool clearAuthor = false,
    String? description,
    bool clearDescription = false,
  }) {
    return ScriptSource(
      id: id ?? this.id,
      name: name ?? this.name,
      sourceCode: sourceCode ?? this.sourceCode,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      group: clearGroup ? null : (group ?? this.group),
      author: clearAuthor ? null : (author ?? this.author),
      description: clearDescription ? null : (description ?? this.description),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sourceCode': sourceCode,
      'enabled': enabled,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'group': group,
      'author': author,
      'description': description,
    };
  }

  factory ScriptSource.fromJson(Map<String, dynamic> json) {
    return ScriptSource(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      sourceCode: _requiredString(json, 'sourceCode'),
      enabled: _asBool(json['enabled']) ?? true,
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
      group: _optionalString(json['group']),
      author: _optionalString(json['author']),
      description: _optionalString(json['description']),
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
    if (value == null) {
      return null;
    }
    final normalized = value.toString().trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static bool? _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
    return null;
  }

  static DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) {
        return parsed;
      }
    }
    throw FormatException('Missing required date field: $key');
  }
}
