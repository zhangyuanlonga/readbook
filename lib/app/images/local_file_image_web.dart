import 'package:flutter/material.dart';

ImageProvider? resolveLocalFileImageProvider(String? imagePath) => null;

String? localFilePathFromUri(Uri uri) => null;

String normalizeLocalFileImagePath(String? imagePath) => '';

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
  return fallback;
}
