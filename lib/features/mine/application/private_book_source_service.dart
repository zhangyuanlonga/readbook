import 'dart:convert';

import '../../../core/errors/error_stage.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';

class PrivateBookSourceService {
  PrivateBookSourceService({ApiClient? client, String? baseUrl})
    : _client =
          client ??
          ApiClient(baseUrl: (baseUrl ?? AppApiConfig.baseUrl).trim());

  final ApiClient _client;

  Future<PrivateBookSourceListResult> list({String? groupName}) {
    return _client.request<PrivateBookSourceListResult>(
      method: ApiMethod.get,
      path: '/v1/me/book-sources',
      queryParameters: <String, dynamic>{
        if (groupName != null) 'group_name': groupName,
      },
      attachAccessToken: true,
      enableRetry: false,
      stage: ErrorStage.source,
      decoder: (data) => PrivateBookSourceListResult.fromJson(_asMap(data)),
    );
  }

  Future<List<PrivateBookSourceGroupSummary>> groups() {
    return _client.request<List<PrivateBookSourceGroupSummary>>(
      method: ApiMethod.get,
      path: '/v1/me/book-source-groups',
      attachAccessToken: true,
      enableRetry: false,
      stage: ErrorStage.source,
      decoder: (data) {
        final items = _asMap(data)['items'] as List? ?? const [];
        return items
            .whereType<Map>()
            .map(
              (item) => PrivateBookSourceGroupSummary.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ),
            )
            .toList(growable: false);
      },
    );
  }

  Future<SourceQuotaSnapshot> quota() {
    return _client.request<SourceQuotaSnapshot>(
      method: ApiMethod.get,
      path: '/v1/me/source-quota',
      attachAccessToken: true,
      enableRetry: false,
      stage: ErrorStage.source,
      decoder: (data) => SourceQuotaSnapshot.fromJson(_asMap(data)),
    );
  }

  Future<PrivateBookSourceItem> create(PrivateBookSourceInput input) {
    return _client.request<PrivateBookSourceItem>(
      method: ApiMethod.post,
      path: '/v1/me/book-sources',
      body: input.toJson(),
      attachAccessToken: true,
      enableRetry: false,
      stage: ErrorStage.source,
      decoder: (data) => _itemFromMutationPayload(data),
    );
  }

  Future<PrivateBookSourceItem> update(
    String id,
    PrivateBookSourceInput input,
  ) {
    return _client.request<PrivateBookSourceItem>(
      method: ApiMethod.patch,
      path: '/v1/me/book-sources/$id',
      body: input.toJson(),
      attachAccessToken: true,
      enableRetry: false,
      stage: ErrorStage.source,
      decoder: (data) => _itemFromMutationPayload(data),
    );
  }

  Future<void> delete(String id) {
    return _client.request<void>(
      method: ApiMethod.delete,
      path: '/v1/me/book-sources/$id',
      attachAccessToken: true,
      enableRetry: false,
      stage: ErrorStage.source,
      decoder: (_) {},
    );
  }

  Future<PrivateBookSourceItem> setEnabled(String id, bool enabled) {
    return _client.request<PrivateBookSourceItem>(
      method: ApiMethod.patch,
      path: '/v1/me/book-sources/$id/enabled',
      body: <String, dynamic>{'enabled': enabled},
      attachAccessToken: true,
      enableRetry: false,
      stage: ErrorStage.source,
      decoder: (data) => _itemFromMutationPayload(data),
    );
  }

  Future<PrivateBookSourceItem> test(String id) {
    return _client.request<PrivateBookSourceItem>(
      method: ApiMethod.post,
      path: '/v1/me/book-sources/$id/test',
      attachAccessToken: true,
      enableRetry: false,
      stage: ErrorStage.source,
      decoder: (data) => _itemFromMutationPayload(data),
    );
  }

  Future<PrivateBookSourceItem> submit(String id, String note) {
    return _client.request<PrivateBookSourceItem>(
      method: ApiMethod.post,
      path: '/v1/me/book-sources/$id/submit',
      body: <String, dynamic>{'note': note},
      attachAccessToken: true,
      enableRetry: false,
      stage: ErrorStage.source,
      decoder: (data) => _itemFromMutationPayload(data),
    );
  }

  Map<String, dynamic> _asMap(Object? data) {
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    throw const FormatException('Invalid private source payload.');
  }

  PrivateBookSourceItem _itemFromMutationPayload(Object? data) {
    final map = _asMap(data);
    final item = map['item'];
    if (item is Map) {
      return PrivateBookSourceItem.fromJson(
        item.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return PrivateBookSourceItem.fromJson(map);
  }
}

class PrivateBookSourceListResult {
  const PrivateBookSourceListResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<PrivateBookSourceItem> items;
  final int total;
  final int page;
  final int pageSize;

  factory PrivateBookSourceListResult.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List? ?? const [];
    return PrivateBookSourceListResult(
      items: items
          .whereType<Map>()
          .map(
            (item) => PrivateBookSourceItem.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 20,
    );
  }
}

class PrivateBookSourceItem {
  const PrivateBookSourceItem({
    required this.id,
    required this.name,
    required this.supportedTypes,
    required this.sourceCode,
    required this.sourceJson,
    required this.description,
    required this.groupName,
    required this.visibility,
    required this.enabled,
    required this.reviewStatus,
    required this.reviewNote,
    required this.lastTestStatus,
    required this.lastTestMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<String> supportedTypes;
  final String sourceCode;
  final String sourceJson;
  final String description;
  final String groupName;
  final String visibility;
  final bool enabled;
  final String reviewStatus;
  final String reviewNote;
  final String lastTestStatus;
  final String lastTestMessage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PrivateBookSourceItem.fromJson(Map<String, dynamic> json) {
    return PrivateBookSourceItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? '',
      supportedTypes: (json['supported_types'] as List? ?? const ['novel'])
          .map((item) => item.toString())
          .toList(growable: false),
      sourceCode: json['source_code']?.toString() ?? '',
      sourceJson: json['source_json']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      groupName: json['group_name']?.toString() ?? '',
      visibility: json['visibility']?.toString() ?? 'private',
      enabled: json['enabled'] as bool? ?? true,
      reviewStatus: json['review_status']?.toString() ?? 'pending',
      reviewNote: json['review_note']?.toString() ?? '',
      lastTestStatus: json['last_test_status']?.toString() ?? '',
      lastTestMessage: json['last_test_message']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }
}

class PrivateBookSourceInput {
  const PrivateBookSourceInput({
    required this.name,
    required this.supportedTypes,
    required this.sourceCode,
    required this.description,
    required this.groupName,
  });

  final String name;
  final List<String> supportedTypes;
  final String sourceCode;
  final String description;
  final String groupName;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'supported_types': supportedTypes,
      'source_code': sourceCode,
      'source_json': sourceCode,
      'description': description,
      'group_name': groupName,
    };
  }

  static bool isValidJson(String value) {
    try {
      jsonDecode(value);
      return true;
    } catch (_) {
      return false;
    }
  }

  static String defaultGroupNameFromJson(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) {
        return '';
      }
      return _firstGroupValue(decoded['bookSourceGroup']) ??
          _firstGroupValue(decoded['book_source_group']) ??
          '';
    } catch (_) {
      return '';
    }
  }

  static String? _firstGroupValue(Object? value) {
    if (value is String) {
      return _firstGroupSegment(value);
    }
    if (value is List) {
      for (final item in value) {
        final group = _firstGroupValue(item);
        if (group != null && group.isNotEmpty) {
          return group;
        }
      }
    }
    return null;
  }

  static String _firstGroupSegment(String value) {
    final parts = value.split(RegExp(r'[,，;；|/\n\t]'));
    for (final part in parts) {
      final normalized = part.trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return value.trim();
  }
}

