import 'package:flutter/material.dart';

import 'advanced_theme_appearance_link_tile.dart';

class AdvancedThemeFontSection extends StatelessWidget {
  const AdvancedThemeFontSection({
    super.key,
    required this.interfaceFontName,
    required this.readerFontName,
    required this.onPickInterfaceFont,
    required this.onPickReaderFont,
  });

  final String interfaceFontName;
  final String readerFontName;
  final VoidCallback onPickInterfaceFont;
  final VoidCallback onPickReaderFont;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AdvancedThemeAppearanceLinkTile(
          icon: Icons.text_fields_rounded,
          title: '界面字体',
          subtitle: interfaceFontName,
          onTap: onPickInterfaceFont,
        ),
        const Divider(height: 1),
        AdvancedThemeAppearanceLinkTile(
          icon: Icons.menu_book_outlined,
          title: '阅读字体',
          subtitle: readerFontName,
          onTap: onPickReaderFont,
        ),
      ],
    );
  }
}
