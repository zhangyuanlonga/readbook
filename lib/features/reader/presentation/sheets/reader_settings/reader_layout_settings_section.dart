import 'package:flutter/material.dart';

import '../../../../../app/widgets/foundation/app_button.dart';
import '../../../../../domain/entities/reader_settings.dart';
import '../../../application/reader_settings_groups.dart';
import '../../reader_icons.dart';
import '../../widgets/reader_typography_slider_row.dart';
import 'reader_settings_components.dart';

typedef ReaderLineHeightFromSlider =
    double Function({
      required double sliderValue,
      required ReaderSettings settings,
    });

class ReaderLayoutInfoSettingsPanel extends StatelessWidget {
  const ReaderLayoutInfoSettingsPanel({
    super.key,
    required this.settings,
    required this.groups,
    required this.compactScale,
    required this.marginControlStep,
    required this.sliderBuilder,
    required this.onChanged,
    required this.formatLayoutMarginValue,
    required this.letterSpacingSliderValue,
    required this.letterSpacingValueLabel,
    required this.letterSpacingFromSliderValue,
    required this.lineHeightSliderValue,
    required this.lineHeightValueLabel,
    required this.lineHeightFromSliderValue,
    required this.paragraphSpacingValueLabel,
    required this.paragraphIndentValueLabel,
    required this.readerBatteryReadFailed,
  });

