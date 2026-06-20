part of '../advanced_theme_editor_page.dart';

extension _AdvancedThemeColorSection on _AdvancedThemeEditorPageState {
  Widget _buildColorsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildThemeFieldSection(
          context,
          title: colorCardThemeSemanticGroup.title,
          tooltipMessage: colorCardThemeSemanticGroup.subtitle,
          fields: _fieldSpecsForGroup(colorCardThemeSemanticGroup),
        ),
      ],
    );
  }
}
