import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/storage/managed_asset_directory_policy.dart';
import 'package:shuxiang_reading_next/domain/entities/managed_asset.dart';

void main() {
  test('directory policies expose expected managed roots and prefixes', () {
    final customCover = ManagedAssetDirectoryPolicies.policyFor(
      ManagedAssetType.customBookCover,
    );
    final appBackground = ManagedAssetDirectoryPolicies.policyFor(
      ManagedAssetType.appBackground,
    );
    final profileAvatar = ManagedAssetDirectoryPolicies.policyFor(
      ManagedAssetType.profileAvatar,
    );

    expect(customCover, isNotNull);
    expect(customCover!.root, ManagedAssetRoot.support);
    expect(
      customCover.allKnownRelativePrefixes,
      contains('shuxiang_reading_next/custom_covers/'),
    );
    expect(customCover.allKnownRelativePrefixes, contains('custom_covers/'));

    expect(appBackground, isNotNull);
    expect(appBackground!.root, ManagedAssetRoot.documents);
    expect(appBackground.relativeDirectory, 'backgrounds/');

    expect(profileAvatar, isNotNull);
    expect(profileAvatar!.scope, ManagedAssetScope.userProfile);
    expect(profileAvatar.root, ManagedAssetRoot.documents);
    expect(profileAvatar.relativeDirectory, 'profile_avatars/');
  });
}
