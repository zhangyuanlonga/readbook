import 'package:flutter/cupertino.dart';

import '../../domain/entities/bottom_nav_icon_gallery.dart';
import '../shell_navigation_provider.dart';
import 'bottom_nav_icon_gallery_tab_mapper.dart';

class ResolvedBottomNavIcon {
  const ResolvedBottomNavIcon({required this.fallbackIcon, this.assetRef});

  final IconData fallbackIcon;
  final BottomNavIconAssetRef? assetRef;
}

ResolvedBottomNavIcon resolveStandardBottomNavIcon({
  required AppShellDestination destination,
  required bool selected,
  required Brightness brightness,
  BottomNavIconGallery? gallery,
}) {
  final assetRef = _resolveGalleryAsset(
    gallery: gallery,
    tab: bottomNavIconGalleryTabForShellTab(destination.tab),
    selected: selected,
    brightness: brightness,
  );

  return ResolvedBottomNavIcon(
    fallbackIcon: selected ? destination.selectedIcon : destination.icon,
    assetRef: assetRef,
  );
}

ResolvedBottomNavIcon resolveCupertinoBottomNavIcon({
  required AppShellTab tab,
  required bool selected,
  required Brightness brightness,
  BottomNavIconGallery? gallery,
}) {
  final assetRef = _resolveGalleryAsset(
    gallery: gallery,
    tab: bottomNavIconGalleryTabForShellTab(tab),
    selected: selected,
    brightness: brightness,
  );

  return ResolvedBottomNavIcon(
    fallbackIcon: _cupertinoFallbackIconFor(tab, selected: selected),
    assetRef: assetRef,
  );
}

BottomNavIconAssetRef? _resolveGalleryAsset({
  required BottomNavIconGallery? gallery,
  required BottomNavIconGalleryTab tab,
  required bool selected,
  required Brightness brightness,
}) {
  final iconSet = gallery?.items[tab];
  if (iconSet == null) {
    return null;
  }

  final candidates = switch ((brightness, selected)) {
    (Brightness.light, false) => [
      iconSet.lightUnselected,
      iconSet.darkUnselected,
      iconSet.lightSelected,
      iconSet.darkSelected,
    ],
    (Brightness.light, true) => [
      iconSet.lightSelected,
      iconSet.lightUnselected,
      iconSet.darkSelected,
      iconSet.darkUnselected,
    ],
    (Brightness.dark, false) => [
      iconSet.darkUnselected,
      iconSet.lightUnselected,
      iconSet.darkSelected,
      iconSet.lightSelected,
    ],
    (Brightness.dark, true) => [
      iconSet.darkSelected,
      iconSet.lightSelected,
      iconSet.darkUnselected,
      iconSet.lightUnselected,
    ],
  };

  for (final candidate in candidates) {
    if (candidate != null) {
      return candidate;
    }
  }
  return null;
}

IconData _cupertinoFallbackIconFor(AppShellTab tab, {required bool selected}) {
  return switch (tab) {
    AppShellTab.bookshelf =>
      selected ? CupertinoIcons.book_fill : CupertinoIcons.book,
    AppShellTab.discover =>
      selected ? CupertinoIcons.compass_fill : CupertinoIcons.compass,
    AppShellTab.stats =>
      selected ? CupertinoIcons.chart_bar_fill : CupertinoIcons.chart_bar,
    AppShellTab.mine =>
      selected ? CupertinoIcons.person_fill : CupertinoIcons.person,
  };
}
