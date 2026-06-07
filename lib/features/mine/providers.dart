import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/composition/app_providers.dart' as app_providers;
import '../../app/navigation/bottom_nav_icon_gallery_provider.dart';
import '../../core/app_update/app_update_service.dart';
import '../../core/auth/auth_session_secret_store.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/media/image_selection_service.dart';
import '../../core/membership/membership_service.dart';
import '../../core/mobile_features/mobile_feature_service.dart';
import '../../core/user/user_profile_service.dart';
import '../../domain/repositories/bookmark_repository.dart';
import '../../features/auth/providers.dart' as auth_providers;
import '../../features/reader/application/local/local_reader_entry_guard_service.dart';
import '../bookshelf/application/bookshelf_service.dart';
import 'application/advanced_theme_page_flow_coordinator.dart';
import 'application/advanced_theme_provider.dart';
import 'application/advanced_theme_resource_reference_service.dart';
import 'application/advanced_theme_editor_state_service.dart';
import 'application/appearance_page_resource_service.dart';
import 'application/app_background_service.dart';
import 'application/bookmarks_query_service.dart';
import 'application/cover_gallery_provider.dart';
import 'application/mine_page_flow_coordinator.dart';
import 'application/mine_page_preferences_service.dart';
import 'application/launch_image_gallery_provider.dart';
import 'application/mine_page_session_service.dart';
import 'application/remote_access_snapshot_service.dart';
import 'application/reader_background_service.dart';
import '../reader/application/reader_font_registry_service.dart';

final mineBookshelfServiceProvider = Provider<BookshelfService>((ref) {
  return BookshelfService();
});

final mineBookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return ref.watch(app_providers.bookmarkRepositoryProvider);
});

final bookmarksQueryServiceProvider = Provider<BookmarksQueryService>((ref) {
  return BookmarksQueryService(
    bookmarkRepository: ref.watch(mineBookmarkRepositoryProvider),
    bookshelfService: ref.watch(mineBookshelfServiceProvider),
  );
});

final bookmarksLocalReaderEntryGuardServiceProvider =
    Provider<LocalReaderEntryGuardService>((ref) {
      return LocalReaderEntryGuardService(
        localBookRepository: ref.watch(
          app_providers.localBookRepositoryProvider,
        ),
      );
    });

final mineAuthSessionStoreProvider = Provider<AuthSessionStore>((ref) {
  return ref.watch(auth_providers.authSessionStoreProvider);
});

final mineAuthSessionSecretStoreProvider = Provider<AuthSessionSecretStore>((
  ref,
) {
  return ref.watch(auth_providers.authSessionSecretStoreProvider);
});

final mineUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService();
});

final mineMobileFeatureServiceProvider = Provider<MobileFeatureService>((ref) {
  return MobileFeatureService();
});

final mineMembershipServiceProvider = Provider<MembershipService>((ref) {
  return MembershipService();
});

final mineUserProfileServiceProvider = Provider<UserProfileService>((ref) {
  return ref.watch(auth_providers.userProfileServiceProvider);
});

final remoteAccessSnapshotServiceProvider =
    Provider<RemoteAccessSnapshotService>((ref) {
      return RemoteAccessSnapshotService();
    });

/// Mine 页账号权益缓存修订号。
///
/// 会员中心会在拉到最新 entitlement 并落地缓存后递增它，避免 Mine 页只依赖
/// 路由返回路径刷新，导致从资料页等其它入口进入会员页后卡片继续显示旧状态。
final mineRemoteAccessSnapshotRevisionProvider = StateProvider<int>((ref) => 0);

final mineImageSelectionServiceProvider = Provider<ImageSelectionService>((
  ref,
) {
  return ImageSelectionService();
});

final appBackgroundServiceProvider = Provider<AppBackgroundService>((ref) {
  return AppBackgroundService();
});

final minePagePreferencesServiceProvider = Provider<MinePagePreferencesService>(
  (ref) {
    return MinePagePreferencesService();
  },
);

final readerBackgroundServiceProvider = Provider<ReaderBackgroundService>((
  ref,
) {
  return ReaderBackgroundService();
});

final appearancePageResourceServiceProvider =
    Provider<AppearancePageResourceService>((ref) {
      return AppearancePageResourceService(
        backgroundService: ref.watch(appBackgroundServiceProvider),
        fontRegistryService: ReaderFontRegistryService(),
      );
    });

final advancedThemeEditorStateServiceProvider =
    Provider<AdvancedThemeEditorStateService>((ref) {
      return AdvancedThemeEditorStateService(
        service: ref.watch(advancedThemeServiceProvider),
        bottomNavIconGalleryService: ref.watch(
          bottomNavIconGalleryServiceProvider,
        ),
        appBackgroundService: ref.watch(appBackgroundServiceProvider),
        coverGalleryService: ref.watch(coverGalleryServiceProvider),
        launchImageGalleryService: ref.watch(launchImageGalleryServiceProvider),
        readerBackgroundService: ref.watch(readerBackgroundServiceProvider),
        fontRegistryService: ReaderFontRegistryService(),
      );
    });

