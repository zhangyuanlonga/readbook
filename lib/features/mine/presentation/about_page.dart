import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const String _appVersion = '1.06';
  static const List<String> _projectFocus = [
    '构建书源兼容层（导入、校验、适配）',
    '打通阅读闭环（搜索 -> 详情 -> 目录 -> 正文）',
    '保持稳定、可维护、可扩展的工程架构',
  ];
  static const List<String> _mvpScope = [
    '文本小说主链路',
    '本地书源 JSON 导入',
    'HTML / Regex / JSONPath 解析能力',
    '错误可定位与可观测',
  ];
  static const List<String> _techStack = [
    'Flutter 3',
    'Riverpod',
    'GoRouter',
    'Dio',
    'Drift + SQLite',
    'html / json_path',
  ];
  static const List<String> _docEntries = [
    'docs/project_overview.md',
    'docs/requirements.md',
    'docs/architecture.md',
    'docs/project_conventions.md',
    'docs/implementation_steps.md',
  ];

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
        appBar: AppBar(title: const Text('关于')),
        body: LayoutBuilder(
          builder: (context, _) {
            final contentMaxWidth = AppLayout.aboutPageContentMaxWidth(context);

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: LayoutBuilder(
                  builder: (context, innerConstraints) {
                    final width = innerConstraints.maxWidth;
                    final isExpanded = AppLayout.isExpandedWidth(width);

                    final leftColumn = <Widget>[
                      _buildIntroCard(context),
                      const SizedBox(height: 10),
                      _buildSectionCard(
                        context,
                        title: '项目当前重点',
                        subtitle: '来自项目总览与 README 的阶段目标。',
                        icon: Icons.track_changes_outlined,
                        items: _projectFocus,
                      ),
                      const SizedBox(height: 10),
                      _buildSectionCard(
                        context,
                        title: 'MVP 范围',
                        subtitle: '当前版本聚焦“导源即读”的可用闭环。',
                        icon: Icons.checklist_rounded,
                        items: _mvpScope,
                      ),
                    ];

                    final rightColumn = <Widget>[
                      _buildTagCard(
                        context,
                        title: '技术栈',
                        subtitle: '当前版本采用的核心方案。',
                        icon: Icons.developer_mode_rounded,
                        tags: _techStack,
                      ),
                      const SizedBox(height: 10),
                      _buildDocCard(context),
                      const SizedBox(height: 10),
                      _buildComplianceCard(context),
                    ];

                    return ListView(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        12,
                        horizontal,
                        12 + bottomSafe,
                      ),
                      children: [
                        if (!isExpanded) ...leftColumn,
                        if (!isExpanded) const SizedBox(height: 10),
                        if (!isExpanded) ...rightColumn,
                        if (isExpanded)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 12,
                                child: Column(children: leftColumn),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 10,
                                child: Column(children: rightColumn),
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

  Widget _buildIntroCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.88),
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
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.auto_stories_rounded,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '书享阅读 · AppRead',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '版本 $_appVersion',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '一个基于 Flutter 的阅读应用，目标是兼容开源阅读生态常见书源规则（以 Legado 规则体系为主），并逐步构建稳定、可维护、可扩展的阅读体验。',
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.4,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final useRow = AppLayout.isMediumWidth(constraints.maxWidth);
                  final items = <Widget>[
                    _buildMetricPill(context, '架构', '分层设计'),
                    _buildMetricPill(context, '书源', 'Legado 兼容'),
                    _buildMetricPill(context, '目标', '导源即读'),
                  ];

                  if (useRow) {
                    return Row(
                      children: [
                        Expanded(child: items[0]),
                        const SizedBox(width: 8),
                        Expanded(child: items[1]),
                        const SizedBox(width: 8),
                        Expanded(child: items[2]),
                      ],
                    );
                  }

                  return Wrap(spacing: 8, runSpacing: 8, children: items);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricPill(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: colorScheme.surface.withValues(alpha: 0.9),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<String> items,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<String> tags,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags
                  .map((tag) => _AboutTag(text: tag))
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.library_books_outlined,
                  size: 19,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '文档入口',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '可在项目目录直接查看以下文档：',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final path in _docEntries)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  path,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplianceCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.gavel_outlined,
                  size: 19,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '使用说明',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '本项目提供书源规则兼容能力，书源由用户自行导入。抓取与访问行为请遵守目标站点条款及当地法律法规。',
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.4,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutTag extends StatelessWidget {
  const _AboutTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
