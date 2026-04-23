import 'dart:async';
import 'dart:convert';

import 'package:html/dom.dart' as dom;

import '../../src/js_runtime.dart';
import '../crypto/source_crypto.dart';
import '../cache/cache_manager.dart';
import '../browser/browser_runtime.dart';
import '../html/html_runtime.dart';
import '../http/http_models.dart';
import '../http/request_engine.dart';
import '../session/source_session.dart';
import '../../core/logging/app_logger.dart';
import '../../features/source/application/source_runtime_diagnostics_service.dart';
import 'source_contract.dart';
import 'source_manifest.dart';
import 'source_result_models.dart';

class SourceScriptCompileException implements Exception {
  const SourceScriptCompileException(this.message);

  final String message;

  @override
  String toString() => 'SourceScriptCompileException: $message';
}

class SourceScriptCompiler {
  const SourceScriptCompiler();

  static void debugResetSharedRunners() {}

  Future<RuntimeSourceDefinition> compile(String sourceCode) async {
    final normalizedSource = _normalizeSourceCode(sourceCode);
    final inspection = await _inspectSource(normalizedSource);
    final rawManifest = SourceManifest.fromMap(inspection.meta);
    final hasDiscoverMethods =
        inspection.hasDiscoverCategories && inspection.hasDiscoverBooks;
    final hasDiscoverMethodGap =
        inspection.hasDiscoverCategories != inspection.hasDiscoverBooks;
    if (hasDiscoverMethodGap) {
      throw const SourceScriptCompileException(
        'discoverCategories 与 discoverBooks 必须成对实现。',
      );
    }

    if (rawManifest.supportsCapability('discover') && !hasDiscoverMethods) {
      throw const SourceScriptCompileException(
        'meta.capabilities 声明了 discover，但书享源缺少 discoverCategories/discoverBooks 实现。',
      );
    }

    final manifest =
        hasDiscoverMethods && !rawManifest.supportsCapability('discover')
            ? rawManifest.copyWith(
              capabilities: <String>{...rawManifest.capabilities, 'discover'},
            )
            : rawManifest;

    if (!inspection.hasSearch ||
        !inspection.hasDetail ||
        !inspection.hasChapters ||
        !inspection.hasContent) {
      throw const SourceScriptCompileException(
        '书享源缺少必须方法，至少需要 search/detail/chapters/content。',
      );
    }

    final runner = _SourceScriptRunner(normalizedSource);

    return RuntimeSourceDefinition(
      manifest: manifest,
      init:
          inspection.hasInit
              ? (SourceRuntimeContext ctx, SourceTask task) async {
                await runner.runVoid(
                  methodName: 'init',
                  ctx: ctx,
                  args: <Object?>[_taskToMap(task)],
                );
              }
              : null,
      discoverCategories:
          inspection.hasDiscoverCategories
              ? (SourceRuntimeContext ctx) async {
                final result = await runner.run(
                  methodName: 'discoverCategories',
                  ctx: ctx,
                  args: const <Object?>[],
                );
                return _decodeDiscoverCategories(result);
              }
              : null,
      discoverBooks:
          inspection.hasDiscoverBooks
              ? (
                SourceRuntimeContext ctx,
                DiscoverCategory category,
                int page,
                int pageSize,
              ) async {
                final result = await runner.run(
                  methodName: 'discoverBooks',
                  ctx: ctx,
                  args: <Object?>[
                    _discoverCategoryToMap(category),
                    page,
                    pageSize,
                  ],
                );
                return _decodeDiscoverBooks(
                  result,
                  fallbackSourceId: ctx.source.id,
                );
              }
              : null,
      search: (SourceRuntimeContext ctx, String keyword) async {
        final result = await runner.run(
          methodName: 'search',
          ctx: ctx,
          args: <Object?>[keyword],
        );
        return _decodeBooks(result, fallbackSourceId: ctx.source.id);
      },
      detail: (SourceRuntimeContext ctx, Book book) async {
        final result = await runner.run(
          methodName: 'detail',
          ctx: ctx,
          args: <Object?>[_bookToMap(book)],
        );
        return _decodeBook(result, fallbackSourceId: ctx.source.id);
      },
      chapters: (SourceRuntimeContext ctx, Book book) async {
        final result = await runner.run(
          methodName: 'chapters',
          ctx: ctx,
          args: <Object?>[_bookToMap(book)],
        );
        return _decodeChapters(result, fallbackSourceId: ctx.source.id);
      },
      content: (SourceRuntimeContext ctx, Book book, Chapter chapter) async {
        final result = await runner.run(
          methodName: 'content',
          ctx: ctx,
          args: <Object?>[_bookToMap(book), _chapterToMap(chapter)],
        );
        return _decodeContent(result, fallbackSourceId: ctx.source.id);
      },
      dispose: runner.dispose,
    );
  }

  Future<_SourceInspection> _inspectSource(String normalizedSource) async {
    final runtime = createJsRuntimeAdapter();
    final logger = AppLogger.instance;
    if (!runtime.isSupported) {
      throw SourceScriptCompileException(
        runtime.unsupportedReason ?? '当前平台不支持 JS 书享源调试。',
      );
    }

    try {
      await runtime.installBootstrap(
        _sourceRuntimeBootstrap,
        sourceUrl: 'source_debugger_bootstrap.js',
      );
      await runtime.installBootstrap(
        normalizedSource,
        sourceUrl: 'pasted_source.js',
      );

      final result = await runtime.runSnippet('''
const __source = globalThis.__sourceDefinition;
const __inspection = {
  meta: __source?.meta ?? {},
  hasInit: typeof __source?.init === 'function',
  hasDiscoverCategories: typeof __source?.discoverCategories === 'function',
  hasDiscoverBooks: typeof __source?.discoverBooks === 'function',
  hasSearch: typeof __source?.search === 'function',
  hasDetail: typeof __source?.detail === 'function',
  hasChapters: typeof __source?.chapters === 'function',
  hasContent: typeof __source?.content === 'function',
};
return globalThis.__appreadEncodeHostSuccess(__inspection);
''');

      if (result.isError) {
        logger.warn(
          'Source inspection runtime error',
          context: <String, Object?>{
            'runtimeChain': 'source_script',
            'output': _truncateLogField(result.output),
          },
        );
        throw SourceScriptCompileException(result.output);
      }

      final envelope = _decodeRuntimeEnvelope(result.output);
      if (envelope != null) {
        if (!envelope.ok) {
          throw SourceScriptCompileException(envelope.error ?? '脚本执行失败。');
        }
        if (envelope.value is! Map<String, dynamic>) {
          logger.warn(
            'Source inspection decode failed',
            context: <String, Object?>{
              'runtimeChain': 'source_script',
              'decodedType': envelope.value.runtimeType.toString(),
              'output': _truncateLogField(result.output),
            },
          );
          throw const SourceScriptCompileException('无法读取书享源导出的 meta。');
        }
        return _SourceInspection.fromMap(
          envelope.value as Map<String, dynamic>,
        );
      }

      final decoded = _decodePossiblyNestedDynamic(result.output);
      if (decoded is! Map<String, dynamic>) {
        logger.warn(
          'Source inspection decode failed',
          context: <String, Object?>{
            'runtimeChain': 'source_script',
            'decodedType': decoded.runtimeType.toString(),
            'output': _truncateLogField(result.output),
          },
        );
        throw const SourceScriptCompileException('无法读取书享源导出的 meta。');
      }

      return _SourceInspection.fromMap(decoded);
    } finally {
      runtime.dispose();
    }
  }
}

String _truncateLogField(String value, {int maxLength = 480}) {
  final normalized = value.replaceAll('\n', r'\n');
  if (normalized.length <= maxLength) {
    return normalized;
  }
  return '${normalized.substring(0, maxLength)}...';
}

enum SourceScriptDebugLogLevel { info, warn, error }

class SourceScriptDebugLogEntry {
  const SourceScriptDebugLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });

  final DateTime timestamp;
  final SourceScriptDebugLogLevel level;
  final String message;
}

class SourceScriptDebugRunResult {
  const SourceScriptDebugRunResult({
    required this.logs,
    required this.result,
    required this.debugTraces,
    this.errorText,
  });

  final List<SourceScriptDebugLogEntry> logs;
  final Object? result;
  final List<Map<String, Object?>> debugTraces;
  final String? errorText;

  bool get isError => errorText != null;
}

class SourceScriptDebugService {
  SourceScriptDebugService({
    RequestEngine? requestEngine,
    CacheManager? cacheManager,
    BrowserRuntime? browserRuntime,
    HtmlRuntime? htmlRuntime,
  }) : _requestEngine = requestEngine ?? HttpPackageRequestEngine(),
       _cacheManager = cacheManager ?? InMemoryCacheManager(),
       _browserRuntime = browserRuntime ?? const UnsupportedBrowserRuntime(),
       _htmlRuntime = htmlRuntime ?? const DefaultHtmlRuntime();

  final RequestEngine _requestEngine;
  final CacheManager _cacheManager;
  final BrowserRuntime _browserRuntime;
  final HtmlRuntime _htmlRuntime;

