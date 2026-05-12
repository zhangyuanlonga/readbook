import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/composition/app_providers.dart' as app_providers;
import '../../app/widgets/feature_disabled_page.dart';
import 'presentation/discover_page.dart';

final StatefulShellBranch discoverShellBranch = StatefulShellBranch(
  routes: [
    GoRoute(
      path: '/discover',
      name: 'discover',
      builder: (context, state) {
        final supportsSourceRuntime =
            ProviderScope.containerOf(
              context,
              listen: false,
            ).read(app_providers.appCapabilitiesProvider).supportsSourceRuntime;
        if (!supportsSourceRuntime) {
          return const FeatureDisabledPage(
            title: '发现暂未启用',
            message: '发现页依赖在线书源和脚本运行时，已移出全平台首版范围。当前版本优先打磨本地阅读体验。',
            icon: Icons.explore_off_outlined,
          );
        }
        return const DiscoverPage();
      },
    ),
  ],
);
