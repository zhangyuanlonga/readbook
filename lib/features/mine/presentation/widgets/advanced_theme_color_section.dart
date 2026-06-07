part of '../advanced_theme_editor_page.dart';

extension _AdvancedThemeColorSection on _AdvancedThemeEditorPageState {
  Widget _buildColorsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (
          var index = 0;
          index < themeSemanticEditorGroups.length;
          index++
        ) ...[
          _buildThemeFieldSection(
            context,
            title: themeSemanticEditorGroups[index].title,
            tooltipMessage: themeSemanticEditorGroups[index].subtitle,
            fields: _fieldSpecsForGroup(themeSemanticEditorGroups[index]),
          ),
          const SizedBox(height: 8),
        ],
        _buildExpandableColorSection(
          context,
          title: '强度层',
          tooltipMessage: '卡片阴影、壁纸透明度、模糊和遮罩强度',
          expanded: _strengthControlsExpanded,
          onToggle: () {
            _updateAdvancedThemeEditorState(() {
              _strengthControlsExpanded = !_strengthControlsExpanded;
            });
          },
          child: _buildStrengthSection(context),
        ),
      ],
    );
  }
}
