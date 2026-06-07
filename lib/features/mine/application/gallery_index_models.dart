import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../domain/entities/bottom_nav_icon_gallery.dart';

part 'gallery_index_models.freezed.dart';
part 'gallery_index_models.g.dart';

@freezed
abstract class CoverGalleryIndexItem with _$CoverGalleryIndexItem {
  const factory CoverGalleryIndexItem({
    required String id,
    required String name,
    required DateTime updatedAt,
    required int imageCount,
    String? previewPath,
  }) = _CoverGalleryIndexItem;

  factory CoverGalleryIndexItem.fromJson(Map<String, dynamic> json) =>
      _$CoverGalleryIndexItemFromJson(json);
}

@freezed
abstract class LaunchImageGalleryIndexItem with _$LaunchImageGalleryIndexItem {
  const factory LaunchImageGalleryIndexItem({
    required String id,
    required String name,
    required DateTime updatedAt,
    required int imageCount,
    required bool isBuiltIn,
    required bool isEditable,
    required bool isDeletable,
    String? previewPath,
  }) = _LaunchImageGalleryIndexItem;

  factory LaunchImageGalleryIndexItem.fromJson(Map<String, dynamic> json) =>
      _$LaunchImageGalleryIndexItemFromJson(json);
}

@freezed
abstract class BottomNavIconGalleryIndexItem
    with _$BottomNavIconGalleryIndexItem {
  const factory BottomNavIconGalleryIndexItem({
    required String id,
    required String name,
    required DateTime updatedAt,
    required bool isBuiltIn,
    required bool isEditable,
    required bool isDeletable,
    @JsonKey(
      fromJson: _bottomNavPreviewItemsFromJson,
      toJson: _bottomNavPreviewItemsToJson,
    )
    required Map<BottomNavIconGalleryTab, BottomNavIconSet> previewItems,
  }) = _BottomNavIconGalleryIndexItem;

  factory BottomNavIconGalleryIndexItem.fromGallery(
    BottomNavIconGallery gallery,
  ) {
    final previewItems = <BottomNavIconGalleryTab, BottomNavIconSet>{};
    for (final tab in BottomNavIconGalleryTab.values) {
      previewItems[tab] = gallery.items[tab] ?? const BottomNavIconSet();
    }
    return BottomNavIconGalleryIndexItem(
      id: gallery.id,
      name: gallery.name,
      updatedAt: gallery.updatedAt,
      isBuiltIn: gallery.isBuiltIn,
      isEditable: gallery.isEditable,
      isDeletable: gallery.isDeletable,
      previewItems: Map<BottomNavIconGalleryTab, BottomNavIconSet>.unmodifiable(
        previewItems,
      ),
    );
  }

  factory BottomNavIconGalleryIndexItem.fromJson(Map<String, dynamic> json) =>
      _$BottomNavIconGalleryIndexItemFromJson(json);
}

Map<BottomNavIconGalleryTab, BottomNavIconSet> _bottomNavPreviewItemsFromJson(
  Object? value,
) {
  if (value is! Map) {
    return const <BottomNavIconGalleryTab, BottomNavIconSet>{};
  }
  final items = <BottomNavIconGalleryTab, BottomNavIconSet>{};
  for (final entry in value.entries) {
    final tab = switch (entry.key.toString().trim()) {
      'bookshelf' => BottomNavIconGalleryTab.bookshelf,
      'discover' => BottomNavIconGalleryTab.discover,
      'stats' => BottomNavIconGalleryTab.stats,
      'mine' => BottomNavIconGalleryTab.mine,
      _ => null,
    };
    if (tab == null || entry.value is! Map) {
      continue;
    }
    items[tab] = BottomNavIconSet.fromJson(
      (entry.value as Map).map(
        (key, nestedValue) => MapEntry(key.toString(), nestedValue),
      ),
    );
  }
  return Map<BottomNavIconGalleryTab, BottomNavIconSet>.unmodifiable(items);
}

Map<String, dynamic> _bottomNavPreviewItemsToJson(
  Map<BottomNavIconGalleryTab, BottomNavIconSet> value,
) {
  return <String, dynamic>{
    for (final entry in value.entries) entry.key.name: entry.value.toJson(),
  };
}
