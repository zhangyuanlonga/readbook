abstract final class BookIdentityScheme {
  static const String localSourceId = '__local_book__';
  static const String localScheme = 'local';
  static const String localBookHost = 'book';
  static const String localChapterHost = 'chapter';
}

enum SourceBookKeyKind { detail, toc, title, anonymous }

/// Canonical source-scoped book key.
///
/// This keeps the app-side "same source, same book" locator explicit without
/// changing the script-source `Book` contract.
class SourceBookKey {
  const SourceBookKey._({
    required this.sourceId,
    required this.kind,
    this.value,
  });

  final String sourceId;
  final SourceBookKeyKind kind;
  final String? value;

  factory SourceBookKey.detail({
    required String sourceId,
    required String detailUrl,
  }) {
    return SourceBookKey._(
      sourceId: sourceId.trim(),
      kind: SourceBookKeyKind.detail,
      value: detailUrl.trim(),
    );
  }

  factory SourceBookKey.toc({
    required String sourceId,
    required String tocUrl,
  }) {
    return SourceBookKey._(
      sourceId: sourceId.trim(),
      kind: SourceBookKeyKind.toc,
      value: tocUrl.trim(),
    );
  }

  factory SourceBookKey.title({
    required String sourceId,
    required String title,
  }) {
    return SourceBookKey._(
      sourceId: sourceId.trim(),
      kind: SourceBookKeyKind.title,
      value: title.trim(),
    );
  }

  factory SourceBookKey.anonymous({required String sourceId}) {
    return SourceBookKey._(
      sourceId: sourceId.trim(),
      kind: SourceBookKeyKind.anonymous,
    );
  }

  factory SourceBookKey.forRemoteBook({
    required String sourceId,
    required String detailUrl,
    required String fallbackTitle,
  }) {
    final normalizedDetailUrl = detailUrl.trim();
    if (normalizedDetailUrl.isNotEmpty) {
      return SourceBookKey.detail(
        sourceId: sourceId,
        detailUrl: normalizedDetailUrl,
      );
    }
    return SourceBookKey.title(sourceId: sourceId, title: fallbackTitle);
  }

  factory SourceBookKey.forReadingFlow({
    required String sourceId,
    required String detailUrl,
    required String tocUrl,
    required String title,
  }) {
    final normalizedDetailUrl = detailUrl.trim();
    if (normalizedDetailUrl.isNotEmpty) {
      return SourceBookKey.detail(
        sourceId: sourceId,
        detailUrl: normalizedDetailUrl,
      );
    }

    final normalizedTocUrl = tocUrl.trim();
    if (normalizedTocUrl.isNotEmpty) {
      return SourceBookKey.toc(sourceId: sourceId, tocUrl: normalizedTocUrl);
    }

    final normalizedTitle = title.trim();
    if (normalizedTitle.isNotEmpty) {
      return SourceBookKey.title(sourceId: sourceId, title: normalizedTitle);
    }

    return SourceBookKey.anonymous(sourceId: sourceId);
  }

  String get storageKey {
    final normalizedSourceId = sourceId.trim();
    final normalizedValue = Uri.encodeComponent((value ?? '').trim());
    return switch (kind) {
      SourceBookKeyKind.detail =>
        '$normalizedSourceId::detail:$normalizedValue',
      SourceBookKeyKind.toc => '$normalizedSourceId::toc:$normalizedValue',
      SourceBookKeyKind.title => '$normalizedSourceId::title:$normalizedValue',
      SourceBookKeyKind.anonymous => '$normalizedSourceId::anonymous-book',
    };
  }

  /// Legacy app-side id shape used by search/discover `Book.id`.
  ///
  /// Keep this stable while internal semantics are being made explicit.
  String get legacyLogicalBookId {
    final normalizedSourceId = sourceId.trim();
    return '$normalizedSourceId:${Uri.encodeComponent((value ?? '').trim())}';
  }
}

class BookIdentity {
  const BookIdentity({
    required this.logicalBookId,
    required this.sourceBookKey,
  });

  final String logicalBookId;
  final SourceBookKey sourceBookKey;

  factory BookIdentity.remote({
    required String sourceId,
    required String detailUrl,
    required String fallbackTitle,
  }) {
    final sourceBookKey = SourceBookKey.forRemoteBook(
      sourceId: sourceId,
      detailUrl: detailUrl,
      fallbackTitle: fallbackTitle,
    );
    return BookIdentity(
      logicalBookId: sourceBookKey.legacyLogicalBookId,
      sourceBookKey: sourceBookKey,
    );
  }

  factory BookIdentity.local({required String logicalBookId}) {
    final normalizedBookId = logicalBookId.trim();
    return BookIdentity(
      logicalBookId:
          normalizedBookId.isEmpty ? 'unknown-local-book' : normalizedBookId,
      sourceBookKey: SourceBookKey.detail(
        sourceId: BookIdentityScheme.localSourceId,
        detailUrl: buildLocalBookDetailUrl(logicalBookId),
      ),
    );
  }
}

bool isLocalBookSourceId(String? sourceId) {
  return (sourceId ?? '').trim() == BookIdentityScheme.localSourceId;
}

bool isLocalSchemeUrl(String? value) {
  final normalized = (value ?? '').trim();
  if (normalized.isEmpty) {
    return false;
  }
  final uri = Uri.tryParse(normalized);
  return uri != null && uri.scheme == BookIdentityScheme.localScheme;
}

String buildLocalBookDetailUrl(String bookId) {
  final normalizedBookId = bookId.trim();
  return Uri(
    scheme: BookIdentityScheme.localScheme,
    host: BookIdentityScheme.localBookHost,
    pathSegments: <String>[normalizedBookId],
  ).toString();
}

String buildLocalChapterUrl(String chapterId) {
  final normalizedChapterId = chapterId.trim();
  return Uri(
    scheme: BookIdentityScheme.localScheme,
    host: BookIdentityScheme.localChapterHost,
    pathSegments: <String>[normalizedChapterId],
  ).toString();
}

String? parseLocalBookIdFromDetailUrl(String? detailUrl) {
  return _parseLocalIdByHost(
    value: detailUrl,
    expectedHost: BookIdentityScheme.localBookHost,
  );
}

String? parseLocalChapterIdFromChapterUrl(String? chapterUrl) {
  return _parseLocalIdByHost(
    value: chapterUrl,
    expectedHost: BookIdentityScheme.localChapterHost,
  );
}

String? _parseLocalIdByHost({
  required String? value,
  required String expectedHost,
}) {
  final normalized = (value ?? '').trim();
  if (normalized.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(normalized);
  if (uri == null ||
      uri.scheme != BookIdentityScheme.localScheme ||
      uri.host != expectedHost) {
    return null;
  }
  if (uri.pathSegments.isEmpty) {
    return null;
  }
  final id = uri.pathSegments.last.trim();
  if (id.isEmpty) {
    return null;
  }
  return id;
}