  Future<SourceScriptDebugRunResult> evaluate({
    required String sourceCode,
    required String command,
    required SourceSession session,
    String runtimeId = '__script_debug__',
  }) async {
    final logs = <SourceScriptDebugLogEntry>[];
    final trimmedCommand = command.trim();
    if (trimmedCommand.isEmpty) {
      return SourceScriptDebugRunResult(
        logs: const <SourceScriptDebugLogEntry>[],
        result: null,
        debugTraces: _readDebugTraces(session),
        errorText: '调试命令不能为空。',
      );
    }

    final runner = _SourceScriptRunner(
      _buildDebugWrappedSource(sourceCode, trimmedCommand),
    );
    final context = SourceRuntimeContext(
      source: const SourceRuntimeInfo(
        id: '__script_debug__',
        name: '书享源调试',
        group: '调试',
        revision: 'debug',
      ),
      http: SourceHttpContext(
        requestEngine: _requestEngine,
        session: session,
        manifest: const SourceManifest(
          name: '书享源调试',
          group: '调试',
          author: 'debugger',
          description: '',
        ),
        browserRuntime: _browserRuntime,
      ),
      browser: SourceBrowserContext(
        browserRuntime: _browserRuntime,
        session: session,
      ),
      cookie: SourceCookieContext(session: session),
      cache: SourceCacheContext(
        cacheStore: CacheStoreContext(cacheManager: _cacheManager),
        sourceId: runtimeId,
      ),
      html: _htmlRuntime,
      session: session,
      utils: SourceUtilsContext(),
      crypto: SourceCryptoContext(),
      log: (String message) {
        appendDebugLog(session, message: message);
        logs.add(
          SourceScriptDebugLogEntry(
            timestamp: DateTime.now(),
            level: SourceScriptDebugLogLevel.info,
            message: message,
          ),
        );
      },
    );

    try {
      final result = await runner.run(
        methodName: '__debug',
        ctx: context,
        args: const <Object?>[],
      );
      return SourceScriptDebugRunResult(
        logs: List<SourceScriptDebugLogEntry>.unmodifiable(logs),
        result: result,
        debugTraces: _readDebugTraces(session),
      );
    } catch (error) {
      return SourceScriptDebugRunResult(
        logs: List<SourceScriptDebugLogEntry>.unmodifiable(logs),
        result: null,
        debugTraces: _readDebugTraces(session),
        errorText: error.toString(),
      );
    }
  }

  String _buildDebugWrappedSource(String sourceCode, String command) {
    final normalizedSource = _normalizeSourceCode(sourceCode);
    return '''
$normalizedSource
;(() => {
  const __safeStringify =
      globalThis.__appreadSafeStringify ||
      ((value) => {
        if (typeof value === 'string') {
          return value;
        }
        try {
          return JSON.stringify(value, null, 2);
        } catch (_) {
          return '[non-serializable value]';
        }
      });

  const __formatDebugValue = (value) => {
    return __safeStringify(value);
  };

  const __source = globalThis.__sourceDefinition || {};
  __source.__debug = async function(ctx) {
    const source = __source;
    const __previousConsole = globalThis.console;
    const __send = (level, args) => {
      const prefix = level === 'info' ? '' : '[' + level + '] ';
      return ctx.log(prefix + Array.from(args).map(__formatDebugValue).join(' '));
    };
    globalThis.console = {
      log: function() { return __send('info', arguments); },
      info: function() { return __send('info', arguments); },
      warn: function() { return __send('warn', arguments); },
      error: function() { return __send('error', arguments); },
    };
    try {
$command
    } finally {
      globalThis.console = __previousConsole;
    }
  };
  globalThis.__sourceDefinition = __source;
})();
''';
  }

  List<Map<String, Object?>> _readDebugTraces(SourceSession session) {
    return readDebugTraces(session);
  }
}

class _SourceScriptRunner {
  _SourceScriptRunner(this._normalizedSource);

  final String _normalizedSource;
  final SourceRuntimeDiagnosticsService _diagnosticsService =
      SourceRuntimeDiagnosticsService.instance;
  final AppLogger _logger = AppLogger.instance;
  JsRuntimeAdapter? _runtime;
  Future<void> _runQueue = Future<void>.value();
  bool _bootstrapsInstalled = false;

  Future<Object?> run({
    required String methodName,
    required SourceRuntimeContext ctx,
    required List<Object?> args,
  }) async {
    final completer = Completer<Object?>();
    _runQueue = _runQueue.catchError((_) {}).then((_) async {
      final runtime = await _ensureRuntime();
      final htmlHandleStore = _HtmlHandleStore();
      _registerBridges(runtime, ctx, htmlHandleStore);
      final marker = await _diagnosticsService.markInvocationStarted(
        sourceId: ctx.source.id,
        sourceName: ctx.source.name,
        methodName: methodName,
        runtimeChain: 'source_script',
        metadata: <String, Object?>{
          'sourceGroup': ctx.source.group,
          'argSummary': _buildArgSummary(methodName: methodName, args: args),
        },
      );

      try {
        final result = await runtime.runSnippet('''
const __ctx = globalThis.__createSourceCtx(${jsonEncode(_sourceInfoToMap(ctx.source))});
const __source = globalThis.__sourceDefinition;
ctx = __ctx;
source = __source;
globalThis.ctx = __ctx;
globalThis.source = __source;
const __args = ${jsonEncode(args)};
const __fn = __source?.['$methodName'];
if (typeof __fn !== 'function') {
  return globalThis.__appreadEncodeHostSuccess(null, '$methodName');
}
try {
  const __rawResult = await __fn.apply(__source, [__ctx, ...__args]);
  return globalThis.__appreadEncodeHostSuccess(__rawResult, '$methodName');
} catch (error) {
  return globalThis.__appreadEncodeHostFailure(error);
} finally {
  ctx = undefined;
  source = undefined;
  globalThis.ctx = undefined;
  globalThis.source = undefined;
}
''');

        if (result.isError) {
          throw SourceScriptCompileException(result.output);
        }

        final envelope = _decodeRuntimeEnvelope(result.output);
        if (envelope != null) {
          if (!envelope.ok) {
            throw SourceScriptCompileException(envelope.error ?? '脚本执行失败。');
          }
          if (envelope.stats.hasMutations) {
            _logger.warn(
              'Sanitized script runtime result',
              context: <String, Object?>{
                'sourceId': ctx.source.id,
                'sourceName': ctx.source.name,
                'methodName': methodName,
                'runtimeChain': 'source_script',
                'droppedValues': envelope.stats.droppedValues,
                'circularRefs': envelope.stats.circularRefs,
                'maxDepthHits': envelope.stats.maxDepthHits,
                'trimmedArrays': envelope.stats.trimmedArrays,
                'trimmedObjects': envelope.stats.trimmedObjects,
              },
            );
          }
          completer.complete(envelope.value);
        } else {
          completer.complete(_decodePossiblyNestedDynamic(result.output));
        }
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        await _diagnosticsService.markInvocationFinished(marker.invocationId);
      }
    });
    return completer.future;
  }

  String _buildArgSummary({
    required String methodName,
    required List<Object?> args,
  }) {
    if (args.isEmpty) {
      return methodName;
    }
    final firstArg = args.first;
    if (firstArg is String) {
      final normalized = firstArg.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (normalized.isEmpty) {
        return methodName;
      }
      if (normalized.length <= 80) {
        return '$methodName:$normalized';
      }
      return '$methodName:${normalized.substring(0, 80)}...';
    }
    if (firstArg is Map<String, Object?>) {
      final title = firstArg['title']?.toString().trim();
      final url = firstArg['detailUrl']?.toString().trim();
      final chapterUrl = firstArg['url']?.toString().trim();
      final parts = <String>[
        if (title != null && title.isNotEmpty) 'title=$title',
        if (url != null && url.isNotEmpty) 'detailUrl=$url',
        if (chapterUrl != null && chapterUrl.isNotEmpty) 'url=$chapterUrl',
      ];
      if (parts.isNotEmpty) {
        return '$methodName:${parts.join(',')}';
      }
    }
    return methodName;
  }

  Future<JsRuntimeAdapter> _ensureRuntime() async {
    final existing = _runtime;
    if (existing != null) {
      return existing;
    }

    final runtime = createJsRuntimeAdapter();
    if (!runtime.isSupported) {
      throw SourceScriptCompileException(
        runtime.unsupportedReason ?? '当前平台不支持 JS 书享源调试。',
      );
    }

    _runtime = runtime;
    if (!_bootstrapsInstalled) {
      await runtime.installBootstrap(
        _sourceRuntimeBootstrap,
        sourceUrl: 'source_debugger_bootstrap.js',
      );
      await runtime.installBootstrap(
        _normalizedSource,
        sourceUrl: 'pasted_source.js',
      );
      _bootstrapsInstalled = true;
    }
    return runtime;
  }

