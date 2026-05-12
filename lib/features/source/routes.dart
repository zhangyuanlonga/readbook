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
        return FeatureDisabledPages.sourceRuntime();
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
        return FeatureDisabledPages.sourceLogin();
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
        return FeatureDisabledPages.sourceWebLogin();
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
          child: FeatureDisabledPages.sourceEditor(),
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
          child: FeatureDisabledPages.sourceImport(),
        );
      }
      return buildFadeSlideTransitionPage(
        state: state,
        child: const ScriptSourcePasteImportPage(),
      );
    },
  ),
];
