import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_js/flutter_js.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:pointycastle/export.dart' as pointycastle;

import '../../errors/error_stage.dart';
import '../../logging/app_logger.dart';
import '../../network/http_client.dart';
import '../../network/request_context.dart';
import '../processors/legacy_rule_compat.dart';
import '../processors/legacy_script_rule_fallback.dart';
import '../rule_parser.dart';
import 'html_executor.dart';
import 'json_executor.dart';
import 'regex_executor.dart';

typedef JsRuntimeFactory = JavascriptRuntime Function();
typedef JsBridgePutCallback = void Function(Map<String, String> variables);

class JsExecutionContext {
  const JsExecutionContext({
    this.result,
    this.baseUrl,
    this.sourceId,
    this.stage,
    this.variables = const <String, String>{},
    this.bookJson,
    this.chapterJson,
    this.sourceJson,
    this.cookieJson,
    this.cacheJson,
    this.jsLibScript,
    this.onBridgePutVariables,
  });

  final String? result;
  final String? baseUrl;
  final String? sourceId;
  final ErrorStage? stage;
  final Map<String, String> variables;
  final Map<String, dynamic>? bookJson;
  final Map<String, dynamic>? chapterJson;
  final Map<String, dynamic>? sourceJson;
  final Map<String, dynamic>? cookieJson;
  final Map<String, dynamic>? cacheJson;
  final String? jsLibScript;
  final JsBridgePutCallback? onBridgePutVariables;

  JsExecutionContext copyWith({
    String? result,
    String? baseUrl,
    String? sourceId,
    ErrorStage? stage,
    Map<String, String>? variables,
    Map<String, dynamic>? bookJson,
    Map<String, dynamic>? chapterJson,
    Map<String, dynamic>? sourceJson,
    Map<String, dynamic>? cookieJson,
    Map<String, dynamic>? cacheJson,
    String? jsLibScript,
    JsBridgePutCallback? onBridgePutVariables,
  }) {
    return JsExecutionContext(
      result: result ?? this.result,
      baseUrl: baseUrl ?? this.baseUrl,
      sourceId: sourceId ?? this.sourceId,
      stage: stage ?? this.stage,
      variables: variables ?? this.variables,
      bookJson: bookJson ?? this.bookJson,
      chapterJson: chapterJson ?? this.chapterJson,
      sourceJson: sourceJson ?? this.sourceJson,
      cookieJson: cookieJson ?? this.cookieJson,
      cacheJson: cacheJson ?? this.cacheJson,
      jsLibScript: jsLibScript ?? this.jsLibScript,
      onBridgePutVariables: onBridgePutVariables ?? this.onBridgePutVariables,
    );
  }
}

class JsExecutor {
  JsExecutor({
    JsRuntimeFactory? runtimeFactory,
    AppLogger? logger,
    AppHttpClient? httpClient,
    this.defaultTimeout = const Duration(seconds: 3),
    this.networkRequestTimeout = const Duration(seconds: 15),
    this.networkRequestLimit = 5,
  }) : _runtimeFactory =
           runtimeFactory ?? (() => getJavascriptRuntime(xhr: false)),
       _logger = logger ?? AppLogger.instance,
       _httpClient = httpClient ?? AppHttpClient();

  final JsRuntimeFactory _runtimeFactory;
  final AppLogger _logger;
  final AppHttpClient _httpClient;
  final RuleParser _ruleParser = const RuleParser();
  final HtmlExecutor _htmlExecutor = const HtmlExecutor();
  final RegexExecutor _regexExecutor = const RegexExecutor();
  final JsonExecutor _jsonExecutor = const JsonExecutor();
  final Duration defaultTimeout;
  final Duration networkRequestTimeout;
  final int networkRequestLimit;
  static const Set<String> _supportedBridgeCalls = <String>{
    'ajax',
    'ajaxall',
    'connect',
    'head',
    'get',
    'post',
    'setcontent',
    'getstring',
    'getstringlist',
    'getelements',
    'getelement',
    'getcookie',
    'put',
    'log',
    'toast',
    'longtoast',
    'startbrowser',
    'startbrowserawait',
    'webview',
    'base64decode',
    'base64encode',
    'base64decodetobytearray',
    'base64decoder',
    'md5encode',
    'md5encode16',
    'encodeuri',
    'htmlformat',
    'timeformat',
    'timeformatutc',
    'tonumchapter',
    't2s',
    's2t',
    'strtobytes',
    'bytestostring',
    'createsymmetriccrypto',
    'refreshtocurl',
    'getwebviewua',
    'randomuuid',
    'androidid',
    'deviceid',
    'hexdecodetostring',
    'hexdecodetobytearray',
    'hexencodetostring',
    'digesthex',
    'hmachex',
    'hmacbase64',
    'desencodetobase64string',
    'initurl',
    'getstrresponse',
    'tourl',
    'regetbook',
    'aesdecodeargsbase64str',
    'cachefile',
    'getverificationcode',
    'importscript',
    'removecookie',
    'aesdecodetostring',
    'aesdecodetobytearray',
    'aesbase64decodetostring',
    'aesbase64decodetobytearray',
    'aesencodetostring',
    'aesencodetobytearray',
    'aesencodetobase64string',
    'aesencodetobase64bytearray',
  };
  static const String _channelPut = '__appread_js_bridge_put';
  static const String _channelGet = '__appread_js_bridge_get';
  static const String _channelLog = '__appread_js_bridge_log';
  static const String _channelBase64Decode =
      '__appread_js_bridge_base64_decode';
  static const String _channelBase64Encode =
      '__appread_js_bridge_base64_encode';
  static const String _channelBase64DecodeBytes =
      '__appread_js_bridge_base64_decode_bytes';
  static const String _channelMd5 = '__appread_js_bridge_md5';
  static const String _channelMd516 = '__appread_js_bridge_md5_16';
  static const String _channelEncodeUri = '__appread_js_bridge_encode_uri';
  static const String _channelHtmlFormat = '__appread_js_bridge_html_format';
  static const String _channelTimeFormat = '__appread_js_bridge_time_format';
  static const String _channelTimeFormatUtc =
      '__appread_js_bridge_time_format_utc';
  static const String _channelToNumChapter =
      '__appread_js_bridge_to_num_chapter';
  static const String _channelHexCodec = '__appread_js_bridge_hex_codec';
  static const String _channelDigest = '__appread_js_bridge_digest';
  static const String _channelHmac = '__appread_js_bridge_hmac';
  static const String _channelDes = '__appread_js_bridge_des';
  static const String _channelRuleAccess = '__appread_js_bridge_rule_access';
  static const String _channelAes = '__appread_js_bridge_aes';
  static const String _channelNetworkCollect =
      '__appread_js_bridge_network_collect';
  static const int _maxNetworkProbeRounds = 5;
  static const int _maxRuleBridgeRecursionDepth = 3;

