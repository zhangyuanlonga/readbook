import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'private_book_source_service.dart';

final privateBookSourceServiceProvider = Provider<PrivateBookSourceService>((
  ref,
) {
  return PrivateBookSourceService();
});

final selectedPrivateBookSourceGroupProvider = StateProvider<String?>((ref) {
  return null;
});

final privateBookSourcesProvider = FutureProvider.family<
  PrivateBookSourceListResult,
  String?
>((ref, groupName) async {
  return ref.watch(privateBookSourceServiceProvider).list(groupName: groupName);
});

final privateBookSourceGroupsProvider =
    FutureProvider<List<PrivateBookSourceGroupSummary>>((ref) async {
      return ref.watch(privateBookSourceServiceProvider).groups();
    });

final sourceQuotaProvider = FutureProvider<SourceQuotaSnapshot>((ref) async {
  return ref.watch(privateBookSourceServiceProvider).quota();
});
