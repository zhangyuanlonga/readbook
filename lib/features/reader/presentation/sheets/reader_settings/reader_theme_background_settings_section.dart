import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../../domain/entities/reader_settings.dart';
import '../../../application/reader_content_session.dart';
import '../../widgets/reader_typography_slider_row.dart';
import 'reader_page_turn_settings_section.dart';
import 'reader_settings_components.dart';

class ReaderThemeBackgroundColorOption {
  const ReaderThemeBackgroundColorOption({
    required this.label,
    required this.previewColor,
    required this.mode,
    required this.backgroundStyle,
    required this.backgroundTone,
  });

  final String label;
  final Color previewColor;
  final ReaderThemeMode mode;
  final ReaderBackgroundStyle backgroundStyle;
  final ReaderBackgroundTone backgroundTone;
}

class ReaderBackgroundImageTileData {
  const ReaderBackgroundImageTileData({
    required this.label,
    required this.selected,
    required this.onTap,
    this.previewBytes,
    this.showLabel = true,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Uint8List? previewBytes;
  final bool showLabel;
  final IconData? icon;
}

class ReaderThemeBackgroundSettingsPanel extends StatelessWidget {
  const ReaderThemeBackgroundSettingsPanel({
    super.key,
    required this.settings,
    required this.contentMode,
    required this.compactScale,
    required this.backgroundTileScale,
    required this.sliderBuilder,
    required this.colorOptions,
    required this.presetBackgroundTiles,
    required this.customBackgroundTiles,
    required this.hasBackgroundImage,
    required this.pageAnimationLabel,
    required this.onChanged,
    required this.onSelectSettingsGroup,
    required this.onClearBackgroundImage,
    required this.onApplyCustomBackgroundImage,
    required this.onOpenBackgroundManagement,
    required this.onRemoveActiveBackground,
  });

  final ReaderSettings settings;
  final ReaderContentMode contentMode;
  final double compactScale;
  final double backgroundTileScale;
  final ReaderPreviewAwareSliderBuilder sliderBuilder;
  final List<ReaderThemeBackgroundColorOption> colorOptions;
  final List<ReaderBackgroundImageTileData> presetBackgroundTiles;
  final List<ReaderBackgroundImageTileData> customBackgroundTiles;
  final bool hasBackgroundImage;
  final String Function(ReaderPageAnimationStyle style) pageAnimationLabel;
  final ValueChanged<ReaderSettings> onChanged;
  final ValueChanged<String> onSelectSettingsGroup;
  final VoidCallback onClearBackgroundImage;
  final VoidCallback onApplyCustomBackgroundImage;
  final VoidCallback onOpenBackgroundManagement;
  final VoidCallback? onRemoveActiveBackground;

  static const Set<PointerDeviceKind> _scrollDragDevices = <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.unknown,
  };

  bool get _isTextMode => contentMode == ReaderContentMode.text;

  double _scale(double value) => value * compactScale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CurrentModeSummaryCard(
          contentMode: contentMode,
          compactScale: compactScale,
        ),
        _buildBrightnessRow(context),
        SizedBox(height: _scale(8)),
        _buildNavigationCapsules(),
        SizedBox(height: _scale(14)),
        ReaderSettingsCompactTitle(title: '背景色', compactScale: compactScale),
        SizedBox(height: _scale(10)),
        _buildBackgroundColors(),
        SizedBox(height: _scale(14)),
        ReaderSettingsCompactTitle(title: '背景图', compactScale: compactScale),
        SizedBox(height: _scale(10)),
        _buildBackgroundImages(context),
        if (_isTextMode) ...[
          const SizedBox(height: 14),
          ReaderSettingsCompactTitle(title: '翻页动画', compactScale: compactScale),
          const SizedBox(height: 10),
          ReaderInlinePageAnimationSelector(
            settings: settings,
            pageAnimationLabel: pageAnimationLabel,
            onChanged: onChanged,
          ),
        ],
      ],
    );
  }

  Widget _buildBrightnessRow(BuildContext context) {
    return Row(
      children: [
        Text(
          '亮度',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        SizedBox(width: _scale(10)),
        Expanded(
          child: sliderBuilder(
            min: 0.2,
            max: 1,
            divisions: 8,
            value: settings.brightness,
            onChanged:
                settings.followSystemBrightness
                    ? null
                    : (value) =>
                        onChanged(settings.copyWith(brightness: value)),
          ),
        ),
        SizedBox(width: _scale(6)),
        _BrightnessFollowChip(
          value: settings.followSystemBrightness,
          compactScale: compactScale,
          onChanged:
              (enabled) =>
                  onChanged(settings.copyWith(followSystemBrightness: enabled)),
        ),
        SizedBox(width: _scale(6)),
        SizedBox(
          height: 40,
          child: TextButton.icon(
            onPressed: () {
              final selected = settings.themeMode != ReaderThemeMode.sepia;
              onChanged(
                settings.copyWith(
                  themeMode:
                      selected ? ReaderThemeMode.sepia : ReaderThemeMode.light,
                  backgroundStyle:
                      selected
                          ? ReaderBackgroundStyle.warm
                          : ReaderBackgroundStyle.plain,
                  backgroundTone:
                      selected
                          ? ReaderBackgroundTone.container
                          : ReaderBackgroundTone.surface,
                ),
              );
            },
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.symmetric(horizontal: _scale(6)),
            ),
            icon: Icon(
              settings.themeMode == ReaderThemeMode.sepia
                  ? Icons.visibility_rounded
                  : Icons.visibility_outlined,
              size: _scale(16),
              color:
                  settings.themeMode == ReaderThemeMode.sepia
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            label: Text(
              '护眼',
              style: TextStyle(
                color:
                    settings.themeMode == ReaderThemeMode.sepia
                        ? Theme.of(context).colorScheme.primary
                        : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationCapsules() {
    return Row(
      children: [
        if (_isTextMode) ...[
          Flexible(
            fit: FlexFit.loose,
            child: _InterfaceCapsuleEntry(
              icon: Icons.format_size_rounded,
              title: '字体',
              compactScale: compactScale,
              onTap: () => onSelectSettingsGroup('typography'),
            ),
          ),
          SizedBox(width: _scale(8)),
          Flexible(
            fit: FlexFit.loose,
            child: _InterfaceCapsuleEntry(
              icon: Icons.info_outline_rounded,
              title: '信息排版',
              compactScale: compactScale,
              onTap: () => onSelectSettingsGroup('info_layout'),
            ),
          ),
          SizedBox(width: _scale(8)),
        ],
        Flexible(
          fit: FlexFit.loose,
          child: _InterfaceCapsuleEntry(
            icon: Icons.tune_rounded,
            title: '更多',
            compactScale: compactScale,
            onTap: () => onSelectSettingsGroup('interaction'),
          ),
        ),
      ],
    );
  }

  Widget _buildBackgroundColors() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: colorOptions
            .map(
              (option) => ReaderThemeBackgroundColorDot(
                settings: settings,
                option: option,
                scale: compactScale,
                onChanged: onChanged,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildBackgroundImages(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(
        context,
      ).copyWith(dragDevices: _scrollDragDevices),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ReaderBackgroundImageTile(
              label: '无背景',
              selected: !hasBackgroundImage,
              icon: Icons.hide_image_outlined,
              scale: backgroundTileScale,
              onTap: onClearBackgroundImage,
            ),
            SizedBox(width: _scale(8)),
            ...presetBackgroundTiles.map(
              (tile) => Padding(
                padding: EdgeInsets.only(right: 8 * backgroundTileScale),
                child: ReaderBackgroundImageTile.fromData(
                  tile,
                  scale: backgroundTileScale,
                ),
              ),
            ),
            ...customBackgroundTiles.map(
              (tile) => Padding(
                padding: EdgeInsets.only(right: 8 * backgroundTileScale),
                child: ReaderBackgroundImageTile.fromData(
                  tile,
                  scale: backgroundTileScale,
                ),
              ),
            ),
            ReaderBackgroundImageTile(
              label: '自定义',
              selected: false,
              icon: Icons.upload_file_rounded,
              showLabel: true,
              scale: backgroundTileScale,
              onTap: onApplyCustomBackgroundImage,
            ),
            SizedBox(width: _scale(8)),
            OutlinedButton.icon(
              onPressed: onOpenBackgroundManagement,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('去我的管理'),
            ),
            if (hasBackgroundImage && onRemoveActiveBackground != null) ...[
              SizedBox(width: _scale(8)),
              OutlinedButton(
                onPressed: onRemoveActiveBackground,
                child: const Text('移除'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ReaderThemeBackgroundColorDot extends StatelessWidget {
  const ReaderThemeBackgroundColorDot({
    super.key,
    required this.settings,
    required this.option,
    required this.onChanged,
    this.scale = 1,
  });

  final ReaderSettings settings;
  final ReaderThemeBackgroundColorOption option;
  final ValueChanged<ReaderSettings> onChanged;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final normalizedTone = normalizeReaderBackgroundTone(
      mode: settings.themeMode,
      tone: settings.backgroundTone,
    );
    final selected =
        settings.themeMode == option.mode &&
        settings.backgroundStyle == option.backgroundStyle &&
        normalizedTone == option.backgroundTone;
    final iconColor =
        ThemeData.estimateBrightnessForColor(option.previewColor) ==
                Brightness.dark
            ? Colors.white
            : null;

    return Tooltip(
      message: option.label,
      child: GestureDetector(
        onTap: () {
          onChanged(
            settings.copyWith(
              themeMode: option.mode,
              backgroundStyle: option.backgroundStyle,
              backgroundTone: option.backgroundTone,
              clearBackgroundImage: true,
            ),
          );
        },
        child: Container(
          width: 30 * scale,
          height: 30 * scale,
          margin: EdgeInsets.only(right: 8 * scale),
          decoration: BoxDecoration(
            color: option.previewColor,
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
              width: (selected ? 2 : 1) * scale.clamp(1.0, 1.4),
            ),
          ),
          child:
              selected
                  ? Icon(
                    Icons.check_rounded,
                    size: 14 * scale,
                    color: iconColor,
                  )
                  : null,
        ),
      ),
    );
  }
}

class ReaderBackgroundImageTile extends StatelessWidget {
  const ReaderBackgroundImageTile({
    super.key,
    required this.label,
    required this.selected,
    this.previewBytes,
    this.onTap,
    this.showLabel = true,
    this.icon,
    this.scale = 1,
  });

  factory ReaderBackgroundImageTile.fromData(
    ReaderBackgroundImageTileData data, {
    double scale = 1,
  }) {
    return ReaderBackgroundImageTile(
      label: data.label,
      selected: data.selected,
      previewBytes: data.previewBytes,
      onTap: data.onTap,
      showLabel: data.showLabel,
      icon: data.icon,
      scale: scale,
    );
  }

  final String label;
  final bool selected;
  final Uint8List? previewBytes;
  final VoidCallback? onTap;
  final bool showLabel;
  final IconData? icon;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final image =
        previewBytes == null
            ? null
            : DecorationImage(
              image: MemoryImage(previewBytes!),
              fit: BoxFit.cover,
            );
    final tile = Container(
      width: 72 * scale,
      height: 44 * scale,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(
          color:
              selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
          width: (selected ? 2 : 1) * scale.clamp(1.0, 1.4),
        ),
        image: image,
      ),
      child: _buildContent(context),
    );

    if (onTap == null) {
      return tile;
    }
    return GestureDetector(onTap: onTap, child: tile);
  }

  Widget _buildContent(BuildContext context) {
    if (previewBytes != null) {
      if (!showLabel) {
        return const SizedBox.expand();
      }
      return Container(
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.bottomCenter,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6 * scale),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00000000), Color(0x7A000000)],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: 2 * scale),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontSize:
                  (Theme.of(context).textTheme.labelSmall?.fontSize ?? 11) *
                  scale,
            ),
          ),
        ),
      );
    }

    if (icon != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18 * scale,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            if (showLabel) ...[
              SizedBox(height: 2 * scale),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize:
                      (Theme.of(context).textTheme.labelSmall?.fontSize ?? 11) *
                      scale,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontSize:
            (Theme.of(context).textTheme.labelSmall?.fontSize ?? 11) * scale,
      ),
    );
  }
}

class _CurrentModeSummaryCard extends StatelessWidget {
  const _CurrentModeSummaryCard({
    required this.contentMode,
    required this.compactScale,
  });

  final ReaderContentMode contentMode;
  final double compactScale;

  double _scale(double value) => value * compactScale;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (title, description) = switch (contentMode) {
      ReaderContentMode.text => ('文本阅读模式', '支持字体、信息排版、背景、翻页动画和自动阅读等完整文本能力。'),
      ReaderContentMode.hybrid => ('版式阅读模式', '以固定版式为主，保留界面和位置相关设置，不提供正文排版能力。'),
      ReaderContentMode.comic => ('漫画阅读模式', '以图片阅读为主，保留背景与漫画阅读方式，隐藏正文排版和自动阅读。'),
      ReaderContentMode.audio => ('听书模式', '保留亮度、背景和听书设置，正文排版与翻页动画不参与当前章节。'),
    };
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: _scale(10)),
      padding: EdgeInsets.fromLTRB(
        _scale(12),
        _scale(10),
        _scale(12),
        _scale(10),
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(_scale(16)),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.36),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: _scale(4)),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrightnessFollowChip extends StatelessWidget {
  const _BrightnessFollowChip({
    required this.value,
    required this.compactScale,
    required this.onChanged,
  });

  final bool value;
  final double compactScale;
  final ValueChanged<bool> onChanged;

  double _scale(double value) => value * compactScale;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = colorScheme.primary;
    final inactiveColor = colorScheme.surfaceContainerLow;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: _scale(10),
            vertical: _scale(8),
          ),
          decoration: BoxDecoration(
            color: value ? activeColor.withValues(alpha: 0.12) : inactiveColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  value
                      ? activeColor.withValues(alpha: 0.45)
                      : colorScheme.outlineVariant.withValues(alpha: 0.38),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                value ? Icons.brightness_auto_rounded : Icons.tune_rounded,
                size: _scale(14),
                color: value ? activeColor : colorScheme.onSurfaceVariant,
              ),
              SizedBox(width: _scale(4)),
              Text(
                value ? '跟随' : '手动',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: value ? activeColor : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  fontSize:
                      (Theme.of(context).textTheme.labelMedium?.fontSize ??
                          12) *
                      compactScale *
                      0.95,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InterfaceCapsuleEntry extends StatelessWidget {
  const _InterfaceCapsuleEntry({
    required this.icon,
    required this.title,
    required this.compactScale,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final double compactScale;
  final VoidCallback onTap;

  double _scale(double value) => value * compactScale;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: _scale(8),
            vertical: _scale(6),
          ),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow.withValues(alpha: 0.54),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.38),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _scale(20),
                height: _scale(20),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: _scale(11),
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              SizedBox(width: _scale(6)),
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize:
                        (Theme.of(context).textTheme.bodyMedium?.fontSize ??
                            14) *
                        compactScale *
                        0.86,
                  ),
                ),
              ),
              SizedBox(width: _scale(2)),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
                size: _scale(16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
