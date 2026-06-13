import 'package:flutter/material.dart';

import '../../../../../domain/entities/reader_settings.dart';
import '../../widgets/reader_typography_slider_row.dart';
import 'reader_settings_components.dart';

class ReaderAudioSettingsPanel extends StatelessWidget {
  const ReaderAudioSettingsPanel({
    super.key,
    required this.settings,
    required this.compactScale,
    required this.sliderBuilder,
    required this.isVolumeKeyPagingSupported,
    required this.onChanged,
  });

  final ReaderSettings settings;
  final double compactScale;
  final ReaderPreviewAwareSliderBuilder sliderBuilder;
  final bool isVolumeKeyPagingSupported;
  final ValueChanged<ReaderSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return ReaderSettingsCard(
      compactScale: compactScale,
      children: [
        ReaderSettingsCompactTitle(title: '听书设置', compactScale: compactScale),
        const SizedBox(height: 10),
        ReaderSettingsToggleRow(
          label: '自动续播',
          value: settings.audioAutoPlay,
          compactScale: compactScale,
          onChanged:
              (enabled) => onChanged(settings.copyWith(audioAutoPlay: enabled)),
        ),
        const SizedBox(height: 12),
        ReaderSettingsToggleRow(
          label: '记忆倍速',
          value: settings.audioRememberSpeed,
          compactScale: compactScale,
          onChanged:
              (enabled) =>
                  onChanged(settings.copyWith(audioRememberSpeed: enabled)),
        ),
        const SizedBox(height: 12),
        ReaderTypographySliderRow(
          label: '默认倍速',
          min: ReaderSettings.minAudioSpeed,
          max: ReaderSettings.maxAudioSpeed,
          divisions: 10,
          step: 0.25,
          value: settings.audioDefaultSpeed,
          valueLabel: '${settings.audioDefaultSpeed.toStringAsFixed(2)}x',
          compactSheetScale: compactScale,
          sliderBuilder: sliderBuilder,
          onChanged:
              (value) => onChanged(
                settings.copyWith(audioDefaultSpeed: (value * 4).round() / 4),
              ),
        ),
        ReaderTypographySliderRow(
          label: '快进/退',
          min: ReaderSettings.minAudioSeekStepSeconds.toDouble(),
          max: ReaderSettings.maxAudioSeekStepSeconds.toDouble(),
          divisions:
              (ReaderSettings.maxAudioSeekStepSeconds -
                  ReaderSettings.minAudioSeekStepSeconds) ~/
              5,
          step: 5,
          value: settings.audioSeekStepSeconds.toDouble(),
          valueLabel: '${settings.audioSeekStepSeconds} 秒',
          compactSheetScale: compactScale,
          sliderBuilder: sliderBuilder,
          onChanged:
              (value) => onChanged(
                settings.copyWith(
                  audioSeekStepSeconds: ((value / 5).round() * 5).clamp(
                    ReaderSettings.minAudioSeekStepSeconds,
                    ReaderSettings.maxAudioSeekStepSeconds,
                  ),
                ),
              ),
        ),
        const SizedBox(height: 6),
        ReaderSettingsToggleRow(
          label: '启用音量键翻页',
          value: settings.volumeKeyPageEnabled,
          compactScale: compactScale,
          onChanged:
              isVolumeKeyPagingSupported
                  ? (enabled) => onChanged(
                    settings.copyWith(volumeKeyPageEnabled: enabled),
                  )
                  : null,
        ),
      ],
    );
  }
}
