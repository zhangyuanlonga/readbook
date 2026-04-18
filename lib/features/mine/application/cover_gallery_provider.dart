import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/cover_gallery.dart';
import 'cover_gallery_service.dart';

final coverGalleryServiceProvider = Provider<CoverGalleryService>((ref) {
  return CoverGalleryService();
});

final coverGalleryRevisionProvider =
    NotifierProvider<CoverGalleryRevisionNotifier, int>(
      CoverGalleryRevisionNotifier.new,
    );

final coverGalleriesProvider = FutureProvider<List<CoverGallery>>((ref) async {
  ref.watch(coverGalleryRevisionProvider);
  final service = ref.watch(coverGalleryServiceProvider);
  return service.loadGalleries();
});

class CoverGalleryRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void markChanged() {
    state += 1;
  }
}
