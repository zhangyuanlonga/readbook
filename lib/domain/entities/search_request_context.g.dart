// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_request_context.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SearchRequestContext _$SearchRequestContextFromJson(
  Map<String, dynamic> json,
) => SearchRequestContext(
  keyword: SearchRequestContext._requiredKeyword(json['keyword']),
  page:
      json['page'] == null
          ? 1
          : SearchRequestContext._validatedPage(json['page']),
  pageSize:
      json['pageSize'] == null
          ? 20
          : SearchRequestContext._validatedPageSize(json['pageSize']),
  sourceId: SearchRequestContext._asNullableString(json['sourceId']),
  extraParams:
      json['extraParams'] == null
          ? const {}
          : SearchRequestContext._extraParamsFromJson(json['extraParams']),
);

Map<String, dynamic> _$SearchRequestContextToJson(
  SearchRequestContext instance,
) => <String, dynamic>{
  'keyword': instance.keyword,
  'page': instance.page,
  'pageSize': instance.pageSize,
  'sourceId': instance.sourceId,
  'extraParams': instance.extraParams,
};
