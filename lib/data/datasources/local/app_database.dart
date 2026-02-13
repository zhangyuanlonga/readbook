import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../domain/entities/source_definition.dart';

part 'app_database.g.dart';

class Sources extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get baseUrl => text()();
  TextColumn get group => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get comment => text().nullable()();
  TextColumn get headersJson => text().withDefault(const Constant('{}'))();
  TextColumn get rulesJson => text().withDefault(const Constant('{}'))();
  TextColumn get healthStatus =>
      text().withDefault(const Constant('unknown'))();
  DateTimeColumn get lastCheckedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get rawJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Sources])
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  static final AppDatabase instance = AppDatabase();

  @override
  int get schemaVersion => 1;

  Future<List<SourceDefinition>> getAllSources() async {
    final rows =
        await (select(sources)..orderBy([
          (table) => OrderingTerm.asc(table.group),
          (table) => OrderingTerm.asc(table.name),
        ])).get();
    return rows.map(_mapRowToSource).toList();
  }

  Stream<List<SourceDefinition>> watchAllSources() {
    final query = select(sources)..orderBy([
      (table) => OrderingTerm.asc(table.group),
      (table) => OrderingTerm.asc(table.name),
    ]);
    return query.watch().map(
      (rows) => rows.map(_mapRowToSource).toList(growable: false),
    );
  }

  Future<void> upsertSources(List<SourceDefinition> items) async {
    if (items.isEmpty) {
      return;
    }

    final now = DateTime.now();

    await batch((batch) {
      for (final item in items) {
        batch.insert(
          sources,
          _toCompanion(item, now),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> setSourceEnabled(String id, bool enabled) {
    return (update(sources)..where((table) => table.id.equals(id))).write(
      SourcesCompanion(
        enabled: Value(enabled),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteSource(String id) {
    return (delete(sources)..where((table) => table.id.equals(id))).go();
  }

  Future<void> deleteSourcesByIds(List<String> ids) {
    if (ids.isEmpty) {
      return Future.value();
    }

    return (delete(sources)..where((table) => table.id.isIn(ids))).go();
  }

  Future<void> clearSources() => delete(sources).go();

  SourceDefinition _mapRowToSource(Source row) {
    final rules = _decodeMap(row.rulesJson);
    final headers = _decodeMap(
      row.headersJson,
    ).map((key, value) => MapEntry(key, value.toString()));
    final raw = _decodeMap(row.rawJson);

    final status = SourceHealthStatus.values.firstWhere(
      (item) => item.name == row.healthStatus,
      orElse: () => SourceHealthStatus.unknown,
    );

    return SourceDefinition(
      id: row.id,
      name: row.name,
      baseUrl: row.baseUrl,
      group: row.group,
      enabled: row.enabled,
      comment: row.comment,
      headers: headers,
      rules: SourceRuleSet.fromJson(rules),
      lastCheckStatus: status,
      lastCheckedAt: row.lastCheckedAt,
      lastCheckMessage: _nullableString(raw['lastCheckMessage']),
    );
  }

  SourcesCompanion _toCompanion(SourceDefinition source, DateTime now) {
    final rulesJson = jsonEncode(source.rules.toJson());
    final headersJson = jsonEncode(source.headers);
    final rawJson = jsonEncode(source.toJson());

    return SourcesCompanion(
      id: Value(source.id),
      name: Value(source.name),
      baseUrl: Value(source.baseUrl),
      group: Value(source.group),
      enabled: Value(source.enabled),
      comment: Value(source.comment),
      headersJson: Value(headersJson),
      rulesJson: Value(rulesJson),
      healthStatus: Value(source.lastCheckStatus.name),
      lastCheckedAt: Value(source.lastCheckedAt),
      createdAt: Value(now),
      updatedAt: Value(now),
      rawJson: Value(rawJson),
    );
  }

  String? _nullableString(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }

  Map<String, dynamic> _decodeMap(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
      return const {};
    } on FormatException {
      return const {};
    }
  }
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final isFlutterTest = Platform.environment.containsKey('FLUTTER_TEST');

    final baseDir =
        isFlutterTest
            ? Directory.systemTemp
            : await getApplicationSupportDirectory();

    final databaseDir = Directory(p.join(baseDir.path, 'flutter_appread'));
    if (!databaseDir.existsSync()) {
      databaseDir.createSync(recursive: true);
    }

    final file = File(p.join(databaseDir.path, 'appread_sources.db'));
    return NativeDatabase(file);
  });
}
