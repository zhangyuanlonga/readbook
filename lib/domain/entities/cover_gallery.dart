class CoverGallery {
  const CoverGallery({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.imagePaths,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> imagePaths;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'imagePaths': imagePaths,
    };
  }

  factory CoverGallery.fromJson(Map<String, dynamic> json) {
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

    return CoverGallery(
      id: rawId,
      name: rawName,
      createdAt: _readDateTime(json, 'createdAt'),
      updatedAt: _readDateTime(json, 'updatedAt'),
      imagePaths: imagePaths,
    );
  }

  CoverGallery copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? imagePaths,
  }) {
    return CoverGallery(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imagePaths: imagePaths ?? this.imagePaths,
    );
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
