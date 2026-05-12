import 'dart:async';

import '../../../core/auth/auth_event_bus.dart';

class MinePageFlowCoordinator {
  MinePageFlowCoordinator({Stream<AuthEvent>? authEvents})
    : _authEvents = authEvents ?? AuthEventBus.instance.stream;

  final Stream<AuthEvent> _authEvents;

  StreamSubscription<AuthEvent>? _authEventSubscription;

  void initialize({required void Function(AuthEvent event) onAuthEvent}) {
    _authEventSubscription ??= _authEvents.listen(onAuthEvent);
  }

  Future<void> dispose() async {
    await _authEventSubscription?.cancel();
    _authEventSubscription = null;
  }
}
