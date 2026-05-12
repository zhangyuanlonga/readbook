import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/managed_asset.dart';

void main() {
  test('managed asset ref builds stable binding key', () {
    const ref = ManagedAssetRef(
      type: ManagedAssetType.customBookCover,
      scope: ManagedAssetScope.bookshelfBook,
      root: ManagedAssetRoot.support,
      relativePath: 'shuxiang_reading_next/custom_covers/book_1.jpg',
      collectionId: 'cover_overrides',
      assetId: 'book_1',
      displayName: '封面',
    );

    expect(
      ref.bindingKey,
      'bookshelfBook:customBookCover:cover_overrides:book_1',
    );
    expect(
      ref.copyWith(clearAssetId: true).bindingKey,
      'bookshelfBook:customBookCover:cover_overrides:shuxiang_reading_next/custom_covers/book_1.jpg',
    );
  });

  test('managed asset collection keeps type scope and refs', () {
    const ref = ManagedAssetRef(
      type: ManagedAssetType.coverGalleryImage,
      scope: ManagedAssetScope.themeBinding,
      root: ManagedAssetRoot.documents,
      relativePath: 'cover_galleries/gallery_a/cover_1.png',
    );
    const collection = ManagedAssetCollection(
      id: 'gallery_a',
      type: ManagedAssetType.coverGalleryImage,
      scope: ManagedAssetScope.themeBinding,
      displayName: '封面图集 A',
      assetRefs: [ref],
    );

    expect(collection.assetRefs, hasLength(1));
    expect(collection.assetRefs.single.type, ManagedAssetType.coverGalleryImage);
    expect(collection.scope, ManagedAssetScope.themeBinding);
  });

  test('managed asset ref serializes without resolved runtime path', () {
    final ref = ManagedAssetRef(
      type: ManagedAssetType.readerFont,
      scope: ManagedAssetScope.typography,
      root: ManagedAssetRoot.support,
      relativePath: 'reader_fonts/font_a.ttf',
      assetId: 'font_a',
      resolvedPath: '/tmp/runtime/font_a.ttf',
    );

    final restored = ManagedAssetRef.fromJson(ref.toJson());

    expect(restored.relativePath, 'reader_fonts/font_a.ttf');
    expect(restored.assetId, 'font_a');
    expect(restored.resolvedPath, isNull);
  });
}