  final ReaderSettings settings;
  final ReaderSettingsGroups groups;
  final double compactScale;
  final double marginControlStep;
  final ReaderPreviewAwareSliderBuilder sliderBuilder;
  final ValueChanged<ReaderSettings> onChanged;
  final String Function(double value) formatLayoutMarginValue;
  final double Function(ReaderSettings settings) letterSpacingSliderValue;
  final String Function(ReaderSettings settings) letterSpacingValueLabel;
  final double Function(double sliderValue) letterSpacingFromSliderValue;
  final double Function(ReaderSettings settings) lineHeightSliderValue;
  final String Function(ReaderSettings settings) lineHeightValueLabel;
  final ReaderLineHeightFromSlider lineHeightFromSliderValue;
  final String Function(ReaderSettings settings) paragraphSpacingValueLabel;
  final String Function(ReaderSettings settings) paragraphIndentValueLabel;
  final bool readerBatteryReadFailed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildBodyMarginCard(context),
        _buildReadingLayoutCard(context),
        _buildChapterHeaderCard(context),
        _buildInfoFooterCard(context),
      ],
    );
  }

  Widget _buildBodyMarginCard(BuildContext context) {
    final marginDivisions =
        ((ReaderSettings.maxLayoutMargin - ReaderSettings.minLayoutMargin) /
                marginControlStep)
            .round();
    final effectiveMargins = settings.effectiveBodyMarginValues;
    return _SettingsCard(
      compactScale: compactScale,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionTitle('正文边距')),
            AppButton(
              variant: AppButtonVariant.text,
              size: AppButtonSize.compact,
              onPressed: () {
                onChanged(
                  settings.copyWith(
                    bodyMarginTop: 6,
                    bodyMarginBottom: 6,
                    bodyMarginLeft: 16,
                    bodyMarginRight: 16,
                  ),
                );
              },
              icon: const Icon(ReaderIcons.reset, size: 16),
              label: '恢复默认',
            ),
          ],
        ),
        Text(
          '当前：上 ${groups.bodyLayout.bodyMarginTop.toStringAsFixed(0)} / 下 ${groups.bodyLayout.bodyMarginBottom.toStringAsFixed(0)} / 左 ${groups.bodyLayout.bodyMarginLeft.toStringAsFixed(0)} / 右 ${groups.bodyLayout.bodyMarginRight.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        _slider(
          label: '上',
          min: ReaderSettings.minLayoutMargin,
          max: ReaderSettings.maxLayoutMargin,
          divisions: marginDivisions,
          value: settings.bodyMarginTop,
          step: marginControlStep,
          valueLabel: formatLayoutMarginValue(settings.bodyMarginTop),
          valueLabelBuilder: formatLayoutMarginValue,
          deferChangedUntilEnd: true,
          onChanged:
              (value) => onChanged(settings.copyWith(bodyMarginTop: value)),
        ),
        _slider(
          label: '下',
          min: ReaderSettings.minLayoutMargin,
          max: ReaderSettings.maxLayoutMargin,
          divisions: marginDivisions,
          value: settings.bodyMarginBottom,
          step: marginControlStep,
          valueLabel: formatLayoutMarginValue(settings.bodyMarginBottom),
          valueLabelBuilder: formatLayoutMarginValue,
          deferChangedUntilEnd: true,
          onChanged:
              (value) => onChanged(settings.copyWith(bodyMarginBottom: value)),
        ),
        _slider(
          label: '左',
          min: ReaderSettings.minLayoutMargin,
          max: ReaderSettings.maxLayoutMargin,
          divisions: marginDivisions,
          value: settings.bodyMarginLeft,
          step: marginControlStep,
          valueLabel: formatLayoutMarginValue(settings.bodyMarginLeft),
          valueLabelBuilder: formatLayoutMarginValue,
          deferChangedUntilEnd: true,
          onChanged:
              (value) => onChanged(settings.copyWith(bodyMarginLeft: value)),
        ),
        _slider(
          label: '右',
          min: ReaderSettings.minLayoutMargin,
          max: ReaderSettings.maxLayoutMargin,
          divisions: marginDivisions,
          value: settings.bodyMarginRight,
          step: marginControlStep,
          valueLabel: formatLayoutMarginValue(settings.bodyMarginRight),
          valueLabelBuilder: formatLayoutMarginValue,
          deferChangedUntilEnd: true,
          onChanged:
              (value) => onChanged(settings.copyWith(bodyMarginRight: value)),
        ),
        const SizedBox(height: 8),
        Text(
          '当前正文边距：上 ${effectiveMargins.top.round()} / 下 ${effectiveMargins.bottom.round()} / 左 ${effectiveMargins.left.round()} / 右 ${effectiveMargins.right.round()}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildReadingLayoutCard(BuildContext context) {
    return _SettingsCard(
      compactScale: compactScale,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionTitle('阅读排版')),
            AppButton(
              variant: AppButtonVariant.text,
              size: AppButtonSize.compact,
              onPressed: () {
                onChanged(
                  settings.copyWith(
                    lineHeight: 1.67,
                    paragraphSpacing: 2,
                    paragraphIndent: 2,
                    letterSpacing: ReaderSettings.defaultLetterSpacing,
                  ),
                );
              },
              icon: const Icon(ReaderIcons.reset, size: 16),
              label: '恢复默认',
            ),
          ],
        ),
        const SizedBox(height: 10),
        _slider(
          label: '字距',
          min: 0,
          max: 100,
          divisions: 100,
          value: letterSpacingSliderValue(settings),
          step: 1,
          valueLabel: letterSpacingValueLabel(settings),
          onChanged:
              (value) => onChanged(
                settings.copyWith(
                  letterSpacing: letterSpacingFromSliderValue(value),
                ),
              ),
        ),
        _slider(
          label: '行距',
          min: 0,
          max: 20,
          divisions: 20,
          value: lineHeightSliderValue(settings),
          step: 1,
          valueLabel: lineHeightValueLabel(settings),
          onChanged:
              (value) => onChanged(
                settings.copyWith(
                  lineHeight: lineHeightFromSliderValue(
                    sliderValue: value,
                    settings: settings,
                  ),
                ),
              ),
        ),
        _slider(
          label: '段距',
          min: 0,
          max: 20,
          divisions: 20,
          value: settings.paragraphSpacing,
          step: 1,
          valueLabel: paragraphSpacingValueLabel(settings),
          onChanged:
              (value) => onChanged(settings.copyWith(paragraphSpacing: value)),
        ),
        _slider(
          label: '缩进',
          min: 0,
          max: 4,
          divisions: 4,
          value: settings.paragraphIndent.clamp(0, 4).toDouble(),
          step: 1,
          valueLabel: paragraphIndentValueLabel(settings),
          onChanged:
              (value) => onChanged(
                settings.copyWith(
                  paragraphIndent: value.round().clamp(0, 4).toDouble(),
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildChapterHeaderCard(BuildContext context) {
    return _SettingsCard(
      compactScale: compactScale,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionTitle('章节头')),
            AppButton(
              variant: AppButtonVariant.text,
              size: AppButtonSize.compact,
              onPressed: () {
                onChanged(
                  settings.copyWith(
                    chapterHeaderHorizontalOffset: 0,
                    chapterHeaderVerticalOffset: 0,
                  ),
                );
              },
              icon: const Icon(ReaderIcons.reset, size: 16),
              label: '恢复默认',
            ),
          ],
        ),
        const SizedBox(height: 10),
        _slider(
          label: '横向',
          min: ReaderSettings.minPinnedHeaderOffsetX,
          max: ReaderSettings.maxPinnedHeaderOffsetX,
          divisions: 100,
          value: settings.chapterHeaderHorizontalOffset,
          step: 0.01,
          valueLabel:
              (settings.chapterHeaderHorizontalOffset * 100).round().toString(),
          valueLabelBuilder: (value) => (value * 100).round().toString(),
          deferChangedUntilEnd: true,
          onChanged:
              (value) => onChanged(
                settings.copyWith(chapterHeaderHorizontalOffset: value),
              ),
        ),
        _slider(
          label: '纵向',
          min: ReaderSettings.minChapterHeaderVerticalOffset,
          max: ReaderSettings.maxChapterHeaderSpacing,
          divisions:
              (ReaderSettings.maxChapterHeaderSpacing -
                      ReaderSettings.minChapterHeaderVerticalOffset)
                  .round(),
          value: settings.chapterHeaderVerticalOffset,
          step: 1,
          valueLabel: settings.chapterHeaderVerticalOffset.round().toString(),
          valueLabelBuilder: (value) => value.round().toString(),
          deferChangedUntilEnd: true,
          onChanged:
              (value) => onChanged(
                settings.copyWith(chapterHeaderVerticalOffset: value),
              ),
        ),
      ],
    );
  }

  Widget _buildInfoFooterCard(BuildContext context) {
    return _SettingsCard(
      compactScale: compactScale,
      children: [
        const _SectionTitle('信息位'),
        const SizedBox(height: 10),
        ReaderSettingsToggleRow(
          label: '显示页脚',
          value: settings.infoFooterEnabled,
          compactScale: compactScale,
          onChanged: (enabled) {
            onChanged(
              settings.copyWith(
                infoFooterEnabled: enabled,
                infoFooterDividerEnabled:
                    enabled ? settings.infoFooterDividerEnabled : false,
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _InfoVisibilityChips(settings: settings, onChanged: onChanged),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(child: _SectionTitle('页脚边距')),
            AppButton(
              variant: AppButtonVariant.text,
              size: AppButtonSize.compact,
              onPressed: () {
                const defaults = ReaderSettings();
                onChanged(
                  settings.copyWith(
                    infoFooterPadding: defaults.infoFooterPadding,
                    infoFooterMarginTop: defaults.infoFooterMarginTop,
                    infoFooterMarginBottom: defaults.infoFooterMarginBottom,
                    infoFooterMarginLeft: defaults.infoFooterMarginLeft,
                    infoFooterMarginRight: defaults.infoFooterMarginRight,
                    infoFooterDividerEnabled: false,
                  ),
                );
              },
              icon: const Icon(ReaderIcons.reset, size: 16),
              label: '恢复默认',
            ),
          ],
        ),
        const SizedBox(height: 8),
        _footerMarginSlider(
          label: '顶部',
          value: settings.infoFooterMarginTop,
          onChanged:
              (value) =>
                  onChanged(settings.copyWith(infoFooterMarginTop: value)),
        ),
        _footerMarginSlider(
          label: '底部',
          value: settings.infoFooterMarginBottom,
          onChanged:
              (value) =>
                  onChanged(settings.copyWith(infoFooterMarginBottom: value)),
        ),
        _footerHorizontalMarginSlider(
          label: '左侧',
          value: settings.infoFooterMarginLeft,
          onChanged:
              (value) =>
                  onChanged(settings.copyWith(infoFooterMarginLeft: value)),
        ),
        _footerHorizontalMarginSlider(
          label: '右侧',
          value: settings.infoFooterMarginRight,
          onChanged:
              (value) =>
                  onChanged(settings.copyWith(infoFooterMarginRight: value)),
        ),
        const SizedBox(height: 10),
        Text(
          '页脚边距控制整条页脚相对阅读区域的位置：顶部增大会向下移动，底部增大会向上移动，左侧增大会向右移动，右侧增大会向左移动。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        if (settings.infoShowBattery) ...[
          const SizedBox(height: 6),
          Text(
            readerBatteryReadFailed
                ? '当前平台未返回电量值，已显示为 N/A。'
                : '电量为实时读取，约每 30 秒刷新一次。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _footerMarginSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return _slider(
      label: label,
      min: ReaderSettings.minLayoutMargin,
      max: ReaderSettings.maxLayoutMargin,
      divisions:
          ReaderSettings.maxLayoutMargin.toInt() -
          ReaderSettings.minLayoutMargin.toInt(),
      value: value,
      step: 1,
      valueLabel: value.round().toString(),
      valueLabelBuilder: (value) => value.round().toString(),
      deferChangedUntilEnd: true,
      onChanged: onChanged,
    );
  }

  Widget _footerHorizontalMarginSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return _slider(
      label: label,
      min: ReaderSettings.minLayoutMargin,
      max: ReaderSettings.maxInfoFooterHorizontalMargin,
      divisions:
          ReaderSettings.maxInfoFooterHorizontalMargin.toInt() -
          ReaderSettings.minLayoutMargin.toInt(),
      value: value,
      step: 1,
      valueLabel: value.round().toString(),
      valueLabelBuilder: (value) => value.round().toString(),
      deferChangedUntilEnd: true,
      onChanged: onChanged,
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String valueLabel,
    required ValueChanged<double> onChanged,
    double step = 1,
    bool deferChangedUntilEnd = false,
    String Function(double value)? valueLabelBuilder,
  }) {
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
      deferChangedUntilEnd: deferChangedUntilEnd,
      valueLabelBuilder: valueLabelBuilder,
      sliderBuilder: sliderBuilder,
    );
  }
}

class _InfoVisibilityChips extends StatelessWidget {
  const _InfoVisibilityChips({required this.settings, required this.onChanged});

  final ReaderSettings settings;
  final ValueChanged<ReaderSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: const Text('时间'),
          selected: settings.infoShowTime,
          onSelected: (selected) {
            onChanged(
              settings.copyWith(
                infoShowTime: selected,
                infoShowProgress:
                    !selected &&
                            !settings.infoShowBattery &&
                            !settings.infoShowProgress
                        ? true
                        : settings.infoShowProgress,
              ),
            );
          },
        ),
        FilterChip(
          label: const Text('电量'),
          selected: settings.infoShowBattery,
          onSelected: (selected) {
            onChanged(
              settings.copyWith(
                infoShowBattery: selected,
                infoShowProgress:
                    !selected &&
                            !settings.infoShowTime &&
                            !settings.infoShowProgress
                        ? true
                        : settings.infoShowProgress,
              ),
            );
          },
        ),
        FilterChip(
          label: const Text('进度'),
          selected: settings.infoShowProgress,
          onSelected: (selected) {
            onChanged(
              settings.copyWith(
                infoShowProgress:
                    selected ||
                            (!settings.infoShowTime &&
                                !settings.infoShowBattery)
                        ? true
                        : selected,
              ),
            );
          },
        ),
        FilterChip(
          label: const Text('章节'),
          selected: settings.infoShowChapter,
          onSelected:
              (selected) =>
                  onChanged(settings.copyWith(infoShowChapter: selected)),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children, required this.compactScale});

  final List<Widget> children;
  final double compactScale;

  @override
  Widget build(BuildContext context) {
    return ReaderSettingsCard(compactScale: compactScale, children: children);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return ReaderSettingsCompactTitle(title: title);
  }
}
