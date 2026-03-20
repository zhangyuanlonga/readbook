enum ReaderReplaceRuleScopeMode { all, bookTitle, sourceId, mixed }

class ReaderReplaceRule {
  const ReaderReplaceRule({
    this.id = 0,
    required this.name,
    required this.pattern,
    this.replacement = '',
    this.group,
    this.scopeMode = ReaderReplaceRuleScopeMode.all,
    this.scope,
    this.excludeScope,
    this.scopeTitle = false,
    this.scopeContent = true,
    this.isEnabled = true,
    this.isRegex = true,
    this.timeoutMs = 3000,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String pattern;
  final String replacement;
  final String? group;
  final ReaderReplaceRuleScopeMode scopeMode;
  final String? scope;
  final String? excludeScope;
  final bool scopeTitle;
  final bool scopeContent;
  final bool isEnabled;
  final bool isRegex;
  final int timeoutMs;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get appliesToContent => scopeContent;
  bool get appliesToTitle => scopeTitle;

  bool get isValid {
    return pattern.trim().isNotEmpty;
  }

  int get safeTimeoutMs => timeoutMs <= 0 ? 3000 : timeoutMs;

  ReaderReplaceRule copyWith({
    int? id,
    String? name,
    String? pattern,
    String? replacement,
    String? group,
    bool clearGroup = false,
    ReaderReplaceRuleScopeMode? scopeMode,
    String? scope,
    bool clearScope = false,
    String? excludeScope,
    bool clearExcludeScope = false,
    bool? scopeTitle,
    bool? scopeContent,
    bool? isEnabled,
    bool? isRegex,
    int? timeoutMs,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReaderReplaceRule(
      id: id ?? this.id,
      name: name ?? this.name,
      pattern: pattern ?? this.pattern,
      replacement: replacement ?? this.replacement,
      group: clearGroup ? null : group ?? this.group,
      scopeMode: scopeMode ?? this.scopeMode,
      scope: clearScope ? null : scope ?? this.scope,
      excludeScope:
          clearExcludeScope ? null : excludeScope ?? this.excludeScope,
      scopeTitle: scopeTitle ?? this.scopeTitle,
      scopeContent: scopeContent ?? this.scopeContent,
      isEnabled: isEnabled ?? this.isEnabled,
      isRegex: isRegex ?? this.isRegex,
      timeoutMs: timeoutMs ?? this.timeoutMs,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool matchesForContent({
    required String bookTitle,
    required String sourceId,
  }) {
    if (!isEnabled || !scopeContent) {
      return false;
    }
    return _matchesScope(bookTitle: bookTitle, sourceId: sourceId);
  }

  bool matchesForTitle({
    required String bookTitle,
    required String sourceId,
  }) {
    if (!isEnabled || !scopeTitle) {
      return false;
    }
    return _matchesScope(bookTitle: bookTitle, sourceId: sourceId);
  }

  bool _matchesScope({
    required String bookTitle,
    required String sourceId,
  }) {
    final normalizedBookTitle = _normalize(bookTitle);
    final normalizedSourceId = _normalize(sourceId);
    if (_matchesAnyToken(
      excludeScope,
      mode: scopeMode,
      bookTitle: normalizedBookTitle,
      sourceId: normalizedSourceId,
    )) {
      return false;
    }

    if (scopeMode == ReaderReplaceRuleScopeMode.all) {
      return true;
    }

    return _matchesAnyToken(
      scope,
      mode: scopeMode,
      bookTitle: normalizedBookTitle,
      sourceId: normalizedSourceId,
    );
  }

  bool _matchesAnyToken(
    String? raw, {
    required ReaderReplaceRuleScopeMode mode,
    required String bookTitle,
    required String sourceId,
  }) {
    final tokens = _splitScopeTokens(raw);
    if (tokens.isEmpty) {
      return false;
    }

    for (final token in tokens) {
      switch (mode) {
        case ReaderReplaceRuleScopeMode.all:
          return true;
        case ReaderReplaceRuleScopeMode.bookTitle:
          if (bookTitle.contains(token)) {
            return true;
          }
          break;
        case ReaderReplaceRuleScopeMode.sourceId:
          if (sourceId == token || sourceId.contains(token)) {
            return true;
          }
          break;
        case ReaderReplaceRuleScopeMode.mixed:
          if (bookTitle.contains(token) ||
              sourceId == token ||
              sourceId.contains(token)) {
            return true;
          }
          break;
      }
    }
    return false;
  }

  List<String> _splitScopeTokens(String? raw) {
    final normalized = _normalize(raw);
    if (normalized.isEmpty) {
      return const <String>[];
    }

    return normalized
        .split(RegExp(r'[\n,;|，；]+'))
        .map(_normalize)
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static String _normalize(String? value) {
    return (value ?? '').trim().toLowerCase();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'pattern': pattern,
      'replacement': replacement,
      'group': group,
      'scopeMode': scopeMode.name,
      'scope': scope,
      'excludeScope': excludeScope,
      'scopeTitle': scopeTitle,
      'scopeContent': scopeContent,
      'isEnabled': isEnabled,
      'isRegex': isRegex,
      'timeoutMs': timeoutMs,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ReaderReplaceRule.fromJson(Map<String, dynamic> json) {
    final scopeModeName = json['scopeMode']?.toString();
    final scopeMode = ReaderReplaceRuleScopeMode.values.firstWhere(
      (item) => item.name == scopeModeName,
      orElse: () => ReaderReplaceRuleScopeMode.all,
    );

    DateTime parseDate(dynamic value) {
      if (value is DateTime) {
        return value;
      }
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    int parseInt(dynamic value, int fallback) {
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        return int.tryParse(value.trim()) ?? fallback;
      }
      return fallback;
    }

    bool parseBool(dynamic value, bool fallback) {
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
      return fallback;
    }

    return ReaderReplaceRule(
      id: parseInt(json['id'], 0),
      name: (json['name'] ?? '').toString(),
      pattern: (json['pattern'] ?? '').toString(),
      replacement: (json['replacement'] ?? '').toString(),
      group: json['group']?.toString(),
      scopeMode: scopeMode,
      scope: json['scope']?.toString(),
      excludeScope: json['excludeScope']?.toString(),
      scopeTitle: parseBool(json['scopeTitle'], false),
      scopeContent: parseBool(json['scopeContent'], true),
      isEnabled: parseBool(json['isEnabled'], true),
      isRegex: parseBool(json['isRegex'], true),
      timeoutMs: parseInt(json['timeoutMs'], 3000),
      sortOrder: parseInt(json['sortOrder'], 0),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }
}
