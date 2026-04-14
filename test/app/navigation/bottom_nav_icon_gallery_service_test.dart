import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/app/navigation/bottom_nav_icon_gallery_defaults.dart';
import 'package:shuxiang_reading_next/app/navigation/bottom_nav_icon_gallery_service.dart';
import 'package:shuxiang_reading_next/app/navigation/bottom_nav_icon_gallery_tab_mapper.dart';
import 'package:shuxiang_reading_next/app/shell_navigation_provider.dart';
import 'package:shuxiang_reading_next/domain/entities/bottom_nav_icon_gallery.dart';

void main() {
  group('BottomNavIconGalleryService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('persists galleries and active gallery id', () async {
      final service = BottomNavIconGalleryService();
      final gallery = BottomNavIconGallery(
        id: 'gallery_custom',
        name: '自定义图集',
        createdAt: DateTime.parse('2026-04-10T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-04-10T11:00:00.000Z'),
        isBuiltIn: false,
        isEditable: true,
        isDeletable: true,
        items: const {BottomNavIconGalleryTab.bookshelf: BottomNavIconSet()},
      );

      await service.saveGalleries([gallery]);
      await service.saveActiveGalleryId(gallery.id);

      final galleries = await service.loadGalleries();
      final activeId = await service.loadActiveGalleryId();
      final activeGallery = await service.loadActiveGallery();

      expect(galleries, hasLength(2));
      expect(
        galleries.any((item) => item.id == defaultBottomNavIconGalleryId),
        isTrue,
      );
      expect(galleries.any((item) => item.id == gallery.id), isTrue);
      expect(activeId, gallery.id);
      expect(activeGallery?.name, gallery.name);
    });

    test('clears active gallery id when saving empty value', () async {
      final service = BottomNavIconGalleryService();

      await service.saveActiveGalleryId('gallery_a');
      await service.saveActiveGalleryId(null);

      expect(await service.loadActiveGalleryId(), isNull);
    });

    test('creates, renames, duplicates and deletes custom galleries', () async {
      final service = BottomNavIconGalleryService();

      final created = await service.createGallery(name: '新图集');
      expect(created.name, '新图集');
      expect(created.isBuiltIn, isFalse);

      await service.renameGallery(galleryId: created.id, name: '重命名图集');
      final renamed = (await service.loadGalleries()).firstWhere(
        (item) => item.id == created.id,
      );
      expect(renamed.name, '重命名图集');

      final duplicated = await service.duplicateGallery(
        sourceGalleryId: created.id,
        name: '重命名图集 副本',
      );
      expect(duplicated.id, isNot(created.id));

      final galleriesAfterDuplicate = await service.loadGalleries();
      expect(galleriesAfterDuplicate.any((item) => item.id == duplicated.id), isTrue);

      await service.saveActiveGalleryId(duplicated.id);
      await service.deleteGallery(duplicated.id);

      final galleriesAfterDelete = await service.loadGalleries();
      expect(galleriesAfterDelete.any((item) => item.id == duplicated.id), isFalse);
      expect(
        await service.loadActiveGalleryId(),
        defaultBottomNavIconGalleryId,
      );
    });
  });

  group('BottomNavIconGallery tab mapper', () {
    test('maps shell tabs to gallery tabs and back', () {
      expect(
        bottomNavIconGalleryTabForShellTab(AppShellTab.bookshelf),
        BottomNavIconGalleryTab.bookshelf,
      );
      expect(
        appShellTabForBottomNavIconGalleryTab(BottomNavIconGalleryTab.stats),
        AppShellTab.stats,
      );
      expect(bottomNavIconGalleryTabs, hasLength(4));
    });
  });
}
