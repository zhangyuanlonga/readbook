import 'dart:convert';

class ReaderGatewayContentCachePayload {
  const ReaderGatewayContentCachePayload({
    required this.content,
    this.imageUrls = const <String>[],
    this.imageHeaders = const <String, String>{},
    this.contentType,
    this.audioUrl,
    this.audioManifestUrl,
    this.audioHeaders = const <String, String>{},
  });

  final String content;
  final List<String> imageUrls;
  final Map<String, String> imageHeaders;
  final String? contentType;
  final String? audioUrl;
  final String? audioManifestUrl;
  final Map<String, String> audioHeaders;

  bool get hasImageContent => imageUrls.isNotEmpty;

  bool get hasAudioContent =>
      (audioUrl?.trim().isNotEmpty ?? false) ||
      (audioManifestUrl?.trim().isNotEmpty ?? false);
}

class ReaderGatewayContentCacheCodec {
  const ReaderGatewayContentCacheCodec._();

  static const String payloadPrefix = '__appread_gateway_payload__:';
  static const String _unsupportedImagePayloadPrefix =
      '__appread_image_payload__:';

  static bool isUnsupportedPayload(String payload) {
    return payload.trim().startsWith(_unsupportedImagePayloadPrefix);
  }

  static String encode({
    required String content,
    List<String> imageUrls = const <String>[],
    Map<String, String> imageHeaders = const <String, String>{},
    String? contentType,
    String? audioUrl,
    String? audioManifestUrl,
    Map<String, String> audioHeaders = const <String, String>{},
  }) {
    final normalizedContent = content.trim();
    final normalizedImages = _normalizeList(imageUrls);
    final normalizedImageHeaders = _normalizeMap(imageHeaders);
    final normalizedAudioUrl = _normalizeOptional(audioUrl);
    final normalizedAudioManifestUrl = _normalizeOptional(audioManifestUrl);
    final normalizedAudioHeaders = _normalizeMap(audioHeaders);
    final normalizedContentType = _normalizeOptional(contentType);

    if (normalizedImages.isEmpty &&
        normalizedAudioUrl == null &&
        normalizedAudioManifestUrl == null) {
      return normalizedContent;
    }

    final payload = <String, Object?>{
      if (normalizedContent.isNotEmpty) 'content': normalizedContent,
      if (normalizedContentType != null) 'contentType': normalizedContentType,
      if (normalizedImages.isNotEmpty) 'imageUrls': normalizedImages,
      if (normalizedImageHeaders.isNotEmpty)
        'imageHeaders': normalizedImageHeaders,
      if (normalizedAudioUrl != null) 'audioUrl': normalizedAudioUrl,
      if (normalizedAudioManifestUrl != null)
        'audioManifestUrl': normalizedAudioManifestUrl,
      if (normalizedAudioHeaders.isNotEmpty)
        'audioHeaders': normalizedAudioHeaders,
    };
    return '$payloadPrefix${jsonEncode(payload)}';
  }

  static ReaderGatewayContentCachePayload decode(String payload) {
    final trimmed = payload.trim();
    if (trimmed.startsWith(payloadPrefix)) {
      return _decodeJsonPayload(trimmed.substring(payloadPrefix.length));
    }
    return ReaderGatewayContentCachePayload(content: trimmed);
  }

  static ReaderGatewayContentCachePayload _decodeJsonPayload(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return ReaderGatewayContentCachePayload(content: raw.trim());
      }
      return ReaderGatewayContentCachePayload(
        content: _normalizeOptional(decoded['content']?.toString()) ?? '',
        contentType: _normalizeOptional(decoded['contentType']?.toString()),
        imageUrls: _normalizeList(decoded['imageUrls'] as List? ?? const []),
        imageHeaders: _normalizeDynamicMap(decoded['imageHeaders']),
        audioUrl: _normalizeOptional(decoded['audioUrl']?.toString()),
        audioManifestUrl: _normalizeOptional(
          decoded['audioManifestUrl']?.toString(),
        ),
        audioHeaders: _normalizeDynamicMap(decoded['audioHeaders']),
      );
    } on FormatException {
      return ReaderGatewayContentCachePayload(content: raw.trim());
    }
  }

  static List<String> _normalizeList(List<dynamic> values) {
    return values
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static Map<String, String> _normalizeDynamicMap(Object? value) {
    if (value is! Map) {
      return const <String, String>{};
    }
    return _normalizeMap(
      value.map((key, value) => MapEntry(key.toString(), value.toString())),
    );
  }

  static Map<String, String> _normalizeMap(Map<String, String> values) {
    final result = <String, String>{};
    for (final entry in values.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        result[key] = value;
      }
    }
    return Map<String, String>.unmodifiable(result);
  }

  static String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
