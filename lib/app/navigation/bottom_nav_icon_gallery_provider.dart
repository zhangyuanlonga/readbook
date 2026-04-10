import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/bottom_nav_icon_gallery.dart';
import 'bottom_nav_icon_gallery_service.dart';

final bottomNavIconGalleryServiceProvider =
    Provider<BottomNavIconGalleryService>(
      (ref) => BottomNavIconGalleryService(),
    );

final activeBottomNavIconGalleryProvider =
    FutureProvider<BottomNavIconGallery?>((ref) async {
      return ref.watch(bottomNavIconGalleryServiceProvider).loadActiveGallery();
    });