  Future<String?> execute({
    required String script,
    required JsExecutionContext context,
    Duration? timeout,
  }) async {
    final normalizedScript = script.trim();
    if (normalizedScript.isEmpty) {
      return null;
    }

    final unsupportedBridgeCall = _firstUnsupportedBridgeCall(normalizedScript);
    if (unsupportedBridgeCall != null) {
      _logger.warn(
        'JS script includes unsupported bridge call',
        context: <String, Object?>{
          'sourceId': context.sourceId,
          'stage': context.stage?.name,
          'bridgeCall': unsupportedBridgeCall,
          'diagnostic': 'js_bridge_unsupported',
        },
      );
    }

    if (_containsPackagesInvocation(normalizedScript)) {
      _logger.warn(
        'JS script includes unsupported Packages bridge',
        context: <String, Object?>{
          'sourceId': context.sourceId,
          'stage': context.stage?.name,
          'diagnostic': 'js_bridge_unsupported',
        },
      );
    }

    if (_looksLikelyInfiniteLoop(normalizedScript)) {
      _logger.warn(
        'JS execution skipped due to loop guard',
        context: <String, Object?>{
          'sourceId': context.sourceId,
          'stage': context.stage?.name,
          'diagnostic': 'js_timeout_guard',
        },
      );
      return null;
    }

    final maxDuration = timeout ?? defaultTimeout;
    final startedAt = DateTime.now();
    JavascriptRuntime? runtime;
    final bridgeVariables = <String, String>{...context.variables};
    final putVariables = <String, String>{};
    final ruleState = _JsRuleBridgeState(
      content: context.result ?? '',
      baseUrl: context.baseUrl,
    );

    try {
      runtime = _runtimeFactory();
      _registerTier1Bridge(
        runtime,
        context: context,
        bridgeVariables: bridgeVariables,
        ruleState: ruleState,
        onBridgePut: (key, value) => putVariables[key] = value,
      );
      final ajaxCache = await _prefetchNetworkResponses(
        script: normalizedScript,
        context: context,
        bridgeVariables: bridgeVariables,
      );
      _injectContext(
        runtime,
        context,
        bridgeVariables: bridgeVariables,
        ajaxCache: ajaxCache,
      );
      _injectJsLib(runtime, context);
      final result = runtime.evaluate(normalizedScript);
      var normalizedResult = _normalizeResult(result.stringResult);
      if (normalizedResult == null) {
        final resultAlias = runtime.evaluate(
          'typeof result === "undefined" ? null : result',
        );
        normalizedResult = _normalizeResult(resultAlias.stringResult);
      }
      if (normalizedResult != null &&
          _looksLikeRuntimeErrorResult(normalizedResult)) {
        _logger.warn(
          'JS execution returned runtime error payload',
          context: <String, Object?>{
            'sourceId': context.sourceId,
            'stage': context.stage?.name,
            'briefMessage': normalizedResult,
            'diagnostic': 'js_runtime_error',
          },
        );
        return null;
      }
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed > maxDuration) {
        _logger.warn(
          'JS execution exceeded timeout window',
          context: <String, Object?>{
            'sourceId': context.sourceId,
            'stage': context.stage?.name,
            'elapsedMs': elapsed.inMilliseconds,
            'timeoutMs': maxDuration.inMilliseconds,
            'diagnostic': 'js_timeout',
          },
        );
        return null;
      }

      return normalizedResult;
    } catch (error) {
      _logger.warn(
        'JS execution failed',
        context: <String, Object?>{
          'sourceId': context.sourceId,
          'stage': context.stage?.name,
          'briefMessage': error.toString(),
          'diagnostic': 'js_executor_exception',
        },
      );
      return null;
    } finally {
      if (putVariables.isNotEmpty && context.onBridgePutVariables != null) {
        try {
          context.onBridgePutVariables!(
            Map<String, String>.unmodifiable({...putVariables}),
          );
        } catch (error) {
          _logger.warn(
            'JS bridge put callback failed',
            context: <String, Object?>{
              'sourceId': context.sourceId,
              'stage': context.stage?.name,
              'briefMessage': error.toString(),
              'diagnostic': 'js_bridge_put_callback_failed',
            },
          );
        }
      }
      runtime?.dispose();
    }
  }

  void _injectJsLib(JavascriptRuntime runtime, JsExecutionContext context) {
    final jsLib = context.jsLibScript?.trim();
    if (jsLib == null || jsLib.isEmpty) {
      return;
    }

    try {
      runtime.evaluate(jsLib);
    } catch (error) {
      _logger.warn(
        'JS library injection failed',
        context: <String, Object?>{
          'sourceId': context.sourceId,
          'stage': context.stage?.name,
          'briefMessage': error.toString(),
          'diagnostic': 'js_lib_inject_failed',
        },
      );
    }
  }

  void _injectContext(
    JavascriptRuntime runtime,
    JsExecutionContext context, {
    required Map<String, String> bridgeVariables,
    required Map<String, String> ajaxCache,
  }) {
    runtime.evaluate('var result = ${jsonEncode(context.result ?? '')};');
    if (context.baseUrl != null && context.baseUrl!.trim().isNotEmpty) {
      runtime.evaluate('var baseUrl = ${jsonEncode(context.baseUrl)};');
    }
    if (context.bookJson != null) {
      runtime.evaluate('var book = ${jsonEncode(context.bookJson)};');
    }
    if (context.chapterJson != null) {
      runtime.evaluate('var chapter = ${jsonEncode(context.chapterJson)};');
    }
    if (context.sourceJson != null) {
      runtime.evaluate('var source = ${jsonEncode(context.sourceJson)};');
    }
    runtime.evaluate('var __bridge_vars = ${jsonEncode(bridgeVariables)};');
    runtime.evaluate(
      'var __cookie_store = ${jsonEncode(context.cookieJson ?? const <String, dynamic>{})};',
    );
    runtime.evaluate(
      'var __cache_store = ${jsonEncode(context.cacheJson ?? const <String, dynamic>{})};',
    );
    runtime.evaluate('var __ajax_cache = ${jsonEncode(ajaxCache)};');
    final bridgeInitResult = runtime.evaluate('''
      function __appread_bridge_call(channel, payload) {
        try {
          return sendMessage(channel, JSON.stringify(payload || {}));
        } catch (_) {
          return null;
        }
      }
      function __appread_bridge_text(value) {
        if (value == null) {
          return '';
        }
        if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
          return String(value);
        }
        try {
          return JSON.stringify(value);
        } catch (_) {
          return String(value);
        }
      }
      function __appread_string_to_bytes(value) {
        var text = __appread_bridge_text(value);
        var output = [];
        for (var i = 0; i < text.length; i++) {
          output.push(text.charCodeAt(i) & 0xFF);
        }
        return output;
      }
      function __appread_bytes_to_string(value) {
        if (!Array.isArray(value)) {
          return __appread_bridge_text(value);
        }
        var chars = [];
        for (var i = 0; i < value.length; i++) {
          var code = Number(value[i]);
          if (!isFinite(code)) {
            continue;
          }
          chars.push(String.fromCharCode(code & 0xFF));
        }
        return chars.join('');
      }
      function __appread_source_value(name) {
        try {
          if (typeof source !== 'undefined' && source != null) {
            var value = source[name];
            if (value != null) {
              return __appread_bridge_text(value);
            }
          }
        } catch (_) {}
        return '';
      }
      function __appread_ajax_headers_signature(headers) {
        if (headers == null || typeof headers !== 'object') {
          return '';
        }
        var keys = Object.keys(headers).sort();
        var pairs = [];
        for (var i = 0; i < keys.length; i++) {
          var key = __appread_bridge_text(keys[i]).trim().toLowerCase();
          if (!key) {
            continue;
          }
          pairs.push(key + ':' + __appread_bridge_text(headers[keys[i]]));
        }
        return pairs.join('\\n');
      }
      function __appread_ajax_signature(method, url, body, headers) {
        return __appread_bridge_text(method).toUpperCase() + '|' +
            __appread_bridge_text(url).trim() + '|' +
            __appread_bridge_text(body) + '|' +
            __appread_ajax_headers_signature(headers);
      }
      function __appread_ajax_url_key(method, url) {
        return __appread_bridge_text(method).toUpperCase() + '|' +
            __appread_bridge_text(url).trim() + '||';
      }
      function __appread_maybe_url(value) {
        var text = __appread_bridge_text(value).trim().toLowerCase();
        return text.indexOf('http://') === 0 ||
            text.indexOf('https://') === 0 ||
            text.indexOf('/') === 0;
      }
      function __appread_parse_absolute_url(value) {
        var text = __appread_bridge_text(value).trim();
        if (!text) {
          return null;
        }
        var schemeSeparator = text.indexOf('://');
        if (schemeSeparator <= 0) {
          return null;
        }
        var protocolName = text.substring(0, schemeSeparator);
        var protocol = protocolName + ':';
        var remainder = text.substring(schemeSeparator + 3);
        var hashIndex = remainder.indexOf('#');
        var hash = '';
        if (hashIndex >= 0) {
          hash = remainder.substring(hashIndex);
          remainder = remainder.substring(0, hashIndex);
        }
        var queryIndex = remainder.indexOf('?');
        var search = '';
        if (queryIndex >= 0) {
          search = remainder.substring(queryIndex);
          remainder = remainder.substring(0, queryIndex);
        }
        var slashIndex = remainder.indexOf('/');
        var host = '';
        var pathname = '/';
        if (slashIndex < 0) {
          host = remainder;
        } else {
          host = remainder.substring(0, slashIndex);
          pathname = remainder.substring(slashIndex);
        }
        if (!host) {
          return null;
        }
        return {
          protocol: protocol,
          host: host,
          pathname: pathname || '/',
          search: search || '',
          hash: hash || '',
          href: text
        };
      }
      function __appread_url_origin(parts) {
        if (parts == null) {
          return '';
        }
        return parts.protocol + '//' + parts.host;
      }
      function __appread_resolve_url(value, baseValue) {
        var raw = __appread_bridge_text(value).trim();
        if (!raw) {
          return '';
        }
        if (raw.indexOf('://') > 0) {
          return raw;
        }
        var base = __appread_parse_absolute_url(baseValue);
        if (base == null) {
          return raw;
        }
        var origin = __appread_url_origin(base);
        if (raw.indexOf('//') === 0) {
          return base.protocol + raw;
        }
        if (raw.charAt(0) === '/') {
          return origin + raw;
        }
        var directory = base.pathname || '/';
        if (!directory.endsWith('/')) {
          var index = directory.lastIndexOf('/');
          directory = index >= 0 ? directory.substring(0, index + 1) : '/';
        }
        return origin + directory + raw;
      }
      function __appread_to_url_object(value, baseValue) {
        var href = __appread_resolve_url(value, baseValue);
        var parsed = __appread_parse_absolute_url(href);
        if (parsed == null) {
          return {
            href: href,
            origin: '',
            host: '',
            hostname: '',
            protocol: '',
            pathname: '',
            search: '',
            hash: '',
            toString: function() {
              return href;
            }
          };
        }
        var hostname = parsed.host;
        if (hostname.indexOf(']') < 0 || hostname.charAt(0) !== '[') {
          var portSeparator = hostname.lastIndexOf(':');
          if (portSeparator > 0) {
            hostname = hostname.substring(0, portSeparator);
          }
        }
        return {
          href: parsed.href,
          origin: __appread_url_origin(parsed),
          host: parsed.host,
          hostname: hostname,
          protocol: parsed.protocol,
          pathname: parsed.pathname,
          search: parsed.search,
          hash: parsed.hash,
          toString: function() {
            return parsed.href;
          }
        };
      }
      function __appread_current_base_url() {
        try {
          if (typeof baseUrl === 'undefined') {
            return '';
          }
          return __appread_bridge_text(baseUrl);
        } catch (_) {
          return '';
        }
      }
      var __appread_str_response_state = {
        url: __appread_maybe_url(result) ? __appread_bridge_text(result) : __appread_current_base_url(),
        body: __appread_maybe_url(result) ? '' : __appread_bridge_text(result),
        code: 200
      };
      function __appread_update_str_response(url, body, code) {
        var normalizedUrl = __appread_bridge_text(url);
        var normalizedBody = __appread_bridge_text(body);
        if (normalizedUrl) {
          __appread_str_response_state.url = normalizedUrl;
        }
        __appread_str_response_state.body = normalizedBody;
        var parsedCode = Number(code);
        __appread_str_response_state.code = isFinite(parsedCode) ? parsedCode : 200;
      }
      function __appread_make_str_response() {
        return {
          url: function() { return __appread_str_response_state.url || ''; },
          body: function() { return __appread_str_response_state.body || ''; },
          bodyText: function() { return __appread_str_response_state.body || ''; },
          text: function() { return __appread_str_response_state.body || ''; },
          html: function() { return __appread_str_response_state.body || ''; },
          code: function() { return __appread_str_response_state.code || 200; },
          headers: function() { return []; },
          cookies: function() { return {}; },
          toString: function() { return __appread_str_response_state.body || ''; }
        };
      }
      function __appread_ajax_fetch(method, url, body, headers) {
        var signature = __appread_ajax_signature(method, url, body, headers);
        var output = __ajax_cache[signature];
        if (output == null) {
          __appread_bridge_call('$_channelNetworkCollect', {
            method: __appread_bridge_text(method).toUpperCase(),
            url: __appread_bridge_text(url),
            body: __appread_bridge_text(body),
            headers: headers == null ? {} : headers
          });
          output = __ajax_cache[__appread_ajax_url_key(method, url)];
        }
        return output == null ? '' : String(output);
      }
      function __appread_ajax_all(method, urls, body, headers) {
        if (!Array.isArray(urls)) {
          return [];
        }
        var results = [];
        for (var i = 0; i < urls.length; i++) {
          var text = __appread_ajax_fetch(method, urls[i], body, headers);
          results.push({
            body: (function(v) {
              return function() {
                return v;
              };
            })(text),
            toString: (function(v) {
              return function() {
                return v;
              };
            })(text)
          });
        }
        return results;
      }
      function __appread_connect_response(text) {
        var bodyText = text == null ? '' : String(text);
        return {
          body: function() { return bodyText; },
          bodyText: function() { return bodyText; },
          text: function() { return bodyText; },
          html: function() { return bodyText; },
          code: function() { return 200; },
          headers: function() { return []; },
          cookies: function() { return {}; },
          toString: function() { return bodyText; }
        };
      }
      function __appread_connect(url, headers) {
        var state = {
          url: __appread_bridge_text(url),
          method: 'GET',
          body: '',
          headers: headers == null || typeof headers !== 'object' ? {} : headers
        };
        function executeFetch() {
          var text = __appread_ajax_fetch(state.method, state.url, state.body, state.headers);
          return __appread_connect_response(text);
        }
        return {
          url: function(value) {
            state.url = __appread_bridge_text(value);
            return this;
          },
          method: function(value) {
            var text = __appread_bridge_text(value).toUpperCase();
            state.method = text === 'POST' ? 'POST' : 'GET';
            return this;
          },
          header: function(key, value) {
            state.headers[__appread_bridge_text(key)] = __appread_bridge_text(value);
            return this;
          },
          headers: function(values) {
            if (values != null && typeof values === 'object') {
              var keys = Object.keys(values);
              for (var i = 0; i < keys.length; i++) {
                state.headers[keys[i]] = __appread_bridge_text(values[keys[i]]);
              }
            }
            return this;
          },
          data: function(value) {
            state.body = __appread_bridge_text(value);
            return this;
          },
          get: function() {
            state.method = 'GET';
            return executeFetch();
          },
          post: function() {
            state.method = 'POST';
            return executeFetch();
          },
          execute: function() {
            return executeFetch();
          }
        };
      }
      function __appread_cookie_bucket(host) {
        var key = __appread_bridge_text(host);
        if (!key) {
          return null;
        }
        var bucket = __cookie_store[key];
        if (bucket == null || typeof bucket !== 'object') {
          bucket = {};
          __cookie_store[key] = bucket;
        }
        return bucket;
      }
      var cookie = {
        getKey: function(host, key) {
          var bucket = __cookie_store[__appread_bridge_text(host)];
          if (bucket == null || typeof bucket !== 'object') {
            return '';
          }
          var value = bucket[__appread_bridge_text(key)];
          return value == null ? '' : String(value);
        },
        setKey: function(host, key, value) {
          var bucket = __appread_cookie_bucket(host);
          if (bucket == null) {
            return '';
          }
          bucket[__appread_bridge_text(key)] = __appread_bridge_text(value);
          return '';
        },
        removeCookie: function(host) {
          delete __cookie_store[__appread_bridge_text(host)];
          return '';
        }
      };
      var cache = {
        putMemory: function(key, value) {
          __cache_store[__appread_bridge_text(key)] = __appread_bridge_text(value);
          return '';
        },
        getFromMemory: function(key) {
          var value = __cache_store[__appread_bridge_text(key)];
          return value == null ? '' : String(value);
        },
        deleteMemory: function(key) {
          delete __cache_store[__appread_bridge_text(key)];
          return '';
        }
      };
      var java = {
        put: function(key, value) {
          __appread_bridge_call('$_channelPut', {
            key: __appread_bridge_text(key),
            value: __appread_bridge_text(value)
          });
          return '';
        },
        log: function(message) {
          __appread_bridge_call('$_channelLog', {
            message: __appread_bridge_text(message)
          });
          return '';
        },
        base64Decode: function(value, flags) {
          var decoded = __appread_bridge_call('$_channelBase64Decode', {
            value: __appread_bridge_text(value),
            flags: flags == null ? null : Number(flags)
          });
          return decoded == null ? '' : String(decoded);
        },
        base64Encode: function(value, flags) {
          var encoded = __appread_bridge_call('$_channelBase64Encode', {
            value: __appread_bridge_text(value),
            flags: flags == null ? null : Number(flags)
          });
          return encoded == null ? '' : String(encoded);
        },
        base64DecodeToByteArray: function(value, flags) {
          var output = __appread_bridge_call('$_channelBase64DecodeBytes', {
            value: __appread_bridge_text(value),
            flags: flags == null ? null : Number(flags)
          });
          return Array.isArray(output) ? output : [];
        },
        md5Encode: function(value) {
          var hashed = __appread_bridge_call('$_channelMd5', {
            value: __appread_bridge_text(value)
          });
          return hashed == null ? '' : String(hashed);
        },
        md5Encode16: function(value) {
          var hashed = __appread_bridge_call('$_channelMd516', {
            value: __appread_bridge_text(value)
          });
          return hashed == null ? '' : String(hashed);
        },
        encodeURI: function(value, encoding) {
          var encoded = __appread_bridge_call('$_channelEncodeUri', {
            value: __appread_bridge_text(value),
            encoding: __appread_bridge_text(encoding)
          });
          return encoded == null ? '' : String(encoded);
        },
        htmlFormat: function(value) {
          var cleaned = __appread_bridge_call('$_channelHtmlFormat', {
            value: __appread_bridge_text(value)
          });
          return cleaned == null ? '' : String(cleaned);
        },
        timeFormat: function(value) {
          var formatted = __appread_bridge_call('$_channelTimeFormat', {
            value: value
          });
          return formatted == null ? '' : String(formatted);
        },
        timeFormatUTC: function(value) {
          var formatted = __appread_bridge_call('$_channelTimeFormatUtc', {
            value: value
          });
          return formatted == null ? '' : String(formatted);
        },
        toNumChapter: function(value) {
          var output = __appread_bridge_call('$_channelToNumChapter', {
            value: __appread_bridge_text(value)
          });
          var parsed = Number(output);
          return isFinite(parsed) ? parsed : -1;
        },
        t2s: function(value) {
          return __appread_bridge_text(value);
        },
        s2t: function(value) {
          return __appread_bridge_text(value);
        },
        toast: function(message) {
          return '';
        },
        longToast: function(message) {
          return '';
        },
        startBrowser: function(url) {
          return '';
        },
        startBrowserAwait: function(url) {
          return '';
        },
        webView: function(url) {
          return '';
        },
        setContent: function(content, baseUrlValue) {
          __appread_bridge_call('$_channelRuleAccess', {
            action: 'set_content',
            content: __appread_bridge_text(content),
            baseUrl: baseUrlValue == null ? '' : __appread_bridge_text(baseUrlValue)
          });
          return '';
        },
        getString: function(rule, isUrl) {
          var output = __appread_bridge_call('$_channelRuleAccess', {
            action: 'get_string',
            rule: __appread_bridge_text(rule),
            isUrl: !!isUrl
          });
          return output == null ? '' : String(output);
        },
        getStringList: function(rule, isUrl) {
          var output = __appread_bridge_call('$_channelRuleAccess', {
            action: 'get_string_list',
            rule: __appread_bridge_text(rule),
            isUrl: !!isUrl
          });
          return Array.isArray(output) ? output : [];
        },
        getElements: function(rule, isUrl) {
          var output = __appread_bridge_call('$_channelRuleAccess', {
            action: 'get_elements',
            rule: __appread_bridge_text(rule),
            isUrl: !!isUrl
          });
          return Array.isArray(output) ? output : [];
        },
        getElement: function(rule, isUrl) {
          var list = java.getElements(rule, isUrl);
          return Array.isArray(list) && list.length > 0 ? list[0] : '';
        },
        getCookie: function(tag, key) {
          return cookie.getKey(tag, key);
        },
        strToBytes: function(value) {
          return __appread_string_to_bytes(value);
        },
        bytesToString: function(value) {
          return __appread_bytes_to_string(value);
        },
        randomUUID: function() {
          return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
            var r = Math.floor(Math.random() * 16);
            var v = c === 'x' ? r : ((r & 0x3) | 0x8);
            return v.toString(16);
          });
        },
        getWebViewUA: function() {
          var fromVars = __bridge_vars["webViewUA"];
          if (fromVars != null && __appread_bridge_text(fromVars).trim()) {
            return __appread_bridge_text(fromVars);
          }
          var fromSource = __appread_source_value("webViewUA");
          if (fromSource) {
            return fromSource;
          }
          return "Mozilla/5.0 (Linux; Android 13; Pixel 7 Build/TQ3A.230901.001) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36";
        },
        androidId: function() {
          var fromVars = __bridge_vars["androidId"];
          if (fromVars != null && __appread_bridge_text(fromVars).trim()) {
            return __appread_bridge_text(fromVars);
          }
          var fromSource = __appread_source_value("androidId");
          if (fromSource) {
            return fromSource;
          }
          return "b443cebc6f614746";
        },
        deviceID: function() {
          return java.androidId();
        },
        initUrl: function(url) {
          var candidate = __appread_bridge_text(url);
          if (!candidate) {
            candidate = __appread_bridge_text(java.ruleUrl);
          }
          if (!candidate) {
            candidate = __appread_current_base_url();
          }
          if (!candidate && __appread_str_response_state.url) {
            candidate = __appread_bridge_text(__appread_str_response_state.url);
          }
          candidate = __appread_resolve_url(candidate, __appread_current_base_url());
          java.ruleUrl = candidate;
          if (candidate) {
            __appread_str_response_state.url = candidate;
          }
          return candidate;
        },
        getStrResponse: function(url, body, code) {
          var nextUrl = '';
          var nextBody = '';
          if (arguments.length >= 2) {
            nextUrl = __appread_bridge_text(url);
            nextBody = __appread_bridge_text(body);
          } else if (arguments.length === 1) {
            if (__appread_maybe_url(url)) {
              nextUrl = __appread_bridge_text(url);
            } else {
              nextBody = __appread_bridge_text(url);
            }
          }
          if (!nextUrl) {
            nextUrl = __appread_bridge_text(java.ruleUrl) ||
                __appread_bridge_text(__appread_str_response_state.url) ||
                __appread_current_base_url();
          }
          if (!nextBody) {
            nextBody = __appread_bridge_text(__appread_str_response_state.body);
          }
          if (!nextBody && !__appread_maybe_url(result)) {
            nextBody = __appread_bridge_text(result);
          }
          __appread_update_str_response(nextUrl, nextBody, code);
          return __appread_make_str_response();
        },
        toURL: function(value, baseValue) {
          return __appread_to_url_object(
            value,
            __appread_bridge_text(baseValue) || __appread_current_base_url()
          );
        },
        toUrl: function(value, baseValue) {
          return __appread_resolve_url(
            value,
            __appread_bridge_text(baseValue) || __appread_current_base_url()
          );
        },
        reGetBook: function() {
          return '';
        },
        refreshTocUrl: function(url) {
          if (arguments.length > 0) {
            java.put("nextTocUrl", __appread_bridge_text(url));
          }
          return java.get("nextTocUrl");
        },
        hexDecodeToString: function(value) {
          var output = __appread_bridge_call('$_channelHexCodec', {
            action: 'decode_string',
            value: __appread_bridge_text(value)
          });
          return output == null ? '' : String(output);
        },
        hexDecodeToByteArray: function(value) {
          var output = __appread_bridge_call('$_channelHexCodec', {
            action: 'decode_bytes',
            value: __appread_bridge_text(value)
          });
          return Array.isArray(output) ? output : [];
        },
        hexEncodeToString: function(value) {
          var output = __appread_bridge_call('$_channelHexCodec', {
            action: 'encode_string',
            value: __appread_bridge_text(value)
          });
          return output == null ? '' : String(output);
        },
        digestHex: function(value, algorithm) {
          var output = __appread_bridge_call('$_channelDigest', {
            value: __appread_bridge_text(value),
            algorithm: __appread_bridge_text(algorithm || 'MD5')
          });
          return output == null ? '' : String(output);
        },
        hmacHex: function(value, algorithm, key) {
          var output = __appread_bridge_call('$_channelHmac', {
            value: __appread_bridge_text(value),
            algorithm: __appread_bridge_text(algorithm || 'HmacMD5'),
            key: __appread_bridge_text(key),
            encoding: 'hex'
          });
          return output == null ? '' : String(output);
        },
        hmacBase64: function(value, algorithm, key) {
          var output = __appread_bridge_call('$_channelHmac', {
            value: __appread_bridge_text(value),
            algorithm: __appread_bridge_text(algorithm || 'HmacMD5'),
            key: __appread_bridge_text(key),
            encoding: 'base64'
          });
          return output == null ? '' : String(output);
        },
        desEncodeToBase64String: function(value, key, transformation, iv) {
          var output = __appread_bridge_call('$_channelDes', {
            action: 'encode_base64_string',
            value: __appread_bridge_text(value),
            key: __appread_bridge_text(key),
            transformation: __appread_bridge_text(
              transformation || 'DES/ECB/PKCS5Padding'
            ),
            iv: iv == null ? null : __appread_bridge_text(iv)
          });
          return output == null ? '' : String(output);
        },
        aesDecodeArgsBase64Str: function(value, key, mode, padding, iv) {
          var decodedKey = java.base64Decode(__appread_bridge_text(key));
          var decodedIv = __appread_bridge_text(iv).trim() ? java.base64Decode(__appread_bridge_text(iv)) : '';
          var normalizedMode = __appread_bridge_text(mode || 'CBC').toUpperCase();
          if (normalizedMode !== 'CBC' && normalizedMode !== 'ECB') {
            normalizedMode = 'CBC';
          }
          var normalizedPadding = __appread_bridge_text(padding || 'PKCS7Padding');
          if (!normalizedPadding) {
            normalizedPadding = 'PKCS7Padding';
          }
          var transformation = 'AES/' + normalizedMode + '/' + normalizedPadding;
          return java.aesBase64DecodeToString(
            __appread_bridge_text(value),
            decodedKey,
            transformation,
            decodedIv
          );
        },
        cacheFile: function(url, headers) {
          return java.ajax(java.toUrl(url), headers);
        },
        importScript: function(url, headers) {
          return java.cacheFile(url, headers);
        },
        getVerificationCode: function(url) {
          return '';
        },
        removeCookie: function(host) {
          return cookie.removeCookie(host);
        },
        ajax: function(url, headers) {
          return __appread_ajax_fetch('GET', url, '', headers);
        },
        ajaxAll: function(urls, headers) {
          return __appread_ajax_all('GET', urls, '', headers);
        },
        connect: function(url, headers) {
          return __appread_connect(url, headers);
        },
        head: function(url, headers) {
          return __appread_ajax_fetch('GET', url, '', headers);
        },
        get: function(keyOrUrl, headers) {
          if (arguments.length > 1 || __appread_maybe_url(keyOrUrl)) {
            return __appread_ajax_fetch('GET', keyOrUrl, '', headers);
          }
          var value = __appread_bridge_call('$_channelGet', {
            key: __appread_bridge_text(keyOrUrl)
          });
          return value == null ? '' : String(value);
        },
        post: function(url, body, headers) {
          return __appread_ajax_fetch('POST', url, body, headers);
        },
        createSymmetricCrypto: function(transformation, key, iv) {
          var normalizedTransformation = __appread_bridge_text(
            transformation || 'AES/CBC/PKCS5Padding'
          );
          var normalizedKey = Array.isArray(key)
              ? __appread_bytes_to_string(key)
              : __appread_bridge_text(key);
          var normalizedIv = Array.isArray(iv)
              ? __appread_bytes_to_string(iv)
              : __appread_bridge_text(iv);
          return {
            decryptStr: function(value) {
              return java.aesDecodeToString(
                value,
                normalizedKey,
                normalizedTransformation,
                normalizedIv
              );
            },
            decryptByteArray: function(value) {
              return java.aesDecodeToByteArray(
                value,
                normalizedKey,
                normalizedTransformation,
                normalizedIv
              );
            },
            decryptBase64Str: function(value) {
              return java.aesBase64DecodeToString(
                value,
                normalizedKey,
                normalizedTransformation,
                normalizedIv
              );
            },
            decryptBase64ByteArray: function(value) {
              return java.aesBase64DecodeToByteArray(
                value,
                normalizedKey,
                normalizedTransformation,
                normalizedIv
              );
            },
            encryptStr: function(value) {
              return java.aesEncodeToString(
                value,
                normalizedKey,
                normalizedTransformation,
                normalizedIv
              );
            },
            encryptByteArray: function(value) {
              return java.aesEncodeToByteArray(
                value,
                normalizedKey,
                normalizedTransformation,
                normalizedIv
              );
            },
            encryptBase64Str: function(value) {
              return java.aesEncodeToBase64String(
                value,
                normalizedKey,
                normalizedTransformation,
                normalizedIv
              );
            },
            encryptBase64ByteArray: function(value) {
              return java.aesEncodeToBase64ByteArray(
                value,
                normalizedKey,
                normalizedTransformation,
                normalizedIv
              );
            }
          };
        },
        aesDecodeToString: function(value, key, transformation, iv) {
          var output = __appread_bridge_call('$_channelAes', {
            action: 'decode_string',
            value: value,
            key: __appread_bridge_text(key),
            transformation: __appread_bridge_text(transformation || 'AES/CBC/PKCS5Padding'),
            iv: iv == null ? null : __appread_bridge_text(iv)
          });
          return output == null ? '' : String(output);
        },
        aesDecodeToByteArray: function(value, key, transformation, iv) {
          var output = __appread_bridge_call('$_channelAes', {
            action: 'decode_bytes',
            value: value,
            key: __appread_bridge_text(key),
            transformation: __appread_bridge_text(transformation || 'AES/CBC/PKCS5Padding'),
            iv: iv == null ? null : __appread_bridge_text(iv)
          });
          return Array.isArray(output) ? output : [];
        },
        aesBase64DecodeToString: function(value, key, transformation, iv) {
          var output = __appread_bridge_call('$_channelAes', {
            action: 'base64_decode_string',
            value: value,
            key: __appread_bridge_text(key),
            transformation: __appread_bridge_text(transformation || 'AES/CBC/PKCS5Padding'),
            iv: iv == null ? null : __appread_bridge_text(iv)
          });
          return output == null ? '' : String(output);
        },
        aesBase64DecodeToByteArray: function(value, key, transformation, iv) {
          var output = __appread_bridge_call('$_channelAes', {
            action: 'base64_decode_bytes',
            value: value,
            key: __appread_bridge_text(key),
            transformation: __appread_bridge_text(transformation || 'AES/CBC/PKCS5Padding'),
            iv: iv == null ? null : __appread_bridge_text(iv)
          });
          return Array.isArray(output) ? output : [];
        },
        aesEncodeToString: function(value, key, transformation, iv) {
          var output = __appread_bridge_call('$_channelAes', {
            action: 'encode_string',
            value: value,
            key: __appread_bridge_text(key),
            transformation: __appread_bridge_text(transformation || 'AES/CBC/PKCS5Padding'),
            iv: iv == null ? null : __appread_bridge_text(iv)
          });
          return output == null ? '' : String(output);
        },
        aesEncodeToByteArray: function(value, key, transformation, iv) {
          var output = __appread_bridge_call('$_channelAes', {
            action: 'encode_bytes',
            value: value,
            key: __appread_bridge_text(key),
            transformation: __appread_bridge_text(transformation || 'AES/CBC/PKCS5Padding'),
            iv: iv == null ? null : __appread_bridge_text(iv)
          });
          return Array.isArray(output) ? output : [];
        },
        aesEncodeToBase64String: function(value, key, transformation, iv) {
          var output = __appread_bridge_call('$_channelAes', {
            action: 'encode_base64_string',
            value: value,
            key: __appread_bridge_text(key),
            transformation: __appread_bridge_text(transformation || 'AES/CBC/PKCS5Padding'),
            iv: iv == null ? null : __appread_bridge_text(iv)
          });
          return output == null ? '' : String(output);
        },
        aesEncodeToBase64ByteArray: function(value, key, transformation, iv) {
          var output = __appread_bridge_call('$_channelAes', {
            action: 'encode_base64_bytes',
            value: value,
            key: __appread_bridge_text(key),
            transformation: __appread_bridge_text(transformation || 'AES/CBC/PKCS5Padding'),
            iv: iv == null ? null : __appread_bridge_text(iv)
          });
          return Array.isArray(output) ? output : [];
        }
      };
      java.HMacHex = java.hmacHex;
      java.HMacBase64 = java.hmacBase64;
      java.base64Decoder = java.base64Decode;
      java.deviceId = java.deviceID;
    ''');
    final bridgeInitOutput = _normalizeResult(bridgeInitResult.stringResult);
    if (bridgeInitOutput != null &&
        _looksLikeRuntimeErrorResult(bridgeInitOutput)) {
      throw StateError('JS bridge bootstrap failed: $bridgeInitOutput');
    }
  }

  void _registerTier1Bridge(
    JavascriptRuntime runtime, {
    required JsExecutionContext context,
    required Map<String, String> bridgeVariables,
    required _JsRuleBridgeState ruleState,
    void Function(String key, String value)? onBridgePut,
    void Function(_JsNetworkRequest request)? onNetworkRequest,
  }) {
    runtime.onMessage(_channelPut, (dynamic args) {
      final payload = _asPayload(args);
      final key = payload['key']?.toString().trim() ?? '';
      if (key.isEmpty) {
        return '';
      }
      final value = payload['value']?.toString() ?? '';
      bridgeVariables[key] = value;
      onBridgePut?.call(key, value);
      return '';
    });

    runtime.onMessage(_channelGet, (dynamic args) {
      final payload = _asPayload(args);
      final key = payload['key']?.toString().trim() ?? '';
      if (key.isEmpty) {
        return '';
      }
      return bridgeVariables[key] ?? '';
    });

    runtime.onMessage(_channelLog, (dynamic args) {
      final payload = _asPayload(args);
      final message = payload['message']?.toString().trim() ?? '';
      if (message.isNotEmpty) {
        _logger.info(
          'JS bridge log',
          context: <String, Object?>{
            'sourceId': context.sourceId,
            'stage': context.stage?.name,
            'message': message,
          },
        );
      }
      return '';
    });

    runtime.onMessage(_channelBase64Decode, (dynamic args) {
      final payload = _asPayload(args);
      final bytes = _decodeBase64Bytes(payload['value']?.toString() ?? '');
      if (bytes == null) {
        return '';
      }
      return utf8.decode(bytes, allowMalformed: true);
    });

    runtime.onMessage(_channelBase64Encode, (dynamic args) {
      final payload = _asPayload(args);
      final value = payload['value']?.toString() ?? '';
      if (value.isEmpty) {
        return '';
      }
      return base64Encode(utf8.encode(value));
    });

    runtime.onMessage(_channelBase64DecodeBytes, (dynamic args) {
      final payload = _asPayload(args);
      final bytes = _decodeBase64Bytes(payload['value']?.toString() ?? '');
      return bytes?.toList(growable: false) ?? const <int>[];
    });

    runtime.onMessage(_channelMd5, (dynamic args) {
      final payload = _asPayload(args);
      final value = payload['value']?.toString() ?? '';
      return crypto.md5.convert(utf8.encode(value)).toString();
    });

    runtime.onMessage(_channelMd516, (dynamic args) {
      final payload = _asPayload(args);
      final value = payload['value']?.toString() ?? '';
      final full = crypto.md5.convert(utf8.encode(value)).toString();
      if (full.length < 24) {
        return full;
      }
      return full.substring(8, 24);
    });

    runtime.onMessage(_channelEncodeUri, (dynamic args) {
      final payload = _asPayload(args);
      final value = payload['value']?.toString() ?? '';
      return Uri.encodeComponent(value);
    });

    runtime.onMessage(_channelHtmlFormat, (dynamic args) {
      final payload = _asPayload(args);
      final value = payload['value']?.toString() ?? '';
      if (value.trim().isEmpty) {
        return '';
      }
      final plainText = html_parser.parseFragment(value).text ?? '';
      return plainText.replaceAll('\u00A0', ' ').trim();
    });

    runtime.onMessage(_channelTimeFormat, (dynamic args) {
      final payload = _asPayload(args);
      final parsed = _parseTime(payload['value']);
      if (parsed == null) {
        return '';
      }
      return _formatTime(parsed);
    });

    runtime.onMessage(_channelTimeFormatUtc, (dynamic args) {
      final payload = _asPayload(args);
      final parsed = _parseTime(payload['value']);
      if (parsed == null) {
        return '';
      }
      return _formatTimeUtc(parsed);
    });

    runtime.onMessage(_channelToNumChapter, (dynamic args) {
      final payload = _asPayload(args);
      final value = payload['value']?.toString() ?? '';
      return _toNumChapter(value).toString();
    });

    runtime.onMessage(_channelHexCodec, (dynamic args) {
      final payload = _asPayload(args);
      final action = payload['action']?.toString().trim().toLowerCase() ?? '';
      final value = payload['value']?.toString() ?? '';
      if (action == 'decode_string') {
        final bytes = _decodeHexBytes(value);
        if (bytes == null || bytes.isEmpty) {
          return '';
        }
        return utf8.decode(bytes, allowMalformed: true);
      }
      if (action == 'decode_bytes') {
        final bytes = _decodeHexBytes(value);
        return bytes?.toList(growable: false) ?? const <int>[];
      }
      if (action == 'encode_string') {
        return _encodeHexString(utf8.encode(value));
      }
      return '';
    });

    runtime.onMessage(_channelDigest, (dynamic args) {
      final payload = _asPayload(args);
      final value = payload['value']?.toString() ?? '';
      final algorithm = payload['algorithm']?.toString() ?? 'MD5';
      return _digestHex(value: value, algorithm: algorithm);
    });

    runtime.onMessage(_channelHmac, (dynamic args) {
      final payload = _asPayload(args);
      final value = payload['value']?.toString() ?? '';
      final algorithm = payload['algorithm']?.toString() ?? 'HmacMD5';
      final key = payload['key']?.toString() ?? '';
      final encoding = payload['encoding']?.toString() ?? 'hex';
      return _hmacDigest(
        value: value,
        algorithm: algorithm,
        key: key,
        encoding: encoding,
      );
    });

    runtime.onMessage(_channelDes, (dynamic args) {
      final payload = _asPayload(args);
      final action = payload['action']?.toString().trim().toLowerCase() ?? '';
      if (action != 'encode_base64_string') {
        return '';
      }

      final value = payload['value'];
      final key = payload['key']?.toString() ?? '';
      final transformation =
          payload['transformation']?.toString() ?? 'DES/ECB/PKCS5Padding';
      final iv = payload['iv']?.toString();
      return _desEncodeToBase64String(
            value: value,
            key: key,
            transformation: transformation,
            iv: iv,
          ) ??
          '';
    });

    runtime.onMessage(_channelRuleAccess, (dynamic args) {
      final payload = _asPayload(args);
      final action = payload['action']?.toString().trim().toLowerCase() ?? '';
      if (action.isEmpty) {
        return '';
      }

      if (action == 'set_content') {
        ruleState.content = payload['content']?.toString() ?? '';
        final baseUrl = payload['baseUrl']?.toString().trim();
        ruleState.baseUrl = baseUrl == null || baseUrl.isEmpty ? null : baseUrl;
        return '';
      }

      final expression = payload['rule']?.toString() ?? '';
      final values = _evaluateBridgeRule(
        content: ruleState.content,
        expression: expression,
        stage: context.stage ?? ErrorStage.search,
        baseUrl: ruleState.baseUrl,
        asUrl: _asNullableBool(payload['isUrl']) ?? false,
        sourceId: context.sourceId,
      );
      if (action == 'get_string') {
        return values.isEmpty ? '' : values.first;
      }
      if (action == 'get_string_list' || action == 'get_elements') {
        return values;
      }
      return '';
    });

    runtime.onMessage(_channelAes, (dynamic args) {
      final payload = _asPayload(args);
      final action = payload['action']?.toString().trim().toLowerCase() ?? '';
      if (action.isEmpty) {
        return '';
      }

      final value = payload['value'];
      final key = payload['key']?.toString() ?? '';
      final transformation =
          payload['transformation']?.toString() ?? 'AES/CBC/PKCS5Padding';
      final iv = payload['iv']?.toString();

      switch (action) {
        case 'decode_string':
          final output = _aesDecode(
            value: value,
            key: key,
            transformation: transformation,
            iv: iv,
            inputIsBase64: false,
          );
          if (output == null) {
            return '';
          }
          return utf8.decode(output, allowMalformed: true);
        case 'decode_bytes':
          final output = _aesDecode(
            value: value,
            key: key,
            transformation: transformation,
            iv: iv,
            inputIsBase64: false,
          );
          return output?.toList(growable: false) ?? const <int>[];
        case 'base64_decode_string':
          final output = _aesDecode(
            value: value,
            key: key,
            transformation: transformation,
            iv: iv,
            inputIsBase64: true,
          );
          if (output == null) {
            return '';
          }
          return utf8.decode(output, allowMalformed: true);
        case 'base64_decode_bytes':
          final output = _aesDecode(
            value: value,
            key: key,
            transformation: transformation,
            iv: iv,
            inputIsBase64: true,
          );
          return output?.toList(growable: false) ?? const <int>[];
        case 'encode_string':
          final output = _aesEncode(
            value: value,
            key: key,
            transformation: transformation,
            iv: iv,
          );
          if (output == null) {
            return '';
          }
          return latin1.decode(output, allowInvalid: true);
        case 'encode_bytes':
          final output = _aesEncode(
            value: value,
            key: key,
            transformation: transformation,
            iv: iv,
          );
          return output?.toList(growable: false) ?? const <int>[];
        case 'encode_base64_string':
          final output = _aesEncode(
            value: value,
            key: key,
            transformation: transformation,
            iv: iv,
          );
          if (output == null) {
            return '';
          }
          return base64Encode(output);
        case 'encode_base64_bytes':
          final output = _aesEncode(
            value: value,
            key: key,
            transformation: transformation,
            iv: iv,
          );
          if (output == null) {
            return const <int>[];
          }
          return utf8.encode(base64Encode(output));
      }
      return '';
    });

    runtime.onMessage(_channelNetworkCollect, (dynamic args) {
      if (onNetworkRequest == null) {
        return '';
      }

      final payload = _asPayload(args);
      final methodText =
          payload['method']?.toString().trim().toUpperCase() ?? 'GET';
      final method =
          methodText == 'POST' ? _JsNetworkMethod.post : _JsNetworkMethod.get;

      final normalizedUrl = _resolveNetworkUrl(
        payload['url']?.toString(),
        baseUrl: context.baseUrl,
      );
      if (normalizedUrl == null || normalizedUrl.isEmpty) {
        return '';
      }

      final body = _normalizeRequestBodyValue(payload['body']);
      final headers = _normalizeHeadersValue(payload['headers']);
      onNetworkRequest(
        _JsNetworkRequest(
          method: method,
          url: normalizedUrl,
          body: body,
          headers: headers,
          signature: _buildAjaxSignature(
            method: method.name.toUpperCase(),
            url: normalizedUrl,
            body: body,
            headers: headers,
          ),
          urlKey: _buildAjaxUrlKey(
            method: method.name.toUpperCase(),
            url: normalizedUrl,
          ),
        ),
      );
      return '';
    });
  }

  Future<Map<String, String>> _prefetchNetworkResponses({
    required String script,
    required JsExecutionContext context,
    required Map<String, String> bridgeVariables,
  }) async {
    if (!_containsNetworkBridgeInvocation(script)) {
      return const <String, String>{};
    }

    final cache = <String, String>{};
    final fetchedSignatures = <String>{};
    final staticRequests = _extractStaticNetworkRequests(script, context);
    var candidateCount = staticRequests.length;

    await _prefetchRequests(
      requests: staticRequests,
      context: context,
      cache: cache,
      fetchedSignatures: fetchedSignatures,
    );

    for (
      var round = 0;
      round < _maxNetworkProbeRounds &&
          fetchedSignatures.length < networkRequestLimit;
      round += 1
    ) {
      final dynamicRequests = await _collectProbeNetworkRequests(
        script: script,
        context: context,
        bridgeVariables: bridgeVariables,
        cache: cache,
      );
      if (dynamicRequests.isEmpty) {
        break;
      }

      candidateCount += dynamicRequests.length;
      final before = fetchedSignatures.length;
      await _prefetchRequests(
        requests: dynamicRequests,
        context: context,
        cache: cache,
        fetchedSignatures: fetchedSignatures,
      );
      if (fetchedSignatures.length == before) {
        break;
      }
    }

    if (candidateCount > networkRequestLimit &&
        fetchedSignatures.length >= networkRequestLimit) {
      _logger.warn(
        'JS bridge network call limit reached',
        context: <String, Object?>{
          'sourceId': context.sourceId,
          'stage': context.stage?.name,
          'maxCalls': networkRequestLimit,
          'actualCalls': candidateCount,
          'diagnostic': 'js_bridge_network_call_limit',
        },
      );
    }

    return cache;
  }

  Future<void> _prefetchRequests({
    required List<_JsNetworkRequest> requests,
    required JsExecutionContext context,
    required Map<String, String> cache,
    required Set<String> fetchedSignatures,
  }) async {
    for (final request in requests) {
      if (fetchedSignatures.length >= networkRequestLimit) {
        return;
      }
      if (fetchedSignatures.contains(request.signature)) {
        continue;
      }

      fetchedSignatures.add(request.signature);
      await _prefetchSingleRequest(
        request: request,
        context: context,
        cache: cache,
      );
    }
  }

  Future<void> _prefetchSingleRequest({
    required _JsNetworkRequest request,
    required JsExecutionContext context,
    required Map<String, String> cache,
  }) async {
    try {
      final response = await _httpClient.get(
        RequestContext(
          url: request.url,
          method:
              request.method == _JsNetworkMethod.post
                  ? HttpRequestMethod.post
                  : HttpRequestMethod.get,
          headers: request.headers,
          body: request.body.isEmpty ? null : request.body,
          connectTimeout: networkRequestTimeout,
          receiveTimeout: networkRequestTimeout,
          stage: context.stage ?? ErrorStage.search,
          sourceId: context.sourceId,
          sourceConcurrentRate:
              context.sourceJson?['concurrentRate']?.toString().trim(),
        ),
      );
      cache[request.signature] = response.body;
      cache[request.urlKey] = response.body;
    } catch (error) {
      _logger.warn(
        'JS bridge network prefetch failed',
        context: <String, Object?>{
          'sourceId': context.sourceId,
          'stage': context.stage?.name,
          'method': request.method.name.toUpperCase(),
          'url': request.url,
          'briefMessage': error.toString(),
          'diagnostic': 'js_bridge_network_failed',
        },
      );
    }
  }

  Future<List<_JsNetworkRequest>> _collectProbeNetworkRequests({
    required String script,
    required JsExecutionContext context,
    required Map<String, String> bridgeVariables,
    required Map<String, String> cache,
  }) async {
    final requests = <_JsNetworkRequest>[];
    JavascriptRuntime? runtime;
    try {
      runtime = _runtimeFactory();
      final probeVariables = <String, String>{...bridgeVariables};
      final probeRuleState = _JsRuleBridgeState(
        content: context.result ?? '',
        baseUrl: context.baseUrl,
      );
      _registerTier1Bridge(
        runtime,
        context: context,
        bridgeVariables: probeVariables,
        ruleState: probeRuleState,
        onNetworkRequest: requests.add,
      );
      _injectContext(
        runtime,
        context,
        bridgeVariables: probeVariables,
        ajaxCache: cache,
      );
      _injectJsLib(runtime, context);
      runtime.evaluate(script);
    } catch (_) {
      // Probe mode intentionally ignores script runtime errors.
    } finally {
      runtime?.dispose();
    }

    if (requests.isEmpty) {
      return const <_JsNetworkRequest>[];
    }

    final unique = <String, _JsNetworkRequest>{};
    for (final request in requests) {
      unique.putIfAbsent(request.signature, () => request);
    }
    return unique.values.toList(growable: false);
  }

  List<_JsNetworkRequest> _extractStaticNetworkRequests(
    String script,
    JsExecutionContext context,
  ) {
    final requests = <_JsNetworkRequest>[];
    final staticStrings = _extractStaticStringVariables(script);
    if (context.baseUrl?.trim().isNotEmpty == true) {
      staticStrings.putIfAbsent('baseUrl', () => context.baseUrl!.trim());
    }
    final callPattern = RegExp(
      r'java\.(ajax|get|post|connect|head|cacheFile|importScript)\s*\(',
    );
    for (final match in callPattern.allMatches(script)) {
      final methodText = match.group(1)?.trim().toLowerCase();
      if (methodText == null || methodText.isEmpty) {
        continue;
      }

      final method = _JsNetworkMethod.fromBridgeName(methodText);
      if (method == null) {
        continue;
      }

      final openParenIndex = match.end - 1;
      final argsText = _extractInvocationArguments(script, openParenIndex);
      if (argsText == null || argsText.trim().isEmpty) {
        continue;
      }

      final args = _splitTopLevelSegments(argsText, delimiter: ',');
      if (args.isEmpty) {
        continue;
      }

      final rawUrl = _resolveStaticStringExpression(
        args.first,
        variables: staticStrings,
      );
      if (rawUrl == null || rawUrl.trim().isEmpty) {
        continue;
      }
      if (method == _JsNetworkMethod.get &&
          args.length == 1 &&
          !_looksLikeNetworkUrlLiteral(rawUrl)) {
        continue;
      }
      final normalizedUrl = _resolveNetworkUrl(
        rawUrl,
        baseUrl: context.baseUrl,
      );
      if (normalizedUrl == null || normalizedUrl.isEmpty) {
        continue;
      }

      var body = '';
      Map<String, String> headers = const <String, String>{};

      if (method == _JsNetworkMethod.post) {
        if (args.length >= 2) {
          body = _normalizeRequestBodyValue(
            _resolveStaticJsonExpression(args[1], variables: staticStrings) ??
                _resolveStaticStringExpression(
                  args[1],
                  variables: staticStrings,
                ),
          );
        }
        if (args.length >= 3) {
          headers =
              _parseHeadersLiteral(args[2], variables: staticStrings) ??
              const <String, String>{};
        }
      } else if (args.length >= 2) {
        headers =
            _parseHeadersLiteral(args[1], variables: staticStrings) ??
            const <String, String>{};
      }

      final signature = _buildAjaxSignature(
        method: method.name.toUpperCase(),
        url: normalizedUrl,
        body: body,
        headers: headers,
      );
      final urlKey = _buildAjaxUrlKey(
        method: method.name.toUpperCase(),
        url: normalizedUrl,
      );
      requests.add(
        _JsNetworkRequest(
          method: method,
          url: normalizedUrl,
          body: body,
          headers: headers,
          signature: signature,
          urlKey: urlKey,
        ),
      );
    }

    return requests;
  }

  String? _extractInvocationArguments(String source, int openParenIndex) {
    if (openParenIndex < 0 ||
        openParenIndex >= source.length ||
        source[openParenIndex] != '(') {
      return null;
    }

    var depth = 0;
    String? quote;
    var escaped = false;
    final buffer = StringBuffer();
    for (var index = openParenIndex; index < source.length; index += 1) {
      final char = source[index];
      if (quote != null) {
        if (escaped) {
          escaped = false;
          if (depth >= 1) {
            buffer.write(char);
          }
          continue;
        }

        if (char == r'\') {
          escaped = true;
          if (depth >= 1) {
            buffer.write(char);
          }
          continue;
        }

        if (char == quote) {
          quote = null;
        }

        if (depth >= 1) {
          buffer.write(char);
        }
        continue;
      }

      if (char == '"' || char == "'") {
        quote = char;
        if (depth >= 1) {
          buffer.write(char);
        }
        continue;
      }

      if (char == '(') {
        depth += 1;
        if (depth > 1) {
          buffer.write(char);
        }
        continue;
      }

      if (char == ')') {
        depth -= 1;
        if (depth == 0) {
          return buffer.toString();
        }
        if (depth < 0) {
          return null;
        }
        buffer.write(char);
        continue;
      }

      if (depth >= 1) {
        buffer.write(char);
      }
    }
    return null;
  }

  List<String> _splitTopLevelSegments(
    String source, {
    required String delimiter,
  }) {
    final output = <String>[];
    if (source.trim().isEmpty) {
      return output;
    }

    final token = delimiter.trim();
    if (token.isEmpty) {
      return <String>[source.trim()];
    }

    var round = 0;
    var square = 0;
    var curly = 0;
    String? quote;
    var escaped = false;
    final buffer = StringBuffer();

    for (var index = 0; index < source.length; index += 1) {
      final char = source[index];

      if (quote != null) {
        buffer.write(char);
        if (escaped) {
          escaped = false;
          continue;
        }

        if (char == r'\') {
          escaped = true;
          continue;
        }

        if (char == quote) {
          quote = null;
        }
        continue;
      }

      if (char == '"' || char == "'") {
        quote = char;
        buffer.write(char);
        continue;
      }

      if (char == '(') {
        round += 1;
        buffer.write(char);
        continue;
      }
      if (char == ')') {
        round -= 1;
        buffer.write(char);
        continue;
      }
      if (char == '[') {
        square += 1;
        buffer.write(char);
        continue;
      }
      if (char == ']') {
        square -= 1;
        buffer.write(char);
        continue;
      }
      if (char == '{') {
        curly += 1;
        buffer.write(char);
        continue;
      }
      if (char == '}') {
        curly -= 1;
        buffer.write(char);
        continue;
      }

      final isTopLevel = round == 0 && square == 0 && curly == 0;
      if (isTopLevel &&
          token.length == 1 &&
          char == token &&
          buffer.isNotEmpty) {
        final segment = buffer.toString().trim();
        if (segment.isNotEmpty) {
          output.add(segment);
        }
        buffer.clear();
        continue;
      }

      buffer.write(char);
    }

    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) {
      output.add(tail);
    }

    return output;
  }

  String? _parseStringLiteral(String source) {
    final text = source.trim();
    if (text.length < 2) {
      return null;
    }

    final quote = text[0];
    if ((quote != '"' && quote != "'") || text[text.length - 1] != quote) {
      return null;
    }

    if (quote == '"') {
      try {
        final decoded = jsonDecode(text);
        return decoded is String ? decoded : null;
      } on FormatException {
        return null;
      }
    }

    return _decodeSingleQuotedString(text.substring(1, text.length - 1));
  }

  String _decodeSingleQuotedString(String source) {
    final buffer = StringBuffer();
    var escaped = false;
    for (var index = 0; index < source.length; index += 1) {
      final char = source[index];
      if (!escaped) {
        if (char == r'\') {
          escaped = true;
          continue;
        }
        buffer.write(char);
        continue;
      }

      escaped = false;
      switch (char) {
        case 'n':
          buffer.write('\n');
          break;
        case 'r':
          buffer.write('\r');
          break;
        case 't':
          buffer.write('\t');
          break;
        case r'\':
          buffer.write(r'\');
          break;
        case "'":
          buffer.write("'");
          break;
        case '"':
          buffer.write('"');
          break;
        default:
          buffer.write(char);
          break;
      }
    }
    return buffer.toString();
  }

  Map<String, String> _extractStaticStringVariables(String script) {
    final output = <String, String>{};
    final assignmentPattern = RegExp(
      r'\b(?:var|let|const)\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([^;]+);',
    );
    for (final match in assignmentPattern.allMatches(script)) {
      final name = (match.group(1) ?? '').trim();
      final expression = (match.group(2) ?? '').trim();
      if (name.isEmpty || expression.isEmpty) {
        continue;
      }
      final value = _resolveStaticStringExpression(
        expression,
        variables: output,
      );
      if (value == null || value.isEmpty) {
        continue;
      }
      output[name] = value;
    }
    return output;
  }

  String? _resolveStaticStringExpression(
    String source, {
    required Map<String, String> variables,
  }) {
    final text = source.trim();
    if (text.isEmpty) {
      return null;
    }

    final literal = _parseStringLiteral(text);
    if (literal != null) {
      return literal;
    }

    if (text.startsWith('`') &&
        text.endsWith('`') &&
        text.length >= 2 &&
        !text.contains(r'${')) {
      return text.substring(1, text.length - 1);
    }

    final direct = variables[text];
    if (direct != null) {
      return direct;
    }

    if (text.startsWith('(') && text.endsWith(')') && text.length > 2) {
      return _resolveStaticStringExpression(
        text.substring(1, text.length - 1),
        variables: variables,
      );
    }

    if (text.startsWith('String(') && text.endsWith(')')) {
      final inner = text.substring(7, text.length - 1);
      final primitive = _parsePrimitiveLiteral(inner);
      if (primitive != null) {
        return primitive.toString();
      }
      return _resolveStaticStringExpression(inner, variables: variables);
    }

    final terms = _splitTopLevelSegments(text, delimiter: '+');
    if (terms.length > 1) {
      final buffer = StringBuffer();
      for (final term in terms) {
        final part = _resolveStaticStringExpression(term, variables: variables);
        if (part == null) {
          return null;
        }
        buffer.write(part);
      }
      return buffer.toString();
    }

    final primitive = _parsePrimitiveLiteral(text);
    if (primitive != null) {
      return primitive.toString();
    }

    return null;
  }

  dynamic _resolveStaticJsonExpression(
    String source, {
    required Map<String, String> variables,
  }) {
    final text = source.trim();
    if (text.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(text);
    } catch (_) {
      // Fall through.
    }

    if (text.startsWith('{') && text.endsWith('}')) {
      return _parseStaticObjectLiteral(text, variables: variables);
    }
    if (text.startsWith('[') && text.endsWith(']')) {
      return _parseStaticListLiteral(text, variables: variables);
    }
    return null;
  }

  Map<String, dynamic>? _parseStaticObjectLiteral(
    String source, {
    required Map<String, String> variables,
  }) {
    final text = source.trim();
    if (!text.startsWith('{') || !text.endsWith('}')) {
      return null;
    }

    final inner = text.substring(1, text.length - 1).trim();
    if (inner.isEmpty) {
      return const <String, dynamic>{};
    }

    final output = <String, dynamic>{};
    final pairs = _splitTopLevelSegments(inner, delimiter: ',');
    for (final pair in pairs) {
      final separator = _indexOfTopLevelSymbol(pair, ':');
      if (separator <= 0) {
        return null;
      }
      final rawKey = pair.substring(0, separator).trim();
      final rawValue = pair.substring(separator + 1).trim();
      final key =
          _parseStringLiteral(rawKey) ??
          (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(rawKey)
              ? rawKey
              : null);
      if (key == null || key.isEmpty) {
        return null;
      }
      final value = _resolveStaticValueExpression(
        rawValue,
        variables: variables,
      );
      if (value == null && rawValue.trim().toLowerCase() != 'null') {
        return null;
      }
      output[key] = value;
    }

    return output;
  }

  List<dynamic>? _parseStaticListLiteral(
    String source, {
    required Map<String, String> variables,
  }) {
    final text = source.trim();
    if (!text.startsWith('[') || !text.endsWith(']')) {
      return null;
    }

    final inner = text.substring(1, text.length - 1).trim();
    if (inner.isEmpty) {
      return const <dynamic>[];
    }

    final output = <dynamic>[];
    final segments = _splitTopLevelSegments(inner, delimiter: ',');
    for (final segment in segments) {
      final value = _resolveStaticValueExpression(
        segment,
        variables: variables,
      );
      if (value == null && segment.trim().toLowerCase() != 'null') {
        return null;
      }
      output.add(value);
    }
    return output;
  }

  dynamic _resolveStaticValueExpression(
    String source, {
    required Map<String, String> variables,
  }) {
    final text = source.trim();
    if (text.isEmpty) {
      return null;
    }

    final stringLiteral = _parseStringLiteral(text);
    if (stringLiteral != null) {
      return stringLiteral;
    }

    final primitive = _parsePrimitiveLiteral(text);
    if (primitive != null || text.toLowerCase() == 'null') {
      return primitive;
    }

    final objectValue = _parseStaticObjectLiteral(text, variables: variables);
    if (objectValue != null) {
      return objectValue;
    }
    final listValue = _parseStaticListLiteral(text, variables: variables);
    if (listValue != null) {
      return listValue;
    }

    final directVariable = variables[text];
    if (directVariable != null) {
      return directVariable;
    }

    final stringValue = _resolveStaticStringExpression(
      text,
      variables: variables,
    );
    if (stringValue != null) {
      return stringValue;
    }

    return null;
  }

  dynamic _parsePrimitiveLiteral(String source) {
    final text = source.trim();
    if (text.isEmpty) {
      return null;
    }
    final normalized = text.toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
    if (normalized == 'null') {
      return null;
    }
    return num.tryParse(text);
  }

  Map<String, String>? _parseHeadersLiteral(
    String source, {
    Map<String, String> variables = const <String, String>{},
  }) {
    final text = source.trim();
    if (!text.startsWith('{') || !text.endsWith('}')) {
      return null;
    }

    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        return decoded.map(
          (key, value) =>
              MapEntry(key.toString(), value == null ? '' : value.toString()),
        );
      }
    } on FormatException {
      // Fall through to lightweight parser.
    }

    final inner = text.substring(1, text.length - 1).trim();
    if (inner.isEmpty) {
      return const <String, String>{};
    }

    final segments = _splitTopLevelSegments(inner, delimiter: ',');
    final output = <String, String>{};
    for (final segment in segments) {
      final separator = _indexOfTopLevelSymbol(segment, ':');
      if (separator <= 0) {
        return null;
      }
      final rawKey = segment.substring(0, separator).trim();
      final rawValue = segment.substring(separator + 1).trim();
      final key =
          _parseStringLiteral(rawKey) ??
          (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(rawKey)
              ? rawKey
              : null);
      if (key == null || key.isEmpty) {
        return null;
      }
      final value =
          _resolveStaticStringExpression(rawValue, variables: variables) ??
          _parsePrimitiveLiteral(rawValue)?.toString();
      if (value == null) {
        return null;
      }
      output[key] = value;
    }
    return output;
  }

  int _indexOfTopLevelSymbol(String source, String symbol) {
    if (symbol.length != 1) {
      return -1;
    }

    var round = 0;
    var square = 0;
    var curly = 0;
    String? quote;
    var escaped = false;

    for (var index = 0; index < source.length; index += 1) {
      final char = source[index];
      if (quote != null) {
        if (escaped) {
          escaped = false;
          continue;
        }
        if (char == r'\') {
          escaped = true;
          continue;
        }
        if (char == quote) {
          quote = null;
        }
        continue;
      }

      if (char == '"' || char == "'") {
        quote = char;
        continue;
      }
      if (char == '(') {
        round += 1;
        continue;
      }
      if (char == ')') {
        round -= 1;
        continue;
      }
      if (char == '[') {
        square += 1;
        continue;
      }
      if (char == ']') {
        square -= 1;
        continue;
      }
      if (char == '{') {
        curly += 1;
        continue;
      }
      if (char == '}') {
        curly -= 1;
        continue;
      }

      if (char == symbol && round == 0 && square == 0 && curly == 0) {
        return index;
      }
    }

    return -1;
  }

  String? _resolveNetworkUrl(String? source, {String? baseUrl}) {
    final text = source?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    final direct = Uri.tryParse(text);
    if (direct != null &&
        direct.hasScheme &&
        (direct.scheme == 'http' || direct.scheme == 'https')) {
      return direct.toString();
    }

    final base = baseUrl?.trim();
    if (base == null || base.isEmpty) {
      return null;
    }

    final baseUri = Uri.tryParse(base);
    if (baseUri == null || !baseUri.hasScheme || baseUri.host.isEmpty) {
      return null;
    }

    return baseUri.resolve(text).toString();
  }

  bool _looksLikeNetworkUrlLiteral(String source) {
    final text = source.trim().toLowerCase();
    return text.startsWith('http://') ||
        text.startsWith('https://') ||
        text.startsWith('/');
  }

  String _buildAjaxSignature({
    required String method,
    required String url,
    required String body,
    required Map<String, String> headers,
  }) {
    final normalizedMethod = method.trim().toUpperCase();
    final normalizedUrl = url.trim();
    final normalizedBody = body;
    final headerSignature = _buildHeadersSignature(headers);
    return '$normalizedMethod|$normalizedUrl|$normalizedBody|$headerSignature';
  }

  String _buildAjaxUrlKey({required String method, required String url}) {
    return '${method.trim().toUpperCase()}|${url.trim()}||';
  }

  String _buildHeadersSignature(Map<String, String> headers) {
    if (headers.isEmpty) {
      return '';
    }

    final entries = headers.entries
        .map((entry) => MapEntry(entry.key.trim().toLowerCase(), entry.value))
        .where((entry) => entry.key.isNotEmpty)
        .toList(growable: false)
      ..sort((left, right) => left.key.compareTo(right.key));

    return entries.map((entry) => '${entry.key}:${entry.value}').join('\n');
  }

  List<String> _evaluateBridgeRule({
    required String content,
    required String expression,
    required ErrorStage stage,
    required String? baseUrl,
    required bool asUrl,
    String? sourceId,
    int depth = 0,
  }) {
    if (depth >= _maxRuleBridgeRecursionDepth) {
      _logger.warn(
        'JS bridge rule recursion limit reached',
        context: <String, Object?>{
          'sourceId': sourceId,
          'stage': stage.name,
          'depth': depth,
          'diagnostic': 'js_rule_bridge_recursion_limit',
        },
      );
      return const <String>[];
    }

    final nestedValues = _evaluateNestedBridgeRuleInvocation(
      content: content,
      expression: expression,
      stage: stage,
      baseUrl: baseUrl,
      sourceId: sourceId,
      depth: depth,
    );
    if (nestedValues != null) {
      return nestedValues;
    }

    final normalizedExpression = _normalizeBridgeRuleExpression(
      expression: expression,
      content: content,
    );
    if (normalizedExpression == null) {
      return const <String>[];
    }

    List<String> values;
    try {
      final parsed = _ruleParser.parse(normalizedExpression);
      if (parsed is ParsedHtmlRule) {
        values = _htmlExecutor.execute(
          content: content,
          rule: parsed,
          stage: stage,
        );
      } else if (parsed is ParsedRegexRule) {
        values = _regexExecutor.execute(
          content: content,
          rule: parsed,
          stage: stage,
        );
      } else if (parsed is ParsedJsonRule) {
        values = _jsonExecutor.execute(
          content: content,
          rule: parsed,
          stage: stage,
        );
      } else if (parsed is ParsedJsRule) {
        final fallback = LegacyScriptRuleFallback.evaluateFieldValue(
          content: content,
          rawRule: '@js:${parsed.script}',
        );
        values = fallback == null ? const <String>[] : <String>[fallback];
      } else {
        values = const <String>[];
      }
    } catch (_) {
      final fallback = _evaluateBridgeRuleFallback(
        content: content,
        expression: expression,
      );
      values = fallback == null ? const <String>[] : <String>[fallback];
    }

    if (!asUrl || values.isEmpty) {
      return values;
    }

    return values
        .map((item) => _resolveNetworkUrl(item, baseUrl: baseUrl) ?? item)
        .toList(growable: false);
  }

  List<String>? _evaluateNestedBridgeRuleInvocation({
    required String content,
    required String expression,
    required ErrorStage stage,
    required String? baseUrl,
    required String? sourceId,
    required int depth,
  }) {
    final trimmed = expression.trim();
    final callMatch = RegExp(
      r'^java\.(getString|getStringList|getElements)\s*\(',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (callMatch == null) {
      return null;
    }

    final action = (callMatch.group(1) ?? '').trim().toLowerCase();
    if (action.isEmpty) {
      return const <String>[];
    }

    final openParenIndex = callMatch.end - 1;
    final argsText = _extractInvocationArguments(trimmed, openParenIndex);
    if (argsText == null) {
      return const <String>[];
    }

    final expectedLength = openParenIndex + argsText.length + 2;
    if (expectedLength > trimmed.length ||
        trimmed.substring(expectedLength).trim().isNotEmpty) {
      return const <String>[];
    }

    final args = _splitTopLevelSegments(argsText, delimiter: ',');
    if (args.isEmpty) {
      return const <String>[];
    }

    final nestedExpression =
        _resolveStaticStringExpression(args.first, variables: const {}) ??
        args.first.trim();
    if (nestedExpression.isEmpty) {
      return const <String>[];
    }

    var nestedAsUrl = false;
    if (args.length >= 2) {
      final rawFlag =
          _parsePrimitiveLiteral(args[1]) ??
          _resolveStaticStringExpression(args[1], variables: const {}) ??
          args[1].trim();
      nestedAsUrl = _asNullableBool(rawFlag) ?? false;
    }

    final values = _evaluateBridgeRule(
      content: content,
      expression: nestedExpression,
      stage: stage,
      baseUrl: baseUrl,
      asUrl: nestedAsUrl,
      sourceId: sourceId,
      depth: depth + 1,
    );
    if (action == 'getstring') {
      return values.isEmpty ? const <String>[] : <String>[values.first];
    }
    return values;
  }

  String? _normalizeBridgeRuleExpression({
    required String expression,
    required String content,
  }) {
    final text = expression.trim();
    if (text.isEmpty) {
      return null;
    }

    if (text.startsWith('@json:')) {
      final inner = text.substring(6).trim();
      return inner.isEmpty ? null : 'json:$inner';
    }

    if (text.startsWith('json:') ||
        text.startsWith('regex:') ||
        text.startsWith('html:') ||
        text.startsWith('@js:') ||
        text.contains('@js:')) {
      return text;
    }

    if (text.startsWith(r'$')) {
      return 'json:$text';
    }

    if (_looksLikeJsonStructuredContent(content)) {
      if (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(text)) {
        return 'json:\$.${text.trim()}';
      }
      return 'json:$text';
    }

    final htmlCandidate = LegacyRuleCompat.buildHtmlRuleCandidate(
      stage: text,
      fallbackExtractor: 'text',
    );
    return htmlCandidate;
  }

  String? _evaluateBridgeRuleFallback({
    required String content,
    required String expression,
  }) {
    final key = expression.trim();
    if (key.isEmpty) {
      return null;
    }

    final decoded = _tryDecodeJson(content);
    if (decoded is Map) {
      final direct = decoded[key];
      if (direct != null) {
        final normalized = direct.toString().trim();
        if (normalized.isNotEmpty) {
          return normalized;
        }
      }
    }

    return LegacyScriptRuleFallback.evaluateFieldValue(
      content: content,
      rawRule: '@js:$expression',
    );
  }

  bool _looksLikeJsonStructuredContent(String value) {
    final text = value.trimLeft();
    return text.startsWith('{') || text.startsWith('[');
  }

  dynamic _tryDecodeJson(String source) {
    try {
      return jsonDecode(source);
    } catch (_) {
      return null;
    }
  }

  Uint8List? _aesDecode({
    required dynamic value,
    required String key,
    required String transformation,
    required String? iv,
    required bool inputIsBase64,
  }) {
    final cipherBytes = _toCipherInputBytes(
      value: value,
      base64Encoded: inputIsBase64,
    );
    if (cipherBytes == null || cipherBytes.isEmpty) {
      return null;
    }

    return _aesCrypt(
      input: cipherBytes,
      key: key,
      transformation: transformation,
      iv: iv,
      encrypt: false,
    );
  }

  Uint8List? _aesEncode({
    required dynamic value,
    required String key,
    required String transformation,
    required String? iv,
  }) {
    final plainBytes = _toPlainInputBytes(value);
    if (plainBytes == null || plainBytes.isEmpty) {
      return null;
    }

    return _aesCrypt(
      input: plainBytes,
      key: key,
      transformation: transformation,
      iv: iv,
      encrypt: true,
    );
  }

  Uint8List? _aesCrypt({
    required Uint8List input,
    required String key,
    required String transformation,
    required String? iv,
    required bool encrypt,
  }) {
    final keyBytes = _normalizeAesKey(key);
    if (keyBytes == null) {
      return null;
    }

    final spec = _parseAesTransformation(transformation);
    final blockSize = 16;
    final useCbc = spec.mode == _AesMode.cbc;
    final ivBytes =
        useCbc ? _normalizeAesIv(iv ?? '', blockSize: blockSize) : null;
    if (useCbc && ivBytes == null) {
      return null;
    }

    final params =
        useCbc
            ? pointycastle.ParametersWithIV<pointycastle.KeyParameter>(
              pointycastle.KeyParameter(keyBytes),
              ivBytes!,
            )
            : pointycastle.KeyParameter(keyBytes);

    try {
      if (spec.padding == _AesPadding.pkcs7) {
        final paddedCipher = pointycastle.PaddedBlockCipherImpl(
          pointycastle.PKCS7Padding(),
          useCbc
              ? pointycastle.CBCBlockCipher(pointycastle.AESEngine())
              : pointycastle.ECBBlockCipher(pointycastle.AESEngine()),
        );
        paddedCipher.init(
          encrypt,
          pointycastle.PaddedBlockCipherParameters<
            pointycastle.CipherParameters?,
            pointycastle.CipherParameters?
          >(params, null),
        );
        return Uint8List.fromList(paddedCipher.process(input));
      }

      var workingInput = input;
      if (encrypt && spec.padding == _AesPadding.zero) {
        workingInput = _applyZeroPadding(input, blockSize: blockSize);
      }
      if (workingInput.isEmpty) {
        return Uint8List(0);
      }
      if (workingInput.lengthInBytes % blockSize != 0) {
        return null;
      }

      final blockCipher =
          useCbc
              ? pointycastle.CBCBlockCipher(pointycastle.AESEngine())
              : pointycastle.ECBBlockCipher(pointycastle.AESEngine());
      blockCipher.init(encrypt, params);
      final output = Uint8List(workingInput.lengthInBytes);
      for (
        var offset = 0;
        offset < workingInput.lengthInBytes;
        offset += blockSize
      ) {
        blockCipher.processBlock(workingInput, offset, output, offset);
      }
      if (!encrypt && spec.padding == _AesPadding.zero) {
        return _stripZeroPadding(output);
      }
      return output;
    } catch (_) {
      return null;
    }
  }

  Uint8List? _normalizeAesKey(String source) {
    final text = source.trim();
    if (text.isEmpty) {
      return null;
    }

    final raw = _decodeFlexibleAesBytes(text);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final targetLength =
        raw.lengthInBytes <= 16
            ? 16
            : raw.lengthInBytes <= 24
            ? 24
            : 32;
    final output = Uint8List(targetLength);
    final copyLength =
        raw.lengthInBytes < targetLength ? raw.lengthInBytes : targetLength;
    output.setRange(0, copyLength, raw);
    return output;
  }

  Uint8List? _normalizeAesIv(String source, {required int blockSize}) {
    final text = source.trim();
    if (text.isEmpty) {
      return Uint8List(blockSize);
    }

    final raw = _decodeFlexibleAesBytes(text);
    if (raw == null) {
      return null;
    }
    final output = Uint8List(blockSize);
    final copyLength =
        raw.lengthInBytes < blockSize ? raw.lengthInBytes : blockSize;
    output.setRange(0, copyLength, raw);
    return output;
  }

  _AesTransformation _parseAesTransformation(String source) {
    final normalized = source.trim().toUpperCase();
    if (normalized.isEmpty) {
      return const _AesTransformation(
        mode: _AesMode.cbc,
        padding: _AesPadding.pkcs7,
      );
    }

    var mode = _AesMode.cbc;
    var padding = _AesPadding.pkcs7;
    final segments = normalized.split('/');
    for (final rawSegment in segments) {
      final segment = rawSegment
          .replaceAll('_', '')
          .replaceAll('-', '')
          .replaceAll(' ', '');
      if (segment.isEmpty) {
        continue;
      }
      if (segment == 'ECB') {
        mode = _AesMode.ecb;
        continue;
      }
      if (segment == 'CBC') {
        mode = _AesMode.cbc;
        continue;
      }
      if (segment == 'NOPADDING') {
        padding = _AesPadding.none;
        continue;
      }
      if (segment == 'ZEROPADDING' ||
          segment == 'ZERO' ||
          segment == 'ZEROBYTEPADDING') {
        padding = _AesPadding.zero;
        continue;
      }
      if (segment == 'PKCS5PADDING' ||
          segment == 'PKCS7PADDING' ||
          segment == 'PKCS5' ||
          segment == 'PKCS7') {
        padding = _AesPadding.pkcs7;
      }
    }
    return _AesTransformation(mode: mode, padding: padding);
  }

  Uint8List? _decodeFlexibleAesBytes(String source) {
    final text = source.trim();
    if (text.isEmpty) {
      return null;
    }

    final hasHexPrefix = text.startsWith('0x') || text.startsWith('0X');
    final normalized = hasHexPrefix ? text.substring(2) : text;
    final looksLikeHex =
        normalized.length.isEven &&
        normalized.length >= 32 &&
        RegExp(r'^[0-9a-fA-F]+$').hasMatch(normalized);
    if ((hasHexPrefix || looksLikeHex) && normalized.isNotEmpty) {
      final bytes = Uint8List(normalized.length ~/ 2);
      for (var index = 0; index < normalized.length; index += 2) {
        final segment = normalized.substring(index, index + 2);
        final value = int.tryParse(segment, radix: 16);
        if (value == null) {
          return null;
        }
        bytes[index ~/ 2] = value;
      }
      return bytes;
    }

    return Uint8List.fromList(utf8.encode(text));
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

  Uint8List _stripZeroPadding(Uint8List input) {
    var end = input.lengthInBytes;
    while (end > 0 && input[end - 1] == 0) {
      end -= 1;
    }
    if (end == input.lengthInBytes) {
      return input;
    }
    return Uint8List.sublistView(input, 0, end);
  }

  Uint8List? _toPlainInputBytes(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is List) {
      final bytes = value
          .whereType<num>()
          .map((item) => item.toInt() & 0xFF)
          .toList(growable: false);
      return Uint8List.fromList(bytes);
    }

    final text = value.toString();
    return Uint8List.fromList(utf8.encode(text));
  }

  Uint8List? _toCipherInputBytes({
    required dynamic value,
    required bool base64Encoded,
  }) {
    if (value == null) {
      return null;
    }
    if (value is List) {
      final bytes = value
          .whereType<num>()
          .map((item) => item.toInt() & 0xFF)
          .toList(growable: false);
      return Uint8List.fromList(bytes);
    }

    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }

    if (!base64Encoded) {
      return Uint8List.fromList(latin1.encode(text));
    }

    return _decodeBase64Bytes(text);
  }

  bool? _asNullableBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return null;
  }

  String _normalizeRequestBodyValue(dynamic raw) {
    if (raw == null) {
      return '';
    }
    if (raw is String) {
      return raw;
    }
    if (raw is List<int>) {
      return utf8.decode(raw, allowMalformed: true);
    }
    if (raw is Map || raw is List) {
      try {
        return jsonEncode(raw);
      } catch (_) {
        return raw.toString();
      }
    }
    if (raw is num || raw is bool) {
      return raw.toString();
    }
    return raw.toString();
  }

  Map<String, String> _normalizeHeadersValue(dynamic raw) {
    if (raw == null) {
      return const <String, String>{};
    }

    if (raw is Map) {
      final output = <String, String>{};
      for (final entry in raw.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty) {
          continue;
        }
        output[key] = entry.value == null ? '' : entry.value.toString();
      }
      return output;
    }

    if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) {
        return const <String, String>{};
      }
      try {
        final decoded = jsonDecode(text);
        return _normalizeHeadersValue(decoded);
      } catch (_) {
        return const <String, String>{};
      }
    }

    return const <String, String>{};
  }

  Map<String, dynamic> _asPayload(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const <String, dynamic>{};
  }

  Uint8List? _decodeBase64Bytes(String source) {
    final text = source.trim();
    if (text.isEmpty) {
      return null;
    }
    final normalized = text.replaceAll('-', '+').replaceAll('_', '/');
    final padded = normalized.padRight(
      normalized.length + ((4 - normalized.length % 4) % 4),
      '=',
    );
    try {
      return base64Decode(padded);
    } on FormatException {
      return null;
    }
  }

  Uint8List? _decodeHexBytes(String source) {
    final text = source.trim();
    if (text.isEmpty) {
      return null;
    }
    final normalized = text.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (normalized.isEmpty || normalized.length.isOdd) {
      return null;
    }

    final bytes = Uint8List(normalized.length ~/ 2);
    for (var index = 0; index < normalized.length; index += 2) {
      final segment = normalized.substring(index, index + 2);
      final value = int.tryParse(segment, radix: 16);
      if (value == null) {
        return null;
      }
      bytes[index ~/ 2] = value;
    }
    return bytes;
  }

  String _encodeHexString(List<int> bytes) {
    final buffer = StringBuffer();
    for (final value in bytes) {
      buffer.write((value & 0xFF).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  String _digestHex({required String value, required String algorithm}) {
    final hash = _resolveHashAlgorithm(algorithm);
    if (hash == null) {
      return '';
    }
    return hash.convert(utf8.encode(value)).toString();
  }

  String _hmacDigest({
    required String value,
    required String algorithm,
    required String key,
    required String encoding,
  }) {
    final hash = _resolveHashAlgorithm(algorithm);
    if (hash == null) {
      return '';
    }
    final hmac = crypto.Hmac(hash, utf8.encode(key));
    final digest = hmac.convert(utf8.encode(value));
    final normalizedEncoding = encoding.trim().toLowerCase();
    if (normalizedEncoding == 'base64') {
      return base64Encode(digest.bytes);
    }
    return digest.toString();
  }

  crypto.Hash? _resolveHashAlgorithm(String algorithm) {
    final normalized = algorithm.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    return switch (normalized) {
      'MD5' || 'HMACMD5' => crypto.md5,
      'SHA1' || 'HSHA1' || 'HMACSHA1' => crypto.sha1,
      'SHA224' || 'HMACSHA224' => crypto.sha224,
      'SHA256' || 'HMACSHA256' => crypto.sha256,
      'SHA384' || 'HMACSHA384' => crypto.sha384,
      'SHA512' || 'HMACSHA512' => crypto.sha512,
      _ => null,
    };
  }

  String? _desEncodeToBase64String({
    required dynamic value,
    required String key,
    required String transformation,
    required String? iv,
  }) {
    final plainBytes = _toPlainInputBytes(value);
    if (plainBytes == null || plainBytes.isEmpty) {
      return null;
    }

    final cipherBytes = _desCrypt(
      input: plainBytes,
      key: key,
      transformation: transformation,
      iv: iv,
      encrypt: true,
    );
    if (cipherBytes == null) {
      return null;
    }
    return base64Encode(cipherBytes);
  }

  Uint8List? _desCrypt({
    required Uint8List input,
    required String key,
    required String transformation,
    required String? iv,
    required bool encrypt,
  }) {
    final keyBytes = _normalizeDesKey(key);
    if (keyBytes == null) {
      return null;
    }

    final spec = _parseDesTransformation(transformation);
    final blockSize = 8;
    final ivBytes =
        spec.mode == _DesMode.cbc
            ? _normalizeDesIv(iv ?? '', blockSize: blockSize)
            : null;
    if (spec.mode == _DesMode.cbc && ivBytes == null) {
      return null;
    }

    final params =
        spec.mode == _DesMode.cbc
            ? pointycastle.ParametersWithIV<pointycastle.KeyParameter>(
              pointycastle.KeyParameter(keyBytes),
              ivBytes!,
            )
            : pointycastle.KeyParameter(keyBytes);

    try {
      if (spec.padding == _DesPadding.pkcs7) {
        final paddedCipher = pointycastle.PaddedBlockCipherImpl(
          pointycastle.PKCS7Padding(),
          spec.mode == _DesMode.cbc
              ? pointycastle.CBCBlockCipher(pointycastle.DESedeEngine())
              : pointycastle.ECBBlockCipher(pointycastle.DESedeEngine()),
        );
        paddedCipher.init(
          encrypt,
          pointycastle.PaddedBlockCipherParameters<
            pointycastle.CipherParameters?,
            pointycastle.CipherParameters?
          >(params, null),
        );
        return Uint8List.fromList(paddedCipher.process(input));
      }

      if (input.lengthInBytes % blockSize != 0) {
        return null;
      }

      final blockCipher =
          spec.mode == _DesMode.cbc
              ? pointycastle.CBCBlockCipher(pointycastle.DESedeEngine())
              : pointycastle.ECBBlockCipher(pointycastle.DESedeEngine());
      blockCipher.init(encrypt, params);
      final output = Uint8List(input.lengthInBytes);
      for (var offset = 0; offset < input.lengthInBytes; offset += blockSize) {
        blockCipher.processBlock(input, offset, output, offset);
      }
      return output;
    } catch (_) {
      return null;
    }
  }

  Uint8List? _normalizeDesKey(String source) {
    final text = source.trim();
    if (text.isEmpty) {
      return null;
    }
    final raw = Uint8List(8);
    final sourceBytes = utf8.encode(text);
    final copyLength = sourceBytes.length < 8 ? sourceBytes.length : 8;
    raw.setRange(0, copyLength, sourceBytes);
    final output =
        Uint8List(24)
          ..setRange(0, 8, raw)
          ..setRange(8, 16, raw)
          ..setRange(16, 24, raw);
    return output;
  }

  Uint8List? _normalizeDesIv(String source, {required int blockSize}) {
    final text = source.trim();
    if (text.isEmpty) {
      return Uint8List(blockSize);
    }

    final raw = Uint8List.fromList(utf8.encode(text));
    final output = Uint8List(blockSize);
    final copyLength =
        raw.lengthInBytes < blockSize ? raw.lengthInBytes : blockSize;
    output.setRange(0, copyLength, raw);
    return output;
  }

  _DesTransformation _parseDesTransformation(String source) {
    final normalized = source.trim().toUpperCase();
    if (normalized.isEmpty) {
      return const _DesTransformation(
        mode: _DesMode.ecb,
        padding: _DesPadding.pkcs7,
      );
    }

    var mode = _DesMode.ecb;
    var padding = _DesPadding.pkcs7;
    for (final rawSegment in normalized.split('/')) {
      final segment = rawSegment
          .replaceAll('_', '')
          .replaceAll('-', '')
          .replaceAll(' ', '');
      if (segment.isEmpty) {
        continue;
      }
      if (segment == 'CBC') {
        mode = _DesMode.cbc;
        continue;
      }
      if (segment == 'ECB') {
        mode = _DesMode.ecb;
        continue;
      }
      if (segment == 'NOPADDING') {
        padding = _DesPadding.none;
        continue;
      }
      if (segment == 'PKCS5PADDING' ||
          segment == 'PKCS7PADDING' ||
          segment == 'PKCS5' ||
          segment == 'PKCS7') {
        padding = _DesPadding.pkcs7;
      }
    }
    return _DesTransformation(mode: mode, padding: padding);
  }

  DateTime? _parseTime(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is num) {
      return _fromEpoch(raw.toInt());
    }

    final text = raw.toString().trim();
    if (text.isEmpty) {
      return null;
    }

    final number = int.tryParse(text);
    if (number != null) {
      return _fromEpoch(number);
    }

    return DateTime.tryParse(text);
  }

  DateTime _fromEpoch(int raw) {
    final epochMillis = raw.abs() >= 1000000000000 ? raw : raw * 1000;
    return DateTime.fromMillisecondsSinceEpoch(epochMillis);
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    final year = local.year.toString().padLeft(4, '0');
    return '$year-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  String _formatTimeUtc(DateTime value) {
    final utc = value.toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    final year = utc.year.toString().padLeft(4, '0');
    return '$year-${two(utc.month)}-${two(utc.day)} '
        '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}';
  }

  int _toNumChapter(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return -1;
    }

    final digitMatch = RegExp(r'(\d{1,9})').firstMatch(text);
    if (digitMatch != null) {
      final parsed = int.tryParse(digitMatch.group(1)!);
      if (parsed != null) {
        return parsed;
      }
    }

    final chapterHint = RegExp(
      r'第([零〇○一二两三四五六七八九十百千万萬]+)[章节卷部篇回]',
    ).firstMatch(text);
    final chapterToken =
        chapterHint?.group(1) ??
        RegExp(r'[零〇○一二两三四五六七八九十百千万萬]+').firstMatch(text)?.group(0);
    if (chapterToken == null || chapterToken.isEmpty) {
      return -1;
    }

    final parsed = _parseChineseNumber(chapterToken);
    if (parsed == null || parsed <= 0) {
      return -1;
    }
    return parsed;
  }

  int? _parseChineseNumber(String source) {
    final digitMap = <String, int>{
      '零': 0,
      '〇': 0,
      '○': 0,
      '一': 1,
      '二': 2,
      '两': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
    };
    final unitMap = <String, int>{
      '十': 10,
      '百': 100,
      '千': 1000,
      '万': 10000,
      '萬': 10000,
    };

    var total = 0;
    var section = 0;
    var number = 0;
    for (final rune in source.runes) {
      final char = String.fromCharCode(rune);
      if (digitMap.containsKey(char)) {
        number = digitMap[char]!;
        continue;
      }
      final unit = unitMap[char];
      if (unit == null) {
        continue;
      }
      if (unit == 10000) {
        section += number;
        if (section == 0) {
          section = 1;
        }
        total += section * unit;
        section = 0;
        number = 0;
        continue;
      }
      final base = number == 0 ? 1 : number;
      section += base * unit;
      number = 0;
    }
    final value = total + section + number;
    return value == 0 ? null : value;
  }

  bool _containsNetworkBridgeInvocation(String script) {
    if (RegExp(
      r'java\.(ajax|ajaxAll|post|connect|head|cacheFile|importScript)\s*\(',
    ).hasMatch(script)) {
      return true;
    }

    final getPattern = RegExp(r'java\.get\s*\(');
    for (final match in getPattern.allMatches(script)) {
      final openParenIndex = match.end - 1;
      final argsText = _extractInvocationArguments(script, openParenIndex);
      if (argsText == null || argsText.trim().isEmpty) {
        continue;
      }
      final args = _splitTopLevelSegments(argsText, delimiter: ',');
      if (args.isEmpty) {
        continue;
      }
      if (args.length >= 2) {
        return true;
      }

      final raw = args.first.trim();
      final literal = _parseStringLiteral(raw);
      if (literal == null) {
        return true;
      }
      if (_looksLikeNetworkUrlLiteral(literal)) {
        return true;
      }
    }
    return false;
  }

  bool _looksLikelyInfiniteLoop(String script) {
    final compact = script.replaceAll(RegExp(r'\s+'), '');
    return compact.contains('while(true)') || compact.contains('for(;;)');
  }

  bool _containsPackagesInvocation(String script) {
    return RegExp(r'\bPackages\.', caseSensitive: false).hasMatch(script);
  }

  bool _looksLikeRuntimeErrorResult(String value) {
    final normalized = value.trimLeft();
    return normalized.startsWith('ERROR:') ||
        normalized.startsWith('TypeError:') ||
        normalized.startsWith('ReferenceError:') ||
        normalized.startsWith('SyntaxError:');
  }

  String? _firstUnsupportedBridgeCall(String script) {
    for (final match in RegExp(
      r'java\.([a-zA-Z_][a-zA-Z0-9_]*)\s*\(',
    ).allMatches(script)) {
      final call = (match.group(1) ?? '').trim();
      final normalized = call.toLowerCase();
      if (normalized.isEmpty || _supportedBridgeCalls.contains(normalized)) {
        continue;
      }
      return call;
    }
    return null;
  }

  String? _normalizeResult(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim();
    if (normalized.isEmpty ||
        normalized == 'undefined' ||
        normalized == 'null') {
      return null;
    }
    return normalized;
  }
}

