import 'dart:io';

import 'package:flutter/material.dart';

ImageProvider? resolveLocalFileImageProvider(String? imagePath) {
  final normalized = normalizeLocalFileImagePath(imagePath);
  if (normalized.isEmpty || !File(normalized).existsSync()) {
    return null;
  }
  return FileImage(File(normalized));
}

String? localFilePathFromUri(Uri uri) {
  if (uri.scheme != 'file') {
    return null;
  }
  return File.fromUri(uri).path;
}

String normalizeLocalFileImagePath(String? imagePath) {
  final normalized = imagePath?.trim() ?? '';
  if (normalized.isEmpty) {
    return '';
  }
  final uri = Uri.tryParse(normalized);
  if (uri != null && uri.scheme == 'file') {
    return File.fromUri(uri).path;
  }
  return normalized;
}

Widget buildLocalFileImage({
  required String? imagePath,
  required Widget fallback,
  Key? key,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  int? cacheWidth,
  int? cacheHeight,
  bool gaplessPlayback = false,
  FilterQuality filterQuality = FilterQuality.medium,
}) {
  final normalized = normalizeLocalFileImagePath(imagePath);
  if (normalized.isEmpty) {
    return fallback;
  }
  return Image.file(
    File(normalized),
    key: key,
    width: width,
    height: height,
    fit: fit,
    cacheWidth: cacheWidth,
    cacheHeight: cacheHeight,
    gaplessPlayback: gaplessPlayback,
    filterQuality: filterQuality,
    errorBuilder: (_, __, ___) => fallback,
  );
}
