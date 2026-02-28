import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_appread/core/rule_engine/executors/js_executor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';

void main() {
  group('JsExecutor Tier-1 bridge', () {
    final executor = JsExecutor();

    test('supports base64 and md5 helpers', () async {
      final value = await executor.execute(
        script: '''
          var decoded = java.base64Decode("aGVsbG8=");
          var hashed = java.md5Encode("test");
          decoded + "|" + hashed;
        ''',
        context: const JsExecutionContext(),
      );

      expect(value, 'hello|098f6bcd4621d373cade4e832627b4f6');
    });

    test('supports put/get helper', () async {
      final value = await executor.execute(
        script: '''
          java.put("token", "abc123");
          java.get("token");
        ''',
        context: const JsExecutionContext(),
      );

      expect(value, 'abc123');
    });

    test('reports put updates through js execution context callback', () async {
      final updates = <String, String>{};
      final value = await executor.execute(
        script: '''
          java.put("token", "abc123");
          java.put("channel", "mobile");
          java.get("token");
        ''',
        context: JsExecutionContext(onBridgePutVariables: updates.addAll),
      );

      expect(value, 'abc123');
      expect(updates, <String, String>{'token': 'abc123', 'channel': 'mobile'});
    });

    test('supports encodeURI/htmlFormat/timeFormat helpers', () async {
      final value = await executor.execute(
        script: '''
          var encoded = java.encodeURI("中文");
          var plain = java.htmlFormat("<p>a&nbsp;b</p>");
          var formatted = java.timeFormat("2026-02-27T12:34:56Z");
          encoded + "|" + plain + "|" + formatted;
        ''',
        context: const JsExecutionContext(),
      );

      expect(value, isNotNull);
      final parts = value!.split('|');
      expect(parts, hasLength(3));
      expect(parts[0], '%E4%B8%AD%E6%96%87');
      expect(parts[1], 'a b');
      expect(
        RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$').hasMatch(parts[2]),
        isTrue,
      );
    });

    test('supports base64DecodeToByteArray helper', () async {
      final value = await executor.execute(
        script: '''
          var bytes = java.base64DecodeToByteArray("aGk=");
          Array.isArray(bytes) ? bytes.join(",") : "";
        ''',
        context: const JsExecutionContext(),
      );

      expect(value, '104,105');
    });

    test('supports cookie/cache context helpers', () async {
      final value = await executor.execute(
        script: '''
          cookie.setKey("fanqie", "sessionid", "abc");
          cache.putMemory("k", "v");
          var c1 = cookie.getKey("fanqie", "sessionid");
          var m1 = cache.getFromMemory("k");
          cache.deleteMemory("k");
          var m2 = cache.getFromMemory("k");
          c1 + "|" + m1 + "|" + m2;
        ''',
        context: const JsExecutionContext(),
      );

      expect(value, 'abc|v|');
    });

    test('injects cookie/cache seed values from execution context', () async {
      final value = await executor.execute(
        script: '''
          var c = cookie.getKey("seedHost", "token");
          var m = cache.getFromMemory("seed");
          c + "|" + m;
        ''',
        context: const JsExecutionContext(
          cookieJson: <String, dynamic>{
            'seedHost': <String, dynamic>{'token': 'seed-token'},
          },
          cacheJson: <String, dynamic>{'seed': 'seed-value'},
        ),
      );

      expect(value, 'seed-token|seed-value');
    });

    test('injects jsLib before user script execution', () async {
      final value = await executor.execute(
        script: 'decrypt(result);',
        context: const JsExecutionContext(
          result: 'cipher',
          jsLibScript: 'function decrypt(v){ return "plain:" + v; }',
        ),
      );

      expect(value, 'plain:cipher');
    });

    test('supports aesBase64DecodeToString helper', () async {
      const key = '0123456789abcdef';
      const iv = '1234567890abcdef';
      const plainText = 'hello-aes';
      final encrypted = _encryptAesCbcPkcs7Base64(
        plainText: plainText,
        key: key,
        iv: iv,
      );

      final value = await executor.execute(
        script:
            'java.aesBase64DecodeToString("$encrypted", "$key", "AES/CBC/PKCS5Padding", "$iv");',
        context: const JsExecutionContext(),
      );

      expect(value, plainText);
    });

    test('supports aesEncodeToBase64String helper', () async {
      const key = '0123456789abcdef';
      const iv = '1234567890abcdef';
      const plainText = 'encode-me';
      final expected = _encryptAesCbcPkcs7Base64(
        plainText: plainText,
        key: key,
        iv: iv,
      );

      final value = await executor.execute(
        script:
            'java.aesEncodeToBase64String("$plainText", "$key", "AES/CBC/PKCS5Padding", "$iv");',
        context: const JsExecutionContext(),
      );

      expect(value, expected);
    });

    test('supports AES transformation variants and hex key/iv', () async {
      const key = '0123456789abcdef';
      const iv = '1234567890abcdef';
      const plainText = 'variant-plain';
      final hexKey = _toHex(utf8.encode(key));
      final hexIv = _toHex(utf8.encode(iv));

      final cbcEncrypted = _encryptAesCbcPkcs7Base64(
        plainText: plainText,
        key: key,
        iv: iv,
      );
      final cbcOutput = await executor.execute(
        script:
            'java.aesBase64DecodeToString("$cbcEncrypted", "$hexKey", "aes/cbc/pkcs7padding", "$hexIv");',
        context: const JsExecutionContext(),
      );
      expect(cbcOutput, plainText);

      final ecbEncrypted = _encryptAesEcbPkcs7Base64(
        plainText: plainText,
        key: key,
      );
      final ecbOutput = await executor.execute(
        script:
            'java.aesBase64DecodeToString("$ecbEncrypted", "$key", "AES/ECB/PKCS5Padding", "");',
        context: const JsExecutionContext(),
      );
      expect(ecbOutput, plainText);
    });

    test('supports AES/CBC/ZeroPadding decode', () async {
      const key = '0123456789abcdef';
      const iv = '1234567890abcdef';
      const plainText = 'zero-padding';
      final encrypted = _encryptAesCbcZeroPaddingBase64(
        plainText: plainText,
        key: key,
        iv: iv,
      );

      final value = await executor.execute(
        script:
            'java.aesBase64DecodeToString("$encrypted", "$key", "AES/CBC/ZeroPadding", "$iv");',
        context: const JsExecutionContext(),
      );

      expect(value, plainText);
    });

    test(
      'supports java.setContent/getString/getStringList/getElements',
      () async {
        final value = await executor.execute(
          script: r'''
          java.setContent('{"tag":"玄幻","next":"/chapter/2"}', 'https://example.com/book/1');
          var one = java.getString('$.tag');
          java.setContent('<ul><li>A</li><li>B</li></ul>', 'https://example.com/book/1');
          var list = java.getStringList('li@text');
          var elements = java.getElements('li@outerHtml');
          java.setContent('{"next":"/chapter/2"}', 'https://example.com/book/1');
          var nextUrl = java.getString('$.next', true);
          one + "|" + list.join(",") + "|" + elements.length + "|" + nextUrl;
        ''',
          context: const JsExecutionContext(),
        );

        expect(value, '玄幻|A,B|2|https://example.com/chapter/2');
      },
    );

    test('supports nested java.getString rule callback', () async {
      final nestedRule = _buildNestedGetStringRule(
        depth: 2,
        terminalRule: r'$.value',
      );
      final value = await executor.execute(
        script: '''
          java.setContent('{"value":"nested-ok"}', 'https://example.com/book/1');
          java.getString(${jsonEncode(nestedRule)});
        ''',
        context: const JsExecutionContext(),
      );

      expect(value, 'nested-ok');
    });

    test('guards nested rule callback recursion depth', () async {
      final deepRule = _buildNestedGetStringRule(
        depth: 6,
        terminalRule: r'$.value',
      );
      final value = await executor.execute(
        script: '''
          java.setContent('{"value":"too-deep"}', 'https://example.com/book/1');
          java.getString(${jsonEncode(deepRule)});
        ''',
        context: const JsExecutionContext(),
      );

      expect(value, isNull);
    });

    test(
      'supports legacy compat helpers getElement/getCookie/timeFormatUTC/toNumChapter',
      () async {
        final value = await executor.execute(
          script: '''
            java.setContent("<ul><li>第十二章</li><li>第二十章</li></ul>");
            cookie.setKey("host", "token", "abc");
            var first = java.getElement("li@text");
            var num = java.toNumChapter(first);
            var utc = java.timeFormatUTC("2026-02-27T12:34:56+08:00");
            var noops = [
              java.toast("a"),
              java.longToast("b"),
              java.startBrowser("https://example.com"),
              java.startBrowserAwait("https://example.com"),
              java.webView("https://example.com")
            ].join(",");
            [
              first,
              String(num),
              java.getCookie("host", "token"),
              utc,
              java.t2s("繁體"),
              java.s2t("简体"),
              java.strToBytes("ab").join(","),
              java.bytesToString([97,98]),
              noops
            ].join("|");
          ''',
          context: const JsExecutionContext(),
        );

        expect(value, isNotNull);
        final parts = value!.split('|');
        expect(parts, hasLength(9));
        expect(parts[0], '第十二章');
        expect(parts[1], '12');
        expect(parts[2], 'abc');
        expect(parts[3], '2026-02-27 04:34:56');
        expect(parts[4], '繁體');
        expect(parts[5], '简体');
        expect(parts[6], '97,98');
        expect(parts[7], 'ab');
        expect(parts[8], ',,,,');
      },
    );

    test('supports java.connect response object alias', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.uri.path == '/connect') {
          request.response
            ..statusCode = 200
            ..write('connect-ok');
        } else {
          request.response
            ..statusCode = 404
            ..write('missing');
        }
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final base = 'http://${server.address.host}:${server.port}';
      final value = await executor.execute(
        script: '''
          java.connect("$base/connect").get().body();
        ''',
        context: const JsExecutionContext(),
      );

      expect(value, 'connect-ok');
    });

    test(
      'supports legacy hex/hash/device helpers and refreshTocUrl alias',
      () async {
        final value = await executor.execute(
          script: '''
            var hex = java.hexEncodeToString("abc");
            var decoded = java.hexDecodeToString(hex);
            var bytes = java.hexDecodeToByteArray(hex).join(",");
            var sha1 = java.digestHex("abc", "SHA-1");
            var hmac = java.HMacHex("abc", "HmacSHA256", "k");
            var uuid = java.randomUUID();
            java.put("nextTocUrl", "/toc/2");
            var refreshed = java.refreshTocUrl();
            var ua = java.getWebViewUA();
            var aid = java.androidId();
            [
              hex,
              decoded,
              bytes,
              sha1,
              hmac,
              /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\$/.test(uuid),
              refreshed,
              ua.indexOf("Mozilla/5.0") === 0,
              aid.length > 0
            ].join("|");
          ''',
          context: const JsExecutionContext(),
        );

        expect(value, isNotNull);
        final parts = value!.split('|');
        expect(parts, hasLength(9));
        expect(parts[0], '616263');
        expect(parts[1], 'abc');
        expect(parts[2], '97,98,99');
        expect(parts[3], 'a9993e364706816aba3e25717850c26c9cd0d89d');
        expect(
          parts[4],
          '342e519ce0ad6c03a36b98eeb3f1d130db4813b9df4d1160eda488d712dc78ee',
        );
        expect(parts[5], 'true');
        expect(parts[6], '/toc/2');
        expect(parts[7], 'true');
        expect(parts[8], 'true');
      },
    );

    test(
      'supports extended legacy bridge helpers for url/response/hmac/aes args',
      () async {
        const key = '0123456789abcdef';
        const iv = '1234567890abcdef';
        const plainText = 'args-aes-plain';
        final encrypted = _encryptAesCbcPkcs7Base64(
          plainText: plainText,
          key: key,
          iv: iv,
        );

        final value = await executor.execute(
          script: '''
            java.initUrl("https://example.com/book/index.html");
            var host = java.toURL("/detail/1", java.ruleUrl).host;
            var abs = java.toUrl("chapter/2", java.ruleUrl);
            var hmacB64 = java.HMacBase64("abc", "HmacSHA256", "k");
            var keyB64 = java.base64Encode("$key");
            var ivB64 = java.base64Encode("$iv");
            var plain = java.aesDecodeArgsBase64Str(
              "$encrypted",
              keyB64,
              "CBC",
              "PKCS7Padding",
              ivB64
            );
            var resp = java.getStrResponse("https://example.com/api", "payload", 201);
            [
              java.deviceID().length > 0,
              host,
              abs,
              hmacB64,
              plain,
              resp.url(),
              resp.body(),
              String(resp.code()),
              java.removeCookie("host"),
              java.reGetBook()
            ].join("|");
          ''',
          context: const JsExecutionContext(),
        );

        expect(value, isNotNull);
        final parts = value!.split('|');
        expect(parts, hasLength(10));
        expect(parts[0], 'true');
        expect(parts[1], 'example.com');
        expect(parts[2], 'https://example.com/book/chapter/2');
        expect(parts[3], 'NC5RnOCtbAOja5jus/HRMNtIE7nfTRFg7aSI1xLceO4=');
        expect(parts[4], plainText);
        expect(parts[5], 'https://example.com/api');
        expect(parts[6], 'payload');
        expect(parts[7], '201');
        expect(parts[8], '');
        expect(parts[9], '');
      },
    );

    test(
      'supports java.cacheFile/importScript fallback network helpers',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          if (request.uri.path == '/cached.txt') {
            request.response
              ..statusCode = 200
              ..write('cache-ok');
          } else if (request.uri.path == '/script.js') {
            request.response
              ..statusCode = 200
              ..write('script-ok');
          } else {
            request.response
              ..statusCode = 404
              ..write('missing');
          }
          await request.response.close();
        });
        addTearDown(() => server.close(force: true));

        final base = 'http://${server.address.host}:${server.port}';
        final value = await executor.execute(
          script: '''
          var cached = java.cacheFile("$base/cached.txt");
          var script = java.importScript("$base/script.js");
          cached + "|" + script;
        ''',
          context: const JsExecutionContext(),
        );

        expect(value, 'cache-ok|script-ok');
      },
    );

    test('supports desEncodeToBase64String helper', () async {
      const plainText = 'des-plain';
      const key = '12345678';
      final expected = _encryptDesEcbPkcs7Base64(
        plainText: plainText,
        key: key,
      );

      final value = await executor.execute(
        script:
            'java.desEncodeToBase64String("$plainText", "$key", "DES/ECB/PKCS5Padding", "");',
        context: const JsExecutionContext(),
      );

      expect(value, expected);
    });

    test(
      'supports createSymmetricCrypto decrypt flow with strToBytes and iv slice',
      () async {
        const key = r'123#2^0@0vm@08.b5%$1[A]1&4115s((';
        const iv = '1234567890abcdef';
        const plainText = 'crypto-plain';
        final encrypted = _encryptAesCbcPkcs7Bytes(
          plainText: plainText,
          key: key,
          iv: iv,
        );
        final payload =
            Uint8List(iv.length + encrypted.lengthInBytes)
              ..setAll(0, utf8.encode(iv))
              ..setAll(iv.length, encrypted);
        final bodyBase64 = base64.encode(payload);

        final value = await executor.execute(
          script: '''
            var data = java.base64DecodeToByteArray("$bodyBase64");
            var iv = data.slice(0, 16);
            var crypt = java.createSymmetricCrypto(
              "AES/CBC/PKCS7Padding",
              java.strToBytes("$key"),
              iv
            );
            crypt.decryptStr(data.slice(16, data.length));
          ''',
          context: const JsExecutionContext(),
        );

        expect(value, plainText);
      },
    );
  });

  group('JsExecutor Tier-2 network bridge', () {
    test(
      'supports java.ajax/java.get/java.post with static literal urls',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          if (request.uri.path == '/ajax') {
            request.response
              ..statusCode = 200
              ..write('ajax-ok');
          } else if (request.uri.path == '/get') {
            request.response
              ..statusCode = 200
              ..write(request.headers.value('x-token') ?? '');
          } else if (request.uri.path == '/post') {
            final body = await utf8.decoder.bind(request).join();
            request.response
              ..statusCode = 200
              ..write(body);
          } else {
            request.response
              ..statusCode = 404
              ..write('missing');
          }
          await request.response.close();
        });

        final base = 'http://${server.address.host}:${server.port}';
        final executor = JsExecutor();
        final output = await executor.execute(
          script: '''
          var a = java.ajax("$base/ajax");
          var g = java.get("$base/get", {"x-token":"token-value"});
          var p = java.post("$base/post", "k=v");
          a + "|" + g + "|" + p;
        ''',
          context: const JsExecutionContext(),
        );

        expect(output, 'ajax-ok|token-value|k=v');
        await server.close(force: true);
      },
    );

    test('ignores network calls beyond configured limit', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response
          ..statusCode = 200
          ..write(request.uri.pathSegments.last);
        await request.response.close();
      });

      final base = 'http://${server.address.host}:${server.port}';
      final executor = JsExecutor(networkRequestLimit: 2);
      final output = await executor.execute(
        script: '''
          var a = java.ajax("$base/1");
          var b = java.ajax("$base/2");
          var c = java.ajax("$base/3");
          [a,b,c].join("|");
        ''',
        context: const JsExecutionContext(),
      );

      expect(output, '1|2|');
      await server.close(force: true);
    });

    test('supports dynamic chained ajax calls via probe prefetch', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.uri.path == '/token') {
          request.response
            ..statusCode = 200
            ..write('tk-1');
        } else if (request.uri.path == '/data') {
          request.response
            ..statusCode = 200
            ..write(request.uri.queryParameters['tk'] ?? '');
        } else {
          request.response
            ..statusCode = 404
            ..write('missing');
        }
        await request.response.close();
      });

      final base = 'http://${server.address.host}:${server.port}';
      final executor = JsExecutor();
      final output = await executor.execute(
        script: '''
          var host = "$base";
          var token = java.ajax(host + "/token");
          java.ajax(host + "/data?tk=" + token);
        ''',
        context: const JsExecutionContext(),
      );

      expect(output, 'tk-1');
      await server.close(force: true);
    });

    test('supports java.ajaxAll response body helper', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response
          ..statusCode = 200
          ..write(request.uri.pathSegments.last);
        await request.response.close();
      });

      final base = 'http://${server.address.host}:${server.port}';
      final executor = JsExecutor();
      final output = await executor.execute(
        script: '''
          var list = java.ajaxAll(["$base/a", "$base/b"]);
          list.map(function(item) {
            return typeof item.body === "function" ? item.body() : String(item);
          }).join("|");
        ''',
        context: const JsExecutionContext(),
      );

      expect(output, 'a|b');
      await server.close(force: true);
    });

    test(
      'supports dynamic java.get network url from bridge variable',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          if (request.uri.path == '/payload') {
            request.response
              ..statusCode = 200
              ..write('payload-ok');
          } else {
            request.response
              ..statusCode = 404
              ..write('missing');
          }
          await request.response.close();
        });

        final base = 'http://${server.address.host}:${server.port}';
        final executor = JsExecutor();
        final output = await executor.execute(
          script: '''
          var api = result;
          java.get(api);
        ''',
          context: JsExecutionContext(result: '$base/payload'),
        );

        expect(output, 'payload-ok');
        await server.close(force: true);
      },
    );

    test(
      'supports dynamic post headers/body and multi-round dependencies',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          final path = request.uri.path;
          if (path == '/seed') {
            request.response
              ..statusCode = 200
              ..write('A');
          } else if (path == '/token') {
            final seed = request.uri.queryParameters['seed'] ?? '';
            request.response
              ..statusCode = 200
              ..write('tk-$seed');
          } else if (path == '/submit') {
            final body = await utf8.decoder.bind(request).join();
            request.response
              ..statusCode = 200
              ..write('${request.headers.value('x-token') ?? ''}|$body');
          } else {
            request.response
              ..statusCode = 404
              ..write('missing');
          }
          await request.response.close();
        });

        final base = 'http://${server.address.host}:${server.port}';
        final executor = JsExecutor(networkRequestLimit: 10);
        final output = await executor.execute(
          script: '''
          var host = "$base";
          var seed = java.ajax(host + "/seed");
          var token = java.ajax(host + "/token?seed=" + seed);
          var headers = {"x-token": token};
          var body = {"seed": seed, "token": token};
          java.post(host + "/submit", body, headers);
        ''',
          context: const JsExecutionContext(),
        );

        expect(output, 'tk-A|{"seed":"A","token":"tk-A"}');
        await server.close(force: true);
      },
    );
  });
}

