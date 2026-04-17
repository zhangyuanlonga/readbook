import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/bottom_nav_icon_gallery.dart';
import '../../features/mine/application/advanced_theme_provider.dart';
import 'bottom_nav_icon_gallery_service.dart';

final bottomNavIconGalleryServiceProvider =
    Provider<BottomNavIconGalleryService>(
      (ref) => BottomNavIconGalleryService(),
    );

final activeBottomNavIconGalleryProvider =
    FutureProvider<BottomNavIconGallery?>((ref) async {
      return ref.watch(bottomNavIconGalleryServiceProvider).loadActiveGallery();
    });

final effectiveBottomNavIconGalleryProvider =
    FutureProvider<BottomNavIconGallery?>((ref) async {
      final service = ref.watch(bottomNavIconGalleryServiceProvider);
      final activeAdvancedTheme = await ref.watch(
        activeAdvancedThemeProvider.future,
      );
      final overrideGalleryId = activeAdvancedTheme?.bottomNavGalleryId?.trim();
      if (overrideGalleryId != null && overrideGalleryId.isNotEmpty) {
        final galleries = await service.loadGalleries();
        for (final gallery in galleries) {
          if (gallery.id == overrideGalleryId) {
            return gallery;
          }
        }
      }
      return service.loadActiveGallery();
    });
