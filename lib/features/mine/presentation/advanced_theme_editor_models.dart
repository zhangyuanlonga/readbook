import 'package:flutter/material.dart';

import '../../../domain/entities/app_advanced_theme.dart';
import '../application/theme_semantic_spec.dart';

enum AdvancedThemeColorSlot {
  primary('强调色', '按钮和链接的颜色'),
  noticeAccent('提示强调', '重要提示和通知强调色'),
  noticeSurface('提示底色', '重要提示块和状态标签的背景色'),
  background('页面背景', '页面底色'),
  surface('弹窗背景', '菜单、弹窗和底部浮层的底色'),
  searchFieldBackground('搜索框背景', '搜索框和搜索触发条的填充颜色'),
  elevatedSurface('次级背景', '分组区域和轻表面的底色'),
  textPrimary('主要文字', '正文和标题的颜色'),
  textSecondary('辅助文字', '提示和说明的颜色'),
  outline('边框', '输入框、分隔线和通用描边颜色'),
  card('卡片背景', '列表项和弹窗的底色'),
  cardText('卡片文字', '卡片内主要文字的颜色'),
  cardBorder('卡片边框', '卡片和面板描边颜色'),
  iconBackground('图标底色', '我的页小卡片图标圆底背景'),
  primaryContainer('强调背景', '标签、筛选和选中态背景色'),
  secondary('辅助强调', '次级徽标和辅助操作的强调色'),
  buttonText('按钮文字', '主按钮和高亮按钮上的文字'),
  divider('分割线', '列表、菜单和分组分割线颜色'),
  shadow('阴影', '卡片和浮层的阴影或光晕颜色'),
  wallpaperOverlay('壁纸遮罩色', '壁纸上层覆盖的颜色');

  const AdvancedThemeColorSlot(this.label, this.description);

  final String label;
  final String description;

  static AdvancedThemeColorSlot fromSemanticField(ThemeSemanticFieldId id) {
    return switch (id) {
      ThemeSemanticFieldId.accent => AdvancedThemeColorSlot.primary,
      ThemeSemanticFieldId.pageBackground => AdvancedThemeColorSlot.background,
      ThemeSemanticFieldId.modalBackground => AdvancedThemeColorSlot.surface,
      ThemeSemanticFieldId.secondaryBackground =>
        AdvancedThemeColorSlot.elevatedSurface,
      ThemeSemanticFieldId.primaryText => AdvancedThemeColorSlot.textPrimary,
      ThemeSemanticFieldId.secondaryText =>
        AdvancedThemeColorSlot.textSecondary,
      ThemeSemanticFieldId.border => AdvancedThemeColorSlot.outline,
      ThemeSemanticFieldId.divider => AdvancedThemeColorSlot.divider,
      ThemeSemanticFieldId.cardBackground => AdvancedThemeColorSlot.card,
      ThemeSemanticFieldId.cardText => AdvancedThemeColorSlot.cardText,
      ThemeSemanticFieldId.cardBorder => AdvancedThemeColorSlot.cardBorder,
      ThemeSemanticFieldId.iconBackground =>
        AdvancedThemeColorSlot.iconBackground,
      ThemeSemanticFieldId.emphasisBackground =>
        AdvancedThemeColorSlot.primaryContainer,
      ThemeSemanticFieldId.buttonText => AdvancedThemeColorSlot.buttonText,
      ThemeSemanticFieldId.shadow => AdvancedThemeColorSlot.shadow,
      ThemeSemanticFieldId.secondaryAccent => AdvancedThemeColorSlot.secondary,
      ThemeSemanticFieldId.searchFieldBackground =>
        AdvancedThemeColorSlot.searchFieldBackground,
      ThemeSemanticFieldId.noticeAccent => AdvancedThemeColorSlot.noticeAccent,
      ThemeSemanticFieldId.noticeSurface =>
        AdvancedThemeColorSlot.noticeSurface,
      ThemeSemanticFieldId.wallpaperOverlay =>
        AdvancedThemeColorSlot.wallpaperOverlay,
    };
  }
}

class AdvancedThemeColorCodec {
  const AdvancedThemeColorCodec._();

  static int? parseHexColor(String raw) {
    final normalized = raw.trim().toUpperCase();
    if (normalized.isEmpty) {
      return null;
    }
    final body =
        normalized.startsWith('#') ? normalized.substring(1) : normalized;
    if (body.length == 6) {
      return int.tryParse('FF$body', radix: 16);
    }
    if (body.length == 8) {
      return int.tryParse(body, radix: 16);
    }
    return null;
  }

  static String formatHex(int? value) {
    if (value == null) {
      return '';
    }
    final hex = value.toRadixString(16).toUpperCase().padLeft(8, '0');
    if (hex.startsWith('FF')) {
      return '#${hex.substring(2)}';
    }
    return '#$hex';
  }

  static Color resolvedColor(int? value, Color fallback) {
    if (value == null) {
      return fallback;
    }
    return Color(value);
  }
}

class AdvancedThemeColorFieldSpec {
  const AdvancedThemeColorFieldSpec({
    required this.slot,
    required this.label,
    required this.description,
    required this.scopeLabels,
  });

  final AdvancedThemeColorSlot slot;
  final String label;
  final String description;
  final List<String> scopeLabels;

  String get tooltipMessage {
    final normalizedScopes = scopeLabels
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .join(' / ');
    if (normalizedScopes.isEmpty) {
      return description.trim();
    }
    return '${description.trim()}\n影响范围：$normalizedScopes';
  }
}

class AdvancedThemeCoverGallerySelectionResult {
  const AdvancedThemeCoverGallerySelectionResult({
    required this.applied,
    required this.galleryId,
  });

  final bool applied;
  final String? galleryId;
}

class AdvancedThemeLaunchImageGallerySelectionResult {
  const AdvancedThemeLaunchImageGallerySelectionResult({
    required this.applied,
    required this.galleryId,
  });

  final bool applied;
  final String? galleryId;
}

class AdvancedThemeWallpaperSelectionResult {
  const AdvancedThemeWallpaperSelectionResult({
    required this.path,
    this.fit = AppAdvancedThemeWallpaperFit.cover,
  });

  final String? path;
  final AppAdvancedThemeWallpaperFit fit;
}

class AdvancedThemeFontSelectionResult {
  const AdvancedThemeFontSelectionResult({
    required this.applied,
    required this.familyKey,
  });

  final bool applied;
  final String? familyKey;
}

class AdvancedThemeComponentStyleChoice<T> {
  const AdvancedThemeComponentStyleChoice(this.value, this.label);

  final T value;
  final String label;
}
