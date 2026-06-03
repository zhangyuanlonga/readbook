import 'package:json_annotation/json_annotation.dart';

part 'launch_image_gallery.g.dart';

@JsonSerializable()
class LaunchImageGallery {
  const LaunchImageGallery({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.imagePaths,
    this.isBuiltIn = false,
    this.isEditable = true,
    this.isDeletable = true,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> imagePaths;
  final bool isBuiltIn;
  final bool isEditable;
  final bool isDeletable;

  Map<String, dynamic> toJson() {
    return _$LaunchImageGalleryToJson(this);
  }

  factory LaunchImageGallery.fromJson(Map<String, dynamic> json) {
    return _$LaunchImageGalleryFromJson(_normalizeLaunchImageGalleryJson(json));
  }

  LaunchImageGallery copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? imagePaths,
    bool? isBuiltIn,
    bool? isEditable,
    bool? isDeletable,
  }) {
    return LaunchImageGallery(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imagePaths: imagePaths ?? this.imagePaths,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      isEditable: isEditable ?? this.isEditable,
      isDeletable: isDeletable ?? this.isDeletable,
    );
  }

  static bool? _readBool(Map<String, dynamic> json, String key) {
    final raw = json[key];
    if (raw == null) {
      return null;
    }
    if (raw is bool) {
      return raw;
    }
    final normalized = raw.toString().trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
    return null;
  }

  static DateTime _readDateTime(Map<String, dynamic> json, String key) {
    final raw = json[key]?.toString().trim() ?? '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw FormatException('Invalid required field: $key');
    }
    return parsed;
  }
}

Map<String, dynamic> _normalizeLaunchImageGalleryJson(
  Map<String, dynamic> json,
) {
  final rawId = json['id']?.toString().trim() ?? '';
  if (rawId.isEmpty) {
    throw const FormatException('Missing required field: id');
  }
  final rawName = json['name']?.toString().trim() ?? '';
  if (rawName.isEmpty) {
    throw const FormatException('Missing required field: name');
  }
  final rawPaths = json['imagePaths'];
  final imagePaths =
      rawPaths is List
          ? rawPaths
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false)
          : const <String>[];

  return <String, dynamic>{
    'id': rawId,
    'name': rawName,
    'createdAt':
        LaunchImageGallery._readDateTime(json, 'createdAt').toIso8601String(),
    'updatedAt':
        LaunchImageGallery._readDateTime(json, 'updatedAt').toIso8601String(),
    'imagePaths': imagePaths,
    'isBuiltIn': LaunchImageGallery._readBool(json, 'isBuiltIn') ?? false,
    'isEditable': LaunchImageGallery._readBool(json, 'isEditable') ?? true,
    'isDeletable': LaunchImageGallery._readBool(json, 'isDeletable') ?? true,
  };
}
