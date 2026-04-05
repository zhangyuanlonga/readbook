import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:shuxiang_reading_next/runtime/http/http_models.dart';
import 'package:shuxiang_reading_next/runtime/http/request_engine.dart';
import 'package:shuxiang_reading_next/runtime/session/source_session.dart';

void main() {
  test('captures multiple cookies from a collapsed set-cookie header', () async {
    var requestCount = 0;
    String? exampleBooksCookieHeader;
    String? subdomainBooksCookieHeader;
    String? exampleSearchCookieHeader;
    final client = MockClient((http.Request request) async {
      requestCount += 1;
      if (requestCount == 1) {
        return http.Response(
          'ok',
          200,
          headers: <String, String>{
            'set-cookie':
                'cf_clearance=token123; Expires=Wed, 21 Oct 2037 07:28:00 GMT; Domain=.example.com; Path=/, sid=abc456; Path=/books',
          },
        );
      }
      switch (request.url.toString()) {
        case 'https://example.com/books/list':
          exampleBooksCookieHeader = request.headers['cookie'];
          break;
        case 'https://sub.example.com/books/item':
          subdomainBooksCookieHeader = request.headers['cookie'];
          break;
        case 'https://example.com/search':
          exampleSearchCookieHeader = request.headers['cookie'];
          break;
        default:
          break;
      }
      return http.Response('ok', 200);
    });
    final engine = HttpPackageRequestEngine(client: client);
    final session = SourceSession(sourceId: 'test_source');
    final request = RuntimeHttpRequest(
      uri: Uri.parse('https://example.com/books'),
    );

    await engine.request(request, session: session);
    await engine.request(
      RuntimeHttpRequest(uri: Uri.parse('https://example.com/books/list')),
      session: session,
    );
    await engine.request(
      RuntimeHttpRequest(uri: Uri.parse('https://sub.example.com/books/item')),
      session: session,
    );
    await engine.request(
      RuntimeHttpRequest(uri: Uri.parse('https://example.com/search')),
      session: session,
    );

    expect(session.cookies['cf_clearance'], 'token123');
    expect(session.cookies['sid'], 'abc456');
    expect(exampleBooksCookieHeader, contains('cf_clearance=token123'));
    expect(exampleBooksCookieHeader, contains('sid=abc456'));
    expect(subdomainBooksCookieHeader, contains('cf_clearance=token123'));
    expect(subdomainBooksCookieHeader, isNot(contains('sid=abc456')));
    expect(exampleSearchCookieHeader, contains('cf_clearance=token123'));
    expect(exampleSearchCookieHeader, isNot(contains('sid=abc456')));
  });

  test('removes cookies when set-cookie expires them immediately', () async {
    var requestCount = 0;
    String? secondRequestCookieHeader;
    String? thirdRequestCookieHeader;
    final client = MockClient((http.Request request) async {
      requestCount += 1;
      if (requestCount == 1) {
        return http.Response(
          'ok',
          200,
          headers: <String, String>{'set-cookie': 'sid=abc456; Path=/books'},
        );
      }
      if (requestCount == 2) {
        secondRequestCookieHeader = request.headers['cookie'];
        return http.Response(
          'ok',
          200,
          headers: <String, String>{
            'set-cookie': 'sid=deleted; Max-Age=0; Path=/books',
          },
        );
      }
      thirdRequestCookieHeader = request.headers['cookie'];
      return http.Response('ok', 200);
    });

    final engine = HttpPackageRequestEngine(client: client);
    final session = SourceSession(sourceId: 'test_source');
    final request = RuntimeHttpRequest(
      uri: Uri.parse('https://example.com/books/list'),
    );

    await engine.request(request, session: session);
    await engine.request(request, session: session);
    await engine.request(request, session: session);

    expect(secondRequestCookieHeader, contains('sid=abc456'));
    expect(thirdRequestCookieHeader, isNot(contains('sid=abc456')));
    expect(session.cookies['sid'], isNull);
  });

  test('does not send request when session is cancelled', () async {
    var requestCalled = false;
    final client = MockClient((http.Request request) async {
      requestCalled = true;
      return http.Response('ok', 200);
    });
    final engine = HttpPackageRequestEngine(client: client);
    final session = SourceSession(sourceId: 'test_source');
    session.set(
      sessionCancellationHandleKey,
      SessionCancellationHandle(isCancelled: () => true),
    );

    await expectLater(
      engine.request(
        RuntimeHttpRequest(uri: Uri.parse('https://example.com/search')),
        session: session,
      ),
      throwsA(isA<SessionTaskCancelledException>()),
    );
    expect(requestCalled, isFalse);
  });
}
