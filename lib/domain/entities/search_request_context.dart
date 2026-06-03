import 'package:json_annotation/json_annotation.dart';

part 'search_request_context.g.dart';

@JsonSerializable()
class SearchRequestContext {
  SearchRequestContext({
    required String keyword,
    this.page = 1,
    this.pageSize = 20,
    this.sourceId,
    Map<String, String> extraParams = const {},
  }) : keyword = keyword.trim(),
       extraParams = Map.unmodifiable({...extraParams}) {
    if (this.keyword.isEmpty) {
      throw const FormatException('keyword must not be empty.');
    }
    if (page < 1) {
      throw const FormatException('page must be greater than or equal to 1.');
    }
    if (pageSize < 1) {
      throw const FormatException(
        'pageSize must be greater than or equal to 1.',
      );
    }
  }

  @JsonKey(fromJson: _requiredKeyword)
  final String keyword;
  @JsonKey(fromJson: _validatedPage)
  final int page;
  @JsonKey(fromJson: _validatedPageSize)
  final int pageSize;
  @JsonKey(fromJson: _asNullableString)
  final String? sourceId;
  @JsonKey(fromJson: _extraParamsFromJson)
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

  SearchRequestContext clearSourceId() {
    return copyWith(clearSourceId: true);
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

  static int _validatedPage(Object? value) {
    final page = _asInt(value) ?? 1;
    if (page < 1) {
      throw const FormatException('page must be greater than or equal to 1.');
    }
    return page;
  }

  static int _validatedPageSize(Object? value) {
    final pageSize = _asInt(value) ?? 20;
    if (pageSize < 1) {
      throw const FormatException(
        'pageSize must be greater than or equal to 1.',
      );
    }
    return pageSize;
  }

  Map<String, dynamic> toJson() {
    return _$SearchRequestContextToJson(this);
  }

  factory SearchRequestContext.fromJson(Map<String, dynamic> json) {
    return _$SearchRequestContextFromJson(json);
  }

  static Map<String, String> _extraParamsFromJson(Object? value) {
    if (value is! Map) {
      return const <String, String>{};
    }
    return value.map((key, val) => MapEntry(key.toString(), val.toString()));
  }
}
