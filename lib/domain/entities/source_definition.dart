enum SourceHealthStatus { unknown, healthy, degraded, unavailable }

enum SourceJsCapability { full, partial, unsupported }

class SourceRuleSet {
  const SourceRuleSet({
    this.searchRule,
    this.searchInitRule,
    this.searchListRule,
    this.searchTitleRule,
    this.searchDetailUrlRule,
    this.searchAuthorRule,
    this.searchIntroRule,
    this.searchCoverUrlRule,
    this.searchLatestChapterRule,
    this.detailRule,
    this.detailInitRule,
    this.detailTitleRule,
    this.detailAuthorRule,
    this.detailCanRenameRule,
    this.detailIntroRule,
    this.detailCoverUrlRule,
    this.detailTocUrlRule,
    this.tocRule,
    this.tocInitRule,
    this.tocListRule,
    this.tocTitleRule,
    this.tocChapterUrlRule,
    this.tocReversed = false,
    this.contentRule,
    this.contentInitRule,
    this.contentDecryptRule,
    this.contentReplaceRegex,
    this.tocNextUrlRule,
    this.contentNextUrlRule,
    this.exploreInitRule,
    this.exploreListRule,
    this.exploreTitleRule,
    this.exploreDetailUrlRule,
    this.exploreAuthorRule,
    this.exploreIntroRule,
    this.exploreCoverUrlRule,
    this.exploreLatestChapterRule,
    this.exploreKindRule,
    this.exploreWordCountRule,
  });

  final String? searchRule;
  final String? searchInitRule;
  final String? searchListRule;
  final String? searchTitleRule;
  final String? searchDetailUrlRule;
  final String? searchAuthorRule;
  final String? searchIntroRule;
  final String? searchCoverUrlRule;
  final String? searchLatestChapterRule;

  final String? detailRule;
  final String? detailInitRule;
  final String? detailTitleRule;
  final String? detailAuthorRule;
  final String? detailCanRenameRule;
  final String? detailIntroRule;
  final String? detailCoverUrlRule;
  final String? detailTocUrlRule;

  final String? tocRule;
  final String? tocInitRule;
  final String? tocListRule;
  final String? tocTitleRule;
  final String? tocChapterUrlRule;
  final bool tocReversed;

  final String? contentRule;
  final String? contentInitRule;
  final String? contentDecryptRule;
  final String? contentReplaceRegex;
  final String? tocNextUrlRule;
  final String? contentNextUrlRule;

  final String? exploreInitRule;
  final String? exploreListRule;
  final String? exploreTitleRule;
  final String? exploreDetailUrlRule;
  final String? exploreAuthorRule;
  final String? exploreIntroRule;
  final String? exploreCoverUrlRule;
  final String? exploreLatestChapterRule;
  final String? exploreKindRule;
  final String? exploreWordCountRule;

