import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/widgets/feature_disabled_page.dart';

final StatefulShellBranch discoverShellBranch = StatefulShellBranch(
  routes: [
    GoRoute(
      path: '/discover',
      name: 'discover',
      builder:
          (context, state) => const FeatureDisabledPage(
            title: '服务器发现开发中',
            message: '发现页将切换到服务器书源网关实现。当前版本先保留本地阅读和搜索能力，待服务器发现能力完成后再开放。',
            icon: Icons.travel_explore_rounded,
          ),
    ),
  ],
);
