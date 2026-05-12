import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/composition/app_providers.dart' as app_providers;
import '../../app/router_transitions.dart';
import '../../app/widgets/feature_disabled_page.dart';
import 'presentation/script_source_editor_page.dart';
import 'presentation/script_source_paste_import_page.dart';
import 'presentation/source_login_page.dart';
import 'presentation/source_page.dart';
import 'presentation/source_web_login_page.dart';

final List<RouteBase> sourceRoutes = <RouteBase>[
  GoRoute(
    path: '/source',
    name: 'source',
    builder: (context, state) {
      final supportsSourceRuntime =
          ProviderScope.containerOf(
            context,
            listen: false,
          ).read(app_providers.appCapabilitiesProvider).supportsSourceRuntime;
      if (!supportsSourceRuntime) {
        return const FeatureDisabledPage(
          title: '书源功能暂未启用',
          message: '当前全平台首版先交付本地阅读、书架、阅读记录和外观设置。在线书源、脚本编辑、登录和调试会在后续版本作为独立专题回归。',
        );
      }
      return const SourcePage();
    },
  ),
  GoRoute(
    path: '/source/login',
    name: 'script-source-login',
    builder: (context, state) {
      final supportsSourceRuntime =
          ProviderScope.containerOf(
            context,
            listen: false,
          ).read(app_providers.appCapabilitiesProvider).supportsSourceRuntime;
      if (!supportsSourceRuntime) {
        return const FeatureDisabledPage(
          title: '书源登录暂未启用',
          message: '在线书源登录依赖脚本源运行时和 WebView 验证，已移出全平台首版范围。',
        );
      }
      final sourceId = state.uri.queryParameters['id'] ?? '';
      return SourceLoginPage(sourceId: sourceId);
    },
  ),
  GoRoute(
    path: '/source/web-login',
    name: 'script-source-web-login',
    builder: (context, state) {
      final supportsSourceRuntime =
          ProviderScope.containerOf(
            context,
            listen: false,
          ).read(app_providers.appCapabilitiesProvider).supportsSourceRuntime;
      if (!supportsSourceRuntime) {
        return const FeatureDisabledPage(
          title: '网页登录暂未启用',
          message: '交互式网页登录会随书源运行时一起在后续版本恢复。',
        );
      }
      final sourceId = state.uri.queryParameters['id'] ?? '';
      return SourceWebLoginPage(sourceId: sourceId);
    },
  ),
  GoRoute(
    path: '/source/script-editor',
    name: 'script-source-editor',
    pageBuilder: (context, state) {
      final supportsSourceRuntime =
          ProviderScope.containerOf(
            context,
            listen: false,
          ).read(app_providers.appCapabilitiesProvider).supportsSourceRuntime;
      if (!supportsSourceRuntime) {
        return buildFadeSlideTransitionPage(
          state: state,
          child: const FeatureDisabledPage(
            title: '脚本源编辑暂未启用',
            message: '脚本源编辑器已从全平台首版中延期，首版优先保证本地阅读闭环稳定。',
          ),
        );
      }
      return buildFadeSlideTransitionPage(
        state: state,
        child: ScriptSourceEditorPage(
          scriptSourceId: state.uri.queryParameters['id'],
        ),
      );
    },
  ),
  GoRoute(
    path: '/source/paste-import',
    name: 'script-source-paste-import',
    pageBuilder: (context, state) {
      final supportsSourceRuntime =
          ProviderScope.containerOf(
            context,
            listen: false,
          ).read(app_providers.appCapabilitiesProvider).supportsSourceRuntime;
      if (!supportsSourceRuntime) {
        return buildFadeSlideTransitionPage(
          state: state,
          child: const FeatureDisabledPage(
            title: '书源导入暂未启用',
            message: '首版全平台暂不导入在线书源，后续会以独立能力开关恢复。',
          ),
        );
      }
      return buildFadeSlideTransitionPage(
        state: state,
        child: const ScriptSourcePasteImportPage(),
      );
    },
  ),
];