  SourceRuleSet copyWith({
    String? searchRule,
    String? searchInitRule,
    String? searchListRule,
    String? searchTitleRule,
    String? searchDetailUrlRule,
    String? searchAuthorRule,
    String? searchIntroRule,
    String? searchCoverUrlRule,
    String? searchLatestChapterRule,
    String? detailRule,
    String? detailInitRule,
    String? detailTitleRule,
    String? detailAuthorRule,
    String? detailCanRenameRule,
    String? detailIntroRule,
    String? detailCoverUrlRule,
    String? detailTocUrlRule,
    String? tocRule,
    String? tocInitRule,
    String? tocListRule,
    String? tocTitleRule,
    String? tocChapterUrlRule,
    bool? tocReversed,
    String? contentRule,
    String? contentInitRule,
    String? contentDecryptRule,
    String? contentReplaceRegex,
    String? tocNextUrlRule,
    String? contentNextUrlRule,
    String? exploreInitRule,
    String? exploreListRule,
    String? exploreTitleRule,
    String? exploreDetailUrlRule,
    String? exploreAuthorRule,
    String? exploreIntroRule,
    String? exploreCoverUrlRule,
    String? exploreLatestChapterRule,
    String? exploreKindRule,
    String? exploreWordCountRule,
  }) {
    return SourceRuleSet(
      searchRule: searchRule ?? this.searchRule,
      searchInitRule: searchInitRule ?? this.searchInitRule,
      searchListRule: searchListRule ?? this.searchListRule,
      searchTitleRule: searchTitleRule ?? this.searchTitleRule,
      searchDetailUrlRule: searchDetailUrlRule ?? this.searchDetailUrlRule,
      searchAuthorRule: searchAuthorRule ?? this.searchAuthorRule,
      searchIntroRule: searchIntroRule ?? this.searchIntroRule,
      searchCoverUrlRule: searchCoverUrlRule ?? this.searchCoverUrlRule,
      searchLatestChapterRule:
          searchLatestChapterRule ?? this.searchLatestChapterRule,
      detailRule: detailRule ?? this.detailRule,
      detailInitRule: detailInitRule ?? this.detailInitRule,
      detailTitleRule: detailTitleRule ?? this.detailTitleRule,
      detailAuthorRule: detailAuthorRule ?? this.detailAuthorRule,
      detailCanRenameRule: detailCanRenameRule ?? this.detailCanRenameRule,
      detailIntroRule: detailIntroRule ?? this.detailIntroRule,
      detailCoverUrlRule: detailCoverUrlRule ?? this.detailCoverUrlRule,
      detailTocUrlRule: detailTocUrlRule ?? this.detailTocUrlRule,
      tocRule: tocRule ?? this.tocRule,
      tocInitRule: tocInitRule ?? this.tocInitRule,
      tocListRule: tocListRule ?? this.tocListRule,
      tocTitleRule: tocTitleRule ?? this.tocTitleRule,
      tocChapterUrlRule: tocChapterUrlRule ?? this.tocChapterUrlRule,
      tocReversed: tocReversed ?? this.tocReversed,
      contentRule: contentRule ?? this.contentRule,
      contentInitRule: contentInitRule ?? this.contentInitRule,
      contentDecryptRule: contentDecryptRule ?? this.contentDecryptRule,
      contentReplaceRegex: contentReplaceRegex ?? this.contentReplaceRegex,
      tocNextUrlRule: tocNextUrlRule ?? this.tocNextUrlRule,
      contentNextUrlRule: contentNextUrlRule ?? this.contentNextUrlRule,
      exploreInitRule: exploreInitRule ?? this.exploreInitRule,
      exploreListRule: exploreListRule ?? this.exploreListRule,
      exploreTitleRule: exploreTitleRule ?? this.exploreTitleRule,
      exploreDetailUrlRule: exploreDetailUrlRule ?? this.exploreDetailUrlRule,
      exploreAuthorRule: exploreAuthorRule ?? this.exploreAuthorRule,
      exploreIntroRule: exploreIntroRule ?? this.exploreIntroRule,
      exploreCoverUrlRule: exploreCoverUrlRule ?? this.exploreCoverUrlRule,
      exploreLatestChapterRule:
          exploreLatestChapterRule ?? this.exploreLatestChapterRule,
      exploreKindRule: exploreKindRule ?? this.exploreKindRule,
      exploreWordCountRule: exploreWordCountRule ?? this.exploreWordCountRule,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'searchRule': searchRule,
      'searchInitRule': searchInitRule,
      'searchListRule': searchListRule,
      'searchTitleRule': searchTitleRule,
      'searchDetailUrlRule': searchDetailUrlRule,
      'searchAuthorRule': searchAuthorRule,
      'searchIntroRule': searchIntroRule,
      'searchCoverUrlRule': searchCoverUrlRule,
      'searchLatestChapterRule': searchLatestChapterRule,
      'detailRule': detailRule,
      'detailInitRule': detailInitRule,
      'detailTitleRule': detailTitleRule,
      'detailAuthorRule': detailAuthorRule,
      'detailCanRenameRule': detailCanRenameRule,
      'detailIntroRule': detailIntroRule,
      'detailCoverUrlRule': detailCoverUrlRule,
      'detailTocUrlRule': detailTocUrlRule,
      'tocRule': tocRule,
      'tocInitRule': tocInitRule,
      'tocListRule': tocListRule,
      'tocTitleRule': tocTitleRule,
      'tocChapterUrlRule': tocChapterUrlRule,
      'tocReversed': tocReversed,
      'contentRule': contentRule,
      'contentInitRule': contentInitRule,
      'contentDecryptRule': contentDecryptRule,
      'contentReplaceRegex': contentReplaceRegex,
      'tocNextUrlRule': tocNextUrlRule,
      'contentNextUrlRule': contentNextUrlRule,
      'exploreInitRule': exploreInitRule,
      'exploreListRule': exploreListRule,
      'exploreTitleRule': exploreTitleRule,
      'exploreDetailUrlRule': exploreDetailUrlRule,
      'exploreAuthorRule': exploreAuthorRule,
      'exploreIntroRule': exploreIntroRule,
      'exploreCoverUrlRule': exploreCoverUrlRule,
      'exploreLatestChapterRule': exploreLatestChapterRule,
      'exploreKindRule': exploreKindRule,
      'exploreWordCountRule': exploreWordCountRule,
    };
  }

