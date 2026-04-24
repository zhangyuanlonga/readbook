import 'dart:convert';

import '../../../runtime/sources/source_contract.dart';
import '../../../runtime/sources/source_registry.dart';
import '../../../runtime/sources/source_result_models.dart' as runtime_models;
import 'source_runtime_facade.dart';

enum SourceLoginFieldType {
  text,
  password,
  select,
  button,
  toggle,
  textarea,
  note,
  divider,
}

class SourceLoginFieldOption {
  const SourceLoginFieldOption({required this.label, required this.value});

  final String label;
  final String value;
}

class SourceLoginFieldStyle {
  const SourceLoginFieldStyle({
    this.layoutFlexGrow,
    this.layoutFlexBasisPercent,
    this.layoutJustifySelf,
  });

  final double? layoutFlexGrow;
  final double? layoutFlexBasisPercent;
  final String? layoutJustifySelf;

  bool get isEmpty =>
      layoutFlexGrow == null &&
      layoutFlexBasisPercent == null &&
      (layoutJustifySelf == null || layoutJustifySelf!.trim().isEmpty);
}

class SourceLoginField {
  const SourceLoginField({
    required this.name,
    required this.type,
    this.label,
    this.viewName,
    this.defaultValue,
    this.action,
    this.style = const SourceLoginFieldStyle(),
    this.options = const <SourceLoginFieldOption>[],
  });

  final String name;
  final SourceLoginFieldType type;
  final String? label;
  final String? viewName;
  final String? defaultValue;
  final String? action;
  final SourceLoginFieldStyle style;
  final List<SourceLoginFieldOption> options;

  SourceLoginField copyWith({
    String? label,
    String? viewName,
    String? defaultValue,
    String? action,
    SourceLoginFieldStyle? style,
    List<SourceLoginFieldOption>? options,
  }) {
    return SourceLoginField(
      name: name,
      type: type,
      label: label ?? this.label,
      viewName: viewName ?? this.viewName,
      defaultValue: defaultValue ?? this.defaultValue,
      action: action ?? this.action,
      style: style ?? this.style,
      options: options ?? this.options,
    );
  }
}

class SourceLoginPresentation {
  const SourceLoginPresentation({
    required this.sourceId,
    required this.sourceName,
    required this.fields,
    required this.formData,
  });

  final String sourceId;
  final String sourceName;
  final List<SourceLoginField> fields;
  final Map<String, String> formData;
}

class SourceLoginActionResult {
  const SourceLoginActionResult({
    required this.presentation,
    this.message,
    this.formPatch = const <String, String>{},
  });

  final SourceLoginPresentation presentation;
  final String? message;
  final Map<String, String> formPatch;
}

class SourceLoginRuntimeService {
  SourceLoginRuntimeService({SourceRuntimeFacade? sourceRuntimeFacade})
    : _sourceRuntimeFacade =
          sourceRuntimeFacade ?? SourceRuntimeFacade.instance;

  final SourceRuntimeFacade _sourceRuntimeFacade;

  Future<bool> supportsLogin(String sourceId) async {
    final registered = await _sourceRuntimeFacade
        .ensureRegisteredScriptSourceById(sourceId);
    return registered?.definition.supportsLogin ?? false;
  }

  Future<SourceLoginPresentation?> loadPresentation(
    String sourceId, {
    SourceUiContext ui = const SourceUiContext(),
    runtime_models.Book? book,
    runtime_models.Chapter? chapter,
  }) async {
    final registered = await _sourceRuntimeFacade
        .ensureRegisteredScriptSourceById(sourceId);
    if (registered == null || !registered.definition.supportsLogin) {
      return null;
    }

    final context = _sourceRuntimeFacade.createRuntimeContext(
      registered,
      ui: ui,
    );
    final initialFormData = await context.sourceLogin.getInfoMap();
    final fields = await _resolveFields(
      registered: registered,
      context: context,
      formData: initialFormData,
      book: book,
      chapter: chapter,
    );
    if (fields == null || fields.isEmpty) {
      return null;
    }

    final resolvedFormData = <String, String>{...initialFormData};
    for (final field in fields) {
      if (field.type == SourceLoginFieldType.button) {
        continue;
      }
      resolvedFormData.putIfAbsent(field.name, () => field.defaultValue ?? '');
    }

    return SourceLoginPresentation(
      sourceId: sourceId,
      sourceName: registered.runtime.name,
      fields: fields,
      formData: resolvedFormData,
    );
  }

