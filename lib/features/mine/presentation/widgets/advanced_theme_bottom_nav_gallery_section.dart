import 'package:flutter/material.dart';

import 'advanced_theme_appearance_link_tile.dart';

class AdvancedThemeBottomNavGallerySection extends StatelessWidget {
  const AdvancedThemeBottomNavGallerySection({
    super.key,
    required this.subtitle,
    required this.onTap,
  });

  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AdvancedThemeAppearanceLinkTile(
      icon: Icons.dashboard_outlined,
      title: '底栏',
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}
