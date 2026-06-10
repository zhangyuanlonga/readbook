import 'package:shared_preferences/shared_preferences.dart';

class DeprecatedKeysCleanupResult {
  const DeprecatedKeysCleanupResult({
    required this.cleaned,
    required this.removedKeys,
  });

  final bool cleaned;
  final List<String> removedKeys;

  int get removedCount => removedKeys.length;
}

class DeprecatedKeysCleaner {
  DeprecatedKeysCleaner({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  static const String _cleanupMarkerKey = '_deprecated_keys_cleaned_v1';

  // 仅清理已明确退役、且当前代码不会再读取的 key。
  static const List<String> _deprecatedKeys = <String>[
    'reader.local.txt.chapterRules',
  ];

  final Future<SharedPreferences> _preferencesFuture;

  Future<DeprecatedKeysCleanupResult> cleanOnce() async {
    final prefs = await _preferencesFuture;
    if (prefs.getBool(_cleanupMarkerKey) ?? false) {
      return const DeprecatedKeysCleanupResult(
        cleaned: false,
        removedKeys: <String>[],
      );
    }

    final removedKeys = <String>[];
    for (final key in _deprecatedKeys) {
      if (!prefs.containsKey(key)) {
        continue;
      }
      await prefs.remove(key);
      removedKeys.add(key);
    }
    await prefs.setBool(_cleanupMarkerKey, true);
    return DeprecatedKeysCleanupResult(
      cleaned: true,
      removedKeys: List<String>.unmodifiable(removedKeys),
    );
  }
}