final advancedThemeResourceReferenceServiceProvider =
    Provider<AdvancedThemeResourceReferenceService>((ref) {
      return AdvancedThemeResourceReferenceService();
    });

final minePageSessionServiceProvider = Provider<MinePageSessionService>((ref) {
  return MinePageSessionService(
    authSessionStore: ref.watch(mineAuthSessionStoreProvider),
    mobileFeatureService: ref.watch(mineMobileFeatureServiceProvider),
    membershipService: ref.watch(mineMembershipServiceProvider),
    userProfileService: ref.watch(mineUserProfileServiceProvider),
    remoteAccessSnapshotService: ref.watch(remoteAccessSnapshotServiceProvider),
  );
});

final minePageVisibilityProvider =
    NotifierProvider<MinePageVisibilityNotifier, MinePageVisibilityState>(
      MinePageVisibilityNotifier.new,
    );

final minePageStartupDestinationProvider = NotifierProvider<
  MinePageStartupDestinationNotifier,
  MinePageStartupDestination
>(MinePageStartupDestinationNotifier.new);

typedef MinePageFlowCoordinatorFactory = MinePageFlowCoordinator Function();

final minePageFlowCoordinatorProvider =
    Provider<MinePageFlowCoordinatorFactory>((ref) {
      return () => MinePageFlowCoordinator(
        authEvents: ref.watch(app_providers.appAuthEventStreamProvider),
      );
    });

typedef AdvancedThemePageFlowCoordinatorFactory =
    AdvancedThemePageFlowCoordinator Function();

final advancedThemePageFlowCoordinatorFactoryProvider =
    Provider<AdvancedThemePageFlowCoordinatorFactory>((ref) {
      return () => AdvancedThemePageFlowCoordinator(
        externalImportBridge: ref.watch(
          app_providers.appExternalImportBridgeProvider,
        ),
        authEvents: ref.watch(app_providers.appAuthEventStreamProvider),
      );
    });

class MinePageVisibilityNotifier extends Notifier<MinePageVisibilityState> {
  static MinePageVisibilityState? _primedState;

  bool _loadTriggered = false;
  bool _hasExplicitSet = false;

  static void prime(SharedPreferences prefs) {
    _primedState = MinePagePreferencesService.readVisibilityState(prefs);
  }

  @override
  MinePageVisibilityState build() {
    final primedState = _primedState;
    if (primedState != null) {
      return primedState;
    }
    if (!_loadTriggered) {
      _loadTriggered = true;
      _load();
    }
    return MinePageVisibilityState();
  }

  Future<void> _load() async {
    final loaded =
        await ref
            .read(minePagePreferencesServiceProvider)
            .loadVisibilityState();
    if (_hasExplicitSet) {
      return;
    }
    if (loaded != state) {
      state = loaded;
    }
  }

  Future<void> setVisible(MinePageItemId itemId, bool visible) async {
    if (!minePageItemDefinitionFor(itemId).configurable) {
      return;
    }

    final previous = state;
    final next = state.copyWithVisibility(itemId, visible);
    if (next == state) {
      return;
    }

    _hasExplicitSet = true;
    _primedState = next;
    state = next;

    try {
      await ref
          .read(minePagePreferencesServiceProvider)
          .saveVisibilityState(next);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

class MinePageStartupDestinationNotifier
    extends Notifier<MinePageStartupDestination> {
  static MinePageStartupDestination? _primedDestination;

  bool _loadTriggered = false;
  bool _hasExplicitSet = false;

  static void prime(SharedPreferences prefs) {
    _primedDestination = MinePagePreferencesService.readStartupDestination(
      prefs,
    );
  }

  static MinePageStartupDestination get primedOrDefault {
    return _primedDestination ?? MinePageStartupDestination.bookshelf;
  }

  @override
  MinePageStartupDestination build() {
    final primedDestination = _primedDestination;
    if (primedDestination != null) {
      return primedDestination;
    }
    if (!_loadTriggered) {
      _loadTriggered = true;
      _load();
    }
    return MinePageStartupDestination.bookshelf;
  }

  Future<void> _load() async {
    final loaded =
        await ref
            .read(minePagePreferencesServiceProvider)
            .loadStartupDestination();
    if (_hasExplicitSet) {
      return;
    }
    if (loaded != state) {
      state = loaded;
    }
  }

  Future<void> setDestination(MinePageStartupDestination destination) async {
    final previous = state;
    if (destination == previous) {
      return;
    }

    _hasExplicitSet = true;
    _primedDestination = destination;
    state = destination;

    try {
      await ref
          .read(minePagePreferencesServiceProvider)
          .saveStartupDestination(destination);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

String resolveMinePageStartupLocation() {
  return MinePageStartupDestinationNotifier.primedOrDefault.location;
}
