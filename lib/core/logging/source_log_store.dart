import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../errors/app_exception.dart';
import 'error_monitoring_service.dart';

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
    final merged = <String, Object?>{
      ...context,
      if (exception != null) ...{
        'code': exception!.code.name,
        'stage': exception!.stage.name,
        'sourceId': exception!.sourceId,
        'requestUrl': exception!.requestUrl,
        'briefMessage': exception!.briefMessage,
      },
    }..removeWhere((key, value) => value == null);
    return AppErrorMonitoringService.sanitizeContext(merged);
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

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'message': message,
      'context': _normalizeValue(details),
    };
  }

  factory AppLogEntry.fromJson(Map<String, Object?> json) {
    final timestampRaw = json['timestamp']?.toString() ?? '';
    final timestamp = DateTime.tryParse(timestampRaw) ?? DateTime.now();
    final levelName = json['level']?.toString() ?? '';
    final contextRaw = json['context'];

    return AppLogEntry(
      timestamp: timestamp,
      level: AppLogLevel.values.firstWhere(
        (item) => item.name == levelName,
        orElse: () => AppLogLevel.info,
      ),
      message: json['message']?.toString() ?? '',
      context:
          contextRaw is Map
              ? contextRaw.map((key, value) => MapEntry(key.toString(), value))
              : const <String, Object?>{},
    );
  }

  static Object? _normalizeValue(Object? value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is Enum) {
      return value.name;
    }
    if (value is Uri) {
      return value.toString();
    }
    if (value is Iterable) {
      return value.map(_normalizeValue).toList(growable: false);
    }
    if (value is Map) {
      return value.map(
        (key, nestedValue) =>
            MapEntry(key.toString(), _normalizeValue(nestedValue)),
      );
    }
    return value.toString();
  }
}

class SourceLogStore {
  SourceLogStore._();

  static final SourceLogStore instance = SourceLogStore._();

  static const int _maxEntries = 400;
  static const Duration _persistDebounce = Duration(milliseconds: 360);

  final List<AppLogEntry> _entries = <AppLogEntry>[];
  final StreamController<List<AppLogEntry>> _controller =
      StreamController<List<AppLogEntry>>.broadcast();
  Future<void>? _restoreFuture;
  Future<void> _pendingPersist = Future<void>.value();
  Timer? _persistTimer;

  List<AppLogEntry> get entries => List.unmodifiable(_entries.reversed);

  Stream<List<AppLogEntry>> watch() => _controller.stream;

  Future<void> restore() {
    final future = _restoreFuture;
    if (future != null) {
      return future;
    }
    final restoreFuture = _restoreInternal();
    _restoreFuture = restoreFuture;
    return restoreFuture;
  }

  void add(AppLogEntry entry) {
    _entries.add(entry);
    _trimEntries();
    _emit();
    _schedulePersist();
  }

  void clear() {
    _entries.clear();
    _emit();
    _schedulePersist();
  }

  String exportText({bool includeInfo = false}) {
    final filtered = entries.where(
      (entry) => includeInfo || entry.level != AppLogLevel.info,
    );

    return filtered.map((entry) => entry.toMultilineText()).join('\n\n');
  }

  Future<void> _restoreInternal() async {
    try {
      final file = await _resolveStoreFile();
      if (!await file.exists()) {
        return;
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }
      _entries
        ..clear()
        ..addAll(
          decoded.whereType<Map>().map(
            (item) => AppLogEntry.fromJson(
              item.map(
                (key, value) => MapEntry(key.toString(), value as Object?),
              ),
            ),
          ),
        );
      _trimEntries();
      _emit();
    } catch (_) {
      // Ignore corrupted local log cache and continue with an empty buffer.
    }
  }

  void _trimEntries() {
    if (_entries.length <= _maxEntries) {
      return;
    }
    _entries.removeRange(0, _entries.length - _maxEntries);
  }

  void _emit() {
    _controller.add(entries);
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDebounce, () {
      final snapshot = _entries
          .map((entry) => entry.toJson())
          .toList(growable: false);
      _pendingPersist = _pendingPersist
          .catchError((_) {})
          .then((_) => _persistSnapshot(snapshot));
    });
  }

  Future<void> _persistSnapshot(List<Map<String, Object?>> snapshot) async {
    try {
      final file = await _resolveStoreFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(snapshot), flush: true);
    } catch (_) {
      // Ignore persistence failures and keep the in-memory buffer available.
    }
  }

  Future<File> _resolveStoreFile() async {
    final supportDirectory = await getApplicationSupportDirectory();
    return File(
      '${supportDirectory.path}${Platform.pathSeparator}logs${Platform.pathSeparator}app_logs.json',
    );
  }
}
