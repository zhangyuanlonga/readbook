import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/composition/app_providers.dart' as app_providers;
import '../../app/router_transitions.dart';
import '../../app/widgets/feature_disabled_page.dart';
import 'presentation/search_page.dart';

final List<RouteBase> searchRoutes = <RouteBase>[
  GoRoute(
    path: '/search',
    name: 'search',
    pageBuilder: (context, state) {
      final supportsSourceRuntime =
          ProviderScope.containerOf(
            context,
            listen: false,
          ).read(app_providers.appCapabilitiesProvider).supportsSourceRuntime;
      return buildFadeTransitionPage(
        state: state,
        child:
            supportsSourceRuntime
                ? const SearchPage()
                : const FeatureDisabledPage(
                  title: '在线搜索暂未启用',
                  message: '全平台首版先聚焦本地书库和本地阅读。在线搜索依赖书源运行时，后续会随书源专题恢复。',
                  icon: Icons.search_off_rounded,
                ),
      );
    },
  ),
];
