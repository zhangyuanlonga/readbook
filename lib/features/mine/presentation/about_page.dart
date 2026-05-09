import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../core/device/device_identity_service.dart';
import '../application/advanced_theme_provider.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();

  static const String _appVersion = '1.1.0';
  static const List<String> _projectFocus = [
    '打造稳定顺手的跨平台阅读体验',
    '强化文档导入、整理与沉浸式阅读闭环',
    '保持可维护、可扩展的工程架构与数据安全',
  ];
  static const List<String> _mvpScope = [
    'TXT / EPUB / PDF / Markdown / HTML 阅读',
    '书架、灵感、阅读记录与进度管理',
    '主题排版、自定义配置与基础校验',
    '错误定位、诊断与可观测反馈',
  ];
  static const List<String> _techStack = [
    'Flutter 3',
    'Riverpod',
    'GoRouter',
    'Dio',
    'Drift + SQLite',
    'html / json_path',
  ];
  static final Uri _officialSiteUri = Uri.parse('https://www.sxyd.lltask.top');
  static final Uri _updatesPageUri = Uri.parse(
    'https://www.sxyd.lltask.top/updates.html',
  );
}

class _AboutPageState extends State<AboutPage> {
  final DeviceIdentityService _identityService = DeviceIdentityService();

  String _appVersionName = AboutPage._appVersion;
  int _appVersionCode = 0;

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    final versionName = await _identityService.getAppVersionName();
    final versionCode = await _identityService.getAppVersionCode();
    if (!mounted) {
      return;
    }
    setState(() {
      if (versionName.trim().isNotEmpty) {
        _appVersionName = versionName.trim();
      }
      _appVersionCode = versionCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final activeAdvancedTheme =
            ref.watch(activeAdvancedThemeProvider).valueOrNull;
        final backdrop = resolveAdvancedThemeBackdrop(
          Theme.of(context).colorScheme,
          activeAdvancedTheme,
        );
        final metrics = AppAdaptiveMetrics.of(context);
        final horizontal = metrics.pagePadding;
        final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
        final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

        return PopScope<void>(
          canPop: context.canPop(),
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || !context.mounted) {
              return;
            }
            context.go('/mine');
          },
          child: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              title: const Text('关于'),
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
            ),
            body: LayoutBuilder(
              builder: (context, _) {
                final contentMaxWidth = AppLayout.aboutPageContentMaxWidth(
                  context,
                );

                return DecoratedBox(
                  decoration: buildAdvancedThemeBackdropDecoration(backdrop),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentMaxWidth),
                      child: LayoutBuilder(
                        builder: (context, innerConstraints) {
                          final innerMetrics =
                              AppAdaptiveMetrics.resolveForConstraints(
                                context,
                                innerConstraints,
                              );
                          final isExpanded = innerMetrics.isExpandedWindow;
                          final contentGap = innerMetrics.contentGap;

                          final leftColumn = <Widget>[
                            _buildIntroCard(context),
                            SizedBox(height: contentGap),
                            _buildSectionCard(
                              context,
                              title: '项目当前重点',
                              subtitle: '当前版本以个人阅读和稳定体验为主。',
                              icon: Icons.track_changes_outlined,
                              items: AboutPage._projectFocus,
                            ),
                            SizedBox(height: contentGap),
                            _buildSectionCard(
                              context,
                              title: '当前能力',
                              subtitle: '优先覆盖本地文档与个人阅读管理。',
                              icon: Icons.checklist_rounded,
                              items: AboutPage._mvpScope,
                            ),
                          ];

                          final rightColumn = <Widget>[
                            _buildWebsiteCard(context),
                            SizedBox(height: contentGap),
                            _buildTagCard(
                              context,
                              title: '技术栈',
                              subtitle: '当前版本采用的核心方案。',
                              icon: Icons.developer_mode_rounded,
                              tags: AboutPage._techStack,
                            ),
                            SizedBox(height: contentGap),
                            _buildComplianceCard(context),
                          ];

                          return ListView(
                            padding: EdgeInsets.fromLTRB(
                              horizontal,
                              topInset + metrics.contentGap,
                              horizontal,
                              metrics.contentGap + bottomSafe,
                            ),
                            children: [
                              if (!isExpanded) ...leftColumn,
                              if (!isExpanded) SizedBox(height: contentGap),
                              if (!isExpanded) ...rightColumn,
                              if (isExpanded)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 12,
                                      child: Column(children: leftColumn),
                                    ),
                                    SizedBox(width: contentGap),
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
                  ),
                );
              },
            ),
          ),
        );
      },
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
                          'Selune',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '版本 $_appVersionName${_appVersionCode > 0 ? ' ($_appVersionCode)' : ''}',
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
                'Selune 是一款基于 Flutter 构建的跨平台阅读应用，面向日常阅读与个人文档整理场景，支持 TXT、EPUB、PDF、Markdown、HTML 等内容导入，提供书架管理、灵感、阅读记录、排版主题与多端一致的阅读体验。',
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
                    _buildMetricPill(context, '定位', '跨平台阅读'),
                    _buildMetricPill(context, '文档', 'TXT / EPUB / PDF'),
                    _buildMetricPill(context, '体验', '书架与沉浸阅读'),
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

  Widget _buildWebsiteCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final urlText = AboutPage._officialSiteUri.toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.public, size: 19, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  '官网地址',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '访问官网获取产品介绍、版本动态、更新说明与下载入口。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                urlText,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _openOfficialSite,
                  child: const Text('打开官网'),
                ),
                OutlinedButton(
                  onPressed: _openUpdatesPage,
                  child: const Text('更新日志'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openOfficialSite() async {
    final launched = await launchUrl(
      AboutPage._officialSiteUri,
      mode: LaunchMode.externalApplication,
    );
    if (launched || !mounted) {
      return;
    }
    _showMessage('跳转失败，请稍后重试。');
  }

  Future<void> _openUpdatesPage() async {
    final launched = await launchUrl(
      AboutPage._updatesPageUri,
      mode: LaunchMode.externalApplication,
    );
    if (launched || !mounted) {
      return;
    }
    _showMessage('打开更新日志失败，请稍后重试。');
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
              '本应用定位为跨平台阅读工具，适用于阅读用户合法获取、拥有授权或自行整理的 TXT、EPUB、PDF、Markdown、HTML 等内容。使用过程中请确保内容来源、访问方式与使用目的符合相关规则及当地法律法规。',
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
