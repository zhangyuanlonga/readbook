// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SourcesTable extends Sources with TableInfo<$SourcesTable, Source> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  @override
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupMeta = const VerificationMeta('group');
  @override
  late final GeneratedColumn<String> group = GeneratedColumn<String>(
    'group',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _commentMeta = const VerificationMeta(
    'comment',
  );
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _headersJsonMeta = const VerificationMeta(
    'headersJson',
  );
  @override
  late final GeneratedColumn<String> headersJson = GeneratedColumn<String>(
    'headers_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _rulesJsonMeta = const VerificationMeta(
    'rulesJson',
  );
  @override
  late final GeneratedColumn<String> rulesJson = GeneratedColumn<String>(
    'rules_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _healthStatusMeta = const VerificationMeta(
    'healthStatus',
  );
  @override
  late final GeneratedColumn<String> healthStatus = GeneratedColumn<String>(
    'health_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unknown'),
  );
  static const VerificationMeta _lastCheckedAtMeta = const VerificationMeta(
    'lastCheckedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastCheckedAt =
      GeneratedColumn<DateTime>(
        'last_checked_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _rawJsonMeta = const VerificationMeta(
    'rawJson',
  );
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
    'raw_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    baseUrl,
    group,
    enabled,
    comment,
    headersJson,
    rulesJson,
    healthStatus,
    lastCheckedAt,
    createdAt,
    updatedAt,
    rawJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<Source> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('group')) {
      context.handle(
        _groupMeta,
        group.isAcceptableOrUnknown(data['group']!, _groupMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('comment')) {
      context.handle(
        _commentMeta,
        comment.isAcceptableOrUnknown(data['comment']!, _commentMeta),
      );
    }
    if (data.containsKey('headers_json')) {
      context.handle(
        _headersJsonMeta,
        headersJson.isAcceptableOrUnknown(
          data['headers_json']!,
          _headersJsonMeta,
        ),
      );
    }
    if (data.containsKey('rules_json')) {
      context.handle(
        _rulesJsonMeta,
        rulesJson.isAcceptableOrUnknown(data['rules_json']!, _rulesJsonMeta),
      );
    }
    if (data.containsKey('health_status')) {
      context.handle(
        _healthStatusMeta,
        healthStatus.isAcceptableOrUnknown(
          data['health_status']!,
          _healthStatusMeta,
        ),
      );
    }
    if (data.containsKey('last_checked_at')) {
      context.handle(
        _lastCheckedAtMeta,
        lastCheckedAt.isAcceptableOrUnknown(
          data['last_checked_at']!,
          _lastCheckedAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('raw_json')) {
      context.handle(
        _rawJsonMeta,
        rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Source map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Source(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      baseUrl:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}base_url'],
          )!,
      group: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group'],
      ),
      enabled:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}enabled'],
          )!,
      comment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment'],
      ),
      headersJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}headers_json'],
          )!,
      rulesJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}rules_json'],
          )!,
      healthStatus:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}health_status'],
          )!,
      lastCheckedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_checked_at'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
      rawJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}raw_json'],
          )!,
    );
  }

  @override
  $SourcesTable createAlias(String alias) {
    return $SourcesTable(attachedDatabase, alias);
  }
}

