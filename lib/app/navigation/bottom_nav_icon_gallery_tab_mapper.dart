import '../../domain/entities/bottom_nav_icon_gallery.dart';
import '../shell_navigation_provider.dart';

BottomNavIconGalleryTab bottomNavIconGalleryTabForShellTab(AppShellTab tab) {
  return switch (tab) {
    AppShellTab.home => BottomNavIconGalleryTab.home,
    AppShellTab.bookshelf => BottomNavIconGalleryTab.bookshelf,
    AppShellTab.discover => BottomNavIconGalleryTab.discover,
    AppShellTab.stats => BottomNavIconGalleryTab.stats,
    AppShellTab.mine => BottomNavIconGalleryTab.mine,
  };
}

AppShellTab appShellTabForBottomNavIconGalleryTab(BottomNavIconGalleryTab tab) {
  return switch (tab) {
    BottomNavIconGalleryTab.home => AppShellTab.home,
    BottomNavIconGalleryTab.bookshelf => AppShellTab.bookshelf,
    BottomNavIconGalleryTab.discover => AppShellTab.discover,
    BottomNavIconGalleryTab.stats => AppShellTab.stats,
    BottomNavIconGalleryTab.mine => AppShellTab.mine,
  };
}

const List<BottomNavIconGalleryTab> bottomNavIconGalleryTabs = [
  BottomNavIconGalleryTab.home,
  BottomNavIconGalleryTab.bookshelf,
  BottomNavIconGalleryTab.discover,
  BottomNavIconGalleryTab.stats,
  BottomNavIconGalleryTab.mine,
];
