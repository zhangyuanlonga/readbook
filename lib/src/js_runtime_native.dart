import 'dart:async';

import 'package:flutter_js/flutter_js.dart';

import 'js_runtime.dart';

const String _playgroundBootstrapSource = '''
(function() {
  function stringifyArg(value) {
    if (typeof value === 'string') {
      return value;
    }

    try {
      return JSON.stringify(value, null, 2);
    } catch (error) {
      return String(value);
    }
  }

  function send(channel, payload) {
    const body = payload === undefined ? {} : payload;
    return sendMessage(channel, JSON.stringify(body));
  }

  const consoleBridge = {
    log: function() {
      return send('appendLog', {
        level: 'info',
        message: Array.from(arguments).map(stringifyArg).join(' ')
      });
    },
    warn: function() {
      return send('appendLog', {
        level: 'warn',
        message: Array.from(arguments).map(stringifyArg).join(' ')
      });
    },
    error: function() {
      return send('appendLog', {
        level: 'error',
        message: Array.from(arguments).map(stringifyArg).join(' ')
      });
    }
  };

  const app = {
    get state() {
      return send('getState');
    },
    updateView: function(patch) {
      return send('updateView', patch);
    },
    setTitle: function(value) {
      return send('updateView', { title: String(value) });
    },
    setSubtitle: function(value) {
      return send('updateView', { subtitle: String(value) });
    },
    setCounter: function(value) {
      return send('updateView', { counter: Number(value) });
    },
    incrementCounter: function(step) {
      return send('incrementCounter', { step: Number(step) || 1 });
    },
    setProgress: function(value) {
      return send('updateView', { progress: Number(value) });
    },
    setEnabled: function(value) {
      return send('updateView', { enabled: Boolean(value) });
    },
    setAccent: function(value) {
      return send('updateView', { accentHex: String(value) });
    },
    resetView: function() {
      return send('resetView');
    },
    clearLogs: function() {
      return send('clearLogs');
    },
    searchBaidu: function(query) {
      return send('searchBaidu', { query: String(query) });
    },
    delay: function(ms) {
      return send('delay', { ms: Number(ms) || 0 });
    },
    log: function() {
      return consoleBridge.log.apply(consoleBridge, arguments);
    }
  };

  globalThis.app = app;
  globalThis.page = app;
  globalThis.console = consoleBridge;
})();
''';

JsRuntimeAdapter createJsRuntimeAdapter() {
  const disableEverywhere = bool.fromEnvironment('DISABLE_FLUTTER_JS');
  const disableOnMacOs = bool.fromEnvironment('DISABLE_FLUTTER_JS_ON_MACOS');

  if (disableEverywhere || disableOnMacOs) {
    return const DisabledNativeJsRuntimeAdapter();
  }

  return NativeJsRuntimeAdapter();
}

class DisabledNativeJsRuntimeAdapter implements JsRuntimeAdapter {
  const DisabledNativeJsRuntimeAdapter();

  @override
  bool get isSupported => false;

  @override
  String? get unsupportedReason =>
      'flutter_js 已通过 dart-define 临时关闭，用于排查 macOS 黑屏问题。';

  @override
  Future<void> installBootstrap(String source, {String? sourceUrl}) async {}

  @override
  Future<void> installPlaygroundBootstrap() async {}

  @override
  void registerBridge(String channelName, JsBridgeHandler handler) {}

  @override
  Future<JsExecutionResult> runSnippet(String script) async {
    return JsExecutionResult(
      output: unsupportedReason ?? 'flutter_js 已被关闭。',
      isError: true,
    );
  }

  @override
  void dispose() {}
}

class NativeJsRuntimeAdapter implements JsRuntimeAdapter {
  NativeJsRuntimeAdapter() : _runtime = getJavascriptRuntime(xhr: true) {
    _runtime.setInspectable(true);
  }

  static Future<void> _executionQueue = Future<void>.value();

  final JavascriptRuntime _runtime;
  bool _bootstrapInstalled = false;

  @override
  bool get isSupported => true;

  @override
  String? get unsupportedReason => null;

  @override
  void registerBridge(String channelName, JsBridgeHandler handler) {
    _runtime.onMessage(channelName, handler);
  }

  @override
  Future<void> installBootstrap(String source, {String? sourceUrl}) async {
    await _runExclusive(() {
      final result = _runtime.evaluate(
        source,
        sourceUrl: sourceUrl ?? 'runtime_bootstrap.js',
      );

      if (result.isError) {
        throw StateError(result.stringResult);
      }
    });
  }

  @override
  Future<void> installPlaygroundBootstrap() async {
    if (_bootstrapInstalled) {
      return;
    }

    await installBootstrap(
      _playgroundBootstrapSource,
      sourceUrl: 'playground_bootstrap.js',
    );

    _bootstrapInstalled = true;
  }

  @override
  Future<JsExecutionResult> runSnippet(String script) async {
    final wrappedScript = '''
(async () => {
$script
})()
''';

    return _runExclusive(() async {
      try {
        final initialResult = await _runtime.evaluateAsync(
          wrappedScript,
          sourceUrl: 'playground_user_script.js',
        );

        if (initialResult.isError) {
          return JsExecutionResult(
            output: initialResult.stringResult,
            isError: true,
          );
        }

        _runtime.executePendingJob();
        final resolvedResult = await _runtime.handlePromise(initialResult);

        return JsExecutionResult(
          output: resolvedResult.stringResult,
          isError: resolvedResult.isError,
        );
      } on JsEvalResult catch (errorResult) {
        return JsExecutionResult(
          output: errorResult.stringResult,
          isError: true,
        );
      } catch (error) {
        return JsExecutionResult(output: error.toString(), isError: true);
      }
    });
  }

  @override
  void dispose() {
    _runtime.dispose();
  }

  Future<T> _runExclusive<T>(FutureOr<T> Function() action) {
    final completer = Completer<T>();
    _executionQueue = _executionQueue
        .catchError((_) {})
        .then((_) async {
          try {
            completer.complete(await action());
          } catch (error, stackTrace) {
            completer.completeError(error, stackTrace);
          }
        });
    return completer.future;
  }
}