  void _registerBridges(
    JsRuntimeAdapter runtime,
    SourceRuntimeContext ctx,
    _HtmlHandleStore htmlHandleStore,
  ) {
    runtime.registerBridge('__ctx_log', (dynamic args) {
      final payload = _asMap(args);
      ctx.log(payload['message']?.toString() ?? '');
      return <String, Object?>{'ok': true};
    });
    runtime.registerBridge('__ctx_session_get', (dynamic args) {
      final payload = _asMap(args);
      return ctx.session.get<Object?>(payload['key']?.toString() ?? '');
    });
    runtime.registerBridge('__ctx_session_set', (dynamic args) {
      final payload = _asMap(args);
      final key = payload['key']?.toString() ?? '';
      ctx.session.set(key, payload['value']);
      return <String, Object?>{'ok': true};
    });
    runtime.registerBridge('__ctx_session_clear', (dynamic args) {
      final payload = _asMap(args);
      final key = payload['key']?.toString();
      ctx.session.clear(key);
      return <String, Object?>{'ok': true};
    });
    runtime.registerBridge('__ctx_session_cookies', (_) => ctx.session.cookies);
    runtime.registerBridge('__ctx_cookie_get', (dynamic args) {
      final payload = _asMap(args);
      return ctx.cookie.get(payload['name']?.toString() ?? '');
    });
    runtime.registerBridge('__ctx_cookie_get_all', (_) {
      return ctx.cookie.getAll();
    });
    runtime.registerBridge('__ctx_cookie_get_for_url', (dynamic args) {
      final payload = _asMap(args);
      return ctx.cookie.getForUrl(
        payload['url']?.toString() ?? '',
        payload['name']?.toString(),
      );
    });
    runtime.registerBridge('__ctx_cookie_set', (dynamic args) {
      final payload = _asMap(args);
      ctx.cookie.set(
        payload['name']?.toString() ?? '',
        payload['value']?.toString() ?? '',
      );
      return <String, Object?>{'ok': true};
    });
    runtime.registerBridge('__ctx_cookie_remove', (dynamic args) {
      final payload = _asMap(args);
      ctx.cookie.remove(payload['name']?.toString() ?? '');
      return <String, Object?>{'ok': true};
    });
    runtime.registerBridge('__ctx_cookie_clear_domain', (dynamic args) {
      final payload = _asMap(args);
      ctx.cookie.clearDomain(payload['domain']?.toString() ?? '');
      return <String, Object?>{'ok': true};
    });
    runtime.registerBridge('__ctx_cache_get', (dynamic args) {
      final payload = _asMap(args);
      return ctx.cache.get<Object?>(payload['key']?.toString() ?? '');
    });
    runtime.registerBridge('__ctx_cache_set', (dynamic args) {
      final payload = _asMap(args);
      ctx.cache.set(payload['key']?.toString() ?? '', payload['value']);
      return <String, Object?>{'ok': true};
    });
    runtime.registerBridge('__ctx_cache_remove', (dynamic args) {
      final payload = _asMap(args);
      ctx.cache.remove(payload['key']?.toString() ?? '');
      return <String, Object?>{'ok': true};
    });
    runtime.registerBridge('__ctx_cache_clear_prefix', (dynamic args) {
      final payload = _asMap(args);
      ctx.cache.clearPrefix(payload['prefix']?.toString() ?? '');
      return <String, Object?>{'ok': true};
    });
    runtime.registerBridge('__ctx_http_request', (dynamic args) async {
      final payload = _asMap(args);
      final options = _asMap(payload['options']);
      final response = await ctx.http.request(_requestFromMap(options));
      return response.toJson();
    });
    runtime.registerBridge('__ctx_http_is_html', (dynamic args) {
      final payload = _asMap(args);
      return ctx.http.isHtml(_responseFromMap(_asMap(payload['response'])));
    });
    runtime.registerBridge('__ctx_http_is_json', (dynamic args) {
      final payload = _asMap(args);
      return ctx.http.isJson(_responseFromMap(_asMap(payload['response'])));
    });
    runtime.registerBridge('__ctx_http_is_redirect', (dynamic args) {
      final payload = _asMap(args);
      return ctx.http.isRedirect(_responseFromMap(_asMap(payload['response'])));
    });
    runtime.registerBridge('__ctx_http_is_challenge', (dynamic args) {
      final payload = _asMap(args);
      return ctx.http.isChallenge(
        _responseFromMap(_asMap(payload['response'])),
      );
    });
    runtime.registerBridge('__ctx_html_parse', (dynamic args) {
      final payload = _asMap(args);
      final html = payload['html']?.toString() ?? '';
      final document = ctx.html.parse(html);
      return htmlHandleStore.store(document);
    });
    runtime.registerBridge('__ctx_html_query_selector', (dynamic args) {
      final payload = _asMap(args);
      final handle = _readInt(payload['handle']);
      final selector = payload['selector']?.toString() ?? '';
      final node = htmlHandleStore.get(handle);
      final selected = _querySelector(node, selector);
      return selected == null ? null : htmlHandleStore.store(selected);
    });
    runtime.registerBridge('__ctx_html_query_selector_all', (dynamic args) {
      final payload = _asMap(args);
      final handle = _readInt(payload['handle']);
      final selector = payload['selector']?.toString() ?? '';
      final node = htmlHandleStore.get(handle);
      final selected = _querySelectorAll(node, selector);
      return selected.map(htmlHandleStore.store).toList(growable: false);
    });
    runtime.registerBridge('__ctx_html_text', (dynamic args) {
      final payload = _asMap(args);
      final handle = _readInt(payload['handle']);
      return ctx.html.text(htmlHandleStore.get(handle));
    });
    runtime.registerBridge('__ctx_html_inner_html', (dynamic args) {
      final payload = _asMap(args);
      final handle = _readInt(payload['handle']);
      final node = htmlHandleStore.get(handle);
      return node is dom.Element ? ctx.html.innerHtml(node) : '';
    });
    runtime.registerBridge('__ctx_html_attr', (dynamic args) {
      final payload = _asMap(args);
      final handle = _readInt(payload['handle']);
      final name = payload['name']?.toString() ?? '';
      final node = htmlHandleStore.get(handle);
      return node is dom.Element ? ctx.html.attr(node, name) : '';
    });
    runtime.registerBridge('__ctx_browser_challenge', (dynamic args) async {
      final payload = _asMap(args);
      final options = _asMap(payload['options']);
      await ctx.browser.challenge(_challengeRequestFromMap(options));
      return <String, Object?>{'ok': true};
    });
    runtime.registerBridge('__ctx_browser_open', (dynamic args) async {
      final payload = _asMap(args);
      final options = _asMap(payload['options']);
      await ctx.browser.open(_openRequestFromMap(options));
      return <String, Object?>{'ok': true};
    });
    runtime.registerBridge('__ctx_browser_wait_for_url', (dynamic args) async {
      final payload = _asMap(args);
      final options = _asMap(payload['options']);
      await ctx.browser.waitForUrl(
        urlIncludes: options['urlIncludes']?.toString() ?? '',
        timeout: Duration(
          milliseconds: _readInt(options['timeoutMs'], fallback: 120000)!,
        ),
        url: _readUri(options['url']),
        reason: options['reason']?.toString() ?? 'wait_for_url',
      );
      return <String, Object?>{'ok': true};
    });
    runtime.registerBridge('__ctx_browser_wait_for_text', (dynamic args) async {
      final payload = _asMap(args);
      final options = _asMap(payload['options']);
      await ctx.browser.waitForText(
        textIncludes: options['textIncludes']?.toString() ?? '',
        timeout: Duration(
          milliseconds: _readInt(options['timeoutMs'], fallback: 120000)!,
        ),
        url: _readUri(options['url']),
        reason: options['reason']?.toString() ?? 'wait_for_text',
      );
      return <String, Object?>{'ok': true};
    });
    runtime.registerBridge('__ctx_browser_eval', (dynamic args) async {
      final payload = _asMap(args);
      final options = _asMap(payload['options']);
      return await ctx.browser.eval(_evalRequestFromMap(options));
    });
    runtime.registerBridge('__ctx_browser_get_cookies', (_) {
      return ctx.browser.getCookies();
    });
    runtime.registerBridge('__ctx_browser_get_current_url', (_) {
      return ctx.browser.getCurrentUrl();
    });
    runtime.registerBridge('__ctx_browser_get_html', (_) {
      return ctx.browser.getHtml();
    });
    runtime.registerBridge('__ctx_browser_get_storage', (_) {
      return ctx.browser.getStorage();
    });
    runtime.registerBridge('__ctx_utils_absolute_url', (dynamic args) {
      final payload = _asMap(args);
      return ctx.utils.absoluteUrl(
        payload['base']?.toString() ?? '',
        payload['relative']?.toString() ?? '',
      );
    });
    runtime.registerBridge('__ctx_utils_sleep', (dynamic args) async {
      final payload = _asMap(args);
      await ctx.utils.sleep(
        Duration(milliseconds: _readInt(payload['ms'], fallback: 0)!),
      );
      return <String, Object?>{'ok': true};
    });
    runtime.registerBridge('__ctx_utils_normalize_text', (dynamic args) {
      final payload = _asMap(args);
      return ctx.utils.normalizeText(payload['value']?.toString());
    });
    runtime.registerBridge('__ctx_utils_html_format', (dynamic args) {
      final payload = _asMap(args);
      return ctx.utils.htmlFormat(payload['value']?.toString());
    });
    runtime.registerBridge('__ctx_utils_time_format', (dynamic args) {
      final payload = _asMap(args);
      return ctx.utils.timeFormat(
        payload['value'],
        pattern: payload['pattern']?.toString() ?? 'yyyy-MM-dd HH:mm:ss',
      );
    });
    runtime.registerBridge('__ctx_utils_base64_encode', (dynamic args) {
      final payload = _asMap(args);
      return ctx.utils.base64Encode(payload['value']?.toString());
    });
    runtime.registerBridge('__ctx_utils_base64_decode', (dynamic args) {
      final payload = _asMap(args);
      return ctx.utils.base64Decode(payload['value']?.toString());
    });
    runtime.registerBridge('__ctx_utils_hex_encode', (dynamic args) {
      final payload = _asMap(args);
      return ctx.utils.hexEncode(payload['value']?.toString());
    });
    runtime.registerBridge('__ctx_utils_hex_decode', (dynamic args) {
      final payload = _asMap(args);
      return ctx.utils.hexDecode(payload['value']?.toString());
    });
    runtime.registerBridge('__ctx_utils_encode_uri', (dynamic args) {
      final payload = _asMap(args);
      return ctx.utils.encodeUri(payload['value']?.toString());
    });
    runtime.registerBridge('__ctx_utils_decode_uri', (dynamic args) {
      final payload = _asMap(args);
      return ctx.utils.decodeUri(payload['value']?.toString());
    });
    runtime.registerBridge('__ctx_utils_encode_uri_component', (dynamic args) {
      final payload = _asMap(args);
      return ctx.utils.encodeUriComponent(payload['value']?.toString());
    });
    runtime.registerBridge('__ctx_utils_decode_uri_component', (dynamic args) {
      final payload = _asMap(args);
      return ctx.utils.decodeUriComponent(payload['value']?.toString());
    });
    runtime.registerBridge('__ctx_utils_get_device_info', (_) async {
      return await ctx.utils.getDeviceInfo();
    });
    runtime.registerBridge('__ctx_utils_get_user_id', (_) async {
      return await ctx.utils.getUserId();
    });
    runtime.registerBridge('__ctx_crypto_md5', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.md5(
        payload['value']?.toString(),
        inputEncoding: payload['inputEncoding']?.toString() ?? 'utf8',
        outputEncoding: payload['outputEncoding']?.toString() ?? 'hex',
      );
    });
    runtime.registerBridge('__ctx_crypto_sha1', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.sha1(
        payload['value']?.toString(),
        inputEncoding: payload['inputEncoding']?.toString() ?? 'utf8',
        outputEncoding: payload['outputEncoding']?.toString() ?? 'hex',
      );
    });
    runtime.registerBridge('__ctx_crypto_sha256', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.sha256(
        payload['value']?.toString(),
        inputEncoding: payload['inputEncoding']?.toString() ?? 'utf8',
        outputEncoding: payload['outputEncoding']?.toString() ?? 'hex',
      );
    });
    runtime.registerBridge('__ctx_crypto_sha512', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.sha512(
        payload['value']?.toString(),
        inputEncoding: payload['inputEncoding']?.toString() ?? 'utf8',
        outputEncoding: payload['outputEncoding']?.toString() ?? 'hex',
      );
    });
    runtime.registerBridge('__ctx_crypto_sm3', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.sm3(
        payload['value']?.toString(),
        inputEncoding: payload['inputEncoding']?.toString() ?? 'utf8',
        outputEncoding: payload['outputEncoding']?.toString() ?? 'hex',
      );
    });
    runtime.registerBridge('__ctx_crypto_hmac_sha1', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.hmacSha1(
        payload['value']?.toString(),
        payload['key']?.toString(),
        inputEncoding: payload['inputEncoding']?.toString() ?? 'utf8',
        keyEncoding: payload['keyEncoding']?.toString() ?? 'utf8',
        outputEncoding: payload['outputEncoding']?.toString() ?? 'hex',
      );
    });
    runtime.registerBridge('__ctx_crypto_hmac_sha256', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.hmacSha256(
        payload['value']?.toString(),
        payload['key']?.toString(),
        inputEncoding: payload['inputEncoding']?.toString() ?? 'utf8',
        keyEncoding: payload['keyEncoding']?.toString() ?? 'utf8',
        outputEncoding: payload['outputEncoding']?.toString() ?? 'hex',
      );
    });
    runtime.registerBridge('__ctx_crypto_hmac_sha512', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.hmacSha512(
        payload['value']?.toString(),
        payload['key']?.toString(),
        inputEncoding: payload['inputEncoding']?.toString() ?? 'utf8',
        keyEncoding: payload['keyEncoding']?.toString() ?? 'utf8',
        outputEncoding: payload['outputEncoding']?.toString() ?? 'hex',
      );
    });
    runtime.registerBridge('__ctx_crypto_aes_encrypt', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.aesEncrypt(
        data: payload['data']?.toString() ?? '',
        key: payload['key']?.toString() ?? '',
        iv: payload['iv']?.toString(),
        mode: payload['mode']?.toString() ?? 'cbc',
        inputEncoding: payload['inputEncoding']?.toString() ?? 'utf8',
        keyEncoding: payload['keyEncoding']?.toString() ?? 'utf8',
        ivEncoding: payload['ivEncoding']?.toString() ?? 'utf8',
        outputEncoding: payload['outputEncoding']?.toString() ?? 'base64',
      );
    });
    runtime.registerBridge('__ctx_crypto_aes_decrypt', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.aesDecrypt(
        data: payload['data']?.toString() ?? '',
        key: payload['key']?.toString() ?? '',
        iv: payload['iv']?.toString(),
        mode: payload['mode']?.toString() ?? 'cbc',
        inputEncoding: payload['inputEncoding']?.toString() ?? 'base64',
        keyEncoding: payload['keyEncoding']?.toString() ?? 'utf8',
        ivEncoding: payload['ivEncoding']?.toString() ?? 'utf8',
        outputEncoding: payload['outputEncoding']?.toString() ?? 'utf8',
      );
    });
    runtime.registerBridge('__ctx_crypto_des_encrypt', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.desEncrypt(
        data: payload['data']?.toString() ?? '',
        key: payload['key']?.toString() ?? '',
        iv: payload['iv']?.toString(),
        mode: payload['mode']?.toString() ?? 'cbc',
        inputEncoding: payload['inputEncoding']?.toString() ?? 'utf8',
        keyEncoding: payload['keyEncoding']?.toString() ?? 'utf8',
        ivEncoding: payload['ivEncoding']?.toString() ?? 'utf8',
        outputEncoding: payload['outputEncoding']?.toString() ?? 'base64',
      );
    });
    runtime.registerBridge('__ctx_crypto_des_decrypt', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.desDecrypt(
        data: payload['data']?.toString() ?? '',
        key: payload['key']?.toString() ?? '',
        iv: payload['iv']?.toString(),
        mode: payload['mode']?.toString() ?? 'cbc',
        inputEncoding: payload['inputEncoding']?.toString() ?? 'base64',
        keyEncoding: payload['keyEncoding']?.toString() ?? 'utf8',
        ivEncoding: payload['ivEncoding']?.toString() ?? 'utf8',
        outputEncoding: payload['outputEncoding']?.toString() ?? 'utf8',
      );
    });
    runtime.registerBridge('__ctx_crypto_3des_encrypt', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.tripleDesEncrypt(
        data: payload['data']?.toString() ?? '',
        key: payload['key']?.toString() ?? '',
        iv: payload['iv']?.toString(),
        mode: payload['mode']?.toString() ?? 'cbc',
        inputEncoding: payload['inputEncoding']?.toString() ?? 'utf8',
        keyEncoding: payload['keyEncoding']?.toString() ?? 'utf8',
        ivEncoding: payload['ivEncoding']?.toString() ?? 'utf8',
        outputEncoding: payload['outputEncoding']?.toString() ?? 'base64',
      );
    });
    runtime.registerBridge('__ctx_crypto_3des_decrypt', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.tripleDesDecrypt(
        data: payload['data']?.toString() ?? '',
        key: payload['key']?.toString() ?? '',
        iv: payload['iv']?.toString(),
        mode: payload['mode']?.toString() ?? 'cbc',
        inputEncoding: payload['inputEncoding']?.toString() ?? 'base64',
        keyEncoding: payload['keyEncoding']?.toString() ?? 'utf8',
        ivEncoding: payload['ivEncoding']?.toString() ?? 'utf8',
        outputEncoding: payload['outputEncoding']?.toString() ?? 'utf8',
      );
    });
    runtime.registerBridge('__ctx_crypto_rc4_encrypt', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.rc4Encrypt(
        data: payload['data']?.toString() ?? '',
        key: payload['key']?.toString() ?? '',
        inputEncoding: payload['inputEncoding']?.toString() ?? 'utf8',
        keyEncoding: payload['keyEncoding']?.toString() ?? 'utf8',
        outputEncoding: payload['outputEncoding']?.toString() ?? 'base64',
      );
    });
    runtime.registerBridge('__ctx_crypto_rc4_decrypt', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.rc4Decrypt(
        data: payload['data']?.toString() ?? '',
        key: payload['key']?.toString() ?? '',
        inputEncoding: payload['inputEncoding']?.toString() ?? 'base64',
        keyEncoding: payload['keyEncoding']?.toString() ?? 'utf8',
        outputEncoding: payload['outputEncoding']?.toString() ?? 'utf8',
      );
    });
    runtime.registerBridge('__ctx_crypto_symmetric_encrypt', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.symmetricEncrypt(
        algorithm: payload['algorithm']?.toString() ?? '',
        data: payload['data']?.toString() ?? '',
        key: payload['key']?.toString() ?? '',
        iv: payload['iv']?.toString(),
        inputEncoding: payload['inputEncoding']?.toString() ?? 'utf8',
        dataEncoding: payload['dataEncoding']?.toString() ?? 'utf8',
        keyEncoding: payload['keyEncoding']?.toString() ?? 'utf8',
        ivEncoding: payload['ivEncoding']?.toString() ?? 'utf8',
        outputEncoding: payload['outputEncoding']?.toString() ?? 'base64',
      );
    });
    runtime.registerBridge('__ctx_crypto_symmetric_decrypt', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.symmetricDecrypt(
        algorithm: payload['algorithm']?.toString() ?? '',
        data: payload['data']?.toString() ?? '',
        key: payload['key']?.toString() ?? '',
        iv: payload['iv']?.toString(),
        dataEncoding: payload['dataEncoding']?.toString() ?? 'base64',
        keyEncoding: payload['keyEncoding']?.toString() ?? 'utf8',
        ivEncoding: payload['ivEncoding']?.toString() ?? 'utf8',
        outputEncoding: payload['outputEncoding']?.toString() ?? 'utf8',
      );
    });
    runtime.registerBridge('__ctx_crypto_rsa_encrypt', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.rsaEncrypt(
        data: payload['data']?.toString() ?? '',
        publicKey: payload['publicKey']?.toString() ?? '',
        inputEncoding: payload['inputEncoding']?.toString() ?? 'utf8',
        outputEncoding: payload['outputEncoding']?.toString() ?? 'base64',
        padding: payload['padding']?.toString() ?? 'pkcs1',
      );
    });
    runtime.registerBridge('__ctx_crypto_rsa_decrypt', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.rsaDecrypt(
        data: payload['data']?.toString() ?? '',
        privateKey: payload['privateKey']?.toString() ?? '',
        inputEncoding: payload['inputEncoding']?.toString() ?? 'base64',
        outputEncoding: payload['outputEncoding']?.toString() ?? 'utf8',
        padding: payload['padding']?.toString() ?? 'pkcs1',
      );
    });
    runtime.registerBridge('__ctx_crypto_asymmetric_encrypt', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.asymmetricEncrypt(
        algorithm: payload['algorithm']?.toString() ?? '',
        data: payload['data']?.toString() ?? '',
        publicKey: payload['publicKey']?.toString() ?? '',
        inputEncoding: payload['inputEncoding']?.toString() ?? 'utf8',
        outputEncoding: payload['outputEncoding']?.toString() ?? 'base64',
      );
    });
    runtime.registerBridge('__ctx_crypto_asymmetric_decrypt', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.asymmetricDecrypt(
        algorithm: payload['algorithm']?.toString() ?? '',
        data: payload['data']?.toString() ?? '',
        privateKey: payload['privateKey']?.toString() ?? '',
        inputEncoding: payload['inputEncoding']?.toString() ?? 'base64',
        outputEncoding: payload['outputEncoding']?.toString() ?? 'utf8',
      );
    });
    runtime.registerBridge('__ctx_crypto_rsa_sign', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.rsaSign(
        data: payload['data']?.toString() ?? '',
        privateKey: payload['privateKey']?.toString() ?? '',
        algorithm: payload['algorithm']?.toString() ?? 'SHA-256/RSA',
        inputEncoding: payload['inputEncoding']?.toString() ?? 'utf8',
        outputEncoding: payload['outputEncoding']?.toString() ?? 'base64',
      );
    });
    runtime.registerBridge('__ctx_crypto_rsa_verify', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.rsaVerify(
        data: payload['data']?.toString() ?? '',
        publicKey: payload['publicKey']?.toString() ?? '',
        signature: payload['signature']?.toString() ?? '',
        algorithm: payload['algorithm']?.toString() ?? 'SHA-256/RSA',
        inputEncoding: payload['inputEncoding']?.toString() ?? 'utf8',
        signatureEncoding: payload['signatureEncoding']?.toString() ?? 'base64',
      );
    });
    runtime.registerBridge('__ctx_crypto_random_bytes', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.randomBytes(
        _readInt(payload['length'], fallback: 0) ?? 0,
        outputEncoding: payload['outputEncoding']?.toString() ?? 'hex',
      );
    });
    runtime.registerBridge('__ctx_crypto_random_string', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.randomString(
        _readInt(payload['length'], fallback: 0) ?? 0,
        alphabet:
            payload['alphabet']?.toString() ??
            'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789',
      );
    });
    runtime.registerBridge('__ctx_crypto_timestamp', (dynamic args) {
      final payload = _asMap(args);
      return ctx.crypto.timestamp(unit: payload['unit']?.toString() ?? 'ms');
    });
  }

  Future<void> runVoid({
    required String methodName,
    required SourceRuntimeContext ctx,
    required List<Object?> args,
  }) async {
    await run(methodName: methodName, ctx: ctx, args: args);
  }

  void dispose() {
    _runtime?.dispose();
    _runtime = null;
    _bootstrapsInstalled = false;
  }
}

