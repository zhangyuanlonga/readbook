import 'package:flutter/material.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/theme/app_official_theme_presets.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../app/widgets/adaptive_card.dart';
import '../../../app/widgets/adaptive_setting_tile.dart';
import '../../../app/widgets/app_empty_state_card.dart';
import '../../../app/widgets/app_status_state_card.dart';
import '../../../app/widgets/foundation/foundation.dart';
import '../../../app/widgets/text_cover_placeholder.dart';
import 'widgets/image_resource_collection_widgets.dart';
import 'widgets/mine_route_top_bar.dart';

class ComponentDemoPage extends StatefulWidget {
  const ComponentDemoPage({super.key});

  @override
  State<ComponentDemoPage> createState() => _ComponentDemoPageState();
}

class _ComponentDemoPageState extends State<ComponentDemoPage> {
  final TextEditingController _searchController = TextEditingController(
    text: '斗破苍穹',
  );
  String _scope = 'all';
  String _sort = 'recent';
  String _viewMode = 'grid';
  bool _showProgress = true;
  bool _showLatestChapter = true;
  bool _onlyUpdates = false;
  bool _syncProgress = true;
  double _readerFontSize = 18;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewTheme = _buildLuminaTheme(Theme.of(context));
    return Theme(data: previewTheme, child: Builder(builder: _buildDemoPage));
  }

  Widget _buildDemoPage(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = AppAdaptiveMetrics.of(context);
    final routeTopBar = buildMineRouteTopBar(
      context: context,
      title: 'Lumina 组件样板',
      subtitle: '固定 Lumina 视觉基线，用于内部 QA 和视觉回归。',
      fallbackRoute: '/appearance',
    );
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final maxWidth = AppLayout.pageContentMaxWidth(
      context,
      maxWidth:
          metrics.isExpandedWindow ? 1080 : AppLayout.settingsContentMaxWidth,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: routeTopBar,
      body: DecoratedBox(
        decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                metrics.pagePadding,
                topInset +
                    routeTopBar.preferredSize.height +
                    metrics.contentGap,
                metrics.pagePadding,
                metrics.sectionGap + bottomInset,
              ),
              children: [
                _DemoSectionCard(
                  title: '搜索框',
                  icon: Icons.search_rounded,
                  child: Column(
                    children: [
                      AppTextField(
                        hintText: '搜索书名、作者、标签、分类',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: Padding(
                          padding: const EdgeInsetsDirectional.only(end: 12),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              '全部 1 本',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: metrics.contentGap),
                      AppTextField(
                        controller: _searchController,
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          tooltip: '清空',
                          onPressed:
                              _searchController.text.isEmpty
                                  ? null
                                  : () {
                                    setState(_searchController.clear);
                                  },
                          icon: const Icon(Icons.close_rounded),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: metrics.sectionGap),
                _ResponsiveDemoGrid(
                  children: [
                    _DemoSectionCard(
                      title: '按钮',
                      icon: Icons.smart_button_outlined,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          AppButton(
                            label: '开始阅读',
                            icon: const Icon(Icons.menu_book_rounded),
                            onPressed: () {},
                          ),
                          AppButton(
                            label: '加入书架',
                            icon: const Icon(Icons.library_add_rounded),
                            variant: AppButtonVariant.tonal,
                            style: _luminaTonalButtonStyle(theme),
                            onPressed: () {},
                          ),
                          AppButton(
                            label: '取消',
                            variant: AppButtonVariant.ghost,
                            onPressed: () {},
                          ),
                          IconButton.filledTonal(
                            tooltip: '更多',
                            onPressed: () {},
                            icon: const Icon(Icons.more_horiz_rounded),
                          ),
                          const AppButton(
                            label: '不可用',
                            onPressed: null,
                            variant: AppButtonVariant.secondary,
                          ),
                        ],
                      ),
                    ),
                    _DemoSectionCard(
                      title: '下拉框',
                      icon: Icons.arrow_drop_down_circle_outlined,
                      child: Column(
                        children: [
                          AppDropdownField<String>(
                            value: _scope,
                            options: const [
                              AppDropdownOption(value: 'all', label: '全部书籍'),
                              AppDropdownOption(value: 'recent', label: '最近阅读'),
                              AppDropdownOption(
                                value: 'updates',
                                label: '未读更新',
                              ),
                            ],
                            onSelected:
                                (value) => setState(() {
                                  _scope = value ?? _scope;
                                }),
                          ),
                          SizedBox(height: metrics.contentGap),
                          AppDropdownField<String>(
                            value: _sort,
                            options: const [
                              AppDropdownOption(
                                value: 'recent',
                                label: '按最近阅读排序',
                              ),
                              AppDropdownOption(
                                value: 'updated',
                                label: '按更新时间排序',
                              ),
                              AppDropdownOption(value: 'title', label: '按书名排序'),
                            ],
                            onSelected:
                                (value) => setState(() {
                                  _sort = value ?? _sort;
                                }),
                          ),
                        ],
                      ),
                    ),
                    _DemoSectionCard(
                      title: '单选',
                      icon: Icons.radio_button_checked_rounded,
                      child: Column(
                        children: [
                          _RadioOption(
                            value: 'grid',
                            groupValue: _viewMode,
                            label: '书架网格',
                            onChanged: _setViewMode,
                          ),
                          const SizedBox(height: 8),
                          _RadioOption(
                            value: 'list',
                            groupValue: _viewMode,
                            label: '紧凑列表',
                            onChanged: _setViewMode,
                          ),
                          const SizedBox(height: 8),
                          _RadioOption(
                            value: 'records',
                            groupValue: _viewMode,
                            label: '阅读记录',
                            onChanged: _setViewMode,
                          ),
                        ],
                      ),
                    ),
                    _DemoSectionCard(
                      title: '多选',
                      icon: Icons.check_box_outlined,
                      child: Column(
                        children: [
                          _CheckboxOption(
                            value: _showProgress,
                            label: '显示阅读进度',
                            onChanged:
                                (value) => setState(() {
                                  _showProgress = value;
                                }),
                          ),
                          const SizedBox(height: 8),
                          _CheckboxOption(
                            value: _showLatestChapter,
                            label: '显示最新章节',
                            onChanged:
                                (value) => setState(() {
                                  _showLatestChapter = value;
                                }),
                          ),
                          const SizedBox(height: 8),
                          _CheckboxOption(
                            value: _onlyUpdates,
                            label: '仅看有更新',
                            onChanged:
                                (value) => setState(() {
                                  _onlyUpdates = value;
                                }),
                          ),
                        ],
                      ),
                    ),
                    _DemoSectionCard(
                      title: '标签',
                      icon: Icons.sell_outlined,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('全部'),
                            selected: true,
                            onSelected: (_) {},
                          ),
                          FilterChip(
                            label: const Text('玄幻'),
                            selected: false,
                            onSelected: (_) {},
                          ),
                          FilterChip(
                            label: const Text('科幻'),
                            selected: false,
                            onSelected: (_) {},
                          ),
                          FilterChip(
                            label: const Text('已完结'),
                            selected: false,
                            onSelected: (_) {},
                          ),
                          FilterChip(
                            label: const Text('有更新'),
                            selected: _onlyUpdates,
                            onSelected:
                                (value) => setState(() {
                                  _onlyUpdates = value;
                                }),
                          ),
                        ],
                      ),
                    ),
                    _DemoSectionCard(
                      title: '开关与滑条',
                      icon: Icons.tune_rounded,
                      child: Column(
                        children: [
                          _SwitchRow(
                            value: _syncProgress,
                            label: '自动同步阅读进度',
                            onChanged:
                                (value) => setState(() {
                                  _syncProgress = value;
                                }),
                          ),
                          SizedBox(height: metrics.contentGap),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '阅读字号 ${_readerFontSize.round()}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Slider(
                            value: _readerFontSize,
                            min: 14,
                            max: 28,
                            divisions: 14,
                            label: _readerFontSize.round().toString(),
                            onChanged:
                                (value) => setState(() {
                                  _readerFontSize = value;
                                }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: metrics.sectionGap),
                _DemoSectionCard(
                  title: '列表',
                  icon: Icons.list_alt_rounded,
                  child: Column(
                    children: const [
                      _DemoListTile(
                        icon: Icons.update_rounded,
                        title: '斗破苍穹',
                        subtitle: '最新: 第七百八十一章 · 2 分钟前',
                      ),
                      SizedBox(height: 8),
                      _DemoListTile(
                        icon: Icons.bookmark_border_rounded,
                        title: '旧世界的门',
                        subtitle: '书签 · 第 162 章 · 21:42',
                      ),
                      SizedBox(height: 8),
                      _DemoListTile(
                        icon: Icons.public_rounded,
                        title: '书源 A',
                        subtitle: '可用 · 响应 320ms · 目录完整',
                      ),
                    ],
                  ),
                ),
                SizedBox(height: metrics.sectionGap),
                _ResponsiveDemoGrid(
                  children: const [
                    _DemoSectionCard(
                      title: '加载骨架',
                      icon: Icons.hourglass_top_rounded,
                      child: AppSkeletonList(
                        itemCount: 3,
                        itemHeight: 64,
                        showTrailing: true,
                      ),
                    ),
                    _DemoSectionCard(
                      title: '空状态',
                      icon: Icons.inbox_outlined,
                      child: AppEmptyStateCard(
                        icon: Icons.auto_stories_outlined,
                        title: '暂无书籍',
                        description: '导入本地文件后，书籍会出现在这里。',
                        compact: true,
                      ),
                    ),
                    _DemoSectionCard(
                      title: '警告状态',
                      icon: Icons.warning_amber_rounded,
                      child: AppStatusStateCard(
                        icon: Icons.cloud_off_outlined,
                        title: '同步暂不可用',
                        message: '网络恢复后会自动继续同步阅读进度。',
                        tone: AppStatusStateTone.warning,
                        compact: true,
                      ),
                    ),
                    _DemoSectionCard(
                      title: '错误状态',
                      icon: Icons.error_outline_rounded,
                      child: AppStatusStateCard(
                        icon: Icons.report_gmailerrorred_rounded,
                        title: '导入失败',
                        message: '文件格式无法识别，请重新选择或查看错误中心。',
                        tone: AppStatusStateTone.error,
                        compact: true,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: metrics.sectionGap),
                _DemoSectionCard(
                  title: '页面状态',
                  icon: Icons.rule_folder_outlined,
                  child: _DemoStateMatrix(onRetry: () {}, onDestructive: () {}),
                ),
                SizedBox(height: metrics.sectionGap),
                _DemoSectionCard(
                  title: '业务模式',
                  icon: Icons.dashboard_customize_outlined,
                  child: _ResponsiveDemoGrid(
                    children: const [
                      _DemoBookCard(),
                      _DemoThemeCard(),
                      _DemoSourceCard(),
                      _DemoReaderSettingRow(),
                      _DemoImageResourceTile(),
                      _DemoTaskCard(),
                    ],
                  ),
                ),
                SizedBox(height: metrics.sectionGap),
                AdaptiveSettingSection(
                  child: Column(
                    children: const [
                      AdaptiveSettingTile(
                        icon: Icons.palette_outlined,
                        title: '设置项样例',
                        description: '用于观察 Mine/Appearance 内常见设置卡片的真实效果。',
                        trailing: Icon(Icons.chevron_right_rounded),
                      ),
                      SizedBox(height: 10),
                      AdaptiveSettingTile(
                        icon: Icons.auto_awesome_outlined,
                        title: '高级主题覆盖',
                        description: '切换主题色或高级主题后，这里的颜色、边框和圆角会跟随 ThemeData。',
                        trailing: Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setViewMode(String? value) {
    if (value == null) {
      return;
    }
    setState(() {
      _viewMode = value;
    });
  }
}

ThemeData _buildLuminaTheme(ThemeData base) {
  final preset = appOfficialThemePresetById(AppOfficialThemePresetId.lumina);
  final isDark = base.brightness == Brightness.dark;
  final scheme =
      isDark
          ? buildAppBaseDarkColorScheme(preset.id.defaultBaseColorSchemeId)
          : buildAppBaseLightColorScheme(preset.id.defaultBaseColorSchemeId);
  final modeConfig = isDark ? preset.darkConfig : preset.lightConfig;
  return AppTheme.build(scheme, advancedModeConfig: modeConfig);
}

ButtonStyle _luminaTonalButtonStyle(ThemeData theme) {
  final scheme = theme.colorScheme;
  return FilledButton.styleFrom(
    backgroundColor: scheme.primaryContainer,
    foregroundColor: scheme.primary,
    disabledBackgroundColor: scheme.surfaceContainerHighest,
    disabledForegroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.48),
  );
}

class _ResponsiveDemoGrid extends StatelessWidget {
  const _ResponsiveDemoGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final columns = metrics.isMediumUpWindow ? 2 : 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = metrics.contentGap;
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class _DemoSectionCard extends StatelessWidget {
  const _DemoSectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = AppAdaptiveMetrics.of(context);
    return AdaptiveCard(
      color: theme.colorScheme.surfaceContainerLow,
      borderColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.46),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: metrics.isCompactDensity ? 28 : 30,
                height: metrics.isCompactDensity ? 28 : 30,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.72,
                  ),
                  borderRadius: BorderRadius.circular(
                    metrics.cardRadius * 0.62,
                  ),
                ),
                child: Icon(
                  icon,
                  size: metrics.isCompactDensity ? 16 : 17,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              SizedBox(width: metrics.contentGap),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: metrics.contentGap),
          child,
        ],
      ),
    );
  }
}

class _RadioOption extends StatelessWidget {
  const _RadioOption({
    required this.value,
    required this.groupValue,
    required this.label,
    required this.onChanged,
  });

  final String value;
  final String groupValue;
  final String label;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = value == groupValue;
    return _OptionShell(
      onTap: () => onChanged(value),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 14, end: 12),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                  width: selected ? 5 : 1.2,
                ),
              ),
            ),
          ),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _CheckboxOption extends StatelessWidget {
  const _CheckboxOption({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _OptionShell(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Checkbox(value: value, onChanged: (next) => onChanged(next ?? value)),
          const SizedBox(width: 2),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _OptionShell(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _OptionShell extends StatelessWidget {
  const _OptionShell({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = AppAdaptiveMetrics.of(context);
    final radius = BorderRadius.circular(metrics.cardRadius * 0.82);
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.56),
        ),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: metrics.minTouchTargetSize),
            child: DefaultTextStyle.merge(
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoListTile extends StatelessWidget {
  const _DemoListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = AppAdaptiveMetrics.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(metrics.cardRadius),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.56),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(metrics.cardRadius),
        onTap: () {},
        child: Padding(
          padding: EdgeInsets.all(metrics.isCompactDensity ? 10 : 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.55,
                  ),
                  borderRadius: BorderRadius.circular(
                    metrics.cardRadius * 0.82,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              SizedBox(width: metrics.contentGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: metrics.contentGap),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoStateMatrix extends StatelessWidget {
  const _DemoStateMatrix({required this.onRetry, required this.onDestructive});

  final VoidCallback onRetry;
  final VoidCallback onDestructive;

  @override
  Widget build(BuildContext context) {
    return _ResponsiveDemoGrid(
      children: [
        const AppStateView(
          kind: AppViewStateKind.loading,
          title: '正在加载',
          description: '读取主题资源和本地缓存。',
          compact: true,
        ),
        const AppStateView(
          kind: AppViewStateKind.locked,
          title: '需要会员',
          description: '自定义高级主题编辑需要会员权益。',
          compact: true,
        ),
        const AppStateView(
          kind: AppViewStateKind.offline,
          title: '离线状态',
          description: '网络恢复后可继续同步。',
          compact: true,
        ),
        const AppStateView(
          kind: AppViewStateKind.progress,
          title: '正在导入',
          description: '3 / 8 个资源包',
          progress: 0.38,
          compact: true,
        ),
        AppStateView(
          kind: AppViewStateKind.filteredEmpty,
          title: '没有筛选结果',
          description: '换个关键词或清空筛选条件。',
          primaryAction: AppStateAction(
            label: '清空筛选',
            icon: const Icon(Icons.filter_alt_off_outlined),
            onPressed: onRetry,
          ),
          compact: true,
        ),
        AppStateView(
          kind: AppViewStateKind.error,
          title: '导入失败',
          description: '资源包缺少 manifest，请重新选择文件。',
          primaryAction: AppStateAction(
            label: '重试',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: onRetry,
          ),
          secondaryAction: AppStateAction(
            label: '删除任务',
            icon: const Icon(Icons.delete_outline),
            variant: AppButtonVariant.danger,
            onPressed: onDestructive,
          ),
          footer: const Text('诊断码: THEME_IMPORT_MANIFEST_MISSING'),
          compact: true,
        ),
        const AppStateView(
          kind: AppViewStateKind.error,
          title: '依赖不可用',
          description: '请先选择封面图集，再启用主题封面补位。',
          primaryAction: AppStateAction(label: '选择图集', onPressed: null),
          compact: true,
        ),
      ],
    );
  }
}

class _DemoBookCard extends StatelessWidget {
  const _DemoBookCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppPanel(
      title: '书籍卡',
      leading: const Icon(Icons.menu_book_outlined),
      child: Row(
        children: [
          const SizedBox(
            width: 48,
            height: 66,
            child: TextCoverPlaceholder(title: '长夜余火', width: 48, height: 66),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '长夜余火',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '第 218 章 · 阅读 64%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoThemeCard extends StatelessWidget {
  const _DemoThemeCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppPanel(
      title: '主题卡',
      leading: const Icon(Icons.auto_awesome_outlined),
      trailing: const ImageResourceUsageBadge(label: '当前'),
      child: Row(
        children: [
          for (final color in [
            scheme.primary,
            scheme.secondary,
            scheme.surfaceContainerHighest,
            scheme.tertiary,
          ])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: SizedBox(
                  height: 36,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DemoSourceCard extends StatelessWidget {
  const _DemoSourceCard();

  @override
  Widget build(BuildContext context) {
    return const AppPanel(
      title: '书源卡',
      subtitle: '响应 320ms · 目录完整 · 最近测试成功',
      leading: Icon(Icons.public_rounded),
      child: AppInlineProgress(
        label: '健康检查',
        message: '正在验证搜索、详情、目录、正文',
        value: 0.72,
      ),
    );
  }
}

class _DemoReaderSettingRow extends StatelessWidget {
  const _DemoReaderSettingRow();

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      title: '阅读设置行',
      leading: const Icon(Icons.format_size_rounded),
      child: Row(
        children: [
          Text(
            '字号',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Slider(value: 0.5, onChanged: null)),
          const SizedBox(width: 12),
          const Text('18'),
        ],
      ),
    );
  }
}

class _DemoImageResourceTile extends StatelessWidget {
  const _DemoImageResourceTile();

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      title: '资源 Tile',
      leading: const Icon(Icons.image_outlined),
      trailing: const ImageResourceUsageBadge(label: '主题默认'),
      child: AspectRatio(
        aspectRatio: 3,
        child: Row(
          children: const [
            Expanded(child: _DemoImageSwatch(index: 0)),
            SizedBox(width: 6),
            Expanded(child: _DemoImageSwatch(index: 1)),
            SizedBox(width: 6),
            Expanded(child: _DemoImageSwatch(index: 2)),
          ],
        ),
      ),
    );
  }
}

class _DemoImageSwatch extends StatelessWidget {
  const _DemoImageSwatch({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = [
      scheme.primaryContainer,
      scheme.secondaryContainer,
      scheme.tertiaryContainer,
    ];
    return AppSurface(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(10),
      backgroundColor: colors[index],
      child: Center(
        child: Icon(Icons.image_outlined, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _DemoTaskCard extends StatelessWidget {
  const _DemoTaskCard();

  @override
  Widget build(BuildContext context) {
    return const AppPanel(
      title: '任务卡',
      leading: Icon(Icons.task_alt_rounded),
      child: AppTaskProgressRow(
        title: '导出主题资源',
        message: '正在写入封面图集和启动图集',
        value: 0.64,
      ),
    );
  }
}
