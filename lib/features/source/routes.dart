import 'package:go_router/go_router.dart';

import '../../app/router_transitions.dart';
import 'presentation/script_source_editor_page.dart';
import 'presentation/script_source_paste_import_page.dart';
import 'presentation/source_login_page.dart';
import 'presentation/source_page.dart';
import 'presentation/source_web_login_page.dart';

final List<RouteBase> sourceRoutes = <RouteBase>[
  GoRoute(
    path: '/source',
    name: 'source',
    builder: (context, state) => const SourcePage(),
  ),
  GoRoute(
    path: '/source/login',
    name: 'script-source-login',
    builder: (context, state) {
      final sourceId = state.uri.queryParameters['id'] ?? '';
      return SourceLoginPage(sourceId: sourceId);
    },
  ),
  GoRoute(
    path: '/source/web-login',
    name: 'script-source-web-login',
    builder: (context, state) {
      final sourceId = state.uri.queryParameters['id'] ?? '';
      return SourceWebLoginPage(sourceId: sourceId);
    },
  ),
  GoRoute(
    path: '/source/script-editor',
    name: 'script-source-editor',
    pageBuilder: (context, state) {
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
      return buildFadeSlideTransitionPage(
        state: state,
        child: const ScriptSourcePasteImportPage(),
      );
    },
  ),
];
