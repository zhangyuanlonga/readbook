import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../reader/application/reader_system_settings_service.dart';
import '../../search/application/search_system_settings_service.dart';

const double _kSectionGap = 18;
const double _kSectionListGap = 6;

TextStyle? _sectionTitleTextStyle(BuildContext context) {
  return Theme.of(context).textTheme.titleSmall?.copyWith(
    fontSize: 14.5,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );
}

TextStyle? _sectionDescriptionTextStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodySmall?.copyWith(
    fontSize: 12,
    height: 1.35,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}

TextStyle? _settingTitleTextStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyLarge?.copyWith(
    fontSize: 14.5,
    height: 1.25,
    fontWeight: FontWeight.w600,
  );
}

TextStyle? _settingSubtitleTextStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodySmall?.copyWith(
    fontSize: 12,
    height: 1.3,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}

TextStyle? _statusTextStyle(BuildContext context) {
  return Theme.of(context).textTheme.labelMedium?.copyWith(
    fontSize: 11.5,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}

class SystemSettingsPage extends StatelessWidget {
  const SystemSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final horizontal = AppSpacing.pageHorizontal(context);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !context.mounted) {
          return;
        }
        context.go('/mine');
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('系统')),
        body: LayoutBuilder(
          builder: (context, _) {
            final maxWidth = AppLayout.pageContentMaxWidth(
              context,
              maxWidth: AppLayout.systemSettingsContentMaxWidth,
            );

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    12,
                    horizontal,
                    16 + bottomSafe,
                  ),
                  children: [
                    _buildPageIntro(context),
                    const SizedBox(height: _kSectionGap),
                    _buildReaderFallbackSection(context),
                    const SizedBox(height: _kSectionGap),
                    _buildSearchAggregationSection(context),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPageIntro(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text('阅读与搜索偏好', style: _sectionTitleTextStyle(context))],
    );
  }

  Widget _buildReaderFallbackSection(BuildContext context) {
    return _buildSettingsSection(
      context,
      icon: Icons.auto_fix_high_rounded,
      title: '阅读容错',
      description: '正文失败时自动补位。',
      child: const _ReaderAutoSwitchSettingPanel(),
    );
  }

  Widget _buildSearchAggregationSection(BuildContext context) {
    return _buildSettingsSection(
      context,
      icon: Icons.auto_awesome_mosaic_rounded,
      title: '搜索聚合',
      description: '控制同书多源合并。',
      child: const _SearchAggregationSettingPanel(),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(title, style: _sectionTitleTextStyle(context)),
          ],
        ),
        const SizedBox(height: 4),
        Text(description, style: _sectionDescriptionTextStyle(context)),
        const SizedBox(height: _kSectionListGap),
        child,
      ],
    );
  }
}

Widget _buildSettingsList(
  BuildContext context, {
  required List<Widget> children,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final dividerColor = colorScheme.outlineVariant.withValues(alpha: 0.55);

  return Column(
    children: [
      Container(height: 1, color: dividerColor),
      for (final child in children) ...[
        child,
        Container(height: 1, color: dividerColor),
      ],
    ],
  );
}

Widget _buildSavingIndicator(BuildContext context, {required bool visible}) {
  final colorScheme = Theme.of(context).colorScheme;

  return SizedBox(
    width: 54,
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child:
          visible
              ? Row(
                key: const ValueKey('saving'),
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('保存中', style: _statusTextStyle(context)),
                ],
              )
              : const SizedBox(key: ValueKey('idle')),
    ),
  );
}

Widget _buildErrorBanner(BuildContext context, {required String message}) {
  final colorScheme = Theme.of(context).colorScheme;

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    decoration: BoxDecoration(
      color: colorScheme.errorContainer.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colorScheme.error.withValues(alpha: 0.35)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline_rounded, size: 16, color: colorScheme.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12.5,
              color: colorScheme.onErrorContainer,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildStateHint(BuildContext context, {required String message}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(message, style: _settingSubtitleTextStyle(context)),
  );
}

Widget _buildSwitchRow(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required bool value,
  required bool isSaving,
  required ValueChanged<bool>? onChanged,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            icon,
            size: 18,
            color: value ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(title, style: _settingTitleTextStyle(context)),
                  ),
                  _buildSavingIndicator(context, visible: isSaving),
                ],
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: _settingSubtitleTextStyle(context)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    ),
  );
}

