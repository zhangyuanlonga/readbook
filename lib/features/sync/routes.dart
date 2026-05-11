import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/platform/app_platform_capabilities.dart';
import '../../app/widgets/feature_disabled_page.dart';
import 'presentation/pages/sync_history_page.dart';
import 'presentation/pages/sync_settings_page.dart';

final List<RouteBase> syncRoutes = <RouteBase>[
  GoRoute(
    path: '/sync',
    name: 'sync',
    builder:
        (context, state) => Consumer(
          builder: (context, ref, _) {
            final capabilities = ref.watch(appPlatformCapabilitiesProvider);
            if (!capabilities.supportsWebDavSync) {
              return const FeatureDisabledPage(
                title: '同步功能暂未启用',
                message:
                    '首版全平台先保证本地阅读和常用业务闭环。WebDAV 同步已放入 P1+，默认不参与首版验收；可继续使用本地书架、书签、阅读记录和外观设置。',
                icon: Icons.sync_disabled_rounded,
              );
            }
            return const SyncSettingsPage();
          },
        ),
  ),
  GoRoute(
    path: '/sync/history',
    name: 'sync-history',
    builder:
        (context, state) => Consumer(
          builder: (context, ref, _) {
            final capabilities = ref.watch(appPlatformCapabilitiesProvider);
            if (!capabilities.supportsWebDavSync) {
              return const FeatureDisabledPage(
                title: '同步历史暂不可用',
                message: '当前平台未开放 WebDAV 同步能力，因此不会产生同步历史。首版可继续使用本地阅读记录和书签。',
                icon: Icons.history_toggle_off_rounded,
              );
            }
            return const SyncHistoryPage();
          },
        ),
  ),
];
