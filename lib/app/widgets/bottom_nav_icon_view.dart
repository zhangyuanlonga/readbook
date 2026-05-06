import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/entities/bottom_nav_icon_gallery.dart';
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
    if (assetRef == null) {
      return Icon(icon.fallbackIcon, size: size, color: fallbackColor);
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
        if (!kIsWeb) {
          return SvgPicture.file(
            File(assetRef.path),
            width: size,
            height: size,
            fit: BoxFit.contain,
          );
        }
      } else if (assetRef.format == BottomNavIconAssetFormat.png ||
          assetRef.format == BottomNavIconAssetFormat.gif) {
        if (assetRef.isAsset) {
          return Image.asset(
            assetRef.path,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder:
                (_, __, ___) =>
                    Icon(icon.fallbackIcon, size: size, color: fallbackColor),
          );
        }
        if (!kIsWeb) {
          return Image.file(
            File(assetRef.path),
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder:
                (_, __, ___) =>
                    Icon(icon.fallbackIcon, size: size, color: fallbackColor),
          );
        }
      }
      return Icon(icon.fallbackIcon, size: size, color: fallbackColor);
    } catch (_) {
      return Icon(icon.fallbackIcon, size: size, color: fallbackColor);
    }
  }
}
