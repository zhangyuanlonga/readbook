import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../domain/entities/announcement.dart';
import '../../features/announcement/application/announcement_read_state_service.dart';
import '../../features/announcement/application/announcement_service.dart';
import 'startup_task_gate_service.dart';

typedef StartupAnnouncementPresenter = void Function(Announcement announcement);

class AppAnnouncementCoordinator {
  AppAnnouncementCoordinator({
    AnnouncementService? announcementService,
    AnnouncementReadStateService? announcementReadStateService,
    StartupTaskGateService? taskGateService,
  }) : _announcementService = announcementService ?? AnnouncementService(),
       _announcementReadStateService =
           announcementReadStateService ?? AnnouncementReadStateService(),
       _taskGateService = taskGateService ?? StartupTaskGateService();

  final AnnouncementService _announcementService;
  final AnnouncementReadStateService _announcementReadStateService;
  final StartupTaskGateService _taskGateService;

  bool _hasShownStartupAnnouncement = false;
  bool _startupAnnouncementScheduled = false;
  int _startupAnnouncementRetryCount = 0;

  void showStartupAnnouncementIfNeeded({
    required bool isStartupReady,
    required bool Function() isMounted,
    required BuildContext? Function() currentNavigatorContext,
    required StartupAnnouncementPresenter presentAnnouncement,
  }) {
    if (!isStartupReady ||
        _hasShownStartupAnnouncement ||
        _startupAnnouncementScheduled) {
      return;
    }

    _startupAnnouncementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startupAnnouncementScheduled = false;
      if (!isMounted() || _hasShownStartupAnnouncement) {
        return;
      }

      final navigatorContext = currentNavigatorContext();
      if (navigatorContext == null) {
        if (_startupAnnouncementRetryCount < 10) {
          _startupAnnouncementRetryCount += 1;
          showStartupAnnouncementIfNeeded(
            isStartupReady: isStartupReady,
            isMounted: isMounted,
            currentNavigatorContext: currentNavigatorContext,
            presentAnnouncement: presentAnnouncement,
          );
        }
        return;
      }

      _startupAnnouncementRetryCount = 0;
      unawaited(
        _tryShowLatestAnnouncement(
          isMounted: isMounted,
          currentNavigatorContext: currentNavigatorContext,
          presentAnnouncement: presentAnnouncement,
        ),
      );
    });
  }

  Future<void> markRead(String id) {
    return _announcementReadStateService.markRead(id);
  }

  Future<void> _tryShowLatestAnnouncement({
    required bool Function() isMounted,
    required BuildContext? Function() currentNavigatorContext,
    required StartupAnnouncementPresenter presentAnnouncement,
  }) async {
    final shouldRun = await _taskGateService.claimDailyRun(
      'startup_announcement',
    );
    if (!shouldRun) {
      return;
    }
    Announcement? latest;
    try {
      latest = await _announcementService.fetchLatestAnnouncement();
    } catch (_) {
      return;
    }

    if (!isMounted()) {
      return;
    }

    final announcement = latest;
    if (announcement == null) {
      return;
    }

    final active = announcement.isActiveAt(DateTime.now().toUtc());
    if (!active) {
      return;
    }

    final isRead = await _announcementReadStateService.isRead(announcement.id);
    if (isRead) {
      return;
    }

    final dialogContext = currentNavigatorContext();
    if (!isMounted() || dialogContext == null || !dialogContext.mounted) {
      return;
    }

    _hasShownStartupAnnouncement = true;
    presentAnnouncement(announcement);
  }
}
