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

class $StoredLocalBooksTable extends StoredLocalBooks
    with TableInfo<$StoredLocalBooksTable, StoredLocalBook> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredLocalBooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storagePathMeta = const VerificationMeta(
    'storagePath',
  );
  @override
  late final GeneratedColumn<String> storagePath = GeneratedColumn<String>(
    'storage_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourcePathMeta = const VerificationMeta(
    'sourcePath',
  );
  @override
  late final GeneratedColumn<String> sourcePath = GeneratedColumn<String>(
    'source_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _indexStatusMeta = const VerificationMeta(
    'indexStatus',
  );
  @override
  late final GeneratedColumn<String> indexStatus = GeneratedColumn<String>(
    'index_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _chapterCountMeta = const VerificationMeta(
    'chapterCount',
  );
  @override
  late final GeneratedColumn<int> chapterCount = GeneratedColumn<int>(
    'chapter_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    format,
    storagePath,
    sourcePath,
    fileSize,
    author,
    coverPath,
    indexStatus,
    chapterCount,
    lastError,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_books';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredLocalBook> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('storage_path')) {
      context.handle(
        _storagePathMeta,
        storagePath.isAcceptableOrUnknown(
          data['storage_path']!,
          _storagePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_storagePathMeta);
    }
    if (data.containsKey('source_path')) {
      context.handle(
        _sourcePathMeta,
        sourcePath.isAcceptableOrUnknown(data['source_path']!, _sourcePathMeta),
      );
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_fileSizeMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('index_status')) {
      context.handle(
        _indexStatusMeta,
        indexStatus.isAcceptableOrUnknown(
          data['index_status']!,
          _indexStatusMeta,
        ),
      );
    }
    if (data.containsKey('chapter_count')) {
      context.handle(
        _chapterCountMeta,
        chapterCount.isAcceptableOrUnknown(
          data['chapter_count']!,
          _chapterCountMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredLocalBook map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredLocalBook(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      title:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}title'],
          )!,
      format:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}format'],
          )!,
      storagePath:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}storage_path'],
          )!,
      sourcePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_path'],
      ),
      fileSize:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}file_size'],
          )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      indexStatus:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}index_status'],
          )!,
      chapterCount:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}chapter_count'],
          )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
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
    );
  }

  @override
  $StoredLocalBooksTable createAlias(String alias) {
    return $StoredLocalBooksTable(attachedDatabase, alias);
  }
}

