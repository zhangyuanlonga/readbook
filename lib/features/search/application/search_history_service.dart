import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/preferences/preference_key.dart';
import '../../../core/auth/auth_session_store.dart';

/// 搜索历史偏好服务。
///
/// 搜索历史只是一组短字符串，继续放在 `SharedPreferences` 比进 Drift 更轻。
/// 新版本统一用 `PreferenceKey<List<String>>` 和 `setStringList` 保存，避免手写
/// JSON 增加解析分支和 Web / 桌面端类型差异。读取时仍兼容旧版本写入的 JSON 字符串，
/// 这样升级后 Android、iOS、Web JS、macOS、Windows、Linux 都能保留原历史记录。
class SearchHistoryService {
  SearchHistoryService({
    SharedPreferences? preferences,
    Future<String?> Function()? userIdResolver,
  }) : _preferencesFuture =
           preferences == null
               ? SharedPreferences.getInstance()
               : Future.value(preferences),
       _userIdResolver = userIdResolver ?? AuthSessionStore().getUserId;

  final Future<SharedPreferences> _preferencesFuture;
  final Future<String?> Function() _userIdResolver;

  static const String historyPreferenceKey = 'search.history';
  static const PreferenceKey<List<String>> historyPreference =
      PreferenceKey<List<String>>(
        historyPreferenceKey,
        defaultValue: <String>[],
      );
  static const String localUserId = 'local_user';
  static const int _maxHistoryCount = 15;

  Future<List<String>> getAll() async {
    final prefs = await _preferencesFuture;
    final key = await _historyKey();
    final scoped = _readHistory(prefs, key);
    if (scoped.isNotEmpty) {
      return scoped;
    }
    return _readHistory(prefs, historyPreference.name);
  }

  Future<void> add(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final all = (await getAll()).toList(growable: true);
    all.remove(trimmed);
    all.insert(0, trimmed);

    await _save(all);
  }

  Future<void> remove(String keyword) async {
    final all = (await getAll())
        .where((item) => item != keyword.trim())
        .toList(growable: false);
    await _save(all);
  }

  Future<void> clear() async {
    final prefs = await _preferencesFuture;
    await prefs.remove(await _historyKey());
  }

  Future<void> _save(List<String> history) async {
    final prefs = await _preferencesFuture;
    await prefs.setStringList(await _historyKey(), _normalizeHistory(history));
  }

  Future<String> _historyKey() async {
    final userId = (await _userIdResolver())?.trim() ?? '';
    final scope = userId.isEmpty ? localUserId : userId;
    return '${historyPreference.name}.$scope';
  }

  static List<String> _readHistory(SharedPreferences prefs, String key) {
    final stored = prefs.get(key);
    if (stored is List) {
      return _normalizeHistory(stored.whereType<String>());
    }
    if (stored is String) {
      return _readLegacyJsonHistory(stored);
    }
    return historyPreference.defaultValue ?? const <String>[];
  }

  static List<String> _readLegacyJsonHistory(String raw) {
    if (raw.trim().isEmpty) {
      return const <String>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <String>[];
      }

      // 旧版本把搜索历史写成 JSON 字符串；新版本改用 StringList。
      // 保留这条兼容读取路径，避免升级后 Android、iOS、Web 和桌面端丢历史。
      return _normalizeHistory(decoded.whereType<String>());
    } on FormatException {
      return const <String>[];
    }
  }

  static List<String> _normalizeHistory(Iterable<String> history) {
    final normalized = <String>[];
    for (final item in history) {
      final trimmed = item.trim();
      if (trimmed.isEmpty || normalized.contains(trimmed)) {
        continue;
      }
      normalized.add(trimmed);
      if (normalized.length >= _maxHistoryCount) {
        break;
      }
    }
    return normalized;
  }
}
