import 'dart:convert';

class ReaderChapterCachePayload {
  const ReaderChapterCachePayload({
    required this.content,
    this.imageUrls = const <String>[],
    this.imageHeaders = const <String, String>{},
  });

  final String content;
  final List<String> imageUrls;
  final Map<String, String> imageHeaders;
}

class ReaderChapterCacheDecoder {
  const ReaderChapterCacheDecoder({
    this.imagePayloadPrefix = defaultImagePayloadPrefix,
  });

  static const String defaultImagePayloadPrefix = '__appread_image_payload__:';

  final String imagePayloadPrefix;

  ReaderChapterCachePayload decode(String payload) {
    final trimmed = payload.trim();
    if (!trimmed.startsWith(imagePayloadPrefix)) {
      return ReaderChapterCachePayload(content: trimmed);
    }

    final raw = trimmed.substring(imagePayloadPrefix.length);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final urls = decoded
            .map((item) => item?.toString().trim() ?? '')
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
        return ReaderChapterCachePayload(content: '', imageUrls: urls);
      }

      if (decoded is Map) {
        final urls =
            (decoded['imageUrls'] as List?)
                ?.map((item) => item?.toString().trim() ?? '')
                .where((item) => item.isNotEmpty)
                .toList(growable: false) ??
            const <String>[];
        final headers =
            (decoded['imageHeaders'] as Map?)
                ?.map(
                  (key, value) =>
                      MapEntry(key.toString(), value?.toString().trim() ?? ''),
                )
                .map((key, value) => MapEntry(key.trim(), value.trim()))
                .entries
                .where(
                  (entry) => entry.key.isNotEmpty && entry.value.isNotEmpty,
                )
                .fold<Map<String, String>>(
                  <String, String>{},
                  (result, entry) => result..[entry.key] = entry.value,
                ) ??
            const <String, String>{};

        return ReaderChapterCachePayload(
          content: '',
          imageUrls: urls,
          imageHeaders: headers,
        );
      }
    } on FormatException {
      return ReaderChapterCachePayload(content: trimmed);
    }

    return ReaderChapterCachePayload(content: trimmed);
  }
}
