import 'dart:io';

import 'package:flutter/painting.dart';

Future<void> evictFileImagePath(String? path) async {
  final normalized = path?.trim() ?? '';
  if (normalized.isEmpty) {
    return;
  }
  final provider = FileImage(File(normalized));
  await provider.evict();
}

Future<void> evictFileImagePaths(Iterable<String> paths) async {
  for (final path in paths) {
    await evictFileImagePath(path);
  }
}
