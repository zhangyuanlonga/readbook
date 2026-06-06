import '../../../domain/entities/reader_settings.dart';
import '../application/reader_font_registry_service.dart';

class ReaderSettingsOwnershipDescriptor {
  const ReaderSettingsOwnershipDescriptor({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;
}

class ReaderSettingsSectionDescriptor {
  const ReaderSettingsSectionDescriptor({
    required this.groupKey,
    required this.title,
  });

  final String groupKey;
  final String title;
}

class ReaderSettingsPresenter {
  const ReaderSettingsPresenter();

  String bodyMarginDisplayValue(ReaderSettings settings) {
    return '上${settings.bodyMarginTop.round()} 下${settings.bodyMarginBottom.round()} 左${settings.bodyMarginLeft.round()} 右${settings.bodyMarginRight.round()}';
  }

  String autoReadSpeedLevelLabel(double speed) {
    if (speed < 42) {
      return '慢速';
    }
    if (speed < 78) {
      return '中速';
    }
    return '快速';
  }

  String fontSizeValueLabel(ReaderSettings settings) {
    return _formatTypographyValue(
      value: settings.fontSize,
      fractionDigits: 0,
      unit: 'px',
    );
  }

  String letterSpacingValueLabel(ReaderSettings settings) {
    return _formatTypographyValue(
      value: settings.letterSpacing,
      fractionDigits: 2,
    );
  }

  String lineHeightValueLabel(ReaderSettings settings) {
    return _formatTypographyValue(
      value: settings.lineHeight,
      fractionDigits: 2,
    );
  }

  String paragraphSpacingValueLabel(ReaderSettings settings) {
    return _formatTypographyValue(
      value: settings.paragraphSpacing,
      fractionDigits: 0,
    );
  }

  String paragraphIndentValueLabel(ReaderSettings settings) {
    return settings.paragraphIndent.round().toString();
  }

  String layoutMarginValueLabel(double value) {
    final normalized = value.clamp(
      ReaderSettings.minLayoutMargin,
      ReaderSettings.maxLayoutMargin,
    );
    final rounded = normalized.roundToDouble();
    if ((normalized - rounded).abs() < 0.001) {
      return rounded.toInt().toString();
    }
    return normalized.toStringAsFixed(1);
  }

  String mangaReadModeLabel(ReaderMangaReadMode mode) {
    return switch (mode) {
      ReaderMangaReadMode.continuous => '连续长图',
      ReaderMangaReadMode.paged => '分页图',
      ReaderMangaReadMode.horizontal => '横向翻页',
    };
  }

  String mangaLoadStrategyLabel(ReaderMangaLoadStrategy strategy) {
    return switch (strategy) {
      ReaderMangaLoadStrategy.balanced => '平衡',
      ReaderMangaLoadStrategy.smooth => '流畅优先',
      ReaderMangaLoadStrategy.saveData => '省流量',
    };
  }

  String pageAnimationLabel(ReaderPageAnimationStyle style) {
    return switch (style) {
      ReaderPageAnimationStyle.curl => '仿真',
      ReaderPageAnimationStyle.paperCurl => '纸页卷动',
      ReaderPageAnimationStyle.fade => '淡入淡出',
      ReaderPageAnimationStyle.cover => '覆盖',
      ReaderPageAnimationStyle.translate => '滑动',
      ReaderPageAnimationStyle.vertical => '滑动',
      ReaderPageAnimationStyle.none => '无动画',
    };
  }

  String systemFontPresetLabel(ReaderSystemFontPreset preset) {
    return switch (preset) {
      ReaderSystemFontPreset.defaultSans => '系统默认',
      ReaderSystemFontPreset.serif => '衬线',
      ReaderSystemFontPreset.monospace => '等宽',
    };
  }

  String currentFontLabel({
    required ReaderSettings settings,
    required List<ReaderCustomFontEntry> customFonts,
  }) {
    if (settings.fontSource == ReaderFontSource.custom) {
      final familyKey = settings.fontFamilyKey;
      if (familyKey != null) {
        for (final entry in customFonts) {
          if (entry.fontFamilyKey == familyKey) {
            return entry.displayName;
          }
        }
      }
      return '自定义字体';
    }
    return systemFontPresetLabel(settings.systemFontPreset);
  }

  ReaderSettingsOwnershipDescriptor ownershipDescriptor(String groupKey) {
    return switch (groupKey) {
      'typography' ||
      'quick_margins' ||
      'info_layout' => const ReaderSettingsOwnershipDescriptor(
        title: '文本模式偏好',
        description: '这组设置会跟随当前阅读模式长期保存，影响文本正文的显示与排版。',
      ),
      'interaction' => const ReaderSettingsOwnershipDescriptor(
        title: '设备级交互偏好',
        description: '这组设置会作为当前设备的阅读交互偏好保存，影响工具栏、翻页和按键行为。',
      ),
      'auto_read' => const ReaderSettingsOwnershipDescriptor(
        title: '设备级 + 会话级',
        description: '自动阅读配置会长期保存，但本次是否正在自动阅读属于阅读会话状态，不会单独持久化。',
      ),
      'audio' => const ReaderSettingsOwnershipDescriptor(
        title: '设备级听书偏好',
        description: '这组设置会作为听书模式的设备级偏好保存，进入新章节时继续沿用。',
      ),
      _ => const ReaderSettingsOwnershipDescriptor(
        title: '阅读器偏好',
        description: '该分组会按阅读器当前模式和设备偏好共同生效。',
      ),
    };
  }

  /// 设置面板分组标题的统一入口。
  ///
  /// 后续继续拆 `reader_page_settings_sheet.dart` 时，section widget 应优先消费这里
  /// 的分组语义，避免移动端底部面板和桌面侧栏各自维护一份标题映射。
  String sectionTitle({
    required String? groupKey,
    required bool showInterfaceSettings,
  }) {
    return switch (groupKey) {
      'quick_margins' || 'info_layout' || 'info' => '信息排版',
      'typography' => '字体',
      'interaction' => '翻页与动画',
      'behavior' => '阅读行为',
      'manga' => '漫画阅读',
      'audio' => '听书设置',
      'auto_read' => '自动阅读',
      _ => showInterfaceSettings ? '界面设置' : '设置',
    };
  }

  List<ReaderSettingsSectionDescriptor> sectionPlan({
    required bool showInterfaceSettings,
    required bool supportsAutoRead,
    required bool supportsAudio,
    required bool supportsManga,
  }) {
    final groupKeys =
        showInterfaceSettings
            ? const <String>['typography', 'quick_margins', 'interaction']
            : const <String>['behavior', 'info'];
    final descriptors = <ReaderSettingsSectionDescriptor>[
      for (final groupKey in groupKeys)
        ReaderSettingsSectionDescriptor(
          groupKey: groupKey,
          title: sectionTitle(
            groupKey: groupKey,
            showInterfaceSettings: showInterfaceSettings,
          ),
        ),
      if (supportsAutoRead)
        ReaderSettingsSectionDescriptor(
          groupKey: 'auto_read',
          title: sectionTitle(
            groupKey: 'auto_read',
            showInterfaceSettings: showInterfaceSettings,
          ),
        ),
      if (supportsAudio)
        ReaderSettingsSectionDescriptor(
          groupKey: 'audio',
          title: sectionTitle(
            groupKey: 'audio',
            showInterfaceSettings: showInterfaceSettings,
          ),
        ),
      if (supportsManga)
        ReaderSettingsSectionDescriptor(
          groupKey: 'manga',
          title: sectionTitle(
            groupKey: 'manga',
            showInterfaceSettings: showInterfaceSettings,
          ),
        ),
    ];
    return List<ReaderSettingsSectionDescriptor>.unmodifiable(descriptors);
  }

  String _formatTypographyValue({
    required double value,
    required int fractionDigits,
    String unit = '',
  }) {
    final normalized = value == 0 ? 0.0 : value;
    return '${normalized.toStringAsFixed(fractionDigits)}$unit';
  }
}