class _SourceInspection {
  const _SourceInspection({
    required this.meta,
    required this.hasInit,
    required this.hasDiscoverCategories,
    required this.hasDiscoverBooks,
    required this.hasSearch,
    required this.hasDetail,
    required this.hasChapters,
    required this.hasContent,
  });

  final Map<String, dynamic> meta;
  final bool hasInit;
  final bool hasDiscoverCategories;
  final bool hasDiscoverBooks;
  final bool hasSearch;
  final bool hasDetail;
  final bool hasChapters;
  final bool hasContent;

  factory _SourceInspection.fromMap(Map<String, dynamic> map) {
    return _SourceInspection(
      meta: _asMap(map['meta']),
      hasInit: map['hasInit'] == true,
      hasDiscoverCategories: map['hasDiscoverCategories'] == true,
      hasDiscoverBooks: map['hasDiscoverBooks'] == true,
      hasSearch: map['hasSearch'] == true,
      hasDetail: map['hasDetail'] == true,
      hasChapters: map['hasChapters'] == true,
      hasContent: map['hasContent'] == true,
    );
  }
}

class _HtmlHandleStore {
  final Map<int, dom.Node> _nodes = <int, dom.Node>{};
  int _counter = 0;

  int store(dom.Node node) {
    _counter += 1;
    _nodes[_counter] = node;
    return _counter;
  }

