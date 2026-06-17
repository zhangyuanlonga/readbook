import 'dart:async';

import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/errors/gateway_failure.dart';
import '../../../domain/entities/book.dart';

class SourceSearchFailure {
  const SourceSearchFailure({
    required this.sourceId,
    required this.sourceName,
    required this.message,
    required this.code,
    required this.stage,
    this.requestUrl,
    this.debugMessage,
    this.gatewayFailure,
  });

  final String sourceId;
  final String sourceName;
  final String message;
  final ErrorCode code;
  final ErrorStage stage;
  final String? requestUrl;
  final String? debugMessage;
  final GatewayFailure? gatewayFailure;

  String? get gatewayCode => gatewayFailure?.displayCode;
  bool get retryable => gatewayFailure?.retryable ?? code == ErrorCode.network;
  String? get hint => gatewayFailure?.displayHint;
}

class SearchExecutionReport {
  const SearchExecutionReport({
    required this.keyword,
    required this.sourceCount,
    required this.successSourceCount,
    required this.books,
    required this.failures,
    required this.sourceNames,
    this.bookSourceHitCounts = const <String, int>{},
    this.bookSourceHits = const <String, List<Book>>{},
    this.processedSourceCountOverride,
  });

  final String keyword;
  final int sourceCount;
  final int successSourceCount;
  final List<Book> books;
  final List<SourceSearchFailure> failures;
  final Map<String, String> sourceNames;
  final Map<String, int> bookSourceHitCounts;
  final Map<String, List<Book>> bookSourceHits;
  final int? processedSourceCountOverride;

  int get failedSourceCount => failures.length;
  int get processedSourceCount =>
      processedSourceCountOverride ?? successSourceCount + failedSourceCount;

  int sourceHitCountOf(Book book) => bookSourceHitCounts[book.id] ?? 1;

  List<Book> sourceHitsOf(Book book) {
    final hits = bookSourceHits[book.id];
    if (hits == null || hits.isEmpty) {
      return <Book>[book];
    }
    return hits;
  }
}

typedef SearchProgressCallback = void Function(SearchExecutionReport report);

enum SearchContentMode { novel, manga, audio }

enum SearchPlanScenario { globalSearch, switchSource, autoSwitchSource }

class SearchSourceSelection {
  const SearchSourceSelection({
    this.groupNames = const <String>{},
    this.sourceId,
  });

  final Set<String> groupNames;
  final String? sourceId;

  bool get isAll => groupNames.isEmpty && (sourceId ?? '').trim().isEmpty;

  SearchSourceSelection copyWith({Set<String>? groupNames, String? sourceId}) {
    return SearchSourceSelection(
      groupNames: groupNames ?? this.groupNames,
      sourceId: sourceId,
    );
  }

  static const all = SearchSourceSelection();
}

class SearchCancellationToken {
  bool _cancelled = false;
  bool _paused = false;
  Completer<void>? _resumeCompleter;

  bool get isCancelled => _cancelled;
  bool get isPaused => _paused && !_cancelled;

  void pause() {
    if (_cancelled || _paused) {
      return;
    }
    _paused = true;
    _resumeCompleter ??= Completer<void>();
  }

  void resume() {
    if (_cancelled || !_paused) {
      return;
    }
    _paused = false;
    _resumeCompleter?.complete();
    _resumeCompleter = null;
  }

  Future<void> waitIfPaused() async {
    while (!_cancelled && _paused) {
      final completer = _resumeCompleter ??= Completer<void>();
      await completer.future;
    }
  }

  void cancel() {
    if (_cancelled) {
      return;
    }
    _cancelled = true;
    _paused = false;
    _resumeCompleter?.complete();
    _resumeCompleter = null;
  }
}

class SearchSourceSnapshot {
  const SearchSourceSnapshot({
    required this.id,
    required this.name,
    this.group = '',
    this.revision = '',
    this.manifest = const <String, Object?>{},
  });

  final String id;
  final String name;
  final String group;
  final String revision;
  final Map<String, Object?> manifest;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'group': group,
      'revision': revision,
      if (manifest.isNotEmpty) 'manifest': manifest,
    };
  }
}
