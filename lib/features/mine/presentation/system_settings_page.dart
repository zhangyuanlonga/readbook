import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../../../app/shell_navigation_provider.dart';
import '../../reader/application/reader_system_settings_service.dart';
import '../../search/application/search_system_settings_service.dart';

const double _kSectionGap = 12;
const double _kCardPadding = 16;
const double _kCardIntroGap = 12;
const double _kCardPanelGap = 16;

TextStyle? _sectionTitleTextStyle(BuildContext context) {
  return Theme.of(context).textTheme.titleSmall?.copyWith(
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
  );
}

TextStyle? _sectionDescriptionTextStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodySmall?.copyWith(
    fontSize: 13,
    height: 1.45,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}

TextStyle? _settingTitleTextStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyLarge?.copyWith(
    fontSize: 15,
    height: 1.25,
    fontWeight: FontWeight.w600,
  );
}

TextStyle? _settingSubtitleTextStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodySmall?.copyWith(
    fontSize: 13,
    height: 1.35,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  );
}

TextStyle? _statusTextStyle(BuildContext context) {
  return Theme.of(context).textTheme.labelMedium?.copyWith(
    fontSize: 12,
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
                16,
                horizontal,
                16 + bottomSafe,
              ),
              children: [
                _buildBottomNavigationCard(context),
                const SizedBox(height: _kSectionGap),
                _buildReaderFallbackCard(context),
                const SizedBox(height: _kSectionGap),
                _buildSearchAggregationCard(context),
                const SizedBox(height: _kSectionGap),
                _buildDebugToolsCard(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(_kCardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              context,
              icon: Icons.space_dashboard_rounded,
              title: '底部菜单',
            ),
            const SizedBox(height: _kCardIntroGap),
            Text(
              '可控制底部导航栏展示项数量；“我的”固定显示，避免找不到系统设置入口。',
              style: _sectionDescriptionTextStyle(context),
            ),
            const SizedBox(height: _kCardPanelGap),
            const _BottomNavigationSettingPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildReaderFallbackCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(_kCardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              context,
              icon: Icons.auto_fix_high_rounded,
              title: '阅读容错',
            ),
            const SizedBox(height: _kCardIntroGap),
            Text(
              '当正文加载失败时，可自动尝试切换到候选书源。',
              style: _sectionDescriptionTextStyle(context),
            ),
            const SizedBox(height: _kCardPanelGap),
            const _ReaderAutoSwitchSettingPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAggregationCard(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(_kCardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              context,
              icon: Icons.auto_awesome_mosaic_rounded,
              title: '搜索聚合',
            ),
            const SizedBox(height: _kCardIntroGap),
            Text(
              '同书多源命中时，是否按书名+作者聚合为单条结果。',
              style: _sectionDescriptionTextStyle(context),
            ),
            const SizedBox(height: _kCardPanelGap),
            const _SearchAggregationSettingPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugToolsCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          maintainState: true,
          tilePadding: const EdgeInsets.fromLTRB(
            _kCardPadding,
            _kCardIntroGap,
            _kCardPadding,
            _kCardIntroGap,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            _kCardPadding,
            0,
            _kCardPadding,
            _kCardPadding,
          ),
          leading: Icon(
            Icons.bug_report_outlined,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          iconColor: colorScheme.onSurfaceVariant,
          collapsedIconColor: colorScheme.onSurfaceVariant,
          title: Text(
            '开发与调试',
            style: _sectionTitleTextStyle(context)?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '仅在排查问题时展开并开启，默认收起。',
            style: _sectionDescriptionTextStyle(context),
          ),
          children: const [
            _SearchDebugLogSettingPanel(),
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
          style: _sectionTitleTextStyle(context),
        ),
      ],
    );
  }
}

Widget _buildSavingIndicator(BuildContext context, {required bool visible}) {
  final colorScheme = Theme.of(context).colorScheme;
  final textStyle = _statusTextStyle(context);

  return SizedBox(
    width: 76,
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child:
          visible
              ? Row(
                key: const ValueKey('saving'),
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('保存中', style: textStyle),
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
              fontSize: 13,
              color: colorScheme.onErrorContainer,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

class _BottomNavigationSettingPanel extends ConsumerStatefulWidget {
  const _BottomNavigationSettingPanel();

  @override
  ConsumerState<_BottomNavigationSettingPanel> createState() =>
      _BottomNavigationSettingPanelState();
}

class _BottomNavigationSettingPanelState
    extends ConsumerState<_BottomNavigationSettingPanel> {
  bool _isSaving = false;
  AppShellTab? _savingTab;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final navigationState = ref.watch(appShellNavigationProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '当前展示 ${navigationState.visibleTabCount}/4 项',
          style: _statusTextStyle(context),
        ),
        const SizedBox(height: 8),
        _buildTabToggle(
          context,
          tab: AppShellTab.bookshelf,
          title: '书架',
          enabled: navigationState.showBookshelf,
          enabledSubtitle: '已显示在底部菜单。',
          disabledSubtitle: '已从底部菜单隐藏。',
        ),
        _buildTabToggle(
          context,
          tab: AppShellTab.discover,
          title: '发现',
          enabled: navigationState.showDiscover,
          enabledSubtitle: '已显示在底部菜单。',
          disabledSubtitle: '已从底部菜单隐藏。',
        ),
        _buildTabToggle(
          context,
          tab: AppShellTab.source,
          title: '书源',
          enabled: navigationState.showSource,
          enabledSubtitle: '已显示在底部菜单。',
          disabledSubtitle: '已从底部菜单隐藏。',
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          title: Text('我的（固定显示）', style: _settingTitleTextStyle(context)),
          subtitle: Text(
            '保留入口，方便随时返回系统设置调整。',
            style: _settingSubtitleTextStyle(context),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '固定',
              style: _statusTextStyle(context),
            ),
          ),
        ),
        if (_errorText case final message?) ...[
          const SizedBox(height: 8),
          _buildErrorBanner(context, message: message),
        ],
      ],
    );
  }

  Widget _buildTabToggle(
    BuildContext context, {
    required AppShellTab tab,
    required String title,
    required bool enabled,
    required String enabledSubtitle,
    required String disabledSubtitle,
  }) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: enabled,
      onChanged: _isSaving ? null : (value) => _toggle(tab, value),
      title: Row(
        children: [
          Expanded(child: Text(title, style: _settingTitleTextStyle(context))),
          _buildSavingIndicator(context, visible: _isSaving && _savingTab == tab),
        ],
      ),
      subtitle: Text(
        enabled ? enabledSubtitle : disabledSubtitle,
        style: _settingSubtitleTextStyle(context),
      ),
    );
  }

  Future<void> _toggle(AppShellTab tab, bool enabled) async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
      _savingTab = tab;
      _errorText = null;
    });

    try {
      await ref.read(appShellNavigationProvider.notifier).setTabVisible(
            tab,
            enabled,
          );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '保存底部菜单配置失败，请稍后重试。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _savingTab = null;
        });
      }
    }
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _enabled,
          onChanged: _isSaving ? null : _toggle,
          title: Row(
            children: [
              Expanded(
                child: Text(
                  '自动换源（正文加载失败时）',
                  style: _settingTitleTextStyle(context),
                ),
              ),
              _buildSavingIndicator(context, visible: _isSaving),
            ],
          ),
          subtitle: Text(
            _enabled ? '已开启，失败时自动尝试候选源。' : '已关闭，仅支持手动换源。',
            style: _settingSubtitleTextStyle(context),
          ),
        ),
        if (_errorText case final message?) ...[
          const SizedBox(height: 8),
          _buildErrorBanner(context, message: message),
        ],
      ],
    );
  }

  Widget _buildStateHint(BuildContext context, {required String message}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        message,
        style: _settingSubtitleTextStyle(context),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _enabled,
          onChanged: _isSaving ? null : _toggle,
          title: Row(
            children: [
              Expanded(
                child: Text(
                  '同书聚合（书名+作者）',
                  style: _settingTitleTextStyle(context),
                ),
              ),
              _buildSavingIndicator(context, visible: _isSaving),
            ],
          ),
          subtitle: Text(
            _enabled ? '已开启，同一本书多源命中时合并展示。' : '已关闭，按各书源原始结果逐条展示。',
            style: _settingSubtitleTextStyle(context),
          ),
        ),
        if (_errorText case final message?) ...[
          const SizedBox(height: 8),
          _buildErrorBanner(context, message: message),
        ],
      ],
    );
  }

  Widget _buildStateHint(BuildContext context, {required String message}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        message,
        style: _settingSubtitleTextStyle(context),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _enabled,
          onChanged: _isSaving ? null : _toggle,
          title: Row(
            children: [
              Expanded(
                child: Text(
                  '搜索调试日志（INFO）',
                  style: _settingTitleTextStyle(context),
                ),
              ),
              _buildSavingIndicator(context, visible: _isSaving),
            ],
          ),
          subtitle: Text(
            _enabled ? '已开启，记录搜索阶段调试信息。' : '已关闭，仅保留告警和错误日志。',
            style: _settingSubtitleTextStyle(context),
          ),
        ),
        if (_errorText case final message?) ...[
          const SizedBox(height: 8),
          _buildErrorBanner(context, message: message),
        ],
      ],
    );
  }

  Widget _buildStateHint(BuildContext context, {required String message}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        message,
        style: _settingSubtitleTextStyle(context),
      ),
    );
  }
}