  dom.Node? get(int? handle) {
    if (handle == null) {
      return null;
    }
    return _nodes[handle];
  }
}

dom.Element? _querySelector(dom.Node? node, String selector) {
  if (selector.isEmpty) {
    return null;
  }
  if (node is dom.Document) {
    return node.querySelector(selector);
  }
  if (node is dom.Element) {
    return node.querySelector(selector);
  }
  return null;
}

List<dom.Element> _querySelectorAll(dom.Node? node, String selector) {
  if (selector.isEmpty) {
    return const <dom.Element>[];
  }
  if (node is dom.Document) {
    return node.querySelectorAll(selector);
  }
  if (node is dom.Element) {
    return node.querySelectorAll(selector);
  }
  return const <dom.Element>[];
}

String _normalizeSourceCode(String sourceCode) {
  final trimmed = sourceCode.trim();
  if (trimmed.contains('export default')) {
    return trimmed.replaceFirst(
      RegExp(r'export\s+default'),
      'globalThis.__sourceDefinition =',
    );
  }
  if (trimmed.contains('globalThis.__sourceDefinition')) {
    return trimmed;
  }
  throw const SourceScriptCompileException(
    '当前仅支持以 `export default` 或 `globalThis.__sourceDefinition = ...` 导出书享源。',
  );
}

Object? _decodeDynamic(String output) {
  final trimmed = output.trim();
  if (trimmed.isEmpty || trimmed == 'undefined' || trimmed == 'null') {
    return null;
  }

  try {
    return jsonDecode(trimmed);
  } on FormatException {
    return trimmed;
  }
}

Object? _decodePossiblyNestedDynamic(String output, {int maxDepth = 3}) {
  Object? decoded = _decodeDynamic(output);
  var remainingDepth = maxDepth - 1;
  while (decoded is String && remainingDepth > 0) {
    final next = _decodeDynamic(decoded);
    if (next is String && next == decoded) {
      break;
    }
    decoded = next;
    remainingDepth -= 1;
  }
  return decoded;
}

_RuntimeEnvelope? _decodeRuntimeEnvelope(String output) {
  final decoded = _decodePossiblyNestedDynamic(output);
  if (decoded is! Map<String, dynamic>) {
    return null;
  }
  final rawOk = decoded['ok'];
  if (rawOk is! bool) {
    return null;
  }
  return _RuntimeEnvelope(
    ok: rawOk,
    value: decoded['value'],
    error: decoded['error']?.toString(),
    stats: _decodeRuntimeSanitizeStats(decoded['stats']),
  );
}

_RuntimeSanitizeStats _decodeRuntimeSanitizeStats(Object? raw) {
  if (raw is! Map) {
    return const _RuntimeSanitizeStats();
  }
  return _RuntimeSanitizeStats(
    droppedValues: _readInt(raw['droppedValues']) ?? 0,
    circularRefs: _readInt(raw['circularRefs']) ?? 0,
    maxDepthHits: _readInt(raw['maxDepthHits']) ?? 0,
    trimmedArrays: _readInt(raw['trimmedArrays']) ?? 0,
    trimmedObjects: _readInt(raw['trimmedObjects']) ?? 0,
  );
}

class _RuntimeEnvelope {
  const _RuntimeEnvelope({
    required this.ok,
    this.value,
    this.error,
    this.stats = const _RuntimeSanitizeStats(),
  });

  final bool ok;
  final Object? value;
  final String? error;
  final _RuntimeSanitizeStats stats;
}

class _RuntimeSanitizeStats {
  const _RuntimeSanitizeStats({
    this.droppedValues = 0,
    this.circularRefs = 0,
    this.maxDepthHits = 0,
    this.trimmedArrays = 0,
    this.trimmedObjects = 0,
  });

  final int droppedValues;
  final int circularRefs;
  final int maxDepthHits;
  final int trimmedArrays;
  final int trimmedObjects;

  bool get hasMutations {
    return droppedValues > 0 ||
        circularRefs > 0 ||
        maxDepthHits > 0 ||
        trimmedArrays > 0 ||
        trimmedObjects > 0;
  }
}

List<Book> _decodeBooks(Object? result, {required String fallbackSourceId}) {
  if (result is! List) {
    throw const SourceScriptCompileException('search 必须返回数组。');
  }
  return result
      .map(
        (Object? item) =>
            Book.fromMap(_asMap(item), fallbackSourceId: fallbackSourceId),
      )
      .toList(growable: false);
}

List<DiscoverCategory> _decodeDiscoverCategories(Object? result) {
  if (result is! List) {
    throw const SourceScriptCompileException('discoverCategories 必须返回数组。');
  }
  return result
      .map((Object? item) => DiscoverCategory.fromMap(_asMap(item)))
      .toList(growable: false);
}

List<Book> _decodeDiscoverBooks(
  Object? result, {
  required String fallbackSourceId,
}) {
  if (result is! List) {
    throw const SourceScriptCompileException('discoverBooks 必须返回数组。');
  }
  return result
      .map(
        (Object? item) =>
            Book.fromMap(_asMap(item), fallbackSourceId: fallbackSourceId),
      )
      .toList(growable: false);
}

Book _decodeBook(Object? result, {required String fallbackSourceId}) {
  if (result is! Map) {
    throw const SourceScriptCompileException('detail 必须返回对象。');
  }
  return Book.fromMap(_asMap(result), fallbackSourceId: fallbackSourceId);
}

List<Chapter> _decodeChapters(
  Object? result, {
  required String fallbackSourceId,
}) {
  if (result is! List) {
    throw const SourceScriptCompileException('chapters 必须返回数组。');
  }
  return result
      .asMap()
      .entries
      .map(
        (entry) => Chapter.fromMap(
          _asMap(entry.value),
          fallbackSourceId: fallbackSourceId,
          fallbackIndex: entry.key,
        ).copyWith(index: entry.key),
      )
      .toList(growable: false);
}

Content _decodeContent(Object? result, {required String fallbackSourceId}) {
  if (result is! Map) {
    throw const SourceScriptCompileException('content 必须返回对象。');
  }
  return Content.fromMap(_asMap(result), fallbackSourceId: fallbackSourceId);
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
    );
  }
  return <String, dynamic>{};
}

int? _readInt(dynamic value, {int? fallback}) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

RuntimeHttpRequest _requestFromMap(Map<String, dynamic> map) {
  final rawUrl = map['url']?.toString() ?? '';
  if (rawUrl.isEmpty) {
    throw const SourceScriptCompileException('ctx.http.request 缺少 url。');
  }

  return RuntimeHttpRequest(
    uri: Uri.parse(rawUrl),
    method: _parseHttpMethod(map['method']?.toString()),
    headers: _stringMap(map['headers']),
    query: _stringMap(map['query']),
    body: map['body'],
    bodyType: _parseBodyType(map['bodyType']?.toString()),
    timeout: Duration(
      milliseconds: _readInt(map['timeoutMs'], fallback: 8000)!,
    ),
    responseType: _parseResponseType(map['responseType']?.toString()),
    referer: map['referer']?.toString(),
    followRedirects:
        map['followRedirects'] is bool ? map['followRedirects'] as bool : true,
    charset: map['charset']?.toString(),
    execution: _parseRequestExecution(
      map['execution']?.toString(),
      webView: map['webView'] == true,
    ),
    proxy: map['proxy']?.toString(),
  );
}

RuntimeHttpMethod _parseHttpMethod(String? raw) {
  switch ((raw ?? 'GET').trim().toUpperCase()) {
    case 'POST':
      return RuntimeHttpMethod.post;
    case 'PUT':
      return RuntimeHttpMethod.put;
    case 'PATCH':
      return RuntimeHttpMethod.patch;
    case 'DELETE':
      return RuntimeHttpMethod.delete;
    case 'HEAD':
      return RuntimeHttpMethod.head;
    default:
      return RuntimeHttpMethod.get;
  }
}

