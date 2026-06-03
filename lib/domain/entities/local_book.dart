import 'package:json_annotation/json_annotation.dart';

part 'local_book.g.dart';

enum LocalBookFormat { txt, epub, md, html, pdf, mobi, azw, azw3 }

enum LocalBookIndexStatus { pending, indexing, ready, stale, failed }

extension LocalBookFormatSemantics on LocalBookFormat {
  String get displayLabel => switch (this) {
    LocalBookFormat.txt => 'TXT',
    LocalBookFormat.epub => 'EPUB',
    LocalBookFormat.md => 'Markdown',
    LocalBookFormat.html => 'HTML',
    LocalBookFormat.pdf => 'PDF',
    LocalBookFormat.mobi => 'MOBI',
    LocalBookFormat.azw => 'AZW',
    LocalBookFormat.azw3 => 'AZW3',
  };

  bool get supportsBootstrapPreview => this == LocalBookFormat.txt;

  bool get requiresManagedAssetDirectory => switch (this) {
    LocalBookFormat.epub ||
    LocalBookFormat.md ||
    LocalBookFormat.html ||
    LocalBookFormat.mobi ||
    LocalBookFormat.azw ||
    LocalBookFormat.azw3 => true,
    LocalBookFormat.txt || LocalBookFormat.pdf => false,
  };

  bool get supportsBackgroundIndexOnImport => true;
}

@JsonSerializable()
class LocalBook {
  const LocalBook({
    required this.id,
    required this.title,
    required this.format,
    required this.storagePath,
    required this.fileSize,
    required this.createdAt,
    required this.updatedAt,
    this.sourcePath,
    this.charset,
    this.author,
    this.description,
    this.coverPath,
    this.sourceFileSize,
    this.sourceFileLastModifiedMs,
    this.storageFileLastModifiedMs,
    this.indexStatus = LocalBookIndexStatus.pending,
    this.chapterCount = 0,
    this.lastError,
    this.splitLongChapter = true,
  });

  final String id;
  final String title;
  final LocalBookFormat format;
  final String storagePath;
  final int fileSize;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? sourcePath;
  final String? charset;
  final String? author;
  final String? description;
  final String? coverPath;
  final int? sourceFileSize;
  final int? sourceFileLastModifiedMs;
  final int? storageFileLastModifiedMs;
  final LocalBookIndexStatus indexStatus;
  final int chapterCount;
  final String? lastError;
  final bool splitLongChapter;

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get isReadableReady =>
      indexStatus == LocalBookIndexStatus.ready && chapterCount > 0;

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get needsIndex => !isReadableReady;

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get supportsBootstrapPreview => format.supportsBootstrapPreview;

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get requiresManagedAssetDirectory =>
      format.requiresManagedAssetDirectory;

  LocalBook copyWith({
    String? id,
    String? title,
    LocalBookFormat? format,
    String? storagePath,
    int? fileSize,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? sourcePath,
    bool clearSourcePath = false,
    String? charset,
    bool clearCharset = false,
    String? author,
    bool clearAuthor = false,
    String? description,
    bool clearDescription = false,
    String? coverPath,
    bool clearCoverPath = false,
    int? sourceFileSize,
    bool clearSourceFileSize = false,
    int? sourceFileLastModifiedMs,
    bool clearSourceFileLastModifiedMs = false,
    int? storageFileLastModifiedMs,
    bool clearStorageFileLastModifiedMs = false,
    LocalBookIndexStatus? indexStatus,
    int? chapterCount,
    String? lastError,
    bool clearLastError = false,
    bool? splitLongChapter,
  }) {
    return LocalBook(
      id: id ?? this.id,
      title: title ?? this.title,
      format: format ?? this.format,
      storagePath: storagePath ?? this.storagePath,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sourcePath: clearSourcePath ? null : (sourcePath ?? this.sourcePath),
      charset: clearCharset ? null : (charset ?? this.charset),
      author: clearAuthor ? null : (author ?? this.author),
      description: clearDescription ? null : (description ?? this.description),
      coverPath: clearCoverPath ? null : (coverPath ?? this.coverPath),
      sourceFileSize:
          clearSourceFileSize ? null : (sourceFileSize ?? this.sourceFileSize),
      sourceFileLastModifiedMs:
          clearSourceFileLastModifiedMs
              ? null
              : (sourceFileLastModifiedMs ?? this.sourceFileLastModifiedMs),
      storageFileLastModifiedMs:
          clearStorageFileLastModifiedMs
              ? null
              : (storageFileLastModifiedMs ?? this.storageFileLastModifiedMs),
      indexStatus: indexStatus ?? this.indexStatus,
      chapterCount: chapterCount ?? this.chapterCount,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      splitLongChapter: splitLongChapter ?? this.splitLongChapter,
    );
  }

