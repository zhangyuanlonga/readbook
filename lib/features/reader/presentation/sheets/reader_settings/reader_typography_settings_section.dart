import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../app/theme/app_component_theme_tokens.dart';
import '../../../../../app/widgets/foundation/app_button.dart';
import '../../../../../domain/entities/reader_settings.dart';
import '../../reader_icons.dart';
import '../../widgets/reader_typography_slider_row.dart';
import 'reader_settings_components.dart';

typedef ReaderSettingsColorPicker =
    Future<int?> Function(BuildContext context, int? initialColorValue);

class ReaderTypographySettingsPanel extends StatelessWidget {
  const ReaderTypographySettingsPanel({
    super.key,
    required this.settings,
    required this.currentFontLabel,
    required this.fontWeightLabel,
    required this.compactScale,
    required this.sliderBuilder,
    required this.onChanged,
    required this.onOpenFontPicker,
    required this.onManageFonts,
    required this.onOpenFontWeightSheet,
    required this.onPickBodyTextColor,
    required this.onRememberBodyTextColor,
    required this.onPickBodyTextShadowColor,
    required this.onPickBodyTextDecorationColor,
  });

  final ReaderSettings settings;
  final String currentFontLabel;
  final String fontWeightLabel;
  final double compactScale;
  final ReaderPreviewAwareSliderBuilder sliderBuilder;
  final ValueChanged<ReaderSettings> onChanged;
  final VoidCallback onOpenFontPicker;
  final VoidCallback onManageFonts;
  final VoidCallback onOpenFontWeightSheet;
  final ReaderSettingsColorPicker onPickBodyTextColor;
  final Future<void> Function(int colorValue) onRememberBodyTextColor;
  final ReaderSettingsColorPicker onPickBodyTextShadowColor;
  final ReaderSettingsColorPicker onPickBodyTextDecorationColor;

  double _scale(double value) => value * compactScale;

