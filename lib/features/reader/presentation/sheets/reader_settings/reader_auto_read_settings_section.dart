import 'package:flutter/material.dart';

import '../../../../../domain/entities/reader_settings.dart';
import '../../widgets/reader_typography_slider_row.dart';
import 'reader_settings_components.dart';

class ReaderAutoReadSettingsPanel extends StatelessWidget {
  const ReaderAutoReadSettingsPanel({
    super.key,
    required this.settings,
    required this.compactScale,
    required this.sliderBuilder,
    required this.startAfterApply,
    required this.resolvePagedHoldDuration,
    required this.onStartAfterApplyChanged,
    required this.onChanged,
  });

  final ReaderSettings settings;
  final double compactScale;
  final ReaderPreviewAwareSliderBuilder sliderBuilder;
  final bool startAfterApply;
  final Duration Function({required int speedLevel}) resolvePagedHoldDuration;
  final ValueChanged<bool> onStartAfterApplyChanged;
  final ValueChanged<ReaderSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return ReaderSettingsCard(
      compactScale: compactScale,
      children: [
        ReaderSettingsCompactTitle(title: '自动阅读', compactScale: compactScale),
        const SizedBox(height: 10),
        ReaderSettingsCompactTitle(title: '翻页方式', compactScale: compactScale),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('自动滚动'),
              selected: settings.autoReadMode == ReaderAutoReadMode.scroll,
              onSelected:
                  (_) => onChanged(
                    settings.copyWith(autoReadMode: ReaderAutoReadMode.scroll),
                  ),
            ),
            ChoiceChip(
              label: const Text('自动翻页'),
              selected: settings.autoReadMode == ReaderAutoReadMode.page,
              onSelected:
                  (_) => onChanged(
                    settings.copyWith(autoReadMode: ReaderAutoReadMode.page),
                  ),
            ),
          ],
        ),
        ReaderSettingsDivider(compactScale: compactScale),
        Row(
          children: [
            Expanded(
              child: Text(
                startAfterApply ? '关闭弹窗后立即启动自动阅读' : '本次不启动自动阅读',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Switch.adaptive(
              value: startAfterApply,
              onChanged: onStartAfterApplyChanged,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _speedDescription(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        sliderBuilder(
          min: ReaderSettings.minAutoReadSpeedLevel.toDouble(),
          max: ReaderSettings.maxAutoReadSpeedLevel.toDouble(),
          divisions:
              ReaderSettings.maxAutoReadSpeedLevel -
              ReaderSettings.minAutoReadSpeedLevel,
          label: '${settings.autoReadSpeedLevel}',
          value: settings.autoReadSpeedLevel.toDouble(),
          onChanged:
              (value) => onChanged(
                settings.copyWith(autoReadSpeedLevel: value.round()),
              ),
        ),
        ReaderSettingsDivider(compactScale: compactScale),
        ReaderSettingsCompactTitle(title: '停顿模式', compactScale: compactScale),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final mode in ReaderAutoReadPauseMode.values)
              ChoiceChip(
                label: Text(_pauseModeLabel(mode)),
                selected: settings.autoReadPauseMode == mode,
                onSelected:
                    (_) =>
                        onChanged(settings.copyWith(autoReadPauseMode: mode)),
              ),
          ],
        ),
        ReaderSettingsDivider(compactScale: compactScale),
        ReaderSettingsCompactTitle(title: '结束后', compactScale: compactScale),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final behavior in ReaderAutoReadEndBehavior.values)
              ChoiceChip(
                label: Text(_endBehaviorLabel(behavior)),
                selected: settings.autoReadEndBehavior == behavior,
                onSelected:
                    (_) => onChanged(
                      settings.copyWith(autoReadEndBehavior: behavior),
                    ),
              ),
          ],
        ),
      ],
    );
  }

  String _speedDescription() {
    if (settings.autoReadMode == ReaderAutoReadMode.scroll) {
      return '速度 ${settings.autoReadSpeedLevel} 档 · ${settings.autoReadSpeed.round()} px/s';
    }
    final seconds =
        resolvePagedHoldDuration(
          speedLevel: settings.autoReadSpeedLevel,
        ).inMilliseconds /
        1000;
    return '速度 ${settings.autoReadSpeedLevel} 档 · ${seconds.toStringAsFixed(1)} 秒/页';
  }

  String _pauseModeLabel(ReaderAutoReadPauseMode mode) {
    return switch (mode) {
      ReaderAutoReadPauseMode.none => '不停顿',
      ReaderAutoReadPauseMode.chapterEnd => '章节结束',
      ReaderAutoReadPauseMode.paragraphEnd => '段落结束',
    };
  }

  String _endBehaviorLabel(ReaderAutoReadEndBehavior behavior) {
    return switch (behavior) {
      ReaderAutoReadEndBehavior.stop => '停止',
      ReaderAutoReadEndBehavior.loopBook => '循环本书',
      ReaderAutoReadEndBehavior.nextBook => '下一本书',
    };
  }
}
