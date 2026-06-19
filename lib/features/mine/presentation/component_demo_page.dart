import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../app/layout/app_layout.dart';
import '../../../app/theme/app_advanced_theme_tokens.dart';
import '../../../app/theme/app_component_theme_tokens.dart';
import '../../../app/widgets/adaptive_card.dart';
import '../../../app/widgets/adaptive_setting_tile.dart';
import '../../../app/widgets/advanced_theme_backdrop_decoration.dart';
import '../../../app/widgets/foundation/foundation.dart';
import '../application/advanced_theme_provider.dart';
import 'widgets/mine_route_top_bar.dart';

enum ComponentDemoStyle { currentTheme, lumina }

class ComponentDemoPage extends ConsumerStatefulWidget {
  const ComponentDemoPage({
    super.key,
    this.style = ComponentDemoStyle.currentTheme,
  });

  const ComponentDemoPage.lumina({super.key})
    : style = ComponentDemoStyle.lumina;

  final ComponentDemoStyle style;

  @override
  ConsumerState<ComponentDemoPage> createState() => _ComponentDemoPageState();
}

class _ComponentDemoPageState extends ConsumerState<ComponentDemoPage> {
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
    final previewTheme =
        widget.style == ComponentDemoStyle.lumina
            ? _buildLuminaTheme(Theme.of(context))
            : Theme.of(context);
    return Theme(data: previewTheme, child: Builder(builder: _buildDemoPage));
  }

  Widget _buildDemoPage(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = AppAdaptiveMetrics.of(context);
    final isLumina = widget.style == ComponentDemoStyle.lumina;
    final backdrop =
        isLumina
            ? null
            : resolveAdvancedThemeBackdrop(
              theme.colorScheme,
              ref.watch(activeAdvancedThemeProvider).valueOrNull,
            );
    final routeTopBar = buildMineRouteTopBar(
      context: context,
      title: isLumina ? 'Lumina 组件样板' : '组件样板',
      subtitle: isLumina ? '局部套用 Lumina 风格，不跟随当前主题色' : '真实 Flutter 控件与当前主题效果',
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
        decoration:
            isLumina
                ? BoxDecoration(color: theme.scaffoldBackgroundColor)
                : buildAdvancedThemeBackdropDecoration(backdrop!),
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
                            style:
                                isLumina
                                    ? _luminaTonalButtonStyle(theme)
                                    : null,
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
  final brightness = base.brightness;
  final scheme = _luminaColorScheme(brightness);
  final tokens = _luminaComponentTokens(scheme);
  final buttonShape = const StadiumBorder();
  final inputRadius = BorderRadius.circular(tokens.input.radius);
  final outlineBorder = OutlineInputBorder(
    borderRadius: inputRadius,
    borderSide: BorderSide(
      color: scheme.outlineVariant,
      width: tokens.input.borderWidth,
    ),
  );
  final focusedBorder = OutlineInputBorder(
    borderRadius: inputRadius,
    borderSide: BorderSide(
      color: scheme.secondary,
      width: tokens.input.focusedBorderWidth,
    ),
  );

  return base.copyWith(
    colorScheme: scheme,
    extensions: <ThemeExtension<dynamic>>[tokens],
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.card.radius),
        side: BorderSide(
          color: scheme.outlineVariant,
          width: tokens.card.borderWidth,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: Size(0, tokens.button.height),
        shape: buttonShape,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.button.horizontalPadding,
        ),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        disabledBackgroundColor: scheme.surfaceContainerHighest,
        disabledForegroundColor: scheme.onSurfaceVariant.withValues(
          alpha: 0.48,
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(0, tokens.button.height),
        shape: buttonShape,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.button.horizontalPadding,
        ),
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: Size(0, tokens.button.height),
        shape: buttonShape,
        foregroundColor: scheme.onSurfaceVariant,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.button.horizontalPadding,
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: scheme.primary,
        backgroundColor: scheme.primaryContainer,
        disabledForegroundColor: scheme.onSurfaceVariant.withValues(
          alpha: 0.45,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: outlineBorder,
      enabledBorder: outlineBorder,
      disabledBorder: outlineBorder,
      focusedBorder: focusedBorder,
      errorBorder: outlineBorder.copyWith(
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: focusedBorder.copyWith(
        borderSide: BorderSide(color: scheme.error),
      ),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: scheme.surface,
      selectedColor: scheme.primaryContainer,
      disabledColor: scheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
      secondaryLabelStyle: TextStyle(
        color: scheme.primary,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.selection.chipRadius),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      side: BorderSide(color: scheme.outlineVariant),
      checkmarkColor: scheme.primary,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return scheme.secondary;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(scheme.surface),
      side: BorderSide(color: scheme.outline, width: 1.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return scheme.surface;
        }
        return scheme.onSurfaceVariant;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return scheme.secondary;
        }
        return scheme.surfaceContainerHighest;
      }),
      trackOutlineColor: WidgetStateProperty.all(scheme.outlineVariant),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: scheme.secondary,
      inactiveTrackColor: scheme.surfaceContainerHighest,
      thumbColor: scheme.secondary,
      overlayColor: scheme.secondary.withValues(alpha: 0.12),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: outlineBorder,
        enabledBorder: outlineBorder,
        focusedBorder: focusedBorder,
      ),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStateProperty.all(scheme.surface),
        surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.overlay.radius),
            side: BorderSide(color: scheme.outlineVariant),
          ),
        ),
      ),
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
    ),
  );
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