  @override
  Widget build(BuildContext context) {
    return ReaderSettingsCard(
      compactScale: compactScale,
      children: [
        ReaderSettingsLabeledRow(
          label: '字体',
          compactScale: compactScale,
          child: Row(
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: _scale(180)),
                  child: _ReaderSettingsSecondaryCapsule(
                    icon: ReaderIcons.fontLibrary,
                    title: currentFontLabel,
                    compactScale: compactScale,
                    onTap: onOpenFontPicker,
                  ),
                ),
              ),
              SizedBox(width: _scale(8)),
              _ReaderSettingsIconCapsule(
                icon: ReaderIcons.fontManage,
                tooltip: '管理字体',
                compactScale: compactScale,
                onTap: onManageFonts,
              ),
            ],
          ),
        ),
        ReaderSettingsDivider(compactScale: compactScale),
        ReaderSettingsLabeledRow(
          label: '字重',
          compactScale: compactScale,
          child: _ReaderSettingsSecondaryCapsule(
            icon: ReaderIcons.fontWeight,
            title: fontWeightLabel,
            compactScale: compactScale,
            onTap: onOpenFontWeightSheet,
          ),
        ),
        ReaderSettingsDivider(compactScale: compactScale),
        ReaderSettingsLabeledRow(
          label: '字号',
          compactScale: compactScale,
          child: _FontSizeStepper(
            settings: settings,
            compactScale: compactScale,
            onChanged: onChanged,
          ),
        ),
        ReaderSettingsDivider(compactScale: compactScale),
        _ColorSettingRow(
          label: '字体颜色',
          currentColorValue: settings.bodyTextColorValue,
          compactScale: compactScale,
          onReset: () {
            onChanged(settings.copyWith(clearBodyTextColor: true));
          },
          onPick: () async {
            final selected = await onPickBodyTextColor(
              context,
              settings.bodyTextColorValue,
            );
            if (selected == null || !context.mounted) {
              return;
            }
            onChanged(settings.copyWith(bodyTextColorValue: selected));
            unawaited(onRememberBodyTextColor(selected));
          },
        ),
        ReaderSettingsDivider(compactScale: compactScale),
        _TextStyleChips(
          settings: settings,
          compactScale: compactScale,
          onChanged: onChanged,
        ),
        if (settings.bodyTextShadowEnabled) ...[
          ReaderSettingsDivider(compactScale: compactScale),
          _ColorSettingRow(
            label: '阴影颜色',
            currentColorValue: settings.bodyTextShadowColorValue,
            compactScale: compactScale,
            resetLabel: '清空',
            onReset: () {
              onChanged(settings.copyWith(bodyTextShadowColorValue: null));
            },
            onPick: () async {
              final selected = await onPickBodyTextShadowColor(
                context,
                settings.bodyTextShadowColorValue,
              );
              if (selected == null || !context.mounted) {
                return;
              }
              onChanged(settings.copyWith(bodyTextShadowColorValue: selected));
            },
          ),
          _TypographySlider(
            label: '模糊',
            value: settings.bodyTextShadowBlurRadius,
            min: 0,
            max: 32,
            divisions: 32,
            step: 1,
            valueLabel: settings.bodyTextShadowBlurRadius.round().toString(),
            compactScale: compactScale,
            sliderBuilder: sliderBuilder,
            onChanged:
                (value) => onChanged(
                  settings.copyWith(bodyTextShadowBlurRadius: value),
                ),
          ),
          _TypographySlider(
            label: 'X轴',
            value: settings.bodyTextShadowOffsetDx,
            min: -24,
            max: 24,
            divisions: 48,
            step: 1,
            valueLabel: settings.bodyTextShadowOffsetDx.toStringAsFixed(0),
            compactScale: compactScale,
            sliderBuilder: sliderBuilder,
            onChanged:
                (value) =>
                    onChanged(settings.copyWith(bodyTextShadowOffsetDx: value)),
          ),
          _TypographySlider(
            label: 'Y轴',
            value: settings.bodyTextShadowOffsetDy,
            min: -24,
            max: 24,
            divisions: 48,
            step: 1,
            valueLabel: settings.bodyTextShadowOffsetDy.toStringAsFixed(0),
            compactScale: compactScale,
            sliderBuilder: sliderBuilder,
            onChanged:
                (value) =>
                    onChanged(settings.copyWith(bodyTextShadowOffsetDy: value)),
          ),
        ],
        ReaderSettingsDivider(compactScale: compactScale),
        _UnderlineStyleChips(
          settings: settings,
          compactScale: compactScale,
          onChanged: onChanged,
        ),
        if (settings.bodyTextDecorationStyle !=
            ReaderBodyTextDecorationStyle.none) ...[
          ReaderSettingsDivider(compactScale: compactScale),
          _ColorSettingRow(
            label: '划线颜色',
            currentColorValue: settings.bodyTextDecorationColorValue,
            compactScale: compactScale,
            resetLabel: '跟随',
            onReset: () {
              onChanged(settings.copyWith(clearBodyTextDecorationColor: true));
            },
            onPick: () async {
              final selected = await onPickBodyTextDecorationColor(
                context,
                settings.bodyTextDecorationColorValue,
              );
              if (selected == null || !context.mounted) {
                return;
              }
              onChanged(
                settings.copyWith(bodyTextDecorationColorValue: selected),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _FontSizeStepper extends StatelessWidget {
  const _FontSizeStepper({
    required this.settings,
    required this.compactScale,
    required this.onChanged,
  });

  final ReaderSettings settings;
  final double compactScale;
  final ValueChanged<ReaderSettings> onChanged;

  double _scale(double value) => value * compactScale;

  @override
  Widget build(BuildContext context) {
    return _ReaderSettingsInlineCapsule(
      compactScale: compactScale,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: _scale(38),
        child: Row(
          children: [
            SizedBox(width: _scale(6)),
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: BoxConstraints(
                minWidth: _scale(26),
                minHeight: _scale(26),
              ),
              padding: EdgeInsets.zero,
              onPressed: () {
                final next = (settings.fontSize - 1).clamp(5, 50).toDouble();
                onChanged(settings.copyWith(fontSize: next));
              },
              icon: Icon(Icons.remove_rounded, size: _scale(15)),
            ),
            Expanded(
              child: Center(
                child: Text(
                  settings.fontSize.toStringAsFixed(0),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1,
                    fontSize:
                        (Theme.of(context).textTheme.bodyMedium?.fontSize ??
                            14) *
                        compactScale *
                        0.95,
                  ),
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: BoxConstraints(
                minWidth: _scale(26),
                minHeight: _scale(26),
              ),
              padding: EdgeInsets.zero,
              onPressed: () {
                final next = (settings.fontSize + 1).clamp(5, 50).toDouble();
                onChanged(settings.copyWith(fontSize: next));
              },
              icon: Icon(Icons.add_rounded, size: _scale(15)),
            ),
            SizedBox(width: _scale(6)),
          ],
        ),
      ),
    );
  }
}

class _TextStyleChips extends StatelessWidget {
  const _TextStyleChips({
    required this.settings,
    required this.compactScale,
    required this.onChanged,
  });

  final ReaderSettings settings;
  final double compactScale;
  final ValueChanged<ReaderSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return ReaderSettingsLabeledRow(
      label: '样式',
      compactScale: compactScale,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              label: const Text('斜体'),
              selected: settings.bodyTextItalicEnabled,
              showCheckmark: false,
              onSelected:
                  (selected) => onChanged(
                    settings.copyWith(bodyTextItalicEnabled: selected),
                  ),
            ),
            SizedBox(width: 8 * compactScale),
            FilterChip(
              label: const Text('阴影'),
              selected: settings.bodyTextShadowEnabled,
              showCheckmark: false,
              onSelected:
                  (selected) => onChanged(
                    settings.copyWith(bodyTextShadowEnabled: selected),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnderlineStyleChips extends StatelessWidget {
  const _UnderlineStyleChips({
    required this.settings,
    required this.compactScale,
    required this.onChanged,
  });

  final ReaderSettings settings;
  final double compactScale;
  final ValueChanged<ReaderSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return ReaderSettingsLabeledRow(
      label: '下划线',
      compactScale: compactScale,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              label: const Text('下划线'),
              selected:
                  settings.bodyTextDecorationStyle !=
                  ReaderBodyTextDecorationStyle.none,
              showCheckmark: false,
              onSelected: (selected) {
                onChanged(
                  settings.copyWith(
                    bodyTextDecorationStyle:
                        selected
                            ? ReaderBodyTextDecorationStyle.solid
                            : ReaderBodyTextDecorationStyle.none,
                    bodyTextUnderlineThickness:
                        ReaderSettings.defaultBodyTextUnderlineThickness,
                    bodyTextUnderlineGap:
                        ReaderSettings.defaultBodyTextUnderlineGap,
                    bodyTextUnderlineDashLength:
                        ReaderSettings.defaultBodyTextUnderlineDashLength,
                    bodyTextUnderlineDashGapRatio:
                        ReaderSettings.defaultBodyTextUnderlineDashGapRatio,
                  ),
                );
              },
            ),
            SizedBox(width: 8 * compactScale),
            FilterChip(
              label: const Text('虚线'),
              selected:
                  settings.bodyTextDecorationStyle ==
                  ReaderBodyTextDecorationStyle.dashed,
              showCheckmark: false,
              onSelected:
                  settings.bodyTextDecorationStyle ==
                          ReaderBodyTextDecorationStyle.none
                      ? null
                      : (selected) {
                        onChanged(
                          settings.copyWith(
                            bodyTextDecorationStyle:
                                selected
                                    ? ReaderBodyTextDecorationStyle.dashed
                                    : ReaderBodyTextDecorationStyle.solid,
                            bodyTextUnderlineThickness:
                                ReaderSettings
                                    .defaultBodyTextUnderlineThickness,
                            bodyTextUnderlineGap:
                                ReaderSettings.defaultBodyTextUnderlineGap,
                            bodyTextUnderlineDashLength:
                                ReaderSettings
                                    .defaultBodyTextUnderlineDashLength,
                            bodyTextUnderlineDashGapRatio:
                                ReaderSettings
                                    .defaultBodyTextUnderlineDashGapRatio,
                          ),
                        );
                      },
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorSettingRow extends StatelessWidget {
  const _ColorSettingRow({
    required this.label,
    required this.currentColorValue,
    required this.onReset,
    required this.onPick,
    required this.compactScale,
    this.resetLabel = '跟随',
  });

  final String label;
  final int? currentColorValue;
  final VoidCallback onReset;
  final Future<void> Function() onPick;
  final double compactScale;
  final String resetLabel;

  double _scale(double value) => value * compactScale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: _scale(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _scale(68),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize:
                    (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) *
                    compactScale *
                    0.92,
              ),
            ),
          ),
          SizedBox(width: _scale(10)),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  AppButton(
                    variant: AppButtonVariant.secondary,
                    onPressed: onReset,
                    label: resetLabel,
                  ),
                  SizedBox(width: _scale(8)),
                  AppButton(
                    variant: AppButtonVariant.tonal,
                    onPressed: () => unawaited(onPick()),
                    icon: const Icon(Icons.colorize_rounded, size: 16),
                    label: '颜色',
                  ),
                  if (currentColorValue != null) ...[
                    SizedBox(width: _scale(8)),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Color(currentColorValue!),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypographySlider extends StatelessWidget {
  const _TypographySlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.compactScale,
    required this.sliderBuilder,
    required this.onChanged,
    this.step = 1,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final double compactScale;
  final double step;
  final ReaderPreviewAwareSliderBuilder sliderBuilder;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return ReaderTypographySliderRow(
      label: label,
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      valueLabel: valueLabel,
      onChanged: onChanged,
      compactSheetScale: compactScale,
      step: step,
      sliderBuilder: sliderBuilder,
    );
  }
}

class _ReaderSettingsSecondaryCapsule extends StatelessWidget {
  const _ReaderSettingsSecondaryCapsule({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.compactScale,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final double compactScale;

  double _scale(double value) => value * compactScale;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final componentTokens = appComponentThemeTokensOf(context);
    return _ReaderSettingsInlineCapsule(
      compactScale: compactScale,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: _scale(38),
        child: InkWell(
          onTap: onTap,
          // UI-GOV-EXEMPT: hardcoded-style reader-settings capsule radius follows component token with density scaling.
          borderRadius: BorderRadius.circular(
            componentTokens.selection.segmentRadius,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _scale(8),
              vertical: _scale(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: _scale(20),
                  height: _scale(20),
                  // UI-GOV-EXEMPT: hardcoded-style reader-settings icon chip is a compact local affordance inside a tokenized capsule.
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
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      // UI-GOV-EXEMPT: hardcoded-style reader-settings compactScale mirrors the sheet density slider.
                      fontSize:
                          (Theme.of(context).textTheme.bodyMedium?.fontSize ??
                              14) *
                          compactScale *
                          0.88,
                    ),
                  ),
                ),
                SizedBox(width: _scale(2)),
                Icon(
                  Icons.chevron_right_rounded,
                  size: _scale(14),
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderSettingsIconCapsule extends StatelessWidget {
  const _ReaderSettingsIconCapsule({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.compactScale,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double compactScale;

  double _scale(double value) => value * compactScale;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _ReaderSettingsInlineCapsule(
      compactScale: compactScale,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: _scale(38),
        width: _scale(38),
        child: IconButton(
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          onPressed: onTap,
          icon: Icon(
            icon,
            size: _scale(16),
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ReaderSettingsInlineCapsule extends StatelessWidget {
  const _ReaderSettingsInlineCapsule({
    required this.child,
    required this.compactScale,
    this.padding,
  });

  final Widget child;
  final double compactScale;
  final EdgeInsetsGeometry? padding;

  double _scale(double value) => value * compactScale;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding:
          padding ??
          EdgeInsets.symmetric(horizontal: _scale(12), vertical: _scale(8)),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.38),
        ),
      ),
      child: child,
    );
  }
}
