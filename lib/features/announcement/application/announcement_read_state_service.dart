import 'package:shared_preferences/shared_preferences.dart';

class AnnouncementReadStateService {
  AnnouncementReadStateService({SharedPreferences? preferences})
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences);

  static const String _storageKey = 'announcement.read.ids';

  final Future<SharedPreferences> _preferencesFuture;

  Future<Set<String>> getReadIds() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getStringList(_storageKey) ?? const <String>[];
    return raw
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  Future<bool> isRead(String id) async {
    final normalized = id.trim();
    if (normalized.isEmpty) {
      return false;
    }
    final ids = await getReadIds();
    return ids.contains(normalized);
  }

  Future<void> markRead(String id) async {
    final normalized = id.trim();
    if (normalized.isEmpty) {
      return;
    }
    final prefs = await _preferencesFuture;
    final raw = prefs.getStringList(_storageKey) ?? <String>[];
    if (raw.contains(normalized)) {
      return;
    }
    raw.add(normalized);
    await prefs.setStringList(_storageKey, raw);
  }

  Future<void> markAllRead(Iterable<String> ids) async {
    final normalized = ids
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    if (normalized.isEmpty) {
      return;
    }
    final prefs = await _preferencesFuture;
    final raw = prefs.getStringList(_storageKey) ?? <String>[];
    raw.addAll(normalized);
    await prefs.setStringList(_storageKey, raw.toSet().toList());
  }

  Future<void> clearRead(String id) async {
    final normalized = id.trim();
    if (normalized.isEmpty) {
      return;
    }
    final prefs = await _preferencesFuture;
    final raw = prefs.getStringList(_storageKey) ?? <String>[];
    raw.removeWhere((item) => item == normalized);
    await prefs.setStringList(_storageKey, raw);
  }
}
