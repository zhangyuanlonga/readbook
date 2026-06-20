import 'package:flutter/material.dart';

import '../layout/app_adaptive.dart';
import '../layout/app_spacing.dart';
import 'adaptive_overflow_toolbar.dart';

/// 独立路由使用的自适应顶栏。
///
/// 搜索页、详情页这类页面不在 ShellScaffold 内，不能直接复用桌面 Shell 顶栏。
/// 本组件只提供路由级顶栏骨架：移动端保留轻量 AppBar 语义，桌面端再承载
/// 搜索输入、筛选、主操作和 overflow，避免后续页面各自手搓一套顶栏。
class AdaptiveRouteTopBar extends StatelessWidget
    implements PreferredSizeWidget {
  const AdaptiveRouteTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.titleWidget,
    this.leading,
    this.middle,
    this.bottom,
    this.actions = const <AdaptiveOverflowToolbarItem>[],
    this.mobileActions = const <Widget>[],
    this.backgroundColor,
    this.foregroundColor,
    this.surfaceTintColor = Colors.transparent,
    this.shadowColor = Colors.transparent,
    this.dividerColor,
    this.mobileHeight = kToolbarHeight,
    this.desktopHeight = 64,
    this.titleMaxWidth = 260,
    this.middleMinWidth = 180,
    this.middleMaxWidth = 520,
    this.moreTooltip = '更多',
    this.showDesktopTitle = true,
  });

  final String title;
  final String? subtitle;
  final Widget? titleWidget;
  final Widget? leading;
  final Widget? middle;
  final PreferredSizeWidget? bottom;
  final List<AdaptiveOverflowToolbarItem> actions;
  final List<Widget> mobileActions;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? surfaceTintColor;
  final Color? shadowColor;
  final Color? dividerColor;
  final double mobileHeight;
  final double desktopHeight;
  final double titleMaxWidth;
  final double middleMinWidth;
  final double middleMaxWidth;
  final String moreTooltip;
  final bool showDesktopTitle;

  @override
  Size get preferredSize =>
      Size.fromHeight(desktopHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    if (!metrics.isMediumUpWindow) {
      return _MobileRouteTopBar(
        title: title,
        titleWidget: titleWidget,
        leading: leading,
        bottom: bottom,
        actions: mobileActions,
        height: mobileHeight,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        surfaceTintColor: surfaceTintColor,
        shadowColor: shadowColor,
      );
    }

    final topPadding = MediaQuery.paddingOf(context).top;
    return _DesktopRouteTopBar(
      title: title,
      subtitle: subtitle,
      titleWidget: titleWidget,
      leading: leading,
      middle: middle,
      bottom: bottom,
      actions: actions,
      height: desktopHeight,
      topPadding: topPadding,
      titleMaxWidth: titleMaxWidth,
      middleMinWidth: middleMinWidth,
      middleMaxWidth: middleMaxWidth,
      moreTooltip: moreTooltip,
      showTitle: showDesktopTitle,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      surfaceTintColor: surfaceTintColor,
      shadowColor: shadowColor,
      dividerColor: dividerColor,
    );
  }
}

class _MobileRouteTopBar extends StatelessWidget {
  const _MobileRouteTopBar({
    required this.title,
    required this.titleWidget,
    required this.leading,
    required this.bottom,
    required this.actions,
    required this.height,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.surfaceTintColor,
    required this.shadowColor,
  });

  final String title;
  final Widget? titleWidget;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final List<Widget> actions;
  final double height;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? surfaceTintColor;
  final Color? shadowColor;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: height,
      title: titleWidget ?? Text(title),
      leading: leading,
      actions: actions,
      bottom: bottom,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      surfaceTintColor: surfaceTintColor,
      shadowColor: shadowColor,
    );
  }
}

class _DesktopRouteTopBar extends StatelessWidget {
  const _DesktopRouteTopBar({
    required this.title,
    required this.subtitle,
    required this.titleWidget,
    required this.leading,
    required this.middle,
    required this.bottom,
    required this.actions,
    required this.height,
    required this.topPadding,
    required this.titleMaxWidth,
    required this.middleMinWidth,
    required this.middleMaxWidth,
    required this.moreTooltip,
    required this.showTitle,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.surfaceTintColor,
    required this.shadowColor,
    required this.dividerColor,
  });

  final String title;
  final String? subtitle;
  final Widget? titleWidget;
  final Widget? leading;
  final Widget? middle;
  final PreferredSizeWidget? bottom;
  final List<AdaptiveOverflowToolbarItem> actions;
  final double height;
  final double topPadding;
  final double titleMaxWidth;
  final double middleMinWidth;
  final double middleMaxWidth;
  final String moreTooltip;
  final bool showTitle;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? surfaceTintColor;
  final Color? shadowColor;
  final Color? dividerColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final resolvedBackground = backgroundColor ?? colorScheme.surface;
    final resolvedForeground = foregroundColor ?? colorScheme.onSurface;
    final resolvedDivider =
        dividerColor ?? colorScheme.outlineVariant.withValues(alpha: 0.7);
    final horizontal = AppSpacing.pageHorizontal(context);

    final bottomWidget = bottom;
    return Material(
      color: resolvedBackground,
      surfaceTintColor: surfaceTintColor,
      shadowColor: shadowColor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: resolvedDivider)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: height + topPadding,
              child: Padding(
                padding: EdgeInsets.only(top: topPadding),
                child: SizedBox(
                  height: height,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontal),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final showMiddle =
                            middle != null &&
                            constraints.maxWidth >=
                                titleMaxWidth + middleMinWidth + 220;
                        final toolbarWidth =
                            constraints.maxWidth < 760
                                ? 96.0
                                : constraints.maxWidth < 920
                                ? 136.0
                                : 184.0;

                        return Row(
                          children: [
                            if (leading != null) ...[
                              SizedBox(width: 44, height: 44, child: leading),
                              const SizedBox(width: 8),
                            ],
                            if (showTitle)
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: titleMaxWidth,
                                ),
                                child:
                                    titleWidget ??
                                    _DesktopRouteTitle(
                                      title: title,
                                      subtitle: subtitle,
                                      foregroundColor: resolvedForeground,
                                    ),
                              ),
                            if (showMiddle) ...[
                              const SizedBox(width: 18),
                              Expanded(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: middleMinWidth,
                                    maxWidth: middleMaxWidth,
                                  ),
                                  child: middle!,
                                ),
                              ),
                            ] else
                              const Spacer(),
                            if (actions.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              SizedBox(
                                width: toolbarWidth,
                                child: AdaptiveOverflowToolbar(
                                  items: actions,
                                  moreTooltip: moreTooltip,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            if (bottomWidget != null) bottomWidget,
          ],
        ),
      ),
    );
  }
}

class _DesktopRouteTitle extends StatelessWidget {
  const _DesktopRouteTitle({
    required this.title,
    required this.subtitle,
    required this.foregroundColor,
  });

  final String title;
  final String? subtitle;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subtitleText = subtitle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium?.copyWith(
            color: foregroundColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitleText != null && subtitleText.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitleText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: foregroundColor.withValues(alpha: 0.68),
            ),
          ),
        ],
      ],
    );
  }
}
