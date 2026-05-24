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
          '发现页将由服务器书源网关提供，当前版本优先打磨本地阅读和搜索体验。',
        ),
        icon: Icons.explore_off_outlined,
      );

  static FeatureDisabledPage onlineSearch({AppCapabilityState? capability}) =>
      FeatureDisabledPage(
        title: '在线搜索暂未启用',
        message: _messageFromCapability(
          capability,
          '在线搜索将由服务器书源网关提供。当前环境暂未开放该能力，可继续使用本地书库和本地阅读。',
        ),
        icon: Icons.search_off_rounded,
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