class _ReaderAutoSwitchSettingPanel extends StatefulWidget {
  const _ReaderAutoSwitchSettingPanel();

  @override
  State<_ReaderAutoSwitchSettingPanel> createState() =>
      _ReaderAutoSwitchSettingPanelState();
}

class _ReaderAutoSwitchSettingPanelState
    extends State<_ReaderAutoSwitchSettingPanel> {
  final ReaderSystemSettingsService _systemSettingsService =
      ReaderSystemSettingsService();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _enabled = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    try {
      final enabled =
          await _systemSettingsService.loadAutoSwitchSourceOnFailureEnabled();
      if (!mounted) {
        return;
      }
      setState(() {
        _enabled = enabled;
        _errorText = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '读取自动换源开关失败，请稍后重试。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggle(bool enabled) async {
    if (_isSaving) {
      return;
    }

    final previous = _enabled;
    setState(() {
      _enabled = enabled;
      _isSaving = true;
      _errorText = null;
    });

    try {
      await _systemSettingsService.saveAutoSwitchSourceOnFailureEnabled(
        enabled,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _enabled = previous;
        _errorText = '保存自动换源开关失败，请稍后重试。';
      });
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
    if (_isLoading) {
      return _buildStateHint(context, message: '正在读取自动换源配置...');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingsList(
          context,
          children: [
            _buildSwitchRow(
              context,
              icon: Icons.swap_horiz_rounded,
              title: '自动换源（正文加载失败时）',
              subtitle: _enabled ? '失败时自动尝试候选源。' : '仅支持手动换源。',
              value: _enabled,
              isSaving: _isSaving,
              onChanged: _isSaving ? null : _toggle,
            ),
          ],
        ),
        if (_errorText case final message?) ...[
          const SizedBox(height: 8),
          _buildErrorBanner(context, message: message),
        ],
      ],
    );
  }
}

class _SearchAggregationSettingPanel extends StatefulWidget {
  const _SearchAggregationSettingPanel();

  @override
  State<_SearchAggregationSettingPanel> createState() =>
      _SearchAggregationSettingPanelState();
}

class _SearchAggregationSettingPanelState
    extends State<_SearchAggregationSettingPanel> {
  final SearchSystemSettingsService _settingsService =
      SearchSystemSettingsService();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _enabled = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    try {
      final enabled =
          await _settingsService.loadAggregateByTitleAuthorEnabled();
      if (!mounted) {
        return;
      }
      setState(() {
        _enabled = enabled;
        _errorText = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '读取搜索聚合开关失败，请稍后重试。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggle(bool enabled) async {
    if (_isSaving) {
      return;
    }

    final previous = _enabled;
    setState(() {
      _enabled = enabled;
      _isSaving = true;
      _errorText = null;
    });

    try {
      await _settingsService.saveAggregateByTitleAuthorEnabled(enabled);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _enabled = previous;
        _errorText = '保存搜索聚合开关失败，请稍后重试。';
      });
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
    if (_isLoading) {
      return _buildStateHint(context, message: '正在读取搜索聚合配置...');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingsList(
          context,
          children: [
            _buildSwitchRow(
              context,
              icon: Icons.merge_type_rounded,
              title: '同书聚合（书名 + 作者）',
              subtitle: _enabled ? '多源命中时合并展示。' : '按原始结果逐条展示。',
              value: _enabled,
              isSaving: _isSaving,
              onChanged: _isSaving ? null : _toggle,
            ),
          ],
        ),
        if (_errorText case final message?) ...[
          const SizedBox(height: 8),
          _buildErrorBanner(context, message: message),
        ],
      ],
    );
  }
}
