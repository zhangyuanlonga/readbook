import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/source_access/source_access_provider.dart';
import 'private_book_source_action_controller.dart';
import 'private_book_source_service.dart';

final privateBookSourceServiceProvider = Provider<PrivateBookSourceService>((
  ref,
) {
  return PrivateBookSourceService();
});

final selectedPrivateBookSourceGroupProvider = StateProvider<String?>((ref) {
  return null;
});

final privateBookSourcesProvider =
    FutureProvider.family<PrivateBookSourceListResult, String?>((
      ref,
      groupId,
    ) async {
      return ref.watch(privateBookSourceServiceProvider).list(groupId: groupId);
    });

final privateBookSourceGroupsProvider =
    FutureProvider<List<PrivateBookSourceGroup>>((ref) async {
      return ref.watch(privateBookSourceServiceProvider).groups();
    });

final sourceQuotaProvider = FutureProvider<SourceQuotaSnapshot>((ref) async {
  return ref.watch(privateBookSourceServiceProvider).quota();
});

final privateBookSourceActionControllerProvider = Provider<
  PrivateBookSourceActionController
>((ref) {
  return PrivateBookSourceActionController(
    service: ref.watch(privateBookSourceServiceProvider),
    refresh: () {
      final selectedGroupId = ref.read(selectedPrivateBookSourceGroupProvider);
      ref.invalidate(privateBookSourcesProvider);
      ref.invalidate(privateBookSourcesProvider(selectedGroupId));
      ref.invalidate(privateBookSourcesProvider(null));
      ref.invalidate(privateBookSourceGroupsProvider);
      ref.invalidate(sourceQuotaProvider);
      ref.invalidate(sourceAccessScopeProvider);
    },
    refreshGroups: () {
      final selectedGroupId = ref.read(selectedPrivateBookSourceGroupProvider);
      ref.invalidate(privateBookSourceGroupsProvider);
      ref.invalidate(privateBookSourcesProvider);
      ref.invalidate(privateBookSourcesProvider(selectedGroupId));
      ref.invalidate(privateBookSourcesProvider(null));
    },
    selectGroup: (groupId) {
      ref.read(selectedPrivateBookSourceGroupProvider.notifier).state = groupId;
    },
    clearSelectedGroupIf: (groupId) {
      if (ref.read(selectedPrivateBookSourceGroupProvider) == groupId) {
        ref.read(selectedPrivateBookSourceGroupProvider.notifier).state = null;
      }
    },
  );
});
