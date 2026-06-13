import 'package:flutter/material.dart';

import 'advanced_theme_wallpaper_section.dart';

class AdvancedThemeLaunchGallerySection extends StatelessWidget {
  const AdvancedThemeLaunchGallerySection({
    super.key,
    required this.subtitle,
    required this.preview,
    required this.onTap,
    this.badges = const <String>[],
  });

  final String subtitle;
  final Widget preview;
  final VoidCallback onTap;
  final List<String> badges;

  @override
  Widget build(BuildContext context) {
    return AdvancedThemeWallpaperResourceCard(
      title: '启动图集',
      subtitle: subtitle,
      preview: preview,
      onTap: onTap,
      badges: badges,
    );
  }
}