ColorScheme _luminaColorScheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final base = ColorScheme.fromSeed(
    seedColor: isDark ? const Color(0xFFC0C7D6) : const Color(0xFF68717E),
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.neutral,
  );
  if (isDark) {
    return base.copyWith(
      primary: const Color(0xFFE5E2E1),
      onPrimary: const Color(0xFF141414),
      primaryContainer: const Color(0xFF313030),
      onPrimaryContainer: const Color(0xFFF4F0EF),
      secondary: const Color(0xFFC0C7D6),
      onSecondary: const Color(0xFF1C2430),
      secondaryContainer: const Color(0xFF2B3039),
      onSecondaryContainer: const Color(0xFFE8EDF7),
      tertiary: const Color(0xFFB9AEC8),
      onTertiary: const Color(0xFF2D2536),
      tertiaryContainer: const Color(0xFF3A3244),
      onTertiaryContainer: const Color(0xFFF0E7FA),
      surface: const Color(0xFF141414),
      surfaceDim: const Color(0xFF141414),
      surfaceBright: const Color(0xFF242323),
      surfaceContainerLowest: const Color(0xFF101010),
      surfaceContainerLow: const Color(0xFF1B1A1A),
      surfaceContainer: const Color(0xFF201F1F),
      surfaceContainerHigh: const Color(0xFF242323),
      surfaceContainerHighest: const Color(0xFF313030),
      onSurface: const Color(0xFFF4F0EF),
      onSurfaceVariant: const Color(0xFFC8C6C5),
      outline: const Color(0xFF555252),
      outlineVariant: const Color(0xFF373535),
      inverseSurface: const Color(0xFFE5E2E1),
      onInverseSurface: const Color(0xFF1C1B1B),
      surfaceTint: Colors.transparent,
      shadow: Colors.black,
    );
  }
  return base.copyWith(
    primary: const Color(0xFF1C1B1B),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFF3F6F8),
    onPrimaryContainer: const Color(0xFF1C1B1B),
    secondary: const Color(0xFF68717E),
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFF3F6F8),
    onSecondaryContainer: const Color(0xFF1C1B1B),
    tertiary: const Color(0xFF746B87),
    onTertiary: Colors.white,
    tertiaryContainer: const Color(0xFFF4F0F8),
    onTertiaryContainer: const Color(0xFF292330),
    surface: Colors.white,
    surfaceDim: Colors.white,
    surfaceBright: Colors.white,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Colors.white,
    surfaceContainer: Colors.white,
    surfaceContainerHigh: const Color(0xFFFAFBFD),
    surfaceContainerHighest: const Color(0xFFF6F7F9),
    onSurface: const Color(0xFF1C1B1B),
    onSurfaceVariant: const Color(0xFF606773),
    outline: const Color(0xFFD5DAE2),
    outlineVariant: const Color(0xFFEDF0F4),
    inverseSurface: const Color(0xFF2E3132),
    onInverseSurface: const Color(0xFFF0F1F2),
    surfaceTint: Colors.transparent,
    shadow: const Color(0xFF0F172A),
  );
}

AppComponentThemeTokens _luminaComponentTokens(ColorScheme scheme) {
  final base = resolveAppComponentThemeTokens(scheme);
  final isDark = scheme.brightness == Brightness.dark;
  return base.copyWith(
    card: base.card.copyWith(
      radius: 16,
      elevation: 0,
      borderWidth: 1,
      shadowBlur: 10,
      shadowOffsetY: 4,
      shadowAlpha: isDark ? 0.28 : 0.045,
    ),
    button: base.button.copyWith(
      shapeStyle: AppButtonShapeStyle.stadium,
      height: 40,
      horizontalPadding: 15,
      outlinedBorderWidth: 1,
    ),
    input: base.input.copyWith(
      radius: 16,
      borderWidth: 1,
      focusedBorderWidth: 1.2,
    ),
    overlay: base.overlay.copyWith(
      radius: 16,
      topRadius: 20,
      borderWidth: 1,
      shadowBlur: 12,
      shadowOffsetY: 6,
      shadowAlpha: isDark ? 0.34 : 0.08,
    ),
    selection: base.selection.copyWith(
      chipRadius: 12,
      chipBorderWidth: 0.8,
      tabIndicatorRadius: 12,
      segmentRadius: 12,
      segmentBorderWidth: 0.8,
      switchTrackOutlineWidth: 0.8,
    ),
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
