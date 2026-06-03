import 'package:json_annotation/json_annotation.dart';

part 'book_metadata_override.g.dart';

@JsonSerializable()
class BookMetadataOverride {
  const BookMetadataOverride({
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

  factory BookMetadataOverride.forLocal({
    required String bookId,
    String? title,
    String? author,
    String? intro,
    String? coverPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final normalizedBookId = bookId.trim();
    final now = DateTime.now();
    return BookMetadataOverride(
      targetKey: localTargetKey(normalizedBookId),
      bookId: normalizedBookId,
      title: _normalizeOptional(title),
      author: _normalizeOptional(author),
      intro: _normalizeOptional(intro),
      coverPath: _normalizeOptional(coverPath),
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
    );
  }

  factory BookMetadataOverride.forRemote({
    required String sourceId,
    required String detailUrl,
    String? title,
    String? author,
    String? intro,
    String? coverPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final normalizedSourceId = sourceId.trim();
    final normalizedDetailUrl = detailUrl.trim();
    final now = DateTime.now();
    return BookMetadataOverride(
      targetKey: remoteTargetKey(
        sourceId: normalizedSourceId,
        detailUrl: normalizedDetailUrl,
      ),
      sourceId: normalizedSourceId,
      detailUrl: normalizedDetailUrl,
      title: _normalizeOptional(title),
      author: _normalizeOptional(author),
      intro: _normalizeOptional(intro),
      coverPath: _normalizeOptional(coverPath),
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
    );
  }

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

  bool get isLocalScope => (bookId?.trim().isNotEmpty ?? false);

  BookMetadataOverride copyWith({
    String? targetKey,
    String? bookId,
    String? sourceId,
    String? detailUrl,
    String? title,
    bool clearTitle = false,
    String? author,
    bool clearAuthor = false,
    String? intro,
    bool clearIntro = false,
    String? coverPath,
    bool clearCoverPath = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BookMetadataOverride(
      targetKey: targetKey ?? this.targetKey,
      bookId: bookId ?? this.bookId,
      sourceId: sourceId ?? this.sourceId,
      detailUrl: detailUrl ?? this.detailUrl,
      title: clearTitle ? null : (_normalizeOptional(title) ?? this.title),
      author: clearAuthor ? null : (_normalizeOptional(author) ?? this.author),
      intro: clearIntro ? null : (_normalizeOptional(intro) ?? this.intro),
      coverPath:
          clearCoverPath
              ? null
              : (_normalizeOptional(coverPath) ?? this.coverPath),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => _$BookMetadataOverrideToJson(this);

  factory BookMetadataOverride.fromJson(Map<String, dynamic> json) =>
      _$BookMetadataOverrideFromJson(_normalizeBookMetadataOverrideJson(json));

  static String localTargetKey(String bookId) => 'local::${bookId.trim()}';

  static String remoteTargetKey({
    required String sourceId,
    required String detailUrl,
  }) {
    return 'remote::${sourceId.trim()}::${detailUrl.trim()}';
  }

  static String? _normalizeOptional(String? value) {
    final normalized = (value ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }
}

Map<String, dynamic> _normalizeBookMetadataOverrideJson(
  Map<String, dynamic> json,
) {
  final targetKey = json['targetKey']?.toString().trim() ?? '';
  if (targetKey.isEmpty) {
    throw const FormatException('Missing required field: targetKey');
  }
  final createdAtRaw = json['createdAt']?.toString().trim() ?? '';
  final updatedAtRaw = json['updatedAt']?.toString().trim() ?? '';
  final createdAt = DateTime.tryParse(createdAtRaw);
  final updatedAt = DateTime.tryParse(updatedAtRaw);
  if (createdAt == null) {
    throw const FormatException('Missing required datetime field: createdAt');
  }
  if (updatedAt == null) {
    throw const FormatException('Missing required datetime field: updatedAt');
  }

  return <String, dynamic>{
    'targetKey': targetKey,
    'bookId': BookMetadataOverride._normalizeOptional(
      json['bookId']?.toString(),
    ),
    'sourceId': BookMetadataOverride._normalizeOptional(
      json['sourceId']?.toString(),
    ),
    'detailUrl': BookMetadataOverride._normalizeOptional(
      json['detailUrl']?.toString(),
    ),
    'title': BookMetadataOverride._normalizeOptional(json['title']?.toString()),
    'author': BookMetadataOverride._normalizeOptional(
      json['author']?.toString(),
    ),
    'intro': BookMetadataOverride._normalizeOptional(json['intro']?.toString()),
    'coverPath': BookMetadataOverride._normalizeOptional(
      json['coverPath']?.toString(),
    ),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
