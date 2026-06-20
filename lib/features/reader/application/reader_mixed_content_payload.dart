enum ReaderMixedContentPayloadKind { image, link, footnote, caption }

class ReaderMixedContentPayload {
  const ReaderMixedContentPayload({
    required this.kind,
    this.url,
    this.text,
    this.label,
    this.sourceIndex,
  });

  final ReaderMixedContentPayloadKind kind;
  final String? url;
  final String? text;
  final String? label;
  final int? sourceIndex;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'version': 'reader_mixed_content_payload_v1',
      'kind': kind.name,
      if (url != null) 'url': url,
      if (text != null) 'text': text,
      if (label != null) 'label': label,
      if (sourceIndex != null) 'sourceIndex': sourceIndex,
    };
  }

  static ReaderMixedContentPayload? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    if (value['version'] != 'reader_mixed_content_payload_v1') {
      return null;
    }
    final kind = _parseKind(value['kind']);
    if (kind == null) {
      return null;
    }
    return ReaderMixedContentPayload(
      kind: kind,
      url: _optionalString(value['url']),
      text: _optionalString(value['text']),
      label: _optionalString(value['label']),
      sourceIndex: _optionalInt(value['sourceIndex']),
    );
  }

  static ReaderMixedContentPayloadKind? _parseKind(Object? value) {
    final name = value?.toString();
    for (final kind in ReaderMixedContentPayloadKind.values) {
      if (kind.name == name) {
        return kind;
      }
    }
    return null;
  }

  static String? _optionalString(Object? value) {
    final normalized = value?.toString().trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static int? _optionalInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }
}

class ReaderMixedContentPayloads {
  const ReaderMixedContentPayloads._();

  static const String payloadKey = 'mixedContent';

  static Map<String, Object?> image({
    required String imageUrl,
    int? sourceIndex,
  }) {
    return _wrap(
      ReaderMixedContentPayload(
        kind: ReaderMixedContentPayloadKind.image,
        url: imageUrl,
        sourceIndex: sourceIndex,
      ),
    );
  }

  static Map<String, Object?> link({
    required String text,
    required String url,
    int? sourceIndex,
  }) {
    return _wrap(
      ReaderMixedContentPayload(
        kind: ReaderMixedContentPayloadKind.link,
        url: url,
        text: text,
        sourceIndex: sourceIndex,
      ),
    );
  }

  static Map<String, Object?> footnote({
    required String text,
    int? sourceIndex,
  }) {
    return _wrap(
      ReaderMixedContentPayload(
        kind: ReaderMixedContentPayloadKind.footnote,
        text: text,
        sourceIndex: sourceIndex,
      ),
    );
  }

  static Map<String, Object?> caption({
    required String text,
    int? sourceIndex,
  }) {
    return _wrap(
      ReaderMixedContentPayload(
        kind: ReaderMixedContentPayloadKind.caption,
        text: text,
        sourceIndex: sourceIndex,
      ),
    );
  }

  static Map<String, Object?> merge(
    Map<String, Object?> base,
    Map<String, Object?> semantic,
  ) {
    if (base.isEmpty) {
      return semantic;
    }
    if (semantic.isEmpty) {
      return base;
    }
    return <String, Object?>{...semantic, ...base};
  }

  static ReaderMixedContentPayload? read(Map<String, Object?> payload) {
    return ReaderMixedContentPayload.fromJson(payload[payloadKey]);
  }

  static Map<String, Object?> _wrap(ReaderMixedContentPayload payload) {
    return <String, Object?>{payloadKey: payload.toJson()};
  }
}