  factory SourceRuleSet.fromJson(Map<String, dynamic> json) {
    return SourceRuleSet(
      searchRule: _asNullableString(json['searchRule']),
      searchInitRule: _asNullableString(json['searchInitRule']),
      searchListRule: _asNullableString(json['searchListRule']),
      searchTitleRule: _asNullableString(json['searchTitleRule']),
      searchDetailUrlRule: _asNullableString(json['searchDetailUrlRule']),
      searchAuthorRule: _asNullableString(json['searchAuthorRule']),
      searchIntroRule: _asNullableString(json['searchIntroRule']),
      searchCoverUrlRule: _asNullableString(json['searchCoverUrlRule']),
      searchLatestChapterRule: _asNullableString(
        json['searchLatestChapterRule'],
      ),
      detailRule: _asNullableString(json['detailRule']),
      detailInitRule: _asNullableString(json['detailInitRule']),
      detailTitleRule: _asNullableString(json['detailTitleRule']),
      detailAuthorRule: _asNullableString(json['detailAuthorRule']),
      detailCanRenameRule: _asNullableString(json['detailCanRenameRule']),
      detailIntroRule: _asNullableString(json['detailIntroRule']),
      detailCoverUrlRule: _asNullableString(json['detailCoverUrlRule']),
      detailTocUrlRule: _asNullableString(json['detailTocUrlRule']),
      tocRule: _asNullableString(json['tocRule']),
      tocInitRule: _asNullableString(json['tocInitRule']),
      tocListRule: _asNullableString(json['tocListRule']),
      tocTitleRule: _asNullableString(json['tocTitleRule']),
      tocChapterUrlRule: _asNullableString(json['tocChapterUrlRule']),
      tocReversed: _asBool(json['tocReversed']) ?? false,
      contentRule: _asNullableString(json['contentRule']),
      contentInitRule: _asNullableString(json['contentInitRule']),
      contentDecryptRule: _asNullableString(json['contentDecryptRule']),
      contentReplaceRegex: _asNullableString(json['contentReplaceRegex']),
      tocNextUrlRule: _asNullableString(json['tocNextUrlRule']),
      contentNextUrlRule: _asNullableString(json['contentNextUrlRule']),
      exploreInitRule: _asNullableString(json['exploreInitRule']),
      exploreListRule: _asNullableString(json['exploreListRule']),
      exploreTitleRule: _asNullableString(json['exploreTitleRule']),
      exploreDetailUrlRule: _asNullableString(json['exploreDetailUrlRule']),
      exploreAuthorRule: _asNullableString(json['exploreAuthorRule']),
      exploreIntroRule: _asNullableString(json['exploreIntroRule']),
      exploreCoverUrlRule: _asNullableString(json['exploreCoverUrlRule']),
      exploreLatestChapterRule: _asNullableString(
        json['exploreLatestChapterRule'],
      ),
      exploreKindRule: _asNullableString(json['exploreKindRule']),
      exploreWordCountRule: _asNullableString(json['exploreWordCountRule']),
    );
  }

