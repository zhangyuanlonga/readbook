enum AnnouncementLevel { info, important, urgent }

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.level,
    required this.publishFrom,
    required this.publishTo,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final AnnouncementLevel level;
  final DateTime publishFrom;
  final DateTime? publishTo;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool isActiveAt(DateTime momentUtc) {
    if (!isActive) {
      return false;
    }
    if (momentUtc.isBefore(publishFrom)) {
      return false;
    }
    final end = publishTo;
    if (end != null && momentUtc.isAfter(end)) {
      return false;
    }
    return true;
  }

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      content: (json['content']?.toString() ?? '').trim(),
      level: _parseLevel(json['level']?.toString()),
      publishFrom: _requiredUtcTime(json, 'publish_from'),
      publishTo: _optionalUtcTime(json['publish_to']),
      isActive: _optionalBool(json['is_active']) ?? false,
      createdAt: _requiredUtcTime(json, 'created_at'),
      updatedAt: _requiredUtcTime(json, 'updated_at'),
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      throw FormatException('Missing required field: $key');
    }
    return value;
  }

  static AnnouncementLevel _parseLevel(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    return switch (normalized) {
      'important' => AnnouncementLevel.important,
      'urgent' => AnnouncementLevel.urgent,
      _ => AnnouncementLevel.info,
    };
  }

  static DateTime _requiredUtcTime(Map<String, dynamic> json, String key) {
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

  static DateTime? _optionalUtcTime(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    final parsed = DateTime.tryParse(raw);
    return parsed?.toUtc();
  }

  static bool? _optionalBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is int) {
      return value != 0;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == '1' || normalized == 'true') {
        return true;
      }
      if (normalized == '0' || normalized == 'false') {
        return false;
      }
    }
    return null;
  }
}

class AnnouncementPage {
  const AnnouncementPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<Announcement> items;
  final int page;
  final int pageSize;
  final int total;

  bool get hasMore => items.length < total;

  factory AnnouncementPage.fromJson(Map<String, dynamic> json) {
    final items = _parseItems(json['items']);
    return AnnouncementPage(
      items: items,
      page: _requiredInt(json, 'page'),
      pageSize: _requiredInt(json, 'page_size'),
      total: _requiredInt(json, 'total'),
    );
  }

  static List<Announcement> _parseItems(Object? value) {
    if (value is! List) {
      return const <Announcement>[];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => Announcement.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  static int _requiredInt(Map<String, dynamic> json, String key) {
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
