import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/logging/app_logger.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_diagnostics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SourceRuntimeDiagnosticsService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('stores and clears active invocation markers', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SourceRuntimeDiagnosticsService(preferences: prefs);

      final marker = await service.markInvocationStarted(
        sourceId: 'source_a',
        sourceName: '源 A',
        methodName: 'search',
        runtimeChain: 'source_script',
        metadata: const <String, Object?>{'keyword': '凡人修仙传'},
      );

      final active = await service.loadActiveMarkers();
      expect(active, hasLength(1));
      expect(active.first.sourceId, 'source_a');
      expect(active.first.methodName, 'search');

      await service.markInvocationFinished(marker.invocationId);

      final cleared = await service.loadActiveMarkers();
      expect(cleared, isEmpty);
    });

    test('reports recovered markers and clears storage', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SourceRuntimeDiagnosticsService(preferences: prefs);
      final logger = AppLogger.instance;

      await service.markInvocationStarted(
        sourceId: 'source_b',
        sourceName: '源 B',
        methodName: 'search',
        runtimeChain: 'source_script',
        metadata: const <String, Object?>{'keyword': '作者名'},
      );

      await service.reportRecoveredInvocations(logger: logger);

      final active = await service.loadActiveMarkers();
      expect(active, isEmpty);
    });
  });
}
