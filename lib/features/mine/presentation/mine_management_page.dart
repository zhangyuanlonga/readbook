import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout/app_layout.dart';
import '../../../app/layout/app_spacing.dart';

enum MineManagementSection {
  tagManagement,
  categoryManagement,
  chapterRuleManagement,
  contentCleanup,
}

class MineManagementPage extends StatelessWidget {
  const MineManagementPage({super.key, required this.section});

  final MineManagementSection section;

  @override
  Widget build(BuildContext context) {
    final config = _MineManagementPageConfig.forSection(section);
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
        appBar: AppBar(title: Text(config.title)),
        body: LayoutBuilder(
          builder: (context, _) {
            final maxWidth = AppLayout.pageContentMaxWidth(
              context,
              maxWidth: AppLayout.settingsContentMaxWidth,
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
                    _buildHeroCard(context, config),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide =
                            constraints.maxWidth >=
                            AppLayout.railBreakpointWidth;
                        final overviewCard = _buildOverviewCard(
                          context,
                          config,
                        );
                        final roadmapCard = _buildRoadmapCard(context, config);
                        if (!wide) {
                          return Column(
                            children: [
                              overviewCard,
                              const SizedBox(height: 12),
                              roadmapCard,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: overviewCard),
                            const SizedBox(width: 12),
                            Expanded(child: roadmapCard),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildStatusCard(context, config),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    _MineManagementPageConfig config,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            config.accent.withValues(alpha: 0.22),
            colorScheme.surfaceContainerLow,
            colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: config.accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(config.icon, color: config.accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.title,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        config.subtitle,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in config.tags)
                  _buildMetaChip(context, text: tag, accent: config.accent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(
    BuildContext context,
    _MineManagementPageConfig config,
  ) {
    return _buildCardShell(
      context,
      icon: Icons.dashboard_customize_outlined,
      title: '页面结构',
      subtitle: '先把管理入口和信息架构铺好，后续直接接入真实数据。',
      child: Column(
        children: [
          for (final item in config.previewItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildPreviewTile(context, item, config.accent),
            ),
        ],
      ),
    );
  }

  Widget _buildRoadmapCard(
    BuildContext context,
    _MineManagementPageConfig config,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return _buildCardShell(
      context,
      icon: Icons.track_changes_outlined,
      title: '后续接入',
      subtitle: '这些模块已经预留了展示层，后续可逐步补齐状态、编辑和批量操作。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in config.todoItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: config.accent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.arrow_outward_rounded,
                      size: 12,
                      color: config.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    _MineManagementPageConfig config,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.46),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.construction_rounded, color: config.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                '当前状态',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            config.statusText,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardShell(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.46),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildPreviewTile(
    BuildContext context,
    _MinePreviewItem item,
    Color accent,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, size: 18, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(
    BuildContext context, {
    required String text,
    required Color accent,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.44),
        ),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MineManagementPageConfig {
  const _MineManagementPageConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.tags,
    required this.previewItems,
    required this.todoItems,
    required this.statusText,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<String> tags;
  final List<_MinePreviewItem> previewItems;
  final List<String> todoItems;
  final String statusText;

  static _MineManagementPageConfig forSection(MineManagementSection section) {
    return switch (section) {
      MineManagementSection.tagManagement => const _MineManagementPageConfig(
        title: '标签管理',
        subtitle: '管理阅读标签、展示顺序与常用筛选入口，先把结构铺好，后续可直接接入批量编辑能力。',
        icon: Icons.sell_outlined,
        accent: Color(0xFFB26A00),
        tags: ['标签分组', '排序预留', '书架筛选'],
        previewItems: [
          _MinePreviewItem(
            icon: Icons.label_outline_rounded,
            title: '标签列表',
            subtitle: '预留标签名称、数量、颜色与启停状态展示。',
          ),
          _MinePreviewItem(
            icon: Icons.swap_vert_rounded,
            title: '排序与置顶',
            subtitle: '后续可接拖拽排序、常用标签置顶与推荐展示。',
          ),
          _MinePreviewItem(
            icon: Icons.auto_awesome_mosaic_outlined,
            title: '筛选联动',
            subtitle: '为书架、搜索与阅读记录页预留统一筛选入口。',
          ),
        ],
        todoItems: [
          '接入标签创建、编辑、合并与删除操作。',
          '补齐标签颜色、统计数量与书籍关联关系。',
          '支持书架顶部快捷筛选与最近使用标签。',
        ],
        statusText: '当前已完成页面框架与模块分区，后续可直接接入真实标签数据与交互。',
      ),
      MineManagementSection.categoryManagement =>
        const _MineManagementPageConfig(
          title: '分类管理',
          subtitle: '整理书架分类、展示顺序与归档方式，适合后续承接分组视图和筛选面板。',
          icon: Icons.folder_copy_outlined,
          accent: Color(0xFF2B7A78),
          tags: ['分类分组', '排序预留', '归档结构'],
          previewItems: [
            _MinePreviewItem(
              icon: Icons.folder_open_rounded,
              title: '分类列表',
              subtitle: '展示分类名称、书籍数量与入口状态。',
            ),
            _MinePreviewItem(
              icon: Icons.view_carousel_outlined,
              title: '显示布局',
              subtitle: '后续可切换分栏、卡片和折叠展示方式。',
            ),
            _MinePreviewItem(
              icon: Icons.rule_folder_outlined,
              title: '归类规则',
              subtitle: '预留自动归类、手动移动和批量管理入口。',
            ),
          ],
          todoItems: ['接入分类增删改查与排序能力。', '支持分类封面、描述和智能推荐。', '补齐书架页分类筛选和批量移动交互。'],
          statusText: '当前以“分类结构”展示为主，后续可自然接上真实书架分类管理逻辑。',
        ),
      MineManagementSection.chapterRuleManagement =>
        const _MineManagementPageConfig(
          title: '分章规则',
          subtitle: '管理 TXT 分章模式、规则模板与匹配预览，方便后续承接规则调试和导入方案。',
          icon: Icons.rule_rounded,
          accent: Color(0xFF7B5CFA),
          tags: ['TXT 规则', '模板预留', '匹配预览'],
          previewItems: [
            _MinePreviewItem(
              icon: Icons.tune_rounded,
              title: '规则模板',
              subtitle: '展示内置模板、自定义规则与启用状态。',
            ),
            _MinePreviewItem(
              icon: Icons.find_in_page_outlined,
              title: '匹配预览',
              subtitle: '后续可接章节标题示例、命中结果与优先级说明。',
            ),
            _MinePreviewItem(
              icon: Icons.playlist_add_check_circle_outlined,
              title: '规则测试',
              subtitle: '预留针对单本书的测试入口与应用范围。',
            ),
          ],
          todoItems: [
            '接入规则新增、复制、导入与导出。',
            '支持正则预览、命中结果调试与失败诊断。',
            '补齐“按书生效 / 全局生效”的切换能力。',
          ],
          statusText: '当前页面已预留规则展示与调试区，后续接入 TXT 规则配置时可以直接扩展。',
        ),
      MineManagementSection.contentCleanup => const _MineManagementPageConfig(
        title: '正文净化',
        subtitle: '管理正文替换、空白清理与阅读前净化策略，为后续统一文本清理能力预留入口。',
        icon: Icons.cleaning_services_outlined,
        accent: Color(0xFF2E6CE6),
        tags: ['文本清理', '替换规则', '阅读前处理'],
        previewItems: [
          _MinePreviewItem(
            icon: Icons.backspace_outlined,
            title: '替换规则',
            subtitle: '预留敏感片段替换、多余标记清理和自定义映射。',
          ),
          _MinePreviewItem(
            icon: Icons.wrap_text_outlined,
            title: '排版净化',
            subtitle: '后续可配置空行合并、段首缩进和符号统一。',
          ),
          _MinePreviewItem(
            icon: Icons.preview_outlined,
            title: '净化预览',
            subtitle: '为阅读页和调试页预留“处理前 / 处理后”对照。',
          ),
        ],
        todoItems: [
          '接入替换规则、启停开关与命中统计。',
          '支持按书配置、全局配置和导入导出。',
          '补齐阅读页正文净化调试与即时预览。',
        ],
        statusText: '当前页面先承载正文净化的信息架构，后续接入真实规则和预览逻辑即可。',
      ),
    };
  }
}

class _MinePreviewItem {
  const _MinePreviewItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}
