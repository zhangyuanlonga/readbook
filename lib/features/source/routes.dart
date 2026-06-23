import 'package:go_router/go_router.dart';

import 'presentation/source_login_entry_page.dart';
import 'presentation/source_webview_login_page.dart';
import 'presentation/source_webview_task_page.dart';

final List<RouteBase> sourceRoutes = <RouteBase>[
  GoRoute(
    path: '/source/login',
    name: 'source-login',
    builder: (context, state) {
      final query = state.uri.queryParameters;
      return SourceLoginEntryPage(
        sourceId: query['sourceId'] ?? '',
        sourceName: query['sourceName'],
      );
    },
  ),
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
  GoRoute(
    path: '/source/webview-task',
    name: 'source-webview-task',
    builder: (context, state) {
      final query = state.uri.queryParameters;
      return SourceWebViewTaskPage(
        sourceId: query['sourceId'] ?? '',
        stage: query['stage'] ?? 'content',
        mode: query['mode'],
        url: query['url'],
        keyword: query['keyword'],
        page: int.tryParse(query['page'] ?? ''),
        sourceRegex: query['sourceRegex'],
        overrideUrlRegex: query['overrideUrlRegex'],
        javaScript: query['javaScript'],
        sourceName: query['sourceName'],
        bookId: query['bookId'],
        detailUrl: query['detailUrl'],
        tocUrl: query['tocUrl'],
        chapterUrl: query['chapterUrl'],
        chapterIndex: int.tryParse(query['chapterIndex'] ?? ''),
        chapterTitle: query['chapterTitle'],
        executionContext: query['executionContext'],
      );
    },
  ),
];

String sourceLoginLocation({required String sourceId, String? sourceName}) {
  return Uri(
    path: '/source/login',
    queryParameters: <String, String>{
      'sourceId': sourceId,
      if ((sourceName ?? '').trim().isNotEmpty)
        'sourceName': sourceName!.trim(),
    },
  ).toString();
}

String sourceWebViewLoginLocation({
  required String sourceId,
  String? loginUrl,
  String? sourceName,
}) {
  return Uri(
    path: '/source/webview-login',
    queryParameters: <String, String>{
      'sourceId': sourceId,
      if ((loginUrl ?? '').trim().isNotEmpty) 'loginUrl': loginUrl!.trim(),
      if ((sourceName ?? '').trim().isNotEmpty)
        'sourceName': sourceName!.trim(),
    },
  ).toString();
}

String sourceWebViewTaskLocation({
  required String sourceId,
  required String stage,
  String? mode,
  String? url,
  String? keyword,
  int? page,
  String? sourceRegex,
  String? overrideUrlRegex,
  String? javaScript,
  String? sourceName,
  String? bookId,
  String? detailUrl,
  String? tocUrl,
  String? chapterUrl,
  int? chapterIndex,
  String? chapterTitle,
  String? executionContext,
}) {
  final query = <String, String>{'sourceId': sourceId, 'stage': stage};
  void putIfNotBlank(String key, String? value) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      query[key] = normalized;
    }
  }

  putIfNotBlank('mode', mode);
  putIfNotBlank('url', url);
  putIfNotBlank('keyword', keyword);
  if (page != null) query['page'] = page.toString();
  putIfNotBlank('sourceRegex', sourceRegex);
  putIfNotBlank('overrideUrlRegex', overrideUrlRegex);
  putIfNotBlank('javaScript', javaScript);
  putIfNotBlank('sourceName', sourceName);
  putIfNotBlank('bookId', bookId);
  putIfNotBlank('detailUrl', detailUrl);
  putIfNotBlank('tocUrl', tocUrl);
  putIfNotBlank('chapterUrl', chapterUrl);
  if (chapterIndex != null) query['chapterIndex'] = chapterIndex.toString();
  putIfNotBlank('chapterTitle', chapterTitle);
  putIfNotBlank('executionContext', executionContext);

  return Uri(path: '/source/webview-task', queryParameters: query).toString();
}
