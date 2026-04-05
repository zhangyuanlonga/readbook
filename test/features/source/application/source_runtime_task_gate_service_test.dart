import 'dart:async';

import 'package:flutter_appread/features/source/application/source_runtime_task_gate_service.dart';
import 'package:flutter_appread/runtime/sources/source_contract.dart';
import 'package:flutter_appread/runtime/sources/source_manifest.dart';
import 'package:flutter_appread/runtime/sources/source_registry.dart';
import 'package:flutter_appread/runtime/sources/source_result_models.dart'
    as runtime_models;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SourceRuntimeTaskGateService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('serializes browser heavy tasks on conservative platform', () async {
      final gate = SourceRuntimeTaskGateService(
        runtimePlatform: SourceRuntimeTaskGatePlatform.macos,
      );
      final source = _buildRegisteredSource(
        id: 'browser_source',
        name: '浏览器源',
        capabilities: const <String>{'novel', 'browser'},
      );

      final controls = _GateTaskControls();
      final first = gate.run<void>(
        source: source,
        taskKind: SourceRuntimeTaskKind.content,
        action: () => controls.enter('first'),
      );
      final second = gate.run<void>(
        source: source,
        taskKind: SourceRuntimeTaskKind.discoverBooks,
        action: () => controls.enter('second'),
      );

      await controls.waitUntilStartedCount(1);
      expect(controls.maxConcurrent, 1);
      controls.complete('first');
      await controls.waitUntilStartedCount(2);
      expect(controls.maxConcurrent, 1);
      controls.complete('second');

      await Future.wait<void>(<Future<void>>[first, second]);
      expect(controls.maxConcurrent, 1);
    });
  });
}

RegisteredSource _buildRegisteredSource({
  required String id,
  required String name,
  Set<String> capabilities = const <String>{'novel'},
}) {
  return RegisteredSource(
    runtime: SourceRuntimeInfo(
      id: id,
      name: name,
      group: '测试',
      revision: 'test',
    ),
    definition: RuntimeSourceDefinition(
      manifest: SourceManifest(
        name: name,
        group: '测试',
        author: 'tester',
        description: '',
        capabilities: capabilities,
      ),
      search: (_, __) async => const [],
      detail: (_, book) async => book,
      chapters: (_, __) async => const [],
      content:
          (_, __, ___) async =>
              const runtime_models.Content(title: '', content: ''),
    ),
  );
}

class _GateTaskControls {
  final Map<String, Completer<void>> _pending = <String, Completer<void>>{};
  int _startedCount = 0;
  int _running = 0;
  int maxConcurrent = 0;

  Future<void> enter(String id) async {
    final completer = Completer<void>();
    _pending[id] = completer;
    _startedCount += 1;
    _running += 1;
    if (_running > maxConcurrent) {
      maxConcurrent = _running;
    }
    await completer.future;
    _running -= 1;
  }

  Future<void> waitUntilStartedCount(int expected) async {
    while (_startedCount < expected) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  void complete(String id) {
    _pending.remove(id)?.complete();
  }
}
