import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/features/announcement/application/announcement_read_state_service.dart';
import 'package:shuxiang_reading_next/features/announcement/application/announcement_service.dart';
import 'package:shuxiang_reading_next/features/announcement/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  test('announcement providers expose announcement services', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(announcementServiceProvider),
      isA<AnnouncementService>(),
    );
    expect(
      container.read(announcementReadStateServiceProvider),
      isA<AnnouncementReadStateService>(),
    );
  });
}