  static String? _asNullableString(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }

  static bool? _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return null;
  }
}

class SourceDefinition {
  SourceDefinition({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.group,
    this.enabled = true,
    this.sourceType = 0,
    this.rules = const SourceRuleSet(),
    Map<String, String> headers = const {},
    this.lastCheckStatus = SourceHealthStatus.unknown,
    this.lastCheckedAt,
    this.lastCheckMessage,
    this.comment,
    this.exploreEnabled = false,
    this.exploreUrl,
    this.concurrentRate,
    this.jsLib,
    this.jsCapability = SourceJsCapability.full,
    Map<String, dynamic>? originalSource,
  }) : headers = Map.unmodifiable({...headers}),
       originalSource = _deepCopyMap(originalSource);

  final String id;
  final String name;
  final String baseUrl;
  final String? group;
  final bool enabled;
  final int sourceType;
  final SourceRuleSet rules;
  final Map<String, String> headers;
  final SourceHealthStatus lastCheckStatus;
  final DateTime? lastCheckedAt;
  final String? lastCheckMessage;
  final String? comment;
  final bool exploreEnabled;
  final String? exploreUrl;
  final String? concurrentRate;
  final String? jsLib;
  final SourceJsCapability jsCapability;
  final Map<String, dynamic>? originalSource;

  bool get isMangaSource => sourceType == 2;

  bool get supportsExplore {
    return exploreEnabled &&
        (exploreUrl?.trim().isNotEmpty ?? false) &&
        (rules.exploreListRule?.trim().isNotEmpty ?? false) &&
        (rules.exploreTitleRule?.trim().isNotEmpty ?? false) &&
        (rules.exploreDetailUrlRule?.trim().isNotEmpty ?? false);
  }

  bool get requiresServerTokenAuth {
    if (headers.isEmpty) {
      return false;
    }

    return headers.values.any((value) {
      final normalized = value.trim();
      return normalized.contains('{{sourceToken}}') ||
          normalized.contains('{{token}}');
    });
  }

