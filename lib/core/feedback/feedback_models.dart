enum FeedbackType { issue, suggestion }

extension FeedbackTypeX on FeedbackType {
  String get apiValue => name;

  String get label => switch (this) {
    FeedbackType.issue => '问题',
    FeedbackType.suggestion => '建议',
  };
}

enum FeedbackStatus { pending, resolved, rejected }

extension FeedbackStatusX on FeedbackStatus {
  String get apiValue => name;

  String get label => switch (this) {
    FeedbackStatus.pending => '未处理',
    FeedbackStatus.resolved => '已解决',
    FeedbackStatus.rejected => '不予处理',
  };
}

class FeedbackListItem {
  const FeedbackListItem({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.status,
    required this.labels,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String type;
  final String title;
  final String content;
  final String status;
  final List<String> labels;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FeedbackListItem.fromJson(Map<String, dynamic> json) {
    return FeedbackListItem(
      id: _requiredString(json, 'id'),
      type: _requiredString(json, 'type'),
      title: _requiredString(json, 'title'),
      content: _requiredString(json, 'content'),
      status: _requiredString(json, 'status'),
      labels: _readStringList(json['labels']),
      createdAt: _requiredDateTime(json, 'created_at'),
      updatedAt: _requiredDateTime(json, 'updated_at'),
    );
  }

  String get typeLabel {
    return switch (type) {
      'suggestion' => FeedbackType.suggestion.label,
      _ => FeedbackType.issue.label,
    };
  }

  String get statusLabel {
    return switch (status) {
      'resolved' => FeedbackStatus.resolved.label,
      'rejected' => FeedbackStatus.rejected.label,
      _ => FeedbackStatus.pending.label,
    };
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      throw FormatException('Missing required field: $key');
    }
    return value;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
    final raw = json[key]?.toString().trim() ?? '';
    if (raw.isEmpty) {
      throw FormatException('Missing required DateTime field: $key');
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw FormatException('Invalid DateTime field: $key');
    }
    return parsed.toUtc();
  }
}

class FeedbackListPage {
  const FeedbackListPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<FeedbackListItem> items;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => items.length < total;

  factory FeedbackListPage.fromJson(Map<String, dynamic> json) {
    return FeedbackListPage(
      items: _readItems(json['items']),
      total: _readRequiredInt(json, 'total'),
      page: _readRequiredInt(json, 'page'),
      pageSize: _readRequiredInt(json, 'page_size'),
    );
  }

  static List<FeedbackListItem> _readItems(Object? value) {
    if (value is! List) {
      return const <FeedbackListItem>[];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => FeedbackListItem.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  static int _readRequiredInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) {
        return parsed;
      }
    }
    throw FormatException('Missing required int field: $key');
  }
}
