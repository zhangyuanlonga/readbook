import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_image_pipeline.dart';

void main() {
  group('ReaderImagePipeline', () {
    const pipeline = ReaderImagePipeline();

    test('builds retry request url for remote images only', () {
      expect(
        pipeline.buildRequestUrl(
          imageUrl: 'https://example.com/image.jpg?foo=bar',
          retryNonce: 2,
        ),
        'https://example.com/image.jpg?foo=bar&retry=2',
      );
      expect(
        pipeline.buildRequestUrl(
          imageUrl: 'file:///tmp/image.jpg',
          retryNonce: 2,
        ),
        'file:///tmp/image.jpg',
      );
      expect(
        pipeline.buildRequestUrl(
          imageUrl: 'data:image/png;base64,Zm9v',
          retryNonce: 2,
        ),
        'data:image/png;base64,Zm9v',
      );
    });

    test('detects svg urls and data uris', () {
      expect(
        pipeline.isSvgImageUrl('https://example.com/image.svg?version=1'),
        isTrue,
      );
      expect(
        pipeline.isSvgImageUrl('data:image/svg+xml;base64,PHN2Zz48L3N2Zz4='),
        isTrue,
      );
      expect(pipeline.isSvgImageUrl('https://example.com/image.jpg'), isFalse);
    });

    test('decodes base64 and url-encoded data uris', () {
      final base64Decoded = pipeline.decodeDataUriImage(
        dataUri: 'data:image/svg+xml;base64,PHN2Zz48L3N2Zz4=',
      );
      final plainDecoded = pipeline.decodeDataUriImage(
        dataUri: 'data:text/plain,hello%20reader',
      );

      expect(base64Decoded, isNotNull);
      expect(base64Decoded!.mediaType, 'image/svg+xml');
      expect(base64Decoded.text, '<svg></svg>');
      expect(plainDecoded, isNotNull);
      expect(plainDecoded!.mediaType, 'text/plain');
      expect(plainDecoded.text, 'hello reader');
    });

    testWidgets('retry error widget reports next retry context', (
      tester,
    ) async {
      ReaderImageRetryAction? retriedAction;
      const request = ReaderImagePipelineRequest(
        sourceUrl: 'https://example.com/chapter-1.png',
        requestUrl: 'https://example.com/chapter-1.png?retry=1',
        retryNonce: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: pipeline.buildImageErrorWidget(
              request: request,
              palette: const ReaderImagePipelinePalette(meta: Colors.black54),
              onRetry: (action) {
                retriedAction = action;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('图片加载失败，点击重试'));
      await tester.pump();

      expect(retriedAction, isNotNull);
      expect(retriedAction!.sourceUrl, request.sourceUrl);
      expect(retriedAction!.requestUrl, request.requestUrl);
      expect(retriedAction!.retryNonce, 1);
      expect(retriedAction!.nextRetryNonce, 2);
    });
  });
}
