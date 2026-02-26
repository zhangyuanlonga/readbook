import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';
import '../application/app_icon_service.dart';

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
                child: LayoutBuilder(
                  builder: (context, innerConstraints) {
                    final isExpanded = AppLayout.isExpandedWidth(
                      innerConstraints.maxWidth,
                    );
                    final leftCards = <Widget>[
                      _buildOverviewCard(context),
                      const SizedBox(height: 10),
                      _buildDisplayCard(context),
                    ];
                    final rightCards = <Widget>[
                      _buildRuntimeCard(context),
                      const SizedBox(height: 10),
                      _buildPlannedCard(context),
                    ];

                    return ListView(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        12,
                        horizontal,
                        12 + bottomSafe,
                      ),
                      children: [
                        if (!isExpanded) ...leftCards,
                        if (!isExpanded) const SizedBox(height: 10),
                        if (!isExpanded) ...rightCards,
                        if (isExpanded)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 12,
                                child: Column(children: leftCards),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 10,
                                child: Column(children: rightCards),
                              ),
                            ],
                          ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOverviewCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.tertiaryContainer.withValues(alpha: 0.8),
              colorScheme.surfaceContainerLow,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tune_rounded, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '系统级配置',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '用于集中展示运行策略、显示行为与平台相关能力。当前先提供基础信息与入口，后续逐步开放可配置项。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisplayCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              context,
              icon: Icons.display_settings_outlined,
              title: '显示与交互',
            ),
            const SizedBox(height: 8),
            _SettingRow(
              icon: Icons.text_fields_rounded,
              title: '文本缩放策略',
              subtitle: '当前启用安全区间限制，避免极端字号破版。',
              status: '已启用',
            ),
            const SizedBox(height: 8),
            _SettingRow(
              icon: Icons.motion_photos_on_outlined,
              title: '过渡动画时长',
              subtitle: '全局主题切换采用 180ms 缓动动画。',
              status: '180ms',
            ),
            const SizedBox(height: 8),
            const _AppIconSettingRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildRuntimeCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              context,
              icon: Icons.memory_rounded,
              title: '运行与数据',
            ),
            const SizedBox(height: 8),
            _SettingRow(
              icon: Icons.wifi_tethering_rounded,
              title: '网络请求策略',
              subtitle: '书源请求包含统一超时、错误分类与重试策略。',
              status: '已配置',
            ),
            const SizedBox(height: 8),
            _SettingRow(
              icon: Icons.cloud_outlined,
              title: '缓存管理',
              subtitle: '进入缓存页清理已缓存章节数据。',
              status: '可管理',
              onTap: () => context.push('/cache'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlannedCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
              context,
              icon: Icons.engineering_outlined,
              title: '后续计划',
            ),
            const SizedBox(height: 8),
            Text(
              '后续会在此页补充平台权限开关、启动行为、日志级别与实验性能力入口。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.construction_outlined, size: 18),
                label: const Text('更多能力开发中'),
              ),
            ),
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

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final child = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: colorScheme.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: child,
    );
  }
}

class _AppIconSettingRow extends StatefulWidget {
  const _AppIconSettingRow();

  @override
  State<_AppIconSettingRow> createState() => _AppIconSettingRowState();
}

class _AppIconSettingRowState extends State<_AppIconSettingRow> {
  final AppIconService _appIconService = AppIconService();

  bool _isLoading = true;
  bool _isSupported = false;
  bool _isUpdating = false;
  AppIconVariant _currentIcon = AppIconVariant.primary;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadCurrentIcon();
  }

  Future<void> _loadCurrentIcon() async {
    final supported = await _appIconService.isSupported();
    var current = AppIconVariant.primary;
    if (supported) {
      current = await _appIconService.currentIcon();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = false;
      _isSupported = supported;
      _currentIcon = current;
      _errorText = null;
    });
  }

  Future<void> _switchIcon(AppIconVariant icon) async {
    if (_isUpdating || !_isSupported || icon == _currentIcon) {
      return;
    }
    setState(() {
      _isUpdating = true;
      _errorText = null;
    });
    try {
      await _appIconService.setIcon(icon);
      final current = await _appIconService.currentIcon();
      if (!mounted) {
        return;
      }
      setState(() {
        _currentIcon = current;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '图标切换失败，请稍后重试。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _SettingRow(
        icon: Icons.app_shortcut_rounded,
        title: 'APP 图标',
        subtitle: '正在读取当前图标配置。',
        status: '读取中',
      );
    }
    if (!_isSupported) {
      return const _SettingRow(
        icon: Icons.app_shortcut_rounded,
        title: 'APP 图标',
        subtitle: '当前平台不支持动态切换图标。',
        status: '不可用',
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.app_shortcut_rounded,
                  size: 18,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'APP 图标',
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '切换后桌面图标可能有短暂刷新延迟。',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _currentIcon.label,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final icon in AppIconVariant.values)
                ChoiceChip(
                  label: Text(icon.label),
                  selected: icon == _currentIcon,
                  onSelected: _isUpdating ? null : (_) => _switchIcon(icon),
                  showCheckmark: false,
                ),
            ],
          ),
          if (_isUpdating) ...[
            const SizedBox(height: 8),
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
                  '正在切换图标...',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
          if (_errorText case final message?) ...[
            const SizedBox(height: 8),
            Text(
              message,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
