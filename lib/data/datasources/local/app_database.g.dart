// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
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
  static const VerificationMeta _charsetMeta = const VerificationMeta(
    'charset',
  );
  @override
  late final GeneratedColumn<String> charset = GeneratedColumn<String>(
    'charset',
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
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
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
  static const VerificationMeta _sourceFileSizeMeta = const VerificationMeta(
    'sourceFileSize',
  );
  @override
  late final GeneratedColumn<int> sourceFileSize = GeneratedColumn<int>(
    'source_file_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceFileLastModifiedMsMeta =
      const VerificationMeta('sourceFileLastModifiedMs');
  @override
  late final GeneratedColumn<int> sourceFileLastModifiedMs =
      GeneratedColumn<int>(
        'source_file_last_modified_ms',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _storageFileLastModifiedMsMeta =
      const VerificationMeta('storageFileLastModifiedMs');
  @override
  late final GeneratedColumn<int> storageFileLastModifiedMs =
      GeneratedColumn<int>(
        'storage_file_last_modified_ms',
        aliasedName,
        true,
        type: DriftSqlType.int,
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
  static const VerificationMeta _splitLongChapterMeta = const VerificationMeta(
    'splitLongChapter',
  );
  @override
  late final GeneratedColumn<bool> splitLongChapter = GeneratedColumn<bool>(
    'split_long_chapter',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("split_long_chapter" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    charset,
    fileSize,
    author,
    description,
    coverPath,
    sourceFileSize,
    sourceFileLastModifiedMs,
    storageFileLastModifiedMs,
    indexStatus,
    chapterCount,
    lastError,
    splitLongChapter,
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
    if (data.containsKey('charset')) {
      context.handle(
        _charsetMeta,
        charset.isAcceptableOrUnknown(data['charset']!, _charsetMeta),
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
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('source_file_size')) {
      context.handle(
        _sourceFileSizeMeta,
        sourceFileSize.isAcceptableOrUnknown(
          data['source_file_size']!,
          _sourceFileSizeMeta,
        ),
      );
    }
    if (data.containsKey('source_file_last_modified_ms')) {
      context.handle(
        _sourceFileLastModifiedMsMeta,
        sourceFileLastModifiedMs.isAcceptableOrUnknown(
          data['source_file_last_modified_ms']!,
          _sourceFileLastModifiedMsMeta,
        ),
      );
    }
    if (data.containsKey('storage_file_last_modified_ms')) {
      context.handle(
        _storageFileLastModifiedMsMeta,
        storageFileLastModifiedMs.isAcceptableOrUnknown(
          data['storage_file_last_modified_ms']!,
          _storageFileLastModifiedMsMeta,
        ),
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
    if (data.containsKey('split_long_chapter')) {
      context.handle(
        _splitLongChapterMeta,
        splitLongChapter.isAcceptableOrUnknown(
          data['split_long_chapter']!,
          _splitLongChapterMeta,
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
      charset: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}charset'],
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
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      sourceFileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_file_size'],
      ),
      sourceFileLastModifiedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_file_last_modified_ms'],
      ),
      storageFileLastModifiedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}storage_file_last_modified_ms'],
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
      splitLongChapter:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}split_long_chapter'],
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
  final String? charset;
  final int fileSize;
  final String? author;
  final String? description;
  final String? coverPath;
  final int? sourceFileSize;
  final int? sourceFileLastModifiedMs;
  final int? storageFileLastModifiedMs;
  final String indexStatus;
  final int chapterCount;
  final String? lastError;
  final bool splitLongChapter;
  final DateTime createdAt;
  final DateTime updatedAt;
  const StoredLocalBook({
    required this.id,
    required this.title,
    required this.format,
    required this.storagePath,
    this.sourcePath,
    this.charset,
    required this.fileSize,
    this.author,
    this.description,
    this.coverPath,
    this.sourceFileSize,
    this.sourceFileLastModifiedMs,
    this.storageFileLastModifiedMs,
    required this.indexStatus,
    required this.chapterCount,
    this.lastError,
    required this.splitLongChapter,
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
    if (!nullToAbsent || charset != null) {
      map['charset'] = Variable<String>(charset);
    }
    map['file_size'] = Variable<int>(fileSize);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    if (!nullToAbsent || sourceFileSize != null) {
      map['source_file_size'] = Variable<int>(sourceFileSize);
    }
    if (!nullToAbsent || sourceFileLastModifiedMs != null) {
      map['source_file_last_modified_ms'] = Variable<int>(
        sourceFileLastModifiedMs,
      );
    }
    if (!nullToAbsent || storageFileLastModifiedMs != null) {
      map['storage_file_last_modified_ms'] = Variable<int>(
        storageFileLastModifiedMs,
      );
    }
    map['index_status'] = Variable<String>(indexStatus);
    map['chapter_count'] = Variable<int>(chapterCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['split_long_chapter'] = Variable<bool>(splitLongChapter);
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
      charset:
          charset == null && nullToAbsent
              ? const Value.absent()
              : Value(charset),
      fileSize: Value(fileSize),
      author:
          author == null && nullToAbsent ? const Value.absent() : Value(author),
      description:
          description == null && nullToAbsent
              ? const Value.absent()
              : Value(description),
      coverPath:
          coverPath == null && nullToAbsent
              ? const Value.absent()
              : Value(coverPath),
      sourceFileSize:
          sourceFileSize == null && nullToAbsent
              ? const Value.absent()
              : Value(sourceFileSize),
      sourceFileLastModifiedMs:
          sourceFileLastModifiedMs == null && nullToAbsent
              ? const Value.absent()
              : Value(sourceFileLastModifiedMs),
      storageFileLastModifiedMs:
          storageFileLastModifiedMs == null && nullToAbsent
              ? const Value.absent()
              : Value(storageFileLastModifiedMs),
      indexStatus: Value(indexStatus),
      chapterCount: Value(chapterCount),
      lastError:
          lastError == null && nullToAbsent
              ? const Value.absent()
              : Value(lastError),
      splitLongChapter: Value(splitLongChapter),
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
      charset: serializer.fromJson<String?>(json['charset']),
      fileSize: serializer.fromJson<int>(json['fileSize']),
      author: serializer.fromJson<String?>(json['author']),
      description: serializer.fromJson<String?>(json['description']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      sourceFileSize: serializer.fromJson<int?>(json['sourceFileSize']),
      sourceFileLastModifiedMs: serializer.fromJson<int?>(
        json['sourceFileLastModifiedMs'],
      ),
      storageFileLastModifiedMs: serializer.fromJson<int?>(
        json['storageFileLastModifiedMs'],
      ),
      indexStatus: serializer.fromJson<String>(json['indexStatus']),
      chapterCount: serializer.fromJson<int>(json['chapterCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      splitLongChapter: serializer.fromJson<bool>(json['splitLongChapter']),
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
      'charset': serializer.toJson<String?>(charset),
      'fileSize': serializer.toJson<int>(fileSize),
      'author': serializer.toJson<String?>(author),
      'description': serializer.toJson<String?>(description),
      'coverPath': serializer.toJson<String?>(coverPath),
      'sourceFileSize': serializer.toJson<int?>(sourceFileSize),
      'sourceFileLastModifiedMs': serializer.toJson<int?>(
        sourceFileLastModifiedMs,
      ),
      'storageFileLastModifiedMs': serializer.toJson<int?>(
        storageFileLastModifiedMs,
      ),
      'indexStatus': serializer.toJson<String>(indexStatus),
      'chapterCount': serializer.toJson<int>(chapterCount),
      'lastError': serializer.toJson<String?>(lastError),
      'splitLongChapter': serializer.toJson<bool>(splitLongChapter),
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
    Value<String?> charset = const Value.absent(),
    int? fileSize,
    Value<String?> author = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> coverPath = const Value.absent(),
    Value<int?> sourceFileSize = const Value.absent(),
    Value<int?> sourceFileLastModifiedMs = const Value.absent(),
    Value<int?> storageFileLastModifiedMs = const Value.absent(),
    String? indexStatus,
    int? chapterCount,
    Value<String?> lastError = const Value.absent(),
    bool? splitLongChapter,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StoredLocalBook(
    id: id ?? this.id,
    title: title ?? this.title,
    format: format ?? this.format,
    storagePath: storagePath ?? this.storagePath,
    sourcePath: sourcePath.present ? sourcePath.value : this.sourcePath,
    charset: charset.present ? charset.value : this.charset,
    fileSize: fileSize ?? this.fileSize,
    author: author.present ? author.value : this.author,
    description: description.present ? description.value : this.description,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    sourceFileSize:
        sourceFileSize.present ? sourceFileSize.value : this.sourceFileSize,
    sourceFileLastModifiedMs:
        sourceFileLastModifiedMs.present
            ? sourceFileLastModifiedMs.value
            : this.sourceFileLastModifiedMs,
    storageFileLastModifiedMs:
        storageFileLastModifiedMs.present
            ? storageFileLastModifiedMs.value
            : this.storageFileLastModifiedMs,
    indexStatus: indexStatus ?? this.indexStatus,
    chapterCount: chapterCount ?? this.chapterCount,
    lastError: lastError.present ? lastError.value : this.lastError,
    splitLongChapter: splitLongChapter ?? this.splitLongChapter,
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
      charset: data.charset.present ? data.charset.value : this.charset,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      author: data.author.present ? data.author.value : this.author,
      description:
          data.description.present ? data.description.value : this.description,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      sourceFileSize:
          data.sourceFileSize.present
              ? data.sourceFileSize.value
              : this.sourceFileSize,
      sourceFileLastModifiedMs:
          data.sourceFileLastModifiedMs.present
              ? data.sourceFileLastModifiedMs.value
              : this.sourceFileLastModifiedMs,
      storageFileLastModifiedMs:
          data.storageFileLastModifiedMs.present
              ? data.storageFileLastModifiedMs.value
              : this.storageFileLastModifiedMs,
      indexStatus:
          data.indexStatus.present ? data.indexStatus.value : this.indexStatus,
      chapterCount:
          data.chapterCount.present
              ? data.chapterCount.value
              : this.chapterCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      splitLongChapter:
          data.splitLongChapter.present
              ? data.splitLongChapter.value
              : this.splitLongChapter,
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
          ..write('charset: $charset, ')
          ..write('fileSize: $fileSize, ')
          ..write('author: $author, ')
          ..write('description: $description, ')
          ..write('coverPath: $coverPath, ')
          ..write('sourceFileSize: $sourceFileSize, ')
          ..write('sourceFileLastModifiedMs: $sourceFileLastModifiedMs, ')
          ..write('storageFileLastModifiedMs: $storageFileLastModifiedMs, ')
          ..write('indexStatus: $indexStatus, ')
          ..write('chapterCount: $chapterCount, ')
          ..write('lastError: $lastError, ')
          ..write('splitLongChapter: $splitLongChapter, ')
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
    charset,
    fileSize,
    author,
    description,
    coverPath,
    sourceFileSize,
    sourceFileLastModifiedMs,
    storageFileLastModifiedMs,
    indexStatus,
    chapterCount,
    lastError,
    splitLongChapter,
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
          other.charset == this.charset &&
          other.fileSize == this.fileSize &&
          other.author == this.author &&
          other.description == this.description &&
          other.coverPath == this.coverPath &&
          other.sourceFileSize == this.sourceFileSize &&
          other.sourceFileLastModifiedMs == this.sourceFileLastModifiedMs &&
          other.storageFileLastModifiedMs == this.storageFileLastModifiedMs &&
          other.indexStatus == this.indexStatus &&
          other.chapterCount == this.chapterCount &&
          other.lastError == this.lastError &&
          other.splitLongChapter == this.splitLongChapter &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class StoredLocalBooksCompanion extends UpdateCompanion<StoredLocalBook> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> format;
  final Value<String> storagePath;
  final Value<String?> sourcePath;
  final Value<String?> charset;
  final Value<int> fileSize;
  final Value<String?> author;
  final Value<String?> description;
  final Value<String?> coverPath;
  final Value<int?> sourceFileSize;
  final Value<int?> sourceFileLastModifiedMs;
  final Value<int?> storageFileLastModifiedMs;
  final Value<String> indexStatus;
  final Value<int> chapterCount;
  final Value<String?> lastError;
  final Value<bool> splitLongChapter;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StoredLocalBooksCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.format = const Value.absent(),
    this.storagePath = const Value.absent(),
    this.sourcePath = const Value.absent(),
    this.charset = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.author = const Value.absent(),
    this.description = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.sourceFileSize = const Value.absent(),
    this.sourceFileLastModifiedMs = const Value.absent(),
    this.storageFileLastModifiedMs = const Value.absent(),
    this.indexStatus = const Value.absent(),
    this.chapterCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.splitLongChapter = const Value.absent(),
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
    this.charset = const Value.absent(),
    required int fileSize,
    this.author = const Value.absent(),
    this.description = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.sourceFileSize = const Value.absent(),
    this.sourceFileLastModifiedMs = const Value.absent(),
    this.storageFileLastModifiedMs = const Value.absent(),
    this.indexStatus = const Value.absent(),
    this.chapterCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.splitLongChapter = const Value.absent(),
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
    Expression<String>? charset,
    Expression<int>? fileSize,
    Expression<String>? author,
    Expression<String>? description,
    Expression<String>? coverPath,
    Expression<int>? sourceFileSize,
    Expression<int>? sourceFileLastModifiedMs,
    Expression<int>? storageFileLastModifiedMs,
    Expression<String>? indexStatus,
    Expression<int>? chapterCount,
    Expression<String>? lastError,
    Expression<bool>? splitLongChapter,
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
      if (charset != null) 'charset': charset,
      if (fileSize != null) 'file_size': fileSize,
      if (author != null) 'author': author,
      if (description != null) 'description': description,
      if (coverPath != null) 'cover_path': coverPath,
      if (sourceFileSize != null) 'source_file_size': sourceFileSize,
      if (sourceFileLastModifiedMs != null)
        'source_file_last_modified_ms': sourceFileLastModifiedMs,
      if (storageFileLastModifiedMs != null)
        'storage_file_last_modified_ms': storageFileLastModifiedMs,
      if (indexStatus != null) 'index_status': indexStatus,
      if (chapterCount != null) 'chapter_count': chapterCount,
      if (lastError != null) 'last_error': lastError,
      if (splitLongChapter != null) 'split_long_chapter': splitLongChapter,
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
    Value<String?>? charset,
    Value<int>? fileSize,
    Value<String?>? author,
    Value<String?>? description,
    Value<String?>? coverPath,
    Value<int?>? sourceFileSize,
    Value<int?>? sourceFileLastModifiedMs,
    Value<int?>? storageFileLastModifiedMs,
    Value<String>? indexStatus,
    Value<int>? chapterCount,
    Value<String?>? lastError,
    Value<bool>? splitLongChapter,
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
      charset: charset ?? this.charset,
      fileSize: fileSize ?? this.fileSize,
      author: author ?? this.author,
      description: description ?? this.description,
      coverPath: coverPath ?? this.coverPath,
      sourceFileSize: sourceFileSize ?? this.sourceFileSize,
      sourceFileLastModifiedMs:
          sourceFileLastModifiedMs ?? this.sourceFileLastModifiedMs,
      storageFileLastModifiedMs:
          storageFileLastModifiedMs ?? this.storageFileLastModifiedMs,
      indexStatus: indexStatus ?? this.indexStatus,
      chapterCount: chapterCount ?? this.chapterCount,
      lastError: lastError ?? this.lastError,
      splitLongChapter: splitLongChapter ?? this.splitLongChapter,
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
    if (charset.present) {
      map['charset'] = Variable<String>(charset.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (sourceFileSize.present) {
      map['source_file_size'] = Variable<int>(sourceFileSize.value);
    }
    if (sourceFileLastModifiedMs.present) {
      map['source_file_last_modified_ms'] = Variable<int>(
        sourceFileLastModifiedMs.value,
      );
    }
    if (storageFileLastModifiedMs.present) {
      map['storage_file_last_modified_ms'] = Variable<int>(
        storageFileLastModifiedMs.value,
      );
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
    if (splitLongChapter.present) {
      map['split_long_chapter'] = Variable<bool>(splitLongChapter.value);
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
          ..write('charset: $charset, ')
          ..write('fileSize: $fileSize, ')
          ..write('author: $author, ')
          ..write('description: $description, ')
          ..write('coverPath: $coverPath, ')
          ..write('sourceFileSize: $sourceFileSize, ')
          ..write('sourceFileLastModifiedMs: $sourceFileLastModifiedMs, ')
          ..write('storageFileLastModifiedMs: $storageFileLastModifiedMs, ')
          ..write('indexStatus: $indexStatus, ')
          ..write('chapterCount: $chapterCount, ')
          ..write('lastError: $lastError, ')
          ..write('splitLongChapter: $splitLongChapter, ')
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
  static const VerificationMeta _imageUrlsJsonMeta = const VerificationMeta(
    'imageUrlsJson',
  );
  @override
  late final GeneratedColumn<String> imageUrlsJson = GeneratedColumn<String>(
    'image_urls_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _documentJsonMeta = const VerificationMeta(
    'documentJson',
  );
  @override
  late final GeneratedColumn<String> documentJson = GeneratedColumn<String>(
    'document_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceRefMeta = const VerificationMeta(
    'sourceRef',
  );
  @override
  late final GeneratedColumn<String> sourceRef = GeneratedColumn<String>(
    'source_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    imageUrlsJson,
    documentJson,
    sourceRef,
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
    if (data.containsKey('image_urls_json')) {
      context.handle(
        _imageUrlsJsonMeta,
        imageUrlsJson.isAcceptableOrUnknown(
          data['image_urls_json']!,
          _imageUrlsJsonMeta,
        ),
      );
    }
    if (data.containsKey('document_json')) {
      context.handle(
        _documentJsonMeta,
        documentJson.isAcceptableOrUnknown(
          data['document_json']!,
          _documentJsonMeta,
        ),
      );
    }
    if (data.containsKey('source_ref')) {
      context.handle(
        _sourceRefMeta,
        sourceRef.isAcceptableOrUnknown(data['source_ref']!, _sourceRefMeta),
      );
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
      imageUrlsJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}image_urls_json'],
          )!,
      documentJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_json'],
      ),
      sourceRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_ref'],
      ),
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
  final String imageUrlsJson;
  final String? documentJson;
  final String? sourceRef;
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
    required this.imageUrlsJson,
    this.documentJson,
    this.sourceRef,
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
    map['image_urls_json'] = Variable<String>(imageUrlsJson);
    if (!nullToAbsent || documentJson != null) {
      map['document_json'] = Variable<String>(documentJson);
    }
    if (!nullToAbsent || sourceRef != null) {
      map['source_ref'] = Variable<String>(sourceRef);
    }
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
      imageUrlsJson: Value(imageUrlsJson),
      documentJson:
          documentJson == null && nullToAbsent
              ? const Value.absent()
              : Value(documentJson),
      sourceRef:
          sourceRef == null && nullToAbsent
              ? const Value.absent()
              : Value(sourceRef),
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
      imageUrlsJson: serializer.fromJson<String>(json['imageUrlsJson']),
      documentJson: serializer.fromJson<String?>(json['documentJson']),
      sourceRef: serializer.fromJson<String?>(json['sourceRef']),
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
      'imageUrlsJson': serializer.toJson<String>(imageUrlsJson),
      'documentJson': serializer.toJson<String?>(documentJson),
      'sourceRef': serializer.toJson<String?>(sourceRef),
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
    String? imageUrlsJson,
    Value<String?> documentJson = const Value.absent(),
    Value<String?> sourceRef = const Value.absent(),
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
    imageUrlsJson: imageUrlsJson ?? this.imageUrlsJson,
    documentJson: documentJson.present ? documentJson.value : this.documentJson,
    sourceRef: sourceRef.present ? sourceRef.value : this.sourceRef,
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
      imageUrlsJson:
          data.imageUrlsJson.present
              ? data.imageUrlsJson.value
              : this.imageUrlsJson,
      documentJson:
          data.documentJson.present
              ? data.documentJson.value
              : this.documentJson,
      sourceRef: data.sourceRef.present ? data.sourceRef.value : this.sourceRef,
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
          ..write('imageUrlsJson: $imageUrlsJson, ')
          ..write('documentJson: $documentJson, ')
          ..write('sourceRef: $sourceRef, ')
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
    imageUrlsJson,
    documentJson,
    sourceRef,
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
          other.imageUrlsJson == this.imageUrlsJson &&
          other.documentJson == this.documentJson &&
          other.sourceRef == this.sourceRef &&
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
  final Value<String> imageUrlsJson;
  final Value<String?> documentJson;
  final Value<String?> sourceRef;
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
    this.imageUrlsJson = const Value.absent(),
    this.documentJson = const Value.absent(),
    this.sourceRef = const Value.absent(),
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
    this.imageUrlsJson = const Value.absent(),
    this.documentJson = const Value.absent(),
    this.sourceRef = const Value.absent(),
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
    Expression<String>? imageUrlsJson,
    Expression<String>? documentJson,
    Expression<String>? sourceRef,
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
      if (imageUrlsJson != null) 'image_urls_json': imageUrlsJson,
      if (documentJson != null) 'document_json': documentJson,
      if (sourceRef != null) 'source_ref': sourceRef,
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
    Value<String>? imageUrlsJson,
    Value<String?>? documentJson,
    Value<String?>? sourceRef,
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
      imageUrlsJson: imageUrlsJson ?? this.imageUrlsJson,
      documentJson: documentJson ?? this.documentJson,
      sourceRef: sourceRef ?? this.sourceRef,
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
    if (imageUrlsJson.present) {
      map['image_urls_json'] = Variable<String>(imageUrlsJson.value);
    }
    if (documentJson.present) {
      map['document_json'] = Variable<String>(documentJson.value);
    }
    if (sourceRef.present) {
      map['source_ref'] = Variable<String>(sourceRef.value);
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
          ..write('imageUrlsJson: $imageUrlsJson, ')
          ..write('documentJson: $documentJson, ')
          ..write('sourceRef: $sourceRef, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredBookmarksTable extends StoredBookmarks
    with TableInfo<$StoredBookmarksTable, StoredBookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredBookmarksTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<String> chapterId = GeneratedColumn<String>(
    'chapter_id',
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
  static const VerificationMeta _startOffsetMeta = const VerificationMeta(
    'startOffset',
  );
  @override
  late final GeneratedColumn<int> startOffset = GeneratedColumn<int>(
    'start_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endOffsetMeta = const VerificationMeta(
    'endOffset',
  );
  @override
  late final GeneratedColumn<int> endOffset = GeneratedColumn<int>(
    'end_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _snippetMeta = const VerificationMeta(
    'snippet',
  );
  @override
  late final GeneratedColumn<String> snippet = GeneratedColumn<String>(
    'snippet',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isBoldMeta = const VerificationMeta('isBold');
  @override
  late final GeneratedColumn<bool> isBold = GeneratedColumn<bool>(
    'is_bold',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_bold" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isUnderlineMeta = const VerificationMeta(
    'isUnderline',
  );
  @override
  late final GeneratedColumn<bool> isUnderline = GeneratedColumn<bool>(
    'is_underline',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_underline" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isWavyMeta = const VerificationMeta('isWavy');
  @override
  late final GeneratedColumn<bool> isWavy = GeneratedColumn<bool>(
    'is_wavy',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_wavy" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
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
    bookId,
    chapterId,
    chapterIndex,
    startOffset,
    endOffset,
    snippet,
    note,
    isBold,
    isUnderline,
    isWavy,
    color,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredBookmark> instance, {
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
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
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
    if (data.containsKey('start_offset')) {
      context.handle(
        _startOffsetMeta,
        startOffset.isAcceptableOrUnknown(
          data['start_offset']!,
          _startOffsetMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startOffsetMeta);
    }
    if (data.containsKey('end_offset')) {
      context.handle(
        _endOffsetMeta,
        endOffset.isAcceptableOrUnknown(data['end_offset']!, _endOffsetMeta),
      );
    } else if (isInserting) {
      context.missing(_endOffsetMeta);
    }
    if (data.containsKey('snippet')) {
      context.handle(
        _snippetMeta,
        snippet.isAcceptableOrUnknown(data['snippet']!, _snippetMeta),
      );
    } else if (isInserting) {
      context.missing(_snippetMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('is_bold')) {
      context.handle(
        _isBoldMeta,
        isBold.isAcceptableOrUnknown(data['is_bold']!, _isBoldMeta),
      );
    }
    if (data.containsKey('is_underline')) {
      context.handle(
        _isUnderlineMeta,
        isUnderline.isAcceptableOrUnknown(
          data['is_underline']!,
          _isUnderlineMeta,
        ),
      );
    }
    if (data.containsKey('is_wavy')) {
      context.handle(
        _isWavyMeta,
        isWavy.isAcceptableOrUnknown(data['is_wavy']!, _isWavyMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
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
  StoredBookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredBookmark(
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
      chapterId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}chapter_id'],
          )!,
      chapterIndex:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}chapter_index'],
          )!,
      startOffset:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}start_offset'],
          )!,
      endOffset:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}end_offset'],
          )!,
      snippet:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}snippet'],
          )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      isBold:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_bold'],
          )!,
      isUnderline:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_underline'],
          )!,
      isWavy:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_wavy'],
          )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
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
  $StoredBookmarksTable createAlias(String alias) {
    return $StoredBookmarksTable(attachedDatabase, alias);
  }
}

class StoredBookmark extends DataClass implements Insertable<StoredBookmark> {
  final String id;
  final String bookId;
  final String chapterId;
  final int chapterIndex;
  final int startOffset;
  final int endOffset;
  final String snippet;
  final String? note;
  final bool isBold;
  final bool isUnderline;
  final bool isWavy;
  final String? color;
  final DateTime createdAt;
  final DateTime updatedAt;
  const StoredBookmark({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.chapterIndex,
    required this.startOffset,
    required this.endOffset,
    required this.snippet,
    this.note,
    required this.isBold,
    required this.isUnderline,
    required this.isWavy,
    this.color,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['chapter_id'] = Variable<String>(chapterId);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['start_offset'] = Variable<int>(startOffset);
    map['end_offset'] = Variable<int>(endOffset);
    map['snippet'] = Variable<String>(snippet);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['is_bold'] = Variable<bool>(isBold);
    map['is_underline'] = Variable<bool>(isUnderline);
    map['is_wavy'] = Variable<bool>(isWavy);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StoredBookmarksCompanion toCompanion(bool nullToAbsent) {
    return StoredBookmarksCompanion(
      id: Value(id),
      bookId: Value(bookId),
      chapterId: Value(chapterId),
      chapterIndex: Value(chapterIndex),
      startOffset: Value(startOffset),
      endOffset: Value(endOffset),
      snippet: Value(snippet),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      isBold: Value(isBold),
      isUnderline: Value(isUnderline),
      isWavy: Value(isWavy),
      color:
          color == null && nullToAbsent ? const Value.absent() : Value(color),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredBookmark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredBookmark(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      chapterId: serializer.fromJson<String>(json['chapterId']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      startOffset: serializer.fromJson<int>(json['startOffset']),
      endOffset: serializer.fromJson<int>(json['endOffset']),
      snippet: serializer.fromJson<String>(json['snippet']),
      note: serializer.fromJson<String?>(json['note']),
      isBold: serializer.fromJson<bool>(json['isBold']),
      isUnderline: serializer.fromJson<bool>(json['isUnderline']),
      isWavy: serializer.fromJson<bool>(json['isWavy']),
      color: serializer.fromJson<String?>(json['color']),
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
      'chapterId': serializer.toJson<String>(chapterId),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'startOffset': serializer.toJson<int>(startOffset),
      'endOffset': serializer.toJson<int>(endOffset),
      'snippet': serializer.toJson<String>(snippet),
      'note': serializer.toJson<String?>(note),
      'isBold': serializer.toJson<bool>(isBold),
      'isUnderline': serializer.toJson<bool>(isUnderline),
      'isWavy': serializer.toJson<bool>(isWavy),
      'color': serializer.toJson<String?>(color),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredBookmark copyWith({
    String? id,
    String? bookId,
    String? chapterId,
    int? chapterIndex,
    int? startOffset,
    int? endOffset,
    String? snippet,
    Value<String?> note = const Value.absent(),
    bool? isBold,
    bool? isUnderline,
    bool? isWavy,
    Value<String?> color = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StoredBookmark(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    chapterId: chapterId ?? this.chapterId,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    startOffset: startOffset ?? this.startOffset,
    endOffset: endOffset ?? this.endOffset,
    snippet: snippet ?? this.snippet,
    note: note.present ? note.value : this.note,
    isBold: isBold ?? this.isBold,
    isUnderline: isUnderline ?? this.isUnderline,
    isWavy: isWavy ?? this.isWavy,
    color: color.present ? color.value : this.color,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredBookmark copyWithCompanion(StoredBookmarksCompanion data) {
    return StoredBookmark(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      chapterIndex:
          data.chapterIndex.present
              ? data.chapterIndex.value
              : this.chapterIndex,
      startOffset:
          data.startOffset.present ? data.startOffset.value : this.startOffset,
      endOffset: data.endOffset.present ? data.endOffset.value : this.endOffset,
      snippet: data.snippet.present ? data.snippet.value : this.snippet,
      note: data.note.present ? data.note.value : this.note,
      isBold: data.isBold.present ? data.isBold.value : this.isBold,
      isUnderline:
          data.isUnderline.present ? data.isUnderline.value : this.isUnderline,
      isWavy: data.isWavy.present ? data.isWavy.value : this.isWavy,
      color: data.color.present ? data.color.value : this.color,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredBookmark(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('snippet: $snippet, ')
          ..write('note: $note, ')
          ..write('isBold: $isBold, ')
          ..write('isUnderline: $isUnderline, ')
          ..write('isWavy: $isWavy, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    chapterId,
    chapterIndex,
    startOffset,
    endOffset,
    snippet,
    note,
    isBold,
    isUnderline,
    isWavy,
    color,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredBookmark &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.chapterId == this.chapterId &&
          other.chapterIndex == this.chapterIndex &&
          other.startOffset == this.startOffset &&
          other.endOffset == this.endOffset &&
          other.snippet == this.snippet &&
          other.note == this.note &&
          other.isBold == this.isBold &&
          other.isUnderline == this.isUnderline &&
          other.isWavy == this.isWavy &&
          other.color == this.color &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class StoredBookmarksCompanion extends UpdateCompanion<StoredBookmark> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> chapterId;
  final Value<int> chapterIndex;
  final Value<int> startOffset;
  final Value<int> endOffset;
  final Value<String> snippet;
  final Value<String?> note;
  final Value<bool> isBold;
  final Value<bool> isUnderline;
  final Value<bool> isWavy;
  final Value<String?> color;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StoredBookmarksCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.startOffset = const Value.absent(),
    this.endOffset = const Value.absent(),
    this.snippet = const Value.absent(),
    this.note = const Value.absent(),
    this.isBold = const Value.absent(),
    this.isUnderline = const Value.absent(),
    this.isWavy = const Value.absent(),
    this.color = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredBookmarksCompanion.insert({
    required String id,
    required String bookId,
    required String chapterId,
    required int chapterIndex,
    required int startOffset,
    required int endOffset,
    required String snippet,
    this.note = const Value.absent(),
    this.isBold = const Value.absent(),
    this.isUnderline = const Value.absent(),
    this.isWavy = const Value.absent(),
    this.color = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       chapterId = Value(chapterId),
       chapterIndex = Value(chapterIndex),
       startOffset = Value(startOffset),
       endOffset = Value(endOffset),
       snippet = Value(snippet);
  static Insertable<StoredBookmark> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? chapterId,
    Expression<int>? chapterIndex,
    Expression<int>? startOffset,
    Expression<int>? endOffset,
    Expression<String>? snippet,
    Expression<String>? note,
    Expression<bool>? isBold,
    Expression<bool>? isUnderline,
    Expression<bool>? isWavy,
    Expression<String>? color,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (chapterId != null) 'chapter_id': chapterId,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (startOffset != null) 'start_offset': startOffset,
      if (endOffset != null) 'end_offset': endOffset,
      if (snippet != null) 'snippet': snippet,
      if (note != null) 'note': note,
      if (isBold != null) 'is_bold': isBold,
      if (isUnderline != null) 'is_underline': isUnderline,
      if (isWavy != null) 'is_wavy': isWavy,
      if (color != null) 'color': color,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredBookmarksCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? chapterId,
    Value<int>? chapterIndex,
    Value<int>? startOffset,
    Value<int>? endOffset,
    Value<String>? snippet,
    Value<String?>? note,
    Value<bool>? isBold,
    Value<bool>? isUnderline,
    Value<bool>? isWavy,
    Value<String?>? color,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StoredBookmarksCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      snippet: snippet ?? this.snippet,
      note: note ?? this.note,
      isBold: isBold ?? this.isBold,
      isUnderline: isUnderline ?? this.isUnderline,
      isWavy: isWavy ?? this.isWavy,
      color: color ?? this.color,
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
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (startOffset.present) {
      map['start_offset'] = Variable<int>(startOffset.value);
    }
    if (endOffset.present) {
      map['end_offset'] = Variable<int>(endOffset.value);
    }
    if (snippet.present) {
      map['snippet'] = Variable<String>(snippet.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (isBold.present) {
      map['is_bold'] = Variable<bool>(isBold.value);
    }
    if (isUnderline.present) {
      map['is_underline'] = Variable<bool>(isUnderline.value);
    }
    if (isWavy.present) {
      map['is_wavy'] = Variable<bool>(isWavy.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
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
    return (StringBuffer('StoredBookmarksCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('chapterId: $chapterId, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('snippet: $snippet, ')
          ..write('note: $note, ')
          ..write('isBold: $isBold, ')
          ..write('isUnderline: $isUnderline, ')
          ..write('isWavy: $isWavy, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredBookMetadataOverridesTable extends StoredBookMetadataOverrides
    with
        TableInfo<
          $StoredBookMetadataOverridesTable,
          StoredBookMetadataOverride
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredBookMetadataOverridesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _targetKeyMeta = const VerificationMeta(
    'targetKey',
  );
  @override
  late final GeneratedColumn<String> targetKey = GeneratedColumn<String>(
    'target_key',
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detailUrlMeta = const VerificationMeta(
    'detailUrl',
  );
  @override
  late final GeneratedColumn<String> detailUrl = GeneratedColumn<String>(
    'detail_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _introMeta = const VerificationMeta('intro');
  @override
  late final GeneratedColumn<String> intro = GeneratedColumn<String>(
    'intro',
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
    targetKey,
    bookId,
    sourceId,
    detailUrl,
    title,
    author,
    intro,
    coverPath,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_metadata_overrides';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredBookMetadataOverride> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('target_key')) {
      context.handle(
        _targetKeyMeta,
        targetKey.isAcceptableOrUnknown(data['target_key']!, _targetKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_targetKeyMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    }
    if (data.containsKey('detail_url')) {
      context.handle(
        _detailUrlMeta,
        detailUrl.isAcceptableOrUnknown(data['detail_url']!, _detailUrlMeta),
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
    if (data.containsKey('intro')) {
      context.handle(
        _introMeta,
        intro.isAcceptableOrUnknown(data['intro']!, _introMeta),
      );
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
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
  Set<GeneratedColumn> get $primaryKey => {targetKey};
  @override
  StoredBookMetadataOverride map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredBookMetadataOverride(
      targetKey:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}target_key'],
          )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      ),
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      ),
      detailUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail_url'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      intro: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}intro'],
      ),
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
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
  $StoredBookMetadataOverridesTable createAlias(String alias) {
    return $StoredBookMetadataOverridesTable(attachedDatabase, alias);
  }
}

class StoredBookMetadataOverride extends DataClass
    implements Insertable<StoredBookMetadataOverride> {
  final String targetKey;
  final String? bookId;
  final String? sourceId;
  final String? detailUrl;
  final String? title;
  final String? author;
  final String? intro;
  final String? coverPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  const StoredBookMetadataOverride({
    required this.targetKey,
    this.bookId,
    this.sourceId,
    this.detailUrl,
    this.title,
    this.author,
    this.intro,
    this.coverPath,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['target_key'] = Variable<String>(targetKey);
    if (!nullToAbsent || bookId != null) {
      map['book_id'] = Variable<String>(bookId);
    }
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    if (!nullToAbsent || detailUrl != null) {
      map['detail_url'] = Variable<String>(detailUrl);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || intro != null) {
      map['intro'] = Variable<String>(intro);
    }
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StoredBookMetadataOverridesCompanion toCompanion(bool nullToAbsent) {
    return StoredBookMetadataOverridesCompanion(
      targetKey: Value(targetKey),
      bookId:
          bookId == null && nullToAbsent ? const Value.absent() : Value(bookId),
      sourceId:
          sourceId == null && nullToAbsent
              ? const Value.absent()
              : Value(sourceId),
      detailUrl:
          detailUrl == null && nullToAbsent
              ? const Value.absent()
              : Value(detailUrl),
      title:
          title == null && nullToAbsent ? const Value.absent() : Value(title),
      author:
          author == null && nullToAbsent ? const Value.absent() : Value(author),
      intro:
          intro == null && nullToAbsent ? const Value.absent() : Value(intro),
      coverPath:
          coverPath == null && nullToAbsent
              ? const Value.absent()
              : Value(coverPath),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredBookMetadataOverride.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredBookMetadataOverride(
      targetKey: serializer.fromJson<String>(json['targetKey']),
      bookId: serializer.fromJson<String?>(json['bookId']),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      detailUrl: serializer.fromJson<String?>(json['detailUrl']),
      title: serializer.fromJson<String?>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      intro: serializer.fromJson<String?>(json['intro']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'targetKey': serializer.toJson<String>(targetKey),
      'bookId': serializer.toJson<String?>(bookId),
      'sourceId': serializer.toJson<String?>(sourceId),
      'detailUrl': serializer.toJson<String?>(detailUrl),
      'title': serializer.toJson<String?>(title),
      'author': serializer.toJson<String?>(author),
      'intro': serializer.toJson<String?>(intro),
      'coverPath': serializer.toJson<String?>(coverPath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredBookMetadataOverride copyWith({
    String? targetKey,
    Value<String?> bookId = const Value.absent(),
    Value<String?> sourceId = const Value.absent(),
    Value<String?> detailUrl = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<String?> author = const Value.absent(),
    Value<String?> intro = const Value.absent(),
    Value<String?> coverPath = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StoredBookMetadataOverride(
    targetKey: targetKey ?? this.targetKey,
    bookId: bookId.present ? bookId.value : this.bookId,
    sourceId: sourceId.present ? sourceId.value : this.sourceId,
    detailUrl: detailUrl.present ? detailUrl.value : this.detailUrl,
    title: title.present ? title.value : this.title,
    author: author.present ? author.value : this.author,
    intro: intro.present ? intro.value : this.intro,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredBookMetadataOverride copyWithCompanion(
    StoredBookMetadataOverridesCompanion data,
  ) {
    return StoredBookMetadataOverride(
      targetKey: data.targetKey.present ? data.targetKey.value : this.targetKey,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      detailUrl: data.detailUrl.present ? data.detailUrl.value : this.detailUrl,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      intro: data.intro.present ? data.intro.value : this.intro,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredBookMetadataOverride(')
          ..write('targetKey: $targetKey, ')
          ..write('bookId: $bookId, ')
          ..write('sourceId: $sourceId, ')
          ..write('detailUrl: $detailUrl, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('intro: $intro, ')
          ..write('coverPath: $coverPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    targetKey,
    bookId,
    sourceId,
    detailUrl,
    title,
    author,
    intro,
    coverPath,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredBookMetadataOverride &&
          other.targetKey == this.targetKey &&
          other.bookId == this.bookId &&
          other.sourceId == this.sourceId &&
          other.detailUrl == this.detailUrl &&
          other.title == this.title &&
          other.author == this.author &&
          other.intro == this.intro &&
          other.coverPath == this.coverPath &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class StoredBookMetadataOverridesCompanion
    extends UpdateCompanion<StoredBookMetadataOverride> {
  final Value<String> targetKey;
  final Value<String?> bookId;
  final Value<String?> sourceId;
  final Value<String?> detailUrl;
  final Value<String?> title;
  final Value<String?> author;
  final Value<String?> intro;
  final Value<String?> coverPath;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StoredBookMetadataOverridesCompanion({
    this.targetKey = const Value.absent(),
    this.bookId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.detailUrl = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.intro = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredBookMetadataOverridesCompanion.insert({
    required String targetKey,
    this.bookId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.detailUrl = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.intro = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : targetKey = Value(targetKey);
  static Insertable<StoredBookMetadataOverride> custom({
    Expression<String>? targetKey,
    Expression<String>? bookId,
    Expression<String>? sourceId,
    Expression<String>? detailUrl,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? intro,
    Expression<String>? coverPath,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (targetKey != null) 'target_key': targetKey,
      if (bookId != null) 'book_id': bookId,
      if (sourceId != null) 'source_id': sourceId,
      if (detailUrl != null) 'detail_url': detailUrl,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (intro != null) 'intro': intro,
      if (coverPath != null) 'cover_path': coverPath,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredBookMetadataOverridesCompanion copyWith({
    Value<String>? targetKey,
    Value<String?>? bookId,
    Value<String?>? sourceId,
    Value<String?>? detailUrl,
    Value<String?>? title,
    Value<String?>? author,
    Value<String?>? intro,
    Value<String?>? coverPath,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StoredBookMetadataOverridesCompanion(
      targetKey: targetKey ?? this.targetKey,
      bookId: bookId ?? this.bookId,
      sourceId: sourceId ?? this.sourceId,
      detailUrl: detailUrl ?? this.detailUrl,
      title: title ?? this.title,
      author: author ?? this.author,
      intro: intro ?? this.intro,
      coverPath: coverPath ?? this.coverPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (targetKey.present) {
      map['target_key'] = Variable<String>(targetKey.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (detailUrl.present) {
      map['detail_url'] = Variable<String>(detailUrl.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (intro.present) {
      map['intro'] = Variable<String>(intro.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
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
    return (StringBuffer('StoredBookMetadataOverridesCompanion(')
          ..write('targetKey: $targetKey, ')
          ..write('bookId: $bookId, ')
          ..write('sourceId: $sourceId, ')
          ..write('detailUrl: $detailUrl, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('intro: $intro, ')
          ..write('coverPath: $coverPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredReadingRecordsTable extends StoredReadingRecords
    with TableInfo<$StoredReadingRecordsTable, StoredReadingRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredReadingRecordsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _detailUrlMeta = const VerificationMeta(
    'detailUrl',
  );
  @override
  late final GeneratedColumn<String> detailUrl = GeneratedColumn<String>(
    'detail_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookTitleMeta = const VerificationMeta(
    'bookTitle',
  );
  @override
  late final GeneratedColumn<String> bookTitle = GeneratedColumn<String>(
    'book_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookAuthorMeta = const VerificationMeta(
    'bookAuthor',
  );
  @override
  late final GeneratedColumn<String> bookAuthor = GeneratedColumn<String>(
    'book_author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastChapterIdMeta = const VerificationMeta(
    'lastChapterId',
  );
  @override
  late final GeneratedColumn<String> lastChapterId = GeneratedColumn<String>(
    'last_chapter_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastChapterTitleMeta = const VerificationMeta(
    'lastChapterTitle',
  );
  @override
  late final GeneratedColumn<String> lastChapterTitle = GeneratedColumn<String>(
    'last_chapter_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastChapterIndexMeta = const VerificationMeta(
    'lastChapterIndex',
  );
  @override
  late final GeneratedColumn<int> lastChapterIndex = GeneratedColumn<int>(
    'last_chapter_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastChapterUrlMeta = const VerificationMeta(
    'lastChapterUrl',
  );
  @override
  late final GeneratedColumn<String> lastChapterUrl = GeneratedColumn<String>(
    'last_chapter_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastPositionRatioMeta = const VerificationMeta(
    'lastPositionRatio',
  );
  @override
  late final GeneratedColumn<double> lastPositionRatio =
      GeneratedColumn<double>(
        'last_position_ratio',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _totalReadMillisMeta = const VerificationMeta(
    'totalReadMillis',
  );
  @override
  late final GeneratedColumn<int> totalReadMillis = GeneratedColumn<int>(
    'total_read_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalReadCharsMeta = const VerificationMeta(
    'totalReadChars',
  );
  @override
  late final GeneratedColumn<int> totalReadChars = GeneratedColumn<int>(
    'total_read_chars',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastReadAtMeta = const VerificationMeta(
    'lastReadAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastReadAt = GeneratedColumn<DateTime>(
    'last_read_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookId,
    sourceId,
    detailUrl,
    bookTitle,
    bookAuthor,
    coverUrl,
    lastChapterId,
    lastChapterTitle,
    lastChapterIndex,
    lastChapterUrl,
    lastPositionRatio,
    totalReadMillis,
    totalReadChars,
    lastReadAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredReadingRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
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
    if (data.containsKey('detail_url')) {
      context.handle(
        _detailUrlMeta,
        detailUrl.isAcceptableOrUnknown(data['detail_url']!, _detailUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_detailUrlMeta);
    }
    if (data.containsKey('book_title')) {
      context.handle(
        _bookTitleMeta,
        bookTitle.isAcceptableOrUnknown(data['book_title']!, _bookTitleMeta),
      );
    } else if (isInserting) {
      context.missing(_bookTitleMeta);
    }
    if (data.containsKey('book_author')) {
      context.handle(
        _bookAuthorMeta,
        bookAuthor.isAcceptableOrUnknown(data['book_author']!, _bookAuthorMeta),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('last_chapter_id')) {
      context.handle(
        _lastChapterIdMeta,
        lastChapterId.isAcceptableOrUnknown(
          data['last_chapter_id']!,
          _lastChapterIdMeta,
        ),
      );
    }
    if (data.containsKey('last_chapter_title')) {
      context.handle(
        _lastChapterTitleMeta,
        lastChapterTitle.isAcceptableOrUnknown(
          data['last_chapter_title']!,
          _lastChapterTitleMeta,
        ),
      );
    }
    if (data.containsKey('last_chapter_index')) {
      context.handle(
        _lastChapterIndexMeta,
        lastChapterIndex.isAcceptableOrUnknown(
          data['last_chapter_index']!,
          _lastChapterIndexMeta,
        ),
      );
    }
    if (data.containsKey('last_chapter_url')) {
      context.handle(
        _lastChapterUrlMeta,
        lastChapterUrl.isAcceptableOrUnknown(
          data['last_chapter_url']!,
          _lastChapterUrlMeta,
        ),
      );
    }
    if (data.containsKey('last_position_ratio')) {
      context.handle(
        _lastPositionRatioMeta,
        lastPositionRatio.isAcceptableOrUnknown(
          data['last_position_ratio']!,
          _lastPositionRatioMeta,
        ),
      );
    }
    if (data.containsKey('total_read_millis')) {
      context.handle(
        _totalReadMillisMeta,
        totalReadMillis.isAcceptableOrUnknown(
          data['total_read_millis']!,
          _totalReadMillisMeta,
        ),
      );
    }
    if (data.containsKey('total_read_chars')) {
      context.handle(
        _totalReadCharsMeta,
        totalReadChars.isAcceptableOrUnknown(
          data['total_read_chars']!,
          _totalReadCharsMeta,
        ),
      );
    }
    if (data.containsKey('last_read_at')) {
      context.handle(
        _lastReadAtMeta,
        lastReadAt.isAcceptableOrUnknown(
          data['last_read_at']!,
          _lastReadAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastReadAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  StoredReadingRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredReadingRecord(
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
      detailUrl:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}detail_url'],
          )!,
      bookTitle:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}book_title'],
          )!,
      bookAuthor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_author'],
      ),
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      lastChapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_chapter_id'],
      ),
      lastChapterTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_chapter_title'],
      ),
      lastChapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_chapter_index'],
      ),
      lastChapterUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_chapter_url'],
      ),
      lastPositionRatio:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}last_position_ratio'],
          )!,
      totalReadMillis:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}total_read_millis'],
          )!,
      totalReadChars:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}total_read_chars'],
          )!,
      lastReadAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}last_read_at'],
          )!,
    );
  }

  @override
  $StoredReadingRecordsTable createAlias(String alias) {
    return $StoredReadingRecordsTable(attachedDatabase, alias);
  }
}

class StoredReadingRecord extends DataClass
    implements Insertable<StoredReadingRecord> {
  final String bookId;
  final String sourceId;
  final String detailUrl;
  final String bookTitle;
  final String? bookAuthor;
  final String? coverUrl;
  final String? lastChapterId;
  final String? lastChapterTitle;
  final int? lastChapterIndex;
  final String? lastChapterUrl;
  final double lastPositionRatio;
  final int totalReadMillis;
  final int totalReadChars;
  final DateTime lastReadAt;
  const StoredReadingRecord({
    required this.bookId,
    required this.sourceId,
    required this.detailUrl,
    required this.bookTitle,
    this.bookAuthor,
    this.coverUrl,
    this.lastChapterId,
    this.lastChapterTitle,
    this.lastChapterIndex,
    this.lastChapterUrl,
    required this.lastPositionRatio,
    required this.totalReadMillis,
    required this.totalReadChars,
    required this.lastReadAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['source_id'] = Variable<String>(sourceId);
    map['detail_url'] = Variable<String>(detailUrl);
    map['book_title'] = Variable<String>(bookTitle);
    if (!nullToAbsent || bookAuthor != null) {
      map['book_author'] = Variable<String>(bookAuthor);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || lastChapterId != null) {
      map['last_chapter_id'] = Variable<String>(lastChapterId);
    }
    if (!nullToAbsent || lastChapterTitle != null) {
      map['last_chapter_title'] = Variable<String>(lastChapterTitle);
    }
    if (!nullToAbsent || lastChapterIndex != null) {
      map['last_chapter_index'] = Variable<int>(lastChapterIndex);
    }
    if (!nullToAbsent || lastChapterUrl != null) {
      map['last_chapter_url'] = Variable<String>(lastChapterUrl);
    }
    map['last_position_ratio'] = Variable<double>(lastPositionRatio);
    map['total_read_millis'] = Variable<int>(totalReadMillis);
    map['total_read_chars'] = Variable<int>(totalReadChars);
    map['last_read_at'] = Variable<DateTime>(lastReadAt);
    return map;
  }

  StoredReadingRecordsCompanion toCompanion(bool nullToAbsent) {
    return StoredReadingRecordsCompanion(
      bookId: Value(bookId),
      sourceId: Value(sourceId),
      detailUrl: Value(detailUrl),
      bookTitle: Value(bookTitle),
      bookAuthor:
          bookAuthor == null && nullToAbsent
              ? const Value.absent()
              : Value(bookAuthor),
      coverUrl:
          coverUrl == null && nullToAbsent
              ? const Value.absent()
              : Value(coverUrl),
      lastChapterId:
          lastChapterId == null && nullToAbsent
              ? const Value.absent()
              : Value(lastChapterId),
      lastChapterTitle:
          lastChapterTitle == null && nullToAbsent
              ? const Value.absent()
              : Value(lastChapterTitle),
      lastChapterIndex:
          lastChapterIndex == null && nullToAbsent
              ? const Value.absent()
              : Value(lastChapterIndex),
      lastChapterUrl:
          lastChapterUrl == null && nullToAbsent
              ? const Value.absent()
              : Value(lastChapterUrl),
      lastPositionRatio: Value(lastPositionRatio),
      totalReadMillis: Value(totalReadMillis),
      totalReadChars: Value(totalReadChars),
      lastReadAt: Value(lastReadAt),
    );
  }

  factory StoredReadingRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredReadingRecord(
      bookId: serializer.fromJson<String>(json['bookId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      detailUrl: serializer.fromJson<String>(json['detailUrl']),
      bookTitle: serializer.fromJson<String>(json['bookTitle']),
      bookAuthor: serializer.fromJson<String?>(json['bookAuthor']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      lastChapterId: serializer.fromJson<String?>(json['lastChapterId']),
      lastChapterTitle: serializer.fromJson<String?>(json['lastChapterTitle']),
      lastChapterIndex: serializer.fromJson<int?>(json['lastChapterIndex']),
      lastChapterUrl: serializer.fromJson<String?>(json['lastChapterUrl']),
      lastPositionRatio: serializer.fromJson<double>(json['lastPositionRatio']),
      totalReadMillis: serializer.fromJson<int>(json['totalReadMillis']),
      totalReadChars: serializer.fromJson<int>(json['totalReadChars']),
      lastReadAt: serializer.fromJson<DateTime>(json['lastReadAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'sourceId': serializer.toJson<String>(sourceId),
      'detailUrl': serializer.toJson<String>(detailUrl),
      'bookTitle': serializer.toJson<String>(bookTitle),
      'bookAuthor': serializer.toJson<String?>(bookAuthor),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'lastChapterId': serializer.toJson<String?>(lastChapterId),
      'lastChapterTitle': serializer.toJson<String?>(lastChapterTitle),
      'lastChapterIndex': serializer.toJson<int?>(lastChapterIndex),
      'lastChapterUrl': serializer.toJson<String?>(lastChapterUrl),
      'lastPositionRatio': serializer.toJson<double>(lastPositionRatio),
      'totalReadMillis': serializer.toJson<int>(totalReadMillis),
      'totalReadChars': serializer.toJson<int>(totalReadChars),
      'lastReadAt': serializer.toJson<DateTime>(lastReadAt),
    };
  }

  StoredReadingRecord copyWith({
    String? bookId,
    String? sourceId,
    String? detailUrl,
    String? bookTitle,
    Value<String?> bookAuthor = const Value.absent(),
    Value<String?> coverUrl = const Value.absent(),
    Value<String?> lastChapterId = const Value.absent(),
    Value<String?> lastChapterTitle = const Value.absent(),
    Value<int?> lastChapterIndex = const Value.absent(),
    Value<String?> lastChapterUrl = const Value.absent(),
    double? lastPositionRatio,
    int? totalReadMillis,
    int? totalReadChars,
    DateTime? lastReadAt,
  }) => StoredReadingRecord(
    bookId: bookId ?? this.bookId,
    sourceId: sourceId ?? this.sourceId,
    detailUrl: detailUrl ?? this.detailUrl,
    bookTitle: bookTitle ?? this.bookTitle,
    bookAuthor: bookAuthor.present ? bookAuthor.value : this.bookAuthor,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    lastChapterId:
        lastChapterId.present ? lastChapterId.value : this.lastChapterId,
    lastChapterTitle:
        lastChapterTitle.present
            ? lastChapterTitle.value
            : this.lastChapterTitle,
    lastChapterIndex:
        lastChapterIndex.present
            ? lastChapterIndex.value
            : this.lastChapterIndex,
    lastChapterUrl:
        lastChapterUrl.present ? lastChapterUrl.value : this.lastChapterUrl,
    lastPositionRatio: lastPositionRatio ?? this.lastPositionRatio,
    totalReadMillis: totalReadMillis ?? this.totalReadMillis,
    totalReadChars: totalReadChars ?? this.totalReadChars,
    lastReadAt: lastReadAt ?? this.lastReadAt,
  );
  StoredReadingRecord copyWithCompanion(StoredReadingRecordsCompanion data) {
    return StoredReadingRecord(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      detailUrl: data.detailUrl.present ? data.detailUrl.value : this.detailUrl,
      bookTitle: data.bookTitle.present ? data.bookTitle.value : this.bookTitle,
      bookAuthor:
          data.bookAuthor.present ? data.bookAuthor.value : this.bookAuthor,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      lastChapterId:
          data.lastChapterId.present
              ? data.lastChapterId.value
              : this.lastChapterId,
      lastChapterTitle:
          data.lastChapterTitle.present
              ? data.lastChapterTitle.value
              : this.lastChapterTitle,
      lastChapterIndex:
          data.lastChapterIndex.present
              ? data.lastChapterIndex.value
              : this.lastChapterIndex,
      lastChapterUrl:
          data.lastChapterUrl.present
              ? data.lastChapterUrl.value
              : this.lastChapterUrl,
      lastPositionRatio:
          data.lastPositionRatio.present
              ? data.lastPositionRatio.value
              : this.lastPositionRatio,
      totalReadMillis:
          data.totalReadMillis.present
              ? data.totalReadMillis.value
              : this.totalReadMillis,
      totalReadChars:
          data.totalReadChars.present
              ? data.totalReadChars.value
              : this.totalReadChars,
      lastReadAt:
          data.lastReadAt.present ? data.lastReadAt.value : this.lastReadAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredReadingRecord(')
          ..write('bookId: $bookId, ')
          ..write('sourceId: $sourceId, ')
          ..write('detailUrl: $detailUrl, ')
          ..write('bookTitle: $bookTitle, ')
          ..write('bookAuthor: $bookAuthor, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('lastChapterId: $lastChapterId, ')
          ..write('lastChapterTitle: $lastChapterTitle, ')
          ..write('lastChapterIndex: $lastChapterIndex, ')
          ..write('lastChapterUrl: $lastChapterUrl, ')
          ..write('lastPositionRatio: $lastPositionRatio, ')
          ..write('totalReadMillis: $totalReadMillis, ')
          ..write('totalReadChars: $totalReadChars, ')
          ..write('lastReadAt: $lastReadAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    bookId,
    sourceId,
    detailUrl,
    bookTitle,
    bookAuthor,
    coverUrl,
    lastChapterId,
    lastChapterTitle,
    lastChapterIndex,
    lastChapterUrl,
    lastPositionRatio,
    totalReadMillis,
    totalReadChars,
    lastReadAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredReadingRecord &&
          other.bookId == this.bookId &&
          other.sourceId == this.sourceId &&
          other.detailUrl == this.detailUrl &&
          other.bookTitle == this.bookTitle &&
          other.bookAuthor == this.bookAuthor &&
          other.coverUrl == this.coverUrl &&
          other.lastChapterId == this.lastChapterId &&
          other.lastChapterTitle == this.lastChapterTitle &&
          other.lastChapterIndex == this.lastChapterIndex &&
          other.lastChapterUrl == this.lastChapterUrl &&
          other.lastPositionRatio == this.lastPositionRatio &&
          other.totalReadMillis == this.totalReadMillis &&
          other.totalReadChars == this.totalReadChars &&
          other.lastReadAt == this.lastReadAt);
}

class StoredReadingRecordsCompanion
    extends UpdateCompanion<StoredReadingRecord> {
  final Value<String> bookId;
  final Value<String> sourceId;
  final Value<String> detailUrl;
  final Value<String> bookTitle;
  final Value<String?> bookAuthor;
  final Value<String?> coverUrl;
  final Value<String?> lastChapterId;
  final Value<String?> lastChapterTitle;
  final Value<int?> lastChapterIndex;
  final Value<String?> lastChapterUrl;
  final Value<double> lastPositionRatio;
  final Value<int> totalReadMillis;
  final Value<int> totalReadChars;
  final Value<DateTime> lastReadAt;
  final Value<int> rowid;
  const StoredReadingRecordsCompanion({
    this.bookId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.detailUrl = const Value.absent(),
    this.bookTitle = const Value.absent(),
    this.bookAuthor = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.lastChapterId = const Value.absent(),
    this.lastChapterTitle = const Value.absent(),
    this.lastChapterIndex = const Value.absent(),
    this.lastChapterUrl = const Value.absent(),
    this.lastPositionRatio = const Value.absent(),
    this.totalReadMillis = const Value.absent(),
    this.totalReadChars = const Value.absent(),
    this.lastReadAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredReadingRecordsCompanion.insert({
    required String bookId,
    required String sourceId,
    required String detailUrl,
    required String bookTitle,
    this.bookAuthor = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.lastChapterId = const Value.absent(),
    this.lastChapterTitle = const Value.absent(),
    this.lastChapterIndex = const Value.absent(),
    this.lastChapterUrl = const Value.absent(),
    this.lastPositionRatio = const Value.absent(),
    this.totalReadMillis = const Value.absent(),
    this.totalReadChars = const Value.absent(),
    required DateTime lastReadAt,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       sourceId = Value(sourceId),
       detailUrl = Value(detailUrl),
       bookTitle = Value(bookTitle),
       lastReadAt = Value(lastReadAt);
  static Insertable<StoredReadingRecord> custom({
    Expression<String>? bookId,
    Expression<String>? sourceId,
    Expression<String>? detailUrl,
    Expression<String>? bookTitle,
    Expression<String>? bookAuthor,
    Expression<String>? coverUrl,
    Expression<String>? lastChapterId,
    Expression<String>? lastChapterTitle,
    Expression<int>? lastChapterIndex,
    Expression<String>? lastChapterUrl,
    Expression<double>? lastPositionRatio,
    Expression<int>? totalReadMillis,
    Expression<int>? totalReadChars,
    Expression<DateTime>? lastReadAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (sourceId != null) 'source_id': sourceId,
      if (detailUrl != null) 'detail_url': detailUrl,
      if (bookTitle != null) 'book_title': bookTitle,
      if (bookAuthor != null) 'book_author': bookAuthor,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (lastChapterId != null) 'last_chapter_id': lastChapterId,
      if (lastChapterTitle != null) 'last_chapter_title': lastChapterTitle,
      if (lastChapterIndex != null) 'last_chapter_index': lastChapterIndex,
      if (lastChapterUrl != null) 'last_chapter_url': lastChapterUrl,
      if (lastPositionRatio != null) 'last_position_ratio': lastPositionRatio,
      if (totalReadMillis != null) 'total_read_millis': totalReadMillis,
      if (totalReadChars != null) 'total_read_chars': totalReadChars,
      if (lastReadAt != null) 'last_read_at': lastReadAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredReadingRecordsCompanion copyWith({
    Value<String>? bookId,
    Value<String>? sourceId,
    Value<String>? detailUrl,
    Value<String>? bookTitle,
    Value<String?>? bookAuthor,
    Value<String?>? coverUrl,
    Value<String?>? lastChapterId,
    Value<String?>? lastChapterTitle,
    Value<int?>? lastChapterIndex,
    Value<String?>? lastChapterUrl,
    Value<double>? lastPositionRatio,
    Value<int>? totalReadMillis,
    Value<int>? totalReadChars,
    Value<DateTime>? lastReadAt,
    Value<int>? rowid,
  }) {
    return StoredReadingRecordsCompanion(
      bookId: bookId ?? this.bookId,
      sourceId: sourceId ?? this.sourceId,
      detailUrl: detailUrl ?? this.detailUrl,
      bookTitle: bookTitle ?? this.bookTitle,
      bookAuthor: bookAuthor ?? this.bookAuthor,
      coverUrl: coverUrl ?? this.coverUrl,
      lastChapterId: lastChapterId ?? this.lastChapterId,
      lastChapterTitle: lastChapterTitle ?? this.lastChapterTitle,
      lastChapterIndex: lastChapterIndex ?? this.lastChapterIndex,
      lastChapterUrl: lastChapterUrl ?? this.lastChapterUrl,
      lastPositionRatio: lastPositionRatio ?? this.lastPositionRatio,
      totalReadMillis: totalReadMillis ?? this.totalReadMillis,
      totalReadChars: totalReadChars ?? this.totalReadChars,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (detailUrl.present) {
      map['detail_url'] = Variable<String>(detailUrl.value);
    }
    if (bookTitle.present) {
      map['book_title'] = Variable<String>(bookTitle.value);
    }
    if (bookAuthor.present) {
      map['book_author'] = Variable<String>(bookAuthor.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (lastChapterId.present) {
      map['last_chapter_id'] = Variable<String>(lastChapterId.value);
    }
    if (lastChapterTitle.present) {
      map['last_chapter_title'] = Variable<String>(lastChapterTitle.value);
    }
    if (lastChapterIndex.present) {
      map['last_chapter_index'] = Variable<int>(lastChapterIndex.value);
    }
    if (lastChapterUrl.present) {
      map['last_chapter_url'] = Variable<String>(lastChapterUrl.value);
    }
    if (lastPositionRatio.present) {
      map['last_position_ratio'] = Variable<double>(lastPositionRatio.value);
    }
    if (totalReadMillis.present) {
      map['total_read_millis'] = Variable<int>(totalReadMillis.value);
    }
    if (totalReadChars.present) {
      map['total_read_chars'] = Variable<int>(totalReadChars.value);
    }
    if (lastReadAt.present) {
      map['last_read_at'] = Variable<DateTime>(lastReadAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoredReadingRecordsCompanion(')
          ..write('bookId: $bookId, ')
          ..write('sourceId: $sourceId, ')
          ..write('detailUrl: $detailUrl, ')
          ..write('bookTitle: $bookTitle, ')
          ..write('bookAuthor: $bookAuthor, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('lastChapterId: $lastChapterId, ')
          ..write('lastChapterTitle: $lastChapterTitle, ')
          ..write('lastChapterIndex: $lastChapterIndex, ')
          ..write('lastChapterUrl: $lastChapterUrl, ')
          ..write('lastPositionRatio: $lastPositionRatio, ')
          ..write('totalReadMillis: $totalReadMillis, ')
          ..write('totalReadChars: $totalReadChars, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredReadingRecordDaysTable extends StoredReadingRecordDays
    with TableInfo<$StoredReadingRecordDaysTable, StoredReadingRecordDay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredReadingRecordDaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateKeyMeta = const VerificationMeta(
    'dateKey',
  );
  @override
  late final GeneratedColumn<String> dateKey = GeneratedColumn<String>(
    'date_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookTitleMeta = const VerificationMeta(
    'bookTitle',
  );
  @override
  late final GeneratedColumn<String> bookTitle = GeneratedColumn<String>(
    'book_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookAuthorMeta = const VerificationMeta(
    'bookAuthor',
  );
  @override
  late final GeneratedColumn<String> bookAuthor = GeneratedColumn<String>(
    'book_author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _readMillisMeta = const VerificationMeta(
    'readMillis',
  );
  @override
  late final GeneratedColumn<int> readMillis = GeneratedColumn<int>(
    'read_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _readCharsMeta = const VerificationMeta(
    'readChars',
  );
  @override
  late final GeneratedColumn<int> readChars = GeneratedColumn<int>(
    'read_chars',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _firstReadAtMeta = const VerificationMeta(
    'firstReadAt',
  );
  @override
  late final GeneratedColumn<DateTime> firstReadAt = GeneratedColumn<DateTime>(
    'first_read_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastReadAtMeta = const VerificationMeta(
    'lastReadAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastReadAt = GeneratedColumn<DateTime>(
    'last_read_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookId,
    dateKey,
    bookTitle,
    bookAuthor,
    coverUrl,
    readMillis,
    readChars,
    firstReadAt,
    lastReadAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_record_days';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredReadingRecordDay> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('date_key')) {
      context.handle(
        _dateKeyMeta,
        dateKey.isAcceptableOrUnknown(data['date_key']!, _dateKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dateKeyMeta);
    }
    if (data.containsKey('book_title')) {
      context.handle(
        _bookTitleMeta,
        bookTitle.isAcceptableOrUnknown(data['book_title']!, _bookTitleMeta),
      );
    } else if (isInserting) {
      context.missing(_bookTitleMeta);
    }
    if (data.containsKey('book_author')) {
      context.handle(
        _bookAuthorMeta,
        bookAuthor.isAcceptableOrUnknown(data['book_author']!, _bookAuthorMeta),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('read_millis')) {
      context.handle(
        _readMillisMeta,
        readMillis.isAcceptableOrUnknown(data['read_millis']!, _readMillisMeta),
      );
    }
    if (data.containsKey('read_chars')) {
      context.handle(
        _readCharsMeta,
        readChars.isAcceptableOrUnknown(data['read_chars']!, _readCharsMeta),
      );
    }
    if (data.containsKey('first_read_at')) {
      context.handle(
        _firstReadAtMeta,
        firstReadAt.isAcceptableOrUnknown(
          data['first_read_at']!,
          _firstReadAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstReadAtMeta);
    }
    if (data.containsKey('last_read_at')) {
      context.handle(
        _lastReadAtMeta,
        lastReadAt.isAcceptableOrUnknown(
          data['last_read_at']!,
          _lastReadAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastReadAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId, dateKey};
  @override
  StoredReadingRecordDay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredReadingRecordDay(
      bookId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}book_id'],
          )!,
      dateKey:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}date_key'],
          )!,
      bookTitle:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}book_title'],
          )!,
      bookAuthor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_author'],
      ),
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      readMillis:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}read_millis'],
          )!,
      readChars:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}read_chars'],
          )!,
      firstReadAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}first_read_at'],
          )!,
      lastReadAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}last_read_at'],
          )!,
    );
  }

  @override
  $StoredReadingRecordDaysTable createAlias(String alias) {
    return $StoredReadingRecordDaysTable(attachedDatabase, alias);
  }
}

class StoredReadingRecordDay extends DataClass
    implements Insertable<StoredReadingRecordDay> {
  final String bookId;
  final String dateKey;
  final String bookTitle;
  final String? bookAuthor;
  final String? coverUrl;
  final int readMillis;
  final int readChars;
  final DateTime firstReadAt;
  final DateTime lastReadAt;
  const StoredReadingRecordDay({
    required this.bookId,
    required this.dateKey,
    required this.bookTitle,
    this.bookAuthor,
    this.coverUrl,
    required this.readMillis,
    required this.readChars,
    required this.firstReadAt,
    required this.lastReadAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['date_key'] = Variable<String>(dateKey);
    map['book_title'] = Variable<String>(bookTitle);
    if (!nullToAbsent || bookAuthor != null) {
      map['book_author'] = Variable<String>(bookAuthor);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    map['read_millis'] = Variable<int>(readMillis);
    map['read_chars'] = Variable<int>(readChars);
    map['first_read_at'] = Variable<DateTime>(firstReadAt);
    map['last_read_at'] = Variable<DateTime>(lastReadAt);
    return map;
  }

  StoredReadingRecordDaysCompanion toCompanion(bool nullToAbsent) {
    return StoredReadingRecordDaysCompanion(
      bookId: Value(bookId),
      dateKey: Value(dateKey),
      bookTitle: Value(bookTitle),
      bookAuthor:
          bookAuthor == null && nullToAbsent
              ? const Value.absent()
              : Value(bookAuthor),
      coverUrl:
          coverUrl == null && nullToAbsent
              ? const Value.absent()
              : Value(coverUrl),
      readMillis: Value(readMillis),
      readChars: Value(readChars),
      firstReadAt: Value(firstReadAt),
      lastReadAt: Value(lastReadAt),
    );
  }

  factory StoredReadingRecordDay.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredReadingRecordDay(
      bookId: serializer.fromJson<String>(json['bookId']),
      dateKey: serializer.fromJson<String>(json['dateKey']),
      bookTitle: serializer.fromJson<String>(json['bookTitle']),
      bookAuthor: serializer.fromJson<String?>(json['bookAuthor']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      readMillis: serializer.fromJson<int>(json['readMillis']),
      readChars: serializer.fromJson<int>(json['readChars']),
      firstReadAt: serializer.fromJson<DateTime>(json['firstReadAt']),
      lastReadAt: serializer.fromJson<DateTime>(json['lastReadAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'dateKey': serializer.toJson<String>(dateKey),
      'bookTitle': serializer.toJson<String>(bookTitle),
      'bookAuthor': serializer.toJson<String?>(bookAuthor),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'readMillis': serializer.toJson<int>(readMillis),
      'readChars': serializer.toJson<int>(readChars),
      'firstReadAt': serializer.toJson<DateTime>(firstReadAt),
      'lastReadAt': serializer.toJson<DateTime>(lastReadAt),
    };
  }

  StoredReadingRecordDay copyWith({
    String? bookId,
    String? dateKey,
    String? bookTitle,
    Value<String?> bookAuthor = const Value.absent(),
    Value<String?> coverUrl = const Value.absent(),
    int? readMillis,
    int? readChars,
    DateTime? firstReadAt,
    DateTime? lastReadAt,
  }) => StoredReadingRecordDay(
    bookId: bookId ?? this.bookId,
    dateKey: dateKey ?? this.dateKey,
    bookTitle: bookTitle ?? this.bookTitle,
    bookAuthor: bookAuthor.present ? bookAuthor.value : this.bookAuthor,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    readMillis: readMillis ?? this.readMillis,
    readChars: readChars ?? this.readChars,
    firstReadAt: firstReadAt ?? this.firstReadAt,
    lastReadAt: lastReadAt ?? this.lastReadAt,
  );
  StoredReadingRecordDay copyWithCompanion(
    StoredReadingRecordDaysCompanion data,
  ) {
    return StoredReadingRecordDay(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      dateKey: data.dateKey.present ? data.dateKey.value : this.dateKey,
      bookTitle: data.bookTitle.present ? data.bookTitle.value : this.bookTitle,
      bookAuthor:
          data.bookAuthor.present ? data.bookAuthor.value : this.bookAuthor,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      readMillis:
          data.readMillis.present ? data.readMillis.value : this.readMillis,
      readChars: data.readChars.present ? data.readChars.value : this.readChars,
      firstReadAt:
          data.firstReadAt.present ? data.firstReadAt.value : this.firstReadAt,
      lastReadAt:
          data.lastReadAt.present ? data.lastReadAt.value : this.lastReadAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredReadingRecordDay(')
          ..write('bookId: $bookId, ')
          ..write('dateKey: $dateKey, ')
          ..write('bookTitle: $bookTitle, ')
          ..write('bookAuthor: $bookAuthor, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('readMillis: $readMillis, ')
          ..write('readChars: $readChars, ')
          ..write('firstReadAt: $firstReadAt, ')
          ..write('lastReadAt: $lastReadAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    bookId,
    dateKey,
    bookTitle,
    bookAuthor,
    coverUrl,
    readMillis,
    readChars,
    firstReadAt,
    lastReadAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredReadingRecordDay &&
          other.bookId == this.bookId &&
          other.dateKey == this.dateKey &&
          other.bookTitle == this.bookTitle &&
          other.bookAuthor == this.bookAuthor &&
          other.coverUrl == this.coverUrl &&
          other.readMillis == this.readMillis &&
          other.readChars == this.readChars &&
          other.firstReadAt == this.firstReadAt &&
          other.lastReadAt == this.lastReadAt);
}

class StoredReadingRecordDaysCompanion
    extends UpdateCompanion<StoredReadingRecordDay> {
  final Value<String> bookId;
  final Value<String> dateKey;
  final Value<String> bookTitle;
  final Value<String?> bookAuthor;
  final Value<String?> coverUrl;
  final Value<int> readMillis;
  final Value<int> readChars;
  final Value<DateTime> firstReadAt;
  final Value<DateTime> lastReadAt;
  final Value<int> rowid;
  const StoredReadingRecordDaysCompanion({
    this.bookId = const Value.absent(),
    this.dateKey = const Value.absent(),
    this.bookTitle = const Value.absent(),
    this.bookAuthor = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.readMillis = const Value.absent(),
    this.readChars = const Value.absent(),
    this.firstReadAt = const Value.absent(),
    this.lastReadAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredReadingRecordDaysCompanion.insert({
    required String bookId,
    required String dateKey,
    required String bookTitle,
    this.bookAuthor = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.readMillis = const Value.absent(),
    this.readChars = const Value.absent(),
    required DateTime firstReadAt,
    required DateTime lastReadAt,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       dateKey = Value(dateKey),
       bookTitle = Value(bookTitle),
       firstReadAt = Value(firstReadAt),
       lastReadAt = Value(lastReadAt);
  static Insertable<StoredReadingRecordDay> custom({
    Expression<String>? bookId,
    Expression<String>? dateKey,
    Expression<String>? bookTitle,
    Expression<String>? bookAuthor,
    Expression<String>? coverUrl,
    Expression<int>? readMillis,
    Expression<int>? readChars,
    Expression<DateTime>? firstReadAt,
    Expression<DateTime>? lastReadAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (dateKey != null) 'date_key': dateKey,
      if (bookTitle != null) 'book_title': bookTitle,
      if (bookAuthor != null) 'book_author': bookAuthor,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (readMillis != null) 'read_millis': readMillis,
      if (readChars != null) 'read_chars': readChars,
      if (firstReadAt != null) 'first_read_at': firstReadAt,
      if (lastReadAt != null) 'last_read_at': lastReadAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredReadingRecordDaysCompanion copyWith({
    Value<String>? bookId,
    Value<String>? dateKey,
    Value<String>? bookTitle,
    Value<String?>? bookAuthor,
    Value<String?>? coverUrl,
    Value<int>? readMillis,
    Value<int>? readChars,
    Value<DateTime>? firstReadAt,
    Value<DateTime>? lastReadAt,
    Value<int>? rowid,
  }) {
    return StoredReadingRecordDaysCompanion(
      bookId: bookId ?? this.bookId,
      dateKey: dateKey ?? this.dateKey,
      bookTitle: bookTitle ?? this.bookTitle,
      bookAuthor: bookAuthor ?? this.bookAuthor,
      coverUrl: coverUrl ?? this.coverUrl,
      readMillis: readMillis ?? this.readMillis,
      readChars: readChars ?? this.readChars,
      firstReadAt: firstReadAt ?? this.firstReadAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (dateKey.present) {
      map['date_key'] = Variable<String>(dateKey.value);
    }
    if (bookTitle.present) {
      map['book_title'] = Variable<String>(bookTitle.value);
    }
    if (bookAuthor.present) {
      map['book_author'] = Variable<String>(bookAuthor.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (readMillis.present) {
      map['read_millis'] = Variable<int>(readMillis.value);
    }
    if (readChars.present) {
      map['read_chars'] = Variable<int>(readChars.value);
    }
    if (firstReadAt.present) {
      map['first_read_at'] = Variable<DateTime>(firstReadAt.value);
    }
    if (lastReadAt.present) {
      map['last_read_at'] = Variable<DateTime>(lastReadAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoredReadingRecordDaysCompanion(')
          ..write('bookId: $bookId, ')
          ..write('dateKey: $dateKey, ')
          ..write('bookTitle: $bookTitle, ')
          ..write('bookAuthor: $bookAuthor, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('readMillis: $readMillis, ')
          ..write('readChars: $readChars, ')
          ..write('firstReadAt: $firstReadAt, ')
          ..write('lastReadAt: $lastReadAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredReadingRecordSessionsTable extends StoredReadingRecordSessions
    with
        TableInfo<
          $StoredReadingRecordSessionsTable,
          StoredReadingRecordSession
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredReadingRecordSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
  static const VerificationMeta _detailUrlMeta = const VerificationMeta(
    'detailUrl',
  );
  @override
  late final GeneratedColumn<String> detailUrl = GeneratedColumn<String>(
    'detail_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookTitleMeta = const VerificationMeta(
    'bookTitle',
  );
  @override
  late final GeneratedColumn<String> bookTitle = GeneratedColumn<String>(
    'book_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookAuthorMeta = const VerificationMeta(
    'bookAuthor',
  );
  @override
  late final GeneratedColumn<String> bookAuthor = GeneratedColumn<String>(
    'book_author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<String> chapterId = GeneratedColumn<String>(
    'chapter_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _chapterIndexMeta = const VerificationMeta(
    'chapterIndex',
  );
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
    'chapter_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chapterUrlMeta = const VerificationMeta(
    'chapterUrl',
  );
  @override
  late final GeneratedColumn<String> chapterUrl = GeneratedColumn<String>(
    'chapter_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startAtMeta = const VerificationMeta(
    'startAt',
  );
  @override
  late final GeneratedColumn<DateTime> startAt = GeneratedColumn<DateTime>(
    'start_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endAtMeta = const VerificationMeta('endAt');
  @override
  late final GeneratedColumn<DateTime> endAt = GeneratedColumn<DateTime>(
    'end_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMillisMeta = const VerificationMeta(
    'durationMillis',
  );
  @override
  late final GeneratedColumn<int> durationMillis = GeneratedColumn<int>(
    'duration_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _readCharsMeta = const VerificationMeta(
    'readChars',
  );
  @override
  late final GeneratedColumn<int> readChars = GeneratedColumn<int>(
    'read_chars',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _startPositionRatioMeta =
      const VerificationMeta('startPositionRatio');
  @override
  late final GeneratedColumn<double> startPositionRatio =
      GeneratedColumn<double>(
        'start_position_ratio',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _endPositionRatioMeta = const VerificationMeta(
    'endPositionRatio',
  );
  @override
  late final GeneratedColumn<double> endPositionRatio = GeneratedColumn<double>(
    'end_position_ratio',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    sourceId,
    detailUrl,
    bookTitle,
    bookAuthor,
    coverUrl,
    chapterId,
    chapterTitle,
    chapterIndex,
    chapterUrl,
    startAt,
    endAt,
    durationMillis,
    readChars,
    startPositionRatio,
    endPositionRatio,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_record_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredReadingRecordSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
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
    if (data.containsKey('detail_url')) {
      context.handle(
        _detailUrlMeta,
        detailUrl.isAcceptableOrUnknown(data['detail_url']!, _detailUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_detailUrlMeta);
    }
    if (data.containsKey('book_title')) {
      context.handle(
        _bookTitleMeta,
        bookTitle.isAcceptableOrUnknown(data['book_title']!, _bookTitleMeta),
      );
    } else if (isInserting) {
      context.missing(_bookTitleMeta);
    }
    if (data.containsKey('book_author')) {
      context.handle(
        _bookAuthorMeta,
        bookAuthor.isAcceptableOrUnknown(data['book_author']!, _bookAuthorMeta),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
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
    if (data.containsKey('chapter_index')) {
      context.handle(
        _chapterIndexMeta,
        chapterIndex.isAcceptableOrUnknown(
          data['chapter_index']!,
          _chapterIndexMeta,
        ),
      );
    }
    if (data.containsKey('chapter_url')) {
      context.handle(
        _chapterUrlMeta,
        chapterUrl.isAcceptableOrUnknown(data['chapter_url']!, _chapterUrlMeta),
      );
    }
    if (data.containsKey('start_at')) {
      context.handle(
        _startAtMeta,
        startAt.isAcceptableOrUnknown(data['start_at']!, _startAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startAtMeta);
    }
    if (data.containsKey('end_at')) {
      context.handle(
        _endAtMeta,
        endAt.isAcceptableOrUnknown(data['end_at']!, _endAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endAtMeta);
    }
    if (data.containsKey('duration_millis')) {
      context.handle(
        _durationMillisMeta,
        durationMillis.isAcceptableOrUnknown(
          data['duration_millis']!,
          _durationMillisMeta,
        ),
      );
    }
    if (data.containsKey('read_chars')) {
      context.handle(
        _readCharsMeta,
        readChars.isAcceptableOrUnknown(data['read_chars']!, _readCharsMeta),
      );
    }
    if (data.containsKey('start_position_ratio')) {
      context.handle(
        _startPositionRatioMeta,
        startPositionRatio.isAcceptableOrUnknown(
          data['start_position_ratio']!,
          _startPositionRatioMeta,
        ),
      );
    }
    if (data.containsKey('end_position_ratio')) {
      context.handle(
        _endPositionRatioMeta,
        endPositionRatio.isAcceptableOrUnknown(
          data['end_position_ratio']!,
          _endPositionRatioMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredReadingRecordSession map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredReadingRecordSession(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
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
      detailUrl:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}detail_url'],
          )!,
      bookTitle:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}book_title'],
          )!,
      bookAuthor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_author'],
      ),
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      chapterId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_id'],
      ),
      chapterTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_title'],
      ),
      chapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_index'],
      ),
      chapterUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_url'],
      ),
      startAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}start_at'],
          )!,
      endAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}end_at'],
          )!,
      durationMillis:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}duration_millis'],
          )!,
      readChars:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}read_chars'],
          )!,
      startPositionRatio:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}start_position_ratio'],
          )!,
      endPositionRatio:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}end_position_ratio'],
          )!,
    );
  }

  @override
  $StoredReadingRecordSessionsTable createAlias(String alias) {
    return $StoredReadingRecordSessionsTable(attachedDatabase, alias);
  }
}

class StoredReadingRecordSession extends DataClass
    implements Insertable<StoredReadingRecordSession> {
  final int id;
  final String bookId;
  final String sourceId;
  final String detailUrl;
  final String bookTitle;
  final String? bookAuthor;
  final String? coverUrl;
  final String? chapterId;
  final String? chapterTitle;
  final int? chapterIndex;
  final String? chapterUrl;
  final DateTime startAt;
  final DateTime endAt;
  final int durationMillis;
  final int readChars;
  final double startPositionRatio;
  final double endPositionRatio;
  const StoredReadingRecordSession({
    required this.id,
    required this.bookId,
    required this.sourceId,
    required this.detailUrl,
    required this.bookTitle,
    this.bookAuthor,
    this.coverUrl,
    this.chapterId,
    this.chapterTitle,
    this.chapterIndex,
    this.chapterUrl,
    required this.startAt,
    required this.endAt,
    required this.durationMillis,
    required this.readChars,
    required this.startPositionRatio,
    required this.endPositionRatio,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['book_id'] = Variable<String>(bookId);
    map['source_id'] = Variable<String>(sourceId);
    map['detail_url'] = Variable<String>(detailUrl);
    map['book_title'] = Variable<String>(bookTitle);
    if (!nullToAbsent || bookAuthor != null) {
      map['book_author'] = Variable<String>(bookAuthor);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || chapterId != null) {
      map['chapter_id'] = Variable<String>(chapterId);
    }
    if (!nullToAbsent || chapterTitle != null) {
      map['chapter_title'] = Variable<String>(chapterTitle);
    }
    if (!nullToAbsent || chapterIndex != null) {
      map['chapter_index'] = Variable<int>(chapterIndex);
    }
    if (!nullToAbsent || chapterUrl != null) {
      map['chapter_url'] = Variable<String>(chapterUrl);
    }
    map['start_at'] = Variable<DateTime>(startAt);
    map['end_at'] = Variable<DateTime>(endAt);
    map['duration_millis'] = Variable<int>(durationMillis);
    map['read_chars'] = Variable<int>(readChars);
    map['start_position_ratio'] = Variable<double>(startPositionRatio);
    map['end_position_ratio'] = Variable<double>(endPositionRatio);
    return map;
  }

  StoredReadingRecordSessionsCompanion toCompanion(bool nullToAbsent) {
    return StoredReadingRecordSessionsCompanion(
      id: Value(id),
      bookId: Value(bookId),
      sourceId: Value(sourceId),
      detailUrl: Value(detailUrl),
      bookTitle: Value(bookTitle),
      bookAuthor:
          bookAuthor == null && nullToAbsent
              ? const Value.absent()
              : Value(bookAuthor),
      coverUrl:
          coverUrl == null && nullToAbsent
              ? const Value.absent()
              : Value(coverUrl),
      chapterId:
          chapterId == null && nullToAbsent
              ? const Value.absent()
              : Value(chapterId),
      chapterTitle:
          chapterTitle == null && nullToAbsent
              ? const Value.absent()
              : Value(chapterTitle),
      chapterIndex:
          chapterIndex == null && nullToAbsent
              ? const Value.absent()
              : Value(chapterIndex),
      chapterUrl:
          chapterUrl == null && nullToAbsent
              ? const Value.absent()
              : Value(chapterUrl),
      startAt: Value(startAt),
      endAt: Value(endAt),
      durationMillis: Value(durationMillis),
      readChars: Value(readChars),
      startPositionRatio: Value(startPositionRatio),
      endPositionRatio: Value(endPositionRatio),
    );
  }

  factory StoredReadingRecordSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredReadingRecordSession(
      id: serializer.fromJson<int>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      detailUrl: serializer.fromJson<String>(json['detailUrl']),
      bookTitle: serializer.fromJson<String>(json['bookTitle']),
      bookAuthor: serializer.fromJson<String?>(json['bookAuthor']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      chapterId: serializer.fromJson<String?>(json['chapterId']),
      chapterTitle: serializer.fromJson<String?>(json['chapterTitle']),
      chapterIndex: serializer.fromJson<int?>(json['chapterIndex']),
      chapterUrl: serializer.fromJson<String?>(json['chapterUrl']),
      startAt: serializer.fromJson<DateTime>(json['startAt']),
      endAt: serializer.fromJson<DateTime>(json['endAt']),
      durationMillis: serializer.fromJson<int>(json['durationMillis']),
      readChars: serializer.fromJson<int>(json['readChars']),
      startPositionRatio: serializer.fromJson<double>(
        json['startPositionRatio'],
      ),
      endPositionRatio: serializer.fromJson<double>(json['endPositionRatio']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'bookId': serializer.toJson<String>(bookId),
      'sourceId': serializer.toJson<String>(sourceId),
      'detailUrl': serializer.toJson<String>(detailUrl),
      'bookTitle': serializer.toJson<String>(bookTitle),
      'bookAuthor': serializer.toJson<String?>(bookAuthor),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'chapterId': serializer.toJson<String?>(chapterId),
      'chapterTitle': serializer.toJson<String?>(chapterTitle),
      'chapterIndex': serializer.toJson<int?>(chapterIndex),
      'chapterUrl': serializer.toJson<String?>(chapterUrl),
      'startAt': serializer.toJson<DateTime>(startAt),
      'endAt': serializer.toJson<DateTime>(endAt),
      'durationMillis': serializer.toJson<int>(durationMillis),
      'readChars': serializer.toJson<int>(readChars),
      'startPositionRatio': serializer.toJson<double>(startPositionRatio),
      'endPositionRatio': serializer.toJson<double>(endPositionRatio),
    };
  }

  StoredReadingRecordSession copyWith({
    int? id,
    String? bookId,
    String? sourceId,
    String? detailUrl,
    String? bookTitle,
    Value<String?> bookAuthor = const Value.absent(),
    Value<String?> coverUrl = const Value.absent(),
    Value<String?> chapterId = const Value.absent(),
    Value<String?> chapterTitle = const Value.absent(),
    Value<int?> chapterIndex = const Value.absent(),
    Value<String?> chapterUrl = const Value.absent(),
    DateTime? startAt,
    DateTime? endAt,
    int? durationMillis,
    int? readChars,
    double? startPositionRatio,
    double? endPositionRatio,
  }) => StoredReadingRecordSession(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    sourceId: sourceId ?? this.sourceId,
    detailUrl: detailUrl ?? this.detailUrl,
    bookTitle: bookTitle ?? this.bookTitle,
    bookAuthor: bookAuthor.present ? bookAuthor.value : this.bookAuthor,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    chapterId: chapterId.present ? chapterId.value : this.chapterId,
    chapterTitle: chapterTitle.present ? chapterTitle.value : this.chapterTitle,
    chapterIndex: chapterIndex.present ? chapterIndex.value : this.chapterIndex,
    chapterUrl: chapterUrl.present ? chapterUrl.value : this.chapterUrl,
    startAt: startAt ?? this.startAt,
    endAt: endAt ?? this.endAt,
    durationMillis: durationMillis ?? this.durationMillis,
    readChars: readChars ?? this.readChars,
    startPositionRatio: startPositionRatio ?? this.startPositionRatio,
    endPositionRatio: endPositionRatio ?? this.endPositionRatio,
  );
  StoredReadingRecordSession copyWithCompanion(
    StoredReadingRecordSessionsCompanion data,
  ) {
    return StoredReadingRecordSession(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      detailUrl: data.detailUrl.present ? data.detailUrl.value : this.detailUrl,
      bookTitle: data.bookTitle.present ? data.bookTitle.value : this.bookTitle,
      bookAuthor:
          data.bookAuthor.present ? data.bookAuthor.value : this.bookAuthor,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      chapterTitle:
          data.chapterTitle.present
              ? data.chapterTitle.value
              : this.chapterTitle,
      chapterIndex:
          data.chapterIndex.present
              ? data.chapterIndex.value
              : this.chapterIndex,
      chapterUrl:
          data.chapterUrl.present ? data.chapterUrl.value : this.chapterUrl,
      startAt: data.startAt.present ? data.startAt.value : this.startAt,
      endAt: data.endAt.present ? data.endAt.value : this.endAt,
      durationMillis:
          data.durationMillis.present
              ? data.durationMillis.value
              : this.durationMillis,
      readChars: data.readChars.present ? data.readChars.value : this.readChars,
      startPositionRatio:
          data.startPositionRatio.present
              ? data.startPositionRatio.value
              : this.startPositionRatio,
      endPositionRatio:
          data.endPositionRatio.present
              ? data.endPositionRatio.value
              : this.endPositionRatio,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredReadingRecordSession(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('sourceId: $sourceId, ')
          ..write('detailUrl: $detailUrl, ')
          ..write('bookTitle: $bookTitle, ')
          ..write('bookAuthor: $bookAuthor, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('chapterId: $chapterId, ')
          ..write('chapterTitle: $chapterTitle, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('chapterUrl: $chapterUrl, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('durationMillis: $durationMillis, ')
          ..write('readChars: $readChars, ')
          ..write('startPositionRatio: $startPositionRatio, ')
          ..write('endPositionRatio: $endPositionRatio')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    sourceId,
    detailUrl,
    bookTitle,
    bookAuthor,
    coverUrl,
    chapterId,
    chapterTitle,
    chapterIndex,
    chapterUrl,
    startAt,
    endAt,
    durationMillis,
    readChars,
    startPositionRatio,
    endPositionRatio,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredReadingRecordSession &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.sourceId == this.sourceId &&
          other.detailUrl == this.detailUrl &&
          other.bookTitle == this.bookTitle &&
          other.bookAuthor == this.bookAuthor &&
          other.coverUrl == this.coverUrl &&
          other.chapterId == this.chapterId &&
          other.chapterTitle == this.chapterTitle &&
          other.chapterIndex == this.chapterIndex &&
          other.chapterUrl == this.chapterUrl &&
          other.startAt == this.startAt &&
          other.endAt == this.endAt &&
          other.durationMillis == this.durationMillis &&
          other.readChars == this.readChars &&
          other.startPositionRatio == this.startPositionRatio &&
          other.endPositionRatio == this.endPositionRatio);
}

class StoredReadingRecordSessionsCompanion
    extends UpdateCompanion<StoredReadingRecordSession> {
  final Value<int> id;
  final Value<String> bookId;
  final Value<String> sourceId;
  final Value<String> detailUrl;
  final Value<String> bookTitle;
  final Value<String?> bookAuthor;
  final Value<String?> coverUrl;
  final Value<String?> chapterId;
  final Value<String?> chapterTitle;
  final Value<int?> chapterIndex;
  final Value<String?> chapterUrl;
  final Value<DateTime> startAt;
  final Value<DateTime> endAt;
  final Value<int> durationMillis;
  final Value<int> readChars;
  final Value<double> startPositionRatio;
  final Value<double> endPositionRatio;
  const StoredReadingRecordSessionsCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.detailUrl = const Value.absent(),
    this.bookTitle = const Value.absent(),
    this.bookAuthor = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.chapterTitle = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.chapterUrl = const Value.absent(),
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.durationMillis = const Value.absent(),
    this.readChars = const Value.absent(),
    this.startPositionRatio = const Value.absent(),
    this.endPositionRatio = const Value.absent(),
  });
  StoredReadingRecordSessionsCompanion.insert({
    this.id = const Value.absent(),
    required String bookId,
    required String sourceId,
    required String detailUrl,
    required String bookTitle,
    this.bookAuthor = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.chapterTitle = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.chapterUrl = const Value.absent(),
    required DateTime startAt,
    required DateTime endAt,
    this.durationMillis = const Value.absent(),
    this.readChars = const Value.absent(),
    this.startPositionRatio = const Value.absent(),
    this.endPositionRatio = const Value.absent(),
  }) : bookId = Value(bookId),
       sourceId = Value(sourceId),
       detailUrl = Value(detailUrl),
       bookTitle = Value(bookTitle),
       startAt = Value(startAt),
       endAt = Value(endAt);
  static Insertable<StoredReadingRecordSession> custom({
    Expression<int>? id,
    Expression<String>? bookId,
    Expression<String>? sourceId,
    Expression<String>? detailUrl,
    Expression<String>? bookTitle,
    Expression<String>? bookAuthor,
    Expression<String>? coverUrl,
    Expression<String>? chapterId,
    Expression<String>? chapterTitle,
    Expression<int>? chapterIndex,
    Expression<String>? chapterUrl,
    Expression<DateTime>? startAt,
    Expression<DateTime>? endAt,
    Expression<int>? durationMillis,
    Expression<int>? readChars,
    Expression<double>? startPositionRatio,
    Expression<double>? endPositionRatio,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (sourceId != null) 'source_id': sourceId,
      if (detailUrl != null) 'detail_url': detailUrl,
      if (bookTitle != null) 'book_title': bookTitle,
      if (bookAuthor != null) 'book_author': bookAuthor,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (chapterId != null) 'chapter_id': chapterId,
      if (chapterTitle != null) 'chapter_title': chapterTitle,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (chapterUrl != null) 'chapter_url': chapterUrl,
      if (startAt != null) 'start_at': startAt,
      if (endAt != null) 'end_at': endAt,
      if (durationMillis != null) 'duration_millis': durationMillis,
      if (readChars != null) 'read_chars': readChars,
      if (startPositionRatio != null)
        'start_position_ratio': startPositionRatio,
      if (endPositionRatio != null) 'end_position_ratio': endPositionRatio,
    });
  }

  StoredReadingRecordSessionsCompanion copyWith({
    Value<int>? id,
    Value<String>? bookId,
    Value<String>? sourceId,
    Value<String>? detailUrl,
    Value<String>? bookTitle,
    Value<String?>? bookAuthor,
    Value<String?>? coverUrl,
    Value<String?>? chapterId,
    Value<String?>? chapterTitle,
    Value<int?>? chapterIndex,
    Value<String?>? chapterUrl,
    Value<DateTime>? startAt,
    Value<DateTime>? endAt,
    Value<int>? durationMillis,
    Value<int>? readChars,
    Value<double>? startPositionRatio,
    Value<double>? endPositionRatio,
  }) {
    return StoredReadingRecordSessionsCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      sourceId: sourceId ?? this.sourceId,
      detailUrl: detailUrl ?? this.detailUrl,
      bookTitle: bookTitle ?? this.bookTitle,
      bookAuthor: bookAuthor ?? this.bookAuthor,
      coverUrl: coverUrl ?? this.coverUrl,
      chapterId: chapterId ?? this.chapterId,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterUrl: chapterUrl ?? this.chapterUrl,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      durationMillis: durationMillis ?? this.durationMillis,
      readChars: readChars ?? this.readChars,
      startPositionRatio: startPositionRatio ?? this.startPositionRatio,
      endPositionRatio: endPositionRatio ?? this.endPositionRatio,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (detailUrl.present) {
      map['detail_url'] = Variable<String>(detailUrl.value);
    }
    if (bookTitle.present) {
      map['book_title'] = Variable<String>(bookTitle.value);
    }
    if (bookAuthor.present) {
      map['book_author'] = Variable<String>(bookAuthor.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (chapterTitle.present) {
      map['chapter_title'] = Variable<String>(chapterTitle.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (chapterUrl.present) {
      map['chapter_url'] = Variable<String>(chapterUrl.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<DateTime>(startAt.value);
    }
    if (endAt.present) {
      map['end_at'] = Variable<DateTime>(endAt.value);
    }
    if (durationMillis.present) {
      map['duration_millis'] = Variable<int>(durationMillis.value);
    }
    if (readChars.present) {
      map['read_chars'] = Variable<int>(readChars.value);
    }
    if (startPositionRatio.present) {
      map['start_position_ratio'] = Variable<double>(startPositionRatio.value);
    }
    if (endPositionRatio.present) {
      map['end_position_ratio'] = Variable<double>(endPositionRatio.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoredReadingRecordSessionsCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('sourceId: $sourceId, ')
          ..write('detailUrl: $detailUrl, ')
          ..write('bookTitle: $bookTitle, ')
          ..write('bookAuthor: $bookAuthor, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('chapterId: $chapterId, ')
          ..write('chapterTitle: $chapterTitle, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('chapterUrl: $chapterUrl, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('durationMillis: $durationMillis, ')
          ..write('readChars: $readChars, ')
          ..write('startPositionRatio: $startPositionRatio, ')
          ..write('endPositionRatio: $endPositionRatio')
          ..write(')'))
        .toString();
  }
}

class $StoredReadingBookStatusesTable extends StoredReadingBookStatuses
    with TableInfo<$StoredReadingBookStatusesTable, StoredReadingBookStatuse> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredReadingBookStatusesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _detailUrlMeta = const VerificationMeta(
    'detailUrl',
  );
  @override
  late final GeneratedColumn<String> detailUrl = GeneratedColumn<String>(
    'detail_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookTitleMeta = const VerificationMeta(
    'bookTitle',
  );
  @override
  late final GeneratedColumn<String> bookTitle = GeneratedColumn<String>(
    'book_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusOverrideMeta = const VerificationMeta(
    'statusOverride',
  );
  @override
  late final GeneratedColumn<String> statusOverride = GeneratedColumn<String>(
    'status_override',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookId,
    sourceId,
    detailUrl,
    bookTitle,
    statusOverride,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_book_statuses';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredReadingBookStatuse> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
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
    if (data.containsKey('detail_url')) {
      context.handle(
        _detailUrlMeta,
        detailUrl.isAcceptableOrUnknown(data['detail_url']!, _detailUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_detailUrlMeta);
    }
    if (data.containsKey('book_title')) {
      context.handle(
        _bookTitleMeta,
        bookTitle.isAcceptableOrUnknown(data['book_title']!, _bookTitleMeta),
      );
    } else if (isInserting) {
      context.missing(_bookTitleMeta);
    }
    if (data.containsKey('status_override')) {
      context.handle(
        _statusOverrideMeta,
        statusOverride.isAcceptableOrUnknown(
          data['status_override']!,
          _statusOverrideMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_statusOverrideMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  StoredReadingBookStatuse map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredReadingBookStatuse(
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
      detailUrl:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}detail_url'],
          )!,
      bookTitle:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}book_title'],
          )!,
      statusOverride:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}status_override'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $StoredReadingBookStatusesTable createAlias(String alias) {
    return $StoredReadingBookStatusesTable(attachedDatabase, alias);
  }
}

class StoredReadingBookStatuse extends DataClass
    implements Insertable<StoredReadingBookStatuse> {
  final String bookId;
  final String sourceId;
  final String detailUrl;
  final String bookTitle;
  final String statusOverride;
  final DateTime updatedAt;
  const StoredReadingBookStatuse({
    required this.bookId,
    required this.sourceId,
    required this.detailUrl,
    required this.bookTitle,
    required this.statusOverride,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['source_id'] = Variable<String>(sourceId);
    map['detail_url'] = Variable<String>(detailUrl);
    map['book_title'] = Variable<String>(bookTitle);
    map['status_override'] = Variable<String>(statusOverride);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StoredReadingBookStatusesCompanion toCompanion(bool nullToAbsent) {
    return StoredReadingBookStatusesCompanion(
      bookId: Value(bookId),
      sourceId: Value(sourceId),
      detailUrl: Value(detailUrl),
      bookTitle: Value(bookTitle),
      statusOverride: Value(statusOverride),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredReadingBookStatuse.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredReadingBookStatuse(
      bookId: serializer.fromJson<String>(json['bookId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      detailUrl: serializer.fromJson<String>(json['detailUrl']),
      bookTitle: serializer.fromJson<String>(json['bookTitle']),
      statusOverride: serializer.fromJson<String>(json['statusOverride']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'sourceId': serializer.toJson<String>(sourceId),
      'detailUrl': serializer.toJson<String>(detailUrl),
      'bookTitle': serializer.toJson<String>(bookTitle),
      'statusOverride': serializer.toJson<String>(statusOverride),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredReadingBookStatuse copyWith({
    String? bookId,
    String? sourceId,
    String? detailUrl,
    String? bookTitle,
    String? statusOverride,
    DateTime? updatedAt,
  }) => StoredReadingBookStatuse(
    bookId: bookId ?? this.bookId,
    sourceId: sourceId ?? this.sourceId,
    detailUrl: detailUrl ?? this.detailUrl,
    bookTitle: bookTitle ?? this.bookTitle,
    statusOverride: statusOverride ?? this.statusOverride,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredReadingBookStatuse copyWithCompanion(
    StoredReadingBookStatusesCompanion data,
  ) {
    return StoredReadingBookStatuse(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      detailUrl: data.detailUrl.present ? data.detailUrl.value : this.detailUrl,
      bookTitle: data.bookTitle.present ? data.bookTitle.value : this.bookTitle,
      statusOverride:
          data.statusOverride.present
              ? data.statusOverride.value
              : this.statusOverride,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredReadingBookStatuse(')
          ..write('bookId: $bookId, ')
          ..write('sourceId: $sourceId, ')
          ..write('detailUrl: $detailUrl, ')
          ..write('bookTitle: $bookTitle, ')
          ..write('statusOverride: $statusOverride, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    bookId,
    sourceId,
    detailUrl,
    bookTitle,
    statusOverride,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredReadingBookStatuse &&
          other.bookId == this.bookId &&
          other.sourceId == this.sourceId &&
          other.detailUrl == this.detailUrl &&
          other.bookTitle == this.bookTitle &&
          other.statusOverride == this.statusOverride &&
          other.updatedAt == this.updatedAt);
}

class StoredReadingBookStatusesCompanion
    extends UpdateCompanion<StoredReadingBookStatuse> {
  final Value<String> bookId;
  final Value<String> sourceId;
  final Value<String> detailUrl;
  final Value<String> bookTitle;
  final Value<String> statusOverride;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StoredReadingBookStatusesCompanion({
    this.bookId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.detailUrl = const Value.absent(),
    this.bookTitle = const Value.absent(),
    this.statusOverride = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredReadingBookStatusesCompanion.insert({
    required String bookId,
    required String sourceId,
    required String detailUrl,
    required String bookTitle,
    required String statusOverride,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       sourceId = Value(sourceId),
       detailUrl = Value(detailUrl),
       bookTitle = Value(bookTitle),
       statusOverride = Value(statusOverride),
       updatedAt = Value(updatedAt);
  static Insertable<StoredReadingBookStatuse> custom({
    Expression<String>? bookId,
    Expression<String>? sourceId,
    Expression<String>? detailUrl,
    Expression<String>? bookTitle,
    Expression<String>? statusOverride,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (sourceId != null) 'source_id': sourceId,
      if (detailUrl != null) 'detail_url': detailUrl,
      if (bookTitle != null) 'book_title': bookTitle,
      if (statusOverride != null) 'status_override': statusOverride,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredReadingBookStatusesCompanion copyWith({
    Value<String>? bookId,
    Value<String>? sourceId,
    Value<String>? detailUrl,
    Value<String>? bookTitle,
    Value<String>? statusOverride,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StoredReadingBookStatusesCompanion(
      bookId: bookId ?? this.bookId,
      sourceId: sourceId ?? this.sourceId,
      detailUrl: detailUrl ?? this.detailUrl,
      bookTitle: bookTitle ?? this.bookTitle,
      statusOverride: statusOverride ?? this.statusOverride,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (detailUrl.present) {
      map['detail_url'] = Variable<String>(detailUrl.value);
    }
    if (bookTitle.present) {
      map['book_title'] = Variable<String>(bookTitle.value);
    }
    if (statusOverride.present) {
      map['status_override'] = Variable<String>(statusOverride.value);
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
    return (StringBuffer('StoredReadingBookStatusesCompanion(')
          ..write('bookId: $bookId, ')
          ..write('sourceId: $sourceId, ')
          ..write('detailUrl: $detailUrl, ')
          ..write('bookTitle: $bookTitle, ')
          ..write('statusOverride: $statusOverride, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredReadingProgressesTable extends StoredReadingProgresses
    with TableInfo<$StoredReadingProgressesTable, StoredReadingProgressesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredReadingProgressesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _detailUrlMeta = const VerificationMeta(
    'detailUrl',
  );
  @override
  late final GeneratedColumn<String> detailUrl = GeneratedColumn<String>(
    'detail_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterIdMeta = const VerificationMeta(
    'chapterId',
  );
  @override
  late final GeneratedColumn<String> chapterId = GeneratedColumn<String>(
    'chapter_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _chapterTitleMeta = const VerificationMeta(
    'chapterTitle',
  );
  @override
  late final GeneratedColumn<String> chapterTitle = GeneratedColumn<String>(
    'chapter_title',
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
  static const VerificationMeta _chapterPositionRatioMeta =
      const VerificationMeta('chapterPositionRatio');
  @override
  late final GeneratedColumn<double> chapterPositionRatio =
      GeneratedColumn<double>(
        'chapter_position_ratio',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _logicalPositionJsonMeta =
      const VerificationMeta('logicalPositionJson');
  @override
  late final GeneratedColumn<String> logicalPositionJson =
      GeneratedColumn<String>(
        'logical_position_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    bookId,
    sourceId,
    detailUrl,
    chapterId,
    chapterUrl,
    chapterTitle,
    chapterIndex,
    chapterPositionRatio,
    logicalPositionJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_progresses';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredReadingProgressesData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
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
    if (data.containsKey('detail_url')) {
      context.handle(
        _detailUrlMeta,
        detailUrl.isAcceptableOrUnknown(data['detail_url']!, _detailUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_detailUrlMeta);
    }
    if (data.containsKey('chapter_id')) {
      context.handle(
        _chapterIdMeta,
        chapterId.isAcceptableOrUnknown(data['chapter_id']!, _chapterIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterIdMeta);
    }
    if (data.containsKey('chapter_url')) {
      context.handle(
        _chapterUrlMeta,
        chapterUrl.isAcceptableOrUnknown(data['chapter_url']!, _chapterUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterUrlMeta);
    }
    if (data.containsKey('chapter_title')) {
      context.handle(
        _chapterTitleMeta,
        chapterTitle.isAcceptableOrUnknown(
          data['chapter_title']!,
          _chapterTitleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chapterTitleMeta);
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
    if (data.containsKey('chapter_position_ratio')) {
      context.handle(
        _chapterPositionRatioMeta,
        chapterPositionRatio.isAcceptableOrUnknown(
          data['chapter_position_ratio']!,
          _chapterPositionRatioMeta,
        ),
      );
    }
    if (data.containsKey('logical_position_json')) {
      context.handle(
        _logicalPositionJsonMeta,
        logicalPositionJson.isAcceptableOrUnknown(
          data['logical_position_json']!,
          _logicalPositionJsonMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bookId};
  @override
  StoredReadingProgressesData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredReadingProgressesData(
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
      detailUrl:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}detail_url'],
          )!,
      chapterId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}chapter_id'],
          )!,
      chapterUrl:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}chapter_url'],
          )!,
      chapterTitle:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}chapter_title'],
          )!,
      chapterIndex:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}chapter_index'],
          )!,
      chapterPositionRatio:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}chapter_position_ratio'],
          )!,
      logicalPositionJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logical_position_json'],
      ),
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $StoredReadingProgressesTable createAlias(String alias) {
    return $StoredReadingProgressesTable(attachedDatabase, alias);
  }
}

class StoredReadingProgressesData extends DataClass
    implements Insertable<StoredReadingProgressesData> {
  final String bookId;
  final String sourceId;
  final String detailUrl;
  final String chapterId;
  final String chapterUrl;
  final String chapterTitle;
  final int chapterIndex;
  final double chapterPositionRatio;
  final String? logicalPositionJson;
  final DateTime updatedAt;
  const StoredReadingProgressesData({
    required this.bookId,
    required this.sourceId,
    required this.detailUrl,
    required this.chapterId,
    required this.chapterUrl,
    required this.chapterTitle,
    required this.chapterIndex,
    required this.chapterPositionRatio,
    this.logicalPositionJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['book_id'] = Variable<String>(bookId);
    map['source_id'] = Variable<String>(sourceId);
    map['detail_url'] = Variable<String>(detailUrl);
    map['chapter_id'] = Variable<String>(chapterId);
    map['chapter_url'] = Variable<String>(chapterUrl);
    map['chapter_title'] = Variable<String>(chapterTitle);
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['chapter_position_ratio'] = Variable<double>(chapterPositionRatio);
    if (!nullToAbsent || logicalPositionJson != null) {
      map['logical_position_json'] = Variable<String>(logicalPositionJson);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StoredReadingProgressesCompanion toCompanion(bool nullToAbsent) {
    return StoredReadingProgressesCompanion(
      bookId: Value(bookId),
      sourceId: Value(sourceId),
      detailUrl: Value(detailUrl),
      chapterId: Value(chapterId),
      chapterUrl: Value(chapterUrl),
      chapterTitle: Value(chapterTitle),
      chapterIndex: Value(chapterIndex),
      chapterPositionRatio: Value(chapterPositionRatio),
      logicalPositionJson:
          logicalPositionJson == null && nullToAbsent
              ? const Value.absent()
              : Value(logicalPositionJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredReadingProgressesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredReadingProgressesData(
      bookId: serializer.fromJson<String>(json['bookId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      detailUrl: serializer.fromJson<String>(json['detailUrl']),
      chapterId: serializer.fromJson<String>(json['chapterId']),
      chapterUrl: serializer.fromJson<String>(json['chapterUrl']),
      chapterTitle: serializer.fromJson<String>(json['chapterTitle']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      chapterPositionRatio: serializer.fromJson<double>(
        json['chapterPositionRatio'],
      ),
      logicalPositionJson: serializer.fromJson<String?>(
        json['logicalPositionJson'],
      ),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bookId': serializer.toJson<String>(bookId),
      'sourceId': serializer.toJson<String>(sourceId),
      'detailUrl': serializer.toJson<String>(detailUrl),
      'chapterId': serializer.toJson<String>(chapterId),
      'chapterUrl': serializer.toJson<String>(chapterUrl),
      'chapterTitle': serializer.toJson<String>(chapterTitle),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'chapterPositionRatio': serializer.toJson<double>(chapterPositionRatio),
      'logicalPositionJson': serializer.toJson<String?>(logicalPositionJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredReadingProgressesData copyWith({
    String? bookId,
    String? sourceId,
    String? detailUrl,
    String? chapterId,
    String? chapterUrl,
    String? chapterTitle,
    int? chapterIndex,
    double? chapterPositionRatio,
    Value<String?> logicalPositionJson = const Value.absent(),
    DateTime? updatedAt,
  }) => StoredReadingProgressesData(
    bookId: bookId ?? this.bookId,
    sourceId: sourceId ?? this.sourceId,
    detailUrl: detailUrl ?? this.detailUrl,
    chapterId: chapterId ?? this.chapterId,
    chapterUrl: chapterUrl ?? this.chapterUrl,
    chapterTitle: chapterTitle ?? this.chapterTitle,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    chapterPositionRatio: chapterPositionRatio ?? this.chapterPositionRatio,
    logicalPositionJson:
        logicalPositionJson.present
            ? logicalPositionJson.value
            : this.logicalPositionJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredReadingProgressesData copyWithCompanion(
    StoredReadingProgressesCompanion data,
  ) {
    return StoredReadingProgressesData(
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      detailUrl: data.detailUrl.present ? data.detailUrl.value : this.detailUrl,
      chapterId: data.chapterId.present ? data.chapterId.value : this.chapterId,
      chapterUrl:
          data.chapterUrl.present ? data.chapterUrl.value : this.chapterUrl,
      chapterTitle:
          data.chapterTitle.present
              ? data.chapterTitle.value
              : this.chapterTitle,
      chapterIndex:
          data.chapterIndex.present
              ? data.chapterIndex.value
              : this.chapterIndex,
      chapterPositionRatio:
          data.chapterPositionRatio.present
              ? data.chapterPositionRatio.value
              : this.chapterPositionRatio,
      logicalPositionJson:
          data.logicalPositionJson.present
              ? data.logicalPositionJson.value
              : this.logicalPositionJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredReadingProgressesData(')
          ..write('bookId: $bookId, ')
          ..write('sourceId: $sourceId, ')
          ..write('detailUrl: $detailUrl, ')
          ..write('chapterId: $chapterId, ')
          ..write('chapterUrl: $chapterUrl, ')
          ..write('chapterTitle: $chapterTitle, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('chapterPositionRatio: $chapterPositionRatio, ')
          ..write('logicalPositionJson: $logicalPositionJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    bookId,
    sourceId,
    detailUrl,
    chapterId,
    chapterUrl,
    chapterTitle,
    chapterIndex,
    chapterPositionRatio,
    logicalPositionJson,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredReadingProgressesData &&
          other.bookId == this.bookId &&
          other.sourceId == this.sourceId &&
          other.detailUrl == this.detailUrl &&
          other.chapterId == this.chapterId &&
          other.chapterUrl == this.chapterUrl &&
          other.chapterTitle == this.chapterTitle &&
          other.chapterIndex == this.chapterIndex &&
          other.chapterPositionRatio == this.chapterPositionRatio &&
          other.logicalPositionJson == this.logicalPositionJson &&
          other.updatedAt == this.updatedAt);
}

class StoredReadingProgressesCompanion
    extends UpdateCompanion<StoredReadingProgressesData> {
  final Value<String> bookId;
  final Value<String> sourceId;
  final Value<String> detailUrl;
  final Value<String> chapterId;
  final Value<String> chapterUrl;
  final Value<String> chapterTitle;
  final Value<int> chapterIndex;
  final Value<double> chapterPositionRatio;
  final Value<String?> logicalPositionJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StoredReadingProgressesCompanion({
    this.bookId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.detailUrl = const Value.absent(),
    this.chapterId = const Value.absent(),
    this.chapterUrl = const Value.absent(),
    this.chapterTitle = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.chapterPositionRatio = const Value.absent(),
    this.logicalPositionJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredReadingProgressesCompanion.insert({
    required String bookId,
    required String sourceId,
    required String detailUrl,
    required String chapterId,
    required String chapterUrl,
    required String chapterTitle,
    required int chapterIndex,
    this.chapterPositionRatio = const Value.absent(),
    this.logicalPositionJson = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : bookId = Value(bookId),
       sourceId = Value(sourceId),
       detailUrl = Value(detailUrl),
       chapterId = Value(chapterId),
       chapterUrl = Value(chapterUrl),
       chapterTitle = Value(chapterTitle),
       chapterIndex = Value(chapterIndex),
       updatedAt = Value(updatedAt);
  static Insertable<StoredReadingProgressesData> custom({
    Expression<String>? bookId,
    Expression<String>? sourceId,
    Expression<String>? detailUrl,
    Expression<String>? chapterId,
    Expression<String>? chapterUrl,
    Expression<String>? chapterTitle,
    Expression<int>? chapterIndex,
    Expression<double>? chapterPositionRatio,
    Expression<String>? logicalPositionJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bookId != null) 'book_id': bookId,
      if (sourceId != null) 'source_id': sourceId,
      if (detailUrl != null) 'detail_url': detailUrl,
      if (chapterId != null) 'chapter_id': chapterId,
      if (chapterUrl != null) 'chapter_url': chapterUrl,
      if (chapterTitle != null) 'chapter_title': chapterTitle,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (chapterPositionRatio != null)
        'chapter_position_ratio': chapterPositionRatio,
      if (logicalPositionJson != null)
        'logical_position_json': logicalPositionJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredReadingProgressesCompanion copyWith({
    Value<String>? bookId,
    Value<String>? sourceId,
    Value<String>? detailUrl,
    Value<String>? chapterId,
    Value<String>? chapterUrl,
    Value<String>? chapterTitle,
    Value<int>? chapterIndex,
    Value<double>? chapterPositionRatio,
    Value<String?>? logicalPositionJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StoredReadingProgressesCompanion(
      bookId: bookId ?? this.bookId,
      sourceId: sourceId ?? this.sourceId,
      detailUrl: detailUrl ?? this.detailUrl,
      chapterId: chapterId ?? this.chapterId,
      chapterUrl: chapterUrl ?? this.chapterUrl,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterPositionRatio: chapterPositionRatio ?? this.chapterPositionRatio,
      logicalPositionJson: logicalPositionJson ?? this.logicalPositionJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (detailUrl.present) {
      map['detail_url'] = Variable<String>(detailUrl.value);
    }
    if (chapterId.present) {
      map['chapter_id'] = Variable<String>(chapterId.value);
    }
    if (chapterUrl.present) {
      map['chapter_url'] = Variable<String>(chapterUrl.value);
    }
    if (chapterTitle.present) {
      map['chapter_title'] = Variable<String>(chapterTitle.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (chapterPositionRatio.present) {
      map['chapter_position_ratio'] = Variable<double>(
        chapterPositionRatio.value,
      );
    }
    if (logicalPositionJson.present) {
      map['logical_position_json'] = Variable<String>(
        logicalPositionJson.value,
      );
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
    return (StringBuffer('StoredReadingProgressesCompanion(')
          ..write('bookId: $bookId, ')
          ..write('sourceId: $sourceId, ')
          ..write('detailUrl: $detailUrl, ')
          ..write('chapterId: $chapterId, ')
          ..write('chapterUrl: $chapterUrl, ')
          ..write('chapterTitle: $chapterTitle, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('chapterPositionRatio: $chapterPositionRatio, ')
          ..write('logicalPositionJson: $logicalPositionJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredTocSnapshotsTable extends StoredTocSnapshots
    with TableInfo<$StoredTocSnapshotsTable, StoredTocSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredTocSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _storageKeyMeta = const VerificationMeta(
    'storageKey',
  );
  @override
  late final GeneratedColumn<String> storageKey = GeneratedColumn<String>(
    'storage_key',
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
  static const VerificationMeta _detailUrlMeta = const VerificationMeta(
    'detailUrl',
  );
  @override
  late final GeneratedColumn<String> detailUrl = GeneratedColumn<String>(
    'detail_url',
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
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chaptersJsonMeta = const VerificationMeta(
    'chaptersJson',
  );
  @override
  late final GeneratedColumn<String> chaptersJson = GeneratedColumn<String>(
    'chapters_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    storageKey,
    bookId,
    sourceId,
    detailUrl,
    title,
    author,
    coverUrl,
    chaptersJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'toc_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredTocSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('storage_key')) {
      context.handle(
        _storageKeyMeta,
        storageKey.isAcceptableOrUnknown(data['storage_key']!, _storageKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_storageKeyMeta);
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
    if (data.containsKey('detail_url')) {
      context.handle(
        _detailUrlMeta,
        detailUrl.isAcceptableOrUnknown(data['detail_url']!, _detailUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_detailUrlMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('chapters_json')) {
      context.handle(
        _chaptersJsonMeta,
        chaptersJson.isAcceptableOrUnknown(
          data['chapters_json']!,
          _chaptersJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chaptersJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {storageKey};
  @override
  StoredTocSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredTocSnapshot(
      storageKey:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}storage_key'],
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
      detailUrl:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}detail_url'],
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
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      chaptersJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}chapters_json'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $StoredTocSnapshotsTable createAlias(String alias) {
    return $StoredTocSnapshotsTable(attachedDatabase, alias);
  }
}

class StoredTocSnapshot extends DataClass
    implements Insertable<StoredTocSnapshot> {
  final String storageKey;
  final String bookId;
  final String sourceId;
  final String detailUrl;
  final String title;
  final String? author;
  final String? coverUrl;
  final String chaptersJson;
  final DateTime updatedAt;
  const StoredTocSnapshot({
    required this.storageKey,
    required this.bookId,
    required this.sourceId,
    required this.detailUrl,
    required this.title,
    this.author,
    this.coverUrl,
    required this.chaptersJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['storage_key'] = Variable<String>(storageKey);
    map['book_id'] = Variable<String>(bookId);
    map['source_id'] = Variable<String>(sourceId);
    map['detail_url'] = Variable<String>(detailUrl);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    map['chapters_json'] = Variable<String>(chaptersJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StoredTocSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return StoredTocSnapshotsCompanion(
      storageKey: Value(storageKey),
      bookId: Value(bookId),
      sourceId: Value(sourceId),
      detailUrl: Value(detailUrl),
      title: Value(title),
      author:
          author == null && nullToAbsent ? const Value.absent() : Value(author),
      coverUrl:
          coverUrl == null && nullToAbsent
              ? const Value.absent()
              : Value(coverUrl),
      chaptersJson: Value(chaptersJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredTocSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredTocSnapshot(
      storageKey: serializer.fromJson<String>(json['storageKey']),
      bookId: serializer.fromJson<String>(json['bookId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      detailUrl: serializer.fromJson<String>(json['detailUrl']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      chaptersJson: serializer.fromJson<String>(json['chaptersJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'storageKey': serializer.toJson<String>(storageKey),
      'bookId': serializer.toJson<String>(bookId),
      'sourceId': serializer.toJson<String>(sourceId),
      'detailUrl': serializer.toJson<String>(detailUrl),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String?>(author),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'chaptersJson': serializer.toJson<String>(chaptersJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredTocSnapshot copyWith({
    String? storageKey,
    String? bookId,
    String? sourceId,
    String? detailUrl,
    String? title,
    Value<String?> author = const Value.absent(),
    Value<String?> coverUrl = const Value.absent(),
    String? chaptersJson,
    DateTime? updatedAt,
  }) => StoredTocSnapshot(
    storageKey: storageKey ?? this.storageKey,
    bookId: bookId ?? this.bookId,
    sourceId: sourceId ?? this.sourceId,
    detailUrl: detailUrl ?? this.detailUrl,
    title: title ?? this.title,
    author: author.present ? author.value : this.author,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    chaptersJson: chaptersJson ?? this.chaptersJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredTocSnapshot copyWithCompanion(StoredTocSnapshotsCompanion data) {
    return StoredTocSnapshot(
      storageKey:
          data.storageKey.present ? data.storageKey.value : this.storageKey,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      detailUrl: data.detailUrl.present ? data.detailUrl.value : this.detailUrl,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      chaptersJson:
          data.chaptersJson.present
              ? data.chaptersJson.value
              : this.chaptersJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredTocSnapshot(')
          ..write('storageKey: $storageKey, ')
          ..write('bookId: $bookId, ')
          ..write('sourceId: $sourceId, ')
          ..write('detailUrl: $detailUrl, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('chaptersJson: $chaptersJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    storageKey,
    bookId,
    sourceId,
    detailUrl,
    title,
    author,
    coverUrl,
    chaptersJson,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredTocSnapshot &&
          other.storageKey == this.storageKey &&
          other.bookId == this.bookId &&
          other.sourceId == this.sourceId &&
          other.detailUrl == this.detailUrl &&
          other.title == this.title &&
          other.author == this.author &&
          other.coverUrl == this.coverUrl &&
          other.chaptersJson == this.chaptersJson &&
          other.updatedAt == this.updatedAt);
}

class StoredTocSnapshotsCompanion extends UpdateCompanion<StoredTocSnapshot> {
  final Value<String> storageKey;
  final Value<String> bookId;
  final Value<String> sourceId;
  final Value<String> detailUrl;
  final Value<String> title;
  final Value<String?> author;
  final Value<String?> coverUrl;
  final Value<String> chaptersJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StoredTocSnapshotsCompanion({
    this.storageKey = const Value.absent(),
    this.bookId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.detailUrl = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.chaptersJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredTocSnapshotsCompanion.insert({
    required String storageKey,
    required String bookId,
    required String sourceId,
    required String detailUrl,
    required String title,
    this.author = const Value.absent(),
    this.coverUrl = const Value.absent(),
    required String chaptersJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : storageKey = Value(storageKey),
       bookId = Value(bookId),
       sourceId = Value(sourceId),
       detailUrl = Value(detailUrl),
       title = Value(title),
       chaptersJson = Value(chaptersJson),
       updatedAt = Value(updatedAt);
  static Insertable<StoredTocSnapshot> custom({
    Expression<String>? storageKey,
    Expression<String>? bookId,
    Expression<String>? sourceId,
    Expression<String>? detailUrl,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? coverUrl,
    Expression<String>? chaptersJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (storageKey != null) 'storage_key': storageKey,
      if (bookId != null) 'book_id': bookId,
      if (sourceId != null) 'source_id': sourceId,
      if (detailUrl != null) 'detail_url': detailUrl,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (chaptersJson != null) 'chapters_json': chaptersJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredTocSnapshotsCompanion copyWith({
    Value<String>? storageKey,
    Value<String>? bookId,
    Value<String>? sourceId,
    Value<String>? detailUrl,
    Value<String>? title,
    Value<String?>? author,
    Value<String?>? coverUrl,
    Value<String>? chaptersJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StoredTocSnapshotsCompanion(
      storageKey: storageKey ?? this.storageKey,
      bookId: bookId ?? this.bookId,
      sourceId: sourceId ?? this.sourceId,
      detailUrl: detailUrl ?? this.detailUrl,
      title: title ?? this.title,
      author: author ?? this.author,
      coverUrl: coverUrl ?? this.coverUrl,
      chaptersJson: chaptersJson ?? this.chaptersJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (storageKey.present) {
      map['storage_key'] = Variable<String>(storageKey.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (detailUrl.present) {
      map['detail_url'] = Variable<String>(detailUrl.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (chaptersJson.present) {
      map['chapters_json'] = Variable<String>(chaptersJson.value);
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
    return (StringBuffer('StoredTocSnapshotsCompanion(')
          ..write('storageKey: $storageKey, ')
          ..write('bookId: $bookId, ')
          ..write('sourceId: $sourceId, ')
          ..write('detailUrl: $detailUrl, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('chaptersJson: $chaptersJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredRemoteAccessSnapshotsTable extends StoredRemoteAccessSnapshots
    with
        TableInfo<
          $StoredRemoteAccessSnapshotsTable,
          StoredRemoteAccessSnapshot
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredRemoteAccessSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverSourceGatewayEnabledMeta =
      const VerificationMeta('serverSourceGatewayEnabled');
  @override
  late final GeneratedColumn<bool> serverSourceGatewayEnabled =
      GeneratedColumn<bool>(
        'show_source_entry',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("show_source_entry" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _hasMembershipMeta = const VerificationMeta(
    'hasMembership',
  );
  @override
  late final GeneratedColumn<bool> hasMembership = GeneratedColumn<bool>(
    'has_membership',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_membership" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hasThemeCustomMeta = const VerificationMeta(
    'hasThemeCustom',
  );
  @override
  late final GeneratedColumn<bool> hasThemeCustom = GeneratedColumn<bool>(
    'has_theme_custom',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_theme_custom" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _serverSourceGatewayLimitMeta =
      const VerificationMeta('serverSourceGatewayLimit');
  @override
  late final GeneratedColumn<int> serverSourceGatewayLimit =
      GeneratedColumn<int>(
        'source_import_limit',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(10),
      );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    userId,
    serverSourceGatewayEnabled,
    hasMembership,
    hasThemeCustom,
    serverSourceGatewayLimit,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'remote_access_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredRemoteAccessSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('show_source_entry')) {
      context.handle(
        _serverSourceGatewayEnabledMeta,
        serverSourceGatewayEnabled.isAcceptableOrUnknown(
          data['show_source_entry']!,
          _serverSourceGatewayEnabledMeta,
        ),
      );
    }
    if (data.containsKey('has_membership')) {
      context.handle(
        _hasMembershipMeta,
        hasMembership.isAcceptableOrUnknown(
          data['has_membership']!,
          _hasMembershipMeta,
        ),
      );
    }
    if (data.containsKey('has_theme_custom')) {
      context.handle(
        _hasThemeCustomMeta,
        hasThemeCustom.isAcceptableOrUnknown(
          data['has_theme_custom']!,
          _hasThemeCustomMeta,
        ),
      );
    }
    if (data.containsKey('source_import_limit')) {
      context.handle(
        _serverSourceGatewayLimitMeta,
        serverSourceGatewayLimit.isAcceptableOrUnknown(
          data['source_import_limit']!,
          _serverSourceGatewayLimitMeta,
        ),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  StoredRemoteAccessSnapshot map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredRemoteAccessSnapshot(
      userId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}user_id'],
          )!,
      serverSourceGatewayEnabled:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}show_source_entry'],
          )!,
      hasMembership:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}has_membership'],
          )!,
      hasThemeCustom:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}has_theme_custom'],
          )!,
      serverSourceGatewayLimit:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}source_import_limit'],
          )!,
      cachedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}cached_at'],
          )!,
    );
  }

  @override
  $StoredRemoteAccessSnapshotsTable createAlias(String alias) {
    return $StoredRemoteAccessSnapshotsTable(attachedDatabase, alias);
  }
}

class StoredRemoteAccessSnapshot extends DataClass
    implements Insertable<StoredRemoteAccessSnapshot> {
  final String userId;
  final bool serverSourceGatewayEnabled;
  final bool hasMembership;
  final bool hasThemeCustom;
  final int serverSourceGatewayLimit;
  final DateTime cachedAt;
  const StoredRemoteAccessSnapshot({
    required this.userId,
    required this.serverSourceGatewayEnabled,
    required this.hasMembership,
    required this.hasThemeCustom,
    required this.serverSourceGatewayLimit,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['show_source_entry'] = Variable<bool>(serverSourceGatewayEnabled);
    map['has_membership'] = Variable<bool>(hasMembership);
    map['has_theme_custom'] = Variable<bool>(hasThemeCustom);
    map['source_import_limit'] = Variable<int>(serverSourceGatewayLimit);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  StoredRemoteAccessSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return StoredRemoteAccessSnapshotsCompanion(
      userId: Value(userId),
      serverSourceGatewayEnabled: Value(serverSourceGatewayEnabled),
      hasMembership: Value(hasMembership),
      hasThemeCustom: Value(hasThemeCustom),
      serverSourceGatewayLimit: Value(serverSourceGatewayLimit),
      cachedAt: Value(cachedAt),
    );
  }

  factory StoredRemoteAccessSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredRemoteAccessSnapshot(
      userId: serializer.fromJson<String>(json['userId']),
      serverSourceGatewayEnabled: serializer.fromJson<bool>(
        json['serverSourceGatewayEnabled'],
      ),
      hasMembership: serializer.fromJson<bool>(json['hasMembership']),
      hasThemeCustom: serializer.fromJson<bool>(json['hasThemeCustom']),
      serverSourceGatewayLimit: serializer.fromJson<int>(
        json['serverSourceGatewayLimit'],
      ),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'serverSourceGatewayEnabled': serializer.toJson<bool>(
        serverSourceGatewayEnabled,
      ),
      'hasMembership': serializer.toJson<bool>(hasMembership),
      'hasThemeCustom': serializer.toJson<bool>(hasThemeCustom),
      'serverSourceGatewayLimit': serializer.toJson<int>(
        serverSourceGatewayLimit,
      ),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  StoredRemoteAccessSnapshot copyWith({
    String? userId,
    bool? serverSourceGatewayEnabled,
    bool? hasMembership,
    bool? hasThemeCustom,
    int? serverSourceGatewayLimit,
    DateTime? cachedAt,
  }) => StoredRemoteAccessSnapshot(
    userId: userId ?? this.userId,
    serverSourceGatewayEnabled:
        serverSourceGatewayEnabled ?? this.serverSourceGatewayEnabled,
    hasMembership: hasMembership ?? this.hasMembership,
    hasThemeCustom: hasThemeCustom ?? this.hasThemeCustom,
    serverSourceGatewayLimit:
        serverSourceGatewayLimit ?? this.serverSourceGatewayLimit,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  StoredRemoteAccessSnapshot copyWithCompanion(
    StoredRemoteAccessSnapshotsCompanion data,
  ) {
    return StoredRemoteAccessSnapshot(
      userId: data.userId.present ? data.userId.value : this.userId,
      serverSourceGatewayEnabled:
          data.serverSourceGatewayEnabled.present
              ? data.serverSourceGatewayEnabled.value
              : this.serverSourceGatewayEnabled,
      hasMembership:
          data.hasMembership.present
              ? data.hasMembership.value
              : this.hasMembership,
      hasThemeCustom:
          data.hasThemeCustom.present
              ? data.hasThemeCustom.value
              : this.hasThemeCustom,
      serverSourceGatewayLimit:
          data.serverSourceGatewayLimit.present
              ? data.serverSourceGatewayLimit.value
              : this.serverSourceGatewayLimit,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredRemoteAccessSnapshot(')
          ..write('userId: $userId, ')
          ..write('serverSourceGatewayEnabled: $serverSourceGatewayEnabled, ')
          ..write('hasMembership: $hasMembership, ')
          ..write('hasThemeCustom: $hasThemeCustom, ')
          ..write('serverSourceGatewayLimit: $serverSourceGatewayLimit, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    userId,
    serverSourceGatewayEnabled,
    hasMembership,
    hasThemeCustom,
    serverSourceGatewayLimit,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredRemoteAccessSnapshot &&
          other.userId == this.userId &&
          other.serverSourceGatewayEnabled == this.serverSourceGatewayEnabled &&
          other.hasMembership == this.hasMembership &&
          other.hasThemeCustom == this.hasThemeCustom &&
          other.serverSourceGatewayLimit == this.serverSourceGatewayLimit &&
          other.cachedAt == this.cachedAt);
}

class StoredRemoteAccessSnapshotsCompanion
    extends UpdateCompanion<StoredRemoteAccessSnapshot> {
  final Value<String> userId;
  final Value<bool> serverSourceGatewayEnabled;
  final Value<bool> hasMembership;
  final Value<bool> hasThemeCustom;
  final Value<int> serverSourceGatewayLimit;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const StoredRemoteAccessSnapshotsCompanion({
    this.userId = const Value.absent(),
    this.serverSourceGatewayEnabled = const Value.absent(),
    this.hasMembership = const Value.absent(),
    this.hasThemeCustom = const Value.absent(),
    this.serverSourceGatewayLimit = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredRemoteAccessSnapshotsCompanion.insert({
    required String userId,
    this.serverSourceGatewayEnabled = const Value.absent(),
    this.hasMembership = const Value.absent(),
    this.hasThemeCustom = const Value.absent(),
    this.serverSourceGatewayLimit = const Value.absent(),
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : userId = Value(userId),
       cachedAt = Value(cachedAt);
  static Insertable<StoredRemoteAccessSnapshot> custom({
    Expression<String>? userId,
    Expression<bool>? serverSourceGatewayEnabled,
    Expression<bool>? hasMembership,
    Expression<bool>? hasThemeCustom,
    Expression<int>? serverSourceGatewayLimit,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (serverSourceGatewayEnabled != null)
        'show_source_entry': serverSourceGatewayEnabled,
      if (hasMembership != null) 'has_membership': hasMembership,
      if (hasThemeCustom != null) 'has_theme_custom': hasThemeCustom,
      if (serverSourceGatewayLimit != null)
        'source_import_limit': serverSourceGatewayLimit,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredRemoteAccessSnapshotsCompanion copyWith({
    Value<String>? userId,
    Value<bool>? serverSourceGatewayEnabled,
    Value<bool>? hasMembership,
    Value<bool>? hasThemeCustom,
    Value<int>? serverSourceGatewayLimit,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return StoredRemoteAccessSnapshotsCompanion(
      userId: userId ?? this.userId,
      serverSourceGatewayEnabled:
          serverSourceGatewayEnabled ?? this.serverSourceGatewayEnabled,
      hasMembership: hasMembership ?? this.hasMembership,
      hasThemeCustom: hasThemeCustom ?? this.hasThemeCustom,
      serverSourceGatewayLimit:
          serverSourceGatewayLimit ?? this.serverSourceGatewayLimit,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (serverSourceGatewayEnabled.present) {
      map['show_source_entry'] = Variable<bool>(
        serverSourceGatewayEnabled.value,
      );
    }
    if (hasMembership.present) {
      map['has_membership'] = Variable<bool>(hasMembership.value);
    }
    if (hasThemeCustom.present) {
      map['has_theme_custom'] = Variable<bool>(hasThemeCustom.value);
    }
    if (serverSourceGatewayLimit.present) {
      map['source_import_limit'] = Variable<int>(
        serverSourceGatewayLimit.value,
      );
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoredRemoteAccessSnapshotsCompanion(')
          ..write('userId: $userId, ')
          ..write('serverSourceGatewayEnabled: $serverSourceGatewayEnabled, ')
          ..write('hasMembership: $hasMembership, ')
          ..write('hasThemeCustom: $hasThemeCustom, ')
          ..write('serverSourceGatewayLimit: $serverSourceGatewayLimit, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredSourceHealthSnapshotsTable extends StoredSourceHealthSnapshots
    with
        TableInfo<
          $StoredSourceHealthSnapshotsTable,
          StoredSourceHealthSnapshot
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredSourceHealthSnapshotsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  List<GeneratedColumn> get $columns => [sourceId, payloadJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'source_health_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredSourceHealthSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
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
  Set<GeneratedColumn> get $primaryKey => {sourceId};
  @override
  StoredSourceHealthSnapshot map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredSourceHealthSnapshot(
      sourceId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}source_id'],
          )!,
      payloadJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}payload_json'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $StoredSourceHealthSnapshotsTable createAlias(String alias) {
    return $StoredSourceHealthSnapshotsTable(attachedDatabase, alias);
  }
}

class StoredSourceHealthSnapshot extends DataClass
    implements Insertable<StoredSourceHealthSnapshot> {
  final String sourceId;
  final String payloadJson;
  final DateTime updatedAt;
  const StoredSourceHealthSnapshot({
    required this.sourceId,
    required this.payloadJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<String>(sourceId);
    map['payload_json'] = Variable<String>(payloadJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StoredSourceHealthSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return StoredSourceHealthSnapshotsCompanion(
      sourceId: Value(sourceId),
      payloadJson: Value(payloadJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredSourceHealthSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredSourceHealthSnapshot(
      sourceId: serializer.fromJson<String>(json['sourceId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<String>(sourceId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredSourceHealthSnapshot copyWith({
    String? sourceId,
    String? payloadJson,
    DateTime? updatedAt,
  }) => StoredSourceHealthSnapshot(
    sourceId: sourceId ?? this.sourceId,
    payloadJson: payloadJson ?? this.payloadJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredSourceHealthSnapshot copyWithCompanion(
    StoredSourceHealthSnapshotsCompanion data,
  ) {
    return StoredSourceHealthSnapshot(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      payloadJson:
          data.payloadJson.present ? data.payloadJson.value : this.payloadJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredSourceHealthSnapshot(')
          ..write('sourceId: $sourceId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sourceId, payloadJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredSourceHealthSnapshot &&
          other.sourceId == this.sourceId &&
          other.payloadJson == this.payloadJson &&
          other.updatedAt == this.updatedAt);
}

class StoredSourceHealthSnapshotsCompanion
    extends UpdateCompanion<StoredSourceHealthSnapshot> {
  final Value<String> sourceId;
  final Value<String> payloadJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StoredSourceHealthSnapshotsCompanion({
    this.sourceId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredSourceHealthSnapshotsCompanion.insert({
    required String sourceId,
    required String payloadJson,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       payloadJson = Value(payloadJson);
  static Insertable<StoredSourceHealthSnapshot> custom({
    Expression<String>? sourceId,
    Expression<String>? payloadJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredSourceHealthSnapshotsCompanion copyWith({
    Value<String>? sourceId,
    Value<String>? payloadJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StoredSourceHealthSnapshotsCompanion(
      sourceId: sourceId ?? this.sourceId,
      payloadJson: payloadJson ?? this.payloadJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
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
    return (StringBuffer('StoredSourceHealthSnapshotsCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredBookshelfBooksTable extends StoredBookshelfBooks
    with TableInfo<$StoredBookshelfBooksTable, StoredBookshelfBook> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredBookshelfBooksTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _detailUrlMeta = const VerificationMeta(
    'detailUrl',
  );
  @override
  late final GeneratedColumn<String> detailUrl = GeneratedColumn<String>(
    'detail_url',
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
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
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
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
    sourceId,
    detailUrl,
    bookId,
    title,
    author,
    category,
    coverUrl,
    latestChapter,
    addedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookshelf_books';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredBookshelfBook> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('detail_url')) {
      context.handle(
        _detailUrlMeta,
        detailUrl.isAcceptableOrUnknown(data['detail_url']!, _detailUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_detailUrlMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
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
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
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
  Set<GeneratedColumn> get $primaryKey => {sourceId, detailUrl};
  @override
  StoredBookshelfBook map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredBookshelfBook(
      sourceId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}source_id'],
          )!,
      detailUrl:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}detail_url'],
          )!,
      bookId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}book_id'],
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
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      latestChapter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}latest_chapter'],
      ),
      addedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}added_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $StoredBookshelfBooksTable createAlias(String alias) {
    return $StoredBookshelfBooksTable(attachedDatabase, alias);
  }
}

class StoredBookshelfBook extends DataClass
    implements Insertable<StoredBookshelfBook> {
  final String sourceId;
  final String detailUrl;
  final String bookId;
  final String title;
  final String? author;
  final String? category;
  final String? coverUrl;
  final String? latestChapter;
  final DateTime addedAt;
  final DateTime updatedAt;
  const StoredBookshelfBook({
    required this.sourceId,
    required this.detailUrl,
    required this.bookId,
    required this.title,
    this.author,
    this.category,
    this.coverUrl,
    this.latestChapter,
    required this.addedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<String>(sourceId);
    map['detail_url'] = Variable<String>(detailUrl);
    map['book_id'] = Variable<String>(bookId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || latestChapter != null) {
      map['latest_chapter'] = Variable<String>(latestChapter);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StoredBookshelfBooksCompanion toCompanion(bool nullToAbsent) {
    return StoredBookshelfBooksCompanion(
      sourceId: Value(sourceId),
      detailUrl: Value(detailUrl),
      bookId: Value(bookId),
      title: Value(title),
      author:
          author == null && nullToAbsent ? const Value.absent() : Value(author),
      category:
          category == null && nullToAbsent
              ? const Value.absent()
              : Value(category),
      coverUrl:
          coverUrl == null && nullToAbsent
              ? const Value.absent()
              : Value(coverUrl),
      latestChapter:
          latestChapter == null && nullToAbsent
              ? const Value.absent()
              : Value(latestChapter),
      addedAt: Value(addedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredBookshelfBook.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredBookshelfBook(
      sourceId: serializer.fromJson<String>(json['sourceId']),
      detailUrl: serializer.fromJson<String>(json['detailUrl']),
      bookId: serializer.fromJson<String>(json['bookId']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      category: serializer.fromJson<String?>(json['category']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      latestChapter: serializer.fromJson<String?>(json['latestChapter']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<String>(sourceId),
      'detailUrl': serializer.toJson<String>(detailUrl),
      'bookId': serializer.toJson<String>(bookId),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String?>(author),
      'category': serializer.toJson<String?>(category),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'latestChapter': serializer.toJson<String?>(latestChapter),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredBookshelfBook copyWith({
    String? sourceId,
    String? detailUrl,
    String? bookId,
    String? title,
    Value<String?> author = const Value.absent(),
    Value<String?> category = const Value.absent(),
    Value<String?> coverUrl = const Value.absent(),
    Value<String?> latestChapter = const Value.absent(),
    DateTime? addedAt,
    DateTime? updatedAt,
  }) => StoredBookshelfBook(
    sourceId: sourceId ?? this.sourceId,
    detailUrl: detailUrl ?? this.detailUrl,
    bookId: bookId ?? this.bookId,
    title: title ?? this.title,
    author: author.present ? author.value : this.author,
    category: category.present ? category.value : this.category,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    latestChapter:
        latestChapter.present ? latestChapter.value : this.latestChapter,
    addedAt: addedAt ?? this.addedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredBookshelfBook copyWithCompanion(StoredBookshelfBooksCompanion data) {
    return StoredBookshelfBook(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      detailUrl: data.detailUrl.present ? data.detailUrl.value : this.detailUrl,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      category: data.category.present ? data.category.value : this.category,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      latestChapter:
          data.latestChapter.present
              ? data.latestChapter.value
              : this.latestChapter,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredBookshelfBook(')
          ..write('sourceId: $sourceId, ')
          ..write('detailUrl: $detailUrl, ')
          ..write('bookId: $bookId, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('category: $category, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('latestChapter: $latestChapter, ')
          ..write('addedAt: $addedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceId,
    detailUrl,
    bookId,
    title,
    author,
    category,
    coverUrl,
    latestChapter,
    addedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredBookshelfBook &&
          other.sourceId == this.sourceId &&
          other.detailUrl == this.detailUrl &&
          other.bookId == this.bookId &&
          other.title == this.title &&
          other.author == this.author &&
          other.category == this.category &&
          other.coverUrl == this.coverUrl &&
          other.latestChapter == this.latestChapter &&
          other.addedAt == this.addedAt &&
          other.updatedAt == this.updatedAt);
}

class StoredBookshelfBooksCompanion
    extends UpdateCompanion<StoredBookshelfBook> {
  final Value<String> sourceId;
  final Value<String> detailUrl;
  final Value<String> bookId;
  final Value<String> title;
  final Value<String?> author;
  final Value<String?> category;
  final Value<String?> coverUrl;
  final Value<String?> latestChapter;
  final Value<DateTime> addedAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StoredBookshelfBooksCompanion({
    this.sourceId = const Value.absent(),
    this.detailUrl = const Value.absent(),
    this.bookId = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.category = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.latestChapter = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredBookshelfBooksCompanion.insert({
    required String sourceId,
    required String detailUrl,
    required String bookId,
    required String title,
    this.author = const Value.absent(),
    this.category = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.latestChapter = const Value.absent(),
    required DateTime addedAt,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       detailUrl = Value(detailUrl),
       bookId = Value(bookId),
       title = Value(title),
       addedAt = Value(addedAt);
  static Insertable<StoredBookshelfBook> custom({
    Expression<String>? sourceId,
    Expression<String>? detailUrl,
    Expression<String>? bookId,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? category,
    Expression<String>? coverUrl,
    Expression<String>? latestChapter,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (detailUrl != null) 'detail_url': detailUrl,
      if (bookId != null) 'book_id': bookId,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (category != null) 'category': category,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (latestChapter != null) 'latest_chapter': latestChapter,
      if (addedAt != null) 'added_at': addedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredBookshelfBooksCompanion copyWith({
    Value<String>? sourceId,
    Value<String>? detailUrl,
    Value<String>? bookId,
    Value<String>? title,
    Value<String?>? author,
    Value<String?>? category,
    Value<String?>? coverUrl,
    Value<String?>? latestChapter,
    Value<DateTime>? addedAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StoredBookshelfBooksCompanion(
      sourceId: sourceId ?? this.sourceId,
      detailUrl: detailUrl ?? this.detailUrl,
      bookId: bookId ?? this.bookId,
      title: title ?? this.title,
      author: author ?? this.author,
      category: category ?? this.category,
      coverUrl: coverUrl ?? this.coverUrl,
      latestChapter: latestChapter ?? this.latestChapter,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (detailUrl.present) {
      map['detail_url'] = Variable<String>(detailUrl.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (latestChapter.present) {
      map['latest_chapter'] = Variable<String>(latestChapter.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
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
    return (StringBuffer('StoredBookshelfBooksCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('detailUrl: $detailUrl, ')
          ..write('bookId: $bookId, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('category: $category, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('latestChapter: $latestChapter, ')
          ..write('addedAt: $addedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredBookshelfTagAssignmentsTable extends StoredBookshelfTagAssignments
    with
        TableInfo<
          $StoredBookshelfTagAssignmentsTable,
          StoredBookshelfTagAssignment
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredBookshelfTagAssignmentsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _detailUrlMeta = const VerificationMeta(
    'detailUrl',
  );
  @override
  late final GeneratedColumn<String> detailUrl = GeneratedColumn<String>(
    'detail_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagNameMeta = const VerificationMeta(
    'tagName',
  );
  @override
  late final GeneratedColumn<String> tagName = GeneratedColumn<String>(
    'tag_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceId,
    detailUrl,
    tagName,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookshelf_tag_assignments';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredBookshelfTagAssignment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('detail_url')) {
      context.handle(
        _detailUrlMeta,
        detailUrl.isAcceptableOrUnknown(data['detail_url']!, _detailUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_detailUrlMeta);
    }
    if (data.containsKey('tag_name')) {
      context.handle(
        _tagNameMeta,
        tagName.isAcceptableOrUnknown(data['tag_name']!, _tagNameMeta),
      );
    } else if (isInserting) {
      context.missing(_tagNameMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceId, detailUrl, tagName};
  @override
  StoredBookshelfTagAssignment map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredBookshelfTagAssignment(
      sourceId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}source_id'],
          )!,
      detailUrl:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}detail_url'],
          )!,
      tagName:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}tag_name'],
          )!,
      position:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}position'],
          )!,
    );
  }

  @override
  $StoredBookshelfTagAssignmentsTable createAlias(String alias) {
    return $StoredBookshelfTagAssignmentsTable(attachedDatabase, alias);
  }
}

class StoredBookshelfTagAssignment extends DataClass
    implements Insertable<StoredBookshelfTagAssignment> {
  final String sourceId;
  final String detailUrl;
  final String tagName;
  final int position;
  const StoredBookshelfTagAssignment({
    required this.sourceId,
    required this.detailUrl,
    required this.tagName,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<String>(sourceId);
    map['detail_url'] = Variable<String>(detailUrl);
    map['tag_name'] = Variable<String>(tagName);
    map['position'] = Variable<int>(position);
    return map;
  }

  StoredBookshelfTagAssignmentsCompanion toCompanion(bool nullToAbsent) {
    return StoredBookshelfTagAssignmentsCompanion(
      sourceId: Value(sourceId),
      detailUrl: Value(detailUrl),
      tagName: Value(tagName),
      position: Value(position),
    );
  }

  factory StoredBookshelfTagAssignment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredBookshelfTagAssignment(
      sourceId: serializer.fromJson<String>(json['sourceId']),
      detailUrl: serializer.fromJson<String>(json['detailUrl']),
      tagName: serializer.fromJson<String>(json['tagName']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<String>(sourceId),
      'detailUrl': serializer.toJson<String>(detailUrl),
      'tagName': serializer.toJson<String>(tagName),
      'position': serializer.toJson<int>(position),
    };
  }

  StoredBookshelfTagAssignment copyWith({
    String? sourceId,
    String? detailUrl,
    String? tagName,
    int? position,
  }) => StoredBookshelfTagAssignment(
    sourceId: sourceId ?? this.sourceId,
    detailUrl: detailUrl ?? this.detailUrl,
    tagName: tagName ?? this.tagName,
    position: position ?? this.position,
  );
  StoredBookshelfTagAssignment copyWithCompanion(
    StoredBookshelfTagAssignmentsCompanion data,
  ) {
    return StoredBookshelfTagAssignment(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      detailUrl: data.detailUrl.present ? data.detailUrl.value : this.detailUrl,
      tagName: data.tagName.present ? data.tagName.value : this.tagName,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredBookshelfTagAssignment(')
          ..write('sourceId: $sourceId, ')
          ..write('detailUrl: $detailUrl, ')
          ..write('tagName: $tagName, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sourceId, detailUrl, tagName, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredBookshelfTagAssignment &&
          other.sourceId == this.sourceId &&
          other.detailUrl == this.detailUrl &&
          other.tagName == this.tagName &&
          other.position == this.position);
}

class StoredBookshelfTagAssignmentsCompanion
    extends UpdateCompanion<StoredBookshelfTagAssignment> {
  final Value<String> sourceId;
  final Value<String> detailUrl;
  final Value<String> tagName;
  final Value<int> position;
  final Value<int> rowid;
  const StoredBookshelfTagAssignmentsCompanion({
    this.sourceId = const Value.absent(),
    this.detailUrl = const Value.absent(),
    this.tagName = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredBookshelfTagAssignmentsCompanion.insert({
    required String sourceId,
    required String detailUrl,
    required String tagName,
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       detailUrl = Value(detailUrl),
       tagName = Value(tagName);
  static Insertable<StoredBookshelfTagAssignment> custom({
    Expression<String>? sourceId,
    Expression<String>? detailUrl,
    Expression<String>? tagName,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (detailUrl != null) 'detail_url': detailUrl,
      if (tagName != null) 'tag_name': tagName,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredBookshelfTagAssignmentsCompanion copyWith({
    Value<String>? sourceId,
    Value<String>? detailUrl,
    Value<String>? tagName,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return StoredBookshelfTagAssignmentsCompanion(
      sourceId: sourceId ?? this.sourceId,
      detailUrl: detailUrl ?? this.detailUrl,
      tagName: tagName ?? this.tagName,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (detailUrl.present) {
      map['detail_url'] = Variable<String>(detailUrl.value);
    }
    if (tagName.present) {
      map['tag_name'] = Variable<String>(tagName.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoredBookshelfTagAssignmentsCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('detailUrl: $detailUrl, ')
          ..write('tagName: $tagName, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredBookshelfTagMetadataTable extends StoredBookshelfTagMetadata
    with
        TableInfo<
          $StoredBookshelfTagMetadataTable,
          StoredBookshelfTagMetadataData
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredBookshelfTagMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [name, colorValue, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookshelf_tag_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredBookshelfTagMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {name};
  @override
  StoredBookshelfTagMetadataData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredBookshelfTagMetadataData(
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      colorValue:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}color_value'],
          )!,
      position:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}position'],
          )!,
    );
  }

  @override
  $StoredBookshelfTagMetadataTable createAlias(String alias) {
    return $StoredBookshelfTagMetadataTable(attachedDatabase, alias);
  }
}

class StoredBookshelfTagMetadataData extends DataClass
    implements Insertable<StoredBookshelfTagMetadataData> {
  final String name;
  final int colorValue;
  final int position;
  const StoredBookshelfTagMetadataData({
    required this.name,
    required this.colorValue,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name'] = Variable<String>(name);
    map['color_value'] = Variable<int>(colorValue);
    map['position'] = Variable<int>(position);
    return map;
  }

  StoredBookshelfTagMetadataCompanion toCompanion(bool nullToAbsent) {
    return StoredBookshelfTagMetadataCompanion(
      name: Value(name),
      colorValue: Value(colorValue),
      position: Value(position),
    );
  }

  factory StoredBookshelfTagMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredBookshelfTagMetadataData(
      name: serializer.fromJson<String>(json['name']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'name': serializer.toJson<String>(name),
      'colorValue': serializer.toJson<int>(colorValue),
      'position': serializer.toJson<int>(position),
    };
  }

  StoredBookshelfTagMetadataData copyWith({
    String? name,
    int? colorValue,
    int? position,
  }) => StoredBookshelfTagMetadataData(
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    position: position ?? this.position,
  );
  StoredBookshelfTagMetadataData copyWithCompanion(
    StoredBookshelfTagMetadataCompanion data,
  ) {
    return StoredBookshelfTagMetadataData(
      name: data.name.present ? data.name.value : this.name,
      colorValue:
          data.colorValue.present ? data.colorValue.value : this.colorValue,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredBookshelfTagMetadataData(')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(name, colorValue, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredBookshelfTagMetadataData &&
          other.name == this.name &&
          other.colorValue == this.colorValue &&
          other.position == this.position);
}

class StoredBookshelfTagMetadataCompanion
    extends UpdateCompanion<StoredBookshelfTagMetadataData> {
  final Value<String> name;
  final Value<int> colorValue;
  final Value<int> position;
  final Value<int> rowid;
  const StoredBookshelfTagMetadataCompanion({
    this.name = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredBookshelfTagMetadataCompanion.insert({
    required String name,
    required int colorValue,
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       colorValue = Value(colorValue);
  static Insertable<StoredBookshelfTagMetadataData> custom({
    Expression<String>? name,
    Expression<int>? colorValue,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (colorValue != null) 'color_value': colorValue,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredBookshelfTagMetadataCompanion copyWith({
    Value<String>? name,
    Value<int>? colorValue,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return StoredBookshelfTagMetadataCompanion(
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoredBookshelfTagMetadataCompanion(')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredBookshelfCategoryMetadataTable
    extends StoredBookshelfCategoryMetadata
    with
        TableInfo<
          $StoredBookshelfCategoryMetadataTable,
          StoredBookshelfCategoryMetadataData
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredBookshelfCategoryMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorValueMeta = const VerificationMeta(
    'colorValue',
  );
  @override
  late final GeneratedColumn<int> colorValue = GeneratedColumn<int>(
    'color_value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [name, colorValue, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookshelf_category_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredBookshelfCategoryMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_value')) {
      context.handle(
        _colorValueMeta,
        colorValue.isAcceptableOrUnknown(data['color_value']!, _colorValueMeta),
      );
    } else if (isInserting) {
      context.missing(_colorValueMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {name};
  @override
  StoredBookshelfCategoryMetadataData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredBookshelfCategoryMetadataData(
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      colorValue:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}color_value'],
          )!,
      position:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}position'],
          )!,
    );
  }

  @override
  $StoredBookshelfCategoryMetadataTable createAlias(String alias) {
    return $StoredBookshelfCategoryMetadataTable(attachedDatabase, alias);
  }
}

class StoredBookshelfCategoryMetadataData extends DataClass
    implements Insertable<StoredBookshelfCategoryMetadataData> {
  final String name;
  final int colorValue;
  final int position;
  const StoredBookshelfCategoryMetadataData({
    required this.name,
    required this.colorValue,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['name'] = Variable<String>(name);
    map['color_value'] = Variable<int>(colorValue);
    map['position'] = Variable<int>(position);
    return map;
  }

  StoredBookshelfCategoryMetadataCompanion toCompanion(bool nullToAbsent) {
    return StoredBookshelfCategoryMetadataCompanion(
      name: Value(name),
      colorValue: Value(colorValue),
      position: Value(position),
    );
  }

  factory StoredBookshelfCategoryMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredBookshelfCategoryMetadataData(
      name: serializer.fromJson<String>(json['name']),
      colorValue: serializer.fromJson<int>(json['colorValue']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'name': serializer.toJson<String>(name),
      'colorValue': serializer.toJson<int>(colorValue),
      'position': serializer.toJson<int>(position),
    };
  }

  StoredBookshelfCategoryMetadataData copyWith({
    String? name,
    int? colorValue,
    int? position,
  }) => StoredBookshelfCategoryMetadataData(
    name: name ?? this.name,
    colorValue: colorValue ?? this.colorValue,
    position: position ?? this.position,
  );
  StoredBookshelfCategoryMetadataData copyWithCompanion(
    StoredBookshelfCategoryMetadataCompanion data,
  ) {
    return StoredBookshelfCategoryMetadataData(
      name: data.name.present ? data.name.value : this.name,
      colorValue:
          data.colorValue.present ? data.colorValue.value : this.colorValue,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredBookshelfCategoryMetadataData(')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(name, colorValue, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredBookshelfCategoryMetadataData &&
          other.name == this.name &&
          other.colorValue == this.colorValue &&
          other.position == this.position);
}

class StoredBookshelfCategoryMetadataCompanion
    extends UpdateCompanion<StoredBookshelfCategoryMetadataData> {
  final Value<String> name;
  final Value<int> colorValue;
  final Value<int> position;
  final Value<int> rowid;
  const StoredBookshelfCategoryMetadataCompanion({
    this.name = const Value.absent(),
    this.colorValue = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredBookshelfCategoryMetadataCompanion.insert({
    required String name,
    required int colorValue,
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       colorValue = Value(colorValue);
  static Insertable<StoredBookshelfCategoryMetadataData> custom({
    Expression<String>? name,
    Expression<int>? colorValue,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (name != null) 'name': name,
      if (colorValue != null) 'color_value': colorValue,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredBookshelfCategoryMetadataCompanion copyWith({
    Value<String>? name,
    Value<int>? colorValue,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return StoredBookshelfCategoryMetadataCompanion(
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorValue.present) {
      map['color_value'] = Variable<int>(colorValue.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoredBookshelfCategoryMetadataCompanion(')
          ..write('name: $name, ')
          ..write('colorValue: $colorValue, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredBookshelfBaseFilterOrdersTable
    extends StoredBookshelfBaseFilterOrders
    with
        TableInfo<
          $StoredBookshelfBaseFilterOrdersTable,
          StoredBookshelfBaseFilterOrder
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredBookshelfBaseFilterOrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _filterKeyMeta = const VerificationMeta(
    'filterKey',
  );
  @override
  late final GeneratedColumn<String> filterKey = GeneratedColumn<String>(
    'filter_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [filterKey, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookshelf_base_filter_orders';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredBookshelfBaseFilterOrder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('filter_key')) {
      context.handle(
        _filterKeyMeta,
        filterKey.isAcceptableOrUnknown(data['filter_key']!, _filterKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_filterKeyMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {filterKey};
  @override
  StoredBookshelfBaseFilterOrder map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredBookshelfBaseFilterOrder(
      filterKey:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}filter_key'],
          )!,
      position:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}position'],
          )!,
    );
  }

  @override
  $StoredBookshelfBaseFilterOrdersTable createAlias(String alias) {
    return $StoredBookshelfBaseFilterOrdersTable(attachedDatabase, alias);
  }
}

class StoredBookshelfBaseFilterOrder extends DataClass
    implements Insertable<StoredBookshelfBaseFilterOrder> {
  final String filterKey;
  final int position;
  const StoredBookshelfBaseFilterOrder({
    required this.filterKey,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['filter_key'] = Variable<String>(filterKey);
    map['position'] = Variable<int>(position);
    return map;
  }

  StoredBookshelfBaseFilterOrdersCompanion toCompanion(bool nullToAbsent) {
    return StoredBookshelfBaseFilterOrdersCompanion(
      filterKey: Value(filterKey),
      position: Value(position),
    );
  }

  factory StoredBookshelfBaseFilterOrder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredBookshelfBaseFilterOrder(
      filterKey: serializer.fromJson<String>(json['filterKey']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'filterKey': serializer.toJson<String>(filterKey),
      'position': serializer.toJson<int>(position),
    };
  }

  StoredBookshelfBaseFilterOrder copyWith({String? filterKey, int? position}) =>
      StoredBookshelfBaseFilterOrder(
        filterKey: filterKey ?? this.filterKey,
        position: position ?? this.position,
      );
  StoredBookshelfBaseFilterOrder copyWithCompanion(
    StoredBookshelfBaseFilterOrdersCompanion data,
  ) {
    return StoredBookshelfBaseFilterOrder(
      filterKey: data.filterKey.present ? data.filterKey.value : this.filterKey,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredBookshelfBaseFilterOrder(')
          ..write('filterKey: $filterKey, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(filterKey, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredBookshelfBaseFilterOrder &&
          other.filterKey == this.filterKey &&
          other.position == this.position);
}

class StoredBookshelfBaseFilterOrdersCompanion
    extends UpdateCompanion<StoredBookshelfBaseFilterOrder> {
  final Value<String> filterKey;
  final Value<int> position;
  final Value<int> rowid;
  const StoredBookshelfBaseFilterOrdersCompanion({
    this.filterKey = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredBookshelfBaseFilterOrdersCompanion.insert({
    required String filterKey,
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : filterKey = Value(filterKey);
  static Insertable<StoredBookshelfBaseFilterOrder> custom({
    Expression<String>? filterKey,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (filterKey != null) 'filter_key': filterKey,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredBookshelfBaseFilterOrdersCompanion copyWith({
    Value<String>? filterKey,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return StoredBookshelfBaseFilterOrdersCompanion(
      filterKey: filterKey ?? this.filterKey,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (filterKey.present) {
      map['filter_key'] = Variable<String>(filterKey.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoredBookshelfBaseFilterOrdersCompanion(')
          ..write('filterKey: $filterKey, ')
          ..write('position: $position, ')
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

class $StoredSyncProfilesTable extends StoredSyncProfiles
    with TableInfo<$StoredSyncProfilesTable, StoredSyncProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredSyncProfilesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _driverTypeMeta = const VerificationMeta(
    'driverType',
  );
  @override
  late final GeneratedColumn<String> driverType = GeneratedColumn<String>(
    'driver_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endpointUrlMeta = const VerificationMeta(
    'endpointUrl',
  );
  @override
  late final GeneratedColumn<String> endpointUrl = GeneratedColumn<String>(
    'endpoint_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _basePathMeta = const VerificationMeta(
    'basePath',
  );
  @override
  late final GeneratedColumn<String> basePath = GeneratedColumn<String>(
    'base_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _secretRefMeta = const VerificationMeta(
    'secretRef',
  );
  @override
  late final GeneratedColumn<String> secretRef = GeneratedColumn<String>(
    'secret_ref',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enabledScopesJsonMeta = const VerificationMeta(
    'enabledScopesJson',
  );
  @override
  late final GeneratedColumn<String> enabledScopesJson =
      GeneratedColumn<String>(
        'enabled_scopes_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _scopeConfigJsonMeta = const VerificationMeta(
    'scopeConfigJson',
  );
  @override
  late final GeneratedColumn<String> scopeConfigJson = GeneratedColumn<String>(
    'scope_config_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isAutoSyncEnabledMeta = const VerificationMeta(
    'isAutoSyncEnabled',
  );
  @override
  late final GeneratedColumn<bool> isAutoSyncEnabled = GeneratedColumn<bool>(
    'is_auto_sync_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_auto_sync_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastSyncAtMeta = const VerificationMeta(
    'lastSyncAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncAt = GeneratedColumn<DateTime>(
    'last_sync_at',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    driverType,
    endpointUrl,
    basePath,
    username,
    secretRef,
    enabledScopesJson,
    scopeConfigJson,
    isAutoSyncEnabled,
    lastSyncAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredSyncProfile> instance, {
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
    if (data.containsKey('driver_type')) {
      context.handle(
        _driverTypeMeta,
        driverType.isAcceptableOrUnknown(data['driver_type']!, _driverTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_driverTypeMeta);
    }
    if (data.containsKey('endpoint_url')) {
      context.handle(
        _endpointUrlMeta,
        endpointUrl.isAcceptableOrUnknown(
          data['endpoint_url']!,
          _endpointUrlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_endpointUrlMeta);
    }
    if (data.containsKey('base_path')) {
      context.handle(
        _basePathMeta,
        basePath.isAcceptableOrUnknown(data['base_path']!, _basePathMeta),
      );
    } else if (isInserting) {
      context.missing(_basePathMeta);
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('secret_ref')) {
      context.handle(
        _secretRefMeta,
        secretRef.isAcceptableOrUnknown(data['secret_ref']!, _secretRefMeta),
      );
    }
    if (data.containsKey('enabled_scopes_json')) {
      context.handle(
        _enabledScopesJsonMeta,
        enabledScopesJson.isAcceptableOrUnknown(
          data['enabled_scopes_json']!,
          _enabledScopesJsonMeta,
        ),
      );
    }
    if (data.containsKey('scope_config_json')) {
      context.handle(
        _scopeConfigJsonMeta,
        scopeConfigJson.isAcceptableOrUnknown(
          data['scope_config_json']!,
          _scopeConfigJsonMeta,
        ),
      );
    }
    if (data.containsKey('is_auto_sync_enabled')) {
      context.handle(
        _isAutoSyncEnabledMeta,
        isAutoSyncEnabled.isAcceptableOrUnknown(
          data['is_auto_sync_enabled']!,
          _isAutoSyncEnabledMeta,
        ),
      );
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
        _lastSyncAtMeta,
        lastSyncAt.isAcceptableOrUnknown(
          data['last_sync_at']!,
          _lastSyncAtMeta,
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredSyncProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredSyncProfile(
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
      driverType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}driver_type'],
          )!,
      endpointUrl:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}endpoint_url'],
          )!,
      basePath:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}base_path'],
          )!,
      username:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}username'],
          )!,
      secretRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secret_ref'],
      ),
      enabledScopesJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}enabled_scopes_json'],
          )!,
      scopeConfigJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_config_json'],
      ),
      isAutoSyncEnabled:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_auto_sync_enabled'],
          )!,
      lastSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_sync_at'],
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
  $StoredSyncProfilesTable createAlias(String alias) {
    return $StoredSyncProfilesTable(attachedDatabase, alias);
  }
}

class StoredSyncProfile extends DataClass
    implements Insertable<StoredSyncProfile> {
  final String id;
  final String name;
  final String driverType;
  final String endpointUrl;
  final String basePath;
  final String username;
  final String? secretRef;
  final String enabledScopesJson;
  final String? scopeConfigJson;
  final bool isAutoSyncEnabled;
  final DateTime? lastSyncAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const StoredSyncProfile({
    required this.id,
    required this.name,
    required this.driverType,
    required this.endpointUrl,
    required this.basePath,
    required this.username,
    this.secretRef,
    required this.enabledScopesJson,
    this.scopeConfigJson,
    required this.isAutoSyncEnabled,
    this.lastSyncAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['driver_type'] = Variable<String>(driverType);
    map['endpoint_url'] = Variable<String>(endpointUrl);
    map['base_path'] = Variable<String>(basePath);
    map['username'] = Variable<String>(username);
    if (!nullToAbsent || secretRef != null) {
      map['secret_ref'] = Variable<String>(secretRef);
    }
    map['enabled_scopes_json'] = Variable<String>(enabledScopesJson);
    if (!nullToAbsent || scopeConfigJson != null) {
      map['scope_config_json'] = Variable<String>(scopeConfigJson);
    }
    map['is_auto_sync_enabled'] = Variable<bool>(isAutoSyncEnabled);
    if (!nullToAbsent || lastSyncAt != null) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StoredSyncProfilesCompanion toCompanion(bool nullToAbsent) {
    return StoredSyncProfilesCompanion(
      id: Value(id),
      name: Value(name),
      driverType: Value(driverType),
      endpointUrl: Value(endpointUrl),
      basePath: Value(basePath),
      username: Value(username),
      secretRef:
          secretRef == null && nullToAbsent
              ? const Value.absent()
              : Value(secretRef),
      enabledScopesJson: Value(enabledScopesJson),
      scopeConfigJson:
          scopeConfigJson == null && nullToAbsent
              ? const Value.absent()
              : Value(scopeConfigJson),
      isAutoSyncEnabled: Value(isAutoSyncEnabled),
      lastSyncAt:
          lastSyncAt == null && nullToAbsent
              ? const Value.absent()
              : Value(lastSyncAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredSyncProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredSyncProfile(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      driverType: serializer.fromJson<String>(json['driverType']),
      endpointUrl: serializer.fromJson<String>(json['endpointUrl']),
      basePath: serializer.fromJson<String>(json['basePath']),
      username: serializer.fromJson<String>(json['username']),
      secretRef: serializer.fromJson<String?>(json['secretRef']),
      enabledScopesJson: serializer.fromJson<String>(json['enabledScopesJson']),
      scopeConfigJson: serializer.fromJson<String?>(json['scopeConfigJson']),
      isAutoSyncEnabled: serializer.fromJson<bool>(json['isAutoSyncEnabled']),
      lastSyncAt: serializer.fromJson<DateTime?>(json['lastSyncAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'driverType': serializer.toJson<String>(driverType),
      'endpointUrl': serializer.toJson<String>(endpointUrl),
      'basePath': serializer.toJson<String>(basePath),
      'username': serializer.toJson<String>(username),
      'secretRef': serializer.toJson<String?>(secretRef),
      'enabledScopesJson': serializer.toJson<String>(enabledScopesJson),
      'scopeConfigJson': serializer.toJson<String?>(scopeConfigJson),
      'isAutoSyncEnabled': serializer.toJson<bool>(isAutoSyncEnabled),
      'lastSyncAt': serializer.toJson<DateTime?>(lastSyncAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredSyncProfile copyWith({
    String? id,
    String? name,
    String? driverType,
    String? endpointUrl,
    String? basePath,
    String? username,
    Value<String?> secretRef = const Value.absent(),
    String? enabledScopesJson,
    Value<String?> scopeConfigJson = const Value.absent(),
    bool? isAutoSyncEnabled,
    Value<DateTime?> lastSyncAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StoredSyncProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    driverType: driverType ?? this.driverType,
    endpointUrl: endpointUrl ?? this.endpointUrl,
    basePath: basePath ?? this.basePath,
    username: username ?? this.username,
    secretRef: secretRef.present ? secretRef.value : this.secretRef,
    enabledScopesJson: enabledScopesJson ?? this.enabledScopesJson,
    scopeConfigJson:
        scopeConfigJson.present ? scopeConfigJson.value : this.scopeConfigJson,
    isAutoSyncEnabled: isAutoSyncEnabled ?? this.isAutoSyncEnabled,
    lastSyncAt: lastSyncAt.present ? lastSyncAt.value : this.lastSyncAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredSyncProfile copyWithCompanion(StoredSyncProfilesCompanion data) {
    return StoredSyncProfile(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      driverType:
          data.driverType.present ? data.driverType.value : this.driverType,
      endpointUrl:
          data.endpointUrl.present ? data.endpointUrl.value : this.endpointUrl,
      basePath: data.basePath.present ? data.basePath.value : this.basePath,
      username: data.username.present ? data.username.value : this.username,
      secretRef: data.secretRef.present ? data.secretRef.value : this.secretRef,
      enabledScopesJson:
          data.enabledScopesJson.present
              ? data.enabledScopesJson.value
              : this.enabledScopesJson,
      scopeConfigJson:
          data.scopeConfigJson.present
              ? data.scopeConfigJson.value
              : this.scopeConfigJson,
      isAutoSyncEnabled:
          data.isAutoSyncEnabled.present
              ? data.isAutoSyncEnabled.value
              : this.isAutoSyncEnabled,
      lastSyncAt:
          data.lastSyncAt.present ? data.lastSyncAt.value : this.lastSyncAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredSyncProfile(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('driverType: $driverType, ')
          ..write('endpointUrl: $endpointUrl, ')
          ..write('basePath: $basePath, ')
          ..write('username: $username, ')
          ..write('secretRef: $secretRef, ')
          ..write('enabledScopesJson: $enabledScopesJson, ')
          ..write('scopeConfigJson: $scopeConfigJson, ')
          ..write('isAutoSyncEnabled: $isAutoSyncEnabled, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    driverType,
    endpointUrl,
    basePath,
    username,
    secretRef,
    enabledScopesJson,
    scopeConfigJson,
    isAutoSyncEnabled,
    lastSyncAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredSyncProfile &&
          other.id == this.id &&
          other.name == this.name &&
          other.driverType == this.driverType &&
          other.endpointUrl == this.endpointUrl &&
          other.basePath == this.basePath &&
          other.username == this.username &&
          other.secretRef == this.secretRef &&
          other.enabledScopesJson == this.enabledScopesJson &&
          other.scopeConfigJson == this.scopeConfigJson &&
          other.isAutoSyncEnabled == this.isAutoSyncEnabled &&
          other.lastSyncAt == this.lastSyncAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class StoredSyncProfilesCompanion extends UpdateCompanion<StoredSyncProfile> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> driverType;
  final Value<String> endpointUrl;
  final Value<String> basePath;
  final Value<String> username;
  final Value<String?> secretRef;
  final Value<String> enabledScopesJson;
  final Value<String?> scopeConfigJson;
  final Value<bool> isAutoSyncEnabled;
  final Value<DateTime?> lastSyncAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StoredSyncProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.driverType = const Value.absent(),
    this.endpointUrl = const Value.absent(),
    this.basePath = const Value.absent(),
    this.username = const Value.absent(),
    this.secretRef = const Value.absent(),
    this.enabledScopesJson = const Value.absent(),
    this.scopeConfigJson = const Value.absent(),
    this.isAutoSyncEnabled = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredSyncProfilesCompanion.insert({
    required String id,
    required String name,
    required String driverType,
    required String endpointUrl,
    required String basePath,
    required String username,
    this.secretRef = const Value.absent(),
    this.enabledScopesJson = const Value.absent(),
    this.scopeConfigJson = const Value.absent(),
    this.isAutoSyncEnabled = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       driverType = Value(driverType),
       endpointUrl = Value(endpointUrl),
       basePath = Value(basePath),
       username = Value(username);
  static Insertable<StoredSyncProfile> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? driverType,
    Expression<String>? endpointUrl,
    Expression<String>? basePath,
    Expression<String>? username,
    Expression<String>? secretRef,
    Expression<String>? enabledScopesJson,
    Expression<String>? scopeConfigJson,
    Expression<bool>? isAutoSyncEnabled,
    Expression<DateTime>? lastSyncAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (driverType != null) 'driver_type': driverType,
      if (endpointUrl != null) 'endpoint_url': endpointUrl,
      if (basePath != null) 'base_path': basePath,
      if (username != null) 'username': username,
      if (secretRef != null) 'secret_ref': secretRef,
      if (enabledScopesJson != null) 'enabled_scopes_json': enabledScopesJson,
      if (scopeConfigJson != null) 'scope_config_json': scopeConfigJson,
      if (isAutoSyncEnabled != null) 'is_auto_sync_enabled': isAutoSyncEnabled,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredSyncProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? driverType,
    Value<String>? endpointUrl,
    Value<String>? basePath,
    Value<String>? username,
    Value<String?>? secretRef,
    Value<String>? enabledScopesJson,
    Value<String?>? scopeConfigJson,
    Value<bool>? isAutoSyncEnabled,
    Value<DateTime?>? lastSyncAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StoredSyncProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      driverType: driverType ?? this.driverType,
      endpointUrl: endpointUrl ?? this.endpointUrl,
      basePath: basePath ?? this.basePath,
      username: username ?? this.username,
      secretRef: secretRef ?? this.secretRef,
      enabledScopesJson: enabledScopesJson ?? this.enabledScopesJson,
      scopeConfigJson: scopeConfigJson ?? this.scopeConfigJson,
      isAutoSyncEnabled: isAutoSyncEnabled ?? this.isAutoSyncEnabled,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (driverType.present) {
      map['driver_type'] = Variable<String>(driverType.value);
    }
    if (endpointUrl.present) {
      map['endpoint_url'] = Variable<String>(endpointUrl.value);
    }
    if (basePath.present) {
      map['base_path'] = Variable<String>(basePath.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (secretRef.present) {
      map['secret_ref'] = Variable<String>(secretRef.value);
    }
    if (enabledScopesJson.present) {
      map['enabled_scopes_json'] = Variable<String>(enabledScopesJson.value);
    }
    if (scopeConfigJson.present) {
      map['scope_config_json'] = Variable<String>(scopeConfigJson.value);
    }
    if (isAutoSyncEnabled.present) {
      map['is_auto_sync_enabled'] = Variable<bool>(isAutoSyncEnabled.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<DateTime>(lastSyncAt.value);
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
    return (StringBuffer('StoredSyncProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('driverType: $driverType, ')
          ..write('endpointUrl: $endpointUrl, ')
          ..write('basePath: $basePath, ')
          ..write('username: $username, ')
          ..write('secretRef: $secretRef, ')
          ..write('enabledScopesJson: $enabledScopesJson, ')
          ..write('scopeConfigJson: $scopeConfigJson, ')
          ..write('isAutoSyncEnabled: $isAutoSyncEnabled, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredSyncScopeStatesTable extends StoredSyncScopeStates
    with TableInfo<$StoredSyncScopeStatesTable, StoredSyncScopeState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredSyncScopeStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastBaseSnapshotJsonMeta =
      const VerificationMeta('lastBaseSnapshotJson');
  @override
  late final GeneratedColumn<String> lastBaseSnapshotJson =
      GeneratedColumn<String>(
        'last_base_snapshot_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastRemoteRevisionMeta =
      const VerificationMeta('lastRemoteRevision');
  @override
  late final GeneratedColumn<String> lastRemoteRevision =
      GeneratedColumn<String>(
        'last_remote_revision',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastRemoteHashMeta = const VerificationMeta(
    'lastRemoteHash',
  );
  @override
  late final GeneratedColumn<String> lastRemoteHash = GeneratedColumn<String>(
    'last_remote_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastLocalHashMeta = const VerificationMeta(
    'lastLocalHash',
  );
  @override
  late final GeneratedColumn<String> lastLocalHash = GeneratedColumn<String>(
    'last_local_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
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
  @override
  List<GeneratedColumn> get $columns => [
    profileId,
    scope,
    lastBaseSnapshotJson,
    lastRemoteRevision,
    lastRemoteHash,
    lastLocalHash,
    lastSyncedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_scope_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredSyncScopeState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('last_base_snapshot_json')) {
      context.handle(
        _lastBaseSnapshotJsonMeta,
        lastBaseSnapshotJson.isAcceptableOrUnknown(
          data['last_base_snapshot_json']!,
          _lastBaseSnapshotJsonMeta,
        ),
      );
    }
    if (data.containsKey('last_remote_revision')) {
      context.handle(
        _lastRemoteRevisionMeta,
        lastRemoteRevision.isAcceptableOrUnknown(
          data['last_remote_revision']!,
          _lastRemoteRevisionMeta,
        ),
      );
    }
    if (data.containsKey('last_remote_hash')) {
      context.handle(
        _lastRemoteHashMeta,
        lastRemoteHash.isAcceptableOrUnknown(
          data['last_remote_hash']!,
          _lastRemoteHashMeta,
        ),
      );
    }
    if (data.containsKey('last_local_hash')) {
      context.handle(
        _lastLocalHashMeta,
        lastLocalHash.isAcceptableOrUnknown(
          data['last_local_hash']!,
          _lastLocalHashMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {profileId, scope};
  @override
  StoredSyncScopeState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredSyncScopeState(
      profileId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}profile_id'],
          )!,
      scope:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}scope'],
          )!,
      lastBaseSnapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_base_snapshot_json'],
      ),
      lastRemoteRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_remote_revision'],
      ),
      lastRemoteHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_remote_hash'],
      ),
      lastLocalHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_local_hash'],
      ),
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
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
  $StoredSyncScopeStatesTable createAlias(String alias) {
    return $StoredSyncScopeStatesTable(attachedDatabase, alias);
  }
}

class StoredSyncScopeState extends DataClass
    implements Insertable<StoredSyncScopeState> {
  final String profileId;
  final String scope;
  final String? lastBaseSnapshotJson;
  final String? lastRemoteRevision;
  final String? lastRemoteHash;
  final String? lastLocalHash;
  final DateTime? lastSyncedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const StoredSyncScopeState({
    required this.profileId,
    required this.scope,
    this.lastBaseSnapshotJson,
    this.lastRemoteRevision,
    this.lastRemoteHash,
    this.lastLocalHash,
    this.lastSyncedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['profile_id'] = Variable<String>(profileId);
    map['scope'] = Variable<String>(scope);
    if (!nullToAbsent || lastBaseSnapshotJson != null) {
      map['last_base_snapshot_json'] = Variable<String>(lastBaseSnapshotJson);
    }
    if (!nullToAbsent || lastRemoteRevision != null) {
      map['last_remote_revision'] = Variable<String>(lastRemoteRevision);
    }
    if (!nullToAbsent || lastRemoteHash != null) {
      map['last_remote_hash'] = Variable<String>(lastRemoteHash);
    }
    if (!nullToAbsent || lastLocalHash != null) {
      map['last_local_hash'] = Variable<String>(lastLocalHash);
    }
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StoredSyncScopeStatesCompanion toCompanion(bool nullToAbsent) {
    return StoredSyncScopeStatesCompanion(
      profileId: Value(profileId),
      scope: Value(scope),
      lastBaseSnapshotJson:
          lastBaseSnapshotJson == null && nullToAbsent
              ? const Value.absent()
              : Value(lastBaseSnapshotJson),
      lastRemoteRevision:
          lastRemoteRevision == null && nullToAbsent
              ? const Value.absent()
              : Value(lastRemoteRevision),
      lastRemoteHash:
          lastRemoteHash == null && nullToAbsent
              ? const Value.absent()
              : Value(lastRemoteHash),
      lastLocalHash:
          lastLocalHash == null && nullToAbsent
              ? const Value.absent()
              : Value(lastLocalHash),
      lastSyncedAt:
          lastSyncedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(lastSyncedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredSyncScopeState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredSyncScopeState(
      profileId: serializer.fromJson<String>(json['profileId']),
      scope: serializer.fromJson<String>(json['scope']),
      lastBaseSnapshotJson: serializer.fromJson<String?>(
        json['lastBaseSnapshotJson'],
      ),
      lastRemoteRevision: serializer.fromJson<String?>(
        json['lastRemoteRevision'],
      ),
      lastRemoteHash: serializer.fromJson<String?>(json['lastRemoteHash']),
      lastLocalHash: serializer.fromJson<String?>(json['lastLocalHash']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'profileId': serializer.toJson<String>(profileId),
      'scope': serializer.toJson<String>(scope),
      'lastBaseSnapshotJson': serializer.toJson<String?>(lastBaseSnapshotJson),
      'lastRemoteRevision': serializer.toJson<String?>(lastRemoteRevision),
      'lastRemoteHash': serializer.toJson<String?>(lastRemoteHash),
      'lastLocalHash': serializer.toJson<String?>(lastLocalHash),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredSyncScopeState copyWith({
    String? profileId,
    String? scope,
    Value<String?> lastBaseSnapshotJson = const Value.absent(),
    Value<String?> lastRemoteRevision = const Value.absent(),
    Value<String?> lastRemoteHash = const Value.absent(),
    Value<String?> lastLocalHash = const Value.absent(),
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StoredSyncScopeState(
    profileId: profileId ?? this.profileId,
    scope: scope ?? this.scope,
    lastBaseSnapshotJson:
        lastBaseSnapshotJson.present
            ? lastBaseSnapshotJson.value
            : this.lastBaseSnapshotJson,
    lastRemoteRevision:
        lastRemoteRevision.present
            ? lastRemoteRevision.value
            : this.lastRemoteRevision,
    lastRemoteHash:
        lastRemoteHash.present ? lastRemoteHash.value : this.lastRemoteHash,
    lastLocalHash:
        lastLocalHash.present ? lastLocalHash.value : this.lastLocalHash,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredSyncScopeState copyWithCompanion(StoredSyncScopeStatesCompanion data) {
    return StoredSyncScopeState(
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      scope: data.scope.present ? data.scope.value : this.scope,
      lastBaseSnapshotJson:
          data.lastBaseSnapshotJson.present
              ? data.lastBaseSnapshotJson.value
              : this.lastBaseSnapshotJson,
      lastRemoteRevision:
          data.lastRemoteRevision.present
              ? data.lastRemoteRevision.value
              : this.lastRemoteRevision,
      lastRemoteHash:
          data.lastRemoteHash.present
              ? data.lastRemoteHash.value
              : this.lastRemoteHash,
      lastLocalHash:
          data.lastLocalHash.present
              ? data.lastLocalHash.value
              : this.lastLocalHash,
      lastSyncedAt:
          data.lastSyncedAt.present
              ? data.lastSyncedAt.value
              : this.lastSyncedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredSyncScopeState(')
          ..write('profileId: $profileId, ')
          ..write('scope: $scope, ')
          ..write('lastBaseSnapshotJson: $lastBaseSnapshotJson, ')
          ..write('lastRemoteRevision: $lastRemoteRevision, ')
          ..write('lastRemoteHash: $lastRemoteHash, ')
          ..write('lastLocalHash: $lastLocalHash, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    profileId,
    scope,
    lastBaseSnapshotJson,
    lastRemoteRevision,
    lastRemoteHash,
    lastLocalHash,
    lastSyncedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredSyncScopeState &&
          other.profileId == this.profileId &&
          other.scope == this.scope &&
          other.lastBaseSnapshotJson == this.lastBaseSnapshotJson &&
          other.lastRemoteRevision == this.lastRemoteRevision &&
          other.lastRemoteHash == this.lastRemoteHash &&
          other.lastLocalHash == this.lastLocalHash &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class StoredSyncScopeStatesCompanion
    extends UpdateCompanion<StoredSyncScopeState> {
  final Value<String> profileId;
  final Value<String> scope;
  final Value<String?> lastBaseSnapshotJson;
  final Value<String?> lastRemoteRevision;
  final Value<String?> lastRemoteHash;
  final Value<String?> lastLocalHash;
  final Value<DateTime?> lastSyncedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StoredSyncScopeStatesCompanion({
    this.profileId = const Value.absent(),
    this.scope = const Value.absent(),
    this.lastBaseSnapshotJson = const Value.absent(),
    this.lastRemoteRevision = const Value.absent(),
    this.lastRemoteHash = const Value.absent(),
    this.lastLocalHash = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredSyncScopeStatesCompanion.insert({
    required String profileId,
    required String scope,
    this.lastBaseSnapshotJson = const Value.absent(),
    this.lastRemoteRevision = const Value.absent(),
    this.lastRemoteHash = const Value.absent(),
    this.lastLocalHash = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : profileId = Value(profileId),
       scope = Value(scope);
  static Insertable<StoredSyncScopeState> custom({
    Expression<String>? profileId,
    Expression<String>? scope,
    Expression<String>? lastBaseSnapshotJson,
    Expression<String>? lastRemoteRevision,
    Expression<String>? lastRemoteHash,
    Expression<String>? lastLocalHash,
    Expression<DateTime>? lastSyncedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (profileId != null) 'profile_id': profileId,
      if (scope != null) 'scope': scope,
      if (lastBaseSnapshotJson != null)
        'last_base_snapshot_json': lastBaseSnapshotJson,
      if (lastRemoteRevision != null)
        'last_remote_revision': lastRemoteRevision,
      if (lastRemoteHash != null) 'last_remote_hash': lastRemoteHash,
      if (lastLocalHash != null) 'last_local_hash': lastLocalHash,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredSyncScopeStatesCompanion copyWith({
    Value<String>? profileId,
    Value<String>? scope,
    Value<String?>? lastBaseSnapshotJson,
    Value<String?>? lastRemoteRevision,
    Value<String?>? lastRemoteHash,
    Value<String?>? lastLocalHash,
    Value<DateTime?>? lastSyncedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StoredSyncScopeStatesCompanion(
      profileId: profileId ?? this.profileId,
      scope: scope ?? this.scope,
      lastBaseSnapshotJson: lastBaseSnapshotJson ?? this.lastBaseSnapshotJson,
      lastRemoteRevision: lastRemoteRevision ?? this.lastRemoteRevision,
      lastRemoteHash: lastRemoteHash ?? this.lastRemoteHash,
      lastLocalHash: lastLocalHash ?? this.lastLocalHash,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (lastBaseSnapshotJson.present) {
      map['last_base_snapshot_json'] = Variable<String>(
        lastBaseSnapshotJson.value,
      );
    }
    if (lastRemoteRevision.present) {
      map['last_remote_revision'] = Variable<String>(lastRemoteRevision.value);
    }
    if (lastRemoteHash.present) {
      map['last_remote_hash'] = Variable<String>(lastRemoteHash.value);
    }
    if (lastLocalHash.present) {
      map['last_local_hash'] = Variable<String>(lastLocalHash.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
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
    return (StringBuffer('StoredSyncScopeStatesCompanion(')
          ..write('profileId: $profileId, ')
          ..write('scope: $scope, ')
          ..write('lastBaseSnapshotJson: $lastBaseSnapshotJson, ')
          ..write('lastRemoteRevision: $lastRemoteRevision, ')
          ..write('lastRemoteHash: $lastRemoteHash, ')
          ..write('lastLocalHash: $lastLocalHash, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredSyncJobsTable extends StoredSyncJobs
    with TableInfo<$StoredSyncJobsTable, StoredSyncJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredSyncJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _triggerKindMeta = const VerificationMeta(
    'triggerKind',
  );
  @override
  late final GeneratedColumn<String> triggerKind = GeneratedColumn<String>(
    'trigger_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('bidirectional'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summaryJsonMeta = const VerificationMeta(
    'summaryJson',
  );
  @override
  late final GeneratedColumn<String> summaryJson = GeneratedColumn<String>(
    'summary_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    triggerKind,
    direction,
    status,
    startedAt,
    endedAt,
    summaryJson,
    errorMessage,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredSyncJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('trigger_kind')) {
      context.handle(
        _triggerKindMeta,
        triggerKind.isAcceptableOrUnknown(
          data['trigger_kind']!,
          _triggerKindMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_triggerKindMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('summary_json')) {
      context.handle(
        _summaryJsonMeta,
        summaryJson.isAcceptableOrUnknown(
          data['summary_json']!,
          _summaryJsonMeta,
        ),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredSyncJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredSyncJob(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      profileId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}profile_id'],
          )!,
      triggerKind:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}trigger_kind'],
          )!,
      direction:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}direction'],
          )!,
      status:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}status'],
          )!,
      startedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}started_at'],
          )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      summaryJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_json'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
    );
  }

  @override
  $StoredSyncJobsTable createAlias(String alias) {
    return $StoredSyncJobsTable(attachedDatabase, alias);
  }
}

class StoredSyncJob extends DataClass implements Insertable<StoredSyncJob> {
  final String id;
  final String profileId;
  final String triggerKind;
  final String direction;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? summaryJson;
  final String? errorMessage;
  const StoredSyncJob({
    required this.id,
    required this.profileId,
    required this.triggerKind,
    required this.direction,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.summaryJson,
    this.errorMessage,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['trigger_kind'] = Variable<String>(triggerKind);
    map['direction'] = Variable<String>(direction);
    map['status'] = Variable<String>(status);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    if (!nullToAbsent || summaryJson != null) {
      map['summary_json'] = Variable<String>(summaryJson);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    return map;
  }

  StoredSyncJobsCompanion toCompanion(bool nullToAbsent) {
    return StoredSyncJobsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      triggerKind: Value(triggerKind),
      direction: Value(direction),
      status: Value(status),
      startedAt: Value(startedAt),
      endedAt:
          endedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(endedAt),
      summaryJson:
          summaryJson == null && nullToAbsent
              ? const Value.absent()
              : Value(summaryJson),
      errorMessage:
          errorMessage == null && nullToAbsent
              ? const Value.absent()
              : Value(errorMessage),
    );
  }

  factory StoredSyncJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredSyncJob(
      id: serializer.fromJson<String>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      triggerKind: serializer.fromJson<String>(json['triggerKind']),
      direction: serializer.fromJson<String>(json['direction']),
      status: serializer.fromJson<String>(json['status']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      summaryJson: serializer.fromJson<String?>(json['summaryJson']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileId': serializer.toJson<String>(profileId),
      'triggerKind': serializer.toJson<String>(triggerKind),
      'direction': serializer.toJson<String>(direction),
      'status': serializer.toJson<String>(status),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'summaryJson': serializer.toJson<String?>(summaryJson),
      'errorMessage': serializer.toJson<String?>(errorMessage),
    };
  }

  StoredSyncJob copyWith({
    String? id,
    String? profileId,
    String? triggerKind,
    String? direction,
    String? status,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    Value<String?> summaryJson = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
  }) => StoredSyncJob(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    triggerKind: triggerKind ?? this.triggerKind,
    direction: direction ?? this.direction,
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    summaryJson: summaryJson.present ? summaryJson.value : this.summaryJson,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
  );
  StoredSyncJob copyWithCompanion(StoredSyncJobsCompanion data) {
    return StoredSyncJob(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      triggerKind:
          data.triggerKind.present ? data.triggerKind.value : this.triggerKind,
      direction: data.direction.present ? data.direction.value : this.direction,
      status: data.status.present ? data.status.value : this.status,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      summaryJson:
          data.summaryJson.present ? data.summaryJson.value : this.summaryJson,
      errorMessage:
          data.errorMessage.present
              ? data.errorMessage.value
              : this.errorMessage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredSyncJob(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('triggerKind: $triggerKind, ')
          ..write('direction: $direction, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    triggerKind,
    direction,
    status,
    startedAt,
    endedAt,
    summaryJson,
    errorMessage,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredSyncJob &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.triggerKind == this.triggerKind &&
          other.direction == this.direction &&
          other.status == this.status &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.summaryJson == this.summaryJson &&
          other.errorMessage == this.errorMessage);
}

class StoredSyncJobsCompanion extends UpdateCompanion<StoredSyncJob> {
  final Value<String> id;
  final Value<String> profileId;
  final Value<String> triggerKind;
  final Value<String> direction;
  final Value<String> status;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<String?> summaryJson;
  final Value<String?> errorMessage;
  final Value<int> rowid;
  const StoredSyncJobsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.triggerKind = const Value.absent(),
    this.direction = const Value.absent(),
    this.status = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.summaryJson = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredSyncJobsCompanion.insert({
    required String id,
    required String profileId,
    required String triggerKind,
    this.direction = const Value.absent(),
    required String status,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.summaryJson = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       profileId = Value(profileId),
       triggerKind = Value(triggerKind),
       status = Value(status),
       startedAt = Value(startedAt);
  static Insertable<StoredSyncJob> custom({
    Expression<String>? id,
    Expression<String>? profileId,
    Expression<String>? triggerKind,
    Expression<String>? direction,
    Expression<String>? status,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<String>? summaryJson,
    Expression<String>? errorMessage,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (triggerKind != null) 'trigger_kind': triggerKind,
      if (direction != null) 'direction': direction,
      if (status != null) 'status': status,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (summaryJson != null) 'summary_json': summaryJson,
      if (errorMessage != null) 'error_message': errorMessage,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredSyncJobsCompanion copyWith({
    Value<String>? id,
    Value<String>? profileId,
    Value<String>? triggerKind,
    Value<String>? direction,
    Value<String>? status,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<String?>? summaryJson,
    Value<String?>? errorMessage,
    Value<int>? rowid,
  }) {
    return StoredSyncJobsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      triggerKind: triggerKind ?? this.triggerKind,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      summaryJson: summaryJson ?? this.summaryJson,
      errorMessage: errorMessage ?? this.errorMessage,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (triggerKind.present) {
      map['trigger_kind'] = Variable<String>(triggerKind.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (summaryJson.present) {
      map['summary_json'] = Variable<String>(summaryJson.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoredSyncJobsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('triggerKind: $triggerKind, ')
          ..write('direction: $direction, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredSyncConflictsTable extends StoredSyncConflicts
    with TableInfo<$StoredSyncConflictsTable, StoredSyncConflict> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredSyncConflictsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordKeyMeta = const VerificationMeta(
    'recordKey',
  );
  @override
  late final GeneratedColumn<String> recordKey = GeneratedColumn<String>(
    'record_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _basePayloadJsonMeta = const VerificationMeta(
    'basePayloadJson',
  );
  @override
  late final GeneratedColumn<String> basePayloadJson = GeneratedColumn<String>(
    'base_payload_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localPayloadJsonMeta = const VerificationMeta(
    'localPayloadJson',
  );
  @override
  late final GeneratedColumn<String> localPayloadJson = GeneratedColumn<String>(
    'local_payload_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remotePayloadJsonMeta = const VerificationMeta(
    'remotePayloadJson',
  );
  @override
  late final GeneratedColumn<String> remotePayloadJson =
      GeneratedColumn<String>(
        'remote_payload_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _resolutionMeta = const VerificationMeta(
    'resolution',
  );
  @override
  late final GeneratedColumn<String> resolution = GeneratedColumn<String>(
    'resolution',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unresolved'),
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
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    profileId,
    scope,
    recordKey,
    basePayloadJson,
    localPayloadJson,
    remotePayloadJson,
    resolution,
    createdAt,
    resolvedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredSyncConflict> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('record_key')) {
      context.handle(
        _recordKeyMeta,
        recordKey.isAcceptableOrUnknown(data['record_key']!, _recordKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_recordKeyMeta);
    }
    if (data.containsKey('base_payload_json')) {
      context.handle(
        _basePayloadJsonMeta,
        basePayloadJson.isAcceptableOrUnknown(
          data['base_payload_json']!,
          _basePayloadJsonMeta,
        ),
      );
    }
    if (data.containsKey('local_payload_json')) {
      context.handle(
        _localPayloadJsonMeta,
        localPayloadJson.isAcceptableOrUnknown(
          data['local_payload_json']!,
          _localPayloadJsonMeta,
        ),
      );
    }
    if (data.containsKey('remote_payload_json')) {
      context.handle(
        _remotePayloadJsonMeta,
        remotePayloadJson.isAcceptableOrUnknown(
          data['remote_payload_json']!,
          _remotePayloadJsonMeta,
        ),
      );
    }
    if (data.containsKey('resolution')) {
      context.handle(
        _resolutionMeta,
        resolution.isAcceptableOrUnknown(data['resolution']!, _resolutionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredSyncConflict map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredSyncConflict(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      profileId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}profile_id'],
          )!,
      scope:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}scope'],
          )!,
      recordKey:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}record_key'],
          )!,
      basePayloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_payload_json'],
      ),
      localPayloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_payload_json'],
      ),
      remotePayloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_payload_json'],
      ),
      resolution:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}resolution'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at'],
      ),
    );
  }

  @override
  $StoredSyncConflictsTable createAlias(String alias) {
    return $StoredSyncConflictsTable(attachedDatabase, alias);
  }
}

class StoredSyncConflict extends DataClass
    implements Insertable<StoredSyncConflict> {
  final String id;
  final String profileId;
  final String scope;
  final String recordKey;
  final String? basePayloadJson;
  final String? localPayloadJson;
  final String? remotePayloadJson;
  final String resolution;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  const StoredSyncConflict({
    required this.id,
    required this.profileId,
    required this.scope,
    required this.recordKey,
    this.basePayloadJson,
    this.localPayloadJson,
    this.remotePayloadJson,
    required this.resolution,
    required this.createdAt,
    this.resolvedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['profile_id'] = Variable<String>(profileId);
    map['scope'] = Variable<String>(scope);
    map['record_key'] = Variable<String>(recordKey);
    if (!nullToAbsent || basePayloadJson != null) {
      map['base_payload_json'] = Variable<String>(basePayloadJson);
    }
    if (!nullToAbsent || localPayloadJson != null) {
      map['local_payload_json'] = Variable<String>(localPayloadJson);
    }
    if (!nullToAbsent || remotePayloadJson != null) {
      map['remote_payload_json'] = Variable<String>(remotePayloadJson);
    }
    map['resolution'] = Variable<String>(resolution);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    return map;
  }

  StoredSyncConflictsCompanion toCompanion(bool nullToAbsent) {
    return StoredSyncConflictsCompanion(
      id: Value(id),
      profileId: Value(profileId),
      scope: Value(scope),
      recordKey: Value(recordKey),
      basePayloadJson:
          basePayloadJson == null && nullToAbsent
              ? const Value.absent()
              : Value(basePayloadJson),
      localPayloadJson:
          localPayloadJson == null && nullToAbsent
              ? const Value.absent()
              : Value(localPayloadJson),
      remotePayloadJson:
          remotePayloadJson == null && nullToAbsent
              ? const Value.absent()
              : Value(remotePayloadJson),
      resolution: Value(resolution),
      createdAt: Value(createdAt),
      resolvedAt:
          resolvedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(resolvedAt),
    );
  }

  factory StoredSyncConflict.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredSyncConflict(
      id: serializer.fromJson<String>(json['id']),
      profileId: serializer.fromJson<String>(json['profileId']),
      scope: serializer.fromJson<String>(json['scope']),
      recordKey: serializer.fromJson<String>(json['recordKey']),
      basePayloadJson: serializer.fromJson<String?>(json['basePayloadJson']),
      localPayloadJson: serializer.fromJson<String?>(json['localPayloadJson']),
      remotePayloadJson: serializer.fromJson<String?>(
        json['remotePayloadJson'],
      ),
      resolution: serializer.fromJson<String>(json['resolution']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'profileId': serializer.toJson<String>(profileId),
      'scope': serializer.toJson<String>(scope),
      'recordKey': serializer.toJson<String>(recordKey),
      'basePayloadJson': serializer.toJson<String?>(basePayloadJson),
      'localPayloadJson': serializer.toJson<String?>(localPayloadJson),
      'remotePayloadJson': serializer.toJson<String?>(remotePayloadJson),
      'resolution': serializer.toJson<String>(resolution),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
    };
  }

  StoredSyncConflict copyWith({
    String? id,
    String? profileId,
    String? scope,
    String? recordKey,
    Value<String?> basePayloadJson = const Value.absent(),
    Value<String?> localPayloadJson = const Value.absent(),
    Value<String?> remotePayloadJson = const Value.absent(),
    String? resolution,
    DateTime? createdAt,
    Value<DateTime?> resolvedAt = const Value.absent(),
  }) => StoredSyncConflict(
    id: id ?? this.id,
    profileId: profileId ?? this.profileId,
    scope: scope ?? this.scope,
    recordKey: recordKey ?? this.recordKey,
    basePayloadJson:
        basePayloadJson.present ? basePayloadJson.value : this.basePayloadJson,
    localPayloadJson:
        localPayloadJson.present
            ? localPayloadJson.value
            : this.localPayloadJson,
    remotePayloadJson:
        remotePayloadJson.present
            ? remotePayloadJson.value
            : this.remotePayloadJson,
    resolution: resolution ?? this.resolution,
    createdAt: createdAt ?? this.createdAt,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
  );
  StoredSyncConflict copyWithCompanion(StoredSyncConflictsCompanion data) {
    return StoredSyncConflict(
      id: data.id.present ? data.id.value : this.id,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      scope: data.scope.present ? data.scope.value : this.scope,
      recordKey: data.recordKey.present ? data.recordKey.value : this.recordKey,
      basePayloadJson:
          data.basePayloadJson.present
              ? data.basePayloadJson.value
              : this.basePayloadJson,
      localPayloadJson:
          data.localPayloadJson.present
              ? data.localPayloadJson.value
              : this.localPayloadJson,
      remotePayloadJson:
          data.remotePayloadJson.present
              ? data.remotePayloadJson.value
              : this.remotePayloadJson,
      resolution:
          data.resolution.present ? data.resolution.value : this.resolution,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      resolvedAt:
          data.resolvedAt.present ? data.resolvedAt.value : this.resolvedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredSyncConflict(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('scope: $scope, ')
          ..write('recordKey: $recordKey, ')
          ..write('basePayloadJson: $basePayloadJson, ')
          ..write('localPayloadJson: $localPayloadJson, ')
          ..write('remotePayloadJson: $remotePayloadJson, ')
          ..write('resolution: $resolution, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    profileId,
    scope,
    recordKey,
    basePayloadJson,
    localPayloadJson,
    remotePayloadJson,
    resolution,
    createdAt,
    resolvedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredSyncConflict &&
          other.id == this.id &&
          other.profileId == this.profileId &&
          other.scope == this.scope &&
          other.recordKey == this.recordKey &&
          other.basePayloadJson == this.basePayloadJson &&
          other.localPayloadJson == this.localPayloadJson &&
          other.remotePayloadJson == this.remotePayloadJson &&
          other.resolution == this.resolution &&
          other.createdAt == this.createdAt &&
          other.resolvedAt == this.resolvedAt);
}

class StoredSyncConflictsCompanion extends UpdateCompanion<StoredSyncConflict> {
  final Value<String> id;
  final Value<String> profileId;
  final Value<String> scope;
  final Value<String> recordKey;
  final Value<String?> basePayloadJson;
  final Value<String?> localPayloadJson;
  final Value<String?> remotePayloadJson;
  final Value<String> resolution;
  final Value<DateTime> createdAt;
  final Value<DateTime?> resolvedAt;
  final Value<int> rowid;
  const StoredSyncConflictsCompanion({
    this.id = const Value.absent(),
    this.profileId = const Value.absent(),
    this.scope = const Value.absent(),
    this.recordKey = const Value.absent(),
    this.basePayloadJson = const Value.absent(),
    this.localPayloadJson = const Value.absent(),
    this.remotePayloadJson = const Value.absent(),
    this.resolution = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredSyncConflictsCompanion.insert({
    required String id,
    required String profileId,
    required String scope,
    required String recordKey,
    this.basePayloadJson = const Value.absent(),
    this.localPayloadJson = const Value.absent(),
    this.remotePayloadJson = const Value.absent(),
    this.resolution = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       profileId = Value(profileId),
       scope = Value(scope),
       recordKey = Value(recordKey);
  static Insertable<StoredSyncConflict> custom({
    Expression<String>? id,
    Expression<String>? profileId,
    Expression<String>? scope,
    Expression<String>? recordKey,
    Expression<String>? basePayloadJson,
    Expression<String>? localPayloadJson,
    Expression<String>? remotePayloadJson,
    Expression<String>? resolution,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? resolvedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileId != null) 'profile_id': profileId,
      if (scope != null) 'scope': scope,
      if (recordKey != null) 'record_key': recordKey,
      if (basePayloadJson != null) 'base_payload_json': basePayloadJson,
      if (localPayloadJson != null) 'local_payload_json': localPayloadJson,
      if (remotePayloadJson != null) 'remote_payload_json': remotePayloadJson,
      if (resolution != null) 'resolution': resolution,
      if (createdAt != null) 'created_at': createdAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredSyncConflictsCompanion copyWith({
    Value<String>? id,
    Value<String>? profileId,
    Value<String>? scope,
    Value<String>? recordKey,
    Value<String?>? basePayloadJson,
    Value<String?>? localPayloadJson,
    Value<String?>? remotePayloadJson,
    Value<String>? resolution,
    Value<DateTime>? createdAt,
    Value<DateTime?>? resolvedAt,
    Value<int>? rowid,
  }) {
    return StoredSyncConflictsCompanion(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      scope: scope ?? this.scope,
      recordKey: recordKey ?? this.recordKey,
      basePayloadJson: basePayloadJson ?? this.basePayloadJson,
      localPayloadJson: localPayloadJson ?? this.localPayloadJson,
      remotePayloadJson: remotePayloadJson ?? this.remotePayloadJson,
      resolution: resolution ?? this.resolution,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (recordKey.present) {
      map['record_key'] = Variable<String>(recordKey.value);
    }
    if (basePayloadJson.present) {
      map['base_payload_json'] = Variable<String>(basePayloadJson.value);
    }
    if (localPayloadJson.present) {
      map['local_payload_json'] = Variable<String>(localPayloadJson.value);
    }
    if (remotePayloadJson.present) {
      map['remote_payload_json'] = Variable<String>(remotePayloadJson.value);
    }
    if (resolution.present) {
      map['resolution'] = Variable<String>(resolution.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoredSyncConflictsCompanion(')
          ..write('id: $id, ')
          ..write('profileId: $profileId, ')
          ..write('scope: $scope, ')
          ..write('recordKey: $recordKey, ')
          ..write('basePayloadJson: $basePayloadJson, ')
          ..write('localPayloadJson: $localPayloadJson, ')
          ..write('remotePayloadJson: $remotePayloadJson, ')
          ..write('resolution: $resolution, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ChapterCachesTable chapterCaches = $ChapterCachesTable(this);
  late final $StoredLocalBooksTable storedLocalBooks = $StoredLocalBooksTable(
    this,
  );
  late final $StoredLocalChaptersTable storedLocalChapters =
      $StoredLocalChaptersTable(this);
  late final $StoredBookmarksTable storedBookmarks = $StoredBookmarksTable(
    this,
  );
  late final $StoredBookMetadataOverridesTable storedBookMetadataOverrides =
      $StoredBookMetadataOverridesTable(this);
  late final $StoredReadingRecordsTable storedReadingRecords =
      $StoredReadingRecordsTable(this);
  late final $StoredReadingRecordDaysTable storedReadingRecordDays =
      $StoredReadingRecordDaysTable(this);
  late final $StoredReadingRecordSessionsTable storedReadingRecordSessions =
      $StoredReadingRecordSessionsTable(this);
  late final $StoredReadingBookStatusesTable storedReadingBookStatuses =
      $StoredReadingBookStatusesTable(this);
  late final $StoredReadingProgressesTable storedReadingProgresses =
      $StoredReadingProgressesTable(this);
  late final $StoredTocSnapshotsTable storedTocSnapshots =
      $StoredTocSnapshotsTable(this);
  late final $StoredRemoteAccessSnapshotsTable storedRemoteAccessSnapshots =
      $StoredRemoteAccessSnapshotsTable(this);
  late final $StoredSourceHealthSnapshotsTable storedSourceHealthSnapshots =
      $StoredSourceHealthSnapshotsTable(this);
  late final $StoredBookshelfBooksTable storedBookshelfBooks =
      $StoredBookshelfBooksTable(this);
  late final $StoredBookshelfTagAssignmentsTable storedBookshelfTagAssignments =
      $StoredBookshelfTagAssignmentsTable(this);
  late final $StoredBookshelfTagMetadataTable storedBookshelfTagMetadata =
      $StoredBookshelfTagMetadataTable(this);
  late final $StoredBookshelfCategoryMetadataTable
  storedBookshelfCategoryMetadata = $StoredBookshelfCategoryMetadataTable(this);
  late final $StoredBookshelfBaseFilterOrdersTable
  storedBookshelfBaseFilterOrders = $StoredBookshelfBaseFilterOrdersTable(this);
  late final $SearchSourceHitsTable searchSourceHits = $SearchSourceHitsTable(
    this,
  );
  late final $StoredSyncProfilesTable storedSyncProfiles =
      $StoredSyncProfilesTable(this);
  late final $StoredSyncScopeStatesTable storedSyncScopeStates =
      $StoredSyncScopeStatesTable(this);
  late final $StoredSyncJobsTable storedSyncJobs = $StoredSyncJobsTable(this);
  late final $StoredSyncConflictsTable storedSyncConflicts =
      $StoredSyncConflictsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    chapterCaches,
    storedLocalBooks,
    storedLocalChapters,
    storedBookmarks,
    storedBookMetadataOverrides,
    storedReadingRecords,
    storedReadingRecordDays,
    storedReadingRecordSessions,
    storedReadingBookStatuses,
    storedReadingProgresses,
    storedTocSnapshots,
    storedRemoteAccessSnapshots,
    storedSourceHealthSnapshots,
    storedBookshelfBooks,
    storedBookshelfTagAssignments,
    storedBookshelfTagMetadata,
    storedBookshelfCategoryMetadata,
    storedBookshelfBaseFilterOrders,
    searchSourceHits,
    storedSyncProfiles,
    storedSyncScopeStates,
    storedSyncJobs,
    storedSyncConflicts,
  ];
}

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
      Value<String?> charset,
      required int fileSize,
      Value<String?> author,
      Value<String?> description,
      Value<String?> coverPath,
      Value<int?> sourceFileSize,
      Value<int?> sourceFileLastModifiedMs,
      Value<int?> storageFileLastModifiedMs,
      Value<String> indexStatus,
      Value<int> chapterCount,
      Value<String?> lastError,
      Value<bool> splitLongChapter,
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
      Value<String?> charset,
      Value<int> fileSize,
      Value<String?> author,
      Value<String?> description,
      Value<String?> coverPath,
      Value<int?> sourceFileSize,
      Value<int?> sourceFileLastModifiedMs,
      Value<int?> storageFileLastModifiedMs,
      Value<String> indexStatus,
      Value<int> chapterCount,
      Value<String?> lastError,
      Value<bool> splitLongChapter,
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

  ColumnFilters<String> get charset => $composableBuilder(
    column: $table.charset,
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

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceFileSize => $composableBuilder(
    column: $table.sourceFileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceFileLastModifiedMs => $composableBuilder(
    column: $table.sourceFileLastModifiedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get storageFileLastModifiedMs => $composableBuilder(
    column: $table.storageFileLastModifiedMs,
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

  ColumnFilters<bool> get splitLongChapter => $composableBuilder(
    column: $table.splitLongChapter,
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

  ColumnOrderings<String> get charset => $composableBuilder(
    column: $table.charset,
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

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceFileSize => $composableBuilder(
    column: $table.sourceFileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceFileLastModifiedMs => $composableBuilder(
    column: $table.sourceFileLastModifiedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get storageFileLastModifiedMs => $composableBuilder(
    column: $table.storageFileLastModifiedMs,
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

  ColumnOrderings<bool> get splitLongChapter => $composableBuilder(
    column: $table.splitLongChapter,
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

  GeneratedColumn<String> get charset =>
      $composableBuilder(column: $table.charset, builder: (column) => column);

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<int> get sourceFileSize => $composableBuilder(
    column: $table.sourceFileSize,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sourceFileLastModifiedMs => $composableBuilder(
    column: $table.sourceFileLastModifiedMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get storageFileLastModifiedMs => $composableBuilder(
    column: $table.storageFileLastModifiedMs,
    builder: (column) => column,
  );

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

  GeneratedColumn<bool> get splitLongChapter => $composableBuilder(
    column: $table.splitLongChapter,
    builder: (column) => column,
  );

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
                Value<String?> charset = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<int?> sourceFileSize = const Value.absent(),
                Value<int?> sourceFileLastModifiedMs = const Value.absent(),
                Value<int?> storageFileLastModifiedMs = const Value.absent(),
                Value<String> indexStatus = const Value.absent(),
                Value<int> chapterCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<bool> splitLongChapter = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredLocalBooksCompanion(
                id: id,
                title: title,
                format: format,
                storagePath: storagePath,
                sourcePath: sourcePath,
                charset: charset,
                fileSize: fileSize,
                author: author,
                description: description,
                coverPath: coverPath,
                sourceFileSize: sourceFileSize,
                sourceFileLastModifiedMs: sourceFileLastModifiedMs,
                storageFileLastModifiedMs: storageFileLastModifiedMs,
                indexStatus: indexStatus,
                chapterCount: chapterCount,
                lastError: lastError,
                splitLongChapter: splitLongChapter,
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
                Value<String?> charset = const Value.absent(),
                required int fileSize,
                Value<String?> author = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<int?> sourceFileSize = const Value.absent(),
                Value<int?> sourceFileLastModifiedMs = const Value.absent(),
                Value<int?> storageFileLastModifiedMs = const Value.absent(),
                Value<String> indexStatus = const Value.absent(),
                Value<int> chapterCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<bool> splitLongChapter = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredLocalBooksCompanion.insert(
                id: id,
                title: title,
                format: format,
                storagePath: storagePath,
                sourcePath: sourcePath,
                charset: charset,
                fileSize: fileSize,
                author: author,
                description: description,
                coverPath: coverPath,
                sourceFileSize: sourceFileSize,
                sourceFileLastModifiedMs: sourceFileLastModifiedMs,
                storageFileLastModifiedMs: storageFileLastModifiedMs,
                indexStatus: indexStatus,
                chapterCount: chapterCount,
                lastError: lastError,
                splitLongChapter: splitLongChapter,
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
      Value<String> imageUrlsJson,
      Value<String?> documentJson,
      Value<String?> sourceRef,
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
      Value<String> imageUrlsJson,
      Value<String?> documentJson,
      Value<String?> sourceRef,
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

  ColumnFilters<String> get imageUrlsJson => $composableBuilder(
    column: $table.imageUrlsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentJson => $composableBuilder(
    column: $table.documentJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceRef => $composableBuilder(
    column: $table.sourceRef,
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

  ColumnOrderings<String> get imageUrlsJson => $composableBuilder(
    column: $table.imageUrlsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentJson => $composableBuilder(
    column: $table.documentJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceRef => $composableBuilder(
    column: $table.sourceRef,
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

  GeneratedColumn<String> get imageUrlsJson => $composableBuilder(
    column: $table.imageUrlsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get documentJson => $composableBuilder(
    column: $table.documentJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceRef =>
      $composableBuilder(column: $table.sourceRef, builder: (column) => column);

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
                Value<String> imageUrlsJson = const Value.absent(),
                Value<String?> documentJson = const Value.absent(),
                Value<String?> sourceRef = const Value.absent(),
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
                imageUrlsJson: imageUrlsJson,
                documentJson: documentJson,
                sourceRef: sourceRef,
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
                Value<String> imageUrlsJson = const Value.absent(),
                Value<String?> documentJson = const Value.absent(),
                Value<String?> sourceRef = const Value.absent(),
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
                imageUrlsJson: imageUrlsJson,
                documentJson: documentJson,
                sourceRef: sourceRef,
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
typedef $$StoredBookmarksTableCreateCompanionBuilder =
    StoredBookmarksCompanion Function({
      required String id,
      required String bookId,
      required String chapterId,
      required int chapterIndex,
      required int startOffset,
      required int endOffset,
      required String snippet,
      Value<String?> note,
      Value<bool> isBold,
      Value<bool> isUnderline,
      Value<bool> isWavy,
      Value<String?> color,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$StoredBookmarksTableUpdateCompanionBuilder =
    StoredBookmarksCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> chapterId,
      Value<int> chapterIndex,
      Value<int> startOffset,
      Value<int> endOffset,
      Value<String> snippet,
      Value<String?> note,
      Value<bool> isBold,
      Value<bool> isUnderline,
      Value<bool> isWavy,
      Value<String?> color,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$StoredBookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $StoredBookmarksTable> {
  $$StoredBookmarksTableFilterComposer({
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

  ColumnFilters<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
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

  ColumnFilters<String> get snippet => $composableBuilder(
    column: $table.snippet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBold => $composableBuilder(
    column: $table.isBold,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isUnderline => $composableBuilder(
    column: $table.isUnderline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isWavy => $composableBuilder(
    column: $table.isWavy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
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

class $$StoredBookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredBookmarksTable> {
  $$StoredBookmarksTableOrderingComposer({
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

  ColumnOrderings<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
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

  ColumnOrderings<String> get snippet => $composableBuilder(
    column: $table.snippet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBold => $composableBuilder(
    column: $table.isBold,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isUnderline => $composableBuilder(
    column: $table.isUnderline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isWavy => $composableBuilder(
    column: $table.isWavy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
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

class $$StoredBookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredBookmarksTable> {
  $$StoredBookmarksTableAnnotationComposer({
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

  GeneratedColumn<String> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endOffset =>
      $composableBuilder(column: $table.endOffset, builder: (column) => column);

  GeneratedColumn<String> get snippet =>
      $composableBuilder(column: $table.snippet, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<bool> get isBold =>
      $composableBuilder(column: $table.isBold, builder: (column) => column);

  GeneratedColumn<bool> get isUnderline => $composableBuilder(
    column: $table.isUnderline,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isWavy =>
      $composableBuilder(column: $table.isWavy, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StoredBookmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredBookmarksTable,
          StoredBookmark,
          $$StoredBookmarksTableFilterComposer,
          $$StoredBookmarksTableOrderingComposer,
          $$StoredBookmarksTableAnnotationComposer,
          $$StoredBookmarksTableCreateCompanionBuilder,
          $$StoredBookmarksTableUpdateCompanionBuilder,
          (
            StoredBookmark,
            BaseReferences<
              _$AppDatabase,
              $StoredBookmarksTable,
              StoredBookmark
            >,
          ),
          StoredBookmark,
          PrefetchHooks Function()
        > {
  $$StoredBookmarksTableTableManager(
    _$AppDatabase db,
    $StoredBookmarksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$StoredBookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$StoredBookmarksTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$StoredBookmarksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> chapterId = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<int> startOffset = const Value.absent(),
                Value<int> endOffset = const Value.absent(),
                Value<String> snippet = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> isBold = const Value.absent(),
                Value<bool> isUnderline = const Value.absent(),
                Value<bool> isWavy = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredBookmarksCompanion(
                id: id,
                bookId: bookId,
                chapterId: chapterId,
                chapterIndex: chapterIndex,
                startOffset: startOffset,
                endOffset: endOffset,
                snippet: snippet,
                note: note,
                isBold: isBold,
                isUnderline: isUnderline,
                isWavy: isWavy,
                color: color,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String chapterId,
                required int chapterIndex,
                required int startOffset,
                required int endOffset,
                required String snippet,
                Value<String?> note = const Value.absent(),
                Value<bool> isBold = const Value.absent(),
                Value<bool> isUnderline = const Value.absent(),
                Value<bool> isWavy = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredBookmarksCompanion.insert(
                id: id,
                bookId: bookId,
                chapterId: chapterId,
                chapterIndex: chapterIndex,
                startOffset: startOffset,
                endOffset: endOffset,
                snippet: snippet,
                note: note,
                isBold: isBold,
                isUnderline: isUnderline,
                isWavy: isWavy,
                color: color,
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

typedef $$StoredBookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredBookmarksTable,
      StoredBookmark,
      $$StoredBookmarksTableFilterComposer,
      $$StoredBookmarksTableOrderingComposer,
      $$StoredBookmarksTableAnnotationComposer,
      $$StoredBookmarksTableCreateCompanionBuilder,
      $$StoredBookmarksTableUpdateCompanionBuilder,
      (
        StoredBookmark,
        BaseReferences<_$AppDatabase, $StoredBookmarksTable, StoredBookmark>,
      ),
      StoredBookmark,
      PrefetchHooks Function()
    >;
typedef $$StoredBookMetadataOverridesTableCreateCompanionBuilder =
    StoredBookMetadataOverridesCompanion Function({
      required String targetKey,
      Value<String?> bookId,
      Value<String?> sourceId,
      Value<String?> detailUrl,
      Value<String?> title,
      Value<String?> author,
      Value<String?> intro,
      Value<String?> coverPath,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$StoredBookMetadataOverridesTableUpdateCompanionBuilder =
    StoredBookMetadataOverridesCompanion Function({
      Value<String> targetKey,
      Value<String?> bookId,
      Value<String?> sourceId,
      Value<String?> detailUrl,
      Value<String?> title,
      Value<String?> author,
      Value<String?> intro,
      Value<String?> coverPath,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$StoredBookMetadataOverridesTableFilterComposer
    extends Composer<_$AppDatabase, $StoredBookMetadataOverridesTable> {
  $$StoredBookMetadataOverridesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get targetKey => $composableBuilder(
    column: $table.targetKey,
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

  ColumnFilters<String> get detailUrl => $composableBuilder(
    column: $table.detailUrl,
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

  ColumnFilters<String> get intro => $composableBuilder(
    column: $table.intro,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
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

class $$StoredBookMetadataOverridesTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredBookMetadataOverridesTable> {
  $$StoredBookMetadataOverridesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get targetKey => $composableBuilder(
    column: $table.targetKey,
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

  ColumnOrderings<String> get detailUrl => $composableBuilder(
    column: $table.detailUrl,
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

  ColumnOrderings<String> get intro => $composableBuilder(
    column: $table.intro,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
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

class $$StoredBookMetadataOverridesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredBookMetadataOverridesTable> {
  $$StoredBookMetadataOverridesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get targetKey =>
      $composableBuilder(column: $table.targetKey, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get detailUrl =>
      $composableBuilder(column: $table.detailUrl, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get intro =>
      $composableBuilder(column: $table.intro, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StoredBookMetadataOverridesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredBookMetadataOverridesTable,
          StoredBookMetadataOverride,
          $$StoredBookMetadataOverridesTableFilterComposer,
          $$StoredBookMetadataOverridesTableOrderingComposer,
          $$StoredBookMetadataOverridesTableAnnotationComposer,
          $$StoredBookMetadataOverridesTableCreateCompanionBuilder,
          $$StoredBookMetadataOverridesTableUpdateCompanionBuilder,
          (
            StoredBookMetadataOverride,
            BaseReferences<
              _$AppDatabase,
              $StoredBookMetadataOverridesTable,
              StoredBookMetadataOverride
            >,
          ),
          StoredBookMetadataOverride,
          PrefetchHooks Function()
        > {
  $$StoredBookMetadataOverridesTableTableManager(
    _$AppDatabase db,
    $StoredBookMetadataOverridesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$StoredBookMetadataOverridesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$StoredBookMetadataOverridesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$StoredBookMetadataOverridesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> targetKey = const Value.absent(),
                Value<String?> bookId = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<String?> detailUrl = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> intro = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredBookMetadataOverridesCompanion(
                targetKey: targetKey,
                bookId: bookId,
                sourceId: sourceId,
                detailUrl: detailUrl,
                title: title,
                author: author,
                intro: intro,
                coverPath: coverPath,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String targetKey,
                Value<String?> bookId = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<String?> detailUrl = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> intro = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredBookMetadataOverridesCompanion.insert(
                targetKey: targetKey,
                bookId: bookId,
                sourceId: sourceId,
                detailUrl: detailUrl,
                title: title,
                author: author,
                intro: intro,
                coverPath: coverPath,
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

typedef $$StoredBookMetadataOverridesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredBookMetadataOverridesTable,
      StoredBookMetadataOverride,
      $$StoredBookMetadataOverridesTableFilterComposer,
      $$StoredBookMetadataOverridesTableOrderingComposer,
      $$StoredBookMetadataOverridesTableAnnotationComposer,
      $$StoredBookMetadataOverridesTableCreateCompanionBuilder,
      $$StoredBookMetadataOverridesTableUpdateCompanionBuilder,
      (
        StoredBookMetadataOverride,
        BaseReferences<
          _$AppDatabase,
          $StoredBookMetadataOverridesTable,
          StoredBookMetadataOverride
        >,
      ),
      StoredBookMetadataOverride,
      PrefetchHooks Function()
    >;
typedef $$StoredReadingRecordsTableCreateCompanionBuilder =
    StoredReadingRecordsCompanion Function({
      required String bookId,
      required String sourceId,
      required String detailUrl,
      required String bookTitle,
      Value<String?> bookAuthor,
      Value<String?> coverUrl,
      Value<String?> lastChapterId,
      Value<String?> lastChapterTitle,
      Value<int?> lastChapterIndex,
      Value<String?> lastChapterUrl,
      Value<double> lastPositionRatio,
      Value<int> totalReadMillis,
      Value<int> totalReadChars,
      required DateTime lastReadAt,
      Value<int> rowid,
    });
typedef $$StoredReadingRecordsTableUpdateCompanionBuilder =
    StoredReadingRecordsCompanion Function({
      Value<String> bookId,
      Value<String> sourceId,
      Value<String> detailUrl,
      Value<String> bookTitle,
      Value<String?> bookAuthor,
      Value<String?> coverUrl,
      Value<String?> lastChapterId,
      Value<String?> lastChapterTitle,
      Value<int?> lastChapterIndex,
      Value<String?> lastChapterUrl,
      Value<double> lastPositionRatio,
      Value<int> totalReadMillis,
      Value<int> totalReadChars,
      Value<DateTime> lastReadAt,
      Value<int> rowid,
    });

class $$StoredReadingRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $StoredReadingRecordsTable> {
  $$StoredReadingRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detailUrl => $composableBuilder(
    column: $table.detailUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookTitle => $composableBuilder(
    column: $table.bookTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookAuthor => $composableBuilder(
    column: $table.bookAuthor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastChapterId => $composableBuilder(
    column: $table.lastChapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastChapterTitle => $composableBuilder(
    column: $table.lastChapterTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastChapterIndex => $composableBuilder(
    column: $table.lastChapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastChapterUrl => $composableBuilder(
    column: $table.lastChapterUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lastPositionRatio => $composableBuilder(
    column: $table.lastPositionRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalReadMillis => $composableBuilder(
    column: $table.totalReadMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalReadChars => $composableBuilder(
    column: $table.totalReadChars,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredReadingRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredReadingRecordsTable> {
  $$StoredReadingRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detailUrl => $composableBuilder(
    column: $table.detailUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookTitle => $composableBuilder(
    column: $table.bookTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookAuthor => $composableBuilder(
    column: $table.bookAuthor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastChapterId => $composableBuilder(
    column: $table.lastChapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastChapterTitle => $composableBuilder(
    column: $table.lastChapterTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastChapterIndex => $composableBuilder(
    column: $table.lastChapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastChapterUrl => $composableBuilder(
    column: $table.lastChapterUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lastPositionRatio => $composableBuilder(
    column: $table.lastPositionRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalReadMillis => $composableBuilder(
    column: $table.totalReadMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalReadChars => $composableBuilder(
    column: $table.totalReadChars,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredReadingRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredReadingRecordsTable> {
  $$StoredReadingRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get detailUrl =>
      $composableBuilder(column: $table.detailUrl, builder: (column) => column);

  GeneratedColumn<String> get bookTitle =>
      $composableBuilder(column: $table.bookTitle, builder: (column) => column);

  GeneratedColumn<String> get bookAuthor => $composableBuilder(
    column: $table.bookAuthor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get lastChapterId => $composableBuilder(
    column: $table.lastChapterId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastChapterTitle => $composableBuilder(
    column: $table.lastChapterTitle,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastChapterIndex => $composableBuilder(
    column: $table.lastChapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastChapterUrl => $composableBuilder(
    column: $table.lastChapterUrl,
    builder: (column) => column,
  );

  GeneratedColumn<double> get lastPositionRatio => $composableBuilder(
    column: $table.lastPositionRatio,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalReadMillis => $composableBuilder(
    column: $table.totalReadMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalReadChars => $composableBuilder(
    column: $table.totalReadChars,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => column,
  );
}

class $$StoredReadingRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredReadingRecordsTable,
          StoredReadingRecord,
          $$StoredReadingRecordsTableFilterComposer,
          $$StoredReadingRecordsTableOrderingComposer,
          $$StoredReadingRecordsTableAnnotationComposer,
          $$StoredReadingRecordsTableCreateCompanionBuilder,
          $$StoredReadingRecordsTableUpdateCompanionBuilder,
          (
            StoredReadingRecord,
            BaseReferences<
              _$AppDatabase,
              $StoredReadingRecordsTable,
              StoredReadingRecord
            >,
          ),
          StoredReadingRecord,
          PrefetchHooks Function()
        > {
  $$StoredReadingRecordsTableTableManager(
    _$AppDatabase db,
    $StoredReadingRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$StoredReadingRecordsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$StoredReadingRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$StoredReadingRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> detailUrl = const Value.absent(),
                Value<String> bookTitle = const Value.absent(),
                Value<String?> bookAuthor = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> lastChapterId = const Value.absent(),
                Value<String?> lastChapterTitle = const Value.absent(),
                Value<int?> lastChapterIndex = const Value.absent(),
                Value<String?> lastChapterUrl = const Value.absent(),
                Value<double> lastPositionRatio = const Value.absent(),
                Value<int> totalReadMillis = const Value.absent(),
                Value<int> totalReadChars = const Value.absent(),
                Value<DateTime> lastReadAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredReadingRecordsCompanion(
                bookId: bookId,
                sourceId: sourceId,
                detailUrl: detailUrl,
                bookTitle: bookTitle,
                bookAuthor: bookAuthor,
                coverUrl: coverUrl,
                lastChapterId: lastChapterId,
                lastChapterTitle: lastChapterTitle,
                lastChapterIndex: lastChapterIndex,
                lastChapterUrl: lastChapterUrl,
                lastPositionRatio: lastPositionRatio,
                totalReadMillis: totalReadMillis,
                totalReadChars: totalReadChars,
                lastReadAt: lastReadAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required String sourceId,
                required String detailUrl,
                required String bookTitle,
                Value<String?> bookAuthor = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> lastChapterId = const Value.absent(),
                Value<String?> lastChapterTitle = const Value.absent(),
                Value<int?> lastChapterIndex = const Value.absent(),
                Value<String?> lastChapterUrl = const Value.absent(),
                Value<double> lastPositionRatio = const Value.absent(),
                Value<int> totalReadMillis = const Value.absent(),
                Value<int> totalReadChars = const Value.absent(),
                required DateTime lastReadAt,
                Value<int> rowid = const Value.absent(),
              }) => StoredReadingRecordsCompanion.insert(
                bookId: bookId,
                sourceId: sourceId,
                detailUrl: detailUrl,
                bookTitle: bookTitle,
                bookAuthor: bookAuthor,
                coverUrl: coverUrl,
                lastChapterId: lastChapterId,
                lastChapterTitle: lastChapterTitle,
                lastChapterIndex: lastChapterIndex,
                lastChapterUrl: lastChapterUrl,
                lastPositionRatio: lastPositionRatio,
                totalReadMillis: totalReadMillis,
                totalReadChars: totalReadChars,
                lastReadAt: lastReadAt,
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

typedef $$StoredReadingRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredReadingRecordsTable,
      StoredReadingRecord,
      $$StoredReadingRecordsTableFilterComposer,
      $$StoredReadingRecordsTableOrderingComposer,
      $$StoredReadingRecordsTableAnnotationComposer,
      $$StoredReadingRecordsTableCreateCompanionBuilder,
      $$StoredReadingRecordsTableUpdateCompanionBuilder,
      (
        StoredReadingRecord,
        BaseReferences<
          _$AppDatabase,
          $StoredReadingRecordsTable,
          StoredReadingRecord
        >,
      ),
      StoredReadingRecord,
      PrefetchHooks Function()
    >;
typedef $$StoredReadingRecordDaysTableCreateCompanionBuilder =
    StoredReadingRecordDaysCompanion Function({
      required String bookId,
      required String dateKey,
      required String bookTitle,
      Value<String?> bookAuthor,
      Value<String?> coverUrl,
      Value<int> readMillis,
      Value<int> readChars,
      required DateTime firstReadAt,
      required DateTime lastReadAt,
      Value<int> rowid,
    });
typedef $$StoredReadingRecordDaysTableUpdateCompanionBuilder =
    StoredReadingRecordDaysCompanion Function({
      Value<String> bookId,
      Value<String> dateKey,
      Value<String> bookTitle,
      Value<String?> bookAuthor,
      Value<String?> coverUrl,
      Value<int> readMillis,
      Value<int> readChars,
      Value<DateTime> firstReadAt,
      Value<DateTime> lastReadAt,
      Value<int> rowid,
    });

class $$StoredReadingRecordDaysTableFilterComposer
    extends Composer<_$AppDatabase, $StoredReadingRecordDaysTable> {
  $$StoredReadingRecordDaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookTitle => $composableBuilder(
    column: $table.bookTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookAuthor => $composableBuilder(
    column: $table.bookAuthor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get readMillis => $composableBuilder(
    column: $table.readMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get readChars => $composableBuilder(
    column: $table.readChars,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstReadAt => $composableBuilder(
    column: $table.firstReadAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredReadingRecordDaysTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredReadingRecordDaysTable> {
  $$StoredReadingRecordDaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookTitle => $composableBuilder(
    column: $table.bookTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookAuthor => $composableBuilder(
    column: $table.bookAuthor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get readMillis => $composableBuilder(
    column: $table.readMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get readChars => $composableBuilder(
    column: $table.readChars,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstReadAt => $composableBuilder(
    column: $table.firstReadAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredReadingRecordDaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredReadingRecordDaysTable> {
  $$StoredReadingRecordDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get dateKey =>
      $composableBuilder(column: $table.dateKey, builder: (column) => column);

  GeneratedColumn<String> get bookTitle =>
      $composableBuilder(column: $table.bookTitle, builder: (column) => column);

  GeneratedColumn<String> get bookAuthor => $composableBuilder(
    column: $table.bookAuthor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<int> get readMillis => $composableBuilder(
    column: $table.readMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get readChars =>
      $composableBuilder(column: $table.readChars, builder: (column) => column);

  GeneratedColumn<DateTime> get firstReadAt => $composableBuilder(
    column: $table.firstReadAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastReadAt => $composableBuilder(
    column: $table.lastReadAt,
    builder: (column) => column,
  );
}

class $$StoredReadingRecordDaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredReadingRecordDaysTable,
          StoredReadingRecordDay,
          $$StoredReadingRecordDaysTableFilterComposer,
          $$StoredReadingRecordDaysTableOrderingComposer,
          $$StoredReadingRecordDaysTableAnnotationComposer,
          $$StoredReadingRecordDaysTableCreateCompanionBuilder,
          $$StoredReadingRecordDaysTableUpdateCompanionBuilder,
          (
            StoredReadingRecordDay,
            BaseReferences<
              _$AppDatabase,
              $StoredReadingRecordDaysTable,
              StoredReadingRecordDay
            >,
          ),
          StoredReadingRecordDay,
          PrefetchHooks Function()
        > {
  $$StoredReadingRecordDaysTableTableManager(
    _$AppDatabase db,
    $StoredReadingRecordDaysTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$StoredReadingRecordDaysTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$StoredReadingRecordDaysTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$StoredReadingRecordDaysTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String> dateKey = const Value.absent(),
                Value<String> bookTitle = const Value.absent(),
                Value<String?> bookAuthor = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<int> readMillis = const Value.absent(),
                Value<int> readChars = const Value.absent(),
                Value<DateTime> firstReadAt = const Value.absent(),
                Value<DateTime> lastReadAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredReadingRecordDaysCompanion(
                bookId: bookId,
                dateKey: dateKey,
                bookTitle: bookTitle,
                bookAuthor: bookAuthor,
                coverUrl: coverUrl,
                readMillis: readMillis,
                readChars: readChars,
                firstReadAt: firstReadAt,
                lastReadAt: lastReadAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required String dateKey,
                required String bookTitle,
                Value<String?> bookAuthor = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<int> readMillis = const Value.absent(),
                Value<int> readChars = const Value.absent(),
                required DateTime firstReadAt,
                required DateTime lastReadAt,
                Value<int> rowid = const Value.absent(),
              }) => StoredReadingRecordDaysCompanion.insert(
                bookId: bookId,
                dateKey: dateKey,
                bookTitle: bookTitle,
                bookAuthor: bookAuthor,
                coverUrl: coverUrl,
                readMillis: readMillis,
                readChars: readChars,
                firstReadAt: firstReadAt,
                lastReadAt: lastReadAt,
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

typedef $$StoredReadingRecordDaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredReadingRecordDaysTable,
      StoredReadingRecordDay,
      $$StoredReadingRecordDaysTableFilterComposer,
      $$StoredReadingRecordDaysTableOrderingComposer,
      $$StoredReadingRecordDaysTableAnnotationComposer,
      $$StoredReadingRecordDaysTableCreateCompanionBuilder,
      $$StoredReadingRecordDaysTableUpdateCompanionBuilder,
      (
        StoredReadingRecordDay,
        BaseReferences<
          _$AppDatabase,
          $StoredReadingRecordDaysTable,
          StoredReadingRecordDay
        >,
      ),
      StoredReadingRecordDay,
      PrefetchHooks Function()
    >;
typedef $$StoredReadingRecordSessionsTableCreateCompanionBuilder =
    StoredReadingRecordSessionsCompanion Function({
      Value<int> id,
      required String bookId,
      required String sourceId,
      required String detailUrl,
      required String bookTitle,
      Value<String?> bookAuthor,
      Value<String?> coverUrl,
      Value<String?> chapterId,
      Value<String?> chapterTitle,
      Value<int?> chapterIndex,
      Value<String?> chapterUrl,
      required DateTime startAt,
      required DateTime endAt,
      Value<int> durationMillis,
      Value<int> readChars,
      Value<double> startPositionRatio,
      Value<double> endPositionRatio,
    });
typedef $$StoredReadingRecordSessionsTableUpdateCompanionBuilder =
    StoredReadingRecordSessionsCompanion Function({
      Value<int> id,
      Value<String> bookId,
      Value<String> sourceId,
      Value<String> detailUrl,
      Value<String> bookTitle,
      Value<String?> bookAuthor,
      Value<String?> coverUrl,
      Value<String?> chapterId,
      Value<String?> chapterTitle,
      Value<int?> chapterIndex,
      Value<String?> chapterUrl,
      Value<DateTime> startAt,
      Value<DateTime> endAt,
      Value<int> durationMillis,
      Value<int> readChars,
      Value<double> startPositionRatio,
      Value<double> endPositionRatio,
    });

class $$StoredReadingRecordSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $StoredReadingRecordSessionsTable> {
  $$StoredReadingRecordSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
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

  ColumnFilters<String> get detailUrl => $composableBuilder(
    column: $table.detailUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookTitle => $composableBuilder(
    column: $table.bookTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookAuthor => $composableBuilder(
    column: $table.bookAuthor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterTitle => $composableBuilder(
    column: $table.chapterTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterUrl => $composableBuilder(
    column: $table.chapterUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMillis => $composableBuilder(
    column: $table.durationMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get readChars => $composableBuilder(
    column: $table.readChars,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get startPositionRatio => $composableBuilder(
    column: $table.startPositionRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get endPositionRatio => $composableBuilder(
    column: $table.endPositionRatio,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredReadingRecordSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredReadingRecordSessionsTable> {
  $$StoredReadingRecordSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
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

  ColumnOrderings<String> get detailUrl => $composableBuilder(
    column: $table.detailUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookTitle => $composableBuilder(
    column: $table.bookTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookAuthor => $composableBuilder(
    column: $table.bookAuthor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterTitle => $composableBuilder(
    column: $table.chapterTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterUrl => $composableBuilder(
    column: $table.chapterUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startAt => $composableBuilder(
    column: $table.startAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endAt => $composableBuilder(
    column: $table.endAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMillis => $composableBuilder(
    column: $table.durationMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get readChars => $composableBuilder(
    column: $table.readChars,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get startPositionRatio => $composableBuilder(
    column: $table.startPositionRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get endPositionRatio => $composableBuilder(
    column: $table.endPositionRatio,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredReadingRecordSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredReadingRecordSessionsTable> {
  $$StoredReadingRecordSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get detailUrl =>
      $composableBuilder(column: $table.detailUrl, builder: (column) => column);

  GeneratedColumn<String> get bookTitle =>
      $composableBuilder(column: $table.bookTitle, builder: (column) => column);

  GeneratedColumn<String> get bookAuthor => $composableBuilder(
    column: $table.bookAuthor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<String> get chapterTitle => $composableBuilder(
    column: $table.chapterTitle,
    builder: (column) => column,
  );

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chapterUrl => $composableBuilder(
    column: $table.chapterUrl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endAt =>
      $composableBuilder(column: $table.endAt, builder: (column) => column);

  GeneratedColumn<int> get durationMillis => $composableBuilder(
    column: $table.durationMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get readChars =>
      $composableBuilder(column: $table.readChars, builder: (column) => column);

  GeneratedColumn<double> get startPositionRatio => $composableBuilder(
    column: $table.startPositionRatio,
    builder: (column) => column,
  );

  GeneratedColumn<double> get endPositionRatio => $composableBuilder(
    column: $table.endPositionRatio,
    builder: (column) => column,
  );
}

class $$StoredReadingRecordSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredReadingRecordSessionsTable,
          StoredReadingRecordSession,
          $$StoredReadingRecordSessionsTableFilterComposer,
          $$StoredReadingRecordSessionsTableOrderingComposer,
          $$StoredReadingRecordSessionsTableAnnotationComposer,
          $$StoredReadingRecordSessionsTableCreateCompanionBuilder,
          $$StoredReadingRecordSessionsTableUpdateCompanionBuilder,
          (
            StoredReadingRecordSession,
            BaseReferences<
              _$AppDatabase,
              $StoredReadingRecordSessionsTable,
              StoredReadingRecordSession
            >,
          ),
          StoredReadingRecordSession,
          PrefetchHooks Function()
        > {
  $$StoredReadingRecordSessionsTableTableManager(
    _$AppDatabase db,
    $StoredReadingRecordSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$StoredReadingRecordSessionsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$StoredReadingRecordSessionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$StoredReadingRecordSessionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> detailUrl = const Value.absent(),
                Value<String> bookTitle = const Value.absent(),
                Value<String?> bookAuthor = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> chapterId = const Value.absent(),
                Value<String?> chapterTitle = const Value.absent(),
                Value<int?> chapterIndex = const Value.absent(),
                Value<String?> chapterUrl = const Value.absent(),
                Value<DateTime> startAt = const Value.absent(),
                Value<DateTime> endAt = const Value.absent(),
                Value<int> durationMillis = const Value.absent(),
                Value<int> readChars = const Value.absent(),
                Value<double> startPositionRatio = const Value.absent(),
                Value<double> endPositionRatio = const Value.absent(),
              }) => StoredReadingRecordSessionsCompanion(
                id: id,
                bookId: bookId,
                sourceId: sourceId,
                detailUrl: detailUrl,
                bookTitle: bookTitle,
                bookAuthor: bookAuthor,
                coverUrl: coverUrl,
                chapterId: chapterId,
                chapterTitle: chapterTitle,
                chapterIndex: chapterIndex,
                chapterUrl: chapterUrl,
                startAt: startAt,
                endAt: endAt,
                durationMillis: durationMillis,
                readChars: readChars,
                startPositionRatio: startPositionRatio,
                endPositionRatio: endPositionRatio,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String bookId,
                required String sourceId,
                required String detailUrl,
                required String bookTitle,
                Value<String?> bookAuthor = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> chapterId = const Value.absent(),
                Value<String?> chapterTitle = const Value.absent(),
                Value<int?> chapterIndex = const Value.absent(),
                Value<String?> chapterUrl = const Value.absent(),
                required DateTime startAt,
                required DateTime endAt,
                Value<int> durationMillis = const Value.absent(),
                Value<int> readChars = const Value.absent(),
                Value<double> startPositionRatio = const Value.absent(),
                Value<double> endPositionRatio = const Value.absent(),
              }) => StoredReadingRecordSessionsCompanion.insert(
                id: id,
                bookId: bookId,
                sourceId: sourceId,
                detailUrl: detailUrl,
                bookTitle: bookTitle,
                bookAuthor: bookAuthor,
                coverUrl: coverUrl,
                chapterId: chapterId,
                chapterTitle: chapterTitle,
                chapterIndex: chapterIndex,
                chapterUrl: chapterUrl,
                startAt: startAt,
                endAt: endAt,
                durationMillis: durationMillis,
                readChars: readChars,
                startPositionRatio: startPositionRatio,
                endPositionRatio: endPositionRatio,
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

typedef $$StoredReadingRecordSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredReadingRecordSessionsTable,
      StoredReadingRecordSession,
      $$StoredReadingRecordSessionsTableFilterComposer,
      $$StoredReadingRecordSessionsTableOrderingComposer,
      $$StoredReadingRecordSessionsTableAnnotationComposer,
      $$StoredReadingRecordSessionsTableCreateCompanionBuilder,
      $$StoredReadingRecordSessionsTableUpdateCompanionBuilder,
      (
        StoredReadingRecordSession,
        BaseReferences<
          _$AppDatabase,
          $StoredReadingRecordSessionsTable,
          StoredReadingRecordSession
        >,
      ),
      StoredReadingRecordSession,
      PrefetchHooks Function()
    >;
typedef $$StoredReadingBookStatusesTableCreateCompanionBuilder =
    StoredReadingBookStatusesCompanion Function({
      required String bookId,
      required String sourceId,
      required String detailUrl,
      required String bookTitle,
      required String statusOverride,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$StoredReadingBookStatusesTableUpdateCompanionBuilder =
    StoredReadingBookStatusesCompanion Function({
      Value<String> bookId,
      Value<String> sourceId,
      Value<String> detailUrl,
      Value<String> bookTitle,
      Value<String> statusOverride,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$StoredReadingBookStatusesTableFilterComposer
    extends Composer<_$AppDatabase, $StoredReadingBookStatusesTable> {
  $$StoredReadingBookStatusesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detailUrl => $composableBuilder(
    column: $table.detailUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookTitle => $composableBuilder(
    column: $table.bookTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statusOverride => $composableBuilder(
    column: $table.statusOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredReadingBookStatusesTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredReadingBookStatusesTable> {
  $$StoredReadingBookStatusesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detailUrl => $composableBuilder(
    column: $table.detailUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookTitle => $composableBuilder(
    column: $table.bookTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statusOverride => $composableBuilder(
    column: $table.statusOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredReadingBookStatusesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredReadingBookStatusesTable> {
  $$StoredReadingBookStatusesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get detailUrl =>
      $composableBuilder(column: $table.detailUrl, builder: (column) => column);

  GeneratedColumn<String> get bookTitle =>
      $composableBuilder(column: $table.bookTitle, builder: (column) => column);

  GeneratedColumn<String> get statusOverride => $composableBuilder(
    column: $table.statusOverride,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StoredReadingBookStatusesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredReadingBookStatusesTable,
          StoredReadingBookStatuse,
          $$StoredReadingBookStatusesTableFilterComposer,
          $$StoredReadingBookStatusesTableOrderingComposer,
          $$StoredReadingBookStatusesTableAnnotationComposer,
          $$StoredReadingBookStatusesTableCreateCompanionBuilder,
          $$StoredReadingBookStatusesTableUpdateCompanionBuilder,
          (
            StoredReadingBookStatuse,
            BaseReferences<
              _$AppDatabase,
              $StoredReadingBookStatusesTable,
              StoredReadingBookStatuse
            >,
          ),
          StoredReadingBookStatuse,
          PrefetchHooks Function()
        > {
  $$StoredReadingBookStatusesTableTableManager(
    _$AppDatabase db,
    $StoredReadingBookStatusesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$StoredReadingBookStatusesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$StoredReadingBookStatusesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$StoredReadingBookStatusesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> detailUrl = const Value.absent(),
                Value<String> bookTitle = const Value.absent(),
                Value<String> statusOverride = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredReadingBookStatusesCompanion(
                bookId: bookId,
                sourceId: sourceId,
                detailUrl: detailUrl,
                bookTitle: bookTitle,
                statusOverride: statusOverride,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required String sourceId,
                required String detailUrl,
                required String bookTitle,
                required String statusOverride,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => StoredReadingBookStatusesCompanion.insert(
                bookId: bookId,
                sourceId: sourceId,
                detailUrl: detailUrl,
                bookTitle: bookTitle,
                statusOverride: statusOverride,
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

typedef $$StoredReadingBookStatusesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredReadingBookStatusesTable,
      StoredReadingBookStatuse,
      $$StoredReadingBookStatusesTableFilterComposer,
      $$StoredReadingBookStatusesTableOrderingComposer,
      $$StoredReadingBookStatusesTableAnnotationComposer,
      $$StoredReadingBookStatusesTableCreateCompanionBuilder,
      $$StoredReadingBookStatusesTableUpdateCompanionBuilder,
      (
        StoredReadingBookStatuse,
        BaseReferences<
          _$AppDatabase,
          $StoredReadingBookStatusesTable,
          StoredReadingBookStatuse
        >,
      ),
      StoredReadingBookStatuse,
      PrefetchHooks Function()
    >;
typedef $$StoredReadingProgressesTableCreateCompanionBuilder =
    StoredReadingProgressesCompanion Function({
      required String bookId,
      required String sourceId,
      required String detailUrl,
      required String chapterId,
      required String chapterUrl,
      required String chapterTitle,
      required int chapterIndex,
      Value<double> chapterPositionRatio,
      Value<String?> logicalPositionJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$StoredReadingProgressesTableUpdateCompanionBuilder =
    StoredReadingProgressesCompanion Function({
      Value<String> bookId,
      Value<String> sourceId,
      Value<String> detailUrl,
      Value<String> chapterId,
      Value<String> chapterUrl,
      Value<String> chapterTitle,
      Value<int> chapterIndex,
      Value<double> chapterPositionRatio,
      Value<String?> logicalPositionJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$StoredReadingProgressesTableFilterComposer
    extends Composer<_$AppDatabase, $StoredReadingProgressesTable> {
  $$StoredReadingProgressesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detailUrl => $composableBuilder(
    column: $table.detailUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterUrl => $composableBuilder(
    column: $table.chapterUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterTitle => $composableBuilder(
    column: $table.chapterTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get chapterPositionRatio => $composableBuilder(
    column: $table.chapterPositionRatio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logicalPositionJson => $composableBuilder(
    column: $table.logicalPositionJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredReadingProgressesTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredReadingProgressesTable> {
  $$StoredReadingProgressesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detailUrl => $composableBuilder(
    column: $table.detailUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterId => $composableBuilder(
    column: $table.chapterId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterUrl => $composableBuilder(
    column: $table.chapterUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterTitle => $composableBuilder(
    column: $table.chapterTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get chapterPositionRatio => $composableBuilder(
    column: $table.chapterPositionRatio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logicalPositionJson => $composableBuilder(
    column: $table.logicalPositionJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredReadingProgressesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredReadingProgressesTable> {
  $$StoredReadingProgressesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get detailUrl =>
      $composableBuilder(column: $table.detailUrl, builder: (column) => column);

  GeneratedColumn<String> get chapterId =>
      $composableBuilder(column: $table.chapterId, builder: (column) => column);

  GeneratedColumn<String> get chapterUrl => $composableBuilder(
    column: $table.chapterUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chapterTitle => $composableBuilder(
    column: $table.chapterTitle,
    builder: (column) => column,
  );

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<double> get chapterPositionRatio => $composableBuilder(
    column: $table.chapterPositionRatio,
    builder: (column) => column,
  );

  GeneratedColumn<String> get logicalPositionJson => $composableBuilder(
    column: $table.logicalPositionJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StoredReadingProgressesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredReadingProgressesTable,
          StoredReadingProgressesData,
          $$StoredReadingProgressesTableFilterComposer,
          $$StoredReadingProgressesTableOrderingComposer,
          $$StoredReadingProgressesTableAnnotationComposer,
          $$StoredReadingProgressesTableCreateCompanionBuilder,
          $$StoredReadingProgressesTableUpdateCompanionBuilder,
          (
            StoredReadingProgressesData,
            BaseReferences<
              _$AppDatabase,
              $StoredReadingProgressesTable,
              StoredReadingProgressesData
            >,
          ),
          StoredReadingProgressesData,
          PrefetchHooks Function()
        > {
  $$StoredReadingProgressesTableTableManager(
    _$AppDatabase db,
    $StoredReadingProgressesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$StoredReadingProgressesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$StoredReadingProgressesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$StoredReadingProgressesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> bookId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> detailUrl = const Value.absent(),
                Value<String> chapterId = const Value.absent(),
                Value<String> chapterUrl = const Value.absent(),
                Value<String> chapterTitle = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<double> chapterPositionRatio = const Value.absent(),
                Value<String?> logicalPositionJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredReadingProgressesCompanion(
                bookId: bookId,
                sourceId: sourceId,
                detailUrl: detailUrl,
                chapterId: chapterId,
                chapterUrl: chapterUrl,
                chapterTitle: chapterTitle,
                chapterIndex: chapterIndex,
                chapterPositionRatio: chapterPositionRatio,
                logicalPositionJson: logicalPositionJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bookId,
                required String sourceId,
                required String detailUrl,
                required String chapterId,
                required String chapterUrl,
                required String chapterTitle,
                required int chapterIndex,
                Value<double> chapterPositionRatio = const Value.absent(),
                Value<String?> logicalPositionJson = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => StoredReadingProgressesCompanion.insert(
                bookId: bookId,
                sourceId: sourceId,
                detailUrl: detailUrl,
                chapterId: chapterId,
                chapterUrl: chapterUrl,
                chapterTitle: chapterTitle,
                chapterIndex: chapterIndex,
                chapterPositionRatio: chapterPositionRatio,
                logicalPositionJson: logicalPositionJson,
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

typedef $$StoredReadingProgressesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredReadingProgressesTable,
      StoredReadingProgressesData,
      $$StoredReadingProgressesTableFilterComposer,
      $$StoredReadingProgressesTableOrderingComposer,
      $$StoredReadingProgressesTableAnnotationComposer,
      $$StoredReadingProgressesTableCreateCompanionBuilder,
      $$StoredReadingProgressesTableUpdateCompanionBuilder,
      (
        StoredReadingProgressesData,
        BaseReferences<
          _$AppDatabase,
          $StoredReadingProgressesTable,
          StoredReadingProgressesData
        >,
      ),
      StoredReadingProgressesData,
      PrefetchHooks Function()
    >;
typedef $$StoredTocSnapshotsTableCreateCompanionBuilder =
    StoredTocSnapshotsCompanion Function({
      required String storageKey,
      required String bookId,
      required String sourceId,
      required String detailUrl,
      required String title,
      Value<String?> author,
      Value<String?> coverUrl,
      required String chaptersJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$StoredTocSnapshotsTableUpdateCompanionBuilder =
    StoredTocSnapshotsCompanion Function({
      Value<String> storageKey,
      Value<String> bookId,
      Value<String> sourceId,
      Value<String> detailUrl,
      Value<String> title,
      Value<String?> author,
      Value<String?> coverUrl,
      Value<String> chaptersJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$StoredTocSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $StoredTocSnapshotsTable> {
  $$StoredTocSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get storageKey => $composableBuilder(
    column: $table.storageKey,
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

  ColumnFilters<String> get detailUrl => $composableBuilder(
    column: $table.detailUrl,
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

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chaptersJson => $composableBuilder(
    column: $table.chaptersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredTocSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredTocSnapshotsTable> {
  $$StoredTocSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get storageKey => $composableBuilder(
    column: $table.storageKey,
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

  ColumnOrderings<String> get detailUrl => $composableBuilder(
    column: $table.detailUrl,
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

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chaptersJson => $composableBuilder(
    column: $table.chaptersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredTocSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredTocSnapshotsTable> {
  $$StoredTocSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get storageKey => $composableBuilder(
    column: $table.storageKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get detailUrl =>
      $composableBuilder(column: $table.detailUrl, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get chaptersJson => $composableBuilder(
    column: $table.chaptersJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StoredTocSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredTocSnapshotsTable,
          StoredTocSnapshot,
          $$StoredTocSnapshotsTableFilterComposer,
          $$StoredTocSnapshotsTableOrderingComposer,
          $$StoredTocSnapshotsTableAnnotationComposer,
          $$StoredTocSnapshotsTableCreateCompanionBuilder,
          $$StoredTocSnapshotsTableUpdateCompanionBuilder,
          (
            StoredTocSnapshot,
            BaseReferences<
              _$AppDatabase,
              $StoredTocSnapshotsTable,
              StoredTocSnapshot
            >,
          ),
          StoredTocSnapshot,
          PrefetchHooks Function()
        > {
  $$StoredTocSnapshotsTableTableManager(
    _$AppDatabase db,
    $StoredTocSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$StoredTocSnapshotsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$StoredTocSnapshotsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$StoredTocSnapshotsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> storageKey = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> detailUrl = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String> chaptersJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredTocSnapshotsCompanion(
                storageKey: storageKey,
                bookId: bookId,
                sourceId: sourceId,
                detailUrl: detailUrl,
                title: title,
                author: author,
                coverUrl: coverUrl,
                chaptersJson: chaptersJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String storageKey,
                required String bookId,
                required String sourceId,
                required String detailUrl,
                required String title,
                Value<String?> author = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                required String chaptersJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => StoredTocSnapshotsCompanion.insert(
                storageKey: storageKey,
                bookId: bookId,
                sourceId: sourceId,
                detailUrl: detailUrl,
                title: title,
                author: author,
                coverUrl: coverUrl,
                chaptersJson: chaptersJson,
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

typedef $$StoredTocSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredTocSnapshotsTable,
      StoredTocSnapshot,
      $$StoredTocSnapshotsTableFilterComposer,
      $$StoredTocSnapshotsTableOrderingComposer,
      $$StoredTocSnapshotsTableAnnotationComposer,
      $$StoredTocSnapshotsTableCreateCompanionBuilder,
      $$StoredTocSnapshotsTableUpdateCompanionBuilder,
      (
        StoredTocSnapshot,
        BaseReferences<
          _$AppDatabase,
          $StoredTocSnapshotsTable,
          StoredTocSnapshot
        >,
      ),
      StoredTocSnapshot,
      PrefetchHooks Function()
    >;
typedef $$StoredRemoteAccessSnapshotsTableCreateCompanionBuilder =
    StoredRemoteAccessSnapshotsCompanion Function({
      required String userId,
      Value<bool> serverSourceGatewayEnabled,
      Value<bool> hasMembership,
      Value<bool> hasThemeCustom,
      Value<int> serverSourceGatewayLimit,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$StoredRemoteAccessSnapshotsTableUpdateCompanionBuilder =
    StoredRemoteAccessSnapshotsCompanion Function({
      Value<String> userId,
      Value<bool> serverSourceGatewayEnabled,
      Value<bool> hasMembership,
      Value<bool> hasThemeCustom,
      Value<int> serverSourceGatewayLimit,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$StoredRemoteAccessSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $StoredRemoteAccessSnapshotsTable> {
  $$StoredRemoteAccessSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get serverSourceGatewayEnabled => $composableBuilder(
    column: $table.serverSourceGatewayEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasMembership => $composableBuilder(
    column: $table.hasMembership,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasThemeCustom => $composableBuilder(
    column: $table.hasThemeCustom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverSourceGatewayLimit => $composableBuilder(
    column: $table.serverSourceGatewayLimit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredRemoteAccessSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredRemoteAccessSnapshotsTable> {
  $$StoredRemoteAccessSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get serverSourceGatewayEnabled => $composableBuilder(
    column: $table.serverSourceGatewayEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasMembership => $composableBuilder(
    column: $table.hasMembership,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasThemeCustom => $composableBuilder(
    column: $table.hasThemeCustom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverSourceGatewayLimit => $composableBuilder(
    column: $table.serverSourceGatewayLimit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredRemoteAccessSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredRemoteAccessSnapshotsTable> {
  $$StoredRemoteAccessSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<bool> get serverSourceGatewayEnabled => $composableBuilder(
    column: $table.serverSourceGatewayEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasMembership => $composableBuilder(
    column: $table.hasMembership,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasThemeCustom => $composableBuilder(
    column: $table.hasThemeCustom,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverSourceGatewayLimit => $composableBuilder(
    column: $table.serverSourceGatewayLimit,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$StoredRemoteAccessSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredRemoteAccessSnapshotsTable,
          StoredRemoteAccessSnapshot,
          $$StoredRemoteAccessSnapshotsTableFilterComposer,
          $$StoredRemoteAccessSnapshotsTableOrderingComposer,
          $$StoredRemoteAccessSnapshotsTableAnnotationComposer,
          $$StoredRemoteAccessSnapshotsTableCreateCompanionBuilder,
          $$StoredRemoteAccessSnapshotsTableUpdateCompanionBuilder,
          (
            StoredRemoteAccessSnapshot,
            BaseReferences<
              _$AppDatabase,
              $StoredRemoteAccessSnapshotsTable,
              StoredRemoteAccessSnapshot
            >,
          ),
          StoredRemoteAccessSnapshot,
          PrefetchHooks Function()
        > {
  $$StoredRemoteAccessSnapshotsTableTableManager(
    _$AppDatabase db,
    $StoredRemoteAccessSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$StoredRemoteAccessSnapshotsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$StoredRemoteAccessSnapshotsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$StoredRemoteAccessSnapshotsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> userId = const Value.absent(),
                Value<bool> serverSourceGatewayEnabled = const Value.absent(),
                Value<bool> hasMembership = const Value.absent(),
                Value<bool> hasThemeCustom = const Value.absent(),
                Value<int> serverSourceGatewayLimit = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredRemoteAccessSnapshotsCompanion(
                userId: userId,
                serverSourceGatewayEnabled: serverSourceGatewayEnabled,
                hasMembership: hasMembership,
                hasThemeCustom: hasThemeCustom,
                serverSourceGatewayLimit: serverSourceGatewayLimit,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String userId,
                Value<bool> serverSourceGatewayEnabled = const Value.absent(),
                Value<bool> hasMembership = const Value.absent(),
                Value<bool> hasThemeCustom = const Value.absent(),
                Value<int> serverSourceGatewayLimit = const Value.absent(),
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => StoredRemoteAccessSnapshotsCompanion.insert(
                userId: userId,
                serverSourceGatewayEnabled: serverSourceGatewayEnabled,
                hasMembership: hasMembership,
                hasThemeCustom: hasThemeCustom,
                serverSourceGatewayLimit: serverSourceGatewayLimit,
                cachedAt: cachedAt,
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

typedef $$StoredRemoteAccessSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredRemoteAccessSnapshotsTable,
      StoredRemoteAccessSnapshot,
      $$StoredRemoteAccessSnapshotsTableFilterComposer,
      $$StoredRemoteAccessSnapshotsTableOrderingComposer,
      $$StoredRemoteAccessSnapshotsTableAnnotationComposer,
      $$StoredRemoteAccessSnapshotsTableCreateCompanionBuilder,
      $$StoredRemoteAccessSnapshotsTableUpdateCompanionBuilder,
      (
        StoredRemoteAccessSnapshot,
        BaseReferences<
          _$AppDatabase,
          $StoredRemoteAccessSnapshotsTable,
          StoredRemoteAccessSnapshot
        >,
      ),
      StoredRemoteAccessSnapshot,
      PrefetchHooks Function()
    >;
typedef $$StoredSourceHealthSnapshotsTableCreateCompanionBuilder =
    StoredSourceHealthSnapshotsCompanion Function({
      required String sourceId,
      required String payloadJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$StoredSourceHealthSnapshotsTableUpdateCompanionBuilder =
    StoredSourceHealthSnapshotsCompanion Function({
      Value<String> sourceId,
      Value<String> payloadJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$StoredSourceHealthSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $StoredSourceHealthSnapshotsTable> {
  $$StoredSourceHealthSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredSourceHealthSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredSourceHealthSnapshotsTable> {
  $$StoredSourceHealthSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredSourceHealthSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredSourceHealthSnapshotsTable> {
  $$StoredSourceHealthSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StoredSourceHealthSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredSourceHealthSnapshotsTable,
          StoredSourceHealthSnapshot,
          $$StoredSourceHealthSnapshotsTableFilterComposer,
          $$StoredSourceHealthSnapshotsTableOrderingComposer,
          $$StoredSourceHealthSnapshotsTableAnnotationComposer,
          $$StoredSourceHealthSnapshotsTableCreateCompanionBuilder,
          $$StoredSourceHealthSnapshotsTableUpdateCompanionBuilder,
          (
            StoredSourceHealthSnapshot,
            BaseReferences<
              _$AppDatabase,
              $StoredSourceHealthSnapshotsTable,
              StoredSourceHealthSnapshot
            >,
          ),
          StoredSourceHealthSnapshot,
          PrefetchHooks Function()
        > {
  $$StoredSourceHealthSnapshotsTableTableManager(
    _$AppDatabase db,
    $StoredSourceHealthSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$StoredSourceHealthSnapshotsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$StoredSourceHealthSnapshotsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$StoredSourceHealthSnapshotsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sourceId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredSourceHealthSnapshotsCompanion(
                sourceId: sourceId,
                payloadJson: payloadJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceId,
                required String payloadJson,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredSourceHealthSnapshotsCompanion.insert(
                sourceId: sourceId,
                payloadJson: payloadJson,
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

typedef $$StoredSourceHealthSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredSourceHealthSnapshotsTable,
      StoredSourceHealthSnapshot,
      $$StoredSourceHealthSnapshotsTableFilterComposer,
      $$StoredSourceHealthSnapshotsTableOrderingComposer,
      $$StoredSourceHealthSnapshotsTableAnnotationComposer,
      $$StoredSourceHealthSnapshotsTableCreateCompanionBuilder,
      $$StoredSourceHealthSnapshotsTableUpdateCompanionBuilder,
      (
        StoredSourceHealthSnapshot,
        BaseReferences<
          _$AppDatabase,
          $StoredSourceHealthSnapshotsTable,
          StoredSourceHealthSnapshot
        >,
      ),
      StoredSourceHealthSnapshot,
      PrefetchHooks Function()
    >;
typedef $$StoredBookshelfBooksTableCreateCompanionBuilder =
    StoredBookshelfBooksCompanion Function({
      required String sourceId,
      required String detailUrl,
      required String bookId,
      required String title,
      Value<String?> author,
      Value<String?> category,
      Value<String?> coverUrl,
      Value<String?> latestChapter,
      required DateTime addedAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$StoredBookshelfBooksTableUpdateCompanionBuilder =
    StoredBookshelfBooksCompanion Function({
      Value<String> sourceId,
      Value<String> detailUrl,
      Value<String> bookId,
      Value<String> title,
      Value<String?> author,
      Value<String?> category,
      Value<String?> coverUrl,
      Value<String?> latestChapter,
      Value<DateTime> addedAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$StoredBookshelfBooksTableFilterComposer
    extends Composer<_$AppDatabase, $StoredBookshelfBooksTable> {
  $$StoredBookshelfBooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detailUrl => $composableBuilder(
    column: $table.detailUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
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

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get latestChapter => $composableBuilder(
    column: $table.latestChapter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredBookshelfBooksTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredBookshelfBooksTable> {
  $$StoredBookshelfBooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detailUrl => $composableBuilder(
    column: $table.detailUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
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

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get latestChapter => $composableBuilder(
    column: $table.latestChapter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredBookshelfBooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredBookshelfBooksTable> {
  $$StoredBookshelfBooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get detailUrl =>
      $composableBuilder(column: $table.detailUrl, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get latestChapter => $composableBuilder(
    column: $table.latestChapter,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StoredBookshelfBooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredBookshelfBooksTable,
          StoredBookshelfBook,
          $$StoredBookshelfBooksTableFilterComposer,
          $$StoredBookshelfBooksTableOrderingComposer,
          $$StoredBookshelfBooksTableAnnotationComposer,
          $$StoredBookshelfBooksTableCreateCompanionBuilder,
          $$StoredBookshelfBooksTableUpdateCompanionBuilder,
          (
            StoredBookshelfBook,
            BaseReferences<
              _$AppDatabase,
              $StoredBookshelfBooksTable,
              StoredBookshelfBook
            >,
          ),
          StoredBookshelfBook,
          PrefetchHooks Function()
        > {
  $$StoredBookshelfBooksTableTableManager(
    _$AppDatabase db,
    $StoredBookshelfBooksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$StoredBookshelfBooksTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$StoredBookshelfBooksTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$StoredBookshelfBooksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sourceId = const Value.absent(),
                Value<String> detailUrl = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> latestChapter = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredBookshelfBooksCompanion(
                sourceId: sourceId,
                detailUrl: detailUrl,
                bookId: bookId,
                title: title,
                author: author,
                category: category,
                coverUrl: coverUrl,
                latestChapter: latestChapter,
                addedAt: addedAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceId,
                required String detailUrl,
                required String bookId,
                required String title,
                Value<String?> author = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> latestChapter = const Value.absent(),
                required DateTime addedAt,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredBookshelfBooksCompanion.insert(
                sourceId: sourceId,
                detailUrl: detailUrl,
                bookId: bookId,
                title: title,
                author: author,
                category: category,
                coverUrl: coverUrl,
                latestChapter: latestChapter,
                addedAt: addedAt,
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

typedef $$StoredBookshelfBooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredBookshelfBooksTable,
      StoredBookshelfBook,
      $$StoredBookshelfBooksTableFilterComposer,
      $$StoredBookshelfBooksTableOrderingComposer,
      $$StoredBookshelfBooksTableAnnotationComposer,
      $$StoredBookshelfBooksTableCreateCompanionBuilder,
      $$StoredBookshelfBooksTableUpdateCompanionBuilder,
      (
        StoredBookshelfBook,
        BaseReferences<
          _$AppDatabase,
          $StoredBookshelfBooksTable,
          StoredBookshelfBook
        >,
      ),
      StoredBookshelfBook,
      PrefetchHooks Function()
    >;
typedef $$StoredBookshelfTagAssignmentsTableCreateCompanionBuilder =
    StoredBookshelfTagAssignmentsCompanion Function({
      required String sourceId,
      required String detailUrl,
      required String tagName,
      Value<int> position,
      Value<int> rowid,
    });
typedef $$StoredBookshelfTagAssignmentsTableUpdateCompanionBuilder =
    StoredBookshelfTagAssignmentsCompanion Function({
      Value<String> sourceId,
      Value<String> detailUrl,
      Value<String> tagName,
      Value<int> position,
      Value<int> rowid,
    });

class $$StoredBookshelfTagAssignmentsTableFilterComposer
    extends Composer<_$AppDatabase, $StoredBookshelfTagAssignmentsTable> {
  $$StoredBookshelfTagAssignmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detailUrl => $composableBuilder(
    column: $table.detailUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagName => $composableBuilder(
    column: $table.tagName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredBookshelfTagAssignmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredBookshelfTagAssignmentsTable> {
  $$StoredBookshelfTagAssignmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detailUrl => $composableBuilder(
    column: $table.detailUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagName => $composableBuilder(
    column: $table.tagName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredBookshelfTagAssignmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredBookshelfTagAssignmentsTable> {
  $$StoredBookshelfTagAssignmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get detailUrl =>
      $composableBuilder(column: $table.detailUrl, builder: (column) => column);

  GeneratedColumn<String> get tagName =>
      $composableBuilder(column: $table.tagName, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$StoredBookshelfTagAssignmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredBookshelfTagAssignmentsTable,
          StoredBookshelfTagAssignment,
          $$StoredBookshelfTagAssignmentsTableFilterComposer,
          $$StoredBookshelfTagAssignmentsTableOrderingComposer,
          $$StoredBookshelfTagAssignmentsTableAnnotationComposer,
          $$StoredBookshelfTagAssignmentsTableCreateCompanionBuilder,
          $$StoredBookshelfTagAssignmentsTableUpdateCompanionBuilder,
          (
            StoredBookshelfTagAssignment,
            BaseReferences<
              _$AppDatabase,
              $StoredBookshelfTagAssignmentsTable,
              StoredBookshelfTagAssignment
            >,
          ),
          StoredBookshelfTagAssignment,
          PrefetchHooks Function()
        > {
  $$StoredBookshelfTagAssignmentsTableTableManager(
    _$AppDatabase db,
    $StoredBookshelfTagAssignmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$StoredBookshelfTagAssignmentsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$StoredBookshelfTagAssignmentsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$StoredBookshelfTagAssignmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sourceId = const Value.absent(),
                Value<String> detailUrl = const Value.absent(),
                Value<String> tagName = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredBookshelfTagAssignmentsCompanion(
                sourceId: sourceId,
                detailUrl: detailUrl,
                tagName: tagName,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceId,
                required String detailUrl,
                required String tagName,
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredBookshelfTagAssignmentsCompanion.insert(
                sourceId: sourceId,
                detailUrl: detailUrl,
                tagName: tagName,
                position: position,
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

typedef $$StoredBookshelfTagAssignmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredBookshelfTagAssignmentsTable,
      StoredBookshelfTagAssignment,
      $$StoredBookshelfTagAssignmentsTableFilterComposer,
      $$StoredBookshelfTagAssignmentsTableOrderingComposer,
      $$StoredBookshelfTagAssignmentsTableAnnotationComposer,
      $$StoredBookshelfTagAssignmentsTableCreateCompanionBuilder,
      $$StoredBookshelfTagAssignmentsTableUpdateCompanionBuilder,
      (
        StoredBookshelfTagAssignment,
        BaseReferences<
          _$AppDatabase,
          $StoredBookshelfTagAssignmentsTable,
          StoredBookshelfTagAssignment
        >,
      ),
      StoredBookshelfTagAssignment,
      PrefetchHooks Function()
    >;
typedef $$StoredBookshelfTagMetadataTableCreateCompanionBuilder =
    StoredBookshelfTagMetadataCompanion Function({
      required String name,
      required int colorValue,
      Value<int> position,
      Value<int> rowid,
    });
typedef $$StoredBookshelfTagMetadataTableUpdateCompanionBuilder =
    StoredBookshelfTagMetadataCompanion Function({
      Value<String> name,
      Value<int> colorValue,
      Value<int> position,
      Value<int> rowid,
    });

class $$StoredBookshelfTagMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $StoredBookshelfTagMetadataTable> {
  $$StoredBookshelfTagMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredBookshelfTagMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredBookshelfTagMetadataTable> {
  $$StoredBookshelfTagMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredBookshelfTagMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredBookshelfTagMetadataTable> {
  $$StoredBookshelfTagMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$StoredBookshelfTagMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredBookshelfTagMetadataTable,
          StoredBookshelfTagMetadataData,
          $$StoredBookshelfTagMetadataTableFilterComposer,
          $$StoredBookshelfTagMetadataTableOrderingComposer,
          $$StoredBookshelfTagMetadataTableAnnotationComposer,
          $$StoredBookshelfTagMetadataTableCreateCompanionBuilder,
          $$StoredBookshelfTagMetadataTableUpdateCompanionBuilder,
          (
            StoredBookshelfTagMetadataData,
            BaseReferences<
              _$AppDatabase,
              $StoredBookshelfTagMetadataTable,
              StoredBookshelfTagMetadataData
            >,
          ),
          StoredBookshelfTagMetadataData,
          PrefetchHooks Function()
        > {
  $$StoredBookshelfTagMetadataTableTableManager(
    _$AppDatabase db,
    $StoredBookshelfTagMetadataTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$StoredBookshelfTagMetadataTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$StoredBookshelfTagMetadataTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$StoredBookshelfTagMetadataTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> name = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredBookshelfTagMetadataCompanion(
                name: name,
                colorValue: colorValue,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String name,
                required int colorValue,
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredBookshelfTagMetadataCompanion.insert(
                name: name,
                colorValue: colorValue,
                position: position,
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

typedef $$StoredBookshelfTagMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredBookshelfTagMetadataTable,
      StoredBookshelfTagMetadataData,
      $$StoredBookshelfTagMetadataTableFilterComposer,
      $$StoredBookshelfTagMetadataTableOrderingComposer,
      $$StoredBookshelfTagMetadataTableAnnotationComposer,
      $$StoredBookshelfTagMetadataTableCreateCompanionBuilder,
      $$StoredBookshelfTagMetadataTableUpdateCompanionBuilder,
      (
        StoredBookshelfTagMetadataData,
        BaseReferences<
          _$AppDatabase,
          $StoredBookshelfTagMetadataTable,
          StoredBookshelfTagMetadataData
        >,
      ),
      StoredBookshelfTagMetadataData,
      PrefetchHooks Function()
    >;
typedef $$StoredBookshelfCategoryMetadataTableCreateCompanionBuilder =
    StoredBookshelfCategoryMetadataCompanion Function({
      required String name,
      required int colorValue,
      Value<int> position,
      Value<int> rowid,
    });
typedef $$StoredBookshelfCategoryMetadataTableUpdateCompanionBuilder =
    StoredBookshelfCategoryMetadataCompanion Function({
      Value<String> name,
      Value<int> colorValue,
      Value<int> position,
      Value<int> rowid,
    });

class $$StoredBookshelfCategoryMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $StoredBookshelfCategoryMetadataTable> {
  $$StoredBookshelfCategoryMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredBookshelfCategoryMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredBookshelfCategoryMetadataTable> {
  $$StoredBookshelfCategoryMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredBookshelfCategoryMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredBookshelfCategoryMetadataTable> {
  $$StoredBookshelfCategoryMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorValue => $composableBuilder(
    column: $table.colorValue,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$StoredBookshelfCategoryMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredBookshelfCategoryMetadataTable,
          StoredBookshelfCategoryMetadataData,
          $$StoredBookshelfCategoryMetadataTableFilterComposer,
          $$StoredBookshelfCategoryMetadataTableOrderingComposer,
          $$StoredBookshelfCategoryMetadataTableAnnotationComposer,
          $$StoredBookshelfCategoryMetadataTableCreateCompanionBuilder,
          $$StoredBookshelfCategoryMetadataTableUpdateCompanionBuilder,
          (
            StoredBookshelfCategoryMetadataData,
            BaseReferences<
              _$AppDatabase,
              $StoredBookshelfCategoryMetadataTable,
              StoredBookshelfCategoryMetadataData
            >,
          ),
          StoredBookshelfCategoryMetadataData,
          PrefetchHooks Function()
        > {
  $$StoredBookshelfCategoryMetadataTableTableManager(
    _$AppDatabase db,
    $StoredBookshelfCategoryMetadataTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$StoredBookshelfCategoryMetadataTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$StoredBookshelfCategoryMetadataTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$StoredBookshelfCategoryMetadataTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> name = const Value.absent(),
                Value<int> colorValue = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredBookshelfCategoryMetadataCompanion(
                name: name,
                colorValue: colorValue,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String name,
                required int colorValue,
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredBookshelfCategoryMetadataCompanion.insert(
                name: name,
                colorValue: colorValue,
                position: position,
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

typedef $$StoredBookshelfCategoryMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredBookshelfCategoryMetadataTable,
      StoredBookshelfCategoryMetadataData,
      $$StoredBookshelfCategoryMetadataTableFilterComposer,
      $$StoredBookshelfCategoryMetadataTableOrderingComposer,
      $$StoredBookshelfCategoryMetadataTableAnnotationComposer,
      $$StoredBookshelfCategoryMetadataTableCreateCompanionBuilder,
      $$StoredBookshelfCategoryMetadataTableUpdateCompanionBuilder,
      (
        StoredBookshelfCategoryMetadataData,
        BaseReferences<
          _$AppDatabase,
          $StoredBookshelfCategoryMetadataTable,
          StoredBookshelfCategoryMetadataData
        >,
      ),
      StoredBookshelfCategoryMetadataData,
      PrefetchHooks Function()
    >;
typedef $$StoredBookshelfBaseFilterOrdersTableCreateCompanionBuilder =
    StoredBookshelfBaseFilterOrdersCompanion Function({
      required String filterKey,
      Value<int> position,
      Value<int> rowid,
    });
typedef $$StoredBookshelfBaseFilterOrdersTableUpdateCompanionBuilder =
    StoredBookshelfBaseFilterOrdersCompanion Function({
      Value<String> filterKey,
      Value<int> position,
      Value<int> rowid,
    });

class $$StoredBookshelfBaseFilterOrdersTableFilterComposer
    extends Composer<_$AppDatabase, $StoredBookshelfBaseFilterOrdersTable> {
  $$StoredBookshelfBaseFilterOrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get filterKey => $composableBuilder(
    column: $table.filterKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredBookshelfBaseFilterOrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredBookshelfBaseFilterOrdersTable> {
  $$StoredBookshelfBaseFilterOrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get filterKey => $composableBuilder(
    column: $table.filterKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredBookshelfBaseFilterOrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredBookshelfBaseFilterOrdersTable> {
  $$StoredBookshelfBaseFilterOrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get filterKey =>
      $composableBuilder(column: $table.filterKey, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$StoredBookshelfBaseFilterOrdersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredBookshelfBaseFilterOrdersTable,
          StoredBookshelfBaseFilterOrder,
          $$StoredBookshelfBaseFilterOrdersTableFilterComposer,
          $$StoredBookshelfBaseFilterOrdersTableOrderingComposer,
          $$StoredBookshelfBaseFilterOrdersTableAnnotationComposer,
          $$StoredBookshelfBaseFilterOrdersTableCreateCompanionBuilder,
          $$StoredBookshelfBaseFilterOrdersTableUpdateCompanionBuilder,
          (
            StoredBookshelfBaseFilterOrder,
            BaseReferences<
              _$AppDatabase,
              $StoredBookshelfBaseFilterOrdersTable,
              StoredBookshelfBaseFilterOrder
            >,
          ),
          StoredBookshelfBaseFilterOrder,
          PrefetchHooks Function()
        > {
  $$StoredBookshelfBaseFilterOrdersTableTableManager(
    _$AppDatabase db,
    $StoredBookshelfBaseFilterOrdersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$StoredBookshelfBaseFilterOrdersTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$StoredBookshelfBaseFilterOrdersTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$StoredBookshelfBaseFilterOrdersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> filterKey = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredBookshelfBaseFilterOrdersCompanion(
                filterKey: filterKey,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String filterKey,
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredBookshelfBaseFilterOrdersCompanion.insert(
                filterKey: filterKey,
                position: position,
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

typedef $$StoredBookshelfBaseFilterOrdersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredBookshelfBaseFilterOrdersTable,
      StoredBookshelfBaseFilterOrder,
      $$StoredBookshelfBaseFilterOrdersTableFilterComposer,
      $$StoredBookshelfBaseFilterOrdersTableOrderingComposer,
      $$StoredBookshelfBaseFilterOrdersTableAnnotationComposer,
      $$StoredBookshelfBaseFilterOrdersTableCreateCompanionBuilder,
      $$StoredBookshelfBaseFilterOrdersTableUpdateCompanionBuilder,
      (
        StoredBookshelfBaseFilterOrder,
        BaseReferences<
          _$AppDatabase,
          $StoredBookshelfBaseFilterOrdersTable,
          StoredBookshelfBaseFilterOrder
        >,
      ),
      StoredBookshelfBaseFilterOrder,
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
typedef $$StoredSyncProfilesTableCreateCompanionBuilder =
    StoredSyncProfilesCompanion Function({
      required String id,
      required String name,
      required String driverType,
      required String endpointUrl,
      required String basePath,
      required String username,
      Value<String?> secretRef,
      Value<String> enabledScopesJson,
      Value<String?> scopeConfigJson,
      Value<bool> isAutoSyncEnabled,
      Value<DateTime?> lastSyncAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$StoredSyncProfilesTableUpdateCompanionBuilder =
    StoredSyncProfilesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> driverType,
      Value<String> endpointUrl,
      Value<String> basePath,
      Value<String> username,
      Value<String?> secretRef,
      Value<String> enabledScopesJson,
      Value<String?> scopeConfigJson,
      Value<bool> isAutoSyncEnabled,
      Value<DateTime?> lastSyncAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$StoredSyncProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $StoredSyncProfilesTable> {
  $$StoredSyncProfilesTableFilterComposer({
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

  ColumnFilters<String> get driverType => $composableBuilder(
    column: $table.driverType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endpointUrl => $composableBuilder(
    column: $table.endpointUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get basePath => $composableBuilder(
    column: $table.basePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get secretRef => $composableBuilder(
    column: $table.secretRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get enabledScopesJson => $composableBuilder(
    column: $table.enabledScopesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeConfigJson => $composableBuilder(
    column: $table.scopeConfigJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAutoSyncEnabled => $composableBuilder(
    column: $table.isAutoSyncEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
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

class $$StoredSyncProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredSyncProfilesTable> {
  $$StoredSyncProfilesTableOrderingComposer({
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

  ColumnOrderings<String> get driverType => $composableBuilder(
    column: $table.driverType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endpointUrl => $composableBuilder(
    column: $table.endpointUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get basePath => $composableBuilder(
    column: $table.basePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get secretRef => $composableBuilder(
    column: $table.secretRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get enabledScopesJson => $composableBuilder(
    column: $table.enabledScopesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeConfigJson => $composableBuilder(
    column: $table.scopeConfigJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAutoSyncEnabled => $composableBuilder(
    column: $table.isAutoSyncEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
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

class $$StoredSyncProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredSyncProfilesTable> {
  $$StoredSyncProfilesTableAnnotationComposer({
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

  GeneratedColumn<String> get driverType => $composableBuilder(
    column: $table.driverType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get endpointUrl => $composableBuilder(
    column: $table.endpointUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get basePath =>
      $composableBuilder(column: $table.basePath, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get secretRef =>
      $composableBuilder(column: $table.secretRef, builder: (column) => column);

  GeneratedColumn<String> get enabledScopesJson => $composableBuilder(
    column: $table.enabledScopesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scopeConfigJson => $composableBuilder(
    column: $table.scopeConfigJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isAutoSyncEnabled => $composableBuilder(
    column: $table.isAutoSyncEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StoredSyncProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredSyncProfilesTable,
          StoredSyncProfile,
          $$StoredSyncProfilesTableFilterComposer,
          $$StoredSyncProfilesTableOrderingComposer,
          $$StoredSyncProfilesTableAnnotationComposer,
          $$StoredSyncProfilesTableCreateCompanionBuilder,
          $$StoredSyncProfilesTableUpdateCompanionBuilder,
          (
            StoredSyncProfile,
            BaseReferences<
              _$AppDatabase,
              $StoredSyncProfilesTable,
              StoredSyncProfile
            >,
          ),
          StoredSyncProfile,
          PrefetchHooks Function()
        > {
  $$StoredSyncProfilesTableTableManager(
    _$AppDatabase db,
    $StoredSyncProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$StoredSyncProfilesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$StoredSyncProfilesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$StoredSyncProfilesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> driverType = const Value.absent(),
                Value<String> endpointUrl = const Value.absent(),
                Value<String> basePath = const Value.absent(),
                Value<String> username = const Value.absent(),
                Value<String?> secretRef = const Value.absent(),
                Value<String> enabledScopesJson = const Value.absent(),
                Value<String?> scopeConfigJson = const Value.absent(),
                Value<bool> isAutoSyncEnabled = const Value.absent(),
                Value<DateTime?> lastSyncAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredSyncProfilesCompanion(
                id: id,
                name: name,
                driverType: driverType,
                endpointUrl: endpointUrl,
                basePath: basePath,
                username: username,
                secretRef: secretRef,
                enabledScopesJson: enabledScopesJson,
                scopeConfigJson: scopeConfigJson,
                isAutoSyncEnabled: isAutoSyncEnabled,
                lastSyncAt: lastSyncAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String driverType,
                required String endpointUrl,
                required String basePath,
                required String username,
                Value<String?> secretRef = const Value.absent(),
                Value<String> enabledScopesJson = const Value.absent(),
                Value<String?> scopeConfigJson = const Value.absent(),
                Value<bool> isAutoSyncEnabled = const Value.absent(),
                Value<DateTime?> lastSyncAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredSyncProfilesCompanion.insert(
                id: id,
                name: name,
                driverType: driverType,
                endpointUrl: endpointUrl,
                basePath: basePath,
                username: username,
                secretRef: secretRef,
                enabledScopesJson: enabledScopesJson,
                scopeConfigJson: scopeConfigJson,
                isAutoSyncEnabled: isAutoSyncEnabled,
                lastSyncAt: lastSyncAt,
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

typedef $$StoredSyncProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredSyncProfilesTable,
      StoredSyncProfile,
      $$StoredSyncProfilesTableFilterComposer,
      $$StoredSyncProfilesTableOrderingComposer,
      $$StoredSyncProfilesTableAnnotationComposer,
      $$StoredSyncProfilesTableCreateCompanionBuilder,
      $$StoredSyncProfilesTableUpdateCompanionBuilder,
      (
        StoredSyncProfile,
        BaseReferences<
          _$AppDatabase,
          $StoredSyncProfilesTable,
          StoredSyncProfile
        >,
      ),
      StoredSyncProfile,
      PrefetchHooks Function()
    >;
typedef $$StoredSyncScopeStatesTableCreateCompanionBuilder =
    StoredSyncScopeStatesCompanion Function({
      required String profileId,
      required String scope,
      Value<String?> lastBaseSnapshotJson,
      Value<String?> lastRemoteRevision,
      Value<String?> lastRemoteHash,
      Value<String?> lastLocalHash,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$StoredSyncScopeStatesTableUpdateCompanionBuilder =
    StoredSyncScopeStatesCompanion Function({
      Value<String> profileId,
      Value<String> scope,
      Value<String?> lastBaseSnapshotJson,
      Value<String?> lastRemoteRevision,
      Value<String?> lastRemoteHash,
      Value<String?> lastLocalHash,
      Value<DateTime?> lastSyncedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$StoredSyncScopeStatesTableFilterComposer
    extends Composer<_$AppDatabase, $StoredSyncScopeStatesTable> {
  $$StoredSyncScopeStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastBaseSnapshotJson => $composableBuilder(
    column: $table.lastBaseSnapshotJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastRemoteRevision => $composableBuilder(
    column: $table.lastRemoteRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastRemoteHash => $composableBuilder(
    column: $table.lastRemoteHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastLocalHash => $composableBuilder(
    column: $table.lastLocalHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
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

class $$StoredSyncScopeStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredSyncScopeStatesTable> {
  $$StoredSyncScopeStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastBaseSnapshotJson => $composableBuilder(
    column: $table.lastBaseSnapshotJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastRemoteRevision => $composableBuilder(
    column: $table.lastRemoteRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastRemoteHash => $composableBuilder(
    column: $table.lastRemoteHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastLocalHash => $composableBuilder(
    column: $table.lastLocalHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
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

class $$StoredSyncScopeStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredSyncScopeStatesTable> {
  $$StoredSyncScopeStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get lastBaseSnapshotJson => $composableBuilder(
    column: $table.lastBaseSnapshotJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastRemoteRevision => $composableBuilder(
    column: $table.lastRemoteRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastRemoteHash => $composableBuilder(
    column: $table.lastRemoteHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastLocalHash => $composableBuilder(
    column: $table.lastLocalHash,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StoredSyncScopeStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredSyncScopeStatesTable,
          StoredSyncScopeState,
          $$StoredSyncScopeStatesTableFilterComposer,
          $$StoredSyncScopeStatesTableOrderingComposer,
          $$StoredSyncScopeStatesTableAnnotationComposer,
          $$StoredSyncScopeStatesTableCreateCompanionBuilder,
          $$StoredSyncScopeStatesTableUpdateCompanionBuilder,
          (
            StoredSyncScopeState,
            BaseReferences<
              _$AppDatabase,
              $StoredSyncScopeStatesTable,
              StoredSyncScopeState
            >,
          ),
          StoredSyncScopeState,
          PrefetchHooks Function()
        > {
  $$StoredSyncScopeStatesTableTableManager(
    _$AppDatabase db,
    $StoredSyncScopeStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$StoredSyncScopeStatesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$StoredSyncScopeStatesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$StoredSyncScopeStatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> profileId = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String?> lastBaseSnapshotJson = const Value.absent(),
                Value<String?> lastRemoteRevision = const Value.absent(),
                Value<String?> lastRemoteHash = const Value.absent(),
                Value<String?> lastLocalHash = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredSyncScopeStatesCompanion(
                profileId: profileId,
                scope: scope,
                lastBaseSnapshotJson: lastBaseSnapshotJson,
                lastRemoteRevision: lastRemoteRevision,
                lastRemoteHash: lastRemoteHash,
                lastLocalHash: lastLocalHash,
                lastSyncedAt: lastSyncedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String profileId,
                required String scope,
                Value<String?> lastBaseSnapshotJson = const Value.absent(),
                Value<String?> lastRemoteRevision = const Value.absent(),
                Value<String?> lastRemoteHash = const Value.absent(),
                Value<String?> lastLocalHash = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredSyncScopeStatesCompanion.insert(
                profileId: profileId,
                scope: scope,
                lastBaseSnapshotJson: lastBaseSnapshotJson,
                lastRemoteRevision: lastRemoteRevision,
                lastRemoteHash: lastRemoteHash,
                lastLocalHash: lastLocalHash,
                lastSyncedAt: lastSyncedAt,
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

typedef $$StoredSyncScopeStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredSyncScopeStatesTable,
      StoredSyncScopeState,
      $$StoredSyncScopeStatesTableFilterComposer,
      $$StoredSyncScopeStatesTableOrderingComposer,
      $$StoredSyncScopeStatesTableAnnotationComposer,
      $$StoredSyncScopeStatesTableCreateCompanionBuilder,
      $$StoredSyncScopeStatesTableUpdateCompanionBuilder,
      (
        StoredSyncScopeState,
        BaseReferences<
          _$AppDatabase,
          $StoredSyncScopeStatesTable,
          StoredSyncScopeState
        >,
      ),
      StoredSyncScopeState,
      PrefetchHooks Function()
    >;
typedef $$StoredSyncJobsTableCreateCompanionBuilder =
    StoredSyncJobsCompanion Function({
      required String id,
      required String profileId,
      required String triggerKind,
      Value<String> direction,
      required String status,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      Value<String?> summaryJson,
      Value<String?> errorMessage,
      Value<int> rowid,
    });
typedef $$StoredSyncJobsTableUpdateCompanionBuilder =
    StoredSyncJobsCompanion Function({
      Value<String> id,
      Value<String> profileId,
      Value<String> triggerKind,
      Value<String> direction,
      Value<String> status,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<String?> summaryJson,
      Value<String?> errorMessage,
      Value<int> rowid,
    });

class $$StoredSyncJobsTableFilterComposer
    extends Composer<_$AppDatabase, $StoredSyncJobsTable> {
  $$StoredSyncJobsTableFilterComposer({
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

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get triggerKind => $composableBuilder(
    column: $table.triggerKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredSyncJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredSyncJobsTable> {
  $$StoredSyncJobsTableOrderingComposer({
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

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get triggerKind => $composableBuilder(
    column: $table.triggerKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredSyncJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredSyncJobsTable> {
  $$StoredSyncJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get triggerKind => $composableBuilder(
    column: $table.triggerKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );
}

class $$StoredSyncJobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredSyncJobsTable,
          StoredSyncJob,
          $$StoredSyncJobsTableFilterComposer,
          $$StoredSyncJobsTableOrderingComposer,
          $$StoredSyncJobsTableAnnotationComposer,
          $$StoredSyncJobsTableCreateCompanionBuilder,
          $$StoredSyncJobsTableUpdateCompanionBuilder,
          (
            StoredSyncJob,
            BaseReferences<_$AppDatabase, $StoredSyncJobsTable, StoredSyncJob>,
          ),
          StoredSyncJob,
          PrefetchHooks Function()
        > {
  $$StoredSyncJobsTableTableManager(
    _$AppDatabase db,
    $StoredSyncJobsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$StoredSyncJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$StoredSyncJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$StoredSyncJobsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> triggerKind = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<String?> summaryJson = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredSyncJobsCompanion(
                id: id,
                profileId: profileId,
                triggerKind: triggerKind,
                direction: direction,
                status: status,
                startedAt: startedAt,
                endedAt: endedAt,
                summaryJson: summaryJson,
                errorMessage: errorMessage,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String profileId,
                required String triggerKind,
                Value<String> direction = const Value.absent(),
                required String status,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<String?> summaryJson = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredSyncJobsCompanion.insert(
                id: id,
                profileId: profileId,
                triggerKind: triggerKind,
                direction: direction,
                status: status,
                startedAt: startedAt,
                endedAt: endedAt,
                summaryJson: summaryJson,
                errorMessage: errorMessage,
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

typedef $$StoredSyncJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredSyncJobsTable,
      StoredSyncJob,
      $$StoredSyncJobsTableFilterComposer,
      $$StoredSyncJobsTableOrderingComposer,
      $$StoredSyncJobsTableAnnotationComposer,
      $$StoredSyncJobsTableCreateCompanionBuilder,
      $$StoredSyncJobsTableUpdateCompanionBuilder,
      (
        StoredSyncJob,
        BaseReferences<_$AppDatabase, $StoredSyncJobsTable, StoredSyncJob>,
      ),
      StoredSyncJob,
      PrefetchHooks Function()
    >;
typedef $$StoredSyncConflictsTableCreateCompanionBuilder =
    StoredSyncConflictsCompanion Function({
      required String id,
      required String profileId,
      required String scope,
      required String recordKey,
      Value<String?> basePayloadJson,
      Value<String?> localPayloadJson,
      Value<String?> remotePayloadJson,
      Value<String> resolution,
      Value<DateTime> createdAt,
      Value<DateTime?> resolvedAt,
      Value<int> rowid,
    });
typedef $$StoredSyncConflictsTableUpdateCompanionBuilder =
    StoredSyncConflictsCompanion Function({
      Value<String> id,
      Value<String> profileId,
      Value<String> scope,
      Value<String> recordKey,
      Value<String?> basePayloadJson,
      Value<String?> localPayloadJson,
      Value<String?> remotePayloadJson,
      Value<String> resolution,
      Value<DateTime> createdAt,
      Value<DateTime?> resolvedAt,
      Value<int> rowid,
    });

class $$StoredSyncConflictsTableFilterComposer
    extends Composer<_$AppDatabase, $StoredSyncConflictsTable> {
  $$StoredSyncConflictsTableFilterComposer({
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

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordKey => $composableBuilder(
    column: $table.recordKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get basePayloadJson => $composableBuilder(
    column: $table.basePayloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPayloadJson => $composableBuilder(
    column: $table.localPayloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remotePayloadJson => $composableBuilder(
    column: $table.remotePayloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredSyncConflictsTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredSyncConflictsTable> {
  $$StoredSyncConflictsTableOrderingComposer({
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

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordKey => $composableBuilder(
    column: $table.recordKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get basePayloadJson => $composableBuilder(
    column: $table.basePayloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPayloadJson => $composableBuilder(
    column: $table.localPayloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remotePayloadJson => $composableBuilder(
    column: $table.remotePayloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredSyncConflictsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredSyncConflictsTable> {
  $$StoredSyncConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get recordKey =>
      $composableBuilder(column: $table.recordKey, builder: (column) => column);

  GeneratedColumn<String> get basePayloadJson => $composableBuilder(
    column: $table.basePayloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localPayloadJson => $composableBuilder(
    column: $table.localPayloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remotePayloadJson => $composableBuilder(
    column: $table.remotePayloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );
}

class $$StoredSyncConflictsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredSyncConflictsTable,
          StoredSyncConflict,
          $$StoredSyncConflictsTableFilterComposer,
          $$StoredSyncConflictsTableOrderingComposer,
          $$StoredSyncConflictsTableAnnotationComposer,
          $$StoredSyncConflictsTableCreateCompanionBuilder,
          $$StoredSyncConflictsTableUpdateCompanionBuilder,
          (
            StoredSyncConflict,
            BaseReferences<
              _$AppDatabase,
              $StoredSyncConflictsTable,
              StoredSyncConflict
            >,
          ),
          StoredSyncConflict,
          PrefetchHooks Function()
        > {
  $$StoredSyncConflictsTableTableManager(
    _$AppDatabase db,
    $StoredSyncConflictsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$StoredSyncConflictsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$StoredSyncConflictsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$StoredSyncConflictsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String> recordKey = const Value.absent(),
                Value<String?> basePayloadJson = const Value.absent(),
                Value<String?> localPayloadJson = const Value.absent(),
                Value<String?> remotePayloadJson = const Value.absent(),
                Value<String> resolution = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredSyncConflictsCompanion(
                id: id,
                profileId: profileId,
                scope: scope,
                recordKey: recordKey,
                basePayloadJson: basePayloadJson,
                localPayloadJson: localPayloadJson,
                remotePayloadJson: remotePayloadJson,
                resolution: resolution,
                createdAt: createdAt,
                resolvedAt: resolvedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String profileId,
                required String scope,
                required String recordKey,
                Value<String?> basePayloadJson = const Value.absent(),
                Value<String?> localPayloadJson = const Value.absent(),
                Value<String?> remotePayloadJson = const Value.absent(),
                Value<String> resolution = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredSyncConflictsCompanion.insert(
                id: id,
                profileId: profileId,
                scope: scope,
                recordKey: recordKey,
                basePayloadJson: basePayloadJson,
                localPayloadJson: localPayloadJson,
                remotePayloadJson: remotePayloadJson,
                resolution: resolution,
                createdAt: createdAt,
                resolvedAt: resolvedAt,
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

typedef $$StoredSyncConflictsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredSyncConflictsTable,
      StoredSyncConflict,
      $$StoredSyncConflictsTableFilterComposer,
      $$StoredSyncConflictsTableOrderingComposer,
      $$StoredSyncConflictsTableAnnotationComposer,
      $$StoredSyncConflictsTableCreateCompanionBuilder,
      $$StoredSyncConflictsTableUpdateCompanionBuilder,
      (
        StoredSyncConflict,
        BaseReferences<
          _$AppDatabase,
          $StoredSyncConflictsTable,
          StoredSyncConflict
        >,
      ),
      StoredSyncConflict,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ChapterCachesTableTableManager get chapterCaches =>
      $$ChapterCachesTableTableManager(_db, _db.chapterCaches);
  $$StoredLocalBooksTableTableManager get storedLocalBooks =>
      $$StoredLocalBooksTableTableManager(_db, _db.storedLocalBooks);
  $$StoredLocalChaptersTableTableManager get storedLocalChapters =>
      $$StoredLocalChaptersTableTableManager(_db, _db.storedLocalChapters);
  $$StoredBookmarksTableTableManager get storedBookmarks =>
      $$StoredBookmarksTableTableManager(_db, _db.storedBookmarks);
  $$StoredBookMetadataOverridesTableTableManager
  get storedBookMetadataOverrides =>
      $$StoredBookMetadataOverridesTableTableManager(
        _db,
        _db.storedBookMetadataOverrides,
      );
  $$StoredReadingRecordsTableTableManager get storedReadingRecords =>
      $$StoredReadingRecordsTableTableManager(_db, _db.storedReadingRecords);
  $$StoredReadingRecordDaysTableTableManager get storedReadingRecordDays =>
      $$StoredReadingRecordDaysTableTableManager(
        _db,
        _db.storedReadingRecordDays,
      );
  $$StoredReadingRecordSessionsTableTableManager
  get storedReadingRecordSessions =>
      $$StoredReadingRecordSessionsTableTableManager(
        _db,
        _db.storedReadingRecordSessions,
      );
  $$StoredReadingBookStatusesTableTableManager get storedReadingBookStatuses =>
      $$StoredReadingBookStatusesTableTableManager(
        _db,
        _db.storedReadingBookStatuses,
      );
  $$StoredReadingProgressesTableTableManager get storedReadingProgresses =>
      $$StoredReadingProgressesTableTableManager(
        _db,
        _db.storedReadingProgresses,
      );
  $$StoredTocSnapshotsTableTableManager get storedTocSnapshots =>
      $$StoredTocSnapshotsTableTableManager(_db, _db.storedTocSnapshots);
  $$StoredRemoteAccessSnapshotsTableTableManager
  get storedRemoteAccessSnapshots =>
      $$StoredRemoteAccessSnapshotsTableTableManager(
        _db,
        _db.storedRemoteAccessSnapshots,
      );
  $$StoredSourceHealthSnapshotsTableTableManager
  get storedSourceHealthSnapshots =>
      $$StoredSourceHealthSnapshotsTableTableManager(
        _db,
        _db.storedSourceHealthSnapshots,
      );
  $$StoredBookshelfBooksTableTableManager get storedBookshelfBooks =>
      $$StoredBookshelfBooksTableTableManager(_db, _db.storedBookshelfBooks);
  $$StoredBookshelfTagAssignmentsTableTableManager
  get storedBookshelfTagAssignments =>
      $$StoredBookshelfTagAssignmentsTableTableManager(
        _db,
        _db.storedBookshelfTagAssignments,
      );
  $$StoredBookshelfTagMetadataTableTableManager
  get storedBookshelfTagMetadata =>
      $$StoredBookshelfTagMetadataTableTableManager(
        _db,
        _db.storedBookshelfTagMetadata,
      );
  $$StoredBookshelfCategoryMetadataTableTableManager
  get storedBookshelfCategoryMetadata =>
      $$StoredBookshelfCategoryMetadataTableTableManager(
        _db,
        _db.storedBookshelfCategoryMetadata,
      );
  $$StoredBookshelfBaseFilterOrdersTableTableManager
  get storedBookshelfBaseFilterOrders =>
      $$StoredBookshelfBaseFilterOrdersTableTableManager(
        _db,
        _db.storedBookshelfBaseFilterOrders,
      );
  $$SearchSourceHitsTableTableManager get searchSourceHits =>
      $$SearchSourceHitsTableTableManager(_db, _db.searchSourceHits);
  $$StoredSyncProfilesTableTableManager get storedSyncProfiles =>
      $$StoredSyncProfilesTableTableManager(_db, _db.storedSyncProfiles);
  $$StoredSyncScopeStatesTableTableManager get storedSyncScopeStates =>
      $$StoredSyncScopeStatesTableTableManager(_db, _db.storedSyncScopeStates);
  $$StoredSyncJobsTableTableManager get storedSyncJobs =>
      $$StoredSyncJobsTableTableManager(_db, _db.storedSyncJobs);
  $$StoredSyncConflictsTableTableManager get storedSyncConflicts =>
      $$StoredSyncConflictsTableTableManager(_db, _db.storedSyncConflicts);
}
