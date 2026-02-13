import 'dart:convert';

class LegadoSourceRaw {
  LegadoSourceRaw._(Map<String, dynamic> rawData)
      : rawData = _copyMap(rawData);

  final Map<String, dynamic> rawData;

  factory LegadoSourceRaw.fromJson(Map<String, dynamic> json) {
    return LegadoSourceRaw._(json);
  }

  factory LegadoSourceRaw.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Legado source JSON must be an object.');
    }
    return LegadoSourceRaw.fromJson(decoded);
  }

  String? get sourceName => _readString('bookSourceName');
  String? get sourceUrl => _readString('bookSourceUrl');
  String? get sourceGroup => _readString('bookSourceGroup');
  String? get sourceComment => _readString('bookSourceComment');
  String? get searchUrl => _readString('searchUrl');

  bool get enabled => _readBool('enabled') ?? true;

  Map<String, dynamic> toJson() => _copyMap(rawData);

  String? _readString(String key) {
    final value = rawData[key];
    if (value == null) {
      return null;
    }
    return value.toString().trim();
  }

  bool? _readBool(String key) {
    final value = rawData[key];
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

  static Map<String, dynamic> _copyMap(Map<String, dynamic> map) {
    return map.map((key, value) => MapEntry(key, _copyValue(value)));
  }

  static Object? _copyValue(Object? value) {
    if (value is Map<String, dynamic>) {
      return _copyMap(value);
    }
    if (value is List) {
      return value.map(_copyValue).toList();
    }
    return value;
  }
}
