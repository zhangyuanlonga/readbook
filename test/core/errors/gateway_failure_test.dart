import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/core/errors/error_stage.dart';
import 'package:shuxiang_reading_next/core/errors/gateway_failure.dart';

void main() {
  group('GatewayFailure', () {
    test('parses standard failure and maps retryable timeout', () {
      final failure = GatewayFailure.fromJson(const <String, Object?>{
        'stage': 'content',
        'category': 'timeout',
        'code': 'UPSTREAM_TIMEOUT',
        'message': 'content parse timeout',
        'retryable': true,
        'hint': '可稍后重试',
      });

      expect(failure.stage, 'content');
      expect(failure.code, 'UPSTREAM_TIMEOUT');
      expect(failure.retryable, isTrue);
      expect(failure.toErrorCode(), ErrorCode.network);
      expect(failure.toErrorStage(), ErrorStage.content);
      expect(failure.displayHint, '可稍后重试');
    });

    test('maps parse and login failures to local categories', () {
      final parseFailure = GatewayFailure.fromJson(const <String, Object?>{
        'stage': 'detail',
        'category': 'parse',
        'code': 'PARSE_FAILED',
        'message': 'parse failed',
        'retryable': false,
      });
      final loginFailure = GatewayFailure.fromJson(const <String, Object?>{
        'stage': 'search',
        'category': 'loginRequired',
        'code': 'LOGIN_REQUIRED',
        'message': 'login required',
        'retryable': false,
      });

      expect(parseFailure.toErrorCode(), ErrorCode.ruleParse);
      expect(parseFailure.toErrorStage(), ErrorStage.detail);
      expect(loginFailure.toErrorCode(), ErrorCode.validation);
      expect(loginFailure.toErrorStage(), ErrorStage.search);
      expect(loginFailure.actionHint, contains('登录'));
    });

    test('marks webview and anti spider hints clearly', () {
      final webviewFailure = GatewayFailure.fromJson(const <String, Object?>{
        'stage': 'search',
        'category': 'webviewRequired',
        'code': 'BAD_REQUEST',
        'message': 'unsupported:java.webView:requiresWebView',
        'retryable': false,
      });
      final antiSpiderFailure = GatewayFailure.fromJson(const <String, Object?>{
        'stage': 'search',
        'category': 'antiSpider',
        'code': 'UPSTREAM_ERROR',
        'message': 'captcha required',
        'retryable': false,
      });

      expect(webviewFailure.isWebViewRequired, isTrue);
      expect(webviewFailure.actionHint, contains('WebView'));
      expect(antiSpiderFailure.isAntiSpider, isTrue);
      expect(antiSpiderFailure.actionHint, contains('反爬'));
    });

    test('explains missing source access changes', () {
      final failure = GatewayFailure.fromJson(const <String, Object?>{
        'stage': 'detail',
        'category': 'notFound',
        'code': 'SOURCE_NOT_FOUND',
        'message': 'bookRef.sourceId not found',
        'retryable': false,
      });

      expect(failure.toErrorCode(), ErrorCode.unknownSource);
      expect(failure.isMissingSource, isTrue);
      expect(failure.actionHint, contains('取消授权'));
      expect(failure.actionHint, contains('分组'));
    });
  });
}
