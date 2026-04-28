import '../../../core/webview/interactive_verification_browser_executor.dart';
import '../../../core/webview/webview_executor.dart';

class SourceLoginBrowserResponse {
  const SourceLoginBrowserResponse({
    required this.statusCode,
    this.body,
    this.finalUrl,
    this.matchedResourceUrl,
    this.matchedOverrideUrl,
    this.scriptResult,
  });

  final int statusCode;
  final String? body;
  final String? finalUrl;
  final String? matchedResourceUrl;
  final String? matchedOverrideUrl;
  final Object? scriptResult;

  Map<String, Object?> toUiPayload() {
    return <String, Object?>{
      'statusCode': statusCode,
      'body': body,
      'finalUrl': finalUrl,
      'matchedResourceUrl': matchedResourceUrl,
      'matchedOverrideUrl': matchedOverrideUrl,
      'scriptResult': scriptResult,
    };
  }
}

class SourceLoginBrowserService {
  SourceLoginBrowserService({
    InteractiveVerificationBrowserExecutor? browserExecutor,
  }) : _browserExecutor =
           browserExecutor ?? InteractiveVerificationBrowserExecutor.instance;

  final InteractiveVerificationBrowserExecutor _browserExecutor;

  Future<SourceLoginBrowserResponse> openBrowserAwait({
    required String sourceId,
    required String url,
    String? title,
    bool refetchAfterSuccess = true,
    String? html,
  }) async {
    final normalizedUrl = url.trim();
    final htmlData = _resolveHtmlData(normalizedUrl, html: html);
    final response = await _browserExecutor.open(
      request: WebViewRequestPayload(
        url: htmlData == null ? normalizedUrl : 'about:blank',
        sourceId: sourceId,
        html: htmlData,
      ),
      awaitUserResult: true,
      title: title,
      refetchAfterSuccess: refetchAfterSuccess,
    );
    return SourceLoginBrowserResponse(
      statusCode: response.statusCode,
      body: response.body,
      finalUrl: response.finalUrl,
      matchedResourceUrl: response.matchedResourceUrl,
      matchedOverrideUrl: response.matchedOverrideUrl,
      scriptResult: response.scriptResult,
    );
  }

  Future<void> openUrl({
    required String sourceId,
    required String url,
    String? title,
  }) async {
    final normalizedUrl = url.trim();
    final htmlData = _resolveHtmlData(normalizedUrl);
    await _browserExecutor.open(
      request: WebViewRequestPayload(
        url: htmlData == null ? normalizedUrl : 'about:blank',
        sourceId: sourceId,
        html: htmlData,
      ),
      awaitUserResult: false,
      title: title,
      refetchAfterSuccess: false,
    );
  }

  String? _resolveHtmlData(String url, {String? html}) {
    final normalizedHtml = html?.trim();
    if (normalizedHtml != null && normalizedHtml.isNotEmpty) {
      return normalizedHtml;
    }
    final parsed = Uri.tryParse(url);
    if (parsed == null || !parsed.isScheme('data')) {
      return null;
    }
    if (parsed.data == null || !parsed.data!.mimeType.contains('html')) {
      return null;
    }
    return parsed.data!.contentAsString();
  }
}
