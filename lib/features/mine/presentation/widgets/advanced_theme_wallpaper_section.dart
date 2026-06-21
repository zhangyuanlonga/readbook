import 'package:flutter/material.dart';

import 'advanced_theme_resource_picker_widgets.dart';

class AdvancedThemeWallpaperResourceCard extends StatelessWidget {
  const AdvancedThemeWallpaperResourceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.preview,
    required this.onTap,
    this.badges = const <String>[],
  });

  final String title;
  final String subtitle;
  final Widget preview;
  final VoidCallback onTap;
  final List<String> badges;

  @override
  Widget build(BuildContext context) {
    return AdvancedThemeVisualResourceCard(
      title: title,
      subtitle: subtitle,
      preview: preview,
      onTap: onTap,
      badges: badges,
    );
  }
}