class Source extends DataClass implements Insertable<Source> {
  final String id;
  final String name;
  final String baseUrl;
  final String? group;
  final bool enabled;
  final String? comment;
  final String headersJson;
  final String rulesJson;
  final String healthStatus;
  final DateTime? lastCheckedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String rawJson;
  const Source({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.group,
    required this.enabled,
    this.comment,
    required this.headersJson,
    required this.rulesJson,
    required this.healthStatus,
    this.lastCheckedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.rawJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['base_url'] = Variable<String>(baseUrl);
    if (!nullToAbsent || group != null) {
      map['group'] = Variable<String>(group);
    }
    map['enabled'] = Variable<bool>(enabled);
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    map['headers_json'] = Variable<String>(headersJson);
    map['rules_json'] = Variable<String>(rulesJson);
    map['health_status'] = Variable<String>(healthStatus);
    if (!nullToAbsent || lastCheckedAt != null) {
      map['last_checked_at'] = Variable<DateTime>(lastCheckedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['raw_json'] = Variable<String>(rawJson);
    return map;
  }

  SourcesCompanion toCompanion(bool nullToAbsent) {
    return SourcesCompanion(
      id: Value(id),
      name: Value(name),
      baseUrl: Value(baseUrl),
      group:
          group == null && nullToAbsent ? const Value.absent() : Value(group),
      enabled: Value(enabled),
      comment:
          comment == null && nullToAbsent
              ? const Value.absent()
              : Value(comment),
      headersJson: Value(headersJson),
      rulesJson: Value(rulesJson),
      healthStatus: Value(healthStatus),
      lastCheckedAt:
          lastCheckedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(lastCheckedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      rawJson: Value(rawJson),
    );
  }

  factory Source.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Source(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      baseUrl: serializer.fromJson<String>(json['baseUrl']),
      group: serializer.fromJson<String?>(json['group']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      comment: serializer.fromJson<String?>(json['comment']),
      headersJson: serializer.fromJson<String>(json['headersJson']),
      rulesJson: serializer.fromJson<String>(json['rulesJson']),
      healthStatus: serializer.fromJson<String>(json['healthStatus']),
      lastCheckedAt: serializer.fromJson<DateTime?>(json['lastCheckedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      rawJson: serializer.fromJson<String>(json['rawJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'baseUrl': serializer.toJson<String>(baseUrl),
      'group': serializer.toJson<String?>(group),
      'enabled': serializer.toJson<bool>(enabled),
      'comment': serializer.toJson<String?>(comment),
      'headersJson': serializer.toJson<String>(headersJson),
      'rulesJson': serializer.toJson<String>(rulesJson),
      'healthStatus': serializer.toJson<String>(healthStatus),
      'lastCheckedAt': serializer.toJson<DateTime?>(lastCheckedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'rawJson': serializer.toJson<String>(rawJson),
    };
  }

  Source copyWith({
    String? id,
    String? name,
    String? baseUrl,
    Value<String?> group = const Value.absent(),
    bool? enabled,
    Value<String?> comment = const Value.absent(),
    String? headersJson,
    String? rulesJson,
    String? healthStatus,
    Value<DateTime?> lastCheckedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    String? rawJson,
  }) => Source(
    id: id ?? this.id,
    name: name ?? this.name,
    baseUrl: baseUrl ?? this.baseUrl,
    group: group.present ? group.value : this.group,
    enabled: enabled ?? this.enabled,
    comment: comment.present ? comment.value : this.comment,
    headersJson: headersJson ?? this.headersJson,
    rulesJson: rulesJson ?? this.rulesJson,
    healthStatus: healthStatus ?? this.healthStatus,
    lastCheckedAt:
        lastCheckedAt.present ? lastCheckedAt.value : this.lastCheckedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    rawJson: rawJson ?? this.rawJson,
  );
  Source copyWithCompanion(SourcesCompanion data) {
    return Source(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      group: data.group.present ? data.group.value : this.group,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      comment: data.comment.present ? data.comment.value : this.comment,
      headersJson:
          data.headersJson.present ? data.headersJson.value : this.headersJson,
      rulesJson: data.rulesJson.present ? data.rulesJson.value : this.rulesJson,
      healthStatus:
          data.healthStatus.present
              ? data.healthStatus.value
              : this.healthStatus,
      lastCheckedAt:
          data.lastCheckedAt.present
              ? data.lastCheckedAt.value
              : this.lastCheckedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Source(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('group: $group, ')
          ..write('enabled: $enabled, ')
          ..write('comment: $comment, ')
          ..write('headersJson: $headersJson, ')
          ..write('rulesJson: $rulesJson, ')
          ..write('healthStatus: $healthStatus, ')
          ..write('lastCheckedAt: $lastCheckedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rawJson: $rawJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    baseUrl,
    group,
    enabled,
    comment,
    headersJson,
    rulesJson,
    healthStatus,
    lastCheckedAt,
    createdAt,
    updatedAt,
    rawJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Source &&
          other.id == this.id &&
          other.name == this.name &&
          other.baseUrl == this.baseUrl &&
          other.group == this.group &&
          other.enabled == this.enabled &&
          other.comment == this.comment &&
          other.headersJson == this.headersJson &&
          other.rulesJson == this.rulesJson &&
          other.healthStatus == this.healthStatus &&
          other.lastCheckedAt == this.lastCheckedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.rawJson == this.rawJson);
}

class SourcesCompanion extends UpdateCompanion<Source> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> baseUrl;
  final Value<String?> group;
  final Value<bool> enabled;
  final Value<String?> comment;
  final Value<String> headersJson;
  final Value<String> rulesJson;
  final Value<String> healthStatus;
  final Value<DateTime?> lastCheckedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> rawJson;
  final Value<int> rowid;
  const SourcesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.group = const Value.absent(),
    this.enabled = const Value.absent(),
    this.comment = const Value.absent(),
    this.headersJson = const Value.absent(),
    this.rulesJson = const Value.absent(),
    this.healthStatus = const Value.absent(),
    this.lastCheckedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SourcesCompanion.insert({
    required String id,
    required String name,
    required String baseUrl,
    this.group = const Value.absent(),
    this.enabled = const Value.absent(),
    this.comment = const Value.absent(),
    this.headersJson = const Value.absent(),
    this.rulesJson = const Value.absent(),
    this.healthStatus = const Value.absent(),
    this.lastCheckedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rawJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       baseUrl = Value(baseUrl);
  static Insertable<Source> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? baseUrl,
    Expression<String>? group,
    Expression<bool>? enabled,
    Expression<String>? comment,
    Expression<String>? headersJson,
    Expression<String>? rulesJson,
    Expression<String>? healthStatus,
    Expression<DateTime>? lastCheckedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? rawJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (baseUrl != null) 'base_url': baseUrl,
      if (group != null) 'group': group,
      if (enabled != null) 'enabled': enabled,
      if (comment != null) 'comment': comment,
      if (headersJson != null) 'headers_json': headersJson,
      if (rulesJson != null) 'rules_json': rulesJson,
      if (healthStatus != null) 'health_status': healthStatus,
      if (lastCheckedAt != null) 'last_checked_at': lastCheckedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rawJson != null) 'raw_json': rawJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SourcesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? baseUrl,
    Value<String?>? group,
    Value<bool>? enabled,
    Value<String?>? comment,
    Value<String>? headersJson,
    Value<String>? rulesJson,
    Value<String>? healthStatus,
    Value<DateTime?>? lastCheckedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? rawJson,
    Value<int>? rowid,
  }) {
    return SourcesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      group: group ?? this.group,
      enabled: enabled ?? this.enabled,
      comment: comment ?? this.comment,
      headersJson: headersJson ?? this.headersJson,
      rulesJson: rulesJson ?? this.rulesJson,
      healthStatus: healthStatus ?? this.healthStatus,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rawJson: rawJson ?? this.rawJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (group.present) {
      map['group'] = Variable<String>(group.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (headersJson.present) {
      map['headers_json'] = Variable<String>(headersJson.value);
    }
    if (rulesJson.present) {
      map['rules_json'] = Variable<String>(rulesJson.value);
    }
    if (healthStatus.present) {
      map['health_status'] = Variable<String>(healthStatus.value);
    }
    if (lastCheckedAt.present) {
      map['last_checked_at'] = Variable<DateTime>(lastCheckedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SourcesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('group: $group, ')
          ..write('enabled: $enabled, ')
          ..write('comment: $comment, ')
          ..write('headersJson: $headersJson, ')
          ..write('rulesJson: $rulesJson, ')
          ..write('healthStatus: $healthStatus, ')
          ..write('lastCheckedAt: $lastCheckedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rawJson: $rawJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChapterCachesTable extends ChapterCaches
    with TableInfo<$ChapterCachesTable, ChapterCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChapterCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIndexMeta = const VerificationMeta(
    'chapterIndex',
  );
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
    'chapter_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterTitleMeta = const VerificationMeta(
    'chapterTitle',
  );
  @override
  late final GeneratedColumn<String> chapterTitle = GeneratedColumn<String>(
    'chapter_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chapterUrlMeta = const VerificationMeta(
    'chapterUrl',
  );
  @override
  late final GeneratedColumn<String> chapterUrl = GeneratedColumn<String>(
    'chapter_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    cacheKey,
    bookId,
    sourceId,
    chapterIndex,
    chapterTitle,
    chapterUrl,
    content,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chapter_caches';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChapterCache> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('chapter_index')) {
      context.handle(
        _chapterIndexMeta,
        chapterIndex.isAcceptableOrUnknown(
          data['chapter_index']!,
          _chapterIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterIndexMeta);
    }
    if (data.containsKey('chapter_title')) {
      context.handle(
        _chapterTitleMeta,
        chapterTitle.isAcceptableOrUnknown(
          data['chapter_title']!,
          _chapterTitleMeta,
        ),
      );
    }
    if (data.containsKey('chapter_url')) {
      context.handle(
        _chapterUrlMeta,
        chapterUrl.isAcceptableOrUnknown(data['chapter_url']!, _chapterUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterUrlMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  ChapterCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChapterCache(
      cacheKey:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}cache_key'],
          )!,
      bookId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}book_id'],
          )!,
      sourceId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}source_id'],
          )!,
      chapterIndex:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}chapter_index'],
          )!,
      chapterTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_title'],
      ),
      chapterUrl:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}chapter_url'],
          )!,
      content:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}content'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $ChapterCachesTable createAlias(String alias) {
    return $ChapterCachesTable(attachedDatabase, alias);
  }
}

class ChapterCache extends DataClass implements Insertable<ChapterCache> {
  final String cacheKey;
  final String bookId;
  final String sourceId;
  final int chapterIndex;
  final String? chapterTitle;
  final String chapterUrl;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ChapterCache({
    required this.cacheKey,
    required this.bookId,
    required this.sourceId,
    required this.chapterIndex,
    this.chapterTitle,
    required this.chapterUrl,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['book_id'] = Variable<String>(bookId);
    map['source_id'] = Variable<String>(sourceId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    if (!nullToAbsent || chapterTitle != null) {
      map['chapter_title'] = Variable<String>(chapterTitle);
    }
    map['chapter_url'] = Variable<String>(chapterUrl);
    map['content'] = Variable<String>(content);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ChapterCachesCompanion toCompanion(bool nullToAbsent) {
    return ChapterCachesCompanion(
      cacheKey: Value(cacheKey),
      bookId: Value(bookId),
      sourceId: Value(sourceId),
      chapterIndex: Value(chapterIndex),
      chapterTitle:
          chapterTitle == null && nullToAbsent
              ? const Value.absent()
              : Value(chapterTitle),
      chapterUrl: Value(chapterUrl),
      content: Value(content),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ChapterCache.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChapterCache(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      bookId: serializer.fromJson<String>(json['bookId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      chapterTitle: serializer.fromJson<String?>(json['chapterTitle']),
      chapterUrl: serializer.fromJson<String>(json['chapterUrl']),
      content: serializer.fromJson<String>(json['content']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'bookId': serializer.toJson<String>(bookId),
      'sourceId': serializer.toJson<String>(sourceId),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'chapterTitle': serializer.toJson<String?>(chapterTitle),
      'chapterUrl': serializer.toJson<String>(chapterUrl),
      'content': serializer.toJson<String>(content),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ChapterCache copyWith({
    String? cacheKey,
    String? bookId,
    String? sourceId,
    int? chapterIndex,
    Value<String?> chapterTitle = const Value.absent(),
    String? chapterUrl,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ChapterCache(
    cacheKey: cacheKey ?? this.cacheKey,
    bookId: bookId ?? this.bookId,
    sourceId: sourceId ?? this.sourceId,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    chapterTitle: chapterTitle.present ? chapterTitle.value : this.chapterTitle,
    chapterUrl: chapterUrl ?? this.chapterUrl,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ChapterCache copyWithCompanion(ChapterCachesCompanion data) {
    return ChapterCache(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      chapterIndex:
          data.chapterIndex.present
              ? data.chapterIndex.value
              : this.chapterIndex,
      chapterTitle:
          data.chapterTitle.present
              ? data.chapterTitle.value
              : this.chapterTitle,
      chapterUrl:
          data.chapterUrl.present ? data.chapterUrl.value : this.chapterUrl,
      content: data.content.present ? data.content.value : this.content,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChapterCache(')
          ..write('cacheKey: $cacheKey, ')
          ..write('bookId: $bookId, ')
          ..write('sourceId: $sourceId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('chapterTitle: $chapterTitle, ')
          ..write('chapterUrl: $chapterUrl, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    cacheKey,
    bookId,
    sourceId,
    chapterIndex,
    chapterTitle,
    chapterUrl,
    content,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChapterCache &&
          other.cacheKey == this.cacheKey &&
          other.bookId == this.bookId &&
          other.sourceId == this.sourceId &&
          other.chapterIndex == this.chapterIndex &&
          other.chapterTitle == this.chapterTitle &&
          other.chapterUrl == this.chapterUrl &&
          other.content == this.content &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ChapterCachesCompanion extends UpdateCompanion<ChapterCache> {
  final Value<String> cacheKey;
  final Value<String> bookId;
  final Value<String> sourceId;
  final Value<int> chapterIndex;
  final Value<String?> chapterTitle;
  final Value<String> chapterUrl;
  final Value<String> content;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ChapterCachesCompanion({
    this.cacheKey = const Value.absent(),
    this.bookId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.chapterTitle = const Value.absent(),
    this.chapterUrl = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChapterCachesCompanion.insert({
    required String cacheKey,
    required String bookId,
    required String sourceId,
    required int chapterIndex,
    this.chapterTitle = const Value.absent(),
    required String chapterUrl,
    required String content,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       bookId = Value(bookId),
       sourceId = Value(sourceId),
       chapterIndex = Value(chapterIndex),
       chapterUrl = Value(chapterUrl),
       content = Value(content);
  static Insertable<ChapterCache> custom({
    Expression<String>? cacheKey,
    Expression<String>? bookId,
    Expression<String>? sourceId,
    Expression<int>? chapterIndex,
    Expression<String>? chapterTitle,
    Expression<String>? chapterUrl,
    Expression<String>? content,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (bookId != null) 'book_id': bookId,
      if (sourceId != null) 'source_id': sourceId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (chapterTitle != null) 'chapter_title': chapterTitle,
      if (chapterUrl != null) 'chapter_url': chapterUrl,
      if (content != null) 'content': content,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChapterCachesCompanion copyWith({
    Value<String>? cacheKey,
    Value<String>? bookId,
    Value<String>? sourceId,
    Value<int>? chapterIndex,
    Value<String?>? chapterTitle,
    Value<String>? chapterUrl,
    Value<String>? content,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ChapterCachesCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      bookId: bookId ?? this.bookId,
      sourceId: sourceId ?? this.sourceId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      chapterUrl: chapterUrl ?? this.chapterUrl,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (chapterTitle.present) {
      map['chapter_title'] = Variable<String>(chapterTitle.value);
    }
    if (chapterUrl.present) {
      map['chapter_url'] = Variable<String>(chapterUrl.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChapterCachesCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('bookId: $bookId, ')
          ..write('sourceId: $sourceId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('chapterTitle: $chapterTitle, ')
          ..write('chapterUrl: $chapterUrl, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SourcesTable sources = $SourcesTable(this);
  late final $ChapterCachesTable chapterCaches = $ChapterCachesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [sources, chapterCaches];
}

typedef $$SourcesTableCreateCompanionBuilder =
    SourcesCompanion Function({
      required String id,
      required String name,
      required String baseUrl,
      Value<String?> group,
      Value<bool> enabled,
      Value<String?> comment,
      Value<String> headersJson,
      Value<String> rulesJson,
      Value<String> healthStatus,
      Value<DateTime?> lastCheckedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String> rawJson,
      Value<int> rowid,
    });
typedef $$SourcesTableUpdateCompanionBuilder =
    SourcesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> baseUrl,
      Value<String?> group,
      Value<bool> enabled,
      Value<String?> comment,
      Value<String> headersJson,
      Value<String> rulesJson,
      Value<String> healthStatus,
      Value<DateTime?> lastCheckedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String> rawJson,
      Value<int> rowid,
    });

class $$SourcesTableFilterComposer
    extends Composer<_$AppDatabase, $SourcesTable> {
  $$SourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get group => $composableBuilder(
    column: $table.group,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get headersJson => $composableBuilder(
    column: $table.headersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rulesJson => $composableBuilder(
    column: $table.rulesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get healthStatus => $composableBuilder(
    column: $table.healthStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastCheckedAt => $composableBuilder(
    column: $table.lastCheckedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $SourcesTable> {
  $$SourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get group => $composableBuilder(
    column: $table.group,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headersJson => $composableBuilder(
    column: $table.headersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rulesJson => $composableBuilder(
    column: $table.rulesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get healthStatus => $composableBuilder(
    column: $table.healthStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastCheckedAt => $composableBuilder(
    column: $table.lastCheckedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawJson => $composableBuilder(
    column: $table.rawJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SourcesTable> {
  $$SourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get group =>
      $composableBuilder(column: $table.group, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<String> get headersJson => $composableBuilder(
    column: $table.headersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rulesJson =>
      $composableBuilder(column: $table.rulesJson, builder: (column) => column);

  GeneratedColumn<String> get healthStatus => $composableBuilder(
    column: $table.healthStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastCheckedAt => $composableBuilder(
    column: $table.lastCheckedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);
}

class $$SourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SourcesTable,
          Source,
          $$SourcesTableFilterComposer,
          $$SourcesTableOrderingComposer,
          $$SourcesTableAnnotationComposer,
          $$SourcesTableCreateCompanionBuilder,
          $$SourcesTableUpdateCompanionBuilder,
          (Source, BaseReferences<_$AppDatabase, $SourcesTable, Source>),
          Source,
          PrefetchHooks Function()
        > {
  $$SourcesTableTableManager(_$AppDatabase db, $SourcesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$SourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$SourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$SourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<String?> group = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<String> headersJson = const Value.absent(),
                Value<String> rulesJson = const Value.absent(),
                Value<String> healthStatus = const Value.absent(),
                Value<DateTime?> lastCheckedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> rawJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourcesCompanion(
                id: id,
                name: name,
                baseUrl: baseUrl,
                group: group,
                enabled: enabled,
                comment: comment,
                headersJson: headersJson,
                rulesJson: rulesJson,
                healthStatus: healthStatus,
                lastCheckedAt: lastCheckedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rawJson: rawJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String baseUrl,
                Value<String?> group = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<String> headersJson = const Value.absent(),
                Value<String> rulesJson = const Value.absent(),
                Value<String> healthStatus = const Value.absent(),
                Value<DateTime?> lastCheckedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> rawJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourcesCompanion.insert(
                id: id,
                name: name,
                baseUrl: baseUrl,
                group: group,
                enabled: enabled,
                comment: comment,
                headersJson: headersJson,
                rulesJson: rulesJson,
                healthStatus: healthStatus,
                lastCheckedAt: lastCheckedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rawJson: rawJson,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SourcesTable,
      Source,
      $$SourcesTableFilterComposer,
      $$SourcesTableOrderingComposer,
      $$SourcesTableAnnotationComposer,
      $$SourcesTableCreateCompanionBuilder,
      $$SourcesTableUpdateCompanionBuilder,
      (Source, BaseReferences<_$AppDatabase, $SourcesTable, Source>),
      Source,
      PrefetchHooks Function()
    >;
typedef $$ChapterCachesTableCreateCompanionBuilder =
    ChapterCachesCompanion Function({
      required String cacheKey,
      required String bookId,
      required String sourceId,
      required int chapterIndex,
      Value<String?> chapterTitle,
      required String chapterUrl,
      required String content,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$ChapterCachesTableUpdateCompanionBuilder =
    ChapterCachesCompanion Function({
      Value<String> cacheKey,
      Value<String> bookId,
      Value<String> sourceId,
      Value<int> chapterIndex,
      Value<String?> chapterTitle,
      Value<String> chapterUrl,
      Value<String> content,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ChapterCachesTableFilterComposer
    extends Composer<_$AppDatabase, $ChapterCachesTable> {
  $$ChapterCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterTitle => $composableBuilder(
    column: $table.chapterTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterUrl => $composableBuilder(
    column: $table.chapterUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChapterCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $ChapterCachesTable> {
  $$ChapterCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterTitle => $composableBuilder(
    column: $table.chapterTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterUrl => $composableBuilder(
    column: $table.chapterUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChapterCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChapterCachesTable> {
  $$ChapterCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chapterTitle => $composableBuilder(
    column: $table.chapterTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chapterUrl => $composableBuilder(
    column: $table.chapterUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ChapterCachesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChapterCachesTable,
          ChapterCache,
          $$ChapterCachesTableFilterComposer,
          $$ChapterCachesTableOrderingComposer,
          $$ChapterCachesTableAnnotationComposer,
          $$ChapterCachesTableCreateCompanionBuilder,
          $$ChapterCachesTableUpdateCompanionBuilder,
          (
            ChapterCache,
            BaseReferences<_$AppDatabase, $ChapterCachesTable, ChapterCache>,
          ),
          ChapterCache,
          PrefetchHooks Function()
        > {
  $$ChapterCachesTableTableManager(_$AppDatabase db, $ChapterCachesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ChapterCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$ChapterCachesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$ChapterCachesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> cacheKey = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<String?> chapterTitle = const Value.absent(),
                Value<String> chapterUrl = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChapterCachesCompanion(
                cacheKey: cacheKey,
                bookId: bookId,
                sourceId: sourceId,
                chapterIndex: chapterIndex,
                chapterTitle: chapterTitle,
                chapterUrl: chapterUrl,
                content: content,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                required String bookId,
                required String sourceId,
                required int chapterIndex,
                Value<String?> chapterTitle = const Value.absent(),
                required String chapterUrl,
                required String content,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChapterCachesCompanion.insert(
                cacheKey: cacheKey,
                bookId: bookId,
                sourceId: sourceId,
                chapterIndex: chapterIndex,
                chapterTitle: chapterTitle,
                chapterUrl: chapterUrl,
                content: content,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChapterCachesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChapterCachesTable,
      ChapterCache,
      $$ChapterCachesTableFilterComposer,
      $$ChapterCachesTableOrderingComposer,
      $$ChapterCachesTableAnnotationComposer,
      $$ChapterCachesTableCreateCompanionBuilder,
      $$ChapterCachesTableUpdateCompanionBuilder,
      (
        ChapterCache,
        BaseReferences<_$AppDatabase, $ChapterCachesTable, ChapterCache>,
      ),
      ChapterCache,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db, _db.sources);
  $$ChapterCachesTableTableManager get chapterCaches =>
      $$ChapterCachesTableTableManager(_db, _db.chapterCaches);
}
