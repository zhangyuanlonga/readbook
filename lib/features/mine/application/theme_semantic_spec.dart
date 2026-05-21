import 'package:flutter/material.dart';

import '../../../app/theme/app_advanced_theme_tokens.dart';

enum ThemeSemanticFieldId {
  accent,
  pageBackground,
  modalBackground,
  secondaryBackground,
  primaryText,
  secondaryText,
  border,
  cardBackground,
  cardText,
  cardBorder,
  iconBackground,
  emphasisBackground,
  buttonText,
  secondaryAccent,
  searchFieldBackground,
  noticeAccent,
  noticeSurface,
  wallpaperOverlay,
}

class ThemeSemanticFieldSpec {
  const ThemeSemanticFieldSpec({
    required this.id,
    required this.label,
    required this.description,
    required this.scopeLabels,
  });

  final ThemeSemanticFieldId id;
  final String label;
  final String description;
  final List<String> scopeLabels;
}

class ThemeSemanticGroupSpec {
  const ThemeSemanticGroupSpec({
    required this.title,
    required this.subtitle,
    required this.fields,
  });

  final String title;
  final String subtitle;
  final List<ThemeSemanticFieldSpec> fields;
}

class ThemeSemanticColorPreview {
  const ThemeSemanticColorPreview({
    required this.id,
    required this.label,
    required this.color,
  });

  final ThemeSemanticFieldId id;
  final String label;
  final Color color;
}

const List<ThemeSemanticFieldSpec> colorCardThemeSemanticFields =
    <ThemeSemanticFieldSpec>[
      ThemeSemanticFieldSpec(
        id: ThemeSemanticFieldId.accent,
        label: '强调色',
        description: '影响主按钮、选中态和核心高亮颜色',
        scopeLabels: <String>['主按钮', '选中态', '核心高亮'],
      ),
      ThemeSemanticFieldSpec(
        id: ThemeSemanticFieldId.pageBackground,
        label: '页面背景',
        description: '影响页面主背景和整体底色',
        scopeLabels: <String>['页面底色', '壳层背景'],
      ),
      ThemeSemanticFieldSpec(
        id: ThemeSemanticFieldId.modalBackground,
        label: '弹窗背景',
        description: '影响弹窗、菜单、底部浮层等悬浮内容背景',
        scopeLabels: <String>['Dialog', 'BottomSheet', '菜单', '局部浮层'],
      ),
      ThemeSemanticFieldSpec(
        id: ThemeSemanticFieldId.secondaryBackground,
        label: '次级背景',
        description: '影响分组容器、轻表面和部分次级区域背景',
        scopeLabels: <String>['筛选条', '分组容器', '轻表面'],
      ),
      ThemeSemanticFieldSpec(
        id: ThemeSemanticFieldId.primaryText,
        label: '主要文字',
        description: '影响标题、正文和主要操作说明',
        scopeLabels: <String>['标题', '正文', '主操作说明'],
      ),
      ThemeSemanticFieldSpec(
        id: ThemeSemanticFieldId.secondaryText,
        label: '辅助文字',
        description: '影响描述、提示和未选中内容文字',
        scopeLabels: <String>['描述', '提示', '未选中内容'],
      ),
      ThemeSemanticFieldSpec(
        id: ThemeSemanticFieldId.border,
        label: '边框',
        description: '影响通用边框、输入框边框和分隔线',
        scopeLabels: <String>['输入框边框', '分隔线', '通用描边'],
      ),
    ];

const ThemeSemanticGroupSpec colorCardThemeSemanticGroup =
    ThemeSemanticGroupSpec(
      title: '颜色卡片',
      subtitle: '这里放全局共享的颜色语义，优先决定整体氛围。',
      fields: colorCardThemeSemanticFields,
    );

const ThemeSemanticGroupSpec cardThemeSemanticGroup = ThemeSemanticGroupSpec(
  title: '卡片组件',
  subtitle: '用于卡片本身的背景、文字和边框，不放在全局颜色卡片里。',
  fields: <ThemeSemanticFieldSpec>[
    ThemeSemanticFieldSpec(
      id: ThemeSemanticFieldId.cardBackground,
      label: '卡片背景',
      description: '书架卡片、设置卡片和信息卡片背景',
      scopeLabels: <String>['书架卡片', '设置卡片', '信息卡片'],
    ),
    ThemeSemanticFieldSpec(
      id: ThemeSemanticFieldId.cardText,
      label: '卡片文字',
      description: '卡片内主要文字的颜色',
      scopeLabels: <String>['卡片标题', '卡片正文'],
    ),
    ThemeSemanticFieldSpec(
      id: ThemeSemanticFieldId.cardBorder,
      label: '卡片边框',
      description: '卡片和面板描边颜色',
      scopeLabels: <String>['卡片描边', '面板描边'],
    ),
    ThemeSemanticFieldSpec(
      id: ThemeSemanticFieldId.iconBackground,
      label: '图标底色',
      description: '图标圆底和小型入口底色',
      scopeLabels: <String>['图标圆底', '小型入口'],
    ),
  ],
);