String _encryptAesCbcPkcs7Base64({
  required String plainText,
  required String key,
  required String iv,
}) {
  final keyBytes = Uint8List.fromList(utf8.encode(key));
  final ivBytes = Uint8List.fromList(utf8.encode(iv));
  final cipher = PaddedBlockCipherImpl(
    PKCS7Padding(),
    CBCBlockCipher(AESEngine()),
  );
  cipher.init(
    true,
    PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
      ParametersWithIV<KeyParameter>(KeyParameter(keyBytes), ivBytes),
      null,
    ),
  );

  final encrypted = cipher.process(Uint8List.fromList(utf8.encode(plainText)));
  return base64.encode(encrypted);
}

Uint8List _encryptAesCbcPkcs7Bytes({
  required String plainText,
  required String key,
  required String iv,
}) {
  final keyBytes = Uint8List.fromList(utf8.encode(key));
  final ivBytes = Uint8List.fromList(utf8.encode(iv));
  final cipher = PaddedBlockCipherImpl(
    PKCS7Padding(),
    CBCBlockCipher(AESEngine()),
  );
  cipher.init(
    true,
    PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
      ParametersWithIV<KeyParameter>(KeyParameter(keyBytes), ivBytes),
      null,
    ),
  );
  return cipher.process(Uint8List.fromList(utf8.encode(plainText)));
}

