class SearchRequestContext {
  SearchRequestContext({
    required String keyword,
    this.page = 1,
    this.pageSize = 20,
    this.sourceId,
    Map<String, String> extraParams = const {},
  })  : keyword = keyword.trim(),
        extraParams = Map.unmodifiable({...extraParams}) {
    if (this.keyword.isEmpty) {
      throw const FormatException('keyword must not be empty.');
    }
    if (page < 1) {
      throw const FormatException('page must be greater than or equal to 1.');
    }
    if (pageSize < 1) {
      throw const FormatException('pageSize must be greater than or equal to 1.');
    }
  }

  final String keyword;
  final int page;
  final int pageSize;
  final String? sourceId;
  final Map<String, String> extraParams;

  SearchRequestContext copyWith({
    String? keyword,
    int? page,
    int? pageSize,
    String? sourceId,
    bool clearSourceId = false,
    Map<String, String>? extraParams,
  }) {
    return SearchRequestContext(
      keyword: keyword ?? this.keyword,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      sourceId: clearSourceId ? null : (sourceId ?? this.sourceId),
      extraParams: extraParams ?? this.extraParams,
    );
  }

  Map<String, String> toVariables() {
    final variables = <String, String>{
      'key': keyword,
      'keyword': keyword,
      'page': page.toString(),
      'pageSize': pageSize.toString(),
      ...extraParams,
    };

    if (sourceId != null && sourceId!.trim().isNotEmpty) {
      variables['sourceId'] = sourceId!.trim();
    }

    return variables;
  }

  Map<String, dynamic> toJson() {
    return {
      'keyword': keyword,
      'page': page,
      'pageSize': pageSize,
      'sourceId': sourceId,
      'extraParams': extraParams,
    };
  }

  factory SearchRequestContext.fromJson(Map<String, dynamic> json) {
    final rawExtra = json['extraParams'];
    final extra = <String, String>{};
    if (rawExtra is Map) {
      for (final entry in rawExtra.entries) {
        extra[entry.key.toString()] = entry.value.toString();
      }
    }

    return SearchRequestContext(
      keyword: _requiredKeyword(json['keyword']),
      page: _asInt(json['page']) ?? 1,
      pageSize: _asInt(json['pageSize']) ?? 20,
      sourceId: _asNullableString(json['sourceId']),
      extraParams: extra,
    );
  }

  static String _requiredKeyword(Object? value) {
    final keyword = value?.toString().trim() ?? '';
    if (keyword.isEmpty) {
      throw const FormatException('keyword is required.');
    }
    return keyword;
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

  static String? _asNullableString(Object? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.toString().trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
