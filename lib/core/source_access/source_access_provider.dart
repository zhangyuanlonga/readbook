import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_event_bus.dart';
import 'source_access_scope.dart';
import 'source_access_service.dart';

final sourceAccessServiceProvider = Provider<SourceAccessService>((ref) {
  return SourceAccessService();
});

final sourceAccessTokenReaderProvider = Provider<Future<String?> Function()>((
  ref,
) {
  return () async => null;
});

final sourceAccessScopeProvider =
    AsyncNotifierProvider<SourceAccessScopeNotifier, SourceAccessScope?>(
      SourceAccessScopeNotifier.new,
    );

class SourceAccessScopeNotifier extends AsyncNotifier<SourceAccessScope?> {
  StreamSubscription<AuthEvent>? _authSubscription;

  @override
  Future<SourceAccessScope?> build() async {
    _authSubscription ??= AuthEventBus.instance.stream.listen((event) {
      switch (event.type) {
        case AuthEventType.loggedIn:
          unawaited(refresh());
          break;
        case AuthEventType.sessionExpired:
        case AuthEventType.loggedOut:
          clear();
          break;
      }
    });
    ref.onDispose(() {
      unawaited(_authSubscription?.cancel());
      _authSubscription = null;
    });
    return _fetchScope();
  }

  Future<SourceAccessScope?> refresh() async {
    state = const AsyncLoading<SourceAccessScope?>();
    final next = await AsyncValue.guard(_fetchScope);
    state = next;
    return next.valueOrNull;
  }

  void clear() {
    state = const AsyncData<SourceAccessScope?>(null);
  }

  Future<SourceAccessScope?> _fetchScope() {
    return ref.read(sourceAccessTokenReaderProvider).call().then((token) {
      if (token == null || token.trim().isEmpty) {
        return null;
      }
      return ref.read(sourceAccessServiceProvider).fetchMyScope();
    });
  }
}
