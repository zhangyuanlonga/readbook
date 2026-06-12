import 'package:flutter/material.dart';

class ReaderSettingsSection extends StatelessWidget {
  const ReaderSettingsSection({
    super.key,
    required this.children,
    this.semanticLabel,
  });

  final List<Widget> children;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );

    if (semanticLabel == null || semanticLabel!.trim().isEmpty) {
      return content;
    }
    return Semantics(label: semanticLabel, container: true, child: content);
  }
}

class ReaderTypographySettingsSection extends ReaderSettingsSection {
  const ReaderTypographySettingsSection({super.key, required super.children})
    : super(semanticLabel: 'reader_typography_settings_section');
}

class ReaderThemeBackgroundSettingsSection extends ReaderSettingsSection {
  const ReaderThemeBackgroundSettingsSection({
    super.key,
    required super.children,
  }) : super(semanticLabel: 'reader_theme_background_settings_section');
}

class ReaderLayoutSettingsSection extends ReaderSettingsSection {
  const ReaderLayoutSettingsSection({super.key, required super.children})
    : super(semanticLabel: 'reader_layout_settings_section');
}

class ReaderPageTurnSettingsSection extends ReaderSettingsSection {
  const ReaderPageTurnSettingsSection({super.key, required super.children})
    : super(semanticLabel: 'reader_page_turn_settings_section');
}

class ReaderAutoReadSettingsSection extends ReaderSettingsSection {
  const ReaderAutoReadSettingsSection({super.key, required super.children})
    : super(semanticLabel: 'reader_auto_read_settings_section');
}

class ReaderAudioSettingsSection extends ReaderSettingsSection {
  const ReaderAudioSettingsSection({super.key, required super.children})
    : super(semanticLabel: 'reader_audio_settings_section');
}

class ReaderMangaSettingsSection extends ReaderSettingsSection {
  const ReaderMangaSettingsSection({super.key, required super.children})
    : super(semanticLabel: 'reader_manga_settings_section');
}
