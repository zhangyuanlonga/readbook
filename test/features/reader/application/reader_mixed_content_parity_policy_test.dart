import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_request.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_mixed_content_parity_policy.dart';

void main() {
  group('ReaderMixedContentParityPolicy', () {
    const policy = ReaderMixedContentParityPolicy();

    test('accepts mixed content blocks with semantic payloads', () {
      final report = policy.evaluate(const <ReaderLayoutBlock>[
        ReaderLayoutBlock.title(text: '标题'),
        ReaderLayoutBlock.paragraph(text: '正文'),
        ReaderLayoutBlock.image(imageUrl: 'https://example.com/p.png'),
        ReaderLayoutBlock.caption(text: '图注'),
        ReaderLayoutBlock.footnote(text: '脚注'),
        ReaderLayoutBlock.link(text: '链接', url: 'https://example.com'),
      ]);

      expect(report.hasMissing, isFalse);
      expect(
        report.statusFor('image'),
        ReaderMixedContentParityStatus.supported,
      );
      expect(
        report.statusFor('caption'),
        ReaderMixedContentParityStatus.supported,
      );
      expect(
        report.statusFor('footnote'),
        ReaderMixedContentParityStatus.supported,
      );
      expect(
        report.statusFor('link'),
        ReaderMixedContentParityStatus.supported,
      );
    });

    test(
      'marks absent optional semantics as partial rather than supported',
      () {
        final report = policy.evaluate(const <ReaderLayoutBlock>[
          ReaderLayoutBlock.paragraph(text: '正文'),
        ]);

        expect(report.hasMissing, isFalse);
        expect(report.hasPartial, isTrue);
        expect(
          report.statusFor('image'),
          ReaderMixedContentParityStatus.partial,
        );
        expect(
          report.statusFor('title'),
          ReaderMixedContentParityStatus.partial,
        );
      },
    );
  });
}