  Future<SourceLoginActionResult> submit(
    String sourceId, {
    required Map<String, String> formData,
    SourceUiContext ui = const SourceUiContext(),
    runtime_models.Book? book,
    runtime_models.Chapter? chapter,
    String? actionCode,
    bool isLongClick = false,
  }) async {
    final registered = await _requireRegistered(sourceId);
    final context = _sourceRuntimeFacade.createRuntimeContext(
      registered,
      ui: ui,
    );
    final mergedFormData = <String, String>{...formData};
    await context.sourceLogin.putInfo(_encodeFormData(mergedFormData));

    Object? rawResult;
    if (_looksLikeAbsoluteUrl(actionCode)) {
      await ui.openBrowserAwait(
        url: actionCode!.trim(),
        title: registered.runtime.name,
        refetchAfterSuccess: false,
      );
      rawResult = '已打开页面。';
    } else {
      rawResult = await registered.definition.loginAction?.call(
        context,
        mergedFormData,
        book: book,
        chapter: chapter,
        actionCode: actionCode,
        isLongClick: isLongClick,
      );
    }

    final formPatch = _coerceFormPatch(rawResult);
    if (formPatch.isNotEmpty) {
      mergedFormData.addAll(formPatch);
      await context.sourceLogin.putInfo(_encodeFormData(mergedFormData));
    }
    final message = _coerceMessage(rawResult);

    final presentation =
        await loadPresentation(
          sourceId,
          ui: ui,
          book: book,
          chapter: chapter,
        ) ??
        SourceLoginPresentation(
          sourceId: sourceId,
          sourceName: registered.runtime.name,
          fields: const <SourceLoginField>[],
          formData: await context.sourceLogin.getInfoMap(),
        );

    return SourceLoginActionResult(
      presentation: presentation,
      message: message,
      formPatch: formPatch,
    );
  }

  Future<List<SourceLoginField>?> _resolveFields({
    required RegisteredSource registered,
    required SourceRuntimeContext context,
    required Map<String, String> formData,
    runtime_models.Book? book,
    runtime_models.Chapter? chapter,
  }) async {
    final raw = await registered.definition.loginUi?.call(
      context,
      formData,
      book: book,
      chapter: chapter,
    );
    final fields = _parseFields(raw);
    if (fields == null) {
      return null;
    }
    return await _resolveDynamicLabels(
      registered: registered,
      context: context,
      formData: formData,
      fields: fields,
      book: book,
      chapter: chapter,
    );
  }

  List<SourceLoginField>? _parseFields(Object? raw) {
    final list = switch (raw) {
      List<dynamic>() => raw.cast<Object?>(),
      String() => _decodeFieldList(raw),
      _ => null,
    };
    if (list == null) {
      return null;
    }

    final fields = <SourceLoginField>[];
    for (final item in list) {
      final map = switch (item) {
        Map<Object?, Object?>() => item.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
        _ => null,
      };
      if (map == null) {
        continue;
      }
      final field = _parseField(map);
      if (field != null) {
        fields.add(field);
      }
    }
    return fields;
  }

  List<Object?>? _decodeFieldList(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is List) {
        return decoded.cast<Object?>();
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  SourceLoginField? _parseField(Map<String, dynamic> map) {
    final name = (map['name']?.toString() ?? '').trim();
    final type = _parseFieldType(map['type']?.toString());
    if (name.isEmpty || type == null) {
      return null;
    }

    final viewName = (map['viewName']?.toString() ?? '').trim();
    final options =
        (map['chars'] is List)
            ? (map['chars'] as List)
                .map((item) => item?.toString().trim() ?? '')
                .where((item) => item.isNotEmpty)
                .map((item) => SourceLoginFieldOption(label: item, value: item))
                .toList(growable: false)
            : const <SourceLoginFieldOption>[];
    final style = _parseFieldStyle(map['style']);

    return SourceLoginField(
      name: name,
      type: type,
      label: _resolveStaticViewName(name, viewName),
      viewName: viewName.isEmpty ? null : viewName,
      defaultValue: (map['default']?.toString() ?? '').trim(),
      action: (map['action']?.toString() ?? '').trim(),
      style: style,
      options: options,
    );
  }

  SourceLoginFieldType? _parseFieldType(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    return switch (normalized) {
      'text' => SourceLoginFieldType.text,
      'password' => SourceLoginFieldType.password,
      'select' => SourceLoginFieldType.select,
      'button' => SourceLoginFieldType.button,
      'toggle' => SourceLoginFieldType.toggle,
      'textarea' => SourceLoginFieldType.textarea,
      'note' => SourceLoginFieldType.note,
      'divider' => SourceLoginFieldType.divider,
      _ => null,
    };
  }

  Future<List<SourceLoginField>> _resolveDynamicLabels({
    required RegisteredSource registered,
    required SourceRuntimeContext context,
    required Map<String, String> formData,
    required List<SourceLoginField> fields,
    runtime_models.Book? book,
    runtime_models.Chapter? chapter,
  }) async {
    final resolved = <SourceLoginField>[];
    for (final field in fields) {
      final viewName = field.viewName?.trim();
      if (viewName == null || viewName.isEmpty) {
        resolved.add(field);
        continue;
      }
      if (_isStaticQuotedText(viewName)) {
        resolved.add(field.copyWith(label: _stripQuotedText(viewName)));
        continue;
      }
      try {
        final raw = await registered.definition.loginAction?.call(
          context,
          formData,
          book: book,
          chapter: chapter,
          actionCode: viewName,
          isLongClick: false,
        );
        final label = _coerceViewName(raw);
        resolved.add(field.copyWith(label: label ?? field.label));
      } catch (_) {
        resolved.add(field.copyWith(label: field.label ?? field.name));
      }
    }
    return resolved;
  }

  String? _resolveStaticViewName(String name, String rawViewName) {
    if (rawViewName.isEmpty) {
      return null;
    }
    if (_isStaticQuotedText(rawViewName)) {
      return _stripQuotedText(rawViewName);
    }
    return null;
  }

  bool _isStaticQuotedText(String value) {
    return value.length >= 2 &&
        ((value.startsWith("'") && value.endsWith("'")) ||
            (value.startsWith('"') && value.endsWith('"')));
  }

  String _stripQuotedText(String value) {
    return value.substring(1, value.length - 1).trim();
  }

  String? _coerceViewName(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is Map) {
      return _coerceMessage(raw);
    }
    final text = raw.toString().trim();
    return text.isEmpty ? null : text;
  }

