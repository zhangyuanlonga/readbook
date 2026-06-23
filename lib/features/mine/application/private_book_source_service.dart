import 'dart:convert';

import '../../../core/errors/error_stage.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../domain/entities/source_login_capability.dart';

class PrivateBookSourceService {
  PrivateBookSourceService({
    ApiClient? client,
    ApiClient? quotaClient,
    String? baseUrl,
  }) : _baseUrl = AppApiConfig.normalizeBaseUrl(
         baseUrl ?? AppApiConfig.effectiveReaderGatewayBaseUrl,
       ),
       _client =
           client ??
           ApiClient(
             baseUrl: AppApiConfig.normalizeBaseUrl(
               baseUrl ?? AppApiConfig.effectiveReaderGatewayBaseUrl,
             ),
           ),
       _quotaClient =
           quotaClient ?? ApiClient(baseUrl: AppApiConfig.baseUrl.trim());

  final String _baseUrl;
  final ApiClient _client;
  final ApiClient _quotaClient;

  Future<PrivateBookSourceListResult> list({String? groupId}) {
    return _client.request<PrivateBookSourceListResult>(
      method: ApiMethod.get,
      path: _gatewayPath('v1/me/book-sources'),
      queryParameters: <String, dynamic>{
        if (groupId != null) 'group_id': groupId,
      },
      attachAccessToken: true,
      enableRetry: false,
      stage: ErrorStage.source,
      decoder: (data) => PrivateBookSourceListResult.fromJson(_asMap(data)),
    );
  }

  Future<PrivateBookSourceItem> get(String id) {
    return _client.request<PrivateBookSourceItem>(
      method: ApiMethod.get,
      path: _gatewayPath('v1/me/book-sources/$id'),
      attachAccessToken: true,
      enableRetry: false,
      stage: ErrorStage.source,
      decoder: (data) => _itemFromMutationPayload(data),
    );
  }

