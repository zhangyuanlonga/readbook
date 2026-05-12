import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/navigation/bottom_nav_icon_resolver.dart';
import 'package:shuxiang_reading_next/app/shell_navigation_provider.dart';
import 'package:shuxiang_reading_next/domain/entities/bottom_nav_icon_gallery.dart';

void main() {
  const svgAsset = BottomNavIconAssetRef(
    path: 'assets/icons/custom_bookshelf.svg',
    format: BottomNavIconAssetFormat.svg,
    isAsset: true,
  );

  final gallery = BottomNavIconGallery(
    id: 'gallery_a',
    name: '图集 A',
    createdAt: DateTime.parse('2026-04-10T10:00:00.000Z'),
    updatedAt: DateTime.parse('2026-04-10T10:00:00.000Z'),
    isBuiltIn: false,
    isEditable: true,
    isDeletable: true,
    items: const {
      BottomNavIconGalleryTab.bookshelf: BottomNavIconSet(
        lightUnselected: svgAsset,
      ),
      BottomNavIconGalleryTab.discover: BottomNavIconSet(
        darkSelected: svgAsset,
      ),
    },
  );

  test(
    'standard resolver falls back to destination icons when gallery missing',
    () {
      const destination = AppShellDestination(
        tab: AppShellTab.bookshelf,
        location: '/bookshelf',
        label: '书架',
        icon: Icons.menu_book_outlined,
        selectedIcon: Icons.menu_book_rounded,
      );

      final resolved = resolveStandardBottomNavIcon(
        destination: destination,
        selected: true,
        brightness: Brightness.light,
      );

      expect(resolved.assetRef, isNull);
      expect(resolved.fallbackIcon, Icons.menu_book_rounded);
    },
  );

  test('resolver returns configured asset for matching state', () {
    const destination = AppShellDestination(
      tab: AppShellTab.bookshelf,
      location: '/bookshelf',
      label: '书架',
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book_rounded,
    );

    final resolved = resolveStandardBottomNavIcon(
      destination: destination,
      selected: false,
      brightness: Brightness.light,
      gallery: gallery,
    );

    expect(resolved.assetRef?.path, svgAsset.path);
  });

  test(
    'resolver applies dark-to-light fallback and selected fallback chain',
    () {
      final resolved = resolveCupertinoBottomNavIcon(
        tab: AppShellTab.discover,
        selected: true,
        brightness: Brightness.dark,
        gallery: gallery,
      );

      expect(resolved.assetRef?.path, svgAsset.path);
    },
  );
}