  SourceDefinition copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? group,
    bool? enabled,
    int? sourceType,
    SourceRuleSet? rules,
    Map<String, String>? headers,
    SourceHealthStatus? lastCheckStatus,
    DateTime? lastCheckedAt,
    bool clearLastCheckedAt = false,
    String? lastCheckMessage,
    bool clearLastCheckMessage = false,
    String? comment,
    bool clearComment = false,
    bool? exploreEnabled,
    String? exploreUrl,
    bool clearExploreUrl = false,
    String? concurrentRate,
    bool clearConcurrentRate = false,
    String? jsLib,
    bool clearJsLib = false,
    SourceJsCapability? jsCapability,
    Map<String, dynamic>? originalSource,
    bool clearOriginalSource = false,
  }) {
    return SourceDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      group: group ?? this.group,
      enabled: enabled ?? this.enabled,
      sourceType: sourceType ?? this.sourceType,
      rules: rules ?? this.rules,
      headers: headers ?? this.headers,
      lastCheckStatus: lastCheckStatus ?? this.lastCheckStatus,
      lastCheckedAt:
          clearLastCheckedAt ? null : (lastCheckedAt ?? this.lastCheckedAt),
      lastCheckMessage:
          clearLastCheckMessage
              ? null
              : (lastCheckMessage ?? this.lastCheckMessage),
      comment: clearComment ? null : (comment ?? this.comment),
      exploreEnabled: exploreEnabled ?? this.exploreEnabled,
      exploreUrl: clearExploreUrl ? null : (exploreUrl ?? this.exploreUrl),
      concurrentRate:
          clearConcurrentRate ? null : (concurrentRate ?? this.concurrentRate),
      jsLib: clearJsLib ? null : (jsLib ?? this.jsLib),
      jsCapability: jsCapability ?? this.jsCapability,
      originalSource:
          clearOriginalSource ? null : (originalSource ?? this.originalSource),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      'group': group,
      'enabled': enabled,
      'sourceType': sourceType,
      'rules': rules.toJson(),
      'headers': headers,
      'lastCheckStatus': lastCheckStatus.name,
      'lastCheckedAt': lastCheckedAt?.toIso8601String(),
      'lastCheckMessage': lastCheckMessage,
      'comment': comment,
      'exploreEnabled': exploreEnabled,
      'exploreUrl': exploreUrl,
      'concurrentRate': concurrentRate,
      'jsLib': jsLib,
      'jsCapability': jsCapability.name,
      'originalSource': originalSource,
    };
  }

  factory SourceDefinition.fromJson(Map<String, dynamic> json) {
    final rulesJson = json['rules'];
    final headersJson = json['headers'];

    return SourceDefinition(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      baseUrl: _requiredString(json, 'baseUrl'),
      group: _nullableString(json['group']),
      enabled: _asBool(json['enabled']) ?? true,
      sourceType: _asInt(json['sourceType']) ?? 0,
      rules:
          rulesJson is Map<String, dynamic>
              ? SourceRuleSet.fromJson(rulesJson)
              : const SourceRuleSet(),
      headers:
          headersJson is Map
              ? headersJson.map(
                (key, value) => MapEntry(key.toString(), value.toString()),
              )
              : const {},
      lastCheckStatus: _parseStatus(json['lastCheckStatus']),
      lastCheckedAt: _parseDateTime(json['lastCheckedAt']),
      lastCheckMessage: _nullableString(json['lastCheckMessage']),
      comment: _nullableString(json['comment']),
      exploreEnabled: _asBool(json['exploreEnabled']) ?? false,
      exploreUrl: _nullableString(json['exploreUrl']),
      concurrentRate: _nullableString(json['concurrentRate']),
      jsLib: _nullableString(json['jsLib']),
      jsCapability: _parseJsCapability(json['jsCapability']),
      originalSource: _deepCopyMap(json['originalSource']),
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null || value.toString().trim().isEmpty) {
      throw FormatException('Missing required field: $key');
    }
    return value.toString();
  }

  static String? _nullableString(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }

  static bool? _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
    return null;
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static Map<String, dynamic>? _deepCopyMap(Object? value) {
    if (value is! Map) {
      return null;
    }

    return Map.unmodifiable({
      for (final entry in value.entries)
        entry.key.toString(): _deepCopyValue(entry.value),
    });
  }

  static dynamic _deepCopyValue(Object? value) {
    if (value is Map) {
      return Map.unmodifiable({
        for (final entry in value.entries)
          entry.key.toString(): _deepCopyValue(entry.value),
      });
    }
    if (value is List) {
      return List.unmodifiable(value.map(_deepCopyValue));
    }
    return value;
  }

  static SourceHealthStatus _parseStatus(Object? value) {
    if (value is String) {
      for (final item in SourceHealthStatus.values) {
        if (item.name == value) {
          return item;
        }
      }
    }
    return SourceHealthStatus.unknown;
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static SourceJsCapability _parseJsCapability(Object? value) {
    if (value is String) {
      for (final item in SourceJsCapability.values) {
        if (item.name == value) {
          return item;
        }
      }
    }
    return SourceJsCapability.full;
  }
}