String _encryptDesEcbPkcs7Base64({
  required String plainText,
  required String key,
}) {
  final raw = Uint8List(8)..setAll(0, utf8.encode(key).take(8));
  final keyBytes =
      Uint8List(24)
        ..setRange(0, 8, raw)
        ..setRange(8, 16, raw)
        ..setRange(16, 24, raw);
  final cipher = PaddedBlockCipherImpl(
    PKCS7Padding(),
    ECBBlockCipher(DESedeEngine()),
  );
  cipher.init(
    true,
    PaddedBlockCipherParameters<KeyParameter, Null>(
      KeyParameter(keyBytes),
      null,
    ),
  );
  final encrypted = cipher.process(Uint8List.fromList(utf8.encode(plainText)));
  return base64.encode(encrypted);
}

String _encryptAesEcbPkcs7Base64({
  required String plainText,
  required String key,
}) {
  final keyBytes = Uint8List.fromList(utf8.encode(key));
  final cipher = PaddedBlockCipherImpl(
    PKCS7Padding(),
    ECBBlockCipher(AESEngine()),
  );
  cipher.init(
    true,
    PaddedBlockCipherParameters<KeyParameter, Null>(
      KeyParameter(keyBytes),
      null,
    ),
  );

  final encrypted = cipher.process(Uint8List.fromList(utf8.encode(plainText)));
  return base64.encode(encrypted);
}

