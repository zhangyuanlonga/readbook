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

class $StoredScriptSourcesTable extends StoredScriptSources
    with TableInfo<$StoredScriptSourcesTable, StoredScriptSource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredScriptSourcesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _groupMeta = const VerificationMeta('group');
  @override
  late final GeneratedColumn<String> group = GeneratedColumn<String>(
    'group',
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
  static const VerificationMeta _checkKeywordMeta = const VerificationMeta(
    'checkKeyword',
  );
  @override
  late final GeneratedColumn<String> checkKeyword = GeneratedColumn<String>(
    'check_keyword',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _primaryHostMeta = const VerificationMeta(
    'primaryHost',
  );
  @override
  late final GeneratedColumn<String> primaryHost = GeneratedColumn<String>(
    'primary_host',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _registrableDomainMeta = const VerificationMeta(
    'registrableDomain',
  );
  @override
  late final GeneratedColumn<String> registrableDomain =
      GeneratedColumn<String>(
        'registrable_domain',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _clusterKeyMeta = const VerificationMeta(
    'clusterKey',
  );
  @override
  late final GeneratedColumn<String> clusterKey = GeneratedColumn<String>(
    'cluster_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceCodeMeta = const VerificationMeta(
    'sourceCode',
  );
  @override
  late final GeneratedColumn<String> sourceCode = GeneratedColumn<String>(
    'source_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    group,
    author,
    description,
    checkKeyword,
    primaryHost,
    registrableDomain,
    clusterKey,
    sourceCode,
    enabled,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'script_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredScriptSource> instance, {
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
    if (data.containsKey('group')) {
      context.handle(
        _groupMeta,
        group.isAcceptableOrUnknown(data['group']!, _groupMeta),
      );
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
    if (data.containsKey('check_keyword')) {
      context.handle(
        _checkKeywordMeta,
        checkKeyword.isAcceptableOrUnknown(
          data['check_keyword']!,
          _checkKeywordMeta,
        ),
      );
    }
    if (data.containsKey('primary_host')) {
      context.handle(
        _primaryHostMeta,
        primaryHost.isAcceptableOrUnknown(
          data['primary_host']!,
          _primaryHostMeta,
        ),
      );
    }
    if (data.containsKey('registrable_domain')) {
      context.handle(
        _registrableDomainMeta,
        registrableDomain.isAcceptableOrUnknown(
          data['registrable_domain']!,
          _registrableDomainMeta,
        ),
      );
    }
    if (data.containsKey('cluster_key')) {
      context.handle(
        _clusterKeyMeta,
        clusterKey.isAcceptableOrUnknown(data['cluster_key']!, _clusterKeyMeta),
      );
    }
    if (data.containsKey('source_code')) {
      context.handle(
        _sourceCodeMeta,
        sourceCode.isAcceptableOrUnknown(data['source_code']!, _sourceCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceCodeMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
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
  StoredScriptSource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredScriptSource(
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
      group: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group'],
      ),
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      checkKeyword: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}check_keyword'],
      ),
      primaryHost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primary_host'],
      ),
      registrableDomain: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}registrable_domain'],
      ),
      clusterKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cluster_key'],
      ),
      sourceCode:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}source_code'],
          )!,
      enabled:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}enabled'],
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
  $StoredScriptSourcesTable createAlias(String alias) {
    return $StoredScriptSourcesTable(attachedDatabase, alias);
  }
}

