import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../layout/app_adaptive.dart';
import '../layout/app_layout.dart';
import '../platform/app_capability_state.dart';
import '../theme/app_advanced_theme_tokens.dart';
import 'advanced_theme_backdrop_decoration.dart';
import 'app_status_state_card.dart';

class FeatureDisabledPage extends StatelessWidget {
  const FeatureDisabledPage({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.extension_off_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final metrics = AppAdaptiveMetrics.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final backdrop = resolveAdvancedThemeBackdrop(colorScheme, null);
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/bookshelf');
          },
        ),
      ),
      body: DecoratedBox(
        decoration: buildAdvancedThemeBackdropDecoration(backdrop),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AppLayout.pageContentMaxWidth(context, maxWidth: 560),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                metrics.pagePadding,
                topInset + metrics.sectionGap,
                metrics.pagePadding,
                metrics.sectionGap,
              ),
              child: AppStatusStateCard(
                icon: icon,
                title: title,
                message: message,
                tone: AppStatusStateTone.neutral,
                actionLabel: actionLabel ?? '返回书架',
                onAction: onAction ?? () => context.go('/bookshelf'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FeatureDisabledPages {
  const FeatureDisabledPages._();

  static FeatureDisabledPage discover({AppCapabilityState? capability}) =>
      FeatureDisabledPage(
        title: '发现暂未启用',
        message: _messageFromCapability(
          capability,
          '发现页依赖在线书源和脚本运行时，已移出全平台首版范围。当前版本优先打磨本地阅读体验。',
        ),
        icon: Icons.explore_off_outlined,
      );

  static FeatureDisabledPage onlineSearch({AppCapabilityState? capability}) =>
      FeatureDisabledPage(
        title: '在线搜索暂未启用',
        message: _messageFromCapability(
          capability,
          '全平台首版先聚焦本地书库和本地阅读。在线搜索依赖书源运行时，后续会随书源专题恢复。',
        ),
        icon: Icons.search_off_rounded,
      );

  static FeatureDisabledPage webDavSync({
    AppCapabilityState? capability,
  }) => FeatureDisabledPage(
    title: '同步功能暂未启用',
    message: _messageFromCapability(
      capability,
      '首版全平台先保证本地阅读和常用业务闭环。WebDAV 同步已放入 P1+，默认不参与首版验收；可继续使用本地书架、书签、阅读记录和外观设置。',
    ),
    icon: Icons.sync_disabled_rounded,
  );

  static FeatureDisabledPage syncHistory({AppCapabilityState? capability}) =>
      FeatureDisabledPage(
        title: '同步历史暂不可用',
        message: _messageFromCapability(
          capability,
          '当前平台未开放 WebDAV 同步能力，因此不会产生同步历史。首版可继续使用本地阅读记录和书签。',
        ),
        icon: Icons.history_toggle_off_rounded,
      );

  static FeatureDisabledPage onlineBookDetail({
    AppCapabilityState? capability,
  }) => FeatureDisabledPage(
    title: '在线详情暂未启用',
    message: _messageFromCapability(
      capability,
      '全平台首版先交付本地阅读闭环。在线详情、目录刷新和章节读取会随书源专题恢复。',
    ),
  );

  static FeatureDisabledPage onlineChapter({AppCapabilityState? capability}) =>
      FeatureDisabledPage(
        title: '在线章节暂未启用',
        message: _messageFromCapability(
          capability,
          '当前全平台首版只保证本地阅读。在线章节读取、换源和章节缓存会随书源专题恢复。',
        ),
      );

  static String _messageFromCapability(
    AppCapabilityState? capability,
    String fallback,
  ) {
    final reason = capability?.reason?.trim();
    if (reason == null || reason.isEmpty) {
      return fallback;
    }
    return '$fallback\n\n${capability!.label}：$reason';
  }
}
