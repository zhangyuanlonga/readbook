import 'dart:convert';

import 'source_runtime_session_service.dart';

enum SourceLoginUiKind { json, dynamicJs, unsupported }

enum SourceLoginUiFieldType { text, password, select, toggle, button }

class SourceLoginUiSpec {
  const SourceLoginUiSpec({
    required this.kind,
    required this.fields,
    this.diagnostic,
    this.dynamicScript,
  });

  final SourceLoginUiKind kind;
  final List<SourceLoginUiField> fields;
  final String? diagnostic;
  final String? dynamicScript;

  bool get isRenderable => kind == SourceLoginUiKind.json && fields.isNotEmpty;
  bool get isDynamic => kind == SourceLoginUiKind.dynamicJs;

  factory SourceLoginUiSpec.fromTask(SourceLoginTask task) {
    final raw = _rawLoginUi(task);
    if (raw.trim().isEmpty && task.loginUi == null) {
      return const SourceLoginUiSpec(
        kind: SourceLoginUiKind.unsupported,
        fields: <SourceLoginUiField>[],
        diagnostic: '该书源没有返回 loginUi 数据。',
      );
    }

    final dynamicScript = _extractDynamicScript(raw);
    if (dynamicScript != null) {
      return SourceLoginUiSpec(
        kind: SourceLoginUiKind.dynamicJs,
        fields: const <SourceLoginUiField>[],
        dynamicScript: dynamicScript,
        diagnostic: '该书源使用动态 loginUi JS，需要 Rust 网关提供 Legado 兼容执行上下文后才能渲染。',
      );
    }

    final decoded = task.loginUi ?? _tryDecodeJson(raw);
    final fields = _decodeFields(decoded);
    if (fields.isEmpty) {
      return const SourceLoginUiSpec(
        kind: SourceLoginUiKind.unsupported,
        fields: <SourceLoginUiField>[],
        diagnostic: 'loginUi 不是可识别的 JSON 数组。',
      );
    }
    return SourceLoginUiSpec(kind: SourceLoginUiKind.json, fields: fields);
  }
}

class SourceLoginUiField {
  const SourceLoginUiField({
    required this.name,
    required this.type,
    required this.label,
    this.action,
    this.defaultValue,
    this.required = false,
    this.options = const <String>[],
  });

  final String name;
  final SourceLoginUiFieldType type;
  final String label;
  final String? action;
  final String? defaultValue;
  final bool required;
  final List<String> options;

  bool get capturesInput => type != SourceLoginUiFieldType.button;
}

String _rawLoginUi(SourceLoginTask task) {
  final raw = task.loginUiRaw?.trim();
  if (raw != null && raw.isNotEmpty) {
    return raw;
  }
  final loginUi = task.loginUi;
  if (loginUi == null) {
    return '';
  }
  if (loginUi is String) {
    return loginUi.trim();
  }
  try {
    return jsonEncode(loginUi);
  } catch (_) {
    return loginUi.toString().trim();
  }
}

String? _extractDynamicScript(String value) {
  final raw = value.trim();
  if (raw.startsWith('@js:')) {
    final script = raw.substring(4).trim();
    return script.isEmpty ? null : script;
  }
  if (raw.startsWith('<js>')) {
    final end = raw.lastIndexOf('</js>');
    final script = raw.substring(4, end > 4 ? end : raw.length).trim();
    return script.isEmpty ? null : script;
  }
  return null;
}

Object? _tryDecodeJson(String value) {
  final raw = value.trim();
  if (raw.isEmpty) {
    return null;
  }
  try {
    return jsonDecode(raw);
  } catch (_) {
    return null;
  }
}

List<SourceLoginUiField> _decodeFields(Object? value) {
  final items = value is List ? value : const <Object?>[];
  return items
      .map(_decodeField)
      .whereType<SourceLoginUiField>()
      .toList(growable: false);
}

SourceLoginUiField? _decodeField(Object? value) {
  if (value is! Map) {
    return null;
  }
  final map = value.map((key, value) => MapEntry(key.toString(), value));
  final name = _stringAt(map, const <String>['name', 'key', 'id']);
  final type = _fieldType(_stringAt(map, const <String>['type']));
  if (name.isEmpty || type == null) {
    return null;
  }
  final options = (map['chars'] is List
          ? map['chars'] as List
          : const <Object?>[])
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  final defaultValue = _optionalStringAt(map, const <String>[
    'default',
    'defaultValue',
    'value',
  ]);
  return SourceLoginUiField(
    name: name,
    type: type,
    label: _normalizeLabel(
      _stringAt(map, const <String>['viewName', 'label', 'title']),
      fallback: name,
    ),
    action: _optionalStringAt(map, const <String>['action']),
    defaultValue: defaultValue,
    required: _boolAt(map, const <String>['required', 'require', 'notEmpty']),
    options: options,
  );
}

SourceLoginUiFieldType? _fieldType(String value) {
  return switch (value.trim().toLowerCase()) {
    'text' || 'input' || '' => SourceLoginUiFieldType.text,
    'password' || 'pwd' => SourceLoginUiFieldType.password,
    'select' || 'spinner' => SourceLoginUiFieldType.select,
    'toggle' || 'switch' || 'checkbox' => SourceLoginUiFieldType.toggle,
    'button' || 'btn' => SourceLoginUiFieldType.button,
    _ => null,
  };
}

String _normalizeLabel(String value, {required String fallback}) {
  final text = value.trim();
  if (text.length >= 2 && text.startsWith("'") && text.endsWith("'")) {
    return text.substring(1, text.length - 1).trim();
  }
  if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
    return text.substring(1, text.length - 1).trim();
  }
  return text.isEmpty ? fallback : text;
}

String _stringAt(Map<String, Object?> map, List<String> keys) {
  return _optionalStringAt(map, keys) ?? '';
}

String? _optionalStringAt(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key]?.toString().trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

bool _boolAt(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is bool) return value;
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text == 'true' || text == '1' || text == 'yes') return true;
  }
  return false;
}
