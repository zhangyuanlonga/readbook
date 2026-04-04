import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_appread/runtime/session/source_session.dart';

void main() {
  test('filters cookies by domain and path for a request URL', () {
    final session = SourceSession(sourceId: 'source_69');
    session.setCookie('manual', '1');
    session.setCookie(
      'hostOnly',
      '2',
      uri: Uri.parse('https://www.example.com/books/index.html'),
    );
    session.setCookie('shared', '3', domain: '.example.com');
    session.setCookie(
      'pathOnly',
      '4',
      uri: Uri.parse('https://www.example.com/books/index.html'),
      path: '/books',
    );

    expect(
      session.cookiesForUri(Uri.parse('https://www.example.com/books/1')),
      containsPair('manual', '1'),
    );
    expect(
      session.cookiesForUri(Uri.parse('https://www.example.com/books/1')),
      containsPair('hostOnly', '2'),
    );
    expect(
      session.cookiesForUri(Uri.parse('https://www.example.com/books/1')),
      containsPair('shared', '3'),
    );
    expect(
      session.cookiesForUri(Uri.parse('https://www.example.com/books/1')),
      containsPair('pathOnly', '4'),
    );

    expect(
      session.cookiesForUri(Uri.parse('https://www.example.com/search')),
      isNot(contains('pathOnly')),
    );
    expect(
      session.cookiesForUri(Uri.parse('https://api.example.com/books/1')),
      containsPair('shared', '3'),
    );
    expect(
      session.cookiesForUri(Uri.parse('https://api.example.com/books/1')),
      isNot(contains('hostOnly')),
    );
  });

  test('clears only cookies for the matching domain', () {
    final session = SourceSession(sourceId: 'source_69');
    session.setCookie(
      'hostOnly',
      '2',
      uri: Uri.parse('https://www.example.com/books/index.html'),
    );
    session.setCookie('shared', '3', domain: '.example.com');
    session.setCookie('manual', '1');

    session.clearCookiesForDomain('www.example.com');

    expect(session.cookies['hostOnly'], isNull);
    expect(session.cookies['shared'], '3');
    expect(session.cookies['manual'], '1');
  });
}
