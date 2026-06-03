import 'package:json_annotation/json_annotation.dart';

part 'managed_asset.g.dart';

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

@JsonSerializable()
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

  @JsonKey(fromJson: _managedAssetTypeFromJson)
  final ManagedAssetType type;
  @JsonKey(fromJson: _managedAssetScopeFromJson)
  final ManagedAssetScope scope;
  @JsonKey(fromJson: _managedAssetRootFromJson)
  final ManagedAssetRoot root;
  @JsonKey(fromJson: _requiredRelativePath, toJson: _normalizePath)
  final String relativePath;
  @JsonKey(fromJson: _readNullableString, toJson: _writeNullableString)
  final String? collectionId;
  @JsonKey(fromJson: _readNullableString, toJson: _writeNullableString)
  final String? assetId;
  @JsonKey(fromJson: _readNullableString, toJson: _writeNullableString)
  final String? displayName;
  @JsonKey(includeFromJson: false, includeToJson: false)
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
    final json = _$ManagedAssetRefToJson(this);
    json.removeWhere((key, value) => value == null);
    return json;
  }

  factory ManagedAssetRef.fromJson(Map<String, dynamic> json) =>
      _$ManagedAssetRefFromJson(json);

  static String? _readNullableString(Object? value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static ManagedAssetType _managedAssetTypeFromJson(Object? value) {
    return ManagedAssetType.values.firstWhere(
      (item) => item.name == value?.toString().trim(),
      orElse: () => throw const FormatException('Invalid managed asset type.'),
    );
  }

  static ManagedAssetScope _managedAssetScopeFromJson(Object? value) {
    return ManagedAssetScope.values.firstWhere(
      (item) => item.name == value?.toString().trim(),
      orElse: () => throw const FormatException('Invalid managed asset scope.'),
    );
  }

  static ManagedAssetRoot _managedAssetRootFromJson(Object? value) {
    return ManagedAssetRoot.values.firstWhere(
      (item) => item.name == value?.toString().trim(),
      orElse: () => throw const FormatException('Invalid managed asset root.'),
    );
  }

  static String _requiredRelativePath(Object? value) {
    final normalized = value?.toString().trim().replaceAll('\\', '/') ?? '';
    if (normalized.isEmpty) {
      throw const FormatException('Missing managed asset relative path.');
    }
    return normalized;
  }

  static String _normalizePath(String value) {
    return value.trim().replaceAll('\\', '/');
  }

  static String? _writeNullableString(String? value) {
    final normalized = _readNullableString(value);
    return normalized;
  }
}

@JsonSerializable(explicitToJson: true)
class ManagedAssetCollection {
  const ManagedAssetCollection({
    required this.id,
    required this.type,
    required this.scope,
    required this.displayName,
    this.assetRefs = const <ManagedAssetRef>[],
  });

  @JsonKey(fromJson: ManagedAssetRef._requiredRelativePath)
  final String id;
  @JsonKey(fromJson: ManagedAssetRef._managedAssetTypeFromJson)
  final ManagedAssetType type;
  @JsonKey(fromJson: ManagedAssetRef._managedAssetScopeFromJson)
  final ManagedAssetScope scope;
  @JsonKey(fromJson: ManagedAssetRef._requiredRelativePath)
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

  Map<String, dynamic> toJson() {
    final json = _$ManagedAssetCollectionToJson(this);
    json.removeWhere((key, value) => value == null);
    return json;
  }

  factory ManagedAssetCollection.fromJson(Map<String, dynamic> json) =>
      _$ManagedAssetCollectionFromJson(json);
}