class StoredScriptSource extends DataClass
    implements Insertable<StoredScriptSource> {
  final String id;
  final String name;
  final String? group;
  final String? author;
  final String? description;
  final String? checkKeyword;
  final String? primaryHost;
  final String? registrableDomain;
  final String? clusterKey;
  final String sourceCode;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;
  const StoredScriptSource({
    required this.id,
    required this.name,
    this.group,
    this.author,
    this.description,
    this.checkKeyword,
    this.primaryHost,
    this.registrableDomain,
    this.clusterKey,
    required this.sourceCode,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || group != null) {
      map['group'] = Variable<String>(group);
    }
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || checkKeyword != null) {
      map['check_keyword'] = Variable<String>(checkKeyword);
    }
    if (!nullToAbsent || primaryHost != null) {
      map['primary_host'] = Variable<String>(primaryHost);
    }
    if (!nullToAbsent || registrableDomain != null) {
      map['registrable_domain'] = Variable<String>(registrableDomain);
    }
    if (!nullToAbsent || clusterKey != null) {
      map['cluster_key'] = Variable<String>(clusterKey);
    }
    map['source_code'] = Variable<String>(sourceCode);
    map['enabled'] = Variable<bool>(enabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StoredScriptSourcesCompanion toCompanion(bool nullToAbsent) {
    return StoredScriptSourcesCompanion(
      id: Value(id),
      name: Value(name),
      group:
          group == null && nullToAbsent ? const Value.absent() : Value(group),
      author:
          author == null && nullToAbsent ? const Value.absent() : Value(author),
      description:
          description == null && nullToAbsent
              ? const Value.absent()
              : Value(description),
      checkKeyword:
          checkKeyword == null && nullToAbsent
              ? const Value.absent()
              : Value(checkKeyword),
      primaryHost:
          primaryHost == null && nullToAbsent
              ? const Value.absent()
              : Value(primaryHost),
      registrableDomain:
          registrableDomain == null && nullToAbsent
              ? const Value.absent()
              : Value(registrableDomain),
      clusterKey:
          clusterKey == null && nullToAbsent
              ? const Value.absent()
              : Value(clusterKey),
      sourceCode: Value(sourceCode),
      enabled: Value(enabled),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredScriptSource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredScriptSource(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      group: serializer.fromJson<String?>(json['group']),
      author: serializer.fromJson<String?>(json['author']),
      description: serializer.fromJson<String?>(json['description']),
      checkKeyword: serializer.fromJson<String?>(json['checkKeyword']),
      primaryHost: serializer.fromJson<String?>(json['primaryHost']),
      registrableDomain: serializer.fromJson<String?>(
        json['registrableDomain'],
      ),
      clusterKey: serializer.fromJson<String?>(json['clusterKey']),
      sourceCode: serializer.fromJson<String>(json['sourceCode']),
      enabled: serializer.fromJson<bool>(json['enabled']),
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
      'group': serializer.toJson<String?>(group),
      'author': serializer.toJson<String?>(author),
      'description': serializer.toJson<String?>(description),
      'checkKeyword': serializer.toJson<String?>(checkKeyword),
      'primaryHost': serializer.toJson<String?>(primaryHost),
      'registrableDomain': serializer.toJson<String?>(registrableDomain),
      'clusterKey': serializer.toJson<String?>(clusterKey),
      'sourceCode': serializer.toJson<String>(sourceCode),
      'enabled': serializer.toJson<bool>(enabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredScriptSource copyWith({
    String? id,
    String? name,
    Value<String?> group = const Value.absent(),
    Value<String?> author = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> checkKeyword = const Value.absent(),
    Value<String?> primaryHost = const Value.absent(),
    Value<String?> registrableDomain = const Value.absent(),
    Value<String?> clusterKey = const Value.absent(),
    String? sourceCode,
    bool? enabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StoredScriptSource(
    id: id ?? this.id,
    name: name ?? this.name,
    group: group.present ? group.value : this.group,
    author: author.present ? author.value : this.author,
    description: description.present ? description.value : this.description,
    checkKeyword: checkKeyword.present ? checkKeyword.value : this.checkKeyword,
    primaryHost: primaryHost.present ? primaryHost.value : this.primaryHost,
    registrableDomain:
        registrableDomain.present
            ? registrableDomain.value
            : this.registrableDomain,
    clusterKey: clusterKey.present ? clusterKey.value : this.clusterKey,
    sourceCode: sourceCode ?? this.sourceCode,
    enabled: enabled ?? this.enabled,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredScriptSource copyWithCompanion(StoredScriptSourcesCompanion data) {
    return StoredScriptSource(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      group: data.group.present ? data.group.value : this.group,
      author: data.author.present ? data.author.value : this.author,
      description:
          data.description.present ? data.description.value : this.description,
      checkKeyword:
          data.checkKeyword.present
              ? data.checkKeyword.value
              : this.checkKeyword,
      primaryHost:
          data.primaryHost.present ? data.primaryHost.value : this.primaryHost,
      registrableDomain:
          data.registrableDomain.present
              ? data.registrableDomain.value
              : this.registrableDomain,
      clusterKey:
          data.clusterKey.present ? data.clusterKey.value : this.clusterKey,
      sourceCode:
          data.sourceCode.present ? data.sourceCode.value : this.sourceCode,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredScriptSource(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('group: $group, ')
          ..write('author: $author, ')
          ..write('description: $description, ')
          ..write('checkKeyword: $checkKeyword, ')
          ..write('primaryHost: $primaryHost, ')
          ..write('registrableDomain: $registrableDomain, ')
          ..write('clusterKey: $clusterKey, ')
          ..write('sourceCode: $sourceCode, ')
          ..write('enabled: $enabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    group,
    author,
    description,
    checkKeyword,
    primaryHost,
    registrableDomain,
    clusterKey,
    sourceCode,
    enabled,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredScriptSource &&
          other.id == this.id &&
          other.name == this.name &&
          other.group == this.group &&
          other.author == this.author &&
          other.description == this.description &&
          other.checkKeyword == this.checkKeyword &&
          other.primaryHost == this.primaryHost &&
          other.registrableDomain == this.registrableDomain &&
          other.clusterKey == this.clusterKey &&
          other.sourceCode == this.sourceCode &&
          other.enabled == this.enabled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class StoredScriptSourcesCompanion extends UpdateCompanion<StoredScriptSource> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> group;
  final Value<String?> author;
  final Value<String?> description;
  final Value<String?> checkKeyword;
  final Value<String?> primaryHost;
  final Value<String?> registrableDomain;
  final Value<String?> clusterKey;
  final Value<String> sourceCode;
  final Value<bool> enabled;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StoredScriptSourcesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.group = const Value.absent(),
    this.author = const Value.absent(),
    this.description = const Value.absent(),
    this.checkKeyword = const Value.absent(),
    this.primaryHost = const Value.absent(),
    this.registrableDomain = const Value.absent(),
    this.clusterKey = const Value.absent(),
    this.sourceCode = const Value.absent(),
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredScriptSourcesCompanion.insert({
    required String id,
    required String name,
    this.group = const Value.absent(),
    this.author = const Value.absent(),
    this.description = const Value.absent(),
    this.checkKeyword = const Value.absent(),
    this.primaryHost = const Value.absent(),
    this.registrableDomain = const Value.absent(),
    this.clusterKey = const Value.absent(),
    required String sourceCode,
    this.enabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       sourceCode = Value(sourceCode);
  static Insertable<StoredScriptSource> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? group,
    Expression<String>? author,
    Expression<String>? description,
    Expression<String>? checkKeyword,
    Expression<String>? primaryHost,
    Expression<String>? registrableDomain,
    Expression<String>? clusterKey,
    Expression<String>? sourceCode,
    Expression<bool>? enabled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (group != null) 'group': group,
      if (author != null) 'author': author,
      if (description != null) 'description': description,
      if (checkKeyword != null) 'check_keyword': checkKeyword,
      if (primaryHost != null) 'primary_host': primaryHost,
      if (registrableDomain != null) 'registrable_domain': registrableDomain,
      if (clusterKey != null) 'cluster_key': clusterKey,
      if (sourceCode != null) 'source_code': sourceCode,
      if (enabled != null) 'enabled': enabled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredScriptSourcesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? group,
    Value<String?>? author,
    Value<String?>? description,
    Value<String?>? checkKeyword,
    Value<String?>? primaryHost,
    Value<String?>? registrableDomain,
    Value<String?>? clusterKey,
    Value<String>? sourceCode,
    Value<bool>? enabled,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StoredScriptSourcesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      group: group ?? this.group,
      author: author ?? this.author,
      description: description ?? this.description,
      checkKeyword: checkKeyword ?? this.checkKeyword,
      primaryHost: primaryHost ?? this.primaryHost,
      registrableDomain: registrableDomain ?? this.registrableDomain,
      clusterKey: clusterKey ?? this.clusterKey,
      sourceCode: sourceCode ?? this.sourceCode,
      enabled: enabled ?? this.enabled,
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
    if (group.present) {
      map['group'] = Variable<String>(group.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (checkKeyword.present) {
      map['check_keyword'] = Variable<String>(checkKeyword.value);
    }
    if (primaryHost.present) {
      map['primary_host'] = Variable<String>(primaryHost.value);
    }
    if (registrableDomain.present) {
      map['registrable_domain'] = Variable<String>(registrableDomain.value);
    }
    if (clusterKey.present) {
      map['cluster_key'] = Variable<String>(clusterKey.value);
    }
    if (sourceCode.present) {
      map['source_code'] = Variable<String>(sourceCode.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
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
    return (StringBuffer('StoredScriptSourcesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('group: $group, ')
          ..write('author: $author, ')
          ..write('description: $description, ')
          ..write('checkKeyword: $checkKeyword, ')
          ..write('primaryHost: $primaryHost, ')
          ..write('registrableDomain: $registrableDomain, ')
          ..write('clusterKey: $clusterKey, ')
          ..write('sourceCode: $sourceCode, ')
          ..write('enabled: $enabled, ')
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
  late final $ChapterCachesTable chapterCaches = $ChapterCachesTable(this);
  late final $StoredLocalBooksTable storedLocalBooks = $StoredLocalBooksTable(
    this,
  );
  late final $StoredLocalChaptersTable storedLocalChapters =
      $StoredLocalChaptersTable(this);
  late final $StoredBookmarksTable storedBookmarks = $StoredBookmarksTable(
    this,
  );
  late final $StoredReadingRecordsTable storedReadingRecords =
      $StoredReadingRecordsTable(this);
  late final $StoredReadingRecordDaysTable storedReadingRecordDays =
      $StoredReadingRecordDaysTable(this);
  late final $StoredReadingRecordSessionsTable storedReadingRecordSessions =
      $StoredReadingRecordSessionsTable(this);
  late final $StoredReadingBookStatusesTable storedReadingBookStatuses =
      $StoredReadingBookStatusesTable(this);
  late final $SearchSourceHitsTable searchSourceHits = $SearchSourceHitsTable(
    this,
  );
  late final $StoredScriptSourcesTable storedScriptSources =
      $StoredScriptSourcesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    chapterCaches,
    storedLocalBooks,
    storedLocalChapters,
    storedBookmarks,
    storedReadingRecords,
    storedReadingRecordDays,
    storedReadingRecordSessions,
    storedReadingBookStatuses,
    searchSourceHits,
    storedScriptSources,
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
typedef $$StoredScriptSourcesTableCreateCompanionBuilder =
    StoredScriptSourcesCompanion Function({
      required String id,
      required String name,
      Value<String?> group,
      Value<String?> author,
      Value<String?> description,
      Value<String?> checkKeyword,
      Value<String?> primaryHost,
      Value<String?> registrableDomain,
      Value<String?> clusterKey,
      required String sourceCode,
      Value<bool> enabled,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$StoredScriptSourcesTableUpdateCompanionBuilder =
    StoredScriptSourcesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> group,
      Value<String?> author,
      Value<String?> description,
      Value<String?> checkKeyword,
      Value<String?> primaryHost,
      Value<String?> registrableDomain,
      Value<String?> clusterKey,
      Value<String> sourceCode,
      Value<bool> enabled,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$StoredScriptSourcesTableFilterComposer
    extends Composer<_$AppDatabase, $StoredScriptSourcesTable> {
  $$StoredScriptSourcesTableFilterComposer({
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

  ColumnFilters<String> get group => $composableBuilder(
    column: $table.group,
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

  ColumnFilters<String> get checkKeyword => $composableBuilder(
    column: $table.checkKeyword,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get primaryHost => $composableBuilder(
    column: $table.primaryHost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get registrableDomain => $composableBuilder(
    column: $table.registrableDomain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clusterKey => $composableBuilder(
    column: $table.clusterKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceCode => $composableBuilder(
    column: $table.sourceCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
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

class $$StoredScriptSourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredScriptSourcesTable> {
  $$StoredScriptSourcesTableOrderingComposer({
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

  ColumnOrderings<String> get group => $composableBuilder(
    column: $table.group,
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

  ColumnOrderings<String> get checkKeyword => $composableBuilder(
    column: $table.checkKeyword,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get primaryHost => $composableBuilder(
    column: $table.primaryHost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get registrableDomain => $composableBuilder(
    column: $table.registrableDomain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clusterKey => $composableBuilder(
    column: $table.clusterKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceCode => $composableBuilder(
    column: $table.sourceCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
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

class $$StoredScriptSourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredScriptSourcesTable> {
  $$StoredScriptSourcesTableAnnotationComposer({
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

  GeneratedColumn<String> get group =>
      $composableBuilder(column: $table.group, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get checkKeyword => $composableBuilder(
    column: $table.checkKeyword,
    builder: (column) => column,
  );

  GeneratedColumn<String> get primaryHost => $composableBuilder(
    column: $table.primaryHost,
    builder: (column) => column,
  );

  GeneratedColumn<String> get registrableDomain => $composableBuilder(
    column: $table.registrableDomain,
    builder: (column) => column,
  );

  GeneratedColumn<String> get clusterKey => $composableBuilder(
    column: $table.clusterKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceCode => $composableBuilder(
    column: $table.sourceCode,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StoredScriptSourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredScriptSourcesTable,
          StoredScriptSource,
          $$StoredScriptSourcesTableFilterComposer,
          $$StoredScriptSourcesTableOrderingComposer,
          $$StoredScriptSourcesTableAnnotationComposer,
          $$StoredScriptSourcesTableCreateCompanionBuilder,
          $$StoredScriptSourcesTableUpdateCompanionBuilder,
          (
            StoredScriptSource,
            BaseReferences<
              _$AppDatabase,
              $StoredScriptSourcesTable,
              StoredScriptSource
            >,
          ),
          StoredScriptSource,
          PrefetchHooks Function()
        > {
  $$StoredScriptSourcesTableTableManager(
    _$AppDatabase db,
    $StoredScriptSourcesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$StoredScriptSourcesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$StoredScriptSourcesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$StoredScriptSourcesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> group = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> checkKeyword = const Value.absent(),
                Value<String?> primaryHost = const Value.absent(),
                Value<String?> registrableDomain = const Value.absent(),
                Value<String?> clusterKey = const Value.absent(),
                Value<String> sourceCode = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredScriptSourcesCompanion(
                id: id,
                name: name,
                group: group,
                author: author,
                description: description,
                checkKeyword: checkKeyword,
                primaryHost: primaryHost,
                registrableDomain: registrableDomain,
                clusterKey: clusterKey,
                sourceCode: sourceCode,
                enabled: enabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> group = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> checkKeyword = const Value.absent(),
                Value<String?> primaryHost = const Value.absent(),
                Value<String?> registrableDomain = const Value.absent(),
                Value<String?> clusterKey = const Value.absent(),
                required String sourceCode,
                Value<bool> enabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredScriptSourcesCompanion.insert(
                id: id,
                name: name,
                group: group,
                author: author,
                description: description,
                checkKeyword: checkKeyword,
                primaryHost: primaryHost,
                registrableDomain: registrableDomain,
                clusterKey: clusterKey,
                sourceCode: sourceCode,
                enabled: enabled,
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

typedef $$StoredScriptSourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredScriptSourcesTable,
      StoredScriptSource,
      $$StoredScriptSourcesTableFilterComposer,
      $$StoredScriptSourcesTableOrderingComposer,
      $$StoredScriptSourcesTableAnnotationComposer,
      $$StoredScriptSourcesTableCreateCompanionBuilder,
      $$StoredScriptSourcesTableUpdateCompanionBuilder,
      (
        StoredScriptSource,
        BaseReferences<
          _$AppDatabase,
          $StoredScriptSourcesTable,
          StoredScriptSource
        >,
      ),
      StoredScriptSource,
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
  $$SearchSourceHitsTableTableManager get searchSourceHits =>
      $$SearchSourceHitsTableTableManager(_db, _db.searchSourceHits);
  $$StoredScriptSourcesTableTableManager get storedScriptSources =>
      $$StoredScriptSourcesTableTableManager(_db, _db.storedScriptSources);
}