enum _JsNetworkMethod {
  get,
  post;

  static _JsNetworkMethod? fromBridgeName(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      'ajax' => _JsNetworkMethod.get,
      'connect' => _JsNetworkMethod.get,
      'head' => _JsNetworkMethod.get,
      'cachefile' => _JsNetworkMethod.get,
      'importscript' => _JsNetworkMethod.get,
      'get' => _JsNetworkMethod.get,
      'post' => _JsNetworkMethod.post,
      _ => null,
    };
  }
}

class _JsNetworkRequest {
  const _JsNetworkRequest({
    required this.method,
    required this.url,
    required this.body,
    required this.headers,
    required this.signature,
    required this.urlKey,
  });

  final _JsNetworkMethod method;
  final String url;
  final String body;
  final Map<String, String> headers;
  final String signature;
  final String urlKey;
}

class _JsRuleBridgeState {
  _JsRuleBridgeState({required this.content, this.baseUrl});

  String content;
  String? baseUrl;
}

enum _AesMode { cbc, ecb }

enum _AesPadding { pkcs7, none, zero }

class _AesTransformation {
  const _AesTransformation({required this.mode, required this.padding});

  final _AesMode mode;
  final _AesPadding padding;
}

enum _DesMode { ecb, cbc }

enum _DesPadding { pkcs7, none }

class _DesTransformation {
  const _DesTransformation({required this.mode, required this.padding});

  final _DesMode mode;
  final _DesPadding padding;
}
