// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'managed_asset.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ManagedAssetRef _$ManagedAssetRefFromJson(Map<String, dynamic> json) =>
    ManagedAssetRef(
      type: ManagedAssetRef._managedAssetTypeFromJson(json['type']),
      scope: ManagedAssetRef._managedAssetScopeFromJson(json['scope']),
      root: ManagedAssetRef._managedAssetRootFromJson(json['root']),
      relativePath: ManagedAssetRef._requiredRelativePath(json['relativePath']),
      collectionId: ManagedAssetRef._readNullableString(json['collectionId']),
      assetId: ManagedAssetRef._readNullableString(json['assetId']),
      displayName: ManagedAssetRef._readNullableString(json['displayName']),
    );

Map<String, dynamic> _$ManagedAssetRefToJson(
  ManagedAssetRef instance,
) => <String, dynamic>{
  'type': _$ManagedAssetTypeEnumMap[instance.type]!,
  'scope': _$ManagedAssetScopeEnumMap[instance.scope]!,
  'root': _$ManagedAssetRootEnumMap[instance.root]!,
  'relativePath': ManagedAssetRef._normalizePath(instance.relativePath),
  'collectionId': ManagedAssetRef._writeNullableString(instance.collectionId),
  'assetId': ManagedAssetRef._writeNullableString(instance.assetId),
  'displayName': ManagedAssetRef._writeNullableString(instance.displayName),
};

const _$ManagedAssetTypeEnumMap = {
  ManagedAssetType.appBackground: 'appBackground',
  ManagedAssetType.readerBackground: 'readerBackground',
  ManagedAssetType.coverGalleryImage: 'coverGalleryImage',
  ManagedAssetType.launchImageGalleryImage: 'launchImageGalleryImage',
  ManagedAssetType.bottomNavIcon: 'bottomNavIcon',
  ManagedAssetType.readerFont: 'readerFont',
  ManagedAssetType.customBookCover: 'customBookCover',
  ManagedAssetType.localBookArtifact: 'localBookArtifact',
  ManagedAssetType.profileAvatar: 'profileAvatar',
};

const _$ManagedAssetScopeEnumMap = {
  ManagedAssetScope.appAppearance: 'appAppearance',
  ManagedAssetScope.readerAppearance: 'readerAppearance',
  ManagedAssetScope.bookshelfBook: 'bookshelfBook',
  ManagedAssetScope.readingRecord: 'readingRecord',
  ManagedAssetScope.themeBinding: 'themeBinding',
  ManagedAssetScope.launchImage: 'launchImage',
  ManagedAssetScope.bottomNav: 'bottomNav',
  ManagedAssetScope.typography: 'typography',
  ManagedAssetScope.localBook: 'localBook',
  ManagedAssetScope.userProfile: 'userProfile',
};

const _$ManagedAssetRootEnumMap = {
  ManagedAssetRoot.documents: 'documents',
  ManagedAssetRoot.support: 'support',
  ManagedAssetRoot.bundled: 'bundled',
};

ManagedAssetCollection _$ManagedAssetCollectionFromJson(
  Map<String, dynamic> json,
) => ManagedAssetCollection(
  id: ManagedAssetRef._requiredRelativePath(json['id']),
  type: ManagedAssetRef._managedAssetTypeFromJson(json['type']),
  scope: ManagedAssetRef._managedAssetScopeFromJson(json['scope']),
  displayName: ManagedAssetRef._requiredRelativePath(json['displayName']),
  assetRefs:
      (json['assetRefs'] as List<dynamic>?)
          ?.map((e) => ManagedAssetRef.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <ManagedAssetRef>[],
);

Map<String, dynamic> _$ManagedAssetCollectionToJson(
  ManagedAssetCollection instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': _$ManagedAssetTypeEnumMap[instance.type]!,
  'scope': _$ManagedAssetScopeEnumMap[instance.scope]!,
  'displayName': instance.displayName,
  'assetRefs': instance.assetRefs.map((e) => e.toJson()).toList(),
};
