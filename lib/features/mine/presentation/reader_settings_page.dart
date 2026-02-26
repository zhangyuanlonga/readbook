import 'package:flutter/material.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../domain/entities/reader_settings.dart';
import '../../reader/application/reader_preferences_service.dart';

class ReaderSettingsPage extends StatefulWidget {
  const ReaderSettingsPage({super.key});

  @override
  State<ReaderSettingsPage> createState() => _ReaderSettingsPageState();
}

class _ReaderSettingsPageState extends State<ReaderSettingsPage> {
  final ReaderPreferencesService _preferencesService =
      ReaderPreferencesService();

  ReaderSettings _settings = const ReaderSettings();
  bool _isLoading = true;
  bool _isSaving = false;

  static const List<_SpacingOption> _lineOptions = [
    _SpacingOption('小', 1.3),
    _SpacingOption('较小', 1.5),
    _SpacingOption('适中', 1.7),
    _SpacingOption('大', 2.0),
  ];

  static const List<_SpacingOption> _paddingOptions = [
    _SpacingOption('小', 12),
    _SpacingOption('适中', 18),
    _SpacingOption('较大', 24),
    _SpacingOption('大', 30),
  ];

  static const List<_SpacingOption> _paragraphOptions = [
    _SpacingOption('小', 8),
    _SpacingOption('较小', 10),
    _SpacingOption('适中', 14),
    _SpacingOption('大', 20),
  ];

  static const List<_SpacingOption> _indentOptions = [
    _SpacingOption('无', 0),
    _SpacingOption('小', 2),
    _SpacingOption('适中', 4),
    _SpacingOption('大', 6),
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final settings = await _preferencesService.loadSettings();
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = settings;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('读取阅读设置失败。');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _applySettings(ReaderSettings nextSettings) async {
    if (_isSaving) {
      return;
    }

    final previous = _settings;
    setState(() {
      _settings = nextSettings;
      _isSaving = true;
    });

    try {
      await _preferencesService.saveSettings(nextSettings);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = previous;
      });
      _showMessage('保存失败，请重试。');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(title: const Text('阅读设置')),
      body: LayoutBuilder(
        builder: (context, _) {
          final maxWidth = AppLayout.pageContentMaxWidth(
            context,
            maxWidth: AppLayout.settingsContentMaxWidth,
          );

          if (_isLoading) {
            return const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  12,
                  horizontal,
                  12 + bottomSafe,
                ),
                children: [
                  _buildSummaryCard(context),
                  const SizedBox(height: 10),
                  _buildSpacingCard(context),
                  const SizedBox(height: 10),
                  _buildRoadmapCard(context),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final indent = '　' * _settings.paragraphIndent.round().clamp(0, 8);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '正文排版预览',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '当前：行间距 ${_settings.lineHeight.toStringAsFixed(1)} / 页面边距 ${_settings.horizontalPadding.toStringAsFixed(0)} / 段落 ${_settings.paragraphSpacing.toStringAsFixed(0)} / 缩进 ${_settings.paragraphIndent.toStringAsFixed(0)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: (_settings.horizontalPadding / 2).clamp(8, 24),
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: DefaultTextStyle(
                style: theme.textTheme.bodyMedium!.copyWith(
                  height: _settings.lineHeight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$indent这是正文排版预览，用于确认阅读视觉密度。'),
                    SizedBox(height: _settings.paragraphSpacing.clamp(4, 24)),
                    Text('$indent后续页眉、页脚、分栏等配置也会统一放在这里。'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpacingCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '间距设置',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _buildOptionGroup(
              context,
              title: '行间距',
              options: _lineOptions,
              currentValue: _settings.lineHeight,
              epsilon: 0.06,
              onSelected:
                  (value) =>
                      _applySettings(_settings.copyWith(lineHeight: value)),
            ),
            const SizedBox(height: 12),
            _buildOptionGroup(
              context,
              title: '页面边距',
              options: _paddingOptions,
              currentValue: _settings.horizontalPadding,
              epsilon: 0.6,
              onSelected:
                  (value) => _applySettings(
                    _settings.copyWith(horizontalPadding: value),
                  ),
            ),
            const SizedBox(height: 12),
            _buildOptionGroup(
              context,
              title: '段落间距',
              options: _paragraphOptions,
              currentValue: _settings.paragraphSpacing,
              epsilon: 0.6,
              onSelected:
                  (value) => _applySettings(
                    _settings.copyWith(paragraphSpacing: value),
                  ),
            ),
            const SizedBox(height: 12),
            _buildOptionGroup(
              context,
              title: '首行缩进',
              options: _indentOptions,
              currentValue: _settings.paragraphIndent,
              epsilon: 0.6,
              onSelected:
                  (value) => _applySettings(
                    _settings.copyWith(paragraphIndent: value),
                  ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed:
                    _isSaving
                        ? null
                        : () => _applySettings(
                          _settings.copyWith(
                            lineHeight: 1.7,
                            horizontalPadding: 18,
                            paragraphSpacing: 14,
                            paragraphIndent: 0,
                          ),
                        ),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('恢复默认间距'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionGroup(
    BuildContext context, {
    required String title,
    required List<_SpacingOption> options,
    required double currentValue,
    required double epsilon,
    required ValueChanged<double> onSelected,
  }) {
    final titleStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              ChoiceChip(
                label: Text(option.label),
                selected: (option.value - currentValue).abs() < epsilon,
                onSelected: _isSaving ? null : (_) => onSelected(option.value),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoadmapCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '后续扩展',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '这里会继续承接阅读正文配置：页眉、页脚、翻页区域、手势与分页显示等。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SpacingOption {
  const _SpacingOption(this.label, this.value);

  final String label;
  final double value;
}
