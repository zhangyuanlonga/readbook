import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/script_source.dart';
import '../application/source_runtime_facade.dart';
import '../../../runtime/sources/source_result_models.dart' as runtime_models;

class SourceDebugWebService extends ChangeNotifier {
  SourceDebugWebService._();

  static final SourceDebugWebService instance = SourceDebugWebService._();

  static const int defaultPort = 15421;

  HttpServer? _server;
  StreamSubscription<HttpRequest>? _subscription;
  bool _isStarting = false;
  bool _isStopping = false;
  int? _port;
  DateTime? _startedAt;
  String? _lastErrorText;
  PackageInfo? _packageInfo;
  List<String> _advertisedBaseUrls = const <String>[];
  Future<void>? _startFuture;
  final SourceRuntimeFacade _sourceRuntimeFacade = SourceRuntimeFacade.instance;

  bool get isRunning => _server != null;

  bool get isStarting => _isStarting;

  bool get isStopping => _isStopping;

  int? get port => _port;

  DateTime? get startedAt => _startedAt;

  String? get lastErrorText => _lastErrorText;

  List<String> get advertisedBaseUrls =>
      List<String>.unmodifiable(_advertisedBaseUrls);

  Future<void> start({int port = defaultPort}) {
    final existingFuture = _startFuture;
    if (existingFuture != null) {
      return existingFuture;
    }
    if (isRunning) {
      return Future<void>.value();
    }
    final future = _startInternal(port: port);
    _startFuture = future;
    future.whenComplete(() {
      if (identical(_startFuture, future)) {
        _startFuture = null;
      }
    });
    return future;
  }

  Future<void> _startInternal({required int port}) async {
    _isStarting = true;
    _lastErrorText = null;
    notifyListeners();

    try {
      final server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );
      _server = server;
      _port = server.port;
      _startedAt = DateTime.now();
      _packageInfo = await _loadPackageInfo();
      await refreshAdvertisedBaseUrls();
      _subscription = server.listen(
        (HttpRequest request) {
          unawaited(_handleRequest(request));
        },
        onError: (Object error, StackTrace stackTrace) {
          _lastErrorText = error.toString();
          notifyListeners();
        },
      );
    } catch (error) {
      _lastErrorText = error.toString();
      rethrow;
    } finally {
      _isStarting = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    if (!isRunning && !_isStarting) {
      return;
    }
    _isStopping = true;
    notifyListeners();
    try {
      await _subscription?.cancel();
      _subscription = null;
      await _server?.close(force: true);
      _server = null;
      _port = null;
      _startedAt = null;
      _advertisedBaseUrls = const <String>[];
    } finally {
      _isStopping = false;
      notifyListeners();
    }
  }

