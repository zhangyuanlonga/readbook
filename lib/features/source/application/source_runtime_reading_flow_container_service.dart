import 'dart:async';

import '../../../domain/entities/book_identity.dart';
import '../../../runtime/sources/source_executor.dart';
import '../../../runtime/sources/source_registry.dart';
import '../../../runtime/sources/source_result_models.dart' as runtime_models;
import '../../../core/logging/app_logger.dart';
import 'source_runtime_request_execution_container.dart';

class SourceRuntimeReadingFlowExecutionContainer {
  const SourceRuntimeReadingFlowExecutionContainer({
    required this.sourceId,
    required this.flowKey,
    required this.source,
    required this.requestContainer,
  });

  final String sourceId;
  final String flowKey;
  final RegisteredSource source;
  final SourceRuntimeRequestExecutionContainer requestContainer;

  SourceExecutor get executor => requestContainer.executor;

  void dispose() {
    source.definition.dispose?.call();
    requestContainer.dispose();
  }
}

class SourceRuntimeReadingFlowContainerService {
  SourceRuntimeReadingFlowContainerService({
    AppLogger? logger,
    Duration disposalDelay = const Duration(seconds: 2),
  }) : _logger = logger ?? AppLogger.instance,
       _disposalDelay = disposalDelay;

  final Map<String, SourceRuntimeReadingFlowExecutionContainer> _containers =
      <String, SourceRuntimeReadingFlowExecutionContainer>{};
  final AppLogger _logger;
  final Duration _disposalDelay;
  final Map<SourceRuntimeReadingFlowExecutionContainer, Timer>
  _pendingDisposals = <SourceRuntimeReadingFlowExecutionContainer, Timer>{};

  SourceRuntimeReadingFlowExecutionContainer? get({
    required String sourceId,
    required runtime_models.Book book,
  }) {
    return _containers[_flowKeyOf(sourceId: sourceId, book: book)];
  }

  SourceRuntimeReadingFlowExecutionContainer put(
    SourceRuntimeReadingFlowExecutionContainer container,
  ) {
    final previous = _containers[container.flowKey];
    if (!identical(previous, container)) {
      if (previous != null) {
        _scheduleDisposal(previous, reason: 'replace');
      }
    }
    _containers[container.flowKey] = container;
    _logger.info(
      'Source runtime reading flow container created',
      context: <String, Object?>{
        'sourceId': container.sourceId,
        'sourceName': container.source.runtime.name,
        'flowKey': container.flowKey,
      },
    );
    return container;
  }

  void rebindFlow({
    required String sourceId,
    required runtime_models.Book fromBook,
    required runtime_models.Book toBook,
  }) {
    final oldKey = _flowKeyOf(sourceId: sourceId, book: fromBook);
    final newKey = _flowKeyOf(sourceId: sourceId, book: toBook);
    if (oldKey == newKey) {
      return;
    }
    final existing = _containers.remove(oldKey);
    if (existing == null) {
      return;
    }
    final rebound = SourceRuntimeReadingFlowExecutionContainer(
      sourceId: existing.sourceId,
      flowKey: newKey,
      source: existing.source,
      requestContainer: existing.requestContainer,
    );
    _logger.info(
      'Source runtime reading flow container rebound',
      context: <String, Object?>{
        'sourceId': existing.sourceId,
        'oldFlowKey': oldKey,
        'newFlowKey': newKey,
      },
    );
    put(rebound);
  }

  void clearFlow({
    required String sourceId,
    required runtime_models.Book book,
  }) {
    final flowKey = _flowKeyOf(sourceId: sourceId, book: book);
    final removed = _containers.remove(flowKey);
    if (removed != null) {
      _scheduleDisposal(removed, reason: 'clear_flow');
    }
  }

  void clearSource(String sourceId) {
    final normalized = sourceId.trim();
    if (normalized.isEmpty) {
      return;
    }
    final keys = _containers.keys
        .where((key) => key.startsWith('$normalized::'))
        .toList(growable: false);
    for (final key in keys) {
      final removed = _containers.remove(key);
      if (removed != null) {
        _scheduleDisposal(removed, reason: 'clear_source');
      }
    }
  }

  void clearAll() {
    for (final container in _containers.values) {
      _scheduleDisposal(container, reason: 'clear_all');
    }
    _containers.clear();
  }

  String flowKeyOf({
    required String sourceId,
    required runtime_models.Book book,
  }) {
    return _flowKeyOf(sourceId: sourceId, book: book);
  }

  String _flowKeyOf({
    required String sourceId,
    required runtime_models.Book book,
  }) {
    return SourceBookKey.forReadingFlow(
      sourceId: sourceId,
      detailUrl: book.detailUrl,
      tocUrl: book.tocUrl,
      title: book.title,
    ).storageKey;
  }

  void _scheduleDisposal(
    SourceRuntimeReadingFlowExecutionContainer container, {
    required String reason,
  }) {
    if (_pendingDisposals.containsKey(container)) {
      return;
    }
    _logger.info(
      'Source runtime reading flow container disposal scheduled',
      context: <String, Object?>{
        'sourceId': container.sourceId,
        'sourceName': container.source.runtime.name,
        'flowKey': container.flowKey,
        'reason': reason,
        'delayMs': _disposalDelay.inMilliseconds,
      },
    );
    _pendingDisposals[container] = Timer(_disposalDelay, () {
      _pendingDisposals.remove(container);
      container.dispose();
      _logger.info(
        'Source runtime reading flow container disposed',
        context: <String, Object?>{
          'sourceId': container.sourceId,
          'sourceName': container.source.runtime.name,
          'flowKey': container.flowKey,
          'reason': reason,
        },
      );
    });
  }
}
