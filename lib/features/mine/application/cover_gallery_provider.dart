import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/cover_gallery.dart';
import 'cover_gallery_service.dart';

final coverGalleryServiceProvider = Provider<CoverGalleryService>((ref) {
  return CoverGalleryService();
});

final coverGalleriesProvider = FutureProvider<List<CoverGallery>>((ref) async {
  final service = ref.watch(coverGalleryServiceProvider);
  return service.loadGalleries();
});
