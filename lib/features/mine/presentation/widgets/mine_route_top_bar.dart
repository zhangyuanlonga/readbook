import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/widgets/adaptive_overflow_toolbar.dart';
import '../../../../app/widgets/adaptive_route_top_bar.dart';

/// 我的模块独立路由统一顶栏。
///
/// 外观、资源管理、系统设置和信息类页面都不在 Shell 顶栏内，这里只收口共同
/// 的返回、透明背景和桌面 overflow 骨架；具体业务操作仍留在页面自身。
PreferredSizeWidget buildMineRouteTopBar({
  required BuildContext context,
  required String title,
  String? subtitle,
  String fallbackRoute = '/mine',
  List<AdaptiveOverflowToolbarItem> actions =
      const <AdaptiveOverflowToolbarItem>[],
  List<Widget> mobileActions = const <Widget>[],
  VoidCallback? onBack,
}) {
  return AdaptiveRouteTopBar(
    title: title,
    subtitle: subtitle,
    leading: IconButton(
      tooltip: '返回',
      onPressed:
          onBack ??
          () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go(fallbackRoute);
          },
      icon: const Icon(Icons.arrow_back),
    ),
    actions: actions,
    mobileActions: mobileActions,
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    dividerColor: Colors.transparent,
    desktopHeight: kToolbarHeight,
  );
}