RuntimeResponseType _parseResponseType(String? raw) {
  switch ((raw ?? 'text').trim().toLowerCase()) {
    case 'json':
      return RuntimeResponseType.json;
    case 'bytes':
      return RuntimeResponseType.bytes;
    default:
      return RuntimeResponseType.text;
  }
}

RuntimeBodyType _parseBodyType(String? raw) {
  switch ((raw ?? 'auto').trim().toLowerCase()) {
    case 'json':
      return RuntimeBodyType.json;
    case 'form':
    case 'urlencoded':
    case 'x-www-form-urlencoded':
      return RuntimeBodyType.form;
    case 'text':
      return RuntimeBodyType.text;
    case 'bytes':
      return RuntimeBodyType.bytes;
    default:
      return RuntimeBodyType.auto;
  }
}

RuntimeRequestExecution _parseRequestExecution(
  String? raw, {
  bool webView = false,
}) {
  if (webView) {
    return RuntimeRequestExecution.browser;
  }
  switch ((raw ?? 'http').trim().toLowerCase()) {
    case 'browser':
    case 'webview':
      return RuntimeRequestExecution.browser;
    default:
      return RuntimeRequestExecution.http;
  }
}

RuntimeHttpResponse _responseFromMap(Map<String, dynamic> map) {
  return RuntimeHttpResponse(
    ok: map['ok'] == true,
    status: _readInt(map['status'], fallback: 0)!,
    uri: Uri.tryParse(map['url']?.toString() ?? '') ?? Uri(),
    headers: _stringMap(map['headers']),
    text: map['text']?.toString(),
    json: map['json'],
    bytes: null,
    redirected: map['redirected'] == true,
  );
}

BrowserChallengeRequest _challengeRequestFromMap(Map<String, dynamic> map) {
  final url = map['url']?.toString() ?? '';
  return BrowserChallengeRequest(
    uri: Uri.parse(url),
    reason: map['reason']?.toString() ?? 'challenge',
    waitFor: _asMap(map['waitFor']),
    timeout: Duration(
      milliseconds: _readInt(map['timeoutMs'], fallback: 120000)!,
    ),
  );
}

BrowserOpenRequest _openRequestFromMap(Map<String, dynamic> map) {
  final url = map['url']?.toString() ?? '';
  return BrowserOpenRequest(
    uri: Uri.parse(url),
    timeout: Duration(
      milliseconds: _readInt(map['timeoutMs'], fallback: 120000)!,
    ),
  );
}

BrowserEvalRequest _evalRequestFromMap(Map<String, dynamic> map) {
  final url = map['url']?.toString() ?? '';
  return BrowserEvalRequest(
    uri: Uri.parse(url),
    script: map['script']?.toString() ?? '',
    timeout: Duration(
      milliseconds: _readInt(map['timeoutMs'], fallback: 10000)!,
    ),
  );
}

Uri? _readUri(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  return Uri.tryParse(raw);
}

Map<String, String> _stringMap(dynamic value) {
  if (value is Map<String, String>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic mapValue) =>
          MapEntry(key.toString(), mapValue.toString()),
    );
  }
  return <String, String>{};
}

Map<String, Object?> _sourceInfoToMap(SourceRuntimeInfo source) {
  return <String, Object?>{
    'id': source.id,
    'name': source.name,
    'group': source.group,
    'revision': source.revision,
  };
}

Map<String, Object?> _taskToMap(SourceTask task) {
  return <String, Object?>{
    'step': task.step.name,
    'keyword': task.keyword,
    'category':
        task.category == null ? null : _discoverCategoryToMap(task.category!),
    'page': task.page,
    'pageSize': task.pageSize,
    'book': task.book == null ? null : _bookToMap(task.book!),
    'chapter': task.chapter == null ? null : _chapterToMap(task.chapter!),
  };
}

Map<String, Object?> _discoverCategoryToMap(DiscoverCategory category) {
  return <String, Object?>{
    'title': category.title,
    'url': category.url,
    'style': <String, Object?>{
      'layoutFlexGrow': category.style.layoutFlexGrow,
      'layoutFlexBasisPercent': category.style.layoutFlexBasisPercent,
    },
    'extra': category.extra,
    'debug': category.debug,
  };
}

Map<String, Object?> _bookToMap(Book book) {
  return <String, Object?>{
    'title': book.title,
    'author': book.author,
    'type': book.type,
    'cover': book.cover,
    'intro': book.intro,
    'status': book.status,
    'category': book.category,
    'score': book.score,
    'wordCount': book.wordCount,
    'updateTime': book.updateTime,
    'tags': book.tags,
    'latestChapter': book.latestChapter,
    'detailUrl': book.detailUrl,
    'tocUrl': book.tocUrl,
    'sourceId': book.sourceId,
    'extra': book.extra,
    'debug': book.debug,
  };
}

Map<String, Object?> _chapterToMap(Chapter chapter) {
  return <String, Object?>{
    'title': chapter.title,
    'url': chapter.url,
    'index': chapter.index,
    'isVolume': chapter.isVolume,
    'vip': chapter.vip,
    'isVip': chapter.vip,
    'isPay': chapter.isPay,
    'updateTime': chapter.updateTime,
    'sourceId': chapter.sourceId,
    'extra': chapter.extra,
    'debug': chapter.debug,
  };
}