class StoredLocalBook extends DataClass implements Insertable<StoredLocalBook> {
  final String id;
  final String title;
  final String format;
  final String storagePath;
  final String? sourcePath;
  final int fileSize;
  final String? author;
  final String? coverPath;
  final String indexStatus;
  final int chapterCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;
  const StoredLocalBook({
    required this.id,
    required this.title,
    required this.format,
    required this.storagePath,
    this.sourcePath,
    required this.fileSize,
    this.author,
    this.coverPath,
    required this.indexStatus,
    required this.chapterCount,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['format'] = Variable<String>(format);
    map['storage_path'] = Variable<String>(storagePath);
    if (!nullToAbsent || sourcePath != null) {
      map['source_path'] = Variable<String>(sourcePath);
    }
    map['file_size'] = Variable<int>(fileSize);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    map['index_status'] = Variable<String>(indexStatus);
    map['chapter_count'] = Variable<int>(chapterCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StoredLocalBooksCompanion toCompanion(bool nullToAbsent) {
    return StoredLocalBooksCompanion(
      id: Value(id),
      title: Value(title),
      format: Value(format),
      storagePath: Value(storagePath),
      sourcePath:
          sourcePath == null && nullToAbsent
              ? const Value.absent()
              : Value(sourcePath),
      fileSize: Value(fileSize),
      author:
          author == null && nullToAbsent ? const Value.absent() : Value(author),
      coverPath:
          coverPath == null && nullToAbsent
              ? const Value.absent()
              : Value(coverPath),
      indexStatus: Value(indexStatus),
      chapterCount: Value(chapterCount),
      lastError:
          lastError == null && nullToAbsent
              ? const Value.absent()
              : Value(lastError),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredLocalBook.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredLocalBook(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      format: serializer.fromJson<String>(json['format']),
      storagePath: serializer.fromJson<String>(json['storagePath']),
      sourcePath: serializer.fromJson<String?>(json['sourcePath']),
      fileSize: serializer.fromJson<int>(json['fileSize']),
      author: serializer.fromJson<String?>(json['author']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      indexStatus: serializer.fromJson<String>(json['indexStatus']),
      chapterCount: serializer.fromJson<int>(json['chapterCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'format': serializer.toJson<String>(format),
      'storagePath': serializer.toJson<String>(storagePath),
      'sourcePath': serializer.toJson<String?>(sourcePath),
      'fileSize': serializer.toJson<int>(fileSize),
      'author': serializer.toJson<String?>(author),
      'coverPath': serializer.toJson<String?>(coverPath),
      'indexStatus': serializer.toJson<String>(indexStatus),
      'chapterCount': serializer.toJson<int>(chapterCount),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredLocalBook copyWith({
    String? id,
    String? title,
    String? format,
    String? storagePath,
    Value<String?> sourcePath = const Value.absent(),
    int? fileSize,
    Value<String?> author = const Value.absent(),
    Value<String?> coverPath = const Value.absent(),
    String? indexStatus,
    int? chapterCount,
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StoredLocalBook(
    id: id ?? this.id,
    title: title ?? this.title,
    format: format ?? this.format,
    storagePath: storagePath ?? this.storagePath,
    sourcePath: sourcePath.present ? sourcePath.value : this.sourcePath,
    fileSize: fileSize ?? this.fileSize,
    author: author.present ? author.value : this.author,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    indexStatus: indexStatus ?? this.indexStatus,
    chapterCount: chapterCount ?? this.chapterCount,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredLocalBook copyWithCompanion(StoredLocalBooksCompanion data) {
    return StoredLocalBook(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      format: data.format.present ? data.format.value : this.format,
      storagePath:
          data.storagePath.present ? data.storagePath.value : this.storagePath,
      sourcePath:
          data.sourcePath.present ? data.sourcePath.value : this.sourcePath,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      author: data.author.present ? data.author.value : this.author,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      indexStatus:
          data.indexStatus.present ? data.indexStatus.value : this.indexStatus,
      chapterCount:
          data.chapterCount.present
              ? data.chapterCount.value
              : this.chapterCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredLocalBook(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('format: $format, ')
          ..write('storagePath: $storagePath, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('fileSize: $fileSize, ')
          ..write('author: $author, ')
          ..write('coverPath: $coverPath, ')
          ..write('indexStatus: $indexStatus, ')
          ..write('chapterCount: $chapterCount, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    format,
    storagePath,
    sourcePath,
    fileSize,
    author,
    coverPath,
    indexStatus,
    chapterCount,
    lastError,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredLocalBook &&
          other.id == this.id &&
          other.title == this.title &&
          other.format == this.format &&
          other.storagePath == this.storagePath &&
          other.sourcePath == this.sourcePath &&
          other.fileSize == this.fileSize &&
          other.author == this.author &&
          other.coverPath == this.coverPath &&
          other.indexStatus == this.indexStatus &&
          other.chapterCount == this.chapterCount &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class StoredLocalBooksCompanion extends UpdateCompanion<StoredLocalBook> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> format;
  final Value<String> storagePath;
  final Value<String?> sourcePath;
  final Value<int> fileSize;
  final Value<String?> author;
  final Value<String?> coverPath;
  final Value<String> indexStatus;
  final Value<int> chapterCount;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StoredLocalBooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.format = const Value.absent(),
    this.storagePath = const Value.absent(),
    this.sourcePath = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.author = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.indexStatus = const Value.absent(),
    this.chapterCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredLocalBooksCompanion.insert({
    required String id,
    required String title,
    required String format,
    required String storagePath,
    this.sourcePath = const Value.absent(),
    required int fileSize,
    this.author = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.indexStatus = const Value.absent(),
    this.chapterCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       format = Value(format),
       storagePath = Value(storagePath),
       fileSize = Value(fileSize);
  static Insertable<StoredLocalBook> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? format,
    Expression<String>? storagePath,
    Expression<String>? sourcePath,
    Expression<int>? fileSize,
    Expression<String>? author,
    Expression<String>? coverPath,
    Expression<String>? indexStatus,
    Expression<int>? chapterCount,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (format != null) 'format': format,
      if (storagePath != null) 'storage_path': storagePath,
      if (sourcePath != null) 'source_path': sourcePath,
      if (fileSize != null) 'file_size': fileSize,
      if (author != null) 'author': author,
      if (coverPath != null) 'cover_path': coverPath,
      if (indexStatus != null) 'index_status': indexStatus,
      if (chapterCount != null) 'chapter_count': chapterCount,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredLocalBooksCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? format,
    Value<String>? storagePath,
    Value<String?>? sourcePath,
    Value<int>? fileSize,
    Value<String?>? author,
    Value<String?>? coverPath,
    Value<String>? indexStatus,
    Value<int>? chapterCount,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StoredLocalBooksCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      format: format ?? this.format,
      storagePath: storagePath ?? this.storagePath,
      sourcePath: sourcePath ?? this.sourcePath,
      fileSize: fileSize ?? this.fileSize,
      author: author ?? this.author,
      coverPath: coverPath ?? this.coverPath,
      indexStatus: indexStatus ?? this.indexStatus,
      chapterCount: chapterCount ?? this.chapterCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (storagePath.present) {
      map['storage_path'] = Variable<String>(storagePath.value);
    }
    if (sourcePath.present) {
      map['source_path'] = Variable<String>(sourcePath.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (indexStatus.present) {
      map['index_status'] = Variable<String>(indexStatus.value);
    }
    if (chapterCount.present) {
      map['chapter_count'] = Variable<int>(chapterCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
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
    return (StringBuffer('StoredLocalBooksCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('format: $format, ')
          ..write('storagePath: $storagePath, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('fileSize: $fileSize, ')
          ..write('author: $author, ')
          ..write('coverPath: $coverPath, ')
          ..write('indexStatus: $indexStatus, ')
          ..write('chapterCount: $chapterCount, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredLocalChaptersTable extends StoredLocalChapters
    with TableInfo<$StoredLocalChaptersTable, StoredLocalChapter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredLocalChaptersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
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
  static const VerificationMeta _startOffsetMeta = const VerificationMeta(
    'startOffset',
  );
  @override
  late final GeneratedColumn<int> startOffset = GeneratedColumn<int>(
    'start_offset',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endOffsetMeta = const VerificationMeta(
    'endOffset',
  );
  @override
  late final GeneratedColumn<int> endOffset = GeneratedColumn<int>(
    'end_offset',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    chapterIndex,
    title,
    content,
    startOffset,
    endOffset,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_chapters';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredLocalChapter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
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
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('start_offset')) {
      context.handle(
        _startOffsetMeta,
        startOffset.isAcceptableOrUnknown(
          data['start_offset']!,
          _startOffsetMeta,
        ),
      );
    }
    if (data.containsKey('end_offset')) {
      context.handle(
        _endOffsetMeta,
        endOffset.isAcceptableOrUnknown(data['end_offset']!, _endOffsetMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {bookId, chapterIndex},
  ];
  @override
  StoredLocalChapter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredLocalChapter(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      bookId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}book_id'],
          )!,
      chapterIndex:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}chapter_index'],
          )!,
      title:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}title'],
          )!,
      content:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}content'],
          )!,
      startOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_offset'],
      ),
      endOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_offset'],
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
    );
  }

  @override
  $StoredLocalChaptersTable createAlias(String alias) {
    return $StoredLocalChaptersTable(attachedDatabase, alias);
  }
}

class StoredLocalChapter extends DataClass
    implements Insertable<StoredLocalChapter> {
  final String id;
  final String bookId;
  final int chapterIndex;
  final String title;
  final String content;
  final int? startOffset;
  final int? endOffset;
  final DateTime createdAt;
  final DateTime updatedAt;
  const StoredLocalChapter({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.title,
    required this.content,
    this.startOffset,
    this.endOffset,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || startOffset != null) {
      map['start_offset'] = Variable<int>(startOffset);
    }
    if (!nullToAbsent || endOffset != null) {
      map['end_offset'] = Variable<int>(endOffset);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StoredLocalChaptersCompanion toCompanion(bool nullToAbsent) {
    return StoredLocalChaptersCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapterIndex: Value(chapterIndex),
      title: Value(title),
      content: Value(content),
      startOffset:
          startOffset == null && nullToAbsent
              ? const Value.absent()
              : Value(startOffset),
      endOffset:
          endOffset == null && nullToAbsent
              ? const Value.absent()
              : Value(endOffset),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredLocalChapter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredLocalChapter(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      startOffset: serializer.fromJson<int?>(json['startOffset']),
      endOffset: serializer.fromJson<int?>(json['endOffset']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'startOffset': serializer.toJson<int?>(startOffset),
      'endOffset': serializer.toJson<int?>(endOffset),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredLocalChapter copyWith({
    String? id,
    String? bookId,
    int? chapterIndex,
    String? title,
    String? content,
    Value<int?> startOffset = const Value.absent(),
    Value<int?> endOffset = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StoredLocalChapter(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    title: title ?? this.title,
    content: content ?? this.content,
    startOffset: startOffset.present ? startOffset.value : this.startOffset,
    endOffset: endOffset.present ? endOffset.value : this.endOffset,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredLocalChapter copyWithCompanion(StoredLocalChaptersCompanion data) {
    return StoredLocalChapter(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterIndex:
          data.chapterIndex.present
              ? data.chapterIndex.value
              : this.chapterIndex,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      startOffset:
          data.startOffset.present ? data.startOffset.value : this.startOffset,
      endOffset: data.endOffset.present ? data.endOffset.value : this.endOffset,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredLocalChapter(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    chapterIndex,
    title,
    content,
    startOffset,
    endOffset,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredLocalChapter &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.chapterIndex == this.chapterIndex &&
          other.title == this.title &&
          other.content == this.content &&
          other.startOffset == this.startOffset &&
          other.endOffset == this.endOffset &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class StoredLocalChaptersCompanion extends UpdateCompanion<StoredLocalChapter> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<int> chapterIndex;
  final Value<String> title;
  final Value<String> content;
  final Value<int?> startOffset;
  final Value<int?> endOffset;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StoredLocalChaptersCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.startOffset = const Value.absent(),
    this.endOffset = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredLocalChaptersCompanion.insert({
    required String id,
    required String bookId,
    required int chapterIndex,
    required String title,
    required String content,
    this.startOffset = const Value.absent(),
    this.endOffset = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       chapterIndex = Value(chapterIndex),
       title = Value(title),
       content = Value(content);
  static Insertable<StoredLocalChapter> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<int>? chapterIndex,
    Expression<String>? title,
    Expression<String>? content,
    Expression<int>? startOffset,
    Expression<int>? endOffset,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (startOffset != null) 'start_offset': startOffset,
      if (endOffset != null) 'end_offset': endOffset,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredLocalChaptersCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<int>? chapterIndex,
    Value<String>? title,
    Value<String>? content,
    Value<int?>? startOffset,
    Value<int?>? endOffset,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StoredLocalChaptersCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      title: title ?? this.title,
      content: content ?? this.content,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (startOffset.present) {
      map['start_offset'] = Variable<int>(startOffset.value);
    }
    if (endOffset.present) {
      map['end_offset'] = Variable<int>(endOffset.value);
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
    return (StringBuffer('StoredLocalChaptersCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SearchSourceHitsTable extends SearchSourceHits
    with TableInfo<$SearchSourceHitsTable, SearchSourceHit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchSourceHitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _titleNormMeta = const VerificationMeta(
    'titleNorm',
  );
  @override
  late final GeneratedColumn<String> titleNorm = GeneratedColumn<String>(
    'title_norm',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorNormMeta = const VerificationMeta(
    'authorNorm',
  );
  @override
  late final GeneratedColumn<String> authorNorm = GeneratedColumn<String>(
    'author_norm',
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
  static const VerificationMeta _sourceNameMeta = const VerificationMeta(
    'sourceName',
  );
  @override
  late final GeneratedColumn<String> sourceName = GeneratedColumn<String>(
    'source_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latestChapterMeta = const VerificationMeta(
    'latestChapter',
  );
  @override
  late final GeneratedColumn<String> latestChapter = GeneratedColumn<String>(
    'latest_chapter',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latestChapterNoMeta = const VerificationMeta(
    'latestChapterNo',
  );
  @override
  late final GeneratedColumn<int> latestChapterNo = GeneratedColumn<int>(
    'latest_chapter_no',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hitCountMeta = const VerificationMeta(
    'hitCount',
  );
  @override
  late final GeneratedColumn<int> hitCount = GeneratedColumn<int>(
    'hit_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastHitAtMeta = const VerificationMeta(
    'lastHitAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastHitAt = GeneratedColumn<DateTime>(
    'last_hit_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
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
    titleNorm,
    authorNorm,
    sourceId,
    sourceName,
    title,
    author,
    latestChapter,
    latestChapterNo,
    hitCount,
    lastHitAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_source_hits';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchSourceHit> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('title_norm')) {
      context.handle(
        _titleNormMeta,
        titleNorm.isAcceptableOrUnknown(data['title_norm']!, _titleNormMeta),
      );
    } else if (isInserting) {
      context.missing(_titleNormMeta);
    }
    if (data.containsKey('author_norm')) {
      context.handle(
        _authorNormMeta,
        authorNorm.isAcceptableOrUnknown(data['author_norm']!, _authorNormMeta),
      );
    } else if (isInserting) {
      context.missing(_authorNormMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('source_name')) {
      context.handle(
        _sourceNameMeta,
        sourceName.isAcceptableOrUnknown(data['source_name']!, _sourceNameMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('latest_chapter')) {
      context.handle(
        _latestChapterMeta,
        latestChapter.isAcceptableOrUnknown(
          data['latest_chapter']!,
          _latestChapterMeta,
        ),
      );
    }
    if (data.containsKey('latest_chapter_no')) {
      context.handle(
        _latestChapterNoMeta,
        latestChapterNo.isAcceptableOrUnknown(
          data['latest_chapter_no']!,
          _latestChapterNoMeta,
        ),
      );
    }
    if (data.containsKey('hit_count')) {
      context.handle(
        _hitCountMeta,
        hitCount.isAcceptableOrUnknown(data['hit_count']!, _hitCountMeta),
      );
    }
    if (data.containsKey('last_hit_at')) {
      context.handle(
        _lastHitAtMeta,
        lastHitAt.isAcceptableOrUnknown(data['last_hit_at']!, _lastHitAtMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {titleNorm, authorNorm, sourceId};
  @override
  SearchSourceHit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchSourceHit(
      titleNorm:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}title_norm'],
          )!,
      authorNorm:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}author_norm'],
          )!,
      sourceId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}source_id'],
          )!,
      sourceName:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}source_name'],
          )!,
      title:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}title'],
          )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      latestChapter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}latest_chapter'],
      ),
      latestChapterNo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}latest_chapter_no'],
      ),
      hitCount:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}hit_count'],
          )!,
      lastHitAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}last_hit_at'],
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
  $SearchSourceHitsTable createAlias(String alias) {
    return $SearchSourceHitsTable(attachedDatabase, alias);
  }
}

class SearchSourceHit extends DataClass implements Insertable<SearchSourceHit> {
  final String titleNorm;
  final String authorNorm;
  final String sourceId;
  final String sourceName;
  final String title;
  final String? author;
  final String? latestChapter;
  final int? latestChapterNo;
  final int hitCount;
  final DateTime lastHitAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SearchSourceHit({
    required this.titleNorm,
    required this.authorNorm,
    required this.sourceId,
    required this.sourceName,
    required this.title,
    this.author,
    this.latestChapter,
    this.latestChapterNo,
    required this.hitCount,
    required this.lastHitAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['title_norm'] = Variable<String>(titleNorm);
    map['author_norm'] = Variable<String>(authorNorm);
    map['source_id'] = Variable<String>(sourceId);
    map['source_name'] = Variable<String>(sourceName);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || latestChapter != null) {
      map['latest_chapter'] = Variable<String>(latestChapter);
    }
    if (!nullToAbsent || latestChapterNo != null) {
      map['latest_chapter_no'] = Variable<int>(latestChapterNo);
    }
    map['hit_count'] = Variable<int>(hitCount);
    map['last_hit_at'] = Variable<DateTime>(lastHitAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SearchSourceHitsCompanion toCompanion(bool nullToAbsent) {
    return SearchSourceHitsCompanion(
      titleNorm: Value(titleNorm),
      authorNorm: Value(authorNorm),
      sourceId: Value(sourceId),
      sourceName: Value(sourceName),
      title: Value(title),
      author:
          author == null && nullToAbsent ? const Value.absent() : Value(author),
      latestChapter:
          latestChapter == null && nullToAbsent
              ? const Value.absent()
              : Value(latestChapter),
      latestChapterNo:
          latestChapterNo == null && nullToAbsent
              ? const Value.absent()
              : Value(latestChapterNo),
      hitCount: Value(hitCount),
      lastHitAt: Value(lastHitAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SearchSourceHit.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchSourceHit(
      titleNorm: serializer.fromJson<String>(json['titleNorm']),
      authorNorm: serializer.fromJson<String>(json['authorNorm']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      sourceName: serializer.fromJson<String>(json['sourceName']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      latestChapter: serializer.fromJson<String?>(json['latestChapter']),
      latestChapterNo: serializer.fromJson<int?>(json['latestChapterNo']),
      hitCount: serializer.fromJson<int>(json['hitCount']),
      lastHitAt: serializer.fromJson<DateTime>(json['lastHitAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'titleNorm': serializer.toJson<String>(titleNorm),
      'authorNorm': serializer.toJson<String>(authorNorm),
      'sourceId': serializer.toJson<String>(sourceId),
      'sourceName': serializer.toJson<String>(sourceName),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String?>(author),
      'latestChapter': serializer.toJson<String?>(latestChapter),
      'latestChapterNo': serializer.toJson<int?>(latestChapterNo),
      'hitCount': serializer.toJson<int>(hitCount),
      'lastHitAt': serializer.toJson<DateTime>(lastHitAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SearchSourceHit copyWith({
    String? titleNorm,
    String? authorNorm,
    String? sourceId,
    String? sourceName,
    String? title,
    Value<String?> author = const Value.absent(),
    Value<String?> latestChapter = const Value.absent(),
    Value<int?> latestChapterNo = const Value.absent(),
    int? hitCount,
    DateTime? lastHitAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SearchSourceHit(
    titleNorm: titleNorm ?? this.titleNorm,
    authorNorm: authorNorm ?? this.authorNorm,
    sourceId: sourceId ?? this.sourceId,
    sourceName: sourceName ?? this.sourceName,
    title: title ?? this.title,
    author: author.present ? author.value : this.author,
    latestChapter:
        latestChapter.present ? latestChapter.value : this.latestChapter,
    latestChapterNo:
        latestChapterNo.present ? latestChapterNo.value : this.latestChapterNo,
    hitCount: hitCount ?? this.hitCount,
    lastHitAt: lastHitAt ?? this.lastHitAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SearchSourceHit copyWithCompanion(SearchSourceHitsCompanion data) {
    return SearchSourceHit(
      titleNorm: data.titleNorm.present ? data.titleNorm.value : this.titleNorm,
      authorNorm:
          data.authorNorm.present ? data.authorNorm.value : this.authorNorm,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      sourceName:
          data.sourceName.present ? data.sourceName.value : this.sourceName,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      latestChapter:
          data.latestChapter.present
              ? data.latestChapter.value
              : this.latestChapter,
      latestChapterNo:
          data.latestChapterNo.present
              ? data.latestChapterNo.value
              : this.latestChapterNo,
      hitCount: data.hitCount.present ? data.hitCount.value : this.hitCount,
      lastHitAt: data.lastHitAt.present ? data.lastHitAt.value : this.lastHitAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchSourceHit(')
          ..write('titleNorm: $titleNorm, ')
          ..write('authorNorm: $authorNorm, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceName: $sourceName, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('latestChapter: $latestChapter, ')
          ..write('latestChapterNo: $latestChapterNo, ')
          ..write('hitCount: $hitCount, ')
          ..write('lastHitAt: $lastHitAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    titleNorm,
    authorNorm,
    sourceId,
    sourceName,
    title,
    author,
    latestChapter,
    latestChapterNo,
    hitCount,
    lastHitAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchSourceHit &&
          other.titleNorm == this.titleNorm &&
          other.authorNorm == this.authorNorm &&
          other.sourceId == this.sourceId &&
          other.sourceName == this.sourceName &&
          other.title == this.title &&
          other.author == this.author &&
          other.latestChapter == this.latestChapter &&
          other.latestChapterNo == this.latestChapterNo &&
          other.hitCount == this.hitCount &&
          other.lastHitAt == this.lastHitAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SearchSourceHitsCompanion extends UpdateCompanion<SearchSourceHit> {
  final Value<String> titleNorm;
  final Value<String> authorNorm;
  final Value<String> sourceId;
  final Value<String> sourceName;
  final Value<String> title;
  final Value<String?> author;
  final Value<String?> latestChapter;
  final Value<int?> latestChapterNo;
  final Value<int> hitCount;
  final Value<DateTime> lastHitAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SearchSourceHitsCompanion({
    this.titleNorm = const Value.absent(),
    this.authorNorm = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.sourceName = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.latestChapter = const Value.absent(),
    this.latestChapterNo = const Value.absent(),
    this.hitCount = const Value.absent(),
    this.lastHitAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchSourceHitsCompanion.insert({
    required String titleNorm,
    required String authorNorm,
    required String sourceId,
    this.sourceName = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.latestChapter = const Value.absent(),
    this.latestChapterNo = const Value.absent(),
    this.hitCount = const Value.absent(),
    this.lastHitAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : titleNorm = Value(titleNorm),
       authorNorm = Value(authorNorm),
       sourceId = Value(sourceId);
  static Insertable<SearchSourceHit> custom({
    Expression<String>? titleNorm,
    Expression<String>? authorNorm,
    Expression<String>? sourceId,
    Expression<String>? sourceName,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? latestChapter,
    Expression<int>? latestChapterNo,
    Expression<int>? hitCount,
    Expression<DateTime>? lastHitAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (titleNorm != null) 'title_norm': titleNorm,
      if (authorNorm != null) 'author_norm': authorNorm,
      if (sourceId != null) 'source_id': sourceId,
      if (sourceName != null) 'source_name': sourceName,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (latestChapter != null) 'latest_chapter': latestChapter,
      if (latestChapterNo != null) 'latest_chapter_no': latestChapterNo,
      if (hitCount != null) 'hit_count': hitCount,
      if (lastHitAt != null) 'last_hit_at': lastHitAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchSourceHitsCompanion copyWith({
    Value<String>? titleNorm,
    Value<String>? authorNorm,
    Value<String>? sourceId,
    Value<String>? sourceName,
    Value<String>? title,
    Value<String?>? author,
    Value<String?>? latestChapter,
    Value<int?>? latestChapterNo,
    Value<int>? hitCount,
    Value<DateTime>? lastHitAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SearchSourceHitsCompanion(
      titleNorm: titleNorm ?? this.titleNorm,
      authorNorm: authorNorm ?? this.authorNorm,
      sourceId: sourceId ?? this.sourceId,
      sourceName: sourceName ?? this.sourceName,
      title: title ?? this.title,
      author: author ?? this.author,
      latestChapter: latestChapter ?? this.latestChapter,
      latestChapterNo: latestChapterNo ?? this.latestChapterNo,
      hitCount: hitCount ?? this.hitCount,
      lastHitAt: lastHitAt ?? this.lastHitAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (titleNorm.present) {
      map['title_norm'] = Variable<String>(titleNorm.value);
    }
    if (authorNorm.present) {
      map['author_norm'] = Variable<String>(authorNorm.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (sourceName.present) {
      map['source_name'] = Variable<String>(sourceName.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (latestChapter.present) {
      map['latest_chapter'] = Variable<String>(latestChapter.value);
    }
    if (latestChapterNo.present) {
      map['latest_chapter_no'] = Variable<int>(latestChapterNo.value);
    }
    if (hitCount.present) {
      map['hit_count'] = Variable<int>(hitCount.value);
    }
    if (lastHitAt.present) {
      map['last_hit_at'] = Variable<DateTime>(lastHitAt.value);
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
    return (StringBuffer('SearchSourceHitsCompanion(')
          ..write('titleNorm: $titleNorm, ')
          ..write('authorNorm: $authorNorm, ')
          ..write('sourceId: $sourceId, ')
          ..write('sourceName: $sourceName, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('latestChapter: $latestChapter, ')
          ..write('latestChapterNo: $latestChapterNo, ')
          ..write('hitCount: $hitCount, ')
          ..write('lastHitAt: $lastHitAt, ')
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
  late final $StoredLocalBooksTable storedLocalBooks = $StoredLocalBooksTable(
    this,
  );
  late final $StoredLocalChaptersTable storedLocalChapters =
      $StoredLocalChaptersTable(this);
  late final $SearchSourceHitsTable searchSourceHits = $SearchSourceHitsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sources,
    chapterCaches,
    storedLocalBooks,
    storedLocalChapters,
    searchSourceHits,
  ];
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
typedef $$StoredLocalBooksTableCreateCompanionBuilder =
    StoredLocalBooksCompanion Function({
      required String id,
      required String title,
      required String format,
      required String storagePath,
      Value<String?> sourcePath,
      required int fileSize,
      Value<String?> author,
      Value<String?> coverPath,
      Value<String> indexStatus,
      Value<int> chapterCount,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$StoredLocalBooksTableUpdateCompanionBuilder =
    StoredLocalBooksCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> format,
      Value<String> storagePath,
      Value<String?> sourcePath,
      Value<int> fileSize,
      Value<String?> author,
      Value<String?> coverPath,
      Value<String> indexStatus,
      Value<int> chapterCount,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$StoredLocalBooksTableFilterComposer
    extends Composer<_$AppDatabase, $StoredLocalBooksTable> {
  $$StoredLocalBooksTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storagePath => $composableBuilder(
    column: $table.storagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get indexStatus => $composableBuilder(
    column: $table.indexStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterCount => $composableBuilder(
    column: $table.chapterCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
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

class $$StoredLocalBooksTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredLocalBooksTable> {
  $$StoredLocalBooksTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storagePath => $composableBuilder(
    column: $table.storagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get indexStatus => $composableBuilder(
    column: $table.indexStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterCount => $composableBuilder(
    column: $table.chapterCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
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

class $$StoredLocalBooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredLocalBooksTable> {
  $$StoredLocalBooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get storagePath => $composableBuilder(
    column: $table.storagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<String> get indexStatus => $composableBuilder(
    column: $table.indexStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get chapterCount => $composableBuilder(
    column: $table.chapterCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StoredLocalBooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredLocalBooksTable,
          StoredLocalBook,
          $$StoredLocalBooksTableFilterComposer,
          $$StoredLocalBooksTableOrderingComposer,
          $$StoredLocalBooksTableAnnotationComposer,
          $$StoredLocalBooksTableCreateCompanionBuilder,
          $$StoredLocalBooksTableUpdateCompanionBuilder,
          (
            StoredLocalBook,
            BaseReferences<
              _$AppDatabase,
              $StoredLocalBooksTable,
              StoredLocalBook
            >,
          ),
          StoredLocalBook,
          PrefetchHooks Function()
        > {
  $$StoredLocalBooksTableTableManager(
    _$AppDatabase db,
    $StoredLocalBooksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$StoredLocalBooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$StoredLocalBooksTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$StoredLocalBooksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String> storagePath = const Value.absent(),
                Value<String?> sourcePath = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String> indexStatus = const Value.absent(),
                Value<int> chapterCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredLocalBooksCompanion(
                id: id,
                title: title,
                format: format,
                storagePath: storagePath,
                sourcePath: sourcePath,
                fileSize: fileSize,
                author: author,
                coverPath: coverPath,
                indexStatus: indexStatus,
                chapterCount: chapterCount,
                lastError: lastError,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String format,
                required String storagePath,
                Value<String?> sourcePath = const Value.absent(),
                required int fileSize,
                Value<String?> author = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String> indexStatus = const Value.absent(),
                Value<int> chapterCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredLocalBooksCompanion.insert(
                id: id,
                title: title,
                format: format,
                storagePath: storagePath,
                sourcePath: sourcePath,
                fileSize: fileSize,
                author: author,
                coverPath: coverPath,
                indexStatus: indexStatus,
                chapterCount: chapterCount,
                lastError: lastError,
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

typedef $$StoredLocalBooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredLocalBooksTable,
      StoredLocalBook,
      $$StoredLocalBooksTableFilterComposer,
      $$StoredLocalBooksTableOrderingComposer,
      $$StoredLocalBooksTableAnnotationComposer,
      $$StoredLocalBooksTableCreateCompanionBuilder,
      $$StoredLocalBooksTableUpdateCompanionBuilder,
      (
        StoredLocalBook,
        BaseReferences<_$AppDatabase, $StoredLocalBooksTable, StoredLocalBook>,
      ),
      StoredLocalBook,
      PrefetchHooks Function()
    >;
typedef $$StoredLocalChaptersTableCreateCompanionBuilder =
    StoredLocalChaptersCompanion Function({
      required String id,
      required String bookId,
      required int chapterIndex,
      required String title,
      required String content,
      Value<int?> startOffset,
      Value<int?> endOffset,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$StoredLocalChaptersTableUpdateCompanionBuilder =
    StoredLocalChaptersCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<int> chapterIndex,
      Value<String> title,
      Value<String> content,
      Value<int?> startOffset,
      Value<int?> endOffset,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$StoredLocalChaptersTableFilterComposer
    extends Composer<_$AppDatabase, $StoredLocalChaptersTable> {
  $$StoredLocalChaptersTableFilterComposer({
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

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
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

class $$StoredLocalChaptersTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredLocalChaptersTable> {
  $$StoredLocalChaptersTableOrderingComposer({
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

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endOffset => $composableBuilder(
    column: $table.endOffset,
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

class $$StoredLocalChaptersTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredLocalChaptersTable> {
  $$StoredLocalChaptersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endOffset =>
      $composableBuilder(column: $table.endOffset, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StoredLocalChaptersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredLocalChaptersTable,
          StoredLocalChapter,
          $$StoredLocalChaptersTableFilterComposer,
          $$StoredLocalChaptersTableOrderingComposer,
          $$StoredLocalChaptersTableAnnotationComposer,
          $$StoredLocalChaptersTableCreateCompanionBuilder,
          $$StoredLocalChaptersTableUpdateCompanionBuilder,
          (
            StoredLocalChapter,
            BaseReferences<
              _$AppDatabase,
              $StoredLocalChaptersTable,
              StoredLocalChapter
            >,
          ),
          StoredLocalChapter,
          PrefetchHooks Function()
        > {
  $$StoredLocalChaptersTableTableManager(
    _$AppDatabase db,
    $StoredLocalChaptersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$StoredLocalChaptersTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$StoredLocalChaptersTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$StoredLocalChaptersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int?> startOffset = const Value.absent(),
                Value<int?> endOffset = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredLocalChaptersCompanion(
                id: id,
                bookId: bookId,
                chapterIndex: chapterIndex,
                title: title,
                content: content,
                startOffset: startOffset,
                endOffset: endOffset,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required int chapterIndex,
                required String title,
                required String content,
                Value<int?> startOffset = const Value.absent(),
                Value<int?> endOffset = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredLocalChaptersCompanion.insert(
                id: id,
                bookId: bookId,
                chapterIndex: chapterIndex,
                title: title,
                content: content,
                startOffset: startOffset,
                endOffset: endOffset,
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

typedef $$StoredLocalChaptersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredLocalChaptersTable,
      StoredLocalChapter,
      $$StoredLocalChaptersTableFilterComposer,
      $$StoredLocalChaptersTableOrderingComposer,
      $$StoredLocalChaptersTableAnnotationComposer,
      $$StoredLocalChaptersTableCreateCompanionBuilder,
      $$StoredLocalChaptersTableUpdateCompanionBuilder,
      (
        StoredLocalChapter,
        BaseReferences<
          _$AppDatabase,
          $StoredLocalChaptersTable,
          StoredLocalChapter
        >,
      ),
      StoredLocalChapter,
      PrefetchHooks Function()
    >;
typedef $$SearchSourceHitsTableCreateCompanionBuilder =
    SearchSourceHitsCompanion Function({
      required String titleNorm,
      required String authorNorm,
      required String sourceId,
      Value<String> sourceName,
      Value<String> title,
      Value<String?> author,
      Value<String?> latestChapter,
      Value<int?> latestChapterNo,
      Value<int> hitCount,
      Value<DateTime> lastHitAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$SearchSourceHitsTableUpdateCompanionBuilder =
    SearchSourceHitsCompanion Function({
      Value<String> titleNorm,
      Value<String> authorNorm,
      Value<String> sourceId,
      Value<String> sourceName,
      Value<String> title,
      Value<String?> author,
      Value<String?> latestChapter,
      Value<int?> latestChapterNo,
      Value<int> hitCount,
      Value<DateTime> lastHitAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SearchSourceHitsTableFilterComposer
    extends Composer<_$AppDatabase, $SearchSourceHitsTable> {
  $$SearchSourceHitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get titleNorm => $composableBuilder(
    column: $table.titleNorm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorNorm => $composableBuilder(
    column: $table.authorNorm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get latestChapter => $composableBuilder(
    column: $table.latestChapter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get latestChapterNo => $composableBuilder(
    column: $table.latestChapterNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hitCount => $composableBuilder(
    column: $table.hitCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastHitAt => $composableBuilder(
    column: $table.lastHitAt,
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

class $$SearchSourceHitsTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchSourceHitsTable> {
  $$SearchSourceHitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get titleNorm => $composableBuilder(
    column: $table.titleNorm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorNorm => $composableBuilder(
    column: $table.authorNorm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get latestChapter => $composableBuilder(
    column: $table.latestChapter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get latestChapterNo => $composableBuilder(
    column: $table.latestChapterNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hitCount => $composableBuilder(
    column: $table.hitCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastHitAt => $composableBuilder(
    column: $table.lastHitAt,
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

class $$SearchSourceHitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchSourceHitsTable> {
  $$SearchSourceHitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get titleNorm =>
      $composableBuilder(column: $table.titleNorm, builder: (column) => column);

  GeneratedColumn<String> get authorNorm => $composableBuilder(
    column: $table.authorNorm,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get latestChapter => $composableBuilder(
    column: $table.latestChapter,
    builder: (column) => column,
  );

  GeneratedColumn<int> get latestChapterNo => $composableBuilder(
    column: $table.latestChapterNo,
    builder: (column) => column,
  );

  GeneratedColumn<int> get hitCount =>
      $composableBuilder(column: $table.hitCount, builder: (column) => column);

  GeneratedColumn<DateTime> get lastHitAt =>
      $composableBuilder(column: $table.lastHitAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SearchSourceHitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchSourceHitsTable,
          SearchSourceHit,
          $$SearchSourceHitsTableFilterComposer,
          $$SearchSourceHitsTableOrderingComposer,
          $$SearchSourceHitsTableAnnotationComposer,
          $$SearchSourceHitsTableCreateCompanionBuilder,
          $$SearchSourceHitsTableUpdateCompanionBuilder,
          (
            SearchSourceHit,
            BaseReferences<
              _$AppDatabase,
              $SearchSourceHitsTable,
              SearchSourceHit
            >,
          ),
          SearchSourceHit,
          PrefetchHooks Function()
        > {
  $$SearchSourceHitsTableTableManager(
    _$AppDatabase db,
    $SearchSourceHitsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$SearchSourceHitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$SearchSourceHitsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$SearchSourceHitsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> titleNorm = const Value.absent(),
                Value<String> authorNorm = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> sourceName = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> latestChapter = const Value.absent(),
                Value<int?> latestChapterNo = const Value.absent(),
                Value<int> hitCount = const Value.absent(),
                Value<DateTime> lastHitAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchSourceHitsCompanion(
                titleNorm: titleNorm,
                authorNorm: authorNorm,
                sourceId: sourceId,
                sourceName: sourceName,
                title: title,
                author: author,
                latestChapter: latestChapter,
                latestChapterNo: latestChapterNo,
                hitCount: hitCount,
                lastHitAt: lastHitAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String titleNorm,
                required String authorNorm,
                required String sourceId,
                Value<String> sourceName = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> latestChapter = const Value.absent(),
                Value<int?> latestChapterNo = const Value.absent(),
                Value<int> hitCount = const Value.absent(),
                Value<DateTime> lastHitAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchSourceHitsCompanion.insert(
                titleNorm: titleNorm,
                authorNorm: authorNorm,
                sourceId: sourceId,
                sourceName: sourceName,
                title: title,
                author: author,
                latestChapter: latestChapter,
                latestChapterNo: latestChapterNo,
                hitCount: hitCount,
                lastHitAt: lastHitAt,
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

typedef $$SearchSourceHitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchSourceHitsTable,
      SearchSourceHit,
      $$SearchSourceHitsTableFilterComposer,
      $$SearchSourceHitsTableOrderingComposer,
      $$SearchSourceHitsTableAnnotationComposer,
      $$SearchSourceHitsTableCreateCompanionBuilder,
      $$SearchSourceHitsTableUpdateCompanionBuilder,
      (
        SearchSourceHit,
        BaseReferences<_$AppDatabase, $SearchSourceHitsTable, SearchSourceHit>,
      ),
      SearchSourceHit,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SourcesTableTableManager get sources =>
      $$SourcesTableTableManager(_db, _db.sources);
  $$ChapterCachesTableTableManager get chapterCaches =>
      $$ChapterCachesTableTableManager(_db, _db.chapterCaches);
  $$StoredLocalBooksTableTableManager get storedLocalBooks =>
      $$StoredLocalBooksTableTableManager(_db, _db.storedLocalBooks);
  $$StoredLocalChaptersTableTableManager get storedLocalChapters =>
      $$StoredLocalChaptersTableTableManager(_db, _db.storedLocalChapters);
  $$SearchSourceHitsTableTableManager get searchSourceHits =>
      $$SearchSourceHitsTableTableManager(_db, _db.searchSourceHits);
}
