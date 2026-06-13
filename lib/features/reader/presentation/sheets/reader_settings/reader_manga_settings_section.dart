import 'package:flutter/material.dart';

import '../../../../../domain/entities/reader_settings.dart';
import 'reader_settings_components.dart';

class ReaderMangaSettingsPanel extends StatelessWidget {
  const ReaderMangaSettingsPanel({
    super.key,
    required this.settings,
    required this.compactScale,
    required this.onChanged,
  });

  final ReaderSettings settings;
  final double compactScale;
  final ValueChanged<ReaderSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return ReaderSettingsCard(
      compactScale: compactScale,
      children: [
        ReaderSettingsCompactTitle(title: '漫画阅读', compactScale: compactScale),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ReaderMangaReadMode.values
              .map(
                (mode) => ChoiceChip(
                  label: Text(_readModeLabel(mode)),
                  selected: settings.mangaReadMode == mode,
                  onSelected:
                      (_) => onChanged(settings.copyWith(mangaReadMode: mode)),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 10),
        ReaderSettingsCompactTitle(title: '留白', compactScale: compactScale),
        const SizedBox(height: 6),
        _NumberChoiceWrap(
          values: const [0.0, 4.0, 8.0, 12.0, 16.0],
          selectedValue: settings.mangaImagePadding,
          onSelected:
              (value) => onChanged(settings.copyWith(mangaImagePadding: value)),
        ),
        const SizedBox(height: 10),
        ReaderSettingsCompactTitle(title: '图间距', compactScale: compactScale),
        const SizedBox(height: 6),
        _NumberChoiceWrap(
          values: const [0.0, 6.0, 10.0, 14.0, 18.0],
          selectedValue: settings.mangaImageSpacing,
          onSelected:
              (value) => onChanged(settings.copyWith(mangaImageSpacing: value)),
        ),
        const SizedBox(height: 10),
        ReaderSettingsCompactTitle(title: '加载策略', compactScale: compactScale),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ReaderMangaLoadStrategy.values
              .map(
                (strategy) => ChoiceChip(
                  label: Text(_loadStrategyLabel(strategy)),
                  selected: settings.mangaLoadStrategy == strategy,
                  onSelected:
                      (_) => onChanged(
                        settings.copyWith(mangaLoadStrategy: strategy),
                      ),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  String _readModeLabel(ReaderMangaReadMode mode) {
    return switch (mode) {
      ReaderMangaReadMode.continuous => '连续长图',
      ReaderMangaReadMode.paged => '分页图',
      ReaderMangaReadMode.horizontal => '横向翻页',
    };
  }

  String _loadStrategyLabel(ReaderMangaLoadStrategy strategy) {
    return switch (strategy) {
      ReaderMangaLoadStrategy.balanced => '平衡',
      ReaderMangaLoadStrategy.smooth => '流畅优先',
      ReaderMangaLoadStrategy.saveData => '省流量',
    };
  }
}

class _NumberChoiceWrap extends StatelessWidget {
  const _NumberChoiceWrap({
    required this.values,
    required this.selectedValue,
    required this.onSelected,
  });

  final List<double> values;
  final double selectedValue;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values
          .map(
            (value) => ChoiceChip(
              label: Text('${value.toInt()}'),
              selected: (selectedValue - value).abs() < 0.2,
              onSelected: (_) => onSelected(value),
            ),
          )
          .toList(growable: false),
    );
  }
}