  SourceLoginFieldStyle _parseFieldStyle(Object? raw) {
    final map = switch (raw) {
      Map<Object?, Object?>() => raw.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      _ => null,
    };
    if (map == null) {
      return const SourceLoginFieldStyle();
    }
    return SourceLoginFieldStyle(
      layoutFlexGrow: _readDouble(
        map['layoutFlexGrow'] ?? map['layout_flexGrow'],
      ),
      layoutFlexBasisPercent: _normalizeBasisPercent(
        _readDouble(
          map['layoutFlexBasisPercent'] ?? map['layout_flexBasisPercent'],
        ),
      ),
      layoutJustifySelf:
          (map['layoutJustifySelf'] ?? map['layout_justifySelf'])
              ?.toString()
              .trim(),
    );
  }

  double? _readDouble(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is num) {
      return raw.toDouble();
    }
    return double.tryParse(raw.toString().trim());
  }

  double? _normalizeBasisPercent(double? raw) {
    if (raw == null || raw <= 0) {
      return null;
    }
    if (raw > 1 && raw <= 100) {
      return raw / 100;
    }
    return raw.clamp(0.0, 1.0);
  }

  Future<RegisteredSource> _requireRegistered(String sourceId) async {
    final registered = await _sourceRuntimeFacade
        .ensureRegisteredScriptSourceById(sourceId);
    if (registered == null || !registered.definition.supportsLogin) {
      throw StateError('当前书源未实现登录能力。');
    }
    return registered;
  }

  String _encodeFormData(Map<String, String> formData) {
    return jsonEncode(formData);
  }

  String? _coerceMessage(Object? raw) {
    if (raw is Map) {
      final message =
          raw['message'] ??
          raw['_message'] ??
          raw['toast'] ??
          raw['tip'];
      final text = (message?.toString() ?? '').trim();
      return text.isEmpty ? null : text;
    }
    if (raw is String) {
      final normalized = raw.trim();
      if (normalized.startsWith('{') && normalized.endsWith('}')) {
        try {
          final decoded = jsonDecode(normalized);
          if (decoded is Map) {
            return _coerceMessage(decoded);
          }
        } catch (_) {
          // Ignore invalid json-shaped message.
        }
      }
    }
    final text = (raw?.toString() ?? '').trim();
    return text.isEmpty ? null : text;
  }

  Map<String, String> _coerceFormPatch(Object? raw) {
    final map = switch (raw) {
      Map<Object?, Object?>() => raw.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      String() => _decodeJsonObject(raw),
      _ => null,
    };
    if (map == null) {
      return const <String, String>{};
    }
    return <String, String>{
      for (final entry in map.entries)
        if (!_isReservedActionKey(entry.key))
          entry.key.toString(): entry.value?.toString() ?? '',
    };
  }

  Map<String, dynamic>? _decodeJsonObject(String raw) {
    final normalized = raw.trim();
    if (!normalized.startsWith('{') || !normalized.endsWith('}')) {
      return null;
    }
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  bool _isReservedActionKey(Object? key) {
    final normalized = key?.toString().trim().toLowerCase();
    return normalized == 'message' ||
        normalized == '_message' ||
        normalized == 'toast' ||
        normalized == 'tip';
  }

  bool _looksLikeAbsoluteUrl(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    return normalized.startsWith('http://') ||
        normalized.startsWith('https://') ||
        normalized.startsWith('data:text/html');
  }
}
