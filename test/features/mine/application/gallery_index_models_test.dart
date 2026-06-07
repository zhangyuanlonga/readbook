import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/bottom_nav_icon_gallery.dart';
import 'package:shuxiang_reading_next/features/mine/application/gallery_index_models.dart';

void main() {
  group('gallery index models', () {
    test('cover gallery index supports json round trip and copyWith', () {
      final updatedAt = DateTime.parse('2026-06-07T10:00:00.000Z');
      final item = CoverGalleryIndexItem(
        id: 'cover_gallery_a',
        name: '封面图集',
        updatedAt: updatedAt,
        imageCount: 3,
        previewPath: '/tmp/cover.png',
      );

      final restored = CoverGalleryIndexItem.fromJson(item.toJson());

      expect(restored, item);
      expect(restored.copyWith(imageCount: 4).imageCount, 4);
    });

    test('launch gallery index preserves capability flags', () {
      final item = LaunchImageGalleryIndexItem.fromJson({
        'id': 'launch_gallery_a',
        'name': '启动图集',
        'updatedAt': '2026-06-07T10:00:00.000Z',
        'imageCount': 1,
        'isBuiltIn': true,
        'isEditable': false,
        'isDeletable': false,
      });

      expect(item.isBuiltIn, isTrue);
      expect(item.isEditable, isFalse);
      expect(item.isDeletable, isFalse);
      expect(item.previewPath, isNull);
    });

    test('bottom nav index can be built from gallery and serialized', () {
      final updatedAt = DateTime.parse('2026-06-07T10:00:00.000Z');
      const asset = BottomNavIconAssetRef(
        path: 'assets/icons/bookshelf.svg',
        format: BottomNavIconAssetFormat.svg,
        isAsset: true,
      );
      final gallery = BottomNavIconGallery(
        id: 'bottom_nav_gallery_a',
        name: '底栏图标',
        createdAt: updatedAt,
        updatedAt: updatedAt,
        isBuiltIn: false,
        isEditable: true,
        isDeletable: true,
        items: const {
          BottomNavIconGalleryTab.bookshelf: BottomNavIconSet(
            lightSelected: asset,
          ),
        },
      );

      final item = BottomNavIconGalleryIndexItem.fromGallery(gallery);
      final restored = BottomNavIconGalleryIndexItem.fromJson(item.toJson());

      expect(restored.id, gallery.id);
      final restoredAsset =
          restored
              .previewItems[BottomNavIconGalleryTab.bookshelf]
              ?.lightSelected;
      expect(restoredAsset?.path, asset.path);
      expect(restoredAsset?.format, asset.format);
      expect(restoredAsset?.isAsset, asset.isAsset);
      final discoverSet =
          restored.previewItems[BottomNavIconGalleryTab.discover];
      expect(discoverSet?.lightUnselected, isNull);
      expect(discoverSet?.lightSelected, isNull);
      expect(discoverSet?.darkUnselected, isNull);
      expect(discoverSet?.darkSelected, isNull);
    });
  });
}
