import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/app/startup/startup_task_gate_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('claims daily run only once per day for the same key', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = StartupTaskGateService(preferences: prefs);
    final first = await service.claimDailyRun(
      'startup_announcement',
      now: DateTime(2026, 5, 12, 10),
    );
    final second = await service.claimDailyRun(
      'startup_announcement',
      now: DateTime(2026, 5, 12, 18),
    );
    final nextDay = await service.claimDailyRun(
      'startup_announcement',
      now: DateTime(2026, 5, 13, 9),
    );

    expect(first, isTrue);
    expect(second, isFalse);
    expect(nextDay, isTrue);
  });

  test('claims interval run only after minimum duration has elapsed', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = StartupTaskGateService(preferences: prefs);
    final first = await service.claimIntervalRun(
      'storage_maintenance',
      minInterval: const Duration(days: 7),
      now: DateTime.utc(2026, 6, 1, 8),
    );
    final second = await service.claimIntervalRun(
      'storage_maintenance',
      minInterval: const Duration(days: 7),
      now: DateTime.utc(2026, 6, 5, 8),
    );
    final third = await service.claimIntervalRun(
      'storage_maintenance',
      minInterval: const Duration(days: 7),
      now: DateTime.utc(2026, 6, 8, 8),
    );

    expect(first, isTrue);
    expect(second, isFalse);
    expect(third, isTrue);
  });
}