  Map<String, dynamic> toJson() {
    return _$LocalBookToJson(this);
  }

  factory LocalBook.fromJson(Map<String, dynamic> json) {
    return _$LocalBookFromJson(_normalizeLocalBookJson(json));
  }

  static LocalBookFormat _parseFormat(Object? value) {
    final name = value?.toString().trim();
    return LocalBookFormat.values.firstWhere(
      (item) => item.name == name,
      orElse: () => LocalBookFormat.txt,
    );
  }

  static LocalBookIndexStatus _parseIndexStatus(Object? value) {
    final name = value?.toString().trim();
    return LocalBookIndexStatus.values.firstWhere(
      (item) => item.name == name,
      orElse: () => LocalBookIndexStatus.pending,
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      throw FormatException('Missing required field: $key');
    }
    return value;
  }

  static int _requiredInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) {
        return parsed;
      }
    }
    throw FormatException('Missing required int field: $key');
  }

  static DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
    final raw = json[key]?.toString();
    if (raw == null || raw.trim().isEmpty) {
      throw FormatException('Missing required DateTime field: $key');
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw FormatException('Invalid DateTime field: $key');
    }
    return parsed;
  }

  static String? _optionalString(Object? value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }

    return text;
  }

  static bool? _optionalBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
    return null;
  }

  static int? _optionalInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }
}

Map<String, dynamic> _normalizeLocalBookJson(Map<String, dynamic> json) {
  return <String, dynamic>{
    'id': LocalBook._requiredString(json, 'id'),
    'title': LocalBook._requiredString(json, 'title'),
    'format': LocalBook._parseFormat(json['format']).name,
    'storagePath': LocalBook._requiredString(json, 'storagePath'),
    'fileSize': LocalBook._requiredInt(json, 'fileSize'),
    'createdAt':
        LocalBook._requiredDateTime(json, 'createdAt').toIso8601String(),
    'updatedAt':
        LocalBook._requiredDateTime(json, 'updatedAt').toIso8601String(),
    'sourcePath': LocalBook._optionalString(json['sourcePath']),
    'charset': LocalBook._optionalString(json['charset']),
    'author': LocalBook._optionalString(json['author']),
    'description': LocalBook._optionalString(json['description']),
    'coverPath': LocalBook._optionalString(json['coverPath']),
    'sourceFileSize': LocalBook._optionalInt(json['sourceFileSize']),
    'sourceFileLastModifiedMs': LocalBook._optionalInt(
      json['sourceFileLastModifiedMs'],
    ),
    'storageFileLastModifiedMs': LocalBook._optionalInt(
      json['storageFileLastModifiedMs'],
    ),
    'indexStatus': LocalBook._parseIndexStatus(json['indexStatus']).name,
    'chapterCount': LocalBook._requiredInt(json, 'chapterCount'),
    'lastError': LocalBook._optionalString(json['lastError']),
    'splitLongChapter':
        LocalBook._optionalBool(json['splitLongChapter']) ?? true,
  };
}
