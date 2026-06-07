import 'dart:io';

import 'package:flutter/widgets.dart';

class AdvancedThemePreviewImageCache {
  final Map<String, ImageProvider<Object>> _providers =
      <String, ImageProvider<Object>>{};

  ImageProvider<Object> providerFor(String wallpaperPath) {
    return _providers.putIfAbsent(
      wallpaperPath,
      () => ResizeImage(FileImage(File(wallpaperPath)), width: 640),
    );
  }

  int get length => _providers.length;

  void clear() {
    _providers.clear();
  }
}