class PrivateBookSourceGroupSummary {
  const PrivateBookSourceGroupSummary({
    required this.name,
    required this.displayName,
    required this.sourceCount,
  });

  final String name;
  final String displayName;
  final int sourceCount;

  factory PrivateBookSourceGroupSummary.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? '';
    return PrivateBookSourceGroupSummary(
      name: name,
      displayName:
          json['display_name']?.toString() ?? (name.isEmpty ? '未分组' : name),
      sourceCount: (json['source_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class SourceQuotaSnapshot {
  const SourceQuotaSnapshot({
    required this.maxPrivateSources,
    required this.privateSourceCount,
    required this.dailyImportLimit,
    required this.dailyImportUsed,
    required this.dailyTestLimit,
    required this.dailyTestUsed,
    required this.dailySubmitLimit,
    required this.dailySubmitUsed,
    required this.maxSourceJsonBytes,
    required this.allowSubmitShared,
    required this.policyName,
  });

  final int maxPrivateSources;
  final int privateSourceCount;
  final int dailyImportLimit;
  final int dailyImportUsed;
  final int dailyTestLimit;
  final int dailyTestUsed;
  final int dailySubmitLimit;
  final int dailySubmitUsed;
  final int maxSourceJsonBytes;
  final bool allowSubmitShared;
  final String policyName;

  int get privateSourceRemaining =>
      _remaining(maxPrivateSources, privateSourceCount);
  int get dailyImportRemaining => _remaining(dailyImportLimit, dailyImportUsed);
  int get dailyTestRemaining => _remaining(dailyTestLimit, dailyTestUsed);
  int get dailySubmitRemaining => _remaining(dailySubmitLimit, dailySubmitUsed);

  factory SourceQuotaSnapshot.fromJson(Map<String, dynamic> json) {
    return SourceQuotaSnapshot(
      maxPrivateSources: _intAt(json, 'max_private_sources'),
      privateSourceCount: _intAt(json, 'private_source_count'),
      dailyImportLimit: _intAt(json, 'daily_import_limit'),
      dailyImportUsed: _intAt(json, 'daily_import_used'),
      dailyTestLimit: _intAt(json, 'daily_test_limit'),
      dailyTestUsed: _intAt(json, 'daily_test_used'),
      dailySubmitLimit: _intAt(json, 'daily_submit_limit'),
      dailySubmitUsed: _intAt(json, 'daily_submit_used'),
      maxSourceJsonBytes: _intAt(json, 'max_source_json_bytes'),
      allowSubmitShared: json['allow_submit_shared'] as bool? ?? false,
      policyName:
          json['policy_name']?.toString() ??
          json['matched_policy_name']?.toString() ??
          '',
    );
  }

  static int _intAt(Map<String, dynamic> json, String key) {
    return (json[key] as num?)?.toInt() ?? 0;
  }

  static int _remaining(int limit, int used) {
    if (limit < 0) {
      return -1;
    }
    final value = limit - used;
    return value < 0 ? 0 : value;
  }
}
