import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/paged_animation/cover_paged_animation_renderer.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/paged_animation/curl_paged_animation_renderer.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/paged_animation/fade_paged_animation_renderer.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/paged_animation/paged_animation_renderer_registry.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/paged_animation/translate_paged_animation_renderer.dart';

void main() {
  group('PagedAnimationRendererRegistry', () {
    const registry = PagedAnimationRendererRegistry();

    test('resolves animation styles to dedicated renderers', () {
      expect(
        registry.resolve(ReaderPageAnimationStyle.cover),
        isA<CoverPagedAnimationRenderer>(),
      );
      expect(
        registry.resolve(ReaderPageAnimationStyle.translate),
        isA<TranslatePagedAnimationRenderer>(),
      );
      expect(
        registry.resolve(ReaderPageAnimationStyle.vertical),
        isA<TranslatePagedAnimationRenderer>(),
      );
      expect(
        registry.resolve(ReaderPageAnimationStyle.fade),
        isA<FadePagedAnimationRenderer>(),
      );
      expect(
        registry.resolve(ReaderPageAnimationStyle.none),
        isA<FadePagedAnimationRenderer>(),
      );
    });
  });

  group('Paged animation renderers', () {
    const fromPage = ColoredBox(color: Colors.red);
    const toPage = ColoredBox(color: Colors.blue);

    testWidgets('cover renderer builds transition stack', (tester) async {
      const renderer = CoverPagedAnimationRenderer();

      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.expand(child: Placeholder()),
        ),
      );

      final widget = renderer.build(
        fromPage: fromPage,
        toPage: toPage,
        progress: 0.4,
        direction: 1,
      );

      expect(widget, isA<Stack>());
    });

    testWidgets('fade renderer builds opacity stack', (tester) async {
      const renderer = FadePagedAnimationRenderer();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: renderer.build(
            fromPage: fromPage,
            toPage: toPage,
            progress: 0.5,
            direction: 1,
          ),
        ),
      );

      expect(find.byType(Opacity), findsNWidgets(2));
    });

    testWidgets('curl renderer keeps current page when progress is zero', (
      tester,
    ) async {
      const renderer = CurlPagedAnimationRenderer();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: renderer.build(
            currentPage: fromPage,
            targetPage: toPage,
            progress: 0,
            direction: 1,
            colors: const CurlRendererColors(
              backgroundColor: Colors.white,
              dividerColor: Colors.black12,
              overlayColor: Colors.black26,
            ),
          ),
        ),
      );

      expect(find.byType(ClipPath), findsNothing);
      expect(find.byType(CustomPaint), findsNothing);
    });

    testWidgets('curl renderer builds clip and overlay layers', (tester) async {
      const renderer = CurlPagedAnimationRenderer();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: renderer.build(
            currentPage: fromPage,
            targetPage: toPage,
            progress: 0.55,
            direction: 1,
            colors: const CurlRendererColors(
              backgroundColor: Colors.white,
              dividerColor: Colors.black12,
              overlayColor: Colors.black26,
            ),
          ),
        ),
      );

      expect(find.byType(ClipPath), findsNWidgets(2));
      expect(find.byType(CustomPaint), findsOneWidget);
      expect(find.byType(Transform), findsOneWidget);
    });

    testWidgets('curl renderer supports reverse direction', (tester) async {
      const renderer = CurlPagedAnimationRenderer();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: renderer.build(
            currentPage: fromPage,
            targetPage: toPage,
            progress: 0.45,
            direction: -1,
            colors: const CurlRendererColors(
              backgroundColor: Colors.white,
              dividerColor: Colors.black12,
              overlayColor: Colors.black26,
            ),
          ),
        ),
      );

      expect(find.byType(ClipPath), findsNWidgets(2));
      expect(find.byType(CustomPaint), findsOneWidget);
      expect(find.byType(Stack), findsAtLeastNWidgets(1));
      expect(find.byType(Transform), findsOneWidget);
    });
  });
}
