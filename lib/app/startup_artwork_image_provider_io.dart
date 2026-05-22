import 'dart:io';

import 'package:flutter/material.dart';

ImageProvider? resolveStartupArtworkFileProvider(String? imagePath) {
  final normalized = imagePath?.trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  if (normalized.startsWith('assets/')) {
    return AssetImage(normalized);
  }
  return FileImage(File(normalized));
}
