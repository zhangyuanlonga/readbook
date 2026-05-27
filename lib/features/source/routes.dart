import 'package:go_router/go_router.dart';

import 'presentation/source_webview_login_page.dart';

final List<RouteBase> sourceRoutes = <RouteBase>[
  GoRoute(
    path: '/source/webview-login',
    name: 'source-webview-login',
    builder: (context, state) {
      final query = state.uri.queryParameters;
      return SourceWebViewLoginPage(
        sourceId: query['sourceId'] ?? '',
        loginUrl: query['loginUrl'] ?? '',
        sourceName: query['sourceName'],
      );
    },
  ),
];

String sourceWebViewLoginLocation({
  required String sourceId,
  required String loginUrl,
  String? sourceName,
}) {
  return Uri(
    path: '/source/webview-login',
    queryParameters: <String, String>{
      'sourceId': sourceId,
      'loginUrl': loginUrl,
      if ((sourceName ?? '').trim().isNotEmpty)
        'sourceName': sourceName!.trim(),
    },
  ).toString();
}
