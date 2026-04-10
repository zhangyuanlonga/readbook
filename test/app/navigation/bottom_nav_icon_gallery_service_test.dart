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