  Future<void> refreshAdvertisedBaseUrls() async {
    final currentPort = _port;
    if (currentPort == null) {
      _advertisedBaseUrls = const <String>[];
      notifyListeners();
      return;
    }

    final urls = <String>{'http://127.0.0.1:$currentPort'};
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final NetworkInterface interface in interfaces) {
        for (final InternetAddress address in interface.addresses) {
          final host = address.address.trim();
          if (host.isEmpty) {
            continue;
          }
          urls.add('http://$host:$currentPort');
        }
      }
    } catch (error) {
      _lastErrorText = error.toString();
    }

    final sorted = urls.toList(growable: false)..sort((String a, String b) {
      final aLoopback = a.contains('127.0.0.1');
      final bLoopback = b.contains('127.0.0.1');
      if (aLoopback == bLoopback) {
        return a.compareTo(b);
      }
      return aLoopback ? 1 : -1;
    });
    _advertisedBaseUrls = sorted;
    notifyListeners();
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;
      final method = request.method.toUpperCase();
      if (request.method.toUpperCase() == 'OPTIONS') {
        _writeCorsHeaders(request.response);
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        return;
      }

      if (method == 'GET' && path == '/api/debug/ping') {
        await _writeJson(request.response, <String, Object?>{
          'ok': true,
          'data': _buildPingPayload(),
          'error': null,
          'meta': _buildMeta(),
        });
        return;
      }

      if (method == 'GET' && path == '/api/sources') {
        await _handleListSources(request);
        return;
      }

      if (method == 'POST' && path == '/api/debug/search') {
        await _handleDebugSearch(request);
        return;
      }

      if (method == 'POST' && path == '/api/debug/detail') {
        await _handleDebugDetail(request);
        return;
      }

      if (method == 'POST' && path == '/api/debug/chapters') {
        await _handleDebugChapters(request);
        return;
      }

      if (method == 'POST' && path == '/api/debug/content') {
        await _handleDebugContent(request);
        return;
      }

      if (method == 'POST' && path == '/api/debug/full-run') {
        await _handleDebugFullRun(request);
        return;
      }

      final sourceRouteMatch = RegExp(
        r'^/api/sources/([^/]+)$',
      ).firstMatch(path);
      final sourceEnabledRouteMatch = RegExp(
        r'^/api/sources/([^/]+)/enabled$',
      ).firstMatch(path);

      if (sourceEnabledRouteMatch != null && method == 'PATCH') {
        final sourceId = Uri.decodeComponent(sourceEnabledRouteMatch.group(1)!);
        await _handlePatchSourceEnabled(request, sourceId);
        return;
      }

      if (sourceRouteMatch != null) {
        final sourceId = Uri.decodeComponent(sourceRouteMatch.group(1)!);
        if (method == 'GET') {
          await _handleGetSource(request, sourceId);
          return;
        }
        if (method == 'PUT') {
          await _handleUpdateSource(request, sourceId);
          return;
        }
        if (method == 'DELETE') {
          await _handleDeleteSource(request, sourceId);
          return;
        }
      }

      if (method == 'POST' && path == '/api/sources') {
        await _handleCreateSource(request);
        return;
      }

      await _writeJson(request.response, <String, Object?>{
        'ok': false,
        'data': null,
        'error': <String, Object?>{
          'code': 'not_found',
          'message': '未找到接口：${request.method} $path',
          'stage': 'router',
        },
        'meta': _buildMeta(),
      }, statusCode: HttpStatus.notFound);
    } catch (error) {
      _lastErrorText = error.toString();
      await _writeJson(request.response, <String, Object?>{
        'ok': false,
        'data': null,
        'error': <String, Object?>{
          'code': 'internal_error',
          'message': '本地调试服务处理失败。',
          'detail': error.toString(),
          'stage': 'router',
        },
        'meta': _buildMeta(),
      }, statusCode: HttpStatus.internalServerError);
    }
  }

  Future<void> _handleListSources(HttpRequest request) async {
    try {
      final items = await _sourceRuntimeFacade.listScriptSources();
      await _writeSuccess(request.response, <String, Object?>{
        'items': items.map(_sourceSummaryToJson).toList(growable: false),
      });
    } catch (error) {
      await _writeFailure(
        request.response,
        code: 'list_sources_failed',
        message: '加载书源列表失败。',
        detail: error.toString(),
      );
    }
  }

  Future<void> _handleGetSource(HttpRequest request, String sourceId) async {
    try {
      final source = await _sourceRuntimeFacade.getScriptSourceById(sourceId);
      if (source == null) {
        await _writeFailure(
          request.response,
          code: 'not_found',
          message: '未找到书源：$sourceId',
          statusCode: HttpStatus.notFound,
        );
        return;
      }
      await _writeSuccess(request.response, <String, Object?>{
        'item': _sourceDetailToJson(source),
      });
    } catch (error) {
      await _writeFailure(
        request.response,
        code: 'get_source_failed',
        message: '加载书源详情失败。',
        detail: error.toString(),
      );
    }
  }

  Future<void> _handleCreateSource(HttpRequest request) async {
    try {
      final body = await _readJsonMap(request);
      final sourceCode = _readRequiredString(body, 'sourceCode');
      final enabled = _readBool(body['enabled']) ?? true;
      final saved = await _sourceRuntimeFacade.saveScriptSource(
        sourceCode: sourceCode,
        enabled: enabled,
      );
      await _writeSuccess(request.response, <String, Object?>{
        'item': _sourceDetailToJson(saved),
      }, statusCode: HttpStatus.created);
    } catch (error) {
      await _handleSourceMutationError(
        request.response,
        error,
        fallbackCode: 'create_source_failed',
        fallbackMessage: '创建书源失败。',
      );
    }
  }

  Future<void> _handleUpdateSource(HttpRequest request, String sourceId) async {
    try {
      final existing = await _sourceRuntimeFacade.getScriptSourceById(sourceId);
      if (existing == null) {
        await _writeFailure(
          request.response,
          code: 'not_found',
          message: '未找到书源：$sourceId',
          statusCode: HttpStatus.notFound,
        );
        return;
      }
      final body = await _readJsonMap(request);
      final sourceCode = _readRequiredString(body, 'sourceCode');
      final enabled = _readBool(body['enabled']) ?? existing.enabled;
      final saved = await _sourceRuntimeFacade.saveScriptSource(
        id: sourceId,
        sourceCode: sourceCode,
        enabled: enabled,
      );
      await _writeSuccess(request.response, <String, Object?>{
        'item': _sourceDetailToJson(saved),
      });
    } catch (error) {
      await _handleSourceMutationError(
        request.response,
        error,
        fallbackCode: 'update_source_failed',
        fallbackMessage: '更新书源失败。',
      );
    }
  }

  Future<void> _handlePatchSourceEnabled(
    HttpRequest request,
    String sourceId,
  ) async {
    try {
      final existing = await _sourceRuntimeFacade.getScriptSourceById(sourceId);
      if (existing == null) {
        await _writeFailure(
          request.response,
          code: 'not_found',
          message: '未找到书源：$sourceId',
          statusCode: HttpStatus.notFound,
        );
        return;
      }
      final body = await _readJsonMap(request);
      final enabled = _readBool(body['enabled']);
      if (enabled == null) {
        throw const _SourceDebugValidationException('字段 enabled 必须为布尔值。');
      }
      await _sourceRuntimeFacade.setScriptSourceEnabled(
        id: sourceId,
        enabled: enabled,
      );
      await _writeSuccess(request.response, <String, Object?>{
        'id': sourceId,
        'enabled': enabled,
      });
    } catch (error) {
      await _handleSourceMutationError(
        request.response,
        error,
        fallbackCode: 'patch_source_enabled_failed',
        fallbackMessage: '更新书源启用状态失败。',
      );
    }
  }

  Future<void> _handleDeleteSource(HttpRequest request, String sourceId) async {
    try {
      final existing = await _sourceRuntimeFacade.getScriptSourceById(sourceId);
      if (existing == null) {
        await _writeFailure(
          request.response,
          code: 'not_found',
          message: '未找到书源：$sourceId',
          statusCode: HttpStatus.notFound,
        );
        return;
      }
      await _sourceRuntimeFacade.deleteScriptSource(sourceId);
      await _writeSuccess(request.response, <String, Object?>{
        'id': sourceId,
        'deleted': true,
      });
    } catch (error) {
      await _writeFailure(
        request.response,
        code: 'delete_source_failed',
        message: '删除书源失败。',
        detail: error.toString(),
      );
    }
  }

  Future<void> _handleDebugSearch(HttpRequest request) async {
    final stopwatch = Stopwatch()..start();
    var sourceId = '';
    var keyword = '';
    try {
      final body = await _readJsonMap(request);
      sourceId = _readRequiredString(body, 'sourceId');
      keyword = _readRequiredString(body, 'keyword');
      final logs = <Object?>[
        _logEntry(
          level: 'info',
          step: 'search',
          message: '开始执行搜索',
          details: <String, Object?>{'sourceId': sourceId, 'keyword': keyword},
        ),
      ];
      final books = await _sourceRuntimeFacade.search(
        sourceId: sourceId,
        keyword: keyword,
      );
      stopwatch.stop();
      final runtimeArtifacts = _sourceRuntimeFacade.consumeLastDebugArtifacts(
        sourceId,
      );
      logs.add(
        _logEntry(
          level: books.isEmpty ? 'warn' : 'success',
          step: 'search',
          message: books.isEmpty ? '搜索无结果' : '搜索执行成功',
          details: <String, Object?>{
            'durationMs': stopwatch.elapsedMilliseconds,
            'summary': _summarizeBooks(books),
          },
        ),
      );
      final traces = <Object?>[
        _traceEntry(
          step: 'search',
          label: 'runtime.search',
          sourceId: sourceId,
          durationMs: stopwatch.elapsedMilliseconds,
          status: books.isEmpty ? 'empty' : 'ok',
          request: <String, Object?>{'keyword': keyword},
          resultSummary: _summarizeBooks(books),
        ),
        ...runtimeArtifacts.traces,
      ];
      await _writeSuccess(request.response, <String, Object?>{
        'sourceId': sourceId,
        'step': 'search',
        'durationMs': stopwatch.elapsedMilliseconds,
        'result': books.map(_bookToJson).toList(growable: false),
        'logs': _mergeLogs(logs, runtimeArtifacts.logs),
        'traces': traces,
      });
    } catch (error) {
      stopwatch.stop();
      await _handleDebugExecutionError(
        request.response,
        error,
        step: 'search',
        durationMs: stopwatch.elapsedMilliseconds,
        requestSummary: <String, Object?>{
          if (sourceId.isNotEmpty) 'sourceId': sourceId,
          if (keyword.isNotEmpty) 'keyword': keyword,
        },
      );
    }
  }

  Future<void> _handleDebugDetail(HttpRequest request) async {
    final stopwatch = Stopwatch()..start();
    var sourceId = '';
    runtime_models.Book? book;
    try {
      final body = await _readJsonMap(request);
      sourceId = _readRequiredString(body, 'sourceId');
      book = _readRequiredBook(body, sourceId);
      final logs = <Object?>[
        _logEntry(
          level: 'info',
          step: 'detail',
          message: '开始获取详情',
          details: <String, Object?>{
            'sourceId': sourceId,
            'book': _summarizeBook(book),
          },
        ),
      ];
      final detail = await _sourceRuntimeFacade.detail(
        sourceId: sourceId,
        book: book,
      );
      stopwatch.stop();
      final runtimeArtifacts = _sourceRuntimeFacade.consumeLastDebugArtifacts(
        sourceId,
      );
      logs.add(
        _logEntry(
          level: 'success',
          step: 'detail',
          message: '详情获取成功',
          details: <String, Object?>{
            'durationMs': stopwatch.elapsedMilliseconds,
            'summary': _summarizeBook(detail),
          },
        ),
      );
      final traces = <Object?>[
        _traceEntry(
          step: 'detail',
          label: 'runtime.detail',
          sourceId: sourceId,
          durationMs: stopwatch.elapsedMilliseconds,
          status: 'ok',
          request: <String, Object?>{'book': _summarizeBook(book)},
          resultSummary: _summarizeBook(detail),
        ),
        ...runtimeArtifacts.traces,
      ];
      await _writeSuccess(request.response, <String, Object?>{
        'sourceId': sourceId,
        'step': 'detail',
        'durationMs': stopwatch.elapsedMilliseconds,
        'result': _bookToJson(detail),
        'logs': _mergeLogs(logs, runtimeArtifacts.logs),
        'traces': traces,
      });
    } catch (error) {
      stopwatch.stop();
      await _handleDebugExecutionError(
        request.response,
        error,
        step: 'detail',
        durationMs: stopwatch.elapsedMilliseconds,
        requestSummary: <String, Object?>{
          if (sourceId.isNotEmpty) 'sourceId': sourceId,
          if (book != null) 'book': _summarizeBook(book),
        },
      );
    }
  }

  Future<void> _handleDebugChapters(HttpRequest request) async {
    final stopwatch = Stopwatch()..start();
    var sourceId = '';
    runtime_models.Book? book;
    try {
      final body = await _readJsonMap(request);
      sourceId = _readRequiredString(body, 'sourceId');
      book = _readRequiredBook(body, sourceId);
      final logs = <Object?>[
        _logEntry(
          level: 'info',
          step: 'chapters',
          message: '开始获取目录',
          details: <String, Object?>{
            'sourceId': sourceId,
            'book': _summarizeBook(book),
          },
        ),
      ];
      final chapters = await _sourceRuntimeFacade.chapters(
        sourceId: sourceId,
        book: book,
      );
      stopwatch.stop();
      final runtimeArtifacts = _sourceRuntimeFacade.consumeLastDebugArtifacts(
        sourceId,
      );
      logs.add(
        _logEntry(
          level: chapters.isEmpty ? 'warn' : 'success',
          step: 'chapters',
          message: chapters.isEmpty ? '目录为空' : '目录获取成功',
          details: <String, Object?>{
            'durationMs': stopwatch.elapsedMilliseconds,
            'summary': _summarizeChapters(chapters),
          },
        ),
      );
      final traces = <Object?>[
        _traceEntry(
          step: 'chapters',
          label: 'runtime.chapters',
          sourceId: sourceId,
          durationMs: stopwatch.elapsedMilliseconds,
          status: chapters.isEmpty ? 'empty' : 'ok',
          request: <String, Object?>{'book': _summarizeBook(book)},
          resultSummary: _summarizeChapters(chapters),
        ),
        ...runtimeArtifacts.traces,
      ];
      await _writeSuccess(request.response, <String, Object?>{
        'sourceId': sourceId,
        'step': 'chapters',
        'durationMs': stopwatch.elapsedMilliseconds,
        'result': chapters.map(_chapterToJson).toList(growable: false),
        'logs': _mergeLogs(logs, runtimeArtifacts.logs),
        'traces': traces,
      });
    } catch (error) {
      stopwatch.stop();
      await _handleDebugExecutionError(
        request.response,
        error,
        step: 'chapters',
        durationMs: stopwatch.elapsedMilliseconds,
        requestSummary: <String, Object?>{
          if (sourceId.isNotEmpty) 'sourceId': sourceId,
          if (book != null) 'book': _summarizeBook(book),
        },
      );
    }
  }

  Future<void> _handleDebugContent(HttpRequest request) async {
    final stopwatch = Stopwatch()..start();
    var sourceId = '';
    runtime_models.Book? book;
    runtime_models.Chapter? chapter;
    try {
      final body = await _readJsonMap(request);
      sourceId = _readRequiredString(body, 'sourceId');
      book = _readRequiredBook(body, sourceId);
      chapter = _readRequiredChapter(body, sourceId);
      final logs = <Object?>[
        _logEntry(
          level: 'info',
          step: 'content',
          message: '开始获取正文',
          details: <String, Object?>{
            'sourceId': sourceId,
            'book': _summarizeBook(book),
            'chapter': _summarizeChapter(chapter),
          },
        ),
      ];
      final content = await _sourceRuntimeFacade.content(
        sourceId: sourceId,
        book: book,
        chapter: chapter,
      );
      stopwatch.stop();
      final runtimeArtifacts = _sourceRuntimeFacade.consumeLastDebugArtifacts(
        sourceId,
      );
      logs.add(
        _logEntry(
          level: content.content.trim().isEmpty ? 'warn' : 'success',
          step: 'content',
          message: content.content.trim().isEmpty ? '正文为空' : '正文获取成功',
          details: <String, Object?>{
            'durationMs': stopwatch.elapsedMilliseconds,
            'summary': _summarizeContent(content),
          },
        ),
      );
      final traces = <Object?>[
        _traceEntry(
          step: 'content',
          label: 'runtime.content',
          sourceId: sourceId,
          durationMs: stopwatch.elapsedMilliseconds,
          status: content.content.trim().isEmpty ? 'empty' : 'ok',
          request: <String, Object?>{
            'book': _summarizeBook(book),
            'chapter': _summarizeChapter(chapter),
          },
          resultSummary: _summarizeContent(content),
        ),
        ...runtimeArtifacts.traces,
      ];
      await _writeSuccess(request.response, <String, Object?>{
        'sourceId': sourceId,
        'step': 'content',
        'durationMs': stopwatch.elapsedMilliseconds,
        'result': _contentToJson(content),
        'logs': _mergeLogs(logs, runtimeArtifacts.logs),
        'traces': traces,
      });
    } catch (error) {
      stopwatch.stop();
      await _handleDebugExecutionError(
        request.response,
        error,
        step: 'content',
        durationMs: stopwatch.elapsedMilliseconds,
        requestSummary: <String, Object?>{
          if (sourceId.isNotEmpty) 'sourceId': sourceId,
          if (book != null) 'book': _summarizeBook(book),
          if (chapter != null) 'chapter': _summarizeChapter(chapter),
        },
      );
    }
  }

  Future<void> _handleDebugFullRun(HttpRequest request) async {
    final stopwatch = Stopwatch()..start();
    var sourceId = '';
    var keyword = '';
    try {
      final body = await _readJsonMap(request);
      sourceId = _readRequiredString(body, 'sourceId');
      keyword = _readRequiredString(body, 'keyword');

      final stages = <Map<String, Object?>>[];
      final outputs = <String, Object?>{};
      final logs = <Object?>[
        _logEntry(
          level: 'info',
          step: 'full-run',
          message: '开始完整链路调试',
          details: <String, Object?>{'sourceId': sourceId, 'keyword': keyword},
        ),
      ];
      final traces = <Object?>[
        _traceEntry(
          step: 'full-run',
          label: 'runtime.full-run.start',
          sourceId: sourceId,
          status: 'started',
          request: <String, Object?>{'keyword': keyword},
        ),
      ];
      var overallOk = true;

      final searchWatch = Stopwatch()..start();
      List<runtime_models.Book> books = const <runtime_models.Book>[];
      try {
        books = await _sourceRuntimeFacade.search(
          sourceId: sourceId,
          keyword: keyword,
        );
        searchWatch.stop();
        final runtimeArtifacts = _sourceRuntimeFacade.consumeLastDebugArtifacts(
          sourceId,
        );
        outputs['search'] = books.map(_bookToJson).toList(growable: false);
        stages.add(<String, Object?>{
          'step': 'search',
          'ok': books.isNotEmpty,
          'durationMs': searchWatch.elapsedMilliseconds,
          'summary': books.isEmpty ? '搜索无结果' : '返回 ${books.length} 本书',
        });
        logs.add(
          _logEntry(
            level: books.isEmpty ? 'warn' : 'success',
            step: 'search',
            message: books.isEmpty ? '搜索无结果' : '搜索执行成功',
            details: <String, Object?>{
              'durationMs': searchWatch.elapsedMilliseconds,
              'summary': _summarizeBooks(books),
            },
          ),
        );
        traces.add(
          _traceEntry(
            step: 'search',
            label: 'runtime.search',
            sourceId: sourceId,
            durationMs: searchWatch.elapsedMilliseconds,
            status: books.isEmpty ? 'empty' : 'ok',
            request: <String, Object?>{'keyword': keyword},
            resultSummary: _summarizeBooks(books),
          ),
        );
        traces.addAll(runtimeArtifacts.traces);
        logs.addAll(runtimeArtifacts.logs);
        if (books.isEmpty) {
          overallOk = false;
        }
      } catch (error) {
        searchWatch.stop();
        final runtimeArtifacts = _sourceRuntimeFacade.consumeLastDebugArtifacts(
          sourceId,
        );
        stages.add(
          _failedStage('search', searchWatch.elapsedMilliseconds, error),
        );
        outputs['search'] = const <Object?>[];
        logs.add(
          _logEntry(
            level: 'error',
            step: 'search',
            message: '搜索执行失败',
            details: <String, Object?>{
              'durationMs': searchWatch.elapsedMilliseconds,
              'error': _errorSummary(error),
            },
          ),
        );
        traces.add(
          _traceEntry(
            step: 'search',
            label: 'runtime.search',
            sourceId: sourceId,
            durationMs: searchWatch.elapsedMilliseconds,
            status: 'failed',
            request: <String, Object?>{'keyword': keyword},
            resultSummary: _errorSummary(error),
          ),
        );
        traces.addAll(runtimeArtifacts.traces);
        logs.addAll(runtimeArtifacts.logs);
        overallOk = false;
      }

      runtime_models.Book? detailBook;
      if (overallOk && books.isNotEmpty) {
        final detailWatch = Stopwatch()..start();
        try {
          detailBook = await _sourceRuntimeFacade.detail(
            sourceId: sourceId,
            book: books.first,
          );
          detailWatch.stop();
          final runtimeArtifacts = _sourceRuntimeFacade
              .consumeLastDebugArtifacts(sourceId);
          outputs['detail'] = _bookToJson(detailBook);
          stages.add(<String, Object?>{
            'step': 'detail',
            'ok': true,
            'durationMs': detailWatch.elapsedMilliseconds,
            'summary': '详情获取成功',
          });
          logs.add(
            _logEntry(
              level: 'success',
              step: 'detail',
              message: '详情获取成功',
              details: <String, Object?>{
                'durationMs': detailWatch.elapsedMilliseconds,
                'summary': _summarizeBook(detailBook),
              },
            ),
          );
          traces.add(
            _traceEntry(
              step: 'detail',
              label: 'runtime.detail',
              sourceId: sourceId,
              durationMs: detailWatch.elapsedMilliseconds,
              status: 'ok',
              request: <String, Object?>{'book': _summarizeBook(books.first)},
              resultSummary: _summarizeBook(detailBook),
            ),
          );
          traces.addAll(runtimeArtifacts.traces);
          logs.addAll(runtimeArtifacts.logs);
        } catch (error) {
          detailWatch.stop();
          final runtimeArtifacts = _sourceRuntimeFacade
              .consumeLastDebugArtifacts(sourceId);
          stages.add(
            _failedStage('detail', detailWatch.elapsedMilliseconds, error),
          );
          outputs['detail'] = null;
          logs.add(
            _logEntry(
              level: 'error',
              step: 'detail',
              message: '详情获取失败',
              details: <String, Object?>{
                'durationMs': detailWatch.elapsedMilliseconds,
                'error': _errorSummary(error),
              },
            ),
          );
          traces.add(
            _traceEntry(
              step: 'detail',
              label: 'runtime.detail',
              sourceId: sourceId,
              durationMs: detailWatch.elapsedMilliseconds,
              status: 'failed',
              request: <String, Object?>{'book': _summarizeBook(books.first)},
              resultSummary: _errorSummary(error),
            ),
          );
          traces.addAll(runtimeArtifacts.traces);
          logs.addAll(runtimeArtifacts.logs);
          overallOk = false;
        }
      } else {
        outputs['detail'] = null;
      }

      List<runtime_models.Chapter> chapters = const <runtime_models.Chapter>[];
      if (overallOk && detailBook != null) {
        final chaptersWatch = Stopwatch()..start();
        try {
          chapters = await _sourceRuntimeFacade.chapters(
            sourceId: sourceId,
            book: detailBook,
          );
          chaptersWatch.stop();
          final runtimeArtifacts = _sourceRuntimeFacade
              .consumeLastDebugArtifacts(sourceId);
          outputs['chapters'] = chapters
              .map(_chapterToJson)
              .toList(growable: false);
          stages.add(<String, Object?>{
            'step': 'chapters',
            'ok': chapters.isNotEmpty,
            'durationMs': chaptersWatch.elapsedMilliseconds,
            'summary': chapters.isEmpty ? '目录为空' : '返回 ${chapters.length} 章',
          });
          logs.add(
            _logEntry(
              level: chapters.isEmpty ? 'warn' : 'success',
              step: 'chapters',
              message: chapters.isEmpty ? '目录为空' : '目录获取成功',
              details: <String, Object?>{
                'durationMs': chaptersWatch.elapsedMilliseconds,
                'summary': _summarizeChapters(chapters),
              },
            ),
          );
          traces.add(
            _traceEntry(
              step: 'chapters',
              label: 'runtime.chapters',
              sourceId: sourceId,
              durationMs: chaptersWatch.elapsedMilliseconds,
              status: chapters.isEmpty ? 'empty' : 'ok',
              request: <String, Object?>{'book': _summarizeBook(detailBook)},
              resultSummary: _summarizeChapters(chapters),
            ),
          );
          traces.addAll(runtimeArtifacts.traces);
          logs.addAll(runtimeArtifacts.logs);
          if (chapters.isEmpty) {
            overallOk = false;
          }
        } catch (error) {
          chaptersWatch.stop();
          final runtimeArtifacts = _sourceRuntimeFacade
              .consumeLastDebugArtifacts(sourceId);
          stages.add(
            _failedStage('chapters', chaptersWatch.elapsedMilliseconds, error),
          );
          outputs['chapters'] = const <Object?>[];
          logs.add(
            _logEntry(
              level: 'error',
              step: 'chapters',
              message: '目录获取失败',
              details: <String, Object?>{
                'durationMs': chaptersWatch.elapsedMilliseconds,
                'error': _errorSummary(error),
              },
            ),
          );
          traces.add(
            _traceEntry(
              step: 'chapters',
              label: 'runtime.chapters',
              sourceId: sourceId,
              durationMs: chaptersWatch.elapsedMilliseconds,
              status: 'failed',
              request: <String, Object?>{'book': _summarizeBook(detailBook)},
              resultSummary: _errorSummary(error),
            ),
          );
          traces.addAll(runtimeArtifacts.traces);
          logs.addAll(runtimeArtifacts.logs);
          overallOk = false;
        }
      } else {
        outputs['chapters'] = const <Object?>[];
      }

      if (overallOk && detailBook != null && chapters.isNotEmpty) {
        final contentWatch = Stopwatch()..start();
        try {
          final content = await _sourceRuntimeFacade.content(
            sourceId: sourceId,
            book: detailBook,
            chapter: chapters.first,
          );
          contentWatch.stop();
          final runtimeArtifacts = _sourceRuntimeFacade
              .consumeLastDebugArtifacts(sourceId);
          outputs['content'] = _contentToJson(content);
          stages.add(<String, Object?>{
            'step': 'content',
            'ok': true,
            'durationMs': contentWatch.elapsedMilliseconds,
            'summary': '正文获取成功',
          });
          logs.add(
            _logEntry(
              level: content.content.trim().isEmpty ? 'warn' : 'success',
              step: 'content',
              message: content.content.trim().isEmpty ? '正文为空' : '正文获取成功',
              details: <String, Object?>{
                'durationMs': contentWatch.elapsedMilliseconds,
                'summary': _summarizeContent(content),
              },
            ),
          );
          traces.add(
            _traceEntry(
              step: 'content',
              label: 'runtime.content',
              sourceId: sourceId,
              durationMs: contentWatch.elapsedMilliseconds,
              status: content.content.trim().isEmpty ? 'empty' : 'ok',
              request: <String, Object?>{
                'book': _summarizeBook(detailBook),
                'chapter': _summarizeChapter(chapters.first),
              },
              resultSummary: _summarizeContent(content),
            ),
          );
          traces.addAll(runtimeArtifacts.traces);
          logs.addAll(runtimeArtifacts.logs);
        } catch (error) {
          contentWatch.stop();
          final runtimeArtifacts = _sourceRuntimeFacade
              .consumeLastDebugArtifacts(sourceId);
          stages.add(
            _failedStage('content', contentWatch.elapsedMilliseconds, error),
          );
          outputs['content'] = null;
          logs.add(
            _logEntry(
              level: 'error',
              step: 'content',
              message: '正文获取失败',
              details: <String, Object?>{
                'durationMs': contentWatch.elapsedMilliseconds,
                'error': _errorSummary(error),
              },
            ),
          );
          traces.add(
            _traceEntry(
              step: 'content',
              label: 'runtime.content',
              sourceId: sourceId,
              durationMs: contentWatch.elapsedMilliseconds,
              status: 'failed',
              request: <String, Object?>{
                'book': _summarizeBook(detailBook),
                'chapter': _summarizeChapter(chapters.first),
              },
              resultSummary: _errorSummary(error),
            ),
          );
          traces.addAll(runtimeArtifacts.traces);
          logs.addAll(runtimeArtifacts.logs);
          overallOk = false;
        }
      } else {
        outputs['content'] = null;
      }

      stopwatch.stop();
      logs.add(
        _logEntry(
          level: overallOk ? 'success' : 'warn',
          step: 'full-run',
          message: overallOk ? '完整链路执行成功' : '完整链路执行完成，但存在失败阶段',
          details: <String, Object?>{
            'durationMs': stopwatch.elapsedMilliseconds,
            'stageCount': stages.length,
          },
        ),
      );
      traces.add(
        _traceEntry(
          step: 'full-run',
          label: 'runtime.full-run.finish',
          sourceId: sourceId,
          durationMs: stopwatch.elapsedMilliseconds,
          status: overallOk ? 'ok' : 'partial',
          request: <String, Object?>{'keyword': keyword},
          resultSummary: 'stages=${stages.length}',
        ),
      );
      await _writeSuccess(request.response, <String, Object?>{
        'sourceId': sourceId,
        'step': 'full-run',
        'usedKeyword': keyword,
        'durationMs': stopwatch.elapsedMilliseconds,
        'overallOk': overallOk,
        'stages': stages,
        'outputs': outputs,
        'logs': logs,
        'traces': traces,
      });
    } catch (error) {
      stopwatch.stop();
      await _handleDebugExecutionError(
        request.response,
        error,
        step: 'full-run',
        durationMs: stopwatch.elapsedMilliseconds,
        requestSummary: <String, Object?>{
          if (sourceId.isNotEmpty) 'sourceId': sourceId,
          if (keyword.isNotEmpty) 'keyword': keyword,
        },
      );
    }
  }

  Future<Map<String, Object?>> _readJsonMap(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    if (raw.trim().isEmpty) {
      return <String, Object?>{};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const _SourceDebugValidationException('请求体必须为 JSON 对象。');
    }
    return Map<String, Object?>.from(
      decoded.map((Object? key, Object? value) {
        return MapEntry(key.toString(), value);
      }),
    );
  }

  String _readRequiredString(Map<String, Object?> body, String key) {
    final value = body[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      throw _SourceDebugValidationException('字段 $key 不能为空。');
    }
    return value;
  }

  runtime_models.Book _readRequiredBook(
    Map<String, Object?> body,
    String sourceId,
  ) {
    final raw = body['book'];
    if (raw is! Map) {
      throw const _SourceDebugValidationException('字段 book 必须为对象。');
    }
    return runtime_models.Book.fromMap(
      Map<String, dynamic>.from(
        raw.map((Object? key, Object? value) {
          return MapEntry(key.toString(), value);
        }),
      ),
      fallbackSourceId: sourceId,
    );
  }

  runtime_models.Chapter _readRequiredChapter(
    Map<String, Object?> body,
    String sourceId,
  ) {
    final raw = body['chapter'];
    if (raw is! Map) {
      throw const _SourceDebugValidationException('字段 chapter 必须为对象。');
    }
    return runtime_models.Chapter.fromMap(
      Map<String, dynamic>.from(
        raw.map((Object? key, Object? value) {
          return MapEntry(key.toString(), value);
        }),
      ),
      fallbackSourceId: sourceId,
    );
  }

  bool? _readBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
    return null;
  }

  Future<void> _handleSourceMutationError(
    HttpResponse response,
    Object error, {
    required String fallbackCode,
    required String fallbackMessage,
  }) async {
    if (error is _SourceDebugValidationException) {
      await _writeFailure(
        response,
        code: 'validation_error',
        message: error.message,
        statusCode: HttpStatus.badRequest,
      );
      return;
    }
    if (error is AppException) {
      await _writeFailure(
        response,
        code: error.code.name,
        message: error.briefMessage,
        detail: error.toString(),
        stage: error.stage.name,
        statusCode: HttpStatus.badRequest,
      );
      return;
    }
    if (error is StateError || error is FormatException) {
      await _writeFailure(
        response,
        code: 'validation_error',
        message: error.toString(),
        statusCode: HttpStatus.badRequest,
      );
      return;
    }
    await _writeFailure(
      response,
      code: fallbackCode,
      message: fallbackMessage,
      detail: error.toString(),
    );
  }

  Map<String, Object?> _sourceSummaryToJson(ScriptSource source) {
    return <String, Object?>{
      'id': source.id,
      'name': source.name,
      'group': source.group,
      'author': source.author,
      'description': source.description,
      'checkKeyword': source.checkKeyword,
      'enabled': source.enabled,
      'createdAt': source.createdAt.toIso8601String(),
      'updatedAt': source.updatedAt.toIso8601String(),
    };
  }

  Map<String, Object?> _sourceDetailToJson(ScriptSource source) {
    return <String, Object?>{
      ..._sourceSummaryToJson(source),
      'sourceCode': source.sourceCode,
      'primaryHost': source.primaryHost,
      'registrableDomain': source.registrableDomain,
      'clusterKey': source.clusterKey,
    };
  }

  Map<String, Object?> _bookToJson(runtime_models.Book book) {
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

  Map<String, Object?> _chapterToJson(runtime_models.Chapter chapter) {
    return <String, Object?>{
      'title': chapter.title,
      'url': chapter.url,
      'index': chapter.index,
      'isVolume': chapter.isVolume,
      'vip': chapter.vip,
      'isPay': chapter.isPay,
      'updateTime': chapter.updateTime,
      'sourceId': chapter.sourceId,
      'extra': chapter.extra,
      'debug': chapter.debug,
    };
  }

  Map<String, Object?> _contentToJson(runtime_models.Content content) {
    return <String, Object?>{
      'title': content.title,
      'content': content.content,
      'nextUrl': content.nextUrl,
      'images': content.images,
      'sourceId': content.sourceId,
      'extra': content.extra,
      'debug': content.debug,
    };
  }

  Map<String, Object?> _logEntry({
    required String level,
    required String step,
    required String message,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    return <String, Object?>{
      'at': DateTime.now().toIso8601String(),
      'level': level,
      'step': step,
      'message': message,
      if (details.isNotEmpty) ...details,
    };
  }

  Map<String, Object?> _traceEntry({
    required String step,
    required String label,
    required String sourceId,
    String status = 'ok',
    int? durationMs,
    Map<String, Object?> request = const <String, Object?>{},
    String? resultSummary,
  }) {
    return <String, Object?>{
      'type': 'runtime',
      'label': label,
      'step': step,
      'sourceId': sourceId,
      'status': status,
      if (durationMs != null) 'durationMs': durationMs,
      if (request.isNotEmpty) 'request': request,
      if (resultSummary != null && resultSummary.trim().isNotEmpty)
        'resultSummary': resultSummary,
      'at': DateTime.now().toIso8601String(),
    };
  }

  String _summarizeBooks(List<runtime_models.Book> books) {
    if (books.isEmpty) {
      return 'count=0';
    }
    final first = books.first;
    return 'count=${books.length}, first=${first.title}/${first.author}';
  }

  String _summarizeBook(runtime_models.Book book) {
    return '${book.title}/${book.author}, detailUrl=${book.detailUrl}, tocUrl=${book.tocUrl}';
  }

  String _summarizeChapters(List<runtime_models.Chapter> chapters) {
    if (chapters.isEmpty) {
      return 'count=0';
    }
    final first = chapters.first;
    return 'count=${chapters.length}, first=${first.index + 1}.${first.title}';
  }

  String _summarizeChapter(runtime_models.Chapter chapter) {
    return '${chapter.index + 1}.${chapter.title}, url=${chapter.url}';
  }

  String _summarizeContent(runtime_models.Content content) {
    final textLength = content.content.trim().length;
    return 'title=${content.title}, textLength=$textLength, images=${content.images.length}';
  }

  String _errorSummary(Object error) {
    if (error is AppException) {
      return '${error.code.name}:${error.briefMessage}';
    }
    return error.toString();
  }

  List<Object?> _mergeLogs(
    List<Object?> baseLogs,
    List<Map<String, Object?>> runtimeLogs,
  ) {
    if (runtimeLogs.isEmpty) {
      return baseLogs;
    }
    return <Object?>[...baseLogs, ...runtimeLogs];
  }

  Map<String, Object?> _failedStage(String step, int durationMs, Object error) {
    if (error is AppException) {
      return <String, Object?>{
        'step': step,
        'ok': false,
        'durationMs': durationMs,
        'summary': error.briefMessage,
        'error': <String, Object?>{
          'code': error.code.name,
          'message': error.briefMessage,
          'stage': error.stage.name,
          'detail': error.toString(),
        },
      };
    }
    return <String, Object?>{
      'step': step,
      'ok': false,
      'durationMs': durationMs,
      'summary': error.toString(),
      'error': <String, Object?>{
        'code': 'runtime_error',
        'message': error.toString(),
        'stage': step,
      },
    };
  }

  Map<String, Object?> _buildPingPayload() {
    final startedAt = _startedAt;
    final now = DateTime.now();
    return <String, Object?>{
      'service': 'source-debug-web',
      'version': _packageInfo?.version ?? 'unknown',
      'buildNumber': _packageInfo?.buildNumber ?? '',
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      'deviceName':
          kIsWeb
              ? 'web'
              : Platform.localHostname.trim().isEmpty
              ? 'unknown'
              : Platform.localHostname.trim(),
      'port': _port,
      'baseUrls': advertisedBaseUrls,
      'startedAt': startedAt?.toIso8601String(),
      'uptimeMs':
          startedAt == null ? 0 : now.difference(startedAt).inMilliseconds,
    };
  }

  Map<String, Object?> _buildMeta() {
    return <String, Object?>{
      'requestId': 'req_${DateTime.now().microsecondsSinceEpoch}',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _writeJson(
    HttpResponse response,
    Map<String, Object?> body, {
    int statusCode = HttpStatus.ok,
  }) async {
    _writeCorsHeaders(response);
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }

  Future<void> _writeSuccess(
    HttpResponse response,
    Map<String, Object?> data, {
    int statusCode = HttpStatus.ok,
  }) {
    return _writeJson(response, <String, Object?>{
      'ok': true,
      'data': data,
      'error': null,
      'meta': _buildMeta(),
    }, statusCode: statusCode);
  }

  Future<void> _writeFailure(
    HttpResponse response, {
    required String code,
    required String message,
    String? detail,
    String? stage,
    int statusCode = HttpStatus.internalServerError,
  }) {
    return _writeJson(response, <String, Object?>{
      'ok': false,
      'data': null,
      'error': <String, Object?>{
        'code': code,
        'message': message,
        if (stage != null && stage.trim().isNotEmpty) 'stage': stage,
        if (detail != null && detail.trim().isNotEmpty) 'detail': detail,
      },
      'meta': _buildMeta(),
    }, statusCode: statusCode);
  }

  Future<void> _handleDebugExecutionError(
    HttpResponse response,
    Object error, {
    required String step,
    required int durationMs,
    Map<String, Object?> requestSummary = const <String, Object?>{},
  }) async {
    final logs = <Object?>[
      _logEntry(
        level: 'error',
        step: step,
        message: '调试执行失败',
        details: <String, Object?>{
          'durationMs': durationMs,
          'error': _errorSummary(error),
        },
      ),
    ];
    final sourceId = requestSummary['sourceId']?.toString().trim() ?? '';
    final runtimeArtifacts =
        sourceId.isEmpty
            ? const SourceRuntimeDebugArtifactsSnapshot()
            : _sourceRuntimeFacade.consumeLastDebugArtifacts(sourceId);
    final traces = <Object?>[
      _traceEntry(
        step: step,
        label: 'runtime.$step',
        sourceId: sourceId,
        durationMs: durationMs,
        status: 'failed',
        request: requestSummary,
        resultSummary: _errorSummary(error),
      ),
      ...runtimeArtifacts.traces,
    ];
    if (error is _SourceDebugValidationException) {
      await _writeFailure(
        response,
        code: 'validation_error',
        message: error.message,
        stage: step,
        detail: jsonEncode(<String, Object?>{
          'durationMs': durationMs,
          'logs': _mergeLogs(logs, runtimeArtifacts.logs),
          'traces': traces,
        }),
        statusCode: HttpStatus.badRequest,
      );
      return;
    }
    if (error is AppException) {
      await _writeFailure(
        response,
        code: error.code.name,
        message: error.briefMessage,
        stage: error.stage.name,
        detail: jsonEncode(<String, Object?>{
          'error': error.toString(),
          'durationMs': durationMs,
          'logs': _mergeLogs(logs, runtimeArtifacts.logs),
          'traces': traces,
        }),
        statusCode: HttpStatus.badRequest,
      );
      return;
    }
    await _writeFailure(
      response,
      code: 'runtime_error',
      message: '调试执行失败。',
      stage: step,
      detail: jsonEncode(<String, Object?>{
        'error': error.toString(),
        'durationMs': durationMs,
        'logs': _mergeLogs(logs, runtimeArtifacts.logs),
        'traces': traces,
      }),
      statusCode: HttpStatus.internalServerError,
    );
  }

  void _writeCorsHeaders(HttpResponse response) {
    response.headers.set(HttpHeaders.accessControlAllowOriginHeader, '*');
    response.headers.set(
      HttpHeaders.accessControlAllowMethodsHeader,
      'GET,POST,PUT,PATCH,DELETE,OPTIONS',
    );
    response.headers.set(
      HttpHeaders.accessControlAllowHeadersHeader,
      'Content-Type, X-Requested-With',
    );
    response.headers.set(HttpHeaders.accessControlMaxAgeHeader, '86400');
  }

  Future<PackageInfo?> _loadPackageInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (_) {
      return null;
    }
  }
}

class _SourceDebugValidationException implements Exception {
  const _SourceDebugValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}
