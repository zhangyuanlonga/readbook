import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/source_health.dart';

class SourceHealthPersistenceService {
  SourceHealthPersistenceService({
    SharedPreferences? preferences,
    AppDatabase? database,
  })
    : _preferencesFuture =
          preferences == null
              ? SharedPreferences.getInstance()
              : Future.value(preferences),
      _database = database ?? AppDatabase.instance;

  static const String _storageKey = 'source.health.snapshots.v1';

  final Future<SharedPreferences> _preferencesFuture;
  final AppDatabase _database;

  Future<Map<String, SourceHealthSnapshot>> loadSnapshots() async {
    final stored = await _database.listSourceHealthSnapshots();
    if (stored.isNotEmpty) {
      return stored;
    }

    final prefs = await _preferencesFuture;
    final raw = (prefs.getString(_storageKey) ?? '').trim();
    if (raw.isEmpty) {
      return <String, SourceHealthSnapshot>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, SourceHealthSnapshot>{};
      }
      final snapshots = <String, SourceHealthSnapshot>{};
      for (final entry in decoded.entries) {
        final sourceId = entry.key.toString().trim();
        final value = entry.value;
        if (sourceId.isEmpty || value is! Map) {
          continue;
        }
        snapshots[sourceId] = SourceHealthSnapshot.fromJson(
          Map<String, dynamic>.from(
            value.map((key, item) => MapEntry(key.toString(), item)),
          ),
        );
      }
      await _database.replaceSourceHealthSnapshots(snapshots);
      await prefs.remove(_storageKey);
      return snapshots;
    } catch (_) {
      return <String, SourceHealthSnapshot>{};
    }
  }

  Future<void> saveSnapshots(
    Map<String, SourceHealthSnapshot> snapshots,
  ) async {
    await _database.replaceSourceHealthSnapshots(snapshots);
    final prefs = await _preferencesFuture;
    await prefs.remove(_storageKey);
  }
}
