enum LocalBookFormat { txt, epub }

enum LocalBookIndexStatus { pending, indexing, ready, failed }

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
    this.author,
    this.coverPath,
    this.indexStatus = LocalBookIndexStatus.pending,
    this.chapterCount = 0,
    this.lastError,
    this.txtTocRuleName,
    this.txtTocRulePattern,
    this.splitLongChapter = false,
  });

  final String id;
  final String title;
  final LocalBookFormat format;
  final String storagePath;
  final int fileSize;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? sourcePath;
  final String? author;
  final String? coverPath;
  final LocalBookIndexStatus indexStatus;
  final int chapterCount;
  final String? lastError;
  final String? txtTocRuleName;
  final String? txtTocRulePattern;
  final bool splitLongChapter;

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
    String? author,
    bool clearAuthor = false,
    String? coverPath,
    bool clearCoverPath = false,
    LocalBookIndexStatus? indexStatus,
    int? chapterCount,
    String? lastError,
    bool clearLastError = false,
    String? txtTocRuleName,
    bool clearTxtTocRuleName = false,
    String? txtTocRulePattern,
    bool clearTxtTocRulePattern = false,
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
      author: clearAuthor ? null : (author ?? this.author),
      coverPath: clearCoverPath ? null : (coverPath ?? this.coverPath),
      indexStatus: indexStatus ?? this.indexStatus,
      chapterCount: chapterCount ?? this.chapterCount,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      txtTocRuleName:
          clearTxtTocRuleName ? null : (txtTocRuleName ?? this.txtTocRuleName),
      txtTocRulePattern:
          clearTxtTocRulePattern
              ? null
              : (txtTocRulePattern ?? this.txtTocRulePattern),
      splitLongChapter: splitLongChapter ?? this.splitLongChapter,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'format': format.name,
      'storagePath': storagePath,
      'fileSize': fileSize,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'sourcePath': sourcePath,
      'author': author,
      'coverPath': coverPath,
      'indexStatus': indexStatus.name,
      'chapterCount': chapterCount,
      'lastError': lastError,
      'txtTocRuleName': txtTocRuleName,
      'txtTocRulePattern': txtTocRulePattern,
      'splitLongChapter': splitLongChapter,
    };
  }

  factory LocalBook.fromJson(Map<String, dynamic> json) {
    return LocalBook(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      format: _parseFormat(json['format']),
      storagePath: _requiredString(json, 'storagePath'),
      fileSize: _requiredInt(json, 'fileSize'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
      sourcePath: _optionalString(json['sourcePath']),
      author: _optionalString(json['author']),
      coverPath: _optionalString(json['coverPath']),
      indexStatus: _parseIndexStatus(json['indexStatus']),
      chapterCount: _requiredInt(json, 'chapterCount'),
      lastError: _optionalString(json['lastError']),
      txtTocRuleName: _optionalString(json['txtTocRuleName']),
      txtTocRulePattern: _optionalString(json['txtTocRulePattern']),
      splitLongChapter: _optionalBool(json['splitLongChapter']) ?? false,
    );
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
}
