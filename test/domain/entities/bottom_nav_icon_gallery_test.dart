import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/bottom_nav_icon_gallery.dart';

void main() {
  test('serializes and deserializes bottom nav icon gallery', () {
    final createdAt = DateTime.parse('2026-04-10T10:00:00.000Z');
    final updatedAt = DateTime.parse('2026-04-10T11:00:00.000Z');
    const asset = BottomNavIconAssetRef(
      path: 'assets/icons/bookshelf_light.svg',
      format: BottomNavIconAssetFormat.svg,
      isAsset: true,
    );
    final gallery = BottomNavIconGallery(
      id: 'gallery_default',
      name: '默认图集',
      createdAt: createdAt,
      updatedAt: updatedAt,
      isBuiltIn: true,
      isEditable: false,
      isDeletable: false,
      items: const {
        BottomNavIconGalleryTab.bookshelf: BottomNavIconSet(
          lightUnselected: asset,
          lightSelected: asset,
        ),
        BottomNavIconGalleryTab.discover: BottomNavIconSet(
          darkUnselected: asset,
        ),
      },
    );

    final restored = BottomNavIconGallery.fromJson(gallery.toJson());

    expect(restored.id, gallery.id);
    expect(restored.name, gallery.name);
    expect(restored.createdAt, createdAt);
    expect(restored.updatedAt, updatedAt);
    expect(restored.isBuiltIn, isTrue);
    expect(restored.isEditable, isFalse);
    expect(restored.isDeletable, isFalse);
    expect(
      restored.items[BottomNavIconGalleryTab.bookshelf]?.lightUnselected?.path,
      asset.path,
    );
    expect(
      restored.items[BottomNavIconGalleryTab.discover]?.darkUnselected?.format,
      BottomNavIconAssetFormat.svg,
    );
  });

  test('throws when required gallery fields are missing', () {
    expect(
      () => BottomNavIconGallery.fromJson(const <String, dynamic>{}),
      throwsFormatException,
    );
  });
}
