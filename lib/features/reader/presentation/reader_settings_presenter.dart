import '../../../domain/entities/reader_settings.dart';
import '../application/reader_font_registry_service.dart';

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

  String _formatTypographyValue({
    required double value,
    required int fractionDigits,
    String unit = '',
  }) {
    final normalized = value == 0 ? 0.0 : value;
    return '${normalized.toStringAsFixed(fractionDigits)}$unit';
  }
}