const ThemeSemanticGroupSpec buttonThemeSemanticGroup = ThemeSemanticGroupSpec(
  title: '按钮组件',
  subtitle: '控制按钮上的背景层和文字颜色。',
  fields: <ThemeSemanticFieldSpec>[
    ThemeSemanticFieldSpec(
      id: ThemeSemanticFieldId.emphasisBackground,
      label: '强调背景',
      description: '选中态和强调区块的背景颜色',
      scopeLabels: <String>['选中态', '强调区块'],
    ),
    ThemeSemanticFieldSpec(
      id: ThemeSemanticFieldId.buttonText,
      label: '按钮文字',
      description: '主按钮和高亮按钮上的文字颜色',
      scopeLabels: <String>['主按钮文字', '高亮按钮文字'],
    ),
    ThemeSemanticFieldSpec(
      id: ThemeSemanticFieldId.secondaryAccent,
      label: '辅助强调',
      description: '次级按钮和辅助操作的强调颜色',
      scopeLabels: <String>['次级按钮', '辅助操作'],
    ),
  ],
);

const ThemeSemanticGroupSpec inputThemeSemanticGroup = ThemeSemanticGroupSpec(
  title: '输入框 / 搜索框组件',
  subtitle: '控制搜索框和输入区自己的底色。',
  fields: <ThemeSemanticFieldSpec>[
    ThemeSemanticFieldSpec(
      id: ThemeSemanticFieldId.searchFieldBackground,
      label: '搜索框背景',
      description: '搜索框、搜索触发条和输入区底色',
      scopeLabels: <String>['搜索框', '搜索触发条', '输入区'],
    ),
  ],
);

const ThemeSemanticGroupSpec optionThemeSemanticGroup = ThemeSemanticGroupSpec(
  title: '选项与切换组件',
  subtitle: '控制标签、徽标和状态提示的颜色。',
  fields: <ThemeSemanticFieldSpec>[
    ThemeSemanticFieldSpec(
      id: ThemeSemanticFieldId.noticeAccent,
      label: '提示强调',
      description: '标签、徽标和状态提示的强调色',
      scopeLabels: <String>['标签', '徽标', '状态提示'],
    ),
    ThemeSemanticFieldSpec(
      id: ThemeSemanticFieldId.noticeSurface,
      label: '提示底色',
      description: '提示块、状态标签和反馈容器背景',
      scopeLabels: <String>['提示块', '状态标签', '反馈容器'],
    ),
  ],
);

const ThemeSemanticGroupSpec pageEffectThemeSemanticGroup =
    ThemeSemanticGroupSpec(
      title: '页面效果',
      subtitle: '用于壁纸叠加和页面氛围微调。',
      fields: <ThemeSemanticFieldSpec>[
        ThemeSemanticFieldSpec(
          id: ThemeSemanticFieldId.wallpaperOverlay,
          label: '壁纸遮罩色',
          description: '页面壁纸上层覆盖色',
          scopeLabels: <String>['页面壁纸', '氛围遮罩'],
        ),
      ],
    );

const List<ThemeSemanticGroupSpec> themeSemanticEditorGroups =
    <ThemeSemanticGroupSpec>[
      colorCardThemeSemanticGroup,
      cardThemeSemanticGroup,
      buttonThemeSemanticGroup,
      inputThemeSemanticGroup,
      optionThemeSemanticGroup,
      pageEffectThemeSemanticGroup,
    ];

final Map<ThemeSemanticFieldId, ThemeSemanticFieldSpec>
_themeSemanticFieldSpecsById = <ThemeSemanticFieldId, ThemeSemanticFieldSpec>{
  for (final group in themeSemanticEditorGroups)
    for (final field in group.fields) field.id: field,
};

ThemeSemanticFieldSpec themeSemanticFieldSpecFor(ThemeSemanticFieldId id) {
  return _themeSemanticFieldSpecsById[id]!;
}

List<ThemeSemanticColorPreview> buildColorCardThemeSemanticPreviews({
  required ResolvedAdvancedThemePalette palette,
  required ResolvedAdvancedThemeBackdrop backdrop,
}) {
  return <ThemeSemanticColorPreview>[
    ThemeSemanticColorPreview(
      id: ThemeSemanticFieldId.accent,
      label: '强调色',
      color: palette.primaryColor,
    ),
    ThemeSemanticColorPreview(
      id: ThemeSemanticFieldId.pageBackground,
      label: '页面背景',
      color: backdrop.backgroundColor,
    ),
    ThemeSemanticColorPreview(
      id: ThemeSemanticFieldId.modalBackground,
      label: '弹窗背景',
      color: palette.surfaceColor,
    ),
    ThemeSemanticColorPreview(
      id: ThemeSemanticFieldId.secondaryBackground,
      label: '次级背景',
      color: palette.elevatedSurfaceColor,
    ),
    ThemeSemanticColorPreview(
      id: ThemeSemanticFieldId.primaryText,
      label: '主要文字',
      color: palette.textPrimaryColor,
    ),
    ThemeSemanticColorPreview(
      id: ThemeSemanticFieldId.secondaryText,
      label: '辅助文字',
      color: palette.textSecondaryColor,
    ),
    ThemeSemanticColorPreview(
      id: ThemeSemanticFieldId.border,
      label: '边框',
      color: palette.outlineColor,
    ),
  ];
}
