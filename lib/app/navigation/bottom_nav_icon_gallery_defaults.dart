import '../../domain/entities/bottom_nav_icon_gallery.dart';

const String defaultBottomNavIconGalleryId = 'system_default';

final BottomNavIconGallery defaultBottomNavIconGallery = BottomNavIconGallery(
  id: defaultBottomNavIconGalleryId,
  name: '系统默认',
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  isBuiltIn: true,
  isEditable: false,
  isDeletable: false,
  items: const {
    BottomNavIconGalleryTab.home: BottomNavIconSet(),
    BottomNavIconGalleryTab.bookshelf: BottomNavIconSet(),
    BottomNavIconGalleryTab.discover: BottomNavIconSet(),
    BottomNavIconGalleryTab.stats: BottomNavIconSet(),
    BottomNavIconGalleryTab.mine: BottomNavIconSet(),
  },
);

final List<BottomNavIconGallery> builtInBottomNavIconGalleries = [
  defaultBottomNavIconGallery,
];
