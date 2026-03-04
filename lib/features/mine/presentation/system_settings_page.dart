import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../reader/application/reader_system_settings_service.dart';
import '../../search/application/search_system_settings_service.dart';

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
        appBar: AppBar(title: const Text('系统设置')),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AppLayout.pageContentMaxWidth(
                context,
                maxWidth: AppLayout.systemSettingsContentMaxWidth,
              ),
            ),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                12,
                horizontal,
                12 + bottomSafe,
              ),
              children: [
                _buildReaderFallbackCard(context),
                const SizedBox(height: 10),
                _buildSearchAggregationCard(context),
                const SizedBox(height: 10),
                _buildDebugToolsCard(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReaderFallbackCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              context,
              icon: Icons.auto_fix_high_rounded,
              title: '阅读容错',
            ),
            const SizedBox(height: 6),
            Text(
              '当正文加载失败时，可自动尝试切换到候选书源。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            const _ReaderAutoSwitchSettingPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAggregationCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              context,
              icon: Icons.auto_awesome_mosaic_rounded,
              title: '搜索聚合',
            ),
            const SizedBox(height: 6),
            Text(
              '同书多源命中时，是否按书名+作者聚合为单条结果。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            const _SearchAggregationSettingPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugToolsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              context,
              icon: Icons.bug_report_rounded,
              title: '其他（调试）',
            ),
            const SizedBox(height: 6),
            Text(
              '排查搜索书源问题时，可开启搜索调试日志（INFO）。日常使用建议关闭。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            const _SearchDebugLogSettingPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
    BuildContext context, {
    required IconData icon,
    required String title,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
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

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _enabled,
          onChanged: _isSaving ? null : _toggle,
          title: const Text('自动换源（正文加载失败时）'),
          subtitle: Text(
            _enabled ? '已开启，失败时自动尝试候选源。' : '已关闭，仅支持手动换源。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (_isSaving) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '正在保存...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
        if (_errorText case final message?) ...[
          const SizedBox(height: 6),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildStateHint(BuildContext context, {required String message}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          height: 1.3,
        ),
      ),
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

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _enabled,
          onChanged: _isSaving ? null : _toggle,
          title: const Text('同书聚合（书名+作者）'),
          subtitle: Text(
            _enabled ? '已开启，同一本书多源命中时合并展示。' : '已关闭，按各书源原始结果逐条展示。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (_isSaving) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '正在保存...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
        if (_errorText case final message?) ...[
          const SizedBox(height: 6),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildStateHint(BuildContext context, {required String message}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          height: 1.3,
        ),
      ),
    );
  }
}

class _SearchDebugLogSettingPanel extends StatefulWidget {
  const _SearchDebugLogSettingPanel();

  @override
  State<_SearchDebugLogSettingPanel> createState() =>
      _SearchDebugLogSettingPanelState();
}

class _SearchDebugLogSettingPanelState
    extends State<_SearchDebugLogSettingPanel> {
  final SearchSystemSettingsService _settingsService =
      SearchSystemSettingsService();

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
      final enabled = await _settingsService.loadSearchDebugLogEnabled();
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
        _errorText = '读取搜索调试日志开关失败，请稍后重试。';
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
      await _settingsService.saveSearchDebugLogEnabled(enabled);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _enabled = previous;
        _errorText = '保存搜索调试日志开关失败，请稍后重试。';
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
      return _buildStateHint(context, message: '正在读取搜索调试日志配置...');
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _enabled,
          onChanged: _isSaving ? null : _toggle,
          title: const Text('搜索调试日志（INFO）'),
          subtitle: Text(
            _enabled ? '已开启，记录搜索阶段调试信息。' : '已关闭，仅保留告警和错误日志。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (_isSaving) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '正在保存...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
        if (_errorText case final message?) ...[
          const SizedBox(height: 6),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildStateHint(BuildContext context, {required String message}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          height: 1.3,
        ),
      ),
    );
  }
}
