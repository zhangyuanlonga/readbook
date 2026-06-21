import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_session.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_engine_mode.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_layout_release_policy.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_mode_model.dart';

void main() {
  group('ReaderLayoutReleasePolicy', () {
    test('enables release renderer for paged text by default', () {
      const policy = ReaderLayoutReleasePolicy();

      final decision = policy.resolve(
        contentMode: ReaderContentMode.text,
        viewportKind: ReaderModeViewportKind.textPaged,
        hasRenderableText: true,
        contentLength: 120,
      );

      expect(decision.useReleaseRenderer, isTrue);
      expect(decision.mode, ReaderLayoutEngineMode.experimental);
      expect(decision.reason, 'enabled');
      expect(decision.options.mode, ReaderLayoutEngineMode.experimental);
    });

    test('keeps legacy renderer when force legacy is enabled', () {
      const policy = ReaderLayoutReleasePolicy(forceLegacy: true);

      final decision = policy.resolve(
        contentMode: ReaderContentMode.text,
        viewportKind: ReaderModeViewportKind.textPaged,
        hasRenderableText: true,
        contentLength: 120,
      );

      expect(decision.useReleaseRenderer, isFalse);
      expect(decision.mode, ReaderLayoutEngineMode.legacy);
      expect(decision.reason, 'force_legacy');
    });

    test('passes strict release validation to renderer options', () {
      const policy = ReaderLayoutReleasePolicy(strictReleaseValidation: true);

      final decision = policy.resolve(
        contentMode: ReaderContentMode.text,
        viewportKind: ReaderModeViewportKind.textPaged,
        hasRenderableText: true,
        contentLength: 120,
      );

      expect(decision.strictReleaseValidation, isTrue);
      expect(decision.options.strictReleaseValidation, isTrue);
      expect(
        decision.toDiagnosticsContext(),
        containsPair('readerLayoutReleaseStrictValidation', true),
      );
    });

    test('does not touch non paged text surfaces', () {
      const policy = ReaderLayoutReleasePolicy();

      final scrollDecision = policy.resolve(
        contentMode: ReaderContentMode.text,
        viewportKind: ReaderModeViewportKind.textScroll,
        hasRenderableText: true,
        contentLength: 120,
      );
      final comicDecision = policy.resolve(
        contentMode: ReaderContentMode.comic,
        viewportKind: ReaderModeViewportKind.imagePaged,
        hasRenderableText: true,
        contentLength: 120,
      );

      expect(scrollDecision.reason, 'non_paged_viewport');
      expect(comicDecision.reason, 'non_text_content');
    });

    test('honors explicit content length cap', () {
      const policy = ReaderLayoutReleasePolicy(maxContentLength: 10);

      final decision = policy.resolve(
        contentMode: ReaderContentMode.text,
        viewportKind: ReaderModeViewportKind.textPaged,
        hasRenderableText: true,
        contentLength: 11,
      );

      expect(decision.useReleaseRenderer, isFalse);
      expect(decision.reason, 'content_length_over_cap');
    });

    test('keeps release renderer for existing page animations', () {
      const policy = ReaderLayoutReleasePolicy();

      final decision = policy.resolve(
        contentMode: ReaderContentMode.text,
        viewportKind: ReaderModeViewportKind.textPaged,
        hasRenderableText: true,
        contentLength: 120,
        pageAnimationStyle: ReaderPageAnimationStyle.paperCurl,
      );

      expect(decision.useReleaseRenderer, isTrue);
      expect(decision.mode, ReaderLayoutEngineMode.experimental);
      expect(decision.reason, 'enabled');
      expect(
        decision.toDiagnosticsContext(),
        containsPair('readerLayoutReleaseRequestedAnimation', 'paperCurl'),
      );
    });

    test('builds stable document fingerprints', () {
      const policy = ReaderLayoutReleasePolicy();
      final document = ReaderDocument(
        blocks: const <ReaderBlock>[ReaderTextBlock(text: '正文')],
      );

      final first = policy.buildDocumentFingerprint(
        chapterId: 'chapter-1',
        document: document,
        paragraphs: const <String>['正文'],
        fallbackContent: '正文',
      );
      final second = policy.buildDocumentFingerprint(
        chapterId: 'chapter-1',
        document: document,
        paragraphs: const <String>['正文'],
        fallbackContent: '正文',
      );
      final changed = policy.buildDocumentFingerprint(
        chapterId: 'chapter-1',
        document: ReaderDocument(
          blocks: const <ReaderBlock>[ReaderTextBlock(text: '正文改动')],
        ),
        paragraphs: const <String>['正文'],
        fallbackContent: '正文',
      );

      expect(first, second);
      expect(first, isNot(changed));
    });
  });
}
