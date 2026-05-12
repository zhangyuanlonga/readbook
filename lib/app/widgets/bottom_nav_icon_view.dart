import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/storage/local_file_stat.dart';
import '../../domain/entities/bottom_nav_icon_gallery.dart';
import '../images/local_file_image.dart';
import '../navigation/bottom_nav_icon_resolver.dart';

class BottomNavIconView extends StatelessWidget {
  const BottomNavIconView({
    super.key,
    required this.icon,
    required this.size,
    this.fallbackColor,
  });

  final ResolvedBottomNavIcon icon;
  final double size;
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) {
    final assetRef = icon.assetRef;
    final fallback = Icon(icon.fallbackIcon, size: size, color: fallbackColor);
    if (assetRef == null) {
      return fallback;
    }

    try {
      if (assetRef.format == BottomNavIconAssetFormat.svg) {
        if (assetRef.isAsset) {
          return SvgPicture.asset(
            assetRef.path,
            width: size,
            height: size,
            fit: BoxFit.contain,
          );
        }
        return FutureBuilder<String?>(
          future: readLocalFileText(assetRef.path),
          builder: (context, snapshot) {
            final svgText = snapshot.data;
            if (svgText == null || svgText.trim().isEmpty) {
              return fallback;
            }
            return SvgPicture.string(
              svgText,
              width: size,
              height: size,
              fit: BoxFit.contain,
            );
          },
        );
      } else if (assetRef.format == BottomNavIconAssetFormat.png ||
          assetRef.format == BottomNavIconAssetFormat.gif) {
        if (assetRef.isAsset) {
          return Image.asset(
            assetRef.path,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => fallback,
          );
        }
        return buildLocalFileImage(
          imagePath: assetRef.path,
          width: size,
          height: size,
          fit: BoxFit.contain,
          fallback: fallback,
        );
      }
      return fallback;
    } catch (_) {
      return fallback;
    }
  }
}
