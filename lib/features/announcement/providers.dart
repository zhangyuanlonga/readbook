import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/announcement_read_state_service.dart';
import 'application/announcement_service.dart';

final announcementServiceProvider = Provider<AnnouncementService>((ref) {
  return AnnouncementService();
});

final announcementReadStateServiceProvider =
    Provider<AnnouncementReadStateService>((ref) {
      return AnnouncementReadStateService();
    });