  Future<List<PrivateBookSourceGroup>> groups() {
    return _client.request<List<PrivateBookSourceGroup>>(
      method: ApiMethod.get,
      path: _gatewayPath('v1/me/book-source-groups'),
      attachAccessToken: true,
      enableRetry: false,
      stage: ErrorStage.source,
      decoder: (data) {
        final items = _asMap(data)['items'] as List? ?? const [];
        return items
            .whereType<Map>()
            .map(
              (item) => PrivateBookSourceGroup.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ),
            )
            .toList(growable: false);
      },
    );
  }

  Future<PrivateBookSourceGroup> createGroup(String name) {
    return _client.request<PrivateBookSourceGroup>(
      method: ApiMethod.post,
      path: _gatewayPath('v1/me/book-source-groups'),
      body: <String, dynamic>{'name': name.trim()},
      attachAccessToken: true,
      enableRetry: false,
      stage: ErrorStage.source,
      decoder: (data) => _groupFromMutationPayload(data),
    );
  }

  Future<PrivateBookSourceGroup> updateGroup(String id, String name) {
    return _client.request<PrivateBookSourceGroup>(
      method: ApiMethod.patch,
      path: _gatewayPath('v1/me/book-source-groups/$id'),
      body: <String, dynamic>{'name': name.trim()},
      attachAccessToken: true,
      enableRetry: false,
      stage: ErrorStage.source,
      decoder: (data) => _groupFromMutationPayload(data),
    );
  }

  Future<void> deleteGroup(String id) {
    return _requestVoid(
      method: ApiMethod.delete,
      path: _gatewayPath('v1/me/book-source-groups/$id'),
    );
  }

  Future<SourceQuotaSnapshot> quota() {
    return _quotaClient.request<SourceQuotaSnapshot>(
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
      path: _gatewayPath('v1/me/book-sources'),
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
      path: _gatewayPath('v1/me/book-sources/$id'),
      body: input.toJson(),
      attachAccessToken: true,
      enableRetry: false,
      stage: ErrorStage.source,
      decoder: (data) => _itemFromMutationPayload(data),
    );
  }

  Future<void> delete(String id) {
    return _requestVoid(
      method: ApiMethod.delete,
      path: _gatewayPath('v1/me/book-sources/$id'),
    );
  }

  Future<PrivateBookSourceItem> setEnabled(String id, bool enabled) {
    return _client.request<PrivateBookSourceItem>(
      method: ApiMethod.patch,
      path: _gatewayPath('v1/me/book-sources/$id/enabled'),
      body: <String, dynamic>{'enabled': enabled},
      attachAccessToken: true,
      enableRetry: false,
      stage: ErrorStage.source,
      decoder: (data) => _itemFromMutationPayload(data),
    );
  }

  Future<PrivateBookSourceTestResult> test(
    String id, {
    String keyword = '',
    int? timeoutMs,
    List<String> checkItems = const <String>[],
  }) {
    final requestTimeout = Duration(
      milliseconds: (timeoutMs ?? 30000).clamp(1000, 180000) + 30000,
    );
    return _client.request<PrivateBookSourceTestResult>(
      method: ApiMethod.post,
      path: _gatewayPath('v1/me/book-sources/$id/test'),
      body: <String, dynamic>{
        if (keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
        if (timeoutMs != null) 'timeoutMs': timeoutMs,
        if (checkItems.isNotEmpty) 'checkItems': checkItems,
      },
      timeout: requestTimeout,
      attachAccessToken: true,
      enableRetry: false,
      stage: ErrorStage.source,
      decoder: (data) => PrivateBookSourceTestResult.fromJson(_asMap(data)),
    );
  }

  Future<void> submit(String id, String note) {
    return _client.request<void>(
      method: ApiMethod.post,
      path: _gatewayPath('v1/me/book-sources/$id/submit'),
      body: <String, dynamic>{'note': note},
      attachAccessToken: true,
      enableRetry: false,
      stage: ErrorStage.source,
      decoder: (_) {},
    );
  }

  Future<void> _requestVoid({required ApiMethod method, required String path}) {
    return _client.request<void>(
      method: method,
      path: path,
      attachAccessToken: true,
      enableRetry: false,
      stage: ErrorStage.source,
      decoder: (_) {},
    );
  }

  String _gatewayPath(String path) {
    return AppApiConfig.readerGatewayApiPath(_baseUrl, path);
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

  PrivateBookSourceGroup _groupFromMutationPayload(Object? data) {
    final map = _asMap(data);
    final item = map['item'];
    if (item is Map) {
      return PrivateBookSourceGroup.fromJson(
        item.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return PrivateBookSourceGroup.fromJson(map);
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

class PrivateBookSourceTestResult {
  const PrivateBookSourceTestResult({
    required this.item,
    required this.quota,
    required this.report,
    required this.raw,
  });

  final PrivateBookSourceItem item;
  final SourceQuotaSnapshot? quota;
  final SourceCheckReport? report;
  final Map<String, dynamic> raw;

  factory PrivateBookSourceTestResult.fromJson(Map<String, dynamic> json) {
    final item = json['item'];
    final quota = json['quota'];
    final report = json['report'];
    return PrivateBookSourceTestResult(
      item:
          item is Map
              ? PrivateBookSourceItem.fromJson(
                item.map((key, value) => MapEntry(key.toString(), value)),
              )
              : PrivateBookSourceItem.fromJson(json),
      quota:
          quota is Map
              ? SourceQuotaSnapshot.fromJson(
                quota.map((key, value) => MapEntry(key.toString(), value)),
              )
              : null,
      report:
          report is Map
              ? SourceCheckReport.fromJson(
                report.map((key, value) => MapEntry(key.toString(), value)),
              )
              : null,
      raw: json,
    );
  }
}

class SourceCheckReport {
  const SourceCheckReport({
    required this.summary,
    required this.logs,
    required this.copyText,
  });

  final SourceCheckSummary summary;
  final List<SourceCheckLogEntry> logs;
  final String copyText;

  factory SourceCheckReport.fromJson(Map<String, dynamic> json) {
    final logs = json['logs'] as List? ?? const [];
    final summary = json['summary'];
    return SourceCheckReport(
      summary:
          summary is Map
              ? SourceCheckSummary.fromJson(
                summary.map((key, value) => MapEntry(key.toString(), value)),
              )
              : const SourceCheckSummary.empty(),
      logs: logs
          .whereType<Map>()
          .map(
            (item) => SourceCheckLogEntry.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false),
      copyText: json['copyText']?.toString() ?? '',
    );
  }
}

class SourceCheckSummary {
  const SourceCheckSummary({
    required this.sourceName,
    required this.mode,
    required this.valid,
    required this.keyword,
    required this.elapsedMs,
    required this.failureStage,
    required this.message,
  });

  const SourceCheckSummary.empty()
    : sourceName = '',
      mode = '',
      valid = false,
      keyword = '',
      elapsedMs = 0,
      failureStage = '',
      message = '';

  final String sourceName;
  final String mode;
  final bool valid;
  final String keyword;
  final int elapsedMs;
  final String failureStage;
  final String message;

  factory SourceCheckSummary.fromJson(Map<String, dynamic> json) {
    return SourceCheckSummary(
      sourceName: json['sourceName']?.toString() ?? '',
      mode: json['mode']?.toString() ?? '',
      valid: json['valid'] == true,
      keyword: json['keyword']?.toString() ?? '',
      elapsedMs: (json['elapsedMs'] as num?)?.toInt() ?? 0,
      failureStage: json['failureStage']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }
}

class SourceCheckLogEntry {
  const SourceCheckLogEntry({
    required this.timeMs,
    required this.direction,
    required this.stage,
    required this.level,
    required this.message,
    required this.details,
  });

  final int timeMs;
  final String direction;
  final String stage;
  final String level;
  final String message;
  final List<String> details;

  factory SourceCheckLogEntry.fromJson(Map<String, dynamic> json) {
    return SourceCheckLogEntry(
      timeMs: (json['timeMs'] as num?)?.toInt() ?? 0,
      direction: json['direction']?.toString() ?? 'out',
      stage: json['stage']?.toString() ?? '',
      level: json['level']?.toString() ?? 'info',
      message: json['message']?.toString() ?? '',
      details: (json['details'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
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
    required this.compatibilityReport,
    required this.normalizationStatus,
    required this.normalizationError,
    required this.reviewStatus,
    required this.reviewNote,
    required this.lastTestStatus,
    required this.lastTestMessage,
    required this.loginCapability,
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
  final String compatibilityReport;
  final String normalizationStatus;
  final String normalizationError;
  final String reviewStatus;
  final String reviewNote;
  final String lastTestStatus;
  final String lastTestMessage;
  final SourceLoginCapability loginCapability;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PrivateBookSourceItem.fromJson(Map<String, dynamic> json) {
    final sourceJson = json['source_json']?.toString() ?? '';
    return PrivateBookSourceItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? '',
      supportedTypes: (json['supported_types'] as List? ?? const ['novel'])
          .map((item) => item.toString())
          .toList(growable: false),
      sourceCode: json['source_code']?.toString() ?? '',
      sourceJson: sourceJson,
      description: json['description']?.toString() ?? '',
      groupName: json['group_name']?.toString() ?? '',
      visibility: json['visibility']?.toString() ?? 'private',
      enabled: json['enabled'] as bool? ?? true,
      compatibilityReport: json['compatibility_report']?.toString() ?? '',
      normalizationStatus: json['normalization_status']?.toString() ?? '',
      normalizationError: json['normalization_error']?.toString() ?? '',
      reviewStatus: json['review_status']?.toString() ?? 'pending',
      reviewNote: json['review_note']?.toString() ?? '',
      lastTestStatus: json['last_test_status']?.toString() ?? '',
      lastTestMessage: json['last_test_message']?.toString() ?? '',
      loginCapability: SourceLoginCapability.fromMap(
        json.map((key, value) => MapEntry(key, value as Object?)),
      ).merge(SourceLoginCapability.fromSourceJson(sourceJson)),
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

class PrivateBookSourceGroup {
  const PrivateBookSourceGroup({
    required this.id,
    required this.code,
    required this.name,
    required this.scopeType,
    required this.ownerUserId,
    required this.enabled,
  });

  final String id;
  final String code;
  final String name;
  final String scopeType;
  final String ownerUserId;
  final bool enabled;

  String get displayName => name.trim().isEmpty ? '未分组' : name.trim();

  factory PrivateBookSourceGroup.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? '';
    return PrivateBookSourceGroup(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: name,
      scopeType: json['scope_type']?.toString() ?? 'private',
      ownerUserId: json['owner_user_id']?.toString() ?? '',
      enabled: json['enabled'] != false,
    );
  }
}

class SourceQuotaSnapshot {
  const SourceQuotaSnapshot({
    required this.maxPrivateSources,
    required this.privateSourceCount,
    required this.dailyTestLimit,
    required this.dailyTestUsed,
  });

  final int maxPrivateSources;
  final int privateSourceCount;
  final int dailyTestLimit;
  final int dailyTestUsed;

  int get privateSourceRemaining =>
      _remaining(maxPrivateSources, privateSourceCount);
  int get dailyTestRemaining => _remaining(dailyTestLimit, dailyTestUsed);

  factory SourceQuotaSnapshot.fromJson(Map<String, dynamic> json) {
    return SourceQuotaSnapshot(
      maxPrivateSources: _intAt(json, 'max_private_sources'),
      privateSourceCount: _intAt(json, 'private_source_count'),
      dailyTestLimit: _intAt(json, 'daily_test_limit'),
      dailyTestUsed: _intAt(json, 'daily_test_used'),
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
