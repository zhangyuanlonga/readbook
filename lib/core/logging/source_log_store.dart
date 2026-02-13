import 'dart:async';

import '../errors/app_exception.dart';

enum AppLogLevel { info, warn, error }

class AppLogEntry {
  const AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.context = const {},
    this.exception,
  });

  final DateTime timestamp;
  final AppLogLevel level;
  final String message;
  final Map<String, Object?> context;
  final AppException? exception;

  Map<String, Object?> get details {
    return <String, Object?>{
      ...context,
      if (exception != null) ...{
        'code': exception!.code.name,
        'stage': exception!.stage.name,
        'sourceId': exception!.sourceId,
        'requestUrl': exception!.requestUrl,
        'briefMessage': exception!.briefMessage,
      },
    }..removeWhere((key, value) => value == null);
  }

  String toMultilineText() {
    final buffer =
        StringBuffer()
          ..writeln(
            '[${timestamp.toIso8601String()}] ${level.name.toUpperCase()}',
          )
          ..writeln(message);

    final detailEntries = details.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in detailEntries) {
      buffer.writeln('${entry.key}: ${entry.value}');
    }

    return buffer.toString().trimRight();
  }
}

class SourceLogStore {
  SourceLogStore._();

  static final SourceLogStore instance = SourceLogStore._();

  static const int _maxEntries = 400;

  final List<AppLogEntry> _entries = <AppLogEntry>[];
  final StreamController<List<AppLogEntry>> _controller =
      StreamController<List<AppLogEntry>>.broadcast();

  List<AppLogEntry> get entries => List.unmodifiable(_entries.reversed);

  Stream<List<AppLogEntry>> watch() => _controller.stream;

  void add(AppLogEntry entry) {
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
    _controller.add(entries);
  }

  void clear() {
    _entries.clear();
    _controller.add(const <AppLogEntry>[]);
  }

  String exportText({bool includeInfo = false}) {
    final filtered = entries.where(
      (entry) => includeInfo || entry.level != AppLogLevel.info,
    );

    return filtered.map((entry) => entry.toMultilineText()).join('\n\n');
  }
}