const String _sourceRuntimeBootstrap = r'''
var ctx = undefined;
var source = undefined;

(function() {
  const __appreadOmit = Symbol('appread.omit');
  const __appreadMaxSanitizeDepth = 8;
  const __appreadMaxArrayLength = Number.MAX_SAFE_INTEGER;
  const __appreadMaxChapterArrayLength = Number.MAX_SAFE_INTEGER;
  const __appreadMaxObjectEntries = Number.MAX_SAFE_INTEGER;

  function isPlainObject(value) {
    if (!value || typeof value !== 'object') {
      return false;
    }
    const prototype = Object.getPrototypeOf(value);
    return prototype === Object.prototype || prototype === null;
  }

  function createSanitizeStats() {
    return {
      droppedValues: 0,
      circularRefs: 0,
      maxDepthHits: 0,
      trimmedArrays: 0,
      trimmedObjects: 0,
    };
  }

  function resolveArrayLengthLimit(rootMethodName, depth) {
    if (depth === 0 && rootMethodName === 'chapters') {
      return __appreadMaxChapterArrayLength;
    }
    return __appreadMaxArrayLength;
  }

  function sanitizeForHost(value, depth, seen, stats, rootMethodName) {
    const effectiveStats = stats || createSanitizeStats();
    if (value === null) {
      return null;
    }

    if (depth > __appreadMaxSanitizeDepth) {
      effectiveStats.maxDepthHits += 1;
      return null;
    }

    const valueType = typeof value;
    switch (valueType) {
      case 'string':
      case 'boolean':
        return value;
      case 'number':
        return Number.isFinite(value) ? value : null;
      case 'undefined':
      case 'function':
      case 'symbol':
      case 'bigint':
        effectiveStats.droppedValues += 1;
        return __appreadOmit;
      default:
        break;
    }

    if (value instanceof Date) {
      const time = value.getTime();
      return Number.isFinite(time) ? value.toISOString() : null;
    }

    if (Array.isArray(value)) {
      if (seen.has(value)) {
        effectiveStats.circularRefs += 1;
        return null;
      }
      seen.add(value);
      try {
        const result = [];
        const limit = Math.min(
          value.length,
          resolveArrayLengthLimit(rootMethodName, depth)
        );
        if (value.length > limit) {
          effectiveStats.trimmedArrays += value.length - limit;
        }
        for (let index = 0; index < limit; index += 1) {
          const sanitized = sanitizeForHost(
            value[index],
            depth + 1,
            seen,
            effectiveStats,
            rootMethodName
          );
          result.push(sanitized === __appreadOmit ? null : sanitized);
        }
        return result;
      } finally {
        seen.delete(value);
      }
    }

    if (valueType === 'object') {
      if (seen.has(value)) {
        effectiveStats.circularRefs += 1;
        return null;
      }

      if (typeof value.toJSON === 'function') {
        try {
          return sanitizeForHost(
            value.toJSON(),
            depth + 1,
            seen,
            effectiveStats,
            rootMethodName
          );
        } catch (_) {
          effectiveStats.droppedValues += 1;
          return null;
        }
      }

      if (!isPlainObject(value)) {
        effectiveStats.droppedValues += 1;
        return null;
      }

      seen.add(value);
      try {
        const result = {};
        const entries = Object.entries(value);
        const limit = Math.min(entries.length, __appreadMaxObjectEntries);
        if (entries.length > limit) {
          effectiveStats.trimmedObjects += entries.length - limit;
        }
        for (let index = 0; index < limit; index += 1) {
          const entry = entries[index];
          const key = entry[0];
          const sanitized = sanitizeForHost(
            entry[1],
            depth + 1,
            seen,
            effectiveStats,
            rootMethodName
          );
          if (sanitized !== __appreadOmit) {
            result[key] = sanitized;
          }
        }
        return result;
      } finally {
        seen.delete(value);
      }
    }

    return null;
  }

  function safeErrorMessage(error) {
    if (typeof error === 'string') {
      return error;
    }
    if (!error || typeof error !== 'object') {
      return '[non-serializable error]';
    }
    if (typeof error.message === 'string' && error.message.trim()) {
      return error.message;
    }
    if (typeof error.name === 'string' && error.name.trim()) {
      return '[' + error.name + ']';
    }
    return '[non-serializable error]';
  }

  function stringifySanitized(value) {
    const stats = createSanitizeStats();
    return JSON.stringify(sanitizeForHost(value, 0, new WeakSet(), stats));
  }

  function encodePayload(payload) {
    return stringifySanitized(payload === undefined ? {} : payload);
  }

  function safeStringify(value) {
    if (typeof value === 'string') {
      return value;
    }
    try {
      const sanitized = sanitizeForHost(value, 0, new WeakSet());
      if (sanitized === __appreadOmit) {
        return '[non-serializable value]';
      }
      return JSON.stringify(sanitized, null, 2);
    } catch (_) {
      return '[non-serializable value]';
    }
  }

  function hostCall(channel, payload) {
    return sendMessage(channel, encodePayload(payload));
  }

  globalThis.__appreadSafeStringify = safeStringify;
  globalThis.__appreadEncodeHostSuccess = function(value, methodName) {
    const stats = createSanitizeStats();
    return JSON.stringify({
      ok: true,
      value: sanitizeForHost(value, 0, new WeakSet(), stats, methodName),
      stats,
    });
  };
  globalThis.__appreadEncodeHostFailure = function(error) {
    return JSON.stringify({
      ok: false,
      error: safeErrorMessage(error),
    });
  };

  function createCryptoChain(state) {
    const next = Object.assign({}, state);
    return {
      encode() {
        next.operation = 'encrypt';
        return createCryptoChain(next);
      },
      decode() {
        next.operation = 'decrypt';
        return createCryptoChain(next);
      },
      encrypt() {
        next.operation = 'encrypt';
        return createCryptoChain(next);
      },
      decrypt() {
        next.operation = 'decrypt';
        return createCryptoChain(next);
      },
      setPublicKey(value) {
        next.publicKey = value;
        return createCryptoChain(next);
      },
      setPrivateKey(value) {
        next.privateKey = value;
        return createCryptoChain(next);
      },
      output(encoding) {
        next.outputEncoding = encoding;
        return createCryptoChain(next);
      },
      input(encoding) {
        next.dataEncoding = encoding;
        return createCryptoChain(next);
      },
      base64() {
        return finalize('base64');
      },
      hex() {
        return finalize('hex');
      },
      string() {
        return finalize('string');
      },
      utf8() {
        return finalize('utf8');
      },
      value() {
        return finalize(next.outputEncoding || defaultOutputEncoding());
      }
    };

    function defaultOutputEncoding() {
      return next.operation === 'decrypt' ? 'utf8' : 'base64';
    }

    function finalize(outputEncoding) {
      const operation = next.operation || 'encrypt';
      if (next.kind === 'symmetric') {
        return hostCall(
          operation === 'decrypt'
            ? '__ctx_crypto_symmetric_decrypt'
            : '__ctx_crypto_symmetric_encrypt',
          {
            algorithm: next.algorithm,
            key: next.key,
            iv: next.iv,
            data: next.data,
            keyEncoding: next.keyEncoding || 'utf8',
            ivEncoding: next.ivEncoding || 'utf8',
            dataEncoding: next.dataEncoding || (operation === 'decrypt' ? 'base64' : 'utf8'),
            outputEncoding
          }
        );
      }

      return hostCall(
        operation === 'decrypt'
          ? '__ctx_crypto_asymmetric_decrypt'
          : '__ctx_crypto_asymmetric_encrypt',
        {
          algorithm: next.algorithm,
          data: next.data,
          publicKey: next.publicKey,
          privateKey: next.privateKey,
          inputEncoding: next.dataEncoding || (operation === 'decrypt' ? 'base64' : 'utf8'),
          outputEncoding
        }
      );
    }
  }

  function utf8Encode(value) {
    const input = String(value ?? '');
    const bytes = [];
    for (let index = 0; index < input.length; index += 1) {
      let codePoint = input.charCodeAt(index);
      if (
        codePoint >= 0xd800 &&
        codePoint <= 0xdbff &&
        index + 1 < input.length
      ) {
        const next = input.charCodeAt(index + 1);
        if (next >= 0xdc00 && next <= 0xdfff) {
          codePoint =
            0x10000 + ((codePoint - 0xd800) << 10) + (next - 0xdc00);
          index += 1;
        }
      }

      if (codePoint <= 0x7f) {
        bytes.push(codePoint);
      } else if (codePoint <= 0x7ff) {
        bytes.push(0xc0 | (codePoint >> 6));
        bytes.push(0x80 | (codePoint & 0x3f));
      } else if (codePoint <= 0xffff) {
        bytes.push(0xe0 | (codePoint >> 12));
        bytes.push(0x80 | ((codePoint >> 6) & 0x3f));
        bytes.push(0x80 | (codePoint & 0x3f));
      } else {
        bytes.push(0xf0 | (codePoint >> 18));
        bytes.push(0x80 | ((codePoint >> 12) & 0x3f));
        bytes.push(0x80 | ((codePoint >> 6) & 0x3f));
        bytes.push(0x80 | (codePoint & 0x3f));
      }
    }
    return new Uint8Array(bytes);
  }

  function utf8Decode(bytes) {
    const input = normalizeBytes(bytes);
    let output = '';
    for (let index = 0; index < input.length; ) {
      const first = input[index++];
      if (first < 0x80) {
        output += String.fromCharCode(first);
      } else if (first >= 0xc0 && first < 0xe0 && index < input.length) {
        const second = input[index++];
        output += String.fromCharCode(((first & 0x1f) << 6) | (second & 0x3f));
      } else if (first >= 0xe0 && first < 0xf0 && index + 1 < input.length) {
        const second = input[index++];
        const third = input[index++];
        output += String.fromCharCode(
          ((first & 0x0f) << 12) | ((second & 0x3f) << 6) | (third & 0x3f)
        );
      } else if (first >= 0xf0 && index + 2 < input.length) {
        const second = input[index++];
        const third = input[index++];
        const fourth = input[index++];
        let codePoint =
          ((first & 0x07) << 18) |
          ((second & 0x3f) << 12) |
          ((third & 0x3f) << 6) |
          (fourth & 0x3f);
        codePoint -= 0x10000;
        output += String.fromCharCode(
          0xd800 + (codePoint >> 10),
          0xdc00 + (codePoint & 0x3ff)
        );
      } else {
        output += '\ufffd';
      }
    }
    return output;
  }

  function normalizeBytes(value) {
    if (value instanceof Uint8Array) {
      return value;
    }
    if (Array.isArray(value)) {
      return new Uint8Array(value.map((item) => Number(item) & 0xff));
    }
    if (value && typeof value.length === 'number') {
      const bytes = [];
      for (let index = 0; index < value.length; index += 1) {
        bytes.push(Number(value[index]) & 0xff);
      }
      return new Uint8Array(bytes);
    }
    return utf8Encode(value ?? '');
  }

  function bytesToHex(value) {
    const bytes = normalizeBytes(value);
    let output = '';
    for (let index = 0; index < bytes.length; index += 1) {
      output += bytes[index].toString(16).padStart(2, '0');
    }
    return output;
  }

  function hexToBytes(value) {
    const raw = String(value ?? '').trim();
    if (raw.length === 0) {
      return new Uint8Array();
    }
    if (raw.length % 2 !== 0) {
      throw new Error('hex string length must be even');
    }
    const output = new Uint8Array(raw.length / 2);
    for (let index = 0; index < raw.length; index += 2) {
      const byte = Number.parseInt(raw.slice(index, index + 2), 16);
      if (!Number.isFinite(byte)) {
        throw new Error('invalid hex string');
      }
      output[index / 2] = byte;
    }
    return output;
  }

  const base64Alphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

  function bytesToBase64(value) {
    const bytes = normalizeBytes(value);
    let output = '';
    let index = 0;
    for (; index + 2 < bytes.length; index += 3) {
      output += base64Alphabet[bytes[index] >> 2];
      output += base64Alphabet[((bytes[index] & 3) << 4) | (bytes[index + 1] >> 4)];
      output += base64Alphabet[((bytes[index + 1] & 15) << 2) | (bytes[index + 2] >> 6)];
      output += base64Alphabet[bytes[index + 2] & 63];
    }
    if (index < bytes.length) {
      output += base64Alphabet[bytes[index] >> 2];
      if (index === bytes.length - 1) {
        output += base64Alphabet[(bytes[index] & 3) << 4] + '==';
      } else {
        output += base64Alphabet[((bytes[index] & 3) << 4) | (bytes[index + 1] >> 4)];
        output += base64Alphabet[(bytes[index + 1] & 15) << 2] + '=';
      }
    }
    return output;
  }

  function base64ToBytes(value) {
    const raw = String(value ?? '').replace(/\s+/g, '');
    if (!raw) {
      return new Uint8Array();
    }
    const clean = raw.replace(/=+$/, '');
    const output = [];
    let buffer = 0;
    let bits = 0;
    for (let index = 0; index < clean.length; index += 1) {
      const valueIndex = base64Alphabet.indexOf(clean[index]);
      if (valueIndex < 0) {
        throw new Error('invalid base64 string');
      }
      buffer = (buffer << 6) | valueIndex;
      bits += 6;
      if (bits >= 8) {
        bits -= 8;
        output.push((buffer >> bits) & 0xff);
      }
    }
    return new Uint8Array(output);
  }

  function bytesOrString(bytes, outputEncoding) {
    const normalized = String(outputEncoding || 'bytes').toLowerCase();
    if (normalized === 'string' || normalized === 'utf8' || normalized === 'utf-8') {
      return utf8Decode(bytes);
    }
    if (normalized === 'array') {
      return Array.from(normalizeBytes(bytes));
    }
    return normalizeBytes(bytes);
  }

  function wrapNode(handle) {
    if (handle === null || handle === undefined) {
      return null;
    }

    return {
      __handle: handle,
      querySelector(selector) {
        return wrapNode(hostCall('__ctx_html_query_selector', { handle, selector }));
      },
      querySelectorAll(selector) {
        const handles = hostCall('__ctx_html_query_selector_all', { handle, selector }) || [];
        return handles.map((childHandle) => wrapNode(childHandle));
      },
      getAttribute(name) {
        return hostCall('__ctx_html_attr', { handle, name }) || '';
      },
      get textContent() {
        return hostCall('__ctx_html_text', { handle }) || '';
      },
      get innerText() {
        return hostCall('__ctx_html_text', { handle }) || '';
      },
      get innerHtml() {
        return hostCall('__ctx_html_inner_html', { handle }) || '';
      }
    };
  }

  globalThis.__createSourceCtx = function(sourceInfo) {
    return {
      source: sourceInfo,
      http: {
        request(options) {
          return hostCall('__ctx_http_request', { options });
        },
        isHtml(response) {
          return !!hostCall('__ctx_http_is_html', { response });
        },
        isJson(response) {
          return !!hostCall('__ctx_http_is_json', { response });
        },
        isRedirect(response) {
          return !!hostCall('__ctx_http_is_redirect', { response });
        },
        isChallenge(response) {
          return !!hostCall('__ctx_http_is_challenge', { response });
        }
      },
      cookie: {
        get(name) {
          return hostCall('__ctx_cookie_get', { name });
        },
        getAll() {
          return hostCall('__ctx_cookie_get_all', {});
        },
        getForUrl(url, name) {
          return hostCall('__ctx_cookie_get_for_url', { url, name });
        },
        set(name, value) {
          return hostCall('__ctx_cookie_set', { name, value });
        },
        remove(name) {
          return hostCall('__ctx_cookie_remove', { name });
        },
        clearDomain(domain) {
          return hostCall('__ctx_cookie_clear_domain', { domain });
        }
      },
      cache: {
        get(key) {
          return hostCall('__ctx_cache_get', { key });
        },
        set(key, value) {
          return hostCall('__ctx_cache_set', { key, value });
        },
        remove(key) {
          return hostCall('__ctx_cache_remove', { key });
        },
        clearPrefix(prefix) {
          return hostCall('__ctx_cache_clear_prefix', { prefix });
        }
      },
      html: {
        parse(html) {
          return wrapNode(hostCall('__ctx_html_parse', { html }));
        },
        text(node) {
          if (!node) {
            return '';
          }
          return hostCall('__ctx_html_text', { handle: node.__handle }) || '';
        },
        innerHtml(node) {
          if (!node) {
            return '';
          }
          return hostCall('__ctx_html_inner_html', { handle: node.__handle }) || '';
        },
        attr(node, name) {
          if (!node) {
            return '';
          }
          return hostCall('__ctx_html_attr', { handle: node.__handle, name }) || '';
        },
        collect(nodes, mapper) {
          return (nodes || []).map((node, index) => mapper(node, index));
        }
      },
      browser: {
        challenge(options) {
          return hostCall('__ctx_browser_challenge', { options });
        },
        open(options) {
          return hostCall('__ctx_browser_open', { options });
        },
        waitForUrl(options) {
          return hostCall('__ctx_browser_wait_for_url', { options });
        },
        waitForText(options) {
          return hostCall('__ctx_browser_wait_for_text', { options });
        },
        eval(options) {
          return hostCall('__ctx_browser_eval', { options });
        },
        getCookies() {
          return hostCall('__ctx_browser_get_cookies', {});
        },
        getCurrentUrl() {
          return hostCall('__ctx_browser_get_current_url', {});
        },
        getHtml() {
          return hostCall('__ctx_browser_get_html', {});
        },
        getStorage() {
          return hostCall('__ctx_browser_get_storage', {});
        }
      },
      session: {
        get(key) {
          return hostCall('__ctx_session_get', { key });
        },
        set(key, value) {
          return hostCall('__ctx_session_set', { key, value });
        },
        clear(key) {
          return hostCall('__ctx_session_clear', { key });
        },
        cookies() {
          return hostCall('__ctx_session_cookies', {});
        }
      },
      utils: {
        absoluteUrl(base, relative) {
          return hostCall('__ctx_utils_absolute_url', { base, relative });
        },
        sleep(ms) {
          return hostCall('__ctx_utils_sleep', { ms });
        },
        pick(value, fallback) {
          return value ?? fallback;
        },
        normalizeText(value) {
          return hostCall('__ctx_utils_normalize_text', { value });
        },
        htmlFormat(value) {
          return hostCall('__ctx_utils_html_format', { value });
        },
        timeFormat(value, pattern = 'yyyy-MM-dd HH:mm:ss') {
          return hostCall('__ctx_utils_time_format', { value, pattern });
        },
        base64Encode(value) {
          return hostCall('__ctx_utils_base64_encode', { value });
        },
        base64Decode(value) {
          return hostCall('__ctx_utils_base64_decode', { value });
        },
        hexEncode(value) {
          return hostCall('__ctx_utils_hex_encode', { value });
        },
        hexDecode(value) {
          return hostCall('__ctx_utils_hex_decode', { value });
        },
        encodeUri(value) {
          return hostCall('__ctx_utils_encode_uri', { value });
        },
        decodeUri(value) {
          return hostCall('__ctx_utils_decode_uri', { value });
        },
        encodeUriComponent(value) {
          return hostCall('__ctx_utils_encode_uri_component', { value });
        },
        decodeUriComponent(value) {
          return hostCall('__ctx_utils_decode_uri_component', { value });
        },
        getDeviceInfo() {
          return hostCall('__ctx_utils_get_device_info', {});
        },
        getUserId() {
          return hostCall('__ctx_utils_get_user_id', {});
        }
      },
      crypto: {
        hexEncode(value, options = {}) {
          return bytesToHex(
            options.inputEncoding === 'hex'
              ? hexToBytes(value)
              : options.inputEncoding === 'base64'
                ? base64ToBytes(value)
                : normalizeBytes(value)
          );
        },
        hexDecode(value, options = {}) {
          return bytesOrString(hexToBytes(value), options.output || options.outputEncoding);
        },
        hexToBytes(value) {
          return hexToBytes(value);
        },
        bytesToHex(value) {
          return bytesToHex(value);
        },
        base64Encode(value, options = {}) {
          if (options.inputEncoding === 'hex') {
            return bytesToBase64(hexToBytes(value));
          }
          if (options.inputEncoding === 'base64') {
            return bytesToBase64(base64ToBytes(value));
          }
          return bytesToBase64(value);
        },
        base64Decode(value, options = {}) {
          return bytesOrString(base64ToBytes(value), options.output || options.outputEncoding);
        },
        base64ToBytes(value) {
          return base64ToBytes(value);
        },
        bytesToBase64(value) {
          return bytesToBase64(value);
        },
        md5(value, options = {}) {
          return hostCall('__ctx_crypto_md5', {
            value,
            inputEncoding: options.inputEncoding,
            outputEncoding: options.outputEncoding
          });
        },
        sha1(value, options = {}) {
          return hostCall('__ctx_crypto_sha1', {
            value,
            inputEncoding: options.inputEncoding,
            outputEncoding: options.outputEncoding
          });
        },
        sha256(value, options = {}) {
          return hostCall('__ctx_crypto_sha256', {
            value,
            inputEncoding: options.inputEncoding,
            outputEncoding: options.outputEncoding
          });
        },
        sha512(value, options = {}) {
          return hostCall('__ctx_crypto_sha512', {
            value,
            inputEncoding: options.inputEncoding,
            outputEncoding: options.outputEncoding
          });
        },
        sm3(value, options = {}) {
          return hostCall('__ctx_crypto_sm3', {
            value,
            inputEncoding: options.inputEncoding,
            outputEncoding: options.outputEncoding
          });
        },
        hmacSha1(value, key, options = {}) {
          return hostCall('__ctx_crypto_hmac_sha1', {
            value,
            key,
            inputEncoding: options.inputEncoding,
            keyEncoding: options.keyEncoding,
            outputEncoding: options.outputEncoding
          });
        },
        hmacSha256(value, key, options = {}) {
          return hostCall('__ctx_crypto_hmac_sha256', {
            value,
            key,
            inputEncoding: options.inputEncoding,
            keyEncoding: options.keyEncoding,
            outputEncoding: options.outputEncoding
          });
        },
        hmacSha512(value, key, options = {}) {
          return hostCall('__ctx_crypto_hmac_sha512', {
            value,
            key,
            inputEncoding: options.inputEncoding,
            keyEncoding: options.keyEncoding,
            outputEncoding: options.outputEncoding
          });
        },
        aesEncrypt(options) {
          return hostCall('__ctx_crypto_aes_encrypt', options || {});
        },
        aesDecrypt(options) {
          return hostCall('__ctx_crypto_aes_decrypt', options || {});
        },
        desEncrypt(options) {
          return hostCall('__ctx_crypto_des_encrypt', options || {});
        },
        desDecrypt(options) {
          return hostCall('__ctx_crypto_des_decrypt', options || {});
        },
        rc4Encrypt(options) {
          return hostCall('__ctx_crypto_rc4_encrypt', options || {});
        },
        rc4Decrypt(options) {
          return hostCall('__ctx_crypto_rc4_decrypt', options || {});
        },
        tripleDesEncrypt(options) {
          return hostCall('__ctx_crypto_3des_encrypt', options || {});
        },
        tripleDesDecrypt(options) {
          return hostCall('__ctx_crypto_3des_decrypt', options || {});
        },
        symmetricEncrypt(options) {
          return hostCall('__ctx_crypto_symmetric_encrypt', options || {});
        },
        symmetricDecrypt(options) {
          return hostCall('__ctx_crypto_symmetric_decrypt', options || {});
        },
        rsaEncrypt(options) {
          return hostCall('__ctx_crypto_rsa_encrypt', options || {});
        },
        rsaDecrypt(options) {
          return hostCall('__ctx_crypto_rsa_decrypt', options || {});
        },
        asymmetricEncrypt(options) {
          return hostCall('__ctx_crypto_asymmetric_encrypt', options || {});
        },
        asymmetricDecrypt(options) {
          return hostCall('__ctx_crypto_asymmetric_decrypt', options || {});
        },
        rsaSign(options) {
          return hostCall('__ctx_crypto_rsa_sign', options || {});
        },
        rsaVerify(options) {
          return !!hostCall('__ctx_crypto_rsa_verify', options || {});
        },
        randomBytes(length, options = {}) {
          return hostCall('__ctx_crypto_random_bytes', {
            length,
            outputEncoding: options.outputEncoding
          });
        },
        randomString(length, options = {}) {
          return hostCall('__ctx_crypto_random_string', {
            length,
            alphabet: options.alphabet
          });
        },
        timestamp(options = {}) {
          return hostCall('__ctx_crypto_timestamp', {
            unit: options.unit
          });
        },
        symmetricCrypto(key, iv, algorithm, data) {
          return createCryptoChain({
            kind: 'symmetric',
            key,
            iv,
            algorithm,
            data
          });
        },
        asymmetricCrypto(algorithm, data) {
          return createCryptoChain({
            kind: 'asymmetric',
            algorithm,
            data
          });
        },
        AsymmetricCrypto(algorithm, data) {
          return this.asymmetricCrypto(algorithm, data);
        }
      },
      log() {
        return hostCall('__ctx_log', {
          message: Array.from(arguments).map(safeStringify).join(' ')
        });
      }
    };
  };
})();
''';
