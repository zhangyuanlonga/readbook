import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/launch_image_gallery.dart';
import 'launch_image_gallery_service.dart';

final launchImageGalleryServiceProvider = Provider<LaunchImageGalleryService>((
  ref,
) {
  return LaunchImageGalleryService();
});

final launchImageGalleryRevisionProvider =
    NotifierProvider<LaunchImageGalleryRevisionNotifier, int>(
      LaunchImageGalleryRevisionNotifier.new,
    );

final launchImageGalleriesProvider = FutureProvider<List<LaunchImageGallery>>((
  ref,
) async {
  ref.watch(launchImageGalleryRevisionProvider);
  final service = ref.watch(launchImageGalleryServiceProvider);
  return service.loadGalleries();
});

final activeLaunchImageGalleryProvider = FutureProvider<LaunchImageGallery?>((
  ref,
) async {
  ref.watch(launchImageGalleryRevisionProvider);
  final service = ref.watch(launchImageGalleryServiceProvider);
  return service.loadActiveGallery();
});

class LaunchImageGalleryRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void markChanged() {
    state += 1;
  }
}
