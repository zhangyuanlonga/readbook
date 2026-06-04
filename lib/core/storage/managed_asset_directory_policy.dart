import '../../domain/entities/managed_asset.dart';

class ManagedAssetDirectoryPolicy {
  const ManagedAssetDirectoryPolicy({
    required this.type,
    required this.scope,
    required this.root,
    required this.relativeDirectory,
    this.legacyRelativePrefixes = const <String>[],
  });

  final ManagedAssetType type;
  final ManagedAssetScope scope;
  final ManagedAssetRoot root;
  final String relativeDirectory;
  final List<String> legacyRelativePrefixes;

  List<String> get allKnownRelativePrefixes => <String>[
    relativeDirectory,
    ...legacyRelativePrefixes,
  ];
}

abstract final class ManagedAssetDirectoryPolicies {
  static const List<ManagedAssetDirectoryPolicy> all =
      <ManagedAssetDirectoryPolicy>[
        ManagedAssetDirectoryPolicy(
          type: ManagedAssetType.appBackground,
          scope: ManagedAssetScope.appAppearance,
          root: ManagedAssetRoot.documents,
          relativeDirectory: 'backgrounds/',
        ),
        ManagedAssetDirectoryPolicy(
          type: ManagedAssetType.readerBackground,
          scope: ManagedAssetScope.readerAppearance,
          root: ManagedAssetRoot.documents,
          relativeDirectory: 'reader_backgrounds/',
        ),
        ManagedAssetDirectoryPolicy(
          type: ManagedAssetType.coverGalleryImage,
          scope: ManagedAssetScope.themeBinding,
          root: ManagedAssetRoot.documents,
          relativeDirectory: 'cover_galleries/',
        ),
        ManagedAssetDirectoryPolicy(
          type: ManagedAssetType.launchImageGalleryImage,
          scope: ManagedAssetScope.launchImage,
          root: ManagedAssetRoot.documents,
          relativeDirectory: 'launch_image_galleries/',
        ),
        ManagedAssetDirectoryPolicy(
          type: ManagedAssetType.bottomNavIcon,
          scope: ManagedAssetScope.bottomNav,
          root: ManagedAssetRoot.support,
          relativeDirectory: 'bottom_nav_icon_galleries/',
        ),
        ManagedAssetDirectoryPolicy(
          type: ManagedAssetType.readerFont,
          scope: ManagedAssetScope.typography,
          root: ManagedAssetRoot.support,
          relativeDirectory: 'reader_fonts/',
        ),
        ManagedAssetDirectoryPolicy(
          type: ManagedAssetType.customBookCover,
          scope: ManagedAssetScope.bookshelfBook,
          root: ManagedAssetRoot.support,
          relativeDirectory: 'shuxiang_reading_next/custom_covers/',
          legacyRelativePrefixes: <String>['custom_covers/'],
        ),
        ManagedAssetDirectoryPolicy(
          type: ManagedAssetType.localBookArtifact,
          scope: ManagedAssetScope.localBook,
          root: ManagedAssetRoot.support,
          relativeDirectory: 'local_books/',
        ),
        ManagedAssetDirectoryPolicy(
          type: ManagedAssetType.profileAvatar,
          scope: ManagedAssetScope.userProfile,
          root: ManagedAssetRoot.documents,
          relativeDirectory: 'profile_avatars/',
        ),
      ];

  static ManagedAssetDirectoryPolicy? policyFor(ManagedAssetType type) {
    for (final policy in all) {
      if (policy.type == type) {
        return policy;
      }
    }
    return null;
  }

  static Iterable<ManagedAssetDirectoryPolicy> policiesForRoot(
    ManagedAssetRoot root,
  ) {
    return all.where((policy) => policy.root == root);
  }
}
