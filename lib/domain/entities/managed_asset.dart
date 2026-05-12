enum ManagedAssetRoot { documents, support, bundled }

enum ManagedAssetScope {
  appAppearance,
  readerAppearance,
  bookshelfBook,
  readingRecord,
  themeBinding,
  launchImage,
  bottomNav,
  typography,
  localBook,
}

enum ManagedAssetType {
  appBackground,
  readerBackground,
  coverGalleryImage,
  launchImageGalleryImage,
  bottomNavIcon,
  readerFont,
  customBookCover,
  localBookArtifact,
}

class ManagedAssetRef {
  const ManagedAssetRef({
    required this.type,
    required this.scope,
    required this.root,
    required this.relativePath,
    this.collectionId,
    this.assetId,
    this.displayName,
    this.resolvedPath,
  });

  final ManagedAssetType type;
  final ManagedAssetScope scope;
  final ManagedAssetRoot root;
  final String relativePath;
  final String? collectionId;
  final String? assetId;
  final String? displayName;
  final String? resolvedPath;

  String get normalizedRelativePath => relativePath.trim().replaceAll('\\', '/');
  String? get normalizedResolvedPath => resolvedPath?.trim().replaceAll('\\', '/');

  bool get belongsToCollection =>
      collectionId?.trim().isNotEmpty == true;

  String get bindingKey {
    final normalizedCollectionId = collectionId?.trim() ?? '';
    final normalizedAssetId = assetId?.trim() ?? '';
    return '${scope.name}:${type.name}:${normalizedCollectionId.isEmpty ? "-" : normalizedCollectionId}:${normalizedAssetId.isEmpty ? normalizedRelativePath : normalizedAssetId}';
  }

  ManagedAssetRef copyWith({
    ManagedAssetType? type,
    ManagedAssetScope? scope,
    ManagedAssetRoot? root,
    String? relativePath,
    String? collectionId,
    bool clearCollectionId = false,
    String? assetId,
    bool clearAssetId = false,
    String? displayName,
    bool clearDisplayName = false,
    String? resolvedPath,
    bool clearResolvedPath = false,
  }) {
    return ManagedAssetRef(
      type: type ?? this.type,
      scope: scope ?? this.scope,
      root: root ?? this.root,
      relativePath: relativePath ?? this.relativePath,
      collectionId:
          clearCollectionId ? null : (collectionId ?? this.collectionId),
      assetId: clearAssetId ? null : (assetId ?? this.assetId),
      displayName: clearDisplayName ? null : (displayName ?? this.displayName),
      resolvedPath:
          clearResolvedPath ? null : (resolvedPath ?? this.resolvedPath),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'scope': scope.name,
      'root': root.name,
      'relativePath': relativePath,
      if (collectionId != null && collectionId!.trim().isNotEmpty)
        'collectionId': collectionId,
      if (assetId != null && assetId!.trim().isNotEmpty) 'assetId': assetId,
      if (displayName != null && displayName!.trim().isNotEmpty)
        'displayName': displayName,
    };
  }

  factory ManagedAssetRef.fromJson(Map<String, dynamic> json) {
    final type = ManagedAssetType.values.firstWhere(
      (item) => item.name == json['type']?.toString().trim(),
      orElse: () => throw const FormatException('Invalid managed asset type.'),
    );
    final scope = ManagedAssetScope.values.firstWhere(
      (item) => item.name == json['scope']?.toString().trim(),
      orElse: () => throw const FormatException('Invalid managed asset scope.'),
    );
    final root = ManagedAssetRoot.values.firstWhere(
      (item) => item.name == json['root']?.toString().trim(),
      orElse: () => throw const FormatException('Invalid managed asset root.'),
    );
    final relativePath = json['relativePath']?.toString().trim() ?? '';
    if (relativePath.isEmpty) {
      throw const FormatException('Missing managed asset relative path.');
    }
    return ManagedAssetRef(
      type: type,
      scope: scope,
      root: root,
      relativePath: relativePath,
      collectionId: _readNullableString(json['collectionId']),
      assetId: _readNullableString(json['assetId']),
      displayName: _readNullableString(json['displayName']),
    );
  }

  static String? _readNullableString(Object? value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}

class ManagedAssetCollection {
  const ManagedAssetCollection({
    required this.id,
    required this.type,
    required this.scope,
    required this.displayName,
    this.assetRefs = const <ManagedAssetRef>[],
  });

  final String id;
  final ManagedAssetType type;
  final ManagedAssetScope scope;
  final String displayName;
  final List<ManagedAssetRef> assetRefs;

  ManagedAssetCollection copyWith({
    String? id,
    ManagedAssetType? type,
    ManagedAssetScope? scope,
    String? displayName,
    List<ManagedAssetRef>? assetRefs,
  }) {
    return ManagedAssetCollection(
      id: id ?? this.id,
      type: type ?? this.type,
      scope: scope ?? this.scope,
      displayName: displayName ?? this.displayName,
      assetRefs: assetRefs ?? this.assetRefs,
    );
  }
}
