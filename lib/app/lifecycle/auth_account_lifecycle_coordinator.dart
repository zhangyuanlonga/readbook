import 'dart:async';

import '../../core/auth/auth_event_bus.dart';
import '../../core/logging/app_logger.dart';

typedef AccountScopedCacheClearer = Future<void> Function(String? userId);
typedef CurrentAccountDataRefresher = Future<void> Function();
typedef AccountLifecycleRevisionNotifier = void Function();

class AuthAccountLifecycleCoordinator {
  AuthAccountLifecycleCoordinator({
    required AccountScopedCacheClearer clearAccountScopedCache,
    required CurrentAccountDataRefresher refreshCurrentAccountData,
    required AccountLifecycleRevisionNotifier notifyAccountDataChanged,
    AppLogger? logger,
  }) : _clearAccountScopedCache = clearAccountScopedCache,
       _refreshCurrentAccountData = refreshCurrentAccountData,
       _notifyAccountDataChanged = notifyAccountDataChanged,
       _logger = logger ?? AppLogger.instance;

  final AccountScopedCacheClearer _clearAccountScopedCache;
  final CurrentAccountDataRefresher _refreshCurrentAccountData;
  final AccountLifecycleRevisionNotifier _notifyAccountDataChanged;
  final AppLogger _logger;

  int _version = 0;

  Future<void> handle(AuthEvent event) async {
    final version = ++_version;
    switch (event.type) {
      case AuthEventType.loggedIn:
        await _handleLoggedIn(event, version);
        break;
      case AuthEventType.loggedOut:
      case AuthEventType.sessionExpired:
        await _handleLoggedOut(event, version);
        break;
    }
  }

  Future<void> _handleLoggedIn(AuthEvent event, int version) async {
    if (event.isAccountSwitch) {
      await _clearCache(event.previousUserId, event);
    }
    if (version != _version) {
      return;
    }

    try {
      await _refreshCurrentAccountData();
      if (version == _version) {
        _notifyAccountDataChanged();
      }
    } catch (error, stackTrace) {
      _logger.warn(
        'Refresh account data after login failed',
        context: {
          'event': event.type.name,
          'userId': event.userId,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }

  Future<void> _handleLoggedOut(AuthEvent event, int version) async {
    await _clearCache(event.previousUserId ?? event.userId, event);
    if (version == _version) {
      _notifyAccountDataChanged();
    }
  }

  Future<void> _clearCache(String? userId, AuthEvent event) async {
    final normalizedUserId = userId?.trim() ?? '';
    if (normalizedUserId.isEmpty) {
      return;
    }
    try {
      await _clearAccountScopedCache(normalizedUserId);
    } catch (error, stackTrace) {
      _logger.warn(
        'Clear account scoped cache failed',
        context: {
          'event': event.type.name,
          'userId': normalizedUserId,
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    }
  }
}