String _encryptAesCbcZeroPaddingBase64({
  required String plainText,
  required String key,
  required String iv,
}) {
  final keyBytes = Uint8List.fromList(utf8.encode(key));
  final ivBytes = Uint8List.fromList(utf8.encode(iv));
  final plainBytes = Uint8List.fromList(utf8.encode(plainText));
  final padded = _applyZeroPadding(plainBytes, blockSize: 16);
  final cipher = CBCBlockCipher(AESEngine());
  cipher.init(
    true,
    ParametersWithIV<KeyParameter>(KeyParameter(keyBytes), ivBytes),
  );

  final output = Uint8List(padded.lengthInBytes);
  for (var offset = 0; offset < padded.lengthInBytes; offset += 16) {
    cipher.processBlock(padded, offset, output, offset);
  }
  return base64.encode(output);
}

Uint8List _applyZeroPadding(Uint8List input, {required int blockSize}) {
  final remainder = input.lengthInBytes % blockSize;
  if (remainder == 0) {
    return Uint8List.fromList(input);
  }
  final output = Uint8List(input.lengthInBytes + (blockSize - remainder));
  output.setRange(0, input.lengthInBytes, input);
  return output;
}

String _toHex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final value in bytes) {
    buffer.write(value.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

String _buildNestedGetStringRule({
  required int depth,
  required String terminalRule,
}) {
  var output = terminalRule;
  for (var i = 0; i < depth; i += 1) {
    output = 'java.getString(${jsonEncode(output)})';
  }
  return output;
}
